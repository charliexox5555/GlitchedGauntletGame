--!strict
-- Target building block (Patch Up; later reveals and marks). Finds live
-- combatants (player characters and anything in workspace.Dummies), checks
-- line of sight against world geometry, and picks the ally nearest the
-- crosshair. The client uses it to highlight; the server re-runs the same
-- checks from its own head before healing.

local Players = game:GetService("Players")

local Teams = require(script.Parent.Parent.Teams)

local Target = {}

function Target.alive(model: Model?): boolean
	local h = model and model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

-- Every combatant model: player characters, then dummies.
function Target.combatants(): { Model }
	local out: { Model } = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			table.insert(out, c)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
				table.insert(out, m)
			end
		end
	end
	return out
end

-- The point we aim heals and line-of-sight checks at (the chest).
function Target.aimPoint(model: Model): Vector3?
	for _, name in { "UpperTorso", "Torso", "HumanoidRootPart", "Head" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part.Position
		end
	end
	return nil
end

-- Nothing in `params` (world geometry) between `from` and the model's chest
-- or head.
function Target.visible(from: Vector3, model: Model, params: RaycastParams): boolean
	for _, name in { "UpperTorso", "Torso", "Head" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local to = part.Position
			if not workspace:Raycast(from, to - from, params) then
				return true
			end
		end
	end
	return false
end

-- Live allies of `owner` (a Player), not counting `owner`'s own character.
function Target.allies(owner: Player): { Model }
	local out: { Model } = {}
	for _, m in Target.combatants() do
		if m ~= owner.Character and Target.alive(m) and Teams.isAlly(owner, m) then
			table.insert(out, m)
		end
	end
	return out
end

-- Angle in degrees between the aim and the direction to `model`.
function Target.angle(origin: Vector3, dir: Vector3, model: Model): number
	local point = Target.aimPoint(model)
	if not point then
		return math.huge
	end
	local to = point - origin
	if to.Magnitude < 1e-3 then
		return 0
	end
	return math.deg(math.acos(math.clamp(to.Unit:Dot(dir.Unit), -1, 1)))
end

-- The candidate nearest the crosshair: within `range` studs, within
-- `maxAngle` degrees of the aim, and in sight.
function Target.pick(
	origin: Vector3,
	dir: Vector3,
	range: number,
	maxAngle: number,
	candidates: { Model },
	params: RaycastParams
): Model?
	local best: Model? = nil
	local bestAngle = maxAngle
	for _, m in candidates do
		local point = Target.aimPoint(m)
		if point and (point - origin).Magnitude <= range then
			local a = Target.angle(origin, dir, m)
			if a <= bestAngle and Target.visible(origin, m, params) then
				best = m
				bestAngle = a
			end
		end
	end
	return best
end

return Target
