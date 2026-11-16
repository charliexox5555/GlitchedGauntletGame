--!strict
-- Shooting through walls (Config/Combat PENETRATION, vault/01 Design/Gun
-- Balance.md → Wall penetration). One rule for the three places a round is
-- traced: the shooter's client (WeaponController), the server's check of a
-- claimed hit (Weapon/Targets) and the bots' own shots (Bots/BotGun).
--
-- A gun's penetration class gives each round a budget: how many studs of wall
-- it may pass in total, through how many walls, and what share of its damage
-- survives each wall. A wall is measured along the round's own line, so a
-- thin sheet hit at a shallow angle counts as thick. Parts tagged ThinWall
-- (a plywood sheet, a fence) always count as THIN_WALL_DEPTH. Terrain stops
-- everything.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Combat = require(script.Parent.Parent.Config.Combat)
local Types = require(script.Parent.Parent.Types)

local Penetration = {}

-- What one round has left. `mult` is the share of its damage still carried.
export type Budget = { depth: number, walls: number, mult: number, loss: number }

local backParams = RaycastParams.new()
backParams.FilterType = Enum.RaycastFilterType.Include

function Penetration.budget(kind: Types.Penetration): Budget
	local p = Combat.PENETRATION[kind]
	return { depth = p.depth, walls = p.walls, mult = 1, loss = p.damage }
end

-- How thick `part` is along `dir` (unit) from where the round entered it at
-- `position`, up to `reach` studs; nil when it's thicker than that.
local function thickness(part: BasePart, position: Vector3, dir: Vector3, reach: number): number?
	if CollectionService:HasTag(part, Combat.THIN_WALL_TAG) then
		return math.min(Combat.THIN_WALL_DEPTH, reach)
	end
	-- Look back at the part from `reach` studs past the entry point: if that
	-- point is still inside it nothing is hit, and the wall is too thick.
	backParams.FilterDescendantsInstances = { part }
	local span = reach + 0.05
	local back = Workspace:Raycast(position + dir * span, -dir * span, backParams)
	if not back then
		return nil
	end
	return (back.Position - position).Magnitude
end

-- Tries to take the round through `part`, which it entered at `position`
-- travelling along `dir` (unit). True when it passes: the budget is charged
-- and `mult` drops. False: the round stops here.
function Penetration.pass(b: Budget, part: Instance, position: Vector3, dir: Vector3): boolean
	if b.walls <= 0 or b.depth <= 0 or not part:IsA("BasePart") or part:IsA("Terrain") then
		return false
	end
	local t = thickness(part, position, dir, b.depth)
	if not t or t > b.depth then
		return false
	end
	b.depth -= t
	b.walls -= 1
	b.mult *= b.loss
	return true
end

return Penetration
