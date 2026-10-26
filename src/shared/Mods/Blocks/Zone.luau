--!strict
-- Zone building block (Lag Field; later heal pads, burn zones, Zero-G). A
-- vertical cylinder on the ground: `radius` across, `height` up from its
-- centre point and a little below it.

export type Zone = {
	center: Vector3, -- on the ground
	radius: number,
	height: number,
}

local Zone = {}

local BELOW = 2 -- studs below the centre that still count (slopes, steps)

function Zone.contains(zone: Zone, point: Vector3): boolean
	local d = point - zone.center
	if d.Y < -BELOW or d.Y > zone.height then
		return false
	end
	return Vector2.new(d.X, d.Z).Magnitude <= zone.radius
end

return Zone
