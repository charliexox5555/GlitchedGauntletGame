--!strict
-- The first-person camera's crouch / slide height: a damped spring that
-- lowers the eye by Config/Movement CROUCH_CAMERA_DROP or SLIDE_CAMERA_DROP
-- (CAMERA_STIFFNESS, CAMERA_DAMPING_RATIO), so the dips feel weighty, not
-- snappy. Pure: MovementController runs it for your own camera, and
-- SpectateController / ReplayController run the same code on a watched
-- fighter's replicated `MoveState`, so their eye sits where theirs does.

local Juice = require(script.Parent.Config.Juice)
local Movement = require(script.Parent.Config.Movement)

local CameraDrop = {}

export type State = {
	drop: number, -- studs the eye is lowered now
	velocity: number, -- studs/s
}

function CameraDrop.new(): State
	return { drop = 0, velocity = 0 }
end

function CameraDrop.reset(s: State)
	s.drop = 0
	s.velocity = 0
end

-- Where the spring is heading for a move state (Idle | Walk | Sprint |
-- Crouch | Slide | Air).
function CameraDrop.target(moveState: string?): number
	if moveState == "Slide" then
		return Movement.SLIDE_CAMERA_DROP
	elseif moveState == "Crouch" then
		return Movement.CROUCH_CAMERA_DROP
	end
	return 0
end

-- A kick to the spring's speed (a landing dips the view).
function CameraDrop.impulse(s: State, velocity: number)
	s.velocity += velocity
end

-- Touching down after falling at `fallSpeed` (studs/s, the fastest of the
-- fall): the view dips by how hard (Juice LAND, k^2; its peak is about
-- v / (omega * e)). Returns k (0..1; 0 = too soft to dip).
function CameraDrop.land(s: State, fallSpeed: number): number
	local land = Juice.LAND
	if fallSpeed <= land.minFall then
		return 0
	end
	local k = math.min(fallSpeed / land.fullFall, 1)
	CameraDrop.impulse(s, land.dip * k * k * math.sqrt(Movement.CAMERA_STIFFNESS) * math.exp(1))
	return k
end

-- Leaving the ground on a jump: the eye trails the body, dipping about
-- `dip` studs (Juice JUMP.takeoffDip) and springing back.
function CameraDrop.takeoff(s: State, dip: number)
	if dip > 0 then
		CameraDrop.impulse(s, dip * math.sqrt(Movement.CAMERA_STIFFNESS) * math.exp(1))
	end
end

-- One frame. Returns the drop (studs to lower the eye).
function CameraDrop.step(s: State, moveState: string?, dt: number): number
	local target = CameraDrop.target(moveState)
	local stiffness = Movement.CAMERA_STIFFNESS
	local damping = 2 * math.sqrt(stiffness) * Movement.CAMERA_DAMPING_RATIO
	local accel = (target - s.drop) * stiffness - s.velocity * damping
	s.velocity += accel * dt
	s.drop += s.velocity * dt
	return s.drop
end

return CameraDrop
