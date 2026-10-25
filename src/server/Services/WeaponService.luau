--!strict
-- Server-authoritative weapons. Owns every player's loadout, ammo, reload and
-- fire timing, validates every shot the client reports, and applies damage.
--
-- Shot validation ladder (roblox-security): rate limit -> types -> ranges ->
-- weapon state (equipped, ammo, interval, charge) -> origin near the server's
-- head -> per hit: real character, alive, not self, within range, inside the
-- gun's possible spread, on the target's recent hitbox, no wall in between.
-- Damage always comes from Config/Weapons on the server, never the client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Damage = require(Shared.Util.Damage)
local Dev = require(Shared.Config.Dev)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local Spread = require(Shared.Util.Spread)
local Types = require(Shared.Types)
local Weapons = require(Shared.Config.Weapons)

local HitboxHistory = require(script.Parent.HitboxHistory)

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig
type HitZone = Types.HitZone

type SlotState = {
	id: string,
	config: WeaponConfig,
	ammo: number,
	reloadToken: number,
	reloadEnd: number?,
	lastFire: number, -- "virtual" time of the last accepted shot (rate enforcement)
	spinStart: number?,
	chargeStart: number?,
}

type PlayerState = {
	slots: { [Slot]: SlotState },
	equipped: Slot?,
	equipReadyAt: number,
	worldModel: Model?,
}

local SLOTS: { Slot } = { "Primary", "Secondary", "Melee" }
local FIRE_JITTER = 0.05 -- seconds of network jitter forgiven per shot
local MAX_COORD = 1e5

local WeaponService = {}

local states: { [Player]: PlayerState } = {}
local loadouts: { [Player]: { [Slot]: string } } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local WeaponsFolder: Instance? = nil

-- Helpers ------------------------------------------------------------------

local function allow(player: Player, key: string): boolean
	local rate = Combat.RATE[key]
	local perSecond, burst = rate[1], rate[2]
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[key]
	if not b then
		b = { tokens = burst, last = now }
		pb[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function finiteVector(v: unknown): Vector3?
	if typeof(v) ~= "Vector3" then
		return nil
	end
	local vec = v :: Vector3
	for _, c in { vec.X, vec.Y, vec.Z } do
		if c ~= c or math.abs(c) > MAX_COORD then
			return nil
		end
	end
	return vec
end

local function isSlot(v: unknown): boolean
	return v == "Primary" or v == "Secondary" or v == "Melee"
end

local function liveHumanoid(model: Model?): Humanoid?
	if not model then
		return nil
	end
	local h = model:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

-- The combatant Model a part belongs to (walks up through accessories etc.).
local function combatantOf(part: Instance): Model?
	local node: Instance? = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function snapshot(state: PlayerState): Types.WeaponState
	local slots = {}
	for slot, s in state.slots do
		slots[slot] = { id = s.id, ammo = s.ammo }
	end
	return { slots = slots, equipped = state.equipped }
end

local function sendState(player: Player)
	local state = states[player]
	if state then
		Net.event("WeaponState"):FireClient(player, snapshot(state))
	end
end

local function newSlot(id: string): SlotState?
	local config = Weapons.get(id)
	if not config then
		return nil
	end
	return {
		id = id,
		config = config,
		ammo = config.magSize,
		reloadToken = 0,
		lastFire = -math.huge,
	}
end

-- World model (what other players see) ---------------------------------------

local GRIP_C0 = CFrame.new(0, -0.15, -0.05) * CFrame.Angles(-math.pi / 2, 0, 0)

local function weaponTemplate(id: string): Model?
	if not WeaponsFolder then
		WeaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	end
	local folder = WeaponsFolder
	local m = folder and folder:FindFirstChild(id)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

-- Puts a copy of `id` in the character's right hand (or removes it with nil).
function WeaponService.attachWorldModel(character: Model, id: string?): Model?
	local old = character:FindFirstChild("WorldWeapon")
	if old then
		old:Destroy()
	end
	if not id then
		return nil
	end
	local template = weaponTemplate(id)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not template or not hand or not hand:IsA("BasePart") then
		return nil
	end
	local model = template:Clone()
	model.Name = "WorldWeapon"
	model:SetAttribute("WeaponId", id)
	local handle = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local grip = Instance.new("Motor6D")
	grip.Name = "WeaponGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = GRIP_C0
	grip.Parent = handle
	handle.CFrame = hand.CFrame * GRIP_C0
	model.Parent = character
	character:SetAttribute("WeaponId", id)
	return model
end

local function refreshWorldModel(player: Player)
	local state = states[player]
	local character = player.Character
	if not state or not character then
		return
	end
	local slot = state.equipped and state.slots[state.equipped]
	state.worldModel = WeaponService.attachWorldModel(character, slot and slot.id or nil)
end

-- Loadout --------------------------------------------------------------------

function WeaponService.getLoadout(player: Player): { [Slot]: string }
	local l = loadouts[player]
	if not l then
		l = {
			Primary = Weapons.DEFAULT_LOADOUT.Primary,
			Secondary = Weapons.DEFAULT_LOADOUT.Secondary,
			Melee = Weapons.DEFAULT_LOADOUT.Melee,
		}
		loadouts[player] = l
	end
	return l
end

-- Gives the player a fresh set of weapons (full ammo) and equips the primary.
function WeaponService.giveLoadout(player: Player)
	local loadout = WeaponService.getLoadout(player)
	local slots: { [Slot]: SlotState } = {}
	for _, slot in SLOTS do
		local s = newSlot(loadout[slot])
		if s then
			slots[slot] = s
		end
	end
	states[player] = {
		slots = slots,
		equipped = "Primary",
		equipReadyAt = os.clock() + slots.Primary.config.equipTime * 0.7,
	}
	refreshWorldModel(player)
	sendState(player)
end

-- Swaps one slot's weapon (used by the draft later, and the Studio dev picker).
function WeaponService.setWeapon(player: Player, slot: Slot, id: string)
	local config = Weapons.get(id)
	if not config or config.slot ~= slot then
		return
	end
	WeaponService.getLoadout(player)[slot] = id
	local state = states[player]
	if not state then
		return
	end
	local s = newSlot(id)
	if not s then
		return
	end
	state.slots[slot] = s
	if state.equipped == slot then
		state.equipReadyAt = os.clock() + config.equipTime * 0.7
		refreshWorldModel(player)
	end
	sendState(player)
end

-- Damage ---------------------------------------------------------------------

local function applyDamage(
	attacker: Player,
	victimModel: Model,
	amount: number,
	zone: HitZone,
	config: WeaponConfig,
	at: Vector3
)
	local humanoid = liveHumanoid(victimModel)
	if not humanoid then
		return
	end
	local before = humanoid.Health
	humanoid:TakeDamage(amount)
	local dealt = math.clamp(before - humanoid.Health, 0, before)
	local killed = before > 0 and humanoid.Health <= 0
	humanoid:SetAttribute("LastAttacker", attacker.UserId)

	Net.event("HitConfirm"):FireClient(attacker, {
		damage = math.round(dealt),
		zone = zone,
		killed = killed,
		position = at,
	})

	local victim = Players:GetPlayerFromCharacter(victimModel)
	local attackerRoot = attacker.Character
		and attacker.Character:FindFirstChild("HumanoidRootPart")
	if victim and attackerRoot and attackerRoot:IsA("BasePart") then
		Net.event("Damaged"):FireClient(victim, attackerRoot.Position, math.round(dealt))
	end
	if killed then
		Net.event("Killed"):FireAllClients(victimModel, attacker, config.id, zone == "Head")
	end
end

-- Is there solid world geometry between `from` and `to` that this gun can't go through?
local function blocked(
	shooter: Model,
	from: Vector3,
	to: Vector3,
	penetration: Types.Penetration
): boolean
	if penetration == "All" then
		return false
	end
	local exclude: { Instance } = { shooter }
	-- Characters never block for this check (they're validated separately).
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(exclude, dummies)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.5 then
		return false
	end
	local origin = from
	for _ = 1, 4 do
		local result = workspace:Raycast(
			origin,
			(to - origin).Unit * math.max((to - origin).Magnitude - 0.5, 0),
			params
		)
		if not result then
			return false
		end
		local part = result.Instance
		if combatantOf(part) then
			return false -- hit the dummy/character body itself
		end
		if penetration == "ThinWall" and CollectionService:HasTag(part, Combat.THIN_WALL_TAG) then
			params:AddToFilter(part)
			origin = result.Position
		else
			return true
		end
	end
	return true
end

-- Remote handlers --------------------------------------------------------------

local function onEquip(player: Player, slot: unknown)
	if not allow(player, "Equip") then
		return
	end
	if not isSlot(slot) then
		return
	end
	local state = states[player]
	if not state or not liveHumanoid(player.Character) then
		return
	end
	local target = state.slots[slot :: Slot]
	if not target or state.equipped == slot then
		return
	end
	-- Swapping cancels a reload in progress.
	local current = state.equipped and state.slots[state.equipped]
	if current then
		current.reloadToken += 1
		current.reloadEnd = nil
		current.chargeStart = nil
	end
	state.equipped = slot :: Slot
	state.equipReadyAt = os.clock() + target.config.equipTime * 0.7
	refreshWorldModel(player)
	sendState(player)
end

local function onReload(player: Player)
	if not allow(player, "Reload") then
		return
	end
	local state = states[player]
	local slot = state and state.equipped and state.slots[state.equipped]
	if not state or not slot or not liveHumanoid(player.Character) then
		return
	end
	local config = slot.config
	if config.magSize <= 0 or slot.ammo >= config.magSize or slot.reloadEnd then
		return
	end
	local duration = if slot.ammo == 0 then config.emptyReloadTime else config.reloadTime
	slot.reloadToken += 1
	local token = slot.reloadToken
	-- Accept the client's reload a little early to hide latency.
	slot.reloadEnd = os.clock() + duration - 0.1
	task.delay(duration - 0.1, function()
		if slot.reloadToken == token and states[player] == state then
			slot.ammo = config.magSize
			slot.reloadEnd = nil
			sendState(player)
		end
	end)
end

local function onCharge(player: Player)
	if not allow(player, "Charge") then
		return
	end
	local state = states[player]
	local slot = state and state.equipped and state.slots[state.equipped]
	if slot and slot.config.chargeTime then
		slot.chargeStart = os.clock()
	end
end

local function onAim(player: Player, pitch: unknown, aiming: unknown)
	if not allow(player, "Aim") then
		return
	end
	if typeof(pitch) ~= "number" or pitch ~= pitch or typeof(aiming) ~= "boolean" then
		return
	end
	local character = player.Character
	if character then
		character:SetAttribute("AimPitch", math.clamp(pitch, -1.5, 1.5))
		character:SetAttribute("Aiming", aiming)
	end
end

local function onDev(player: Player, slot: unknown)
	if not allow(player, "Dev") then
		return
	end
	if not RunService:IsStudio() or not Dev.WEAPON_PICKER then
		return
	end
	if slot ~= "Primary" and slot ~= "Secondary" then
		return
	end
	local list = Weapons.DEV_CYCLE[slot :: string]
	local current = WeaponService.getLoadout(player)[slot :: Slot]
	local index = table.find(list, current) or 0
	local nextId = list[index % #list + 1]
	WeaponService.setWeapon(player, slot :: Slot, nextId)
end

type ValidHit = { model: Model, part: BasePart, position: Vector3, pellet: number }

local function onFire(player: Player, payload: unknown)
	if not allow(player, "Fire") then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: { [string]: unknown }
	local origin = finiteVector(p.origin)
	local aim = finiteVector(p.direction)
	local seed = p.seed
	if not origin or not aim or typeof(seed) ~= "number" or seed ~= seed then
		return
	end
	if aim.Magnitude < 0.9 or aim.Magnitude > 1.1 then
		return
	end
	aim = aim.Unit

	local state = states[player]
	local character = player.Character
	local humanoid = liveHumanoid(character)
	if not state or not character or not humanoid or not state.equipped then
		return
	end
	local slot = state.slots[state.equipped]
	if not slot then
		return
	end
	local config = slot.config
	local now = os.clock()

	-- Weapon state.
	if now < state.equipReadyAt then
		return
	end
	if slot.reloadEnd and now < slot.reloadEnd then
		return
	end
	if config.magSize > 0 and slot.ammo <= 0 then
		return
	end
	local interval = FireRate.interval(config, slot.spinStart, slot.lastFire, now)
	if now < slot.lastFire + interval - FIRE_JITTER then
		return
	end
	if config.chargeTime then
		if not slot.chargeStart or now - slot.chargeStart < config.chargeTime - 0.1 then
			return
		end
		slot.chargeStart = nil
	end

	-- The shot comes from roughly where the server thinks the player's head is.
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	if (origin - head.Position).Magnitude > Combat.ORIGIN_TOLERANCE then
		return
	end

	-- Accept the shot.
	if not slot.spinStart or now - slot.lastFire > FireRate.SPIN_RESET then
		slot.spinStart = now
	end
	slot.lastFire = math.max(now - FIRE_JITTER, slot.lastFire + interval)
	if config.magSize > 0 then
		slot.ammo -= 1
	end

	-- Replicate the visuals to everyone else (cosmetic: clamp, don't trust).
	local ends: { Vector3 } = {}
	if typeof(p.ends) == "table" then
		for i, e in p.ends :: { unknown } do
			if i > config.pellets then
				break
			end
			local v = finiteVector(e)
			if v then
				local offset = v - origin
				if offset.Magnitude > config.range then
					v = origin + offset.Unit * config.range
				end
				table.insert(ends, v)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.unreliable("ShotFx"):FireClient(other, player, config.id, origin, ends)
		end
	end

	-- Validate hits.
	if typeof(p.hits) ~= "table" then
		return
	end
	local maxHits = math.min(
		Combat.MAX_HITS_PER_SHOT,
		config.pellets * (if config.pierceCharacters then 4 else 1)
	)
	local maxAngle = config.hipSpread
		+ config.maxBloom
		+ Combat.MOVE_SPREAD.Air
		+ config.pelletSpread
		+ Combat.DIRECTION_TOLERANCE
	local valid: { ValidHit } = {}
	local seenPellet: { [number]: number } = {}
	for i, raw in p.hits :: { unknown } do
		if i > maxHits then
			break
		end
		if typeof(raw) ~= "table" then
			continue
		end
		local h = raw :: { [string]: unknown }
		local part = h.part
		local position = finiteVector(h.position)
		local pellet = h.pellet
		if typeof(part) ~= "Instance" or not (part :: Instance):IsA("BasePart") or not position then
			continue
		end
		if
			typeof(pellet) ~= "number"
			or pellet ~= math.floor(pellet)
			or pellet < 1
			or pellet > config.pellets
		then
			continue
		end
		local hitPart = part :: BasePart
		if not hitPart:IsDescendantOf(workspace) then
			continue
		end
		local model = combatantOf(hitPart)
		if not model or model == character or not liveHumanoid(model) then
			continue
		end
		if not HitboxHistory.isTracked(model) then
			continue
		end

		-- One target per pellet unless the gun pierces.
		local count = (seenPellet[pellet] or 0) + 1
		if count > 1 and not config.pierceCharacters then
			continue
		end
		seenPellet[pellet] = count

		local offset = position - origin
		local distance = offset.Magnitude
		if config.melee then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local reach = config.melee.range + Combat.MELEE_TOLERANCE + hitPart.Size.Magnitude / 2
			if (hitPart.Position - root.Position).Magnitude > reach then
				continue
			end
		else
			if distance > config.range + 5 then
				continue
			end
			if distance > 2 and Spread.angle(offset, aim) > maxAngle then
				continue
			end
		end
		if not HitboxHistory.plausible(model, hitPart, position, Combat.HIT_POSITION_TOLERANCE) then
			continue
		end
		if blocked(character, origin, position, config.penetration) then
			continue
		end
		table.insert(valid, { model = model, part = hitPart, position = position, pellet = pellet })
	end

	-- Sum damage per target (pellets), then apply once.
	type Tally = { amount: number, zone: HitZone, position: Vector3 }
	local tally: { [Model]: Tally } = {}
	for _, hit in valid do
		local zone = Damage.zoneOf(hit.part.Name)
		local amount: number
		if config.melee then
			amount = config.damage.body
			local victimRoot = hit.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if victimRoot and root then
				local toVictim = (victimRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				if toVictim.Magnitude > 0.01 then
					local facing = victimRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
					if facing.Unit:Dot(toVictim.Unit) > Combat.BACKSTAB_DOT then
						amount = config.melee.backDamage
					end
				end
			end
			zone = "Body"
		else
			amount = Damage.compute(config, zone, (hit.position - origin).Magnitude)
		end
		local t = tally[hit.model]
		if t then
			t.amount += amount
			if zone == "Head" then
				t.zone = "Head"
			end
		else
			tally[hit.model] = { amount = amount, zone = zone, position = hit.position }
		end
	end
	for model, t in tally do
		applyDamage(player, model, t.amount, t.zone, config, t.position)
	end
end

-- Lifecycle --------------------------------------------------------------------

local function onCharacter(player: Player, character: Model)
	-- Wait until CharacterService has prepared the character.
	task.defer(function()
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		character:WaitForChild("RightHand", 5)
		if not humanoid or character.Parent == nil then
			return
		end
		WeaponService.giveLoadout(player)
		humanoid.Died:Connect(function()
			local state = states[player]
			if state then
				state.equipped = nil
				for _, s in state.slots do
					s.reloadToken += 1
				end
			end
		end)
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

function WeaponService.init()
	Net.event("Equip").OnServerEvent:Connect(onEquip)
	Net.event("Fire").OnServerEvent:Connect(onFire)
	Net.event("Reload").OnServerEvent:Connect(onReload)
	Net.event("Charge").OnServerEvent:Connect(onCharge)
	Net.event("Dev").OnServerEvent:Connect(onDev)
	Net.unreliable("Aim").OnServerEvent:Connect(onAim)
end

function WeaponService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		loadouts[player] = nil
		buckets[player] = nil
	end)
end

return WeaponService
