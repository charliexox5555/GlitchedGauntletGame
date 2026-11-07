--!strict
-- What a shot can hit and what stops it (WeaponService, Weapon/Hits,
-- Weapon/Damage): live combatants, real hitboxes, and the wall check every
-- shot gets. A plain module: no init/start (the server boots only the
-- ModuleScripts directly in Services; this one sits in the Weapon folder).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Health = require(Shared.Health)
local Types = require(Shared.Types)

local Targets = {}

function Targets.liveHumanoid(model: Model?): Humanoid?
	if not model then
		return nil
	end
	local h = model:FindFirstChildOfClass("Humanoid")
	if h and Health.isAlive(h) then
		return h
	end
	return nil
end

-- The combatant a part is a hitbox of: only real body parts that are direct
-- children of a character (never hats, held guns or other accessories).
function Targets.hitboxOwner(part: Instance): Model?
	if not Combat.BODY_PARTS[part.Name] then
		return nil
	end
	local model = part.Parent
	if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

-- Any combatant model a part belongs to (used to let bodies not count as walls).
local function combatantOf(part: Instance): Model?
	local node: Instance? = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Things a wall check should ignore: the shooter and every combatant (bodies
-- don't count as walls; they're validated as hitboxes separately).
function Targets.wallExclusions(shooter: Model): { Instance }
	local exclude: { Instance } = { shooter }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(exclude, dummies)
	end
	return exclude
end

-- Is there solid world geometry between `from` and `to` that this gun can't go through?
function Targets.blocked(
	exclude: { Instance },
	from: Vector3,
	to: Vector3,
	penetration: Types.Penetration
): boolean
	if penetration == "All" then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.5 then
		return false
	end
	local origin = from
	for _ = 1, 4 do
		local result = workspace:Raycast(
			origin,
			(to - origin).Unit * math.max((to - origin).Magnitude - 0.5, 0),
			params
		)
		if not result then
			return false
		end
		local part = result.Instance
		if combatantOf(part) then
			return false -- hit the dummy/character body itself
		end
		if penetration == "ThinWall" and CollectionService:HasTag(part, Combat.THIN_WALL_TAG) then
			params:AddToFilter(part)
			origin = result.Position
		else
			return true
		end
	end
	return true
end

return Targets
