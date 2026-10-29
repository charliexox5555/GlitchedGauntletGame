--!strict
-- Updraft (Mobility, was Launch Pad; vault/01 Design/Abilities/Updraft.md):
-- an instant launch straight up for yourself, peaking `peak` studs above
-- where you used it. Keeps your horizontal momentum (running + Updraft = an
-- arc); in the air it resets your fall like a double jump. Then a normal
-- fall. Predicted: simCast runs inside the simulation (Simulation/
-- Abilities), on the server for everyone and on your client for yourself;
-- Updraft.step holds the rise while the Humanoid is still on the floor.
--
-- Character attributes (simulation-written):
--   UpdraftAt     time() of the launch (clients play the effects on change)
--   UpdraftUp     the launch's vertical speed (studs/s)
--   UpdraftGravity  the gravity it was launched under (a status lowers it)
--   Updrafting    true from the launch until you land
--   UpdraftGunDown  seconds from the launch the gun is down (no shots; both
--                 sides gate on it, Mods/Dash.stepGate)

local Movement = require(script.Parent.Parent.Config.Movement)
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

-- Simulation, every step (before the cast): holds the rise, and ends the
-- Updraft on landing.
function Updraft.step(character: Model, humanoid: Humanoid, root: BasePart, now: number)
	if character:GetAttribute("Updrafting") ~= true then
		return
	end
	local since = now - number(character, "UpdraftAt", 0)
	if since < RISE_HOLD then
		local gravity = number(character, "UpdraftGravity", workspace.Gravity)
		local up = number(character, "UpdraftUp", 0) - gravity * since
		local vel = root.AssemblyLinearVelocity
		if vel.Y < up then
			root.AssemblyLinearVelocity = Vector3.new(vel.X, up, vel.Z)
		end
	elseif humanoid.FloorMaterial ~= Enum.Material.Air then
		character:SetAttribute("Updrafting", false) -- landed
	end
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
	character:SetAttribute("UpdraftUp", up)
	character:SetAttribute("UpdraftGravity", gravity)
	character:SetAttribute("Updrafting", true)
	character:SetAttribute("UpdraftGunDown", ctx.stats.gunDown)
	return true
end

Updraft.module = module

return Updraft
