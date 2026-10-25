--!strict
-- Seeded shot spread. The client and server both run this with the same seed,
-- so the server can recompute exactly where each pellet was allowed to go.

local Spread = {}

local function basis(dir: Vector3): CFrame
	local up = if math.abs(dir.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(Vector3.zero, dir, up)
end

-- A random direction inside a cone of `degrees` around `aim` (uniform over the cone's disk).
function Spread.cone(aim: Vector3, rng: Random, degrees: number): Vector3
	if degrees <= 0 then
		return aim.Unit
	end
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	return (basis(aim.Unit) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Directions for one trigger pull: the whole shot is offset by `spread`, then
-- each pellet scatters by `pelletSpread` around that.
function Spread.shot(
	aim: Vector3,
	seed: number,
	pellets: number,
	spread: number,
	pelletSpread: number
): { Vector3 }
	local rng = Random.new(seed)
	local center = Spread.cone(aim, rng, spread)
	if pellets <= 1 then
		return { center }
	end
	local dirs = table.create(pellets)
	for i = 1, pellets do
		dirs[i] = Spread.cone(center, rng, pelletSpread)
	end
	return dirs
end

-- Seed for shot number `index` of a player's sequence. The server hands out
-- `base` (in WeaponState), so a client can't shop for a lucky spread seed.
function Spread.seedFor(base: number, index: number): number
	return (base * 31 + index * 7919) % 2147483647
end

-- Angle in degrees between two directions.
function Spread.angle(a: Vector3, b: Vector3): number
	local d = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
	return math.deg(math.acos(d))
end

return Spread
