--!strict
-- Server-authoritative weapons. Owns every player's loadout, ammo, reload and
-- fire timing, validates every shot the client reports, and applies damage.
--
-- Shot validation ladder (roblox-security): rate limit -> types -> ranges ->
-- weapon state (equipped, ammo, interval) -> origin near the server's
-- head -> per hit: real character, alive, not self, within range, inside the
-- gun's possible spread, on the target's recent hitbox, no wall in between.
-- Damage always comes from Config/Weapons on the server, never the client.
--
-- This module owns the weapon state and the remotes; the pieces live in the
-- plain modules under Services/Weapon (no init/start; the server only boots
-- the ModuleScripts directly in Services):
--   Weapon/Hits        per-hit validation, lag compensation, shot damage
--   Weapon/Motion      motion history: the server's spread band, Dash gate
--   Weapon/Damage      the damage path (guards, shield, health, feedback)
--   Weapon/Targets     live combatants, hitboxes, the wall check
--   Weapon/WorldModel  the third-person gun

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Accuracy = require(Shared.Util.Accuracy)
local Combat = require(Shared.Config.Combat)
local MatchState = require(Shared.MatchState)
local Status = require(Shared.Mods.Status)
local StatusEffects = require(Shared.Config.StatusEffects)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local Spread = require(Shared.Util.Spread)
local TestMode = require(Shared.TestMode)
local Types = require(Shared.Types)
local Validate = require(Shared.Util.Validate)
local Weapons = require(Shared.Config.Weapons)

local StatusService = require(script.Parent.StatusService)
local Health = require(ReplicatedStorage.Shared.Health)

local Weapon = script.Parent.Weapon
local WeaponDamage = require(Weapon.Damage)
local Hits = require(Weapon.Hits)
local Motion = require(Weapon.Motion)
local Targets = require(Weapon.Targets)
local WorldModel = require(Weapon.WorldModel)

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig

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
	shellSlow: number, -- each shell phase takes this × its time (a status at the start)
	readyAt: number,
	meleeStep: number?, -- the knife's light-slash chain (1-3), for what others see
}

type PlayerState = {
	slots: { [Slot]: SlotState },
	equipped: Slot?,
	equipReadyAt: number,
	worldModel: Model?,
	seedBase: number, -- server-issued: spread seeds can't be chosen by the client
	shotIndex: number, -- last accepted shot counter
	resync: boolean?, -- the next state sent sets the client's counter to ours
}

local SLOTS: { Slot } = { "Primary", "Secondary", "Melee" }
local seedRng = Random.new()

local WeaponService = {}

local states: { [Player]: PlayerState } = {}
local loadouts: { [Player]: { [Slot]: string } } = {}
local limiter = RateLimit.new(Combat.RATE)
local holsteredPlayers: { [Player]: boolean } = {}
local busyUntil: { [Player]: number } = {} -- os.clock(): no shots before this (a Mod use)
-- A Mod's fire-rate boost (setFireRate): fire interval divided by `mult`
-- until `untilT` (os.clock()).
local fireBoost: { [Player]: { mult: number, untilT: number, token: number } } = {}

-- Listeners for accepted shots (stats). They only observe: nothing they do
-- feeds back into validation.
local shotListeners: { (player: Player, weaponId: string, hit: boolean) -> () } = {}

-- Helpers ------------------------------------------------------------------

local function allow(player: Player, key: string): boolean
	return limiter:allow(player, key)
end

local finiteVector = Validate.vector

-- Every equip plays the full draw; the server allows 70% of it for latency.
-- A status effect's multiplier on `field` for `player` (Mods/Status), the
-- most lenient one the client could be using (StatusEffects.GRACE).
local function statusMult(player: Player, field: "fireRate" | "reload" | "equip"): number
	local character = player.Character
	return Status.lenient(
		character,
		workspace:GetServerTimeNow(),
		StatusEffects.GRACE,
		StatusService.startedAt(character),
		field
	)
end

-- A stun (Frozen) that started more than StatusEffects.GRACE ago: no shots
-- (a shot fired just before the client saw it still counts).
local function stunned(player: Player): boolean
	local character = player.Character
	local now = workspace:GetServerTimeNow()
	if not Status.stunned(character, now) then
		return false
	end
	local started = StatusService.startedAt(character)
	for name, effect in StatusEffects.effects do
		if effect.stun and Status.active(character, name, now) then
			local at = started and started[name]
			if not at or now - at >= StatusEffects.GRACE then
				return true
			end
		end
	end
	return false
end

local function drawSeconds(config: WeaponConfig): number
	return config.drawTime or config.equipTime
end

local function isSlot(v: unknown): boolean
	return v == "Primary" or v == "Secondary" or v == "Melee"
end

local liveHumanoid = Targets.liveHumanoid
local reject = Hits.reject

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
		resync = state.resync,
	}
end

local function sendState(player: Player)
	local state = states[player]
	if state then
		Net.event("WeaponState"):FireClient(player, snapshot(state))
		state.resync = nil -- once only: later states must not move a counter in use
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
		shellSlow = 1,
		readyAt = -math.huge,
	}
end

-- World model (what other players see; Weapon/WorldModel) --------------------

-- Puts weapon `id` in the character's hand(s) (or removes it with nil).
-- Akimbo guns hold a second model in the left hand ("WorldWeaponLeft").
WeaponService.attachWorldModel = WorldModel.attach

-- Hides the third-person gun while a Mod is in the hand (ModService), and
-- keeps it hidden across a re-equip until shown again.
WeaponService.setWorldWeaponHidden = WorldModel.setHidden

local function refreshWorldModel(player: Player)
	local state = states[player]
	local character = player.Character
	if not state or not character then
		return
	end
	local slot = state.equipped and state.slots[state.equipped]
	state.worldModel = WorldModel.attach(character, slot and slot.id or nil)
	WorldModel.reapplyHidden(player)
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
	-- A new life: a fire-rate boost doesn't carry over.
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
		equipReadyAt = os.clock() + (if first
			then drawSeconds(slots[first].config) * 0.7 / statusMult(player, "equip")
			else 0),
		-- Keep the seed sequence across respawns so in-flight shots stay valid.
		seedBase = if old then old.seedBase else seedRng:NextInteger(1, 2 ^ 30),
		shotIndex = if old then old.shotIndex else 0,
		-- Shots refused at the end of the last life (locked, dead) moved the
		-- client's counter but not ours: without this it could stay out of reach
		-- of MAX_SHOT_SKIP and every shot after it would be refused.
		resync = true,
	}
	refreshWorldModel(player)
	sendState(player)
end

-- The match's loadout for the player (MatchService): what the next
-- giveLoadout hands out, with empty slots left empty.
function WeaponService.setMatchLoadout(player: Player, loadout: { [Slot]: string })
	loadouts[player] = loadout
end

-- Swaps one slot's weapon.
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
		state.equipReadyAt = os.clock() + drawSeconds(config) * 0.7 / statusMult(player, "equip")
		refreshWorldModel(player)
	end
	sendState(player)
end

-- Damage (Weapon/Damage) ---------------------------------------------------

-- A Mod's damage guard: sees every hit on a combatant and returns the amount
-- to deal (0 blocks it: a Barrier, a Ghost dash, Crash Recovery).
WeaponService.addDamageGuard = WeaponDamage.addDamageGuard

-- A Mod's damage modifier: player-on-player damage (guns and Mods) before
-- the guards (Ping Spike's bonus on revealed enemies).
WeaponService.addDamageModifier = WeaponDamage.addDamageModifier

-- All damage goes through here: the guards, then shield first, then health.
-- Returns what it took (0 when a guard blocked it). `attacker`: the player
-- behind it, if any.
WeaponService.hurt = WeaponDamage.hurt

-- Damage from a Mod (ModService), through the same path as gun damage: kill
-- feed, hit confirm, damage direction, LastAttacker, listeners. The amount is
-- computed by the server's Mod code, never by a client.
WeaponService.damage = WeaponDamage.damage

-- AI bots (Services/BotService): damage from a bot's gun or Mod, the same
-- path minus what needs a Player attacker. Returns what it took.
WeaponService.damageBy = WeaponDamage.damageBy

-- Heals a combatant (no natural regen: heals only come from Mods). Returns
-- the health actually added.
WeaponService.heal = WeaponDamage.heal

-- Every hit by a player or a bot (match stats).
WeaponService.onHit = WeaponDamage.onHit

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

-- A Mod's fire-rate boost (the Mod API's `fireRate`): the player's guns fire
-- `mult` times as fast for `duration` seconds. Clients read the FireRateMult
-- player attribute (Util/FireRate).
function WeaponService.setFireRate(player: Player, mult: number, duration: number)
	if mult ~= mult or duration ~= duration then
		return
	end
	mult = math.clamp(mult, Combat.FIRE_BOOST_MIN, Combat.FIRE_BOOST_MAX)
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
	if b and os.clock() < b.untilT + Combat.FIRE_BOOST_GRACE then
		return b.mult
	end
	return 1
end

local function holstered(player: Player): boolean
	local busy = busyUntil[player]
	return holsteredPlayers[player] == true
		or player:GetAttribute(MatchState.COMBAT_LOCKED) == true
		or (busy ~= nil and os.clock() < busy - Combat.FIRE_JITTER)
		or stunned(player)
end

local function notifyShot(player: Player, config: WeaponConfig, hit: boolean)
	for _, fn in shotListeners do
		task.spawn(fn, player, config.id, hit)
	end
end

function WeaponService.onShot(fn: (player: Player, weaponId: string, hit: boolean) -> ())
	table.insert(shotListeners, fn)
end

-- Shells a shell-by-shell reload has loaded by `now` (credited RELOAD_LEAD
-- early, like a normal reload, so the server is never behind the client).
local function shellsLoaded(slot: SlotState, now: number): number
	local reload = slot.config.shellReload
	local from = slot.shellFrom
	if not reload or not from then
		return 0
	end
	local t = now + Combat.RELOAD_LEAD - from - reload.start * slot.shellSlow
	return math.clamp(math.floor(t / (reload.insert * slot.shellSlow)), 0, slot.shellNeeded)
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
	state.equipReadyAt = os.clock() + drawSeconds(target.config) * 0.7 / statusMult(player, "equip")
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

-- lihfolk-ignore: remote-unvalidated-args (slot is checked with isSlot below)
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
-- lihfolk-ignore: remote-unvalidated-args (action must be nil or "stop", below)
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
	if action == nil and Status.stunned(player.Character, workspace:GetServerTimeNow()) then
		return -- or frozen (the client drops its reload when it sees the freeze)
	end
	if action == "stop" then
		local shell = config.shellReload
		if shell and slot.shellFrom and slot.reloadEnd then
			settleShellReload(slot, now)
			-- The gun comes back to the hands before it can fire.
			slot.readyAt = now + shell.finish * slot.shellSlow - Combat.FIRE_JITTER
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
	-- A status (Hinder) slows reloads; the most lenient view of it (one that
	-- only just started doesn't count yet: the client may not have seen it).
	local slow = 1 / statusMult(player, "reload")
	local duration: number
	if shell then
		slot.shellNeeded = config.magSize - slot.ammo
		slot.shellFrom = now
		slot.shellSlow = slow
		duration = (shell.start + shell.insert * slot.shellNeeded + shell.finish) * slow
	else
		duration = (if slot.ammo == 0 then config.emptyReloadTime else config.reloadTime) * slow
	end
	slot.reloadToken += 1
	local token = slot.reloadToken
	-- Others see the reload (Simulation/Poses plays it at this length).
	player:SetAttribute("ReloadFor", duration)
	player:SetAttribute("ReloadAt", workspace:GetServerTimeNow())
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
	if not config or not WorldModel.template(config.id) then
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

-- The equipped gun's config (Weapon/Motion's ADS blend).
local function equippedConfig(player: Player): WeaponConfig?
	local state = states[player]
	local slot = state and state.equipped and state.slots[state.equipped]
	return slot and slot.config
end

-- Shots -------------------------------------------------------------------------

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
	if Motion.dashBlocked(player) then
		reject(player, "dashing")
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
		/ (rateMult(player) * statusMult(player, "fireRate"))
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
	local exclude = Targets.wallExclusions(character)
	if Targets.blocked(exclude, head.Position, origin, "None") then
		reject(player, "blocked(exclude, head.Position, origin, 'None')")
		return
	end

	-- Spray heat before this shot (cools while the trigger is off).
	local gap = now - slot.lastShotAt
	local heatLow = Accuracy.cool(config, slot.heatLow, gap + Combat.FIRE_JITTER)
	local heatHigh = Accuracy.cool(config, slot.heatHigh, math.max(gap - Combat.FIRE_JITTER, 0))

	-- Accept the shot. Dash Focus: the first shot after a dash, inside its
	-- window (the server saw the dash itself; the client never claims it).
	local focus = Motion.takeFocus(player, now, Hits.networkPing(player))
	state.shotIndex = shot
	slot.heatLow = heatLow + altRounds
	slot.heatHigh = heatHigh + altRounds
	slot.lastShotAt = now
	if not slot.spinStart or now - slot.lastFire > FireRate.SPIN_RESET then
		slot.spinStart = now
	end
	slot.burstShots = FireRate.nextBurstCount(config, slot.burstShots, slot.lastFire, now)
	-- The knife's 1-2-3 chain as the client counts it (WeaponController swing):
	-- a light slash within comboWindow of the last one's cooldown is the next
	-- step. Cosmetic: it only picks which slash clip others see.
	local melee = config.melee
	if melee then
		local step = slot.meleeStep or 0
		local readyAt = math.max(slot.lastFire + interval, slot.altReadyAt)
		if altFire then
			slot.meleeStep = 0
		elseif step < 3 and now - readyAt <= (melee.comboWindow or 0) + Combat.FIRE_JITTER then
			slot.meleeStep = step + 1
		else
			slot.meleeStep = 1
		end
	end
	slot.lastFire = math.max(now, slot.lastFire + interval)
	if config.magSize > 0 then
		slot.ammo -= altRounds
	end
	if altFire then
		slot.altReadyAt = now
			+ altFire.fireInterval / (rateMult(player) * statusMult(player, "fireRate"))
	end
	-- Others see the knife swing (Simulation/Poses: KnifeSlash / KnifeHeavy).
	if config.melee then
		player:SetAttribute("SwingHeavy", altFire ~= nil and config.melee.heavy ~= nil)
		player:SetAttribute("SwingStep", slot.meleeStep or 1)
		player:SetAttribute("SwingAt", now)
	end

	-- Replicate the visuals to everyone else (cosmetic: clamp, don't trust).
	local ends: { Vector3 } = {}
	for _, e in Hits.readArray(p.ends, pellets) do
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
	-- (Motion.spreadBand): a claimed cone outside that band is clamped into it, so
	-- a client that lies about its spread gets rays its hits won't match.
	local rewindAge = Hits.rewindWindow(player)
	local low, high, mayCentre =
		Motion.spreadBand(player, config, heatLow, heatHigh, Hits.networkPing(player), focus)
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

	-- Each claimed hit, then the damage (Weapon/Hits).
	local root = character:FindFirstChild("HumanoidRootPart")
	local valid, objectHits = Hits.validate(
		player,
		character,
		root,
		config,
		origin,
		dirs,
		pellets,
		exclude,
		rewindAge,
		p.hits
	)
	local hitCharacter = Hits.apply(player, config, altFire, head, root, valid, objectHits)
	notifyShot(player, config, hitCharacter)
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
		-- A new life: no dash left over from the last one.
		Motion.resetDash(player)
		Health.onDowned(humanoid, function()
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
	RunService.Heartbeat:Connect(function(dt: number)
		Motion.sample(dt, equippedConfig)
	end)
	-- A stun (Frozen) drops a reload in progress (a shell-by-shell one keeps
	-- the shells it loaded), like the client does when it sees the freeze.
	StatusService.onApply(function(model: Model, name: string)
		local effect = StatusEffects.effects[name]
		local player = Players:GetPlayerFromCharacter(model)
		local state = player and states[player]
		if not effect or not effect.stun or not player or not state then
			return
		end
		local dropped = false
		for _, s in state.slots do
			if s.reloadEnd then
				settleShellReload(s, os.clock())
				dropped = true
			end
		end
		if dropped then
			sendState(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Motion.forget(player)
		states[player] = nil
		loadouts[player] = nil
		limiter:forget(player)
		holsteredPlayers[player] = nil
		busyUntil[player] = nil
		fireBoost[player] = nil
		WorldModel.forget(player)
	end)
end

return WeaponService
