--!strict
-- Everyone fighting in this server: players' characters and the AI bots'
-- models (Workspace.Dummies, attribute IsBot). One place for the rule, used
-- by the replay, spectating and the match-end scene.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)
local PlayZone = require(game:GetService("ReplicatedStorage").Shared.PlayZone)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Fighters = {}

local function inScope(inst: Instance): boolean
	if RunService:IsClient() and Players.LocalPlayer then
		return PlayZone.inSameScope(Players.LocalPlayer, inst)
	end
	return true
end

function Fighters.botBody(id: string): Model?
	local folder = workspace:FindFirstChild("Dummies")
	if folder then
		for _, model in folder:GetChildren() do
			if
				model:IsA("Model")
				and StateValues.get(model, "IsBot") == true
				and "b" .. tostring(StateValues.get(model, "BotId")) == id
				and inScope(model)
			then
				return model
			end
		end
	end
	return nil
end

export type Fighter = {
	holder: Instance, -- what carries the fighter's attributes: a Player, or the bot's model
	body: Model,
}

-- Every fighter's body.
function Fighters.bodies(): { Model }
	local list: { Model } = {}
	for _, p in Players:GetPlayers() do
		local body = p.Character
		if body and inScope(p) then
			table.insert(list, body)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and StateValues.get(m, "IsBot") == true and inScope(m) then
				table.insert(list, m)
			end
		end
	end
	return list
end

-- Every fighter with its attribute holder, leaving out `except` (a player).
function Fighters.all(except: Player?): { Fighter }
	local list: { Fighter } = {}
	for _, p in Players:GetPlayers() do
		local body = p.Character
		if p ~= except and body and inScope(p) then
			table.insert(list, { holder = p, body = body })
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and StateValues.get(m, "IsBot") == true and inScope(m) then
				table.insert(list, { holder = m, body = m })
			end
		end
	end
	return list
end

local function finite(v: unknown): number?
	return if typeof(v) == "number" and v == v and math.abs(v) < math.huge then v else nil
end

-- Where someone else is looking (yaw, pitch in radians), from what
-- replicates: a spectated bot's gun look (`AimGunYaw` / `AimGunPitch`, both
-- or neither, so yaw and pitch always agree), else the body's facing and
-- the reported `AimPitch` (players: WeaponService's Aim remote; bots: their
-- intended pitch, Bots/Brain). Used by spectating and the replay recorder.
function Fighters.lookOf(holder: Instance, body: Model): (number, number)
	local gunYaw = finite(StateValues.get(holder, "AimGunYaw"))
	local gunPitch = finite(StateValues.get(holder, "AimGunPitch"))
	if gunYaw and gunPitch then
		return gunYaw, math.clamp(gunPitch, -1.45, 1.45)
	end
	local yaw = 0
	local root = body:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
	end
	local pitch = finite(StateValues.get(holder, "AimPitch")) or 0
	return yaw, math.clamp(pitch, -1.45, 1.45)
end

-- The fighter body a part belongs to (a held gun is a Model inside it).
function Fighters.bodyOfPart(part: Instance): Model?
	local node = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

return Fighters
