--!strict
-- Fills a case's CONTENTS list (Lobby/ShopCatalog): one row per outcome with a
-- rarity-coloured cell, the name in its rarity colour, rarity + kind + gun,
-- and its odds (from the weights, adding up to 100%). Rows clone the template
-- UiTemplates.Lobby.ShopOddsRow. Used by the Shop and the Season Pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)

local OddsList = {}

local WHITE = Color3.new(1, 1, 1)

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

function OddsList.fill(list: ScrollingFrame, case: ShopCatalog.Case)
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local template = ReplicatedStorage:WaitForChild("UiTemplates")
		:WaitForChild("Lobby")
		:WaitForChild("ShopOddsRow") :: Frame
	local odds = ShopCatalog.odds(case)
	for i, item in case.contents do
		local row = template:Clone()
		row.Name = "Row" .. i
		row.LayoutOrder = i
		local color = (if item.rarity then ShopCatalog.RARITY_COLOR[item.rarity] else nil) or WHITE;
		(child(row, "Cell") :: Frame).BackgroundColor3 = color
		local name = child(row, "Name") :: TextLabel
		name.Text = item.name
		name.TextColor3 = color;
		(child(row, "Sub") :: TextLabel).Text = string.format(
			"%s %s  ·  %s",
			string.upper(item.rarity or ""),
			string.upper(item.kind),
			string.upper(item.gun or "")
		);
		(child(row, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(odds[i])
		row.Parent = list
	end
	list.CanvasPosition = Vector2.zero
end

return OddsList
