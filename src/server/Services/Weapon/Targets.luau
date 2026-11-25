--!strict
-- What a shot can hit and what stops it (WeaponService, Weapon/Hits,
-- Weapon/Damage): live combatants, real hitboxes, and the wall check every
-- shot gets. A plain module: no init/start (the server boots only the
-- ModuleScripts directly in Services; this one sits in the Weapon folder).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BallisticGlass = require(Shared.Util.BallisticGlass)
local Combat = require(Shared.Config.Combat)
local Health = require(Shared.Health)
local Types = require(Shared.Types)

local Penetration = require(Shared.Util.Penetration)
local MapGlass = require(script.Parent.Parent.MapGlass)
local ModEntities = require(script.Parent.Parent.ModEntities)
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

-- Glass can break on a miss, so follow the accepted pellet directions even
-- when the client reported no hit. Stop at bodies and cover the round cannot pass.
function Targets.shatterGlass(
	shooter: Model,
	origin: Vector3,
	dirs: { Vector3 },
	config: Types.WeaponConfig
)
	if config.melee or #CollectionService:GetTagged(BallisticGlass.TAG) == 0 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, dir in dirs do
		params.FilterDescendantsInstances = { shooter }
		local budget = Penetration.budget(config.penetration)
		local from = origin
		local remaining = config.range
		for _ = 1, 8 do
			local hit = BallisticGlass.raycast(from, dir * remaining, params, MapGlass.shatter)
			if not hit then
				break
			end
			local part = hit.Instance
			local model = combatantOf(part)
			if model then
				if Targets.liveHumanoid(model) and not config.pierceCharacters then
					break
				end
				params:AddToFilter(model)
			elseif
				ModEntities.isObject(part) or not Penetration.pass(budget, part, hit.Position, dir)
			then
				break
			else
				params:AddToFilter(part)
			end
			remaining -= (hit.Position - from).Magnitude
			from = hit.Position
			if remaining <= 0 then
				break
			end
		end
	end
end

-- Traces a round from `from` to `to` through the world. Returns whether
-- something it can't get through stops it, and the share of its damage left
-- after the walls it did pass (Util/Penetration; 1 = nothing in the way).
function Targets.path(
	exclude: { Instance },
	from: Vector3,
	to: Vector3,
	penetration: Types.Penetration
): (boolean, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local span = to - from
	if span.Magnitude < 0.5 then
		return false, 1
	end
	local dir = span.Unit
	local budget = Penetration.budget(penetration)
	local origin = from
	for _ = 1, 6 do
		local left = (to - origin).Magnitude - 0.5
		if left <= 0 then
			return false, budget.mult
		end
		local result = workspace:Raycast(origin, dir * left, params)
		if not result then
			return false, budget.mult
		end
		local part = result.Instance
		if combatantOf(part) then
			return false, budget.mult -- hit the dummy/character body itself
		end
		if not Penetration.pass(budget, part, result.Position, dir) then
			return true, 0
		end
		params:AddToFilter(part)
		origin = result.Position
	end
	return true, 0
end

-- Is there solid world geometry between `from` and `to` that this gun can't go through?
function Targets.blocked(
	exclude: { Instance },
	from: Vector3,
	to: Vector3,
	penetration: Types.Penetration
): boolean
	local stopped = Targets.path(exclude, from, to, penetration)
	return stopped
end

return Targets
