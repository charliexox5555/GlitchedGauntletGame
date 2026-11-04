--!strict
-- Updraft (Mobility, was Launch Pad; vault/01 Design/Abilities/Updraft.md):
-- an instant launch straight up for yourself, peaking `peak` studs above
-- where you used it. Keeps your horizontal momentum (running + Updraft = an
-- arc); in the air it resets your fall like a double jump. Then a normal
-- fall. Predicted: simCast runs inside the simulation (Simulation/
-- Abilities), on the server for everyone and on your client for yourself;
-- Updraft.step holds the rise while the Humanoid is still on the floor.
--
-- Upgrades (vault/01 Design/Abilities/Upgrade Paths.md → 2. Updraft): path A
-- raises `peak`, path B adds `charges` (numbers only). The glitch path
-- (`behaviour = "Slam"`): a new Crouch press while an Updraft is in the air
-- slams you straight down at `slamSpeed`; a press in the first `slamArm`
-- seconds waits until then, so a launch can't slam where it stood. The
-- landing is a simulation write; the server's hook (module.server) deals
-- `slamDamage` to enemies within `slamRadius` in sight of it (+ Hinder at G3).
--
-- Character attributes (simulation-written):
--   UpdraftAt     time() of the launch (clients play the effects on change)
--   UpdraftLaunch Vector3(up, gravity, gunDown): the launch's vertical speed
--                 (studs/s), the gravity it was launched under (a status
--                 lowers it), and the seconds from the launch the gun is down
--                 (no shots; both sides gate on it, Mods/Dash.stepGate). One
--                 attribute for three: a character's attributes share a
--                 1024-byte budget under Server Authority
--   Updrafting    true from the launch until you land (nil otherwise)
--   UpdraftCrouchIn  last step's Crouch input (Slam owners only: presses)
--   UpdraftSlam   "Queued": a Crouch press waiting for `slamArm`; "Down":
--                 from the slam's start until its landing; nil otherwise
--   UpdraftSlamStart time() the slam started (clients: the dive effects)
--   UpdraftSlamAt / UpdraftSlamPos  time() and root position of the last
--                 slam landing (the server's hook deals the damage)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Health = require(script.Parent.Parent.Health)
local Config = require(script.Parent.Parent.Config.Mods)
local Movement = require(script.Parent.Parent.Config.Movement)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local Updraft = {}

-- The Humanoid's ground state brakes a vertical kick for a few steps
-- (measured on the old Launch Pad: 99 → 55 studs/s in one): hold the launch's
-- own arc this long, until it's clear of the floor.
local RISE_HOLD = 0.2

-- The gravity this character falls under (a status like Hinder lowers it:
-- Simulation/Movement gives the rest back every step).
local function gravityOf(player: Player): number
	local mult = player:GetAttribute("StatusGravityMult")
	return workspace.Gravity * (if typeof(mult) == "number" then mult else 1)
end

-- Launch speed for a peak `peak` studs up under `gravity`.
function Updraft.launchSpeed(peak: number, gravity: number?): number
	return math.sqrt(2 * (gravity or workspace.Gravity) * math.max(peak, 0))
end

local function number(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function set(inst: Instance, name: string, value: any)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

local function actionDown(context: Instance?, name: string): boolean
	local action = context and context:FindFirstChild(name)
	if action and action:IsA("InputAction") then
		return action:GetState() == true
	end
	return false
end

-- Updraft's stats at `level`, resolved like Mods.stats (Mods/init requires
-- this module, so it can't be required back).
local statsCache: { [string]: Types.Stats } = {}
local function statsAt(level: string): Types.Stats?
	local cached = statsCache[level]
	if cached then
		return cached
	end
	local def = Config.defs.Updraft
	local chain = Config.CHAIN[level]
	if not def or not chain then
		return nil
	end
	local out: Types.Stats = {}
	for _, step in chain do
		local values = def.levels[step]
		if values then
			for k, v in values do
				out[k] = v
			end
		end
	end
	table.freeze(out)
	statsCache[level] = out
	return out
end

local SLOT_ID: { string } = {}
local SLOT_LEVEL: { string } = {}
for slot = 1, Config.SLOTS do
	SLOT_ID[slot] = "Mod" .. slot .. "Id"
	SLOT_LEVEL[slot] = "Mod" .. slot .. "Level"
end

-- The stats of `player`'s Updraft when it's on the Slam path (nil: no
-- Updraft slotted, or another level). Reads the loadout attributes, so it
-- works inside the simulation and on any client.
function Updraft.slamStats(player: Player): Types.Stats?
	for slot = 1, Config.SLOTS do
		if player:GetAttribute(SLOT_ID[slot]) == "Updraft" then
			local level = player:GetAttribute(SLOT_LEVEL[slot])
			local stats = if typeof(level) == "string" then statsAt(level) else nil
			return if stats and stats.behaviour == "Slam" then stats else nil
		end
	end
	return nil
end

-- The slam's state in one attribute (a character's attributes share a
-- 1024-byte budget under Server Authority): UpdraftSlam = "Queued" (pressed,
-- waiting for the arm time), "Down" (slamming), nil (none).
local function endSlam(character: Model)
	set(character, "UpdraftSlam", nil)
end

-- Simulation, every step (before the cast): holds the rise, runs a slam, and
-- ends the Updraft on landing. `context`: the player's PlayContext
-- (InputActions).
function Updraft.step(
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	context: Instance?,
	now: number
)
	local slam = Updraft.slamStats(player)
	local pressed = false
	if slam then
		-- Only a new press: crouch held from a slide into the launch isn't one.
		local crouch = actionDown(context, "Crouch")
		pressed = crouch and character:GetAttribute("UpdraftCrouchIn") ~= true
		set(character, "UpdraftCrouchIn", if crouch then true else nil)
	end
	if character:GetAttribute("Updrafting") ~= true then
		return
	end
	local since = now - number(character, "UpdraftAt", 0)
	local airborne = humanoid.FloorMaterial == Enum.Material.Air

	if slam then
		if character:GetAttribute("UpdraftSlam") == "Down" then
			if airborne then
				-- Straight down (no air steering, no carried run speed).
				root.AssemblyLinearVelocity = Vector3.new(0, -slam.slamSpeed, 0)
			else
				endSlam(character)
				set(character, "Updrafting", nil)
				character:SetAttribute("UpdraftSlamPos", root.Position)
				character:SetAttribute("UpdraftSlamAt", now)
			end
			return
		end
		if pressed then
			set(character, "UpdraftSlam", "Queued")
		end
		if
			character:GetAttribute("UpdraftSlam") == "Queued"
			and since >= slam.slamArm
			and airborne
		then
			set(character, "UpdraftSlam", "Down")
			set(character, "UpdraftSlamStart", now)
			set(character, "SlideJumpSpeed", 0)
			root.AssemblyLinearVelocity = Vector3.new(0, -slam.slamSpeed, 0)
			return
		end
	end

	if since < RISE_HOLD then
		local launch = character:GetAttribute("UpdraftLaunch")
		local gravity = if typeof(launch) == "Vector3" then launch.Y else workspace.Gravity
		local up = (if typeof(launch) == "Vector3" then launch.X else 0) - gravity * since
		local vel = root.AssemblyLinearVelocity
		if vel.Y < up then
			root.AssemblyLinearVelocity = Vector3.new(vel.X, up, vel.Z)
		end
	elseif not airborne then
		endSlam(character) -- a press still waiting is dropped
		set(character, "Updrafting", nil) -- landed
	end
end

-- Server: a slam landing the server's own simulation wrote. Enemies within
-- `slamRadius` of the root, in sight of it, take `slamDamage` (no self or
-- team damage), Hindered at G3.
local function slamLanded(api: Types.ServerApi, player: Player, character: Model)
	local _, level = api.slotOf(player, "Updraft")
	local stats = if level then statsAt(level) else nil
	if not stats or stats.behaviour ~= "Slam" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local center = character:GetAttribute("UpdraftSlamPos")
	if
		not humanoid
		or not Health.isAlive(humanoid)
		or not root
		or not root:IsA("BasePart")
		or typeof(center) ~= "Vector3"
	then
		return
	end
	local params = api.worldParams()
	local hinder: number? = stats.slamHinder
	local hits = 0
	for _, model in Target.combatants() do
		if model == character or not Target.alive(model) or Teams.isAlly(player, model) then
			continue
		end
		local body = model:FindFirstChild("HumanoidRootPart")
		local point = if body and body:IsA("BasePart")
			then body.Position
			else Target.aimPoint(model)
		if
			point
			and (point - center).Magnitude <= stats.slamRadius
			and Target.visible(center, model, params)
		then
			api.damage(player, model, stats.slamDamage, point, "Updraft")
			if hinder then
				api.status(model, "Hinder", hinder)
			end
			hits += 1
		end
	end
	local feet = center - Vector3.new(0, humanoid.HipHeight + root.Size.Y * 0.5, 0)
	api.fx(player, "Updraft", "UpdraftSlam", {
		at = feet,
		radius = stats.slamRadius,
		hits = hits,
		hinder = hinder ~= nil,
	})
end

local module: Types.ModModule = {}

module.simCast = function(ctx: Types.SimCtx): boolean
	local root = ctx.root
	local character = ctx.character
	local gravity = gravityOf(ctx.player)
	local up = Updraft.launchSpeed(ctx.stats.peak, gravity)
	local vel = root.AssemblyLinearVelocity
	-- Straight up, from whatever you were doing (a fall is reset).
	root.AssemblyLinearVelocity = Vector3.new(vel.X, up, vel.Z)
	-- Carry the running speed through the air (Movement's air speed), like a
	-- slide-jump, up to maxCarry (a dash's 80 studs/s isn't running speed):
	-- the counter-play is a predictable arc.
	local flat = (vel * Vector3.new(1, 0, 1)).Magnitude
	local carry =
		math.clamp(flat, Movement.WALK_SPEED, math.max(ctx.stats.maxCarry, Movement.WALK_SPEED))
	character:SetAttribute("SlideJumpSpeed", carry)
	character:SetAttribute("UpdraftAt", ctx.now)
	character:SetAttribute("UpdraftLaunch", Vector3.new(up, gravity, ctx.stats.gunDown))
	character:SetAttribute("Updrafting", true)
	-- A new launch mid-slam cancels the slam.
	endSlam(character)
	return true
end

-- Watches every character's slam landings (the server's simulation writes
-- UpdraftSlamAt; a value seen on the first look is old).
module.server = function(api: Types.ServerApi)
	local seen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end
			local at = number(character, "UpdraftSlamAt", 0)
			local last = seen[character]
			seen[character] = at
			if last ~= nil and at > last then
				slamLanded(api, player, character)
			end
		end
	end)
end

Updraft.module = module

return Updraft
