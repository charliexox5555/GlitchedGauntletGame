--!strict
-- Placeable building block (Launch Pad, Firewall). "Placed things go where
-- you're looking" (Mods.md rule 1): a spot on walkable ground within `range`
-- along the aim, facing the aim's yaw, with room for the object and a clear
-- line from the head. The client runs it every frame for the hologram (green /
-- red) and the server runs the same check from its own head before placing.

export type Spot = {
	cframe: CFrame, -- the object's centre, facing the aim (LookVector = forward)
	valid: boolean,
	reason: string?,
}

local Players = game:GetService("Players")

local Placeable = {}

local MIN_UP = 0.7 -- ground must face up at least this much (normal.Y)

local function flatLook(dir: Vector3): Vector3
	local flat = dir * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- What can be in the way of a placed object: world parts and other Mod
-- objects; bodies too when `bodies` (a wall mustn't trap anyone; a pad under
-- someone's feet is fine). Effects and previews never count.
function Placeable.overlap(bodies: boolean): OverlapParams
	local exclude: { Instance } = {}
	for _, name in { "Effects", "ModFx", "ModPreview" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	if not bodies then
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		local dummies = workspace:FindFirstChild("Dummies")
		if dummies then
			table.insert(exclude, dummies)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

-- `size`: the object's box (X across, Y up, Z along the aim). `params`:
-- world-only raycasts. `overlap`: what counts as in the way of the box.
function Placeable.find(
	origin: Vector3,
	dir: Vector3,
	range: number,
	size: Vector3,
	params: RaycastParams,
	overlap: OverlapParams
): Spot
	local look = flatLook(dir)
	local ground: Vector3? = nil
	local hit = workspace:Raycast(origin, dir * range, params)
	if hit and hit.Normal.Y >= MIN_UP then
		ground = hit.Position
	else
		-- Aiming at a wall or into the air: drop straight down from the end
		-- (backed off a wall by half the object, so it fits in front of it).
		local probe = if hit
			then hit.Position - look * (size.Z / 2 + 0.3) + hit.Normal * 0.1
			else origin + dir * range
		local down = workspace:Raycast(probe, Vector3.new(0, -(range + 8), 0), params)
		if down and down.Normal.Y >= MIN_UP then
			ground = down.Position
		end
	end
	if not ground then
		local fallback = CFrame.lookAt(origin + dir * range, origin + dir * range + look)
		return { cframe = fallback, valid = false, reason = "No ground there" }
	end
	local center = ground + Vector3.new(0, size.Y / 2 + 0.05, 0)
	local cframe = CFrame.lookAt(center, center + look)
	-- Room for it (shrunk a touch so resting on the floor doesn't count).
	local inside =
		workspace:GetPartBoundsInBox(cframe, size * 0.92 - Vector3.new(0, 0.1, 0), overlap)
	for _, part in inside do
		local body = part.Parent ~= nil and part.Parent:FindFirstChildOfClass("Humanoid") ~= nil
		if part.CanCollide or body then
			return { cframe = cframe, valid = false, reason = "No room there" }
		end
	end
	-- A clear line from the head to it.
	local to = center + Vector3.new(0, math.min(size.Y / 2, 1), 0)
	local block = workspace:Raycast(origin, to - origin, params)
	if block and block.Distance < (to - origin).Magnitude - 1 then
		return { cframe = cframe, valid = false, reason = "Can't see there" }
	end
	return { cframe = cframe, valid = true }
end

return Placeable
