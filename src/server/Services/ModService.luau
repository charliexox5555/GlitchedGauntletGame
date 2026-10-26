--!strict
-- Server-authoritative Mods (vault/04 Tech/Mod System.md). Owns every
-- player's 3 slots ({ id, level }), charges and cooldowns (server clock),
-- the held slot, and every requested Mod's validation and effect. Predicted
-- Mods (Blink) run in shared/Simulation/Abilities instead; this service only
-- hands them their slot.
--
-- Replicated as player attributes (the HUD and the simulation read them):
--   Mod<n>Id, Mod<n>Level          the loadout (nil = empty slot)
--   Mod<n>Charges, Mod<n>RechargeAt server Mods only (workspace:GetServerTimeNow())
--   ModHeld                        0, or the slot the server has as held
--   ModNoCooldown, ModResetSerial  dev panel switches (DevModService)
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
local Mods = require(Shared.Mods)
local ModTypes = require(Shared.Mods.Types)
local Net = require(Shared.Net)
local RateLimit = require(Shared.Util.RateLimit)
local SelfBuff = require(Shared.Mods.Blocks.SelfBuff)
local Teams = require(Shared.Mods.Teams)
local TestMode = require(Shared.TestMode)
local Validate = require(Shared.Util.Validate)

local ModEntities = require(script.Parent.ModEntities)
local WeaponService = require(script.Parent.WeaponService)

type SlotState = { id: string?, level: string, charges: number, rechargeAt: number }
type PlayerState = { slots: { SlotState }, held: number }
type Heal = { target: Model, from: Player, effect: SelfBuff.Timed }

local MODES: { [string]: boolean } = { Primary = true, Alt = true }

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

local function newState(): PlayerState
	local slots = {}
	for i = 1, Config.SLOTS do
		slots[i] = { id = nil, level = "L1", charges = 0, rechargeAt = 0 }
	end
	return { slots = slots, held = 0 }
end

local function settle(s: SlotState, stats: ModTypes.Stats, now: number)
	s.charges, s.rechargeAt =
		Charges.settle(s.charges, s.rechargeAt, stats.charges, stats.cooldown, now)
end

local function publishSlot(player: Player, slot: number, s: SlotState)
	local p = prefix(slot)
	local def = s.id and Mods.def(s.id)
	player:SetAttribute(p .. "Id", s.id)
	player:SetAttribute(p .. "Level", if s.id then s.level else nil)
	local serverOwned = def ~= nil and def.authority == "Server"
	player:SetAttribute(p .. "Charges", if serverOwned then s.charges else nil)
	player:SetAttribute(p .. "RechargeAt", if serverOwned then s.rechargeAt else nil)
end

local function release(player: Player)
	local state = states[player]
	if state then
		state.held = 0
	end
	WeaponService.setHolstered(player, false)
	player:SetAttribute("ModHeld", 0)
end

local function deny(player: Player, slot: number, reason: string)
	if RunService:IsStudio() then
		player:SetAttribute("ModReject", reason)
	end
	Net.event("ModFx"):FireClient(player, "Denied", { slot = slot, reason = reason })
end

local function angleBetween(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- The claimed aim against what the server knows: the camera the client
-- replicates (Player:GetCameraState, Server Authority), else the character's
-- facing (first person turns the character with the camera's yaw).
local function aimPlausible(player: Player, root: BasePart, direction: Vector3): boolean
	local ok, state = pcall(function()
		return (player :: any):GetCameraState()
	end)
	local cf = if ok and typeof(state) == "table" then state.CFrame else nil
	if typeof(cf) == "CFrame" then
		return angleBetween(direction, cf.LookVector) <= Config.AIM_TOLERANCE
	end
	local flatAim = direction * Vector3.new(1, 0, 1)
	local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatAim.Magnitude < 0.2 or flatLook.Magnitude < 0.2 then
		return true -- looking straight up or down: yaw says nothing
	end
	return angleBetween(flatAim, flatLook) <= Config.AIM_YAW_TOLERANCE
end

-- World-only raycast params: bodies, dummies, effects and Mod objects don't
-- block a Mod's line of sight or a projectile's path.
local function worldParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Dummies", "Effects", "ModObjects" } do
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

-- Loadout API (draft later; the dev panel now) ------------------------------------

-- Puts Mod `id` at `level` in `slot` (nil id empties it), full charges.
-- Returns false for an unknown or unbuilt Mod.
function ModService.setSlot(player: Player, slot: number, id: string?, level: string): boolean
	local state = states[player]
	if not state or slot < 1 or slot > Config.SLOTS then
		return false
	end
	local stats = id and Mods.stats(id, level)
	if id and (not stats or not Mods.isBuilt(id)) then
		return false
	end
	if state.held == slot then
		release(player)
	end
	local s = state.slots[slot]
	s.id = id
	s.level = level
	s.charges = if stats then stats.charges else 0
	s.rechargeAt = serverNow()
	publishSlot(player, slot, s)
	return true
end

function ModService.setLoadout(player: Player, loadout: { ModTypes.SlotLoadout })
	for slot = 1, Config.SLOTS do
		local entry = loadout[slot]
		ModService.setSlot(player, slot, entry and entry.id, if entry then entry.level else "L1")
	end
end

-- Every charge back, server and simulation Mods alike.
function ModService.resetCooldowns(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for slot, s in state.slots do
		local stats = s.id and Mods.stats(s.id, s.level)
		if stats then
			s.charges = stats.charges
			s.rechargeAt = serverNow()
			publishSlot(player, slot, s)
		end
	end
	local serial = player:GetAttribute("ModResetSerial")
	player:SetAttribute("ModResetSerial", (if typeof(serial) == "number" then serial else 0) + 1)
end

function ModService.setNoCooldown(player: Player, on: boolean)
	player:SetAttribute("ModNoCooldown", on)
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
		release(player)
		return
	end
	if not active() or not liveHumanoid(player.Character) then
		return
	end
	local s = state.slots[slot]
	local def = s.id and Mods.def(s.id)
	local stats = s.id and Mods.stats(s.id, s.level)
	if not def or not stats or def.activation == "Instant" then
		return
	end
	settle(s, stats, serverNow())
	if s.charges < 1 and player:GetAttribute("ModNoCooldown") ~= true then
		deny(player, slot, "not ready")
		release(player)
		return
	end
	state.held = slot
	WeaponService.setHolstered(player, true)
	player:SetAttribute("ModHeld", slot)
end

local function onUse(
	player: Player,
	slotArg: unknown,
	modeArg: unknown,
	originArg: unknown,
	directionArg: unknown,
	targetArg: unknown
)
	if not limiter:allow(player, "ModUse") then
		return
	end
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
	local free = player:GetAttribute("ModNoCooldown") == true
	if s.charges < 1 and not free then
		deny(player, slot, "not ready")
		return
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
		worldParams = worldParams(),
		damage = function(victim: Model, amount: number, at: Vector3)
			WeaponService.damage(player, victim, amount, id, at)
		end,
		heal = function(healTarget: Model, amount: number, duration: number)
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
			data.id = id
			data.level = s.level
			Net.event("ModFx"):FireAllClients(kind, data)
		end,
		schedule = function(delay: number, fn: () -> ())
			ModEntities.schedule(player, delay, fn)
		end,
	}
	local req: ModTypes.Request = {
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

	if not free then
		s.charges, s.rechargeAt =
			Charges.spend(s.charges, s.rechargeAt, stats.charges, stats.cooldown, now)
	end
	publishSlot(player, slot, s)
	if state.held == slot then
		release(player)
	end
	apply(ctx, req)
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

local function onCharacter(player: Player, character: Model)
	release(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			release(player)
		end)
	end
end

local function onPlayer(player: Player)
	assignTeam(player)
	states[player] = newState()
	player:SetAttribute("ModHeld", 0)
	if active() then
		ModService.setLoadout(player, Config.TEST_LOADOUT)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function ModService.init()
	Net.event("ModHold").OnServerEvent:Connect(onHold)
	Net.event("ModUse").OnServerEvent:Connect(onUse)
end

function ModService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		limiter:forget(player)
		for i = #heals, 1, -1 do
			if heals[i].from == player then
				table.remove(heals, i)
			end
		end
	end)
	RunService.Heartbeat:Connect(stepHeals)
end

return ModService
