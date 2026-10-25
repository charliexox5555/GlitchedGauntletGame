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
	burstShots: number,
	rechargeFrom: number, -- beam battery: recharge counted from here
	beamTarget: Model?,
	beamStart: number,
	beamLastHit: number,
}

type PlayerState = {
	slots: { [Slot]: SlotState },
	equipped: Slot?,
	equipReadyAt: number,
	worldModel: Model?,
	seedBase: number, -- server-issued: spread seeds can't be chosen by the client
	shotIndex: number, -- last accepted shot counter
}

local SLOTS: { Slot } = { "Primary", "Secondary", "Melee" }
local MAX_COORD = 1e5
local seedRng = Random.new()

local WeaponService = {}

local states: { [Player]: PlayerState } = {}
local loadouts: { [Player]: { [Slot]: string } } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local WeaponsFolder: Instance? = nil

-- Defined further down (used by onFire).
local rechargeBeam: (SlotState, number) -> ()
local beamTickDamage: (SlotState, Model, number) -> number
local spawnProjectile: (Player, Model, Vector3, Vector3, WeaponConfig) -> ()

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

-- The combatant a part is a hitbox of: only real body parts that are direct
-- children of a character (never hats, held guns or other accessories).
local function hitboxOwner(part: Instance): Model?
	if not Combat.BODY_PARTS[part.Name] then
		return nil
	end
	local model = part.Parent
	if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

-- Any combatant model a part belongs to (used to let bodies not count as walls).
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
	return {
		slots = slots,
		equipped = state.equipped,
		seedBase = state.seedBase,
		shotIndex = state.shotIndex,
	}
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
		burstShots = 0,
		rechargeFrom = 0,
		beamStart = 0,
		beamLastHit = -math.huge,
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

local function holdModel(
	character: Model,
	templateId: string,
	handName: string,
	name: string
): Model?
	local template = weaponTemplate(templateId)
	local hand = character:FindFirstChild(handName)
		or character:FindFirstChild(if handName == "RightHand" then "Right Arm" else "Left Arm")
	if not template or not hand or not hand:IsA("BasePart") then
		return nil
	end
	local model = template:Clone()
	model.Name = name
	local handle = model.PrimaryPart
	if not handle then
		model:Destroy()
		return nil
	end
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
	return model
end

-- Puts weapon `id` in the character's hand(s) (or removes it with nil).
-- Dual Boot holds a second model in the left hand ("WorldWeaponLeft").
function WeaponService.attachWorldModel(character: Model, id: string?): Model?
	for _, name in { "WorldWeapon", "WorldWeaponLeft" } do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if not id then
		return nil
	end
	local config = Weapons.get(id)
	local rightId = if config and config.models then config.models.right else id
	local model = holdModel(character, rightId, "RightHand", "WorldWeapon")
	if model then
		model:SetAttribute("WeaponId", id)
	end
	if config and config.models and config.models.left then
		holdModel(character, config.models.left, "LeftHand", "WorldWeaponLeft")
	end
	-- Cosmetic state lives on the Player (not the predicted character) so it
	-- never triggers Server Authority rollbacks. Dummies keep it on the model.
	local owner = Players:GetPlayerFromCharacter(character)
	if owner then
		owner:SetAttribute("WeaponId", id)
	else
		character:SetAttribute("WeaponId", id)
	end
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
	-- Read by the movement simulation (shared/Simulation/Movement).
	player:SetAttribute("MoveMult", if slot then slot.config.moveMultiplier else 1)
	player:SetAttribute("AdsMult", if slot then slot.config.adsMoveMultiplier else 1)
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
	local first: Slot? = if slots.Primary
		then "Primary"
		elseif slots.Secondary then "Secondary"
		else nil
	local old = states[player]
	states[player] = {
		slots = slots,
		equipped = first,
		equipReadyAt = os.clock() + (if first then slots[first].config.equipTime * 0.7 else 0),
		-- Keep the seed sequence across respawns so in-flight shots stay valid.
		seedBase = if old then old.seedBase else seedRng:NextInteger(1, 2 ^ 30),
		shotIndex = if old then old.shotIndex else 0,
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

-- Things a wall check should ignore: the shooter and every combatant (bodies
-- don't count as walls; they're validated as hitboxes separately).
local function wallExclusions(shooter: Model): { Instance }
	local exclude: { Instance } = { shooter }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(exclude, dummies)
	end
	return exclude
end

-- Is there solid world geometry between `from` and `to` that this gun can't go through?
local function blocked(
	exclude: { Instance },
	from: Vector3,
	to: Vector3,
	penetration: Types.Penetration
): boolean
	if penetration == "All" then
		return false
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
	if config.magSize <= 0 or config.beam or slot.ammo >= config.magSize or slot.reloadEnd then
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
	player:SetAttribute("AimPitch", math.clamp(pitch, -1.5, 1.5))
	player:SetAttribute("Aiming", aiming)
end

local function onDev(player: Player, slot: unknown)
	if not allow(player, "Dev") then
		return
	end
	if not RunService:IsStudio() or not Dev.WEAPON_PICKER then
		return
	end
	-- A weapon id equips that gun directly (the dev menu); a slot cycles it.
	if typeof(slot) == "string" and Weapons.get(slot) then
		local config = Weapons.get(slot) :: WeaponConfig
		WeaponService.setWeapon(player, config.slot, config.id)
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

type ValidHit = { model: Model, part: BasePart, rewound: Vector3, pellet: number }

-- Reads an array argument safely (ignores non-integer keys, caps length).
local function readArray(value: unknown, max: number): { unknown }
	local out = {}
	if typeof(value) ~= "table" then
		return out
	end
	for _, v in ipairs(value :: { unknown }) do
		if #out >= max then
			break
		end
		table.insert(out, v)
	end
	return out
end

local function rewindWindow(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	local p = if ok and typeof(ping) == "number" then ping else 0.1
	return math.min(p * 2 + Combat.REWIND_EXTRA, Combat.REWIND_MAX)
end

-- Studio-only: record why the last shot or hit was rejected (player attribute
-- "FireReject"), so tuning tolerances doesn't need print debugging.
local function reject(player: Player, reason: string)
	if RunService:IsStudio() then
		player:SetAttribute("FireReject", reason)
	end
end

-- Beam (Null) --------------------------------------------------------------------

-- Refills the beam battery (in ticks) after the recharge delay.
rechargeBeam = function(slot: SlotState, now: number)
	local beam = slot.config.beam
	if not beam then
		return
	end
	local from = math.max(slot.lastFire + beam.rechargeDelay, slot.rechargeFrom)
	if now > from then
		slot.ammo =
			math.min(slot.config.magSize, slot.ammo + (now - from) * beam.rechargeRate / beam.tick)
		slot.rechargeFrom = now
	end
end

-- Damage for one beam tick: ramps up while the beam stays on the same target.
beamTickDamage = function(slot: SlotState, model: Model, now: number): number
	local beam = slot.config.beam :: Types.BeamStats
	if slot.beamTarget ~= model or now - slot.beamLastHit > beam.tick * 2.5 then
		slot.beamTarget = model
		slot.beamStart = now
	end
	slot.beamLastHit = now
	local t = math.clamp((now - slot.beamStart) / beam.rampTime, 0, 1)
	return (beam.dpsStart + (beam.dpsEnd - beam.dpsStart) * t) * beam.tick
end

-- Projectiles (Loopback) -----------------------------------------------------------
-- Flown on the server: authoritative hits, no client claims to validate.

type Projectile = {
	owner: Player,
	config: WeaponConfig,
	position: Vector3,
	velocity: Vector3,
	bounces: number,
	expires: number,
	params: RaycastParams,
}

local projectiles: { Projectile } = {}

spawnProjectile = function(
	owner: Player,
	shooter: Model,
	origin: Vector3,
	dir: Vector3,
	config: WeaponConfig
)
	local stats = config.projectile :: Types.ProjectileStats
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooter }
	table.insert(projectiles, {
		owner = owner,
		config = config,
		position = origin + dir * 1.5,
		velocity = dir * stats.speed,
		bounces = stats.bounces,
		expires = os.clock() + stats.lifetime,
		params = params,
	})
end

local function stepProjectiles(dt: number)
	local now = os.clock()
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local stats = pr.config.projectile :: Types.ProjectileStats
		local alive = now < pr.expires and pr.owner.Parent ~= nil
		if alive then
			local move = pr.velocity * dt
			local result = workspace:Spherecast(pr.position, stats.radius, move, pr.params)
			if not result then
				pr.position += move
			else
				local part = result.Instance
				local victim = hitboxOwner(part)
				if victim and liveHumanoid(victim) then
					applyDamage(
						pr.owner,
						victim,
						pr.config.damage.body,
						"Body",
						pr.config,
						result.Position
					)
					alive = false
				elseif combatantOf(part) then
					pr.params:AddToFilter(part) -- hats, held guns: fly through
					pr.position += move
				else
					-- Bounce off the surface.
					pr.bounces -= 1
					if pr.bounces < 0 then
						alive = false
					else
						local n = result.Normal
						pr.velocity = pr.velocity - 2 * pr.velocity:Dot(n) * n
						pr.position = result.Position + n * (stats.radius + 0.05)
					end
				end
			end
		end
		if not alive then
			table.remove(projectiles, i)
		end
	end
end

local function onFire(player: Player, payload: unknown)
	if not allow(player, "Fire") then
		return
	end
	if typeof(payload) ~= "table" then
		reject(player, "typeof(payload) ~= 'table'")
		return
	end
	local p = payload :: { [string]: unknown }
	local origin = finiteVector(p.origin)
	local aim = finiteVector(p.direction)
	local shot = p.shot
	local spreadClaim = p.spread
	if not origin or not aim then
		reject(player, "not origin or not aim")
		return
	end
	if typeof(shot) ~= "number" or shot ~= math.floor(shot) then
		reject(player, "typeof(shot) ~= 'number' or shot ~= math.floor(shot)")
		return
	end
	if typeof(spreadClaim) ~= "number" or spreadClaim ~= spreadClaim then
		reject(player, "typeof(spreadClaim) ~= 'number' or spreadClaim ~= spreadClaim")
		return
	end
	if aim.Magnitude < 0.9 or aim.Magnitude > 1.1 then
		reject(player, "aim.Magnitude < 0.9 or aim.Magnitude > 1.1")
		return
	end
	aim = aim.Unit

	local state = states[player]
	local character = player.Character
	local humanoid = liveHumanoid(character)
	if not state or not character or not humanoid or not state.equipped then
		reject(player, "not state or not character or not humanoid or not state.equipped")
		return
	end
	local slot = state.slots[state.equipped]
	if not slot then
		reject(player, "not slot")
		return
	end
	local config = slot.config
	local now = os.clock()

	-- Shot counter: must move forward, and only by a little (lost shots).
	if shot <= state.shotIndex or shot > state.shotIndex + Combat.MAX_SHOT_SKIP then
		reject(player, "shot <= state.shotIndex or shot > state.shotIndex + Combat.MAX_SHOT_SKIP")
		return
	end

	-- Weapon state.
	if now < state.equipReadyAt then
		reject(player, "now < state.equipReadyAt")
		return
	end
	if slot.reloadEnd and now < slot.reloadEnd then
		reject(player, "slot.reloadEnd and now < slot.reloadEnd")
		return
	end
	rechargeBeam(slot, now)
	if config.magSize > 0 and slot.ammo < 1 then
		reject(player, "out of ammo")
		return
	end
	local interval = FireRate.interval(config, slot.spinStart, slot.lastFire, now, slot.burstShots)
	if now < slot.lastFire + interval - Combat.FIRE_JITTER then
		reject(player, "now < slot.lastFire + interval - Combat.FIRE_JITTER")
		return
	end
	if config.chargeTime then
		if not slot.chargeStart or now - slot.chargeStart < config.chargeTime - 0.1 then
			reject(
				player,
				"not slot.chargeStart or now - slot.chargeStart < config.chargeTime - 0.1"
			)
			return
		end
		slot.chargeStart = nil
	end

	-- The shot comes from roughly where the server thinks the player's head
	-- is, with nothing solid between the head and that point.
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		reject(player, "not head or not head:IsA('BasePart')")
		return
	end
	if (origin - head.Position).Magnitude > Combat.ORIGIN_TOLERANCE then
		reject(player, "(origin - head.Position).Magnitude > Combat.ORIGIN_TOLERANCE")
		return
	end
	local exclude = wallExclusions(character)
	if blocked(exclude, head.Position, origin, "None") then
		reject(player, "blocked(exclude, head.Position, origin, 'None')")
		return
	end

	-- Accept the shot.
	state.shotIndex = shot
	if not slot.spinStart or now - slot.lastFire > FireRate.SPIN_RESET then
		slot.spinStart = now
	end
	slot.burstShots = FireRate.nextBurstCount(config, slot.burstShots, slot.lastFire, now)
	slot.lastFire = math.max(now, slot.lastFire + interval)
	if config.magSize > 0 then
		slot.ammo -= 1
	end

	-- Replicate the visuals to everyone else (cosmetic: clamp, don't trust).
	local ends: { Vector3 } = {}
	for _, e in readArray(p.ends, config.pellets) do
		local v = finiteVector(e)
		if v then
			local offset = v - origin
			if offset.Magnitude > config.range then
				v = origin + offset.Unit * config.range
			end
			table.insert(ends, v)
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.unreliable("ShotFx"):FireClient(other, player, config.id, origin, ends)
		end
	end

	-- Recompute exactly where each pellet was allowed to go. The seed comes
	-- from the server's sequence; the claimed spread can't go below the gun's
	-- best case (aimed, standing still) or above its worst case.
	local minSpread = config.hipSpread
		* config.adsSpreadMultiplier
		* (config.crouchSpreadMultiplier or 1)
	local maxSpread = config.hipSpread
		+ config.maxBloom
		+ Combat.MOVE_SPREAD.Air * (config.moveSpreadMultiplier or 1)
	local spread = math.clamp(spreadClaim, minSpread, maxSpread)
	local dirs = Spread.shot(
		aim,
		Spread.seedFor(state.seedBase, shot),
		config.pellets,
		spread,
		config.pelletSpread
	)

	-- Projectile guns: the server flies the disc itself; there are no client hit claims.
	if config.projectile then
		spawnProjectile(player, character, origin, dirs[1], config)
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local rewindAge = rewindWindow(player)
	local maxHits = math.min(
		Combat.MAX_HITS_PER_SHOT,
		config.pellets * (if config.pierceCharacters then 4 else 1)
	)
	local valid: { ValidHit } = {}
	local seen: { [Model]: { [number]: boolean } } = {}
	local pelletUsed: { [number]: boolean } = {}
	for _, raw in readArray(p.hits, maxHits) do
		if typeof(raw) ~= "table" then
			reject(player, "typeof(raw) ~= 'table'")
			continue
		end
		local h = raw :: { [string]: unknown }
		local part = h.part
		local position = finiteVector(h.position)
		local pellet = h.pellet
		if typeof(part) ~= "Instance" or not (part :: Instance):IsA("BasePart") or not position then
			reject(
				player,
				"typeof(part) ~= 'Instance' or not (part :: Instance):IsA('BasePart') or not position"
			)
			continue
		end
		if
			typeof(pellet) ~= "number"
			or pellet ~= math.floor(pellet)
			or pellet < 1
			or pellet > config.pellets
		then
			reject(player, "bad pellet index")
			continue
		end
		local hitPart = part :: BasePart
		local model = hitboxOwner(hitPart)
		if
			not model
			or model == character
			or not liveHumanoid(model)
			or not HitboxHistory.isTracked(model)
		then
			reject(player, "not a live tracked hitbox: " .. hitPart.Name)
			continue
		end

		-- One target per pellet (piercing guns: each target once per pellet).
		local seenForModel = seen[model]
		if
			(seenForModel and seenForModel[pellet])
			or (pelletUsed[pellet] and not config.pierceCharacters)
		then
			reject(player, "duplicate hit for this pellet")
			continue
		end

		if config.melee then
			-- In reach and roughly in front of the attacker.
			if not root or not root:IsA("BasePart") then
				reject(player, "not root or not root:IsA('BasePart')")
				continue
			end
			local toTarget = hitPart.Position - root.Position
			local reach = config.melee.range + Combat.MELEE_TOLERANCE + hitPart.Size.Magnitude / 2
			if toTarget.Magnitude > reach then
				reject(player, "toTarget.Magnitude > reach")
				continue
			end
			local flat = toTarget * Vector3.new(1, 0, 1)
			local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.5 and facing.Unit:Dot(flat.Unit) < Combat.MELEE_FACING_DOT then
				reject(
					player,
					"flat.Magnitude > 0.5 and facing.Unit:Dot(flat.Unit) < Combat.MELEE_FACING_DOT"
				)
				continue
			end
		else
			local offset = position - origin
			if offset.Magnitude > config.range + 5 then
				reject(player, "offset.Magnitude > config.range + 5")
				continue
			end
			-- The hit must lie on this pellet's server-computed ray.
			if
				offset.Magnitude > 1
				and Spread.angle(offset, dirs[pellet]) > Combat.DIRECTION_TOLERANCE
			then
				reject(
					player,
					string.format("off pellet ray by %.2f deg", Spread.angle(offset, dirs[pellet]))
				)
				continue
			end
		end

		-- The target really was there recently (rewound to the shooter's ping)...
		local isArm = string.find(hitPart.Name, "Arm") ~= nil
			or string.find(hitPart.Name, "Hand") ~= nil
		local tolerance = Combat.HIT_POSITION_TOLERANCE
			+ (if isArm then Combat.ARM_HIT_EXTRA_TOLERANCE else 0)
		local rewound = HitboxHistory.rewind(model, hitPart, position, tolerance, rewindAge)
		if not rewound then
			reject(player, "not rewound")
			continue
		end
		-- ...and nothing solid sits between the shooter and the hit point, or
		-- between the hit point and the actual body part.
		if blocked(exclude, origin, position, config.penetration) then
			reject(player, "blocked(exclude, origin, position, config.penetration)")
			continue
		end
		if blocked(exclude, position, rewound, config.penetration) then
			reject(player, "blocked(exclude, position, rewound, config.penetration)")
			continue
		end
		if not seenForModel then
			seenForModel = {}
			seen[model] = seenForModel
		end
		seenForModel[pellet] = true
		pelletUsed[pellet] = true
		table.insert(valid, { model = model, part = hitPart, rewound = rewound, pellet = pellet })
	end

	-- Sum damage per target (pellets), then apply once. Distance for falloff is
	-- measured by the server: head to the rewound body part.
	type Tally = { amount: number, zone: HitZone, position: Vector3 }
	local tally: { [Model]: Tally } = {}
	for _, hit in valid do
		local zone = Damage.zoneOf(hit.part.Name)
		local amount: number
		if config.melee then
			amount = config.damage.body
			local victimRoot = hit.model:FindFirstChild("HumanoidRootPart")
			if victimRoot and victimRoot:IsA("BasePart") and root and root:IsA("BasePart") then
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
			if config.beam then
				amount = beamTickDamage(slot, hit.model, now)
			else
				amount = Damage.compute(config, zone, (hit.rewound - head.Position).Magnitude)
			end
		end
		local t = tally[hit.model]
		if t then
			t.amount += amount
			if zone == "Head" then
				t.zone = "Head"
			end
		else
			tally[hit.model] = { amount = amount, zone = zone, position = hit.rewound }
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
	RunService.Heartbeat:Connect(stepProjectiles)
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
