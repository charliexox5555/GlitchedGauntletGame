--!strict
-- Dash building block (Blink, later Burst/Ghost/Desync). Pure maths plus one
-- spherecast, safe inside the simulation: which way to go, and how far before
-- a wall.

local Dash = {}

-- Flat unit direction: where you're moving, or where you face when still.
function Dash.direction(moveDirection: Vector3, look: Vector3): Vector3?
	local flatMove = moveDirection * Vector3.new(1, 0, 1)
	if flatMove.Magnitude > 0.1 then
		return flatMove.Unit
	end
	local flatLook = look * Vector3.new(1, 0, 1)
	if flatLook.Magnitude > 0.01 then
		return flatLook.Unit
	end
	return nil
end

-- How far a sphere of `radius` gets from `origin` along `dir` (up to
-- `distance`), stopping short of the first thing in the way.
function Dash.reach(
	origin: Vector3,
	dir: Vector3,
	distance: number,
	radius: number,
	params: RaycastParams
): number
	local hit = workspace:Spherecast(origin, radius, dir * distance, params)
	if hit then
		return math.max(hit.Distance - 0.25, 0)
	end
	return distance
end

return Dash
