--!strict
-- Server-authoritative weapons. Owns every player's loadout, ammo, reload and
-- fire timing, validates every shot the client reports, and applies damage.
--
-- Shot validation ladder (roblox-security): rate limit -> types -> ranges ->
-- weapon state (equipped, ammo, interval) -> origin near the server's
-- head -> per hit: real character, alive, not self, within range, inside the
-- gun's possible spread, on the target's recent hitbox, no wall in between.
-- Damage always comes from Config/Weapons on the server, never the client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Accuracy = require(Shared.Util.Accuracy)
local Combat = require(Shared.Config.Combat)
local Damage = require(Shared.Util.Damage)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local Spread = require(Shared.Util.Spread)
local TestMode = require(Shared.TestMode)
local Types = require(Shared.Types)
local Validate = require(Shared.Util.Validate)
local Weapons = require(Shared.Config.Weapons)

local HitboxHistory = require(script.Parent.HitboxHistory)
local ModEntities = require(script.Parent.ModEntities)

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
	burstShots: number,
	-- Spray heat after the last accepted shot (Util/Accuracy), as a band:
	-- cooled with each gap lengthened / shortened by Combat.FIRE_JITTER, so
	-- the client's own count (its gaps differ by network timing) stays inside.
	heatLow: number,
	heatHigh: number,
	lastShotAt: number, -- os.clock() of the last accepted shot
	altReadyAt: number, -- alt-fire's longer cooldown: no shot of either kind before this
	-- Shell-by-shell reloads (config shellReload): when it started and how
	-- many shells it set out to load; and no shot before `readyAt` after one
	-- is stopped (the gun's back in the hands).
	shellFrom: number?,
	shellNeeded: number,
	readyAt: number,
}

-- What the server's own simulation says a player was doing (sampled every
-- Heartbeat), for recomputing spread: Gunplay v2 movement penalty and ADS.
-- `aim` is the ADS blend the client also runs (0..1 over the gun's adsTime).
type MotionSample = {
	t: number,
	state: string,
	speed: number,
	aim: number,
	sinceLanding: number,
}

type MotionTrack = {
	samples: { MotionSample },
	aim: number,
	lastState: string,
	landedAt: number,
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
local seedRng = Random.new()

local WeaponService = {}

local states: { [Player]: PlayerState } = {}
local loadouts: { [Player]: { [Slot]: string } } = {}
local limiter = RateLimit.new(Combat.RATE)
local holsteredPlayers: { [Player]: boolean } = {}
local busyUntil: { [Player]: number } = {} -- os.clock(): no shots before this (a Mod use)
-- Overclock: fire interval divided by `mult` until `untilT` (os.clock()).
local fireBoost: { [Player]: { mult: number, untilT: number, token: number } } = {}
local BOOST_GRACE = 0.3 -- shots this late still get the boost (latency)
-- Ammo over the last few seconds, for Rollback (rewindAmmo).
type AmmoSnapshot = { t: number, ammo: { [Slot]: { id: string, ammo: number } } }
local ammoHistory: { [Player]: { AmmoSnapshot } } = {}
local AMMO_HISTORY = 4.5 -- seconds
local OBJECT_HIT_TOLERANCE = 0.5 -- studs outside a Mod object's box a hit may claim
local motion: { [Player]: MotionTrack } = {}

local WeaponsFolder: Instance? = nil

-- Listeners for accepted shots and applied damage (stats, later rounds).
-- They only observe: nothing they do feeds back into validation.
export type DamageEvent = {
	attacker: Player,
	victim: Model,
	damage: number,
	zone: HitZone,
	killed: boolean,
	weaponId: string,
	position: Vector3,
}
local shotListeners: { (player: Player, weaponId: string, hit: boolean) -> () } = {}
local damageListeners: { (event: DamageEvent) -> () } = {}

-- Helpers ------------------------------------------------------------------

local function allow(player: Player, key: string): boolean
	return limiter:allow(player, key)
end

local finiteVector = Validate.vector

-- Every equip plays the full draw; the server allows 70% of it for latency.
local function drawSeconds(config: WeaponConfig): number
	return config.drawTime or config.equipTime
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

-- Remembers the ammo in every slot now (Rollback gives it back later).
local function recordAmmo(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local ammo = {}
	for slot, s in state.slots do
		ammo[slot] = { id = s.id, ammo = s.ammo }
	end
	local list = ammoHistory[player]
	if not list then
		list = {}
		ammoHistory[player] = list
	end
	local now = os.clock()
	table.insert(list, { t = now, ammo = ammo })
	-- Keep one snapshot older than the window: the state at its start.
	while #list >= 2 and now - list[2].t > AMMO_HISTORY do
		table.remove(list, 1)
	end
end

local function sendState(player: Player)
	local state = states[player]
	if state then
		recordAmmo(player)
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
		heatLow = 0,
		heatHigh = 0,
		lastShotAt = -math.huge,
		altReadyAt = -math.huge,
		shellNeeded = 0,
		readyAt = -math.huge,
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
-- Akimbo guns hold a second model in the left hand ("WorldWeaponLeft").
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

-- Hides the third-person gun while a Mod is in the hand (ModService), and
-- keeps it hidden across a re-equip until shown again.
local worldHidden: { [Player]: boolean } = {}

local function applyWorldHidden(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hide = worldHidden[player] == true
	for _, name in { "WorldWeapon", "WorldWeaponLeft" } do
		local model = character:FindFirstChild(name)
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local base = d:GetAttribute("BaseTransparency")
					if base == nil then
						base = d.Transparency
						d:SetAttribute("BaseTransparency", base)
					end
					d.Transparency = if hide then 1 else base :: number
				end
			end
		end
	end
end

function WeaponService.setWorldWeaponHidden(player: Player, hidden: boolean)
	worldHidden[player] = if hidden then true else nil
	applyWorldHidden(player)
end

local function refreshWorldModel(player: Player)
	local state = states[player]
	local character = player.Character
	if not state or not character then
		return
	end
	local slot = state.equipped and state.slots[state.equipped]
	state.worldModel = WeaponService.attachWorldModel(character, slot and slot.id or nil)
	if worldHidden[player] then
		applyWorldHidden(player)
	end
	-- Read by the movement simulation (shared/Simulation/Movement).
	player:SetAttribute("MoveMult", if slot then slot.config.moveMultiplier else 1)
	player:SetAttribute("AdsMult", if slot then slot.config.adsMoveMultiplier else 1)
end

-- Loadout --------------------------------------------------------------------

function WeaponService.getLoadout(player: Player): { [Slot]: string }
	local l = loadouts[player]
	if not l then
		l = table.clone(Weapons.DEFAULT_LOADOUT)
		loadouts[player] = l
	end
	return l
end

-- Gives the player a fresh set of weapons (full ammo) and equips the primary.
function WeaponService.giveLoadout(player: Player)
	-- A new life: Rollback can't reach back into the last one's ammo, and
	-- Overclock doesn't carry over.
	ammoHistory[player] = nil
	fireBoost[player] = nil
	player:SetAttribute("FireRateMult", nil)
	local loadout = WeaponService.getLoadout(player)
	local slots: { [Slot]: SlotState } = {}
	for _, slot in SLOTS do
		local id = loadout[slot]
		local s = if id then newSlot(id) else nil
		if s then
			slots[slot] = s
		end
	end
	local first: Slot? = if slots.Primary
		then "Primary"
		elseif slots.Secondary then "Secondary"
		elseif slots.Melee then "Melee"
		else nil
	local old = states[player]
	states[player] = {
		slots = slots,
		equipped = first,
		equipReadyAt = os.clock() + (if first then drawSeconds(slots[first].config) * 0.7 else 0),
		-- Keep the seed sequence across respawns so in-flight shots stay valid.
		seedBase = if old then old.seedBase else seedRng:NextInteger(1, 2 ^ 30),
		shotIndex = if old then old.shotIndex else 0,
	}
	refreshWorldModel(player)
	sendState(player)
end

-- Swaps one slot's weapon (used by the draft later).
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
		state.equipReadyAt = os.clock() + drawSeconds(config) * 0.7
		refreshWorldModel(player)
	end
	sendState(player)
end

-- Damage ---------------------------------------------------------------------

-- `sourceId`: the gun's id, or a Mod's id for Mod damage (WeaponService.damage).
local function applyDamage(
	attacker: Player,
	victimModel: Model,
	amount: number,
	zone: HitZone,
	sourceId: string,
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
	if #damageListeners > 0 then
		local event: DamageEvent = {
			attacker = attacker,
			victim = victimModel,
			damage = dealt,
			zone = zone,
			killed = killed,
			weaponId = sourceId,
			position = at,
		}
		for _, fn in damageListeners do
			task.spawn(fn, event)
		end
	end

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
		Net.event("Killed"):FireAllClients(victimModel, attacker, sourceId, zone == "Head")
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

-- Damage from a Mod (ModService), through the same path as gun damage: kill
-- feed, hit confirm, damage direction, LastAttacker, listeners. The amount is
-- computed by the server's Mod code, never by a client.
function WeaponService.damage(
	attacker: Player,
	victim: Model,
	amount: number,
	sourceId: string,
	at: Vector3
)
	if amount ~= amount or amount <= 0 then
		return
	end
	applyDamage(attacker, victim, amount, "Body", sourceId, at)
end

-- Heals a combatant (no natural regen: heals only come from Mods). Returns
-- the health actually added.
function WeaponService.heal(target: Model, amount: number): number
	local humanoid = liveHumanoid(target)
	if not humanoid or amount ~= amount or amount <= 0 then
		return 0
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + amount)
	return humanoid.Health - before
end

-- While a held Mod is up the gun is lowered: no shots are accepted
-- (ModService). Lowering it ends with `busyFor` more seconds without shots
-- (the throw / heal animation after a use).
function WeaponService.setHolstered(player: Player, holstered: boolean, busyFor: number?)
	if holstered then
		holsteredPlayers[player] = true
	else
		holsteredPlayers[player] = nil
		if busyFor and busyFor > 0 then
			busyUntil[player] = os.clock() + busyFor
		end
	end
end

-- Overclock: the player's guns fire `mult` times as fast for `duration`
-- seconds. Clients read the FireRateMult player attribute (Util/FireRate).
function WeaponService.setFireRate(player: Player, mult: number, duration: number)
	if mult ~= mult or duration ~= duration then
		return
	end
	mult = math.clamp(mult, 1, 3)
	local old = fireBoost[player]
	local token = (if old then old.token else 0) + 1
	fireBoost[player] = { mult = mult, untilT = os.clock() + duration, token = token }
	player:SetAttribute("FireRateMult", mult)
	task.delay(duration, function()
		local b = fireBoost[player]
		if b and b.token == token then
			player:SetAttribute("FireRateMult", nil)
		end
	end)
end

local function rateMult(player: Player): number
	local b = fireBoost[player]
	if b and os.clock() < b.untilT + BOOST_GRACE then
		return b.mult
	end
	return 1
end

-- Rollback: every slot gets back the ammo it had `age` seconds ago (a reload
-- in progress is cancelled). Slots whose gun changed since keep theirs.
function WeaponService.rewindAmmo(player: Player, age: number)
	local state = states[player]
	local list = ammoHistory[player]
	if not state or not list or #list == 0 or age ~= age then
		return
	end
	local target = os.clock() - age
	local pick = list[1]
	for i = #list, 1, -1 do
		if list[i].t <= target then
			pick = list[i]
			break
		end
	end
	for slot, s in state.slots do
		local old = pick.ammo[slot]
		if old and old.id == s.id then
			s.ammo = math.clamp(old.ammo, 0, s.config.magSize)
			s.reloadToken += 1
			s.reloadEnd = nil
			s.shellFrom = nil
		end
	end
	sendState(player)
end

local function holstered(player: Player): boolean
	local busy = busyUntil[player]
	return holsteredPlayers[player] == true
		or (busy ~= nil and os.clock() < busy - Combat.FIRE_JITTER)
end

local function notifyShot(player: Player, config: WeaponConfig, hit: boolean)
	for _, fn in shotListeners do
		task.spawn(fn, player, config.id, hit)
	end
end

function WeaponService.onShot(fn: (player: Player, weaponId: string, hit: boolean) -> ())
	table.insert(shotListeners, fn)
end

function WeaponService.onDamage(fn: (event: DamageEvent) -> ())
	table.insert(damageListeners, fn)
end

-- Shells a shell-by-shell reload has loaded by `now` (credited RELOAD_LEAD
-- early, like a normal reload, so the server is never behind the client).
local function shellsLoaded(slot: SlotState, now: number): number
	local reload = slot.config.shellReload
	local from = slot.shellFrom
	if not reload or not from then
		return 0
	end
	local t = now + Combat.RELOAD_LEAD - from - reload.start
	return math.clamp(math.floor(t / reload.insert), 0, slot.shellNeeded)
end

-- Ends a shell-by-shell reload in progress, keeping the shells loaded so far.
local function settleShellReload(slot: SlotState, now: number)
	if slot.shellFrom and slot.reloadEnd then
		slot.ammo = math.min(slot.ammo + shellsLoaded(slot, now), slot.config.magSize)
	end
	slot.shellFrom = nil
	slot.reloadToken += 1
	slot.reloadEnd = nil
end

-- Equips one of the player's slots (the Equip remote, and server-side picks).
function WeaponService.equip(player: Player, slot: Slot)
	local state = states[player]
	if not state or not liveHumanoid(player.Character) then
		return
	end
	local target = state.slots[slot]
	if not target or state.equipped == slot then
		return
	end
	-- Swapping cancels a reload in progress (a shell-by-shell one keeps the
	-- shells it loaded).
	local current = state.equipped and state.slots[state.equipped]
	if current then
		settleShellReload(current, os.clock())
	end
	state.equipped = slot
	state.equipReadyAt = os.clock() + drawSeconds(target.config) * 0.7
	refreshWorldModel(player)
	sendState(player)
end

-- Fills every magazine, cancelling a reload in progress.
function WeaponService.refill(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, s in state.slots do
		s.reloadToken += 1
		s.reloadEnd = nil
		s.shellFrom = nil
		s.readyAt = -math.huge
		s.ammo = s.config.magSize
	end
	sendState(player)
end

-- Remote handlers --------------------------------------------------------------

local function onEquip(player: Player, slot: unknown)
	if not allow(player, "Equip") then
		return
	end
	if not isSlot(slot) then
		return
	end
	WeaponService.equip(player, slot :: Slot)
end

-- `action`: nil starts a reload; "stop" ends a shell-by-shell one early
-- (the player fired), keeping the shells loaded so far.
local function onReload(player: Player, action: unknown)
	if not allow(player, "Reload") then
		return
	end
	local state = states[player]
	local slot = state and state.equipped and state.slots[state.equipped]
	if not state or not slot or not liveHumanoid(player.Character) then
		return
	end
	local config = slot.config
	local now = os.clock()
	if action == nil and holsteredPlayers[player] then
		return -- no reloads with a Mod in hand (the client doesn't start one)
	end
	if action == "stop" then
		local shell = config.shellReload
		if shell and slot.shellFrom and slot.reloadEnd then
			settleShellReload(slot, now)
			-- The gun comes back to the hands before it can fire.
			slot.readyAt = now + shell.finish - Combat.FIRE_JITTER
			sendState(player)
		end
		return
	end
	if action ~= nil then
		return
	end
	if config.magSize <= 0 or slot.ammo >= config.magSize or slot.reloadEnd then
		return
	end
	local shell = config.shellReload
	local duration: number
	if shell then
		slot.shellNeeded = config.magSize - slot.ammo
		slot.shellFrom = now
		duration = shell.start + shell.insert * slot.shellNeeded + shell.finish
	else
		duration = if slot.ammo == 0 then config.emptyReloadTime else config.reloadTime
	end
	slot.reloadToken += 1
	local token = slot.reloadToken
	-- Accept the client's reload a little early to hide latency.
	slot.reloadEnd = now + duration - Combat.RELOAD_LEAD
	task.delay(duration - Combat.RELOAD_LEAD, function()
		if slot.reloadToken == token and states[player] == state then
			slot.ammo = config.magSize
			slot.reloadEnd = nil
			slot.shellFrom = nil
			sendState(player)
		end
	end)
end

-- Studio and test-mode servers only: put any installed gun in its slot and
-- equip it (the weapon picker). Validates the id against the config and the
-- installed models; nothing else comes from the client.
local MAX_ID_LENGTH = 32

local function onPickWeapon(player: Player, id: unknown)
	if not allow(player, "PickWeapon") then
		return
	end
	if not RunService:IsStudio() and not TestMode.isOn() then
		return
	end
	if typeof(id) ~= "string" or #id == 0 or #id > MAX_ID_LENGTH then
		return
	end
	local config = Weapons.get(id :: string)
	if not config or not weaponTemplate(config.id) then
		return
	end
	if not liveHumanoid(player.Character) then
		return
	end
	-- Already in that slot: just switch to it (a fresh copy would be a free
	-- reload and skip its cooldowns).
	local state = states[player]
	local current = state and state.slots[config.slot]
	if not current or current.id ~= config.id then
		WeaponService.setWeapon(player, config.slot, config.id)
	end
	WeaponService.equip(player, config.slot)
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

-- Motion history --------------------------------------------------------------

local function aimHeld(player: Player): boolean
	local context = player:FindFirstChild("PlayContext")
	local action = context and context:FindFirstChild("Aim")
	return action ~= nil and action:IsA("InputAction") and action:GetState() == true
end

local function equippedConfig(player: Player): WeaponConfig?
	local state = states[player]
	local slot = state and state.equipped and state.slots[state.equipped]
	return slot and slot.config
end

local function sampleMotion(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			continue
		end
		local track = motion[player]
		if not track then
			track = { samples = {}, aim = 0, lastState = "Idle", landedAt = -math.huge }
			motion[player] = track
		end
		local state = (character:GetAttribute("MoveState") :: string?) or "Idle"
		-- Landings, on the server's own clock (the client spots its own).
		if track.lastState == "Air" and state ~= "Air" then
			track.landedAt = now
		end
		track.lastState = state
		-- The same ADS blend the client runs (WeaponController): toward 1 while
		-- the Aim input is held, at 1 / adsTime per second.
		local config = equippedConfig(player)
		local canAim = config ~= nil and config.fireMode ~= "Melee" and not config.noAds
		local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
		local held = canAim and aimHeld(player) and state ~= "Sprint"
		track.aim = math.clamp(track.aim + (if held then rate else -rate) * dt, 0, 1)
		local list = track.samples
		table.insert(list, {
			t = now,
			state = state,
			speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
			aim = track.aim,
			sinceLanding = now - track.landedAt,
		})
		while #list > 0 and now - list[1].t > Combat.MOTION_HISTORY do
			table.remove(list, 1)
		end
	end
end

-- The spread a shot is allowed to have, from the server's own state: the
-- gun's spray heat band (from accepted shot times, plus SPREAD_HEAT_SLACK
-- shots) and what the player was doing around when they fired: samples from
-- `ping` + FIRE_TIME_SLACK ago up to now. The high edge also allows a jump the
-- server hasn't simulated yet (high edges only ever cost the shooter).
-- Returns the lowest and highest cone, and whether a centre-biased shot is
-- allowed (only when the server saw the shooter standing at fire time).
local function spreadBand(
	player: Player,
	config: WeaponConfig,
	heatLow: number,
	heatHigh: number,
	ping: number
): (number, number, boolean)
	local now = os.clock()
	local track = motion[player]
	local samples = if track then track.samples else {}
	local fireTime = now - ping
	local recent: { MotionSample } = {}
	local closest: MotionSample? = nil
	for _, s in samples do
		if s.t >= fireTime - Combat.FIRE_TIME_SLACK then
			table.insert(recent, s)
		end
		if not closest or math.abs(s.t - fireTime) < math.abs(closest.t - fireTime) then
			closest = s
		end
	end
	local latest = samples[#samples]
	if #recent == 0 and latest then
		table.insert(recent, latest)
	end
	if #recent == 0 then
		-- No samples yet (just spawned): anything from standing aimed to airborne.
		table.insert(
			recent,
			{ t = now, state = "Idle", speed = 0, aim = 1, sinceLanding = math.huge }
		)
		table.insert(recent, { t = now, state = "Air", speed = 0, aim = 0, sinceLanding = 0 })
	end
	local aimLow, aimHigh = 0, 1
	local anyCrouch, allCrouch = false, true
	for _, s in recent do
		aimLow = math.max(aimLow, s.aim)
		aimHigh = math.min(aimHigh, s.aim)
		anyCrouch = anyCrouch or s.state == "Crouch"
		allCrouch = allCrouch and s.state == "Crouch"
	end
	local moveLow, moveHigh = math.huge, 0
	for _, s in recent do
		local m: Accuracy.Motion =
			{ state = s.state, speed = s.speed, aim = aimLow, sinceLanding = s.sinceLanding }
		moveLow = math.min(moveLow, Accuracy.movement(config, m))
		m.aim = aimHigh
		moveHigh = math.max(moveHigh, Accuracy.movement(config, m))
	end
	if latest and latest.state ~= "Air" then
		local jump: Accuracy.Motion =
			{ state = "Air", speed = latest.speed, aim = aimHigh, sinceLanding = math.huge }
		moveHigh = math.max(moveHigh, Accuracy.movement(config, jump))
	end
	-- The gun's spread is monotonic in heat but may fall as it heats (Ares),
	-- so take both heat edges each way.
	local slack = Combat.SPREAD_HEAT_SLACK
	local coolHeat, hotHeat = heatLow - slack, heatHigh + slack
	local low = math.min(
		Accuracy.gun(config, coolHeat, aimLow, anyCrouch),
		Accuracy.gun(config, hotHeat, aimLow, anyCrouch)
	) + moveLow
	local high = math.max(
		Accuracy.gun(config, coolHeat, aimHigh, allCrouch),
		Accuracy.gun(config, hotHeat, aimHigh, allCrouch)
	) + moveHigh
	local standing = moveLow <= 0
		and closest ~= nil
		and Accuracy.movement(config, {
				state = closest.state,
				speed = closest.speed,
				aim = closest.aim,
				sinceLanding = closest.sinceLanding,
			})
			<= 0
	return low, high, standing
end

local function networkPing(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	return if ok and typeof(ping) == "number" and ping == ping then math.clamp(ping, 0, 1) else 0.1
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
	if holstered(player) then
		reject(player, "holding a Mod")
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
	if now < slot.readyAt then
		reject(player, "a stopped shell reload is still finishing")
		return
	end
	if config.magSize > 0 and slot.ammo < 1 then
		reject(player, "out of ammo")
		return
	end
	-- Alt-fire (guns with no ADS, e.g. the Classic's 3-pellet burst): its own
	-- pellets, cone and ammo cost, and a longer cooldown before the next shot.
	local altFire = if p.alt == true and config.noAds then config.altFire else nil
	-- An alt shot fires one pellet per round it uses, so a nearly empty mag
	-- fires fewer.
	local altRounds = if altFire
		then (if config.magSize > 0 then math.min(altFire.ammo, slot.ammo) else altFire.ammo)
		else 1
	local pellets = if altFire
		then math.max(1, math.floor(altFire.pellets * altRounds / altFire.ammo))
		else config.pellets
	local pelletSpread = if altFire then altFire.pelletSpread else config.pelletSpread
	local interval = FireRate.interval(config, slot.spinStart, slot.lastFire, now, slot.burstShots)
		/ rateMult(player)
	if now < slot.lastFire + interval - Combat.FIRE_JITTER then
		reject(player, "now < slot.lastFire + interval - Combat.FIRE_JITTER")
		return
	end
	if now < slot.altReadyAt - Combat.FIRE_JITTER then
		reject(player, "alt-fire cooldown")
		return
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

	-- Spray heat before this shot (cools while the trigger is off).
	local gap = now - slot.lastShotAt
	local heatLow = Accuracy.cool(config, slot.heatLow, gap + Combat.FIRE_JITTER)
	local heatHigh = Accuracy.cool(config, slot.heatHigh, math.max(gap - Combat.FIRE_JITTER, 0))

	-- Accept the shot.
	state.shotIndex = shot
	slot.heatLow = heatLow + altRounds
	slot.heatHigh = heatHigh + altRounds
	slot.lastShotAt = now
	if not slot.spinStart or now - slot.lastFire > FireRate.SPIN_RESET then
		slot.spinStart = now
	end
	slot.burstShots = FireRate.nextBurstCount(config, slot.burstShots, slot.lastFire, now)
	slot.lastFire = math.max(now, slot.lastFire + interval)
	if config.magSize > 0 then
		slot.ammo -= altRounds
	end
	if altFire then
		slot.altReadyAt = now + altFire.fireInterval
	end
	recordAmmo(player)

	-- Replicate the visuals to everyone else (cosmetic: clamp, don't trust).
	local ends: { Vector3 } = {}
	for _, e in readArray(p.ends, pellets) do
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
	-- from the server's sequence, and the cone from the server's own state
	-- (spreadBand): a claimed cone outside that band is clamped into it, so
	-- a client that lies about its spread gets rays its hits won't match.
	local rewindAge = rewindWindow(player)
	local low, high, mayCentre = spreadBand(player, config, heatLow, heatHigh, networkPing(player))
	local spread = math.clamp(spreadClaim, low, high)
	if RunService:IsStudio() then
		-- Tuning aid: what the client claimed and the band the server allowed.
		player:SetAttribute(
			"FireSpread",
			string.format("%.3f [%.3f, %.3f]", spreadClaim, low, high)
		)
	end
	-- Centre bias only when the server also saw the shooter standing (an even
	-- spread is always allowed: it only makes the shot less accurate).
	local centred = p.centred == true and mayCentre
	local dirs = Spread.shot(
		aim,
		Spread.seedFor(state.seedBase, shot),
		pellets,
		spread,
		pelletSpread,
		centred
	)

	local root = character:FindFirstChild("HumanoidRootPart")
	local maxHits =
		math.min(Combat.MAX_HITS_PER_SHOT, pellets * (if config.pierceCharacters then 4 else 1))
	local valid: { ValidHit } = {}
	local objectHits: { { part: BasePart, position: Vector3 } } = {}
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
			or pellet > pellets
		then
			reject(player, "bad pellet index")
			continue
		end
		local hitPart = part :: BasePart
		-- A Mod object (Firewall, Launch Pad): the pellet stops on it and
		-- takes its HP. Same ray, range and wall checks as a body hit.
		if ModEntities.isObject(hitPart) then
			local offset = position - origin
			local rel = hitPart.CFrame:PointToObjectSpace(position)
			-- Objects don't move: a tight box (not the bodies' latency allowance).
			local half = hitPart.Size / 2 + Vector3.one * OBJECT_HIT_TOLERANCE
			if
				config.melee
				or pelletUsed[pellet]
				or offset.Magnitude > config.range + 5
				or (offset.Magnitude > 1 and Spread.angle(offset, dirs[pellet]) > Combat.DIRECTION_TOLERANCE)
				or math.abs(rel.X) > half.X
				or math.abs(rel.Y) > half.Y
				or math.abs(rel.Z) > half.Z
				or blocked(exclude, origin, position, config.penetration)
			then
				reject(player, "bad Mod object hit")
			else
				pelletUsed[pellet] = true
				table.insert(objectHits, { part = hitPart, position = position })
			end
			continue
		end
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
			local heavy = if altFire then config.melee.heavy else nil
			amount = if heavy then heavy.damage else config.damage.body
			local victimRoot = hit.model:FindFirstChild("HumanoidRootPart")
			if victimRoot and victimRoot:IsA("BasePart") and root and root:IsA("BasePart") then
				local toVictim = (victimRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				if toVictim.Magnitude > 0.01 then
					local facing = victimRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
					if facing.Unit:Dot(toVictim.Unit) > Combat.BACKSTAB_DOT then
						amount = if heavy then heavy.backDamage else config.melee.backDamage
					end
				end
			end
			zone = "Body"
		else
			amount = Damage.compute(config, zone, (hit.rewound - head.Position).Magnitude)
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
		applyDamage(player, model, t.amount, t.zone, config.id, t.position)
	end
	-- Mod objects: pellets summed per object, falloff by the server's distance.
	local objectTally: { [BasePart]: { amount: number, position: Vector3 } } = {}
	for _, hit in objectHits do
		local amount = Damage.compute(config, "Body", (hit.position - head.Position).Magnitude)
		local t = objectTally[hit.part]
		if t then
			t.amount += amount
		else
			objectTally[hit.part] = { amount = amount, position = hit.position }
		end
	end
	for part, t in objectTally do
		local dealt = ModEntities.damage(part, t.amount, player)
		if dealt > 0 then
			Net.event("HitConfirm"):FireClient(player, {
				damage = math.round(dealt),
				zone = "Body",
				killed = false,
				position = t.position,
			})
		end
	end
	notifyShot(player, config, next(tally) ~= nil)
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
			fireBoost[player] = nil
			player:SetAttribute("FireRateMult", nil)
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
	-- A shell reload's start must outlast RELOAD_LEAD, or stopping and
	-- restarting it over and over would load faster than letting it run.
	for id, config in Weapons.list do
		local shell = config.shellReload
		assert(
			not shell or shell.start > Combat.RELOAD_LEAD,
			id .. ": shellReload.start must be longer than Combat.RELOAD_LEAD"
		)
	end
	Net.event("Equip").OnServerEvent:Connect(onEquip)
	Net.event("Fire").OnServerEvent:Connect(onFire)
	Net.event("Reload").OnServerEvent:Connect(onReload)
	Net.event("PickWeapon").OnServerEvent:Connect(onPickWeapon)
	Net.unreliable("Aim").OnServerEvent:Connect(onAim)
end

function WeaponService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	RunService.Heartbeat:Connect(sampleMotion)
	Players.PlayerRemoving:Connect(function(player)
		motion[player] = nil
		states[player] = nil
		loadouts[player] = nil
		limiter:forget(player)
		holsteredPlayers[player] = nil
		busyUntil[player] = nil
		fireBoost[player] = nil
		ammoHistory[player] = nil
		worldHidden[player] = nil
	end)
end

return WeaponService
