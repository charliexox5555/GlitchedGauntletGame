--!strict
-- Gunplay v2 spread maths (vault/01 Design/Gunplay.md §2), shared so the
-- client shoots with exactly the spread the server recomputes from its own
-- state (WeaponService). Pure functions, degrees throughout.
--
--   cone = gun spread (first shot + spray growth, ADS and crouch multipliers)
--        + movement penalty (by horizontal speed, deadzone, landing; ADS halves it)

local Combat = require(script.Parent.Parent.Config.Combat)
local Movement = require(script.Parent.Parent.Config.Movement)
local Types = require(script.Parent.Parent.Types)

type WeaponConfig = Types.WeaponConfig

local Accuracy = {}

-- What the shooter is doing at the moment of a shot. `aim`: 0 hip .. 1 fully
-- aimed. `sinceLanding`: seconds since touching down.
export type Motion = {
	state: string, -- MoveState: Idle | Walk | Sprint | Crouch | Slide | Air
	speed: number, -- horizontal studs/s
	aim: number,
	sinceLanding: number,
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Spray heat after `sinceLast` seconds without firing. Holding the trigger
-- (shots no further apart than the gun's fire interval, plus a margin) keeps
-- all of it; after that it cools linearly, reaching 0 at recoveryTime, so a
-- short pause keeps part of the spread.
function Accuracy.cool(config: WeaponConfig, heat: number, sinceLast: number): number
	local hold = config.fireInterval * Combat.SPRAY_HOLD
	local recovery = config.spread.recoveryTime
	if sinceLast <= hold then
		return heat
	elseif recovery <= hold then
		return 0
	end
	return heat * math.clamp(1 - (sinceLast - hold) / (recovery - hold), 0, 1)
end

-- Spread added by `heat` shots of spraying (protected shots first).
function Accuracy.growth(spread: Types.SpreadStats, heat: number): number
	local h = math.max(heat, 0)
	local protected = math.min(h, spread.protected)
	return protected * spread.protectedGrowth + math.max(h - spread.protected, 0) * spread.growth
end

-- The gun's own cone at `heat`, aimed by `aim` (0..1), crouched or not.
function Accuracy.gun(config: WeaponConfig, heat: number, aim: number, crouched: boolean): number
	local s = config.spread
	local cone = math.clamp(
		s.first + Accuracy.growth(s, heat),
		math.min(s.first, s.max),
		math.max(s.first, s.max)
	)
	cone *= lerp(1, s.adsMultiplier, math.clamp(aim, 0, 1))
	if crouched then
		cone *= Combat.CROUCH_SPREAD
	end
	return cone
end

-- Extra spread from moving: smooth in horizontal speed, nothing inside the
-- deadzone, fixed values sliding and in the air, plus a moment after landing.
function Accuracy.movement(config: WeaponConfig, motion: Motion): number
	local rows = Combat.MOVE_PENALTY :: { [string]: { [string]: number } }
	local row = rows[config.moveClass or config.class] or rows.Rifle
	local walk = Movement.WALK_SPEED
	local deadzone = Combat.MOVE_DEADZONE * walk
	local penalty = 0
	if motion.state == "Air" then
		penalty = row.air
	elseif motion.state == "Slide" then
		penalty = row.slide
	elseif motion.speed > deadzone then
		if motion.state == "Crouch" then
			local t = (motion.speed - deadzone) / math.max(Movement.CROUCH_SPEED - deadzone, 0.1)
			penalty = row.crouchWalk * math.clamp(t, 0, 1)
		elseif motion.speed <= walk then
			penalty = row.walk * (motion.speed - deadzone) / (walk - deadzone)
		else
			local t = (motion.speed - walk) / (Movement.SPRINT_SPEED - walk)
			penalty = lerp(row.walk, row.sprint, math.clamp(t, 0, 1))
		end
	end
	if motion.sinceLanding < Combat.LANDING_TIME then
		penalty += Combat.LANDING_PENALTY
	end
	return penalty * lerp(1, Combat.ADS_MOVE_PENALTY, math.clamp(motion.aim, 0, 1))
end

-- The whole cone for a shot, and whether it's centre-biased (no movement penalty).
function Accuracy.cone(config: WeaponConfig, heat: number, motion: Motion): (number, boolean)
	local move = Accuracy.movement(config, motion)
	return Accuracy.gun(config, heat, motion.aim, motion.state == "Crouch") + move, move <= 0
end

return Accuracy
