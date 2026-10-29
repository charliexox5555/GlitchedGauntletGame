--!strict
-- Server-authoritative Mods (vault/04 Tech/Mod System.md). Owns every
-- player's 3 slots ({ id, level }), charges and cooldowns (server clock;
-- per-round charges come back only through refillCharges, Mods/Charges),
-- the held slot, and every requested Mod's validation and effect. Predicted
-- Mods (Dash) run in shared/Simulation/Abilities instead; this service only
-- hands them their slot.
--
-- Replicated as player attributes (the HUD and the simulation read them):
--   Mod<n>Id, Mod<n>Level          the loadout (nil = empty slot)
-- Owner-only (attributes on PlayerGui.ModState, which replicates to its owner
-- alone, so enemies can't read your cooldowns):
--   Mod<n>Charges, Mod<n>RechargeAt server Mods only (workspace:GetServerTimeNow())
--   Mod<n>ActiveUntil              server time a slot's effect runs until (HUD bar)
-- (Predicted Mods keep theirs on the character, which Server Authority
-- replicates to everyone: that can't be hidden.)
--   ModHeld                        0, or the slot the server has as held
--   ModUnlimitedCharges            test mode: casting spends nothing (dev panel;
--                                  on by default in Studio, Config/Dev)
--   ModResetSerial                 bumped by refillCharges (the simulation
--                                  refills predicted Mods when it changes)
--   Mod<n>Serial                   bumped by setSlot (the simulation refills
--                                  that predicted slot)
--   Mod<n>Carry, Mod<n>CarryAt     predicted Mods: charges and next recharge
--                                  (simulation time()) the last life ended
--                                  with, so a respawn doesn't refill them
--   TeamId                         team until MatchService exists (Mods/Teams)
--
-- Request ladder (roblox-security): rate limit → types (finite, ranges,
-- enums) → active server, alive, owns a built server Mod in that slot, held
-- when it's a held Mod → camera origin near the server head, aim roughly
-- where the character faces → has a charge → the Mod's own validate (range,
-- line of sight, target) → spend → apply → ModFx. A refused request costs
-- nothing and tells only the caster ("Denied").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Charges = require(Shared.Mods.Charges)
local Config = require(Shared.Config.Mods)
local Dev = require(Shared.Config.Dev)
local Mods = require(Shared.Mods)
local ModTypes = require(Shared.Mods.Types)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local SelfBuff = require(Shared.Mods.Blocks.SelfBuff)
local Teams = require(Shared.Mods.Teams)
local TestMode = require(Shared.TestMode)
local Validate = require(Shared.Util.Validate)

local ModEntities = require(script.Parent.ModEntities)
local ModRecall = require(script.Parent.ModRecall)
local ModWalls = require(script.Parent.ModWalls)
local StatusService = require(script.Parent.StatusService)
local WeaponService = require(script.Parent.WeaponService)

type SlotState = { id: string?, level: string, charges: number, rechargeAt: number }
type PlayerState = { slots: { SlotState }, held: number, heldAt: number }
type Heal = { target: Model, from: Player, effect: SelfBuff.Timed }

local MODES: { [string]: boolean } = { Primary = true, Alt = true }
-- The third-person clip a use of each held kind plays (Simulation/Poses).
local USE_KINDS: { [string]: string } = {
	HeldThrow = "Throw",
	HeldPlace = "Place",
	HeldTarget = "Heal",
	HeldSteer = "Cast",
	HeldCharge = "Heal", -- the launcher's shove forward
}
local HELD_ITEM = "ModHeldItem"
-- The item sits in the right hand like a gun (WeaponService's grip).
local HELD_GRIP = CFrame.new(0, -0.15, -0.05) * CFrame.Angles(-math.pi / 2, 0, 0)

local ModService = {}

local states: { [Player]: PlayerState } = {}
local heals: { Heal } = {}
local limiter = RateLimit.new(Config.RATE)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Mods work only where there's something to test them in: Studio and test
-- mode for now (rounds will add "in a round").
local function active(): boolean
	return RunService:IsStudio() or TestMode.isOn()
end

local function liveHumanoid(model: Model?): Humanoid?
	local h = model and model:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

local function prefix(slot: number): string
	return "Mod" .. slot
end

local function unlimited(player: Player): boolean
	return player:GetAttribute("ModUnlimitedCharges") == true
end

local function newState(): PlayerState
	local slots = {}
	for i = 1, Config.SLOTS do
		slots[i] = { id = nil, level = "L1", charges = 0, rechargeAt = 0 }
	end
	return { slots = slots, held = 0, heldAt = 0 }
end

local function settle(s: SlotState, stats: ModTypes.Stats, now: number)
	s.charges, s.rechargeAt =
		Charges.settle(s.charges, s.rechargeAt, stats.charges, stats.cooldown, now)
end

-- The owner-only holder (a disabled ScreenGui in the player's PlayerGui).
local function privateState(player: Player): Instance?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil
	end
	local existing = gui:FindFirstChild("ModState")
	if existing then
		return existing
	end
	local holder = Instance.new("ScreenGui")
	holder.Name = "ModState"
	holder.Enabled = false
	holder.ResetOnSpawn = false
	holder.Parent = gui
	return holder
end

local function publishSlot(player: Player, slot: number, s: SlotState)
	local p = prefix(slot)
	local def = s.id and Mods.def(s.id)
	player:SetAttribute(p .. "Id", s.id)
	player:SetAttribute(p .. "Level", if s.id then s.level else nil)
	local serverOwned = def ~= nil and def.authority == "Server"
	local private = privateState(player)
	if private then
		private:SetAttribute(p .. "Charges", if serverOwned then s.charges else nil)
		private:SetAttribute(p .. "RechargeAt", if serverOwned then s.rechargeAt else nil)
	end
end

-- What others see in your hand while a Mod is held: its finished model
-- (handheld / thrown Mods; clients tint its energy per viewer), with your
-- third-person gun hidden. nil puts the gun back.
local function showHeldItem(player: Player, id: string?)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(HELD_ITEM)
	if old then
		old:Destroy()
	end
	local folder = ReplicatedStorage:FindFirstChild("Abilities")
	local template = id and folder and folder:FindFirstChild(id)
	local kind = template and template:GetAttribute("Kind")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local show = template ~= nil
		and template:IsA("Model")
		and (kind == "handheld" or kind == "thrown")
	WeaponService.setWorldWeaponHidden(player, show)
	if not show or not hand or not hand:IsA("BasePart") then
		return
	end
	local model = (template :: Model):Clone()
	model.Name = HELD_ITEM
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
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
	local offset = model:GetAttribute("HoldOffset")
	local grip = Instance.new("Weld")
	grip.Part0 = hand
	grip.Part1 = root
	grip.C0 = HELD_GRIP
		* (if typeof(offset) == "Vector3" then CFrame.new(offset) else CFrame.identity)
	grip.Parent = root
	root.CFrame = hand.CFrame * grip.C0
	model.Parent = character
end

-- Ends the hold. `busyFor`: the gun stays down this much longer (the throw /
-- heal animation the client plays after a use).
local function release(player: Player, busyFor: number?)
	local state = states[player]
	if state then
		state.held = 0
	end
	WeaponService.setHolstered(player, false, busyFor)
	player:SetAttribute("ModHeld", 0)
	showHeldItem(player, nil)
end

local function deny(player: Player, slot: number, reason: string)
	if RunService:IsStudio() then
		player:SetAttribute("ModReject", reason)
	end
	Net.event("ModFx"):FireClient(player, "Denied", { slot = slot, reason = reason })
end

local warnedFallback = false

local function angleBetween(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- The claimed aim against what the server knows: the camera the client
-- replicates (Player:GetCameraState, Server Authority), else the character's
-- facing (first person turns the character with the camera's yaw).
-- The server's copy of the player's camera look (nil if unavailable).
local function cameraLook(player: Player): Vector3?
	local ok, state = pcall(function()
		return (player :: any):GetCameraState()
	end)
	local cf = if ok and typeof(state) == "table" then state.CFrame else nil
	return if typeof(cf) == "CFrame" then cf.LookVector else nil
end

local function aimPlausible(player: Player, root: BasePart, direction: Vector3): boolean
	local look = cameraLook(player)
	if look then
		return angleBetween(direction, look) <= Config.AIM_TOLERANCE
	end
	if not warnedFallback then
		warnedFallback = true
		warn("[ModService] Player:GetCameraState unavailable: checking aim against facing only")
	end
	local flatAim = direction * Vector3.new(1, 0, 1)
	local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatAim.Magnitude < 0.2 or flatLook.Magnitude < 0.2 then
		return true -- looking straight up or down: yaw says nothing
	end
	return angleBetween(flatAim, flatLook) <= Config.AIM_YAW_TOLERANCE
end

-- World-only raycast params: bodies, dummies and effects don't block a Mod's
-- line of sight or a projectile's path. Mod objects do (a Firewall stops a
-- grenade and its blast).
local function worldParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Dummies", "Effects" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

-- The next life starts full (setSlot, refillCharges).
local function clearCarry(player: Player, slot: number)
	player:SetAttribute(prefix(slot) .. "Carry", nil)
	player:SetAttribute(prefix(slot) .. "CarryAt", nil)
end

-- Loadout API (draft later; the dev panel now) ------------------------------------

-- Puts Mod `id` at `level` in `slot` (nil id empties it), full charges.
-- Returns false for an unknown or unbuilt Mod.
function ModService.setSlot(player: Player, slot: number, id: string?, level: string): boolean
	local state = states[player]
	if not state or slot < 1 or slot > Config.SLOTS then
		return false
	end
	local stats = id and Mods.stats(id, level)
	if id and (not stats or not Mods.isBuilt(id) or not active()) then
		return false
	end
	if state.held == slot then
		ModWalls.stop(player)
		release(player)
	end
	local s = state.slots[slot]
	s.id = id
	s.level = level
	s.charges = if stats then stats.charges else 0
	s.rechargeAt = serverNow()
	clearCarry(player, slot)
	local serial = player:GetAttribute(prefix(slot) .. "Serial")
	player:SetAttribute(
		prefix(slot) .. "Serial",
		(if typeof(serial) == "number" then serial else 0) + 1
	)
	publishSlot(player, slot, s)
	local private = privateState(player)
	if private then
		private:SetAttribute(prefix(slot) .. "ActiveUntil", nil)
	end
	return true
end

function ModService.setLoadout(player: Player, loadout: { ModTypes.SlotLoadout })
	for slot = 1, Config.SLOTS do
		local entry = loadout[slot]
		ModService.setSlot(player, slot, entry and entry.id, if entry then entry.level else "L1")
	end
end

-- Charges ------------------------------------------------------------------------------

-- Every charge back, server and simulation Mods alike. RoundService calls this
-- at the start of each round; the dev panel's "Refill charges" too.
function ModService.refillCharges(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local now = serverNow()
	for slot, s in state.slots do
		clearCarry(player, slot)
		local stats = s.id and Mods.stats(s.id, s.level)
		if stats then
			s.charges = stats.charges
			s.rechargeAt = now
			publishSlot(player, slot, s)
		end
	end
	local serial = player:GetAttribute("ModResetSerial")
	player:SetAttribute("ModResetSerial", (if typeof(serial) == "number" then serial else 0) + 1)
end

-- Round start: everyone's charges back.
function ModService.refillAllCharges()
	for _, player in Players:GetPlayers() do
		ModService.refillCharges(player)
	end
end

-- Test mode: casting spends nothing (charges stay where they are).
function ModService.setUnlimitedCharges(player: Player, on: boolean)
	player:SetAttribute("ModUnlimitedCharges", on)
end

-- A life ends: remember the predicted Mods' charges (the simulation keeps them
-- on the character, which goes) for the next life. Only when the old life
-- applied the latest refill and setSlot and still held the current loadout;
-- otherwise refillCharges / setSlot already cleared the carry, and the next
-- life starts full.
local function carryCharges(player: Player, character: Model)
	local state = states[player]
	local serial = player:GetAttribute("ModResetSerial")
	local seen = character:GetAttribute("ModResetSeen")
	if not state or seen ~= (if typeof(serial) == "number" then serial else 0) then
		return
	end
	for slot, s in state.slots do
		local id = s.id
		local def = id and Mods.def(id)
		if not id or not def or def.authority ~= "Simulation" then
			continue
		end
		local p = prefix(slot)
		local charges = character:GetAttribute(p .. "Charges")
		local rechargeAt = character:GetAttribute(p .. "RechargeAt")
		local slotSerial = player:GetAttribute(p .. "Serial")
		if
			character:GetAttribute(p .. "Key") == id .. ":" .. s.level
			and character:GetAttribute(p .. "SerialSeen") == (if typeof(slotSerial) == "number"
				then slotSerial
				else 0)
			and typeof(charges) == "number"
		then
			player:SetAttribute(p .. "Carry", charges)
			player:SetAttribute(
				p .. "CarryAt",
				if typeof(rechargeAt) == "number" then rechargeAt else nil
			)
		end
	end
end

-- Remote handlers --------------------------------------------------------------------

local function onHold(player: Player, slotArg: unknown)
	if not limiter:allow(player, "ModHold") then
		return
	end
	local slot = Validate.integer(slotArg, 0, Config.SLOTS)
	local state = states[player]
	if slot == nil or not state then
		return
	end
	if slot == 0 then
		-- A wall still building ends where it is: the gun only comes back
		-- once nothing is being built.
		ModWalls.stop(player)
		release(player)
		return
	end
	if ModWalls.isBuilding(player) then
		return -- no other Mod while a wall builds
	end
	if ModRecall.isWinding(player) then
		deny(player, slot, "teleporting") -- the client puts its gun back up
		return
	end
	if not active() or not liveHumanoid(player.Character) then
		return
	end
	if state.held == slot then
		return -- already held (a repeat would re-clone the held model)
	end
	local s = state.slots[slot]
	local def = s.id and Mods.def(s.id)
	local stats = s.id and Mods.stats(s.id, s.level)
	if not def or not stats or def.activation == "Instant" then
		return
	end
	if s.id == "Recall" and ModRecall.anchor(player) then
		deny(player, slot, "Anchor already planted")
		return
	end
	settle(s, stats, serverNow())
	if s.charges < 1 and not unlimited(player) then
		deny(player, slot, "not ready")
		release(player)
		return
	end
	state.held = slot
	state.heldAt = os.clock()
	WeaponService.setHolstered(player, true)
	player:SetAttribute("ModHeld", slot)
	showHeldItem(player, s.id)
end

local function use(
	player: Player,
	slotArg: unknown,
	modeArg: unknown,
	originArg: unknown,
	directionArg: unknown,
	targetArg: unknown,
	chargeArg: unknown,
	bouncesArg: unknown
)
	local slot = Validate.integer(slotArg, 1, Config.SLOTS)
	local mode = Validate.enum(modeArg, MODES)
	local origin = Validate.vector(originArg)
	local direction = Validate.unit(directionArg)
	if not slot or not mode or not origin or not direction then
		return
	end
	local target: Model? = nil
	if targetArg ~= nil then
		local inst = Validate.instance(targetArg, "Model")
		if not inst then
			deny(player, slot, "bad target")
			return
		end
		target = inst :: Model
	end
	local state = states[player]
	if not state then
		return
	end
	local s = state.slots[slot]
	local id = s.id
	local def = id and Mods.def(id)
	local module = id and Mods.module(id)
	local stats = id and Mods.stats(id, s.level)
	if not id or not def or not module or not stats then
		deny(player, slot, "no Mod in that slot")
		return
	end
	local modId: string = id
	local apply = module.apply
	if def.authority ~= "Server" or not apply then
		deny(player, slot, "predicted Mod")
		return
	end
	if not active() then
		deny(player, slot, "Mods are off")
		return
	end
	local character = player.Character
	local humanoid = liveHumanoid(character)
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not character
		or not humanoid
		or not head
		or not head:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
	then
		deny(player, slot, "dead")
		return
	end
	if def.activation ~= "Instant" and state.held ~= slot then
		deny(player, slot, "not held")
		return
	end
	if ModRecall.isWinding(player) then
		deny(player, slot, "teleporting")
		return
	end
	if (origin - head.Position).Magnitude > Config.ORIGIN_TOLERANCE then
		deny(player, slot, "origin too far from head")
		return
	end
	if not aimPlausible(player, root, direction) then
		deny(player, slot, "aim doesn't match the camera")
		return
	end

	local now = serverNow()
	settle(s, stats, now)
	local free = unlimited(player)
	if s.charges < 1 and not free then
		deny(player, slot, "not ready")
		return
	end

	local function damage(victim: Model, amount: number, at: Vector3)
		WeaponService.damage(player, victim, amount, modId, at)
	end
	local ctx: ModTypes.ServerCtx = {
		player = player,
		character = character,
		humanoid = humanoid,
		head = head,
		slot = slot,
		id = id,
		level = s.level,
		stats = stats,
		now = now,
		heldFor = if state.held == slot then os.clock() - state.heldAt else 0,
		worldParams = worldParams,
		damage = damage,
		heal = function(healTarget: Model, amount: number, duration: number)
			-- A new heal replaces what's left of an old one (no stacking).
			for i = #heals, 1, -1 do
				if heals[i].target == healTarget then
					table.remove(heals, i)
				end
			end
			if duration <= 0 then
				WeaponService.heal(healTarget, amount)
			else
				table.insert(heals, {
					target = healTarget,
					from = player,
					effect = SelfBuff.timed(os.clock(), duration, amount),
				})
			end
		end,
		fx = function(kind: string, data: { [string]: any })
			data.caster = player
			data.team = Teams.of(player)
			data.id = modId
			data.level = s.level
			Net.event("ModFx"):FireAllClients(kind, data)
		end,
		schedule = function(delay: number, fn: () -> ())
			ModEntities.schedule(player, delay, fn)
		end,
		-- World effects belong to the life that made them: a zone that opens
		-- after its caster died doesn't (ModEntities clears them on death).
		place = function(kind: string, part: BasePart, life: number, hp: number, maxActive: number)
			if player.Character ~= character or not liveHumanoid(character) then
				part:Destroy()
				return
			end
			ModEntities.place(player, kind, part, life, hp, maxActive)
		end,
		status = function(model: Model, name: string, duration: number)
			StatusService.apply(model, name, duration)
		end,
		reveal = function(targets: { Model }, duration: number)
			for _, other in Players:GetPlayers() do
				if Teams.isAlly(player, other) then
					Net.event("ModReveal"):FireClient(other, targets, duration)
				end
			end
			-- Each revealed player only learns that they were spotted (their
			-- warning sound), not by whom or who else.
			for _, model in targets do
				local victim = Players:GetPlayerFromCharacter(model)
				if victim then
					Net.event("ModFx"):FireClient(victim, "Revealed", { duration = duration })
				end
			end
		end,
		fireRate = function(mult: number, duration: number)
			WeaponService.setFireRate(player, mult, duration)
		end,
		active = function(duration: number)
			local private = privateState(player)
			if private then
				private:SetAttribute(prefix(slot) .. "ActiveUntil", serverNow() + duration)
			end
		end,
		-- Where the server's own copy of the camera looks (Server Authority),
		-- else the claimed aim: for checks that must not stack tolerances.
		cameraLook = cameraLook(player) or direction,
		objectsNear = function(at: Vector3, radius: number): { BasePart }
			return ModEntities.objectsNear(at, radius)
		end,
		damageObject = function(part: BasePart, amount: number)
			ModEntities.damage(part, amount, player)
		end,
		-- HeldSteer (Firewall): the hold (gun down) lasts until it's built.
		wall = function(spec: ModTypes.WallSpec)
			ModWalls.build(player, root, stats, spec, {
				damage = damage,
				look = function(): Vector3?
					return if player.Character == character then cameraLook(player) else nil
				end,
				built = function()
					local st = states[player]
					if st and st.held == slot then
						release(player, Config.USE_TIME)
					end
					Net.event("ModFx"):FireClient(player, "WallBuilt", { slot = slot })
				end,
			})
		end,
		anchor = function(part: BasePart)
			ModRecall.track(player, slot, part, function()
				-- Broken by enemies: the teleport is lost for the round.
				if s.id ~= modId or unlimited(player) then
					return
				end
				local t = serverNow()
				settle(s, stats, t)
				s.charges, s.rechargeAt =
					Charges.spend(s.charges, s.rechargeAt, stats.charges, stats.cooldown, t)
				publishSlot(player, slot, s)
			end)
		end,
		anchorDown = ModRecall.anchor(player) ~= nil,
	}
	local req: ModTypes.Request = {
		charge = if chargeArg == nil then nil else Validate.number(chargeArg, 0, 1),
		bounces = if bouncesArg == nil then nil else Validate.integer(bouncesArg, 0, 2),
		mode = mode :: ModTypes.UseMode,
		origin = origin,
		direction = direction,
		target = target,
	}
	local validate = module.validate
	if validate then
		local ok, reason = validate(ctx, req)
		if not ok then
			deny(player, slot, reason or "invalid")
			return
		end
	end

	local spends = module.spends == nil or module.spends(ctx, req)
	if not free and spends then
		s.charges, s.rechargeAt =
			Charges.spend(s.charges, s.rechargeAt, stats.charges, stats.cooldown, now)
	end
	publishSlot(player, slot, s)
	-- Third person: the throw / place / heal clip (Simulation/Poses).
	-- A held throw's Alt is an underhand lob (Molly).
	local useKind = if def.activation == "HeldThrow" and mode == "Alt"
		then "Lob"
		else def.useKind or USE_KINDS[def.activation]
	if useKind then
		player:SetAttribute("ModUseKind", useKind)
		player:SetAttribute("ModUseAt", now)
	end
	apply(ctx, req)
end

-- Every use ends the hold, accepted or not: the client goes back to its gun
-- either way (a refused hold left behind would silently block its shots).
-- The gun stays down for the use animation, on the server too.
local function onUse(player: Player, ...: unknown)
	if limiter:allow(player, "ModUse") then
		local ok, err = pcall(use, player, ...)
		if not ok then
			warn("[ModService] use failed:", err)
		end
	end
	local state = states[player]
	-- A wall still building keeps the hold (ModWalls lets go when it's built).
	if state and state.held ~= 0 and not ModWalls.isBuilding(player) then
		release(player, Config.USE_TIME)
	end
end

-- ModRecall(slot, action): Recall with its anchor down ("Teleport", or
-- "PickUp" after holding the key next to it). Services/ModRecall runs it;
-- the slot, the charge and the request checks are here.
local RECALL_ACTIONS: { [string]: boolean } = { Teleport = true, PickUp = true }

local function onRecall(player: Player, slotArg: unknown, actionArg: unknown)
	if not limiter:allow(player, "ModRecall") then
		return
	end
	local slot = Validate.integer(slotArg, 1, Config.SLOTS)
	local action = Validate.enum(actionArg, RECALL_ACTIONS)
	local state = states[player]
	if not slot or not action or not state then
		return
	end
	local s = state.slots[slot]
	local stats = s.id == "Recall" and Mods.stats(s.id, s.level)
	if not stats then
		deny(player, slot, "no Recall in that slot")
		return
	end
	if not active() or not liveHumanoid(player.Character) then
		return
	end
	if state.held ~= 0 or ModWalls.isBuilding(player) then
		deny(player, slot, "busy")
		return
	end
	local hooks: ModRecall.Hooks = {
		ready = function(): boolean
			settle(s, stats, serverNow())
			return s.charges >= 1 or unlimited(player)
		end,
		spend = function()
			local now = serverNow()
			settle(s, stats, now)
			if not unlimited(player) then
				s.charges, s.rechargeAt =
					Charges.spend(s.charges, s.rechargeAt, stats.charges, stats.cooldown, now)
			end
			publishSlot(player, slot, s)
		end,
		deny = function(reason: string)
			deny(player, slot, reason)
		end,
		fx = function(kind: string, data: { [string]: any })
			data.caster = player
			data.team = Teams.of(player)
			data.id = "Recall"
			data.level = s.level
			Net.event("ModFx"):FireAllClients(kind, data)
		end,
		pose = function(kind: string)
			player:SetAttribute("ModUseKind", kind)
			player:SetAttribute("ModUseAt", serverNow())
		end,
	}
	if action == "Teleport" then
		ModRecall.teleport(player, slot, stats, hooks)
	else
		ModRecall.pickUp(player, slot, stats, hooks)
	end
end

-- ModSteer(slot, lookX, lookZ, stop): the Firewall's steering stream while
-- LMB is held (the server prefers its own copy of the camera), and the
-- release that ends it early. Only for a wall that is building.
local function onSteer(
	player: Player,
	slotArg: unknown,
	xArg: unknown,
	zArg: unknown,
	stopArg: unknown
)
	if not limiter:allow(player, "ModSteer") then
		return
	end
	local slot = Validate.integer(slotArg, 1, Config.SLOTS)
	local x = Validate.number(xArg, -1.01, 1.01)
	local z = Validate.number(zArg, -1.01, 1.01)
	local stop = Validate.boolean(stopArg)
	local state = states[player]
	if not slot or not x or not z or stop == nil or not state or state.held ~= slot then
		return
	end
	if stop then
		ModWalls.steer(player, nil)
		return
	end
	local look = Vector3.new(x, 0, z)
	if look.Magnitude > 0.05 then
		ModWalls.steer(player, look.Unit)
	end
end

-- Heals over time ---------------------------------------------------------------------

local function stepHeals()
	local now = os.clock()
	for i = #heals, 1, -1 do
		local h = heals[i]
		if not liveHumanoid(h.target) or h.target.Parent == nil then
			table.remove(heals, i)
			continue
		end
		local amount = SelfBuff.take(h.effect, now)
		if amount > 0 then
			WeaponService.heal(h.target, amount)
		end
		if SelfBuff.done(h.effect, now) then
			table.remove(heals, i)
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------------

-- Two teams by join order (fewest players first), until MatchService.
local function assignTeam(player: Player)
	local counts = { 0, 0 }
	for _, other in Players:GetPlayers() do
		local t = Teams.of(other)
		if other ~= player and (t == 1 or t == 2) then
			counts[t] += 1
		end
	end
	player:SetAttribute(Teams.ATTRIBUTE, if counts[2] < counts[1] then 2 else 1)
end

-- Connections that belong to one life (dropped when the character goes).
local lifeConnections: { [Player]: { RBXScriptConnection } } = {}

local function dropLife(player: Player)
	local list = lifeConnections[player]
	if list then
		for _, c in list do
			c:Disconnect()
		end
	end
	lifeConnections[player] = nil
end

local function holdLife(player: Player, c: RBXScriptConnection)
	local list = lifeConnections[player]
	if not list then
		list = {}
		lifeConnections[player] = list
	end
	table.insert(list, c)
end

local function onCharacter(player: Player, character: Model)
	ModWalls.stop(player)
	ModRecall.cancel(player)
	release(player)
	-- A new life: what the last one left in the world goes.
	ModEntities.clear(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if player.Parent ~= Players or player.Character ~= character then
		return -- left (or respawned) while we waited
	end
	if humanoid and humanoid:IsA("Humanoid") then
		holdLife(
			player,
			humanoid.Died:Connect(function()
				ModWalls.stop(player) -- a wall stops growing (it keeps burning)
				ModRecall.cancel(player) -- dying cancels a teleport
				release(player)
				ModEntities.clear(player)
			end)
		)
	end
end

local function onPlayer(player: Player)
	assignTeam(player)
	states[player] = newState()
	player:WaitForChild("PlayerGui", 10)
	player:SetAttribute("ModHeld", 0)
	if RunService:IsStudio() and Dev.UNLIMITED_CHARGES then
		ModService.setUnlimitedCharges(player, true)
	end
	if active() then
		ModService.setLoadout(player, Config.TEST_LOADOUT)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		carryCharges(player, character)
		dropLife(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function ModService.init()
	Net.event("ModHold").OnServerEvent:Connect(onHold)
	Net.event("ModUse").OnServerEvent:Connect(onUse)
	Net.event("ModSteer").OnServerEvent:Connect(onSteer)
	Net.event("ModRecall").OnServerEvent:Connect(onRecall)
end

function ModService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		limiter:forget(player)
		dropLife(player)
		for i = #heals, 1, -1 do
			if heals[i].from == player then
				table.remove(heals, i)
			end
		end
	end)
	RunService.Heartbeat:Connect(stepHeals)
end

return ModService
