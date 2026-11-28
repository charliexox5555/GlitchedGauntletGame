--!strict
-- Target building block (Heal Orb; later reveals and marks). Finds live
-- combatants (player characters and anything in workspace.Dummies), checks
-- line of sight against world geometry, and picks the ally nearest the
-- crosshair. The client uses it to highlight; the server re-runs the same
-- checks from its own head before healing.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Health = require(script.Parent.Parent.Parent.Health)
local Teams = require(script.Parent.Parent.Teams)
local Smoke = require(script.Parent.Smoke)

local Target = {}

function Target.alive(model: Model?): boolean
	local h = model and model:FindFirstChildOfClass("Humanoid")
	return Health.isAlive(h)
end

-- The Range's moving training bots (Lobby RangeBots BOT_TAG): they live in the Range map, not workspace.Dummies.
local RANGE_BOT_TAG = "RangeBot"

-- Every combatant model: player characters, then dummies, then the Range's bots (owner 2026-11-27: powers must
-- work on the Range bots too; Electric Shock never latched onto them).
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
	for _, m in CollectionService:GetTagged(RANGE_BOT_TAG) do
		if
			m:IsA("Model")
			and m:IsDescendantOf(workspace)
			and m:FindFirstChildOfClass("Humanoid")
		then
			if not table.find(out, m) then
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
			local hit = workspace:Raycast(from, to - from, params)
			-- reaching the body itself counts (the Range's bots stand in the map, so world rays can hit them)
			if not hit or hit.Instance:IsDescendantOf(model) then
				return true
			end
		end
	end
	return false
end

-- Can a power's "eye" at `from` (a Recon dart, a Roller, a Flash, the Electric Shock orb) detect `model`? A clear
-- line through the world AND no Smoke dome in the way (Blocks/Smoke: an eye inside a dome sees inside it). Use for
-- detection, not for physical effects: fire, frost and blasts still reach through smoke.
function Target.sees(from: Vector3, model: Model, params: RaycastParams): boolean
	local point = Target.aimPoint(model)
	if point and Smoke.blocks(from, point) then
		return false
	end
	return Target.visible(from, model, params)
end

-- Where `model` looks: a player's server copy of the camera when there is
-- one (Server Authority on), else the body's facing tilted by the
-- replicated AimPitch (players report it, bots publish it).
function Target.lookOf(model: Model): Vector3
	local who = Players:GetPlayerFromCharacter(model)
	if who then
		local ok, state = pcall(function()
			return (who :: any):GetCameraState()
		end)
		local cf = if ok and typeof(state) == "table" then state.CFrame else nil
		if typeof(cf) == "CFrame" then
			return cf.LookVector
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	local basis = if root and root:IsA("BasePart")
		then root
		elseif head and head:IsA("BasePart") then head
		else nil
	if not basis then
		return Vector3.new(0, 0, -1)
	end
	local flat = basis.CFrame.LookVector * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local pitchAttr = if who
		then StateValues.get(who, "AimPitch")
		else StateValues.get(model, "AimPitch")
	local pitch = if typeof(pitchAttr) == "number" and pitchAttr == pitchAttr
		then math.clamp(pitchAttr, -1.5, 1.5)
		else 0
	return flat * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
end

-- Live allies of `owner` (a Player), not counting `owner`'s own character.
function Target.allies(owner: Player): { Model }
	local out: { Model } = {}
	for _, m in Target.combatants() do
		if m ~= Teams.characterOf(owner) and Target.alive(m) and Teams.isAlly(owner, m) then
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
