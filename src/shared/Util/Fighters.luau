--!strict
-- Everyone fighting in this server: players' characters and the AI bots'
-- models (Workspace.Dummies, attribute IsBot). One place for the rule, used
-- by the replay, spectating and the match-end scene.

local Players = game:GetService("Players")

local Fighters = {}

export type Fighter = {
	holder: Instance, -- what carries the fighter's attributes: a Player, or the bot's model
	body: Model,
}

-- Every fighter's body.
function Fighters.bodies(): { Model }
	local list: { Model } = {}
	for _, p in Players:GetPlayers() do
		local body = p.Character
		if body then
			table.insert(list, body)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("IsBot") == true then
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
		if p ~= except and body then
			table.insert(list, { holder = p, body = body })
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("IsBot") == true then
				table.insert(list, { holder = m, body = m })
			end
		end
	end
	return list
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
