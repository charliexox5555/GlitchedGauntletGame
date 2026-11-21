--!strict
-- Fills a case's CONTENTS list: one row per skin the case can give
-- (Shared/SkinCases.contents, from Config/Skins tiers and the skins in the game),
-- with a tier-coloured cell, the name in its tier colour, the tier and gun, and
-- its odds (adding up to 100%, before owned skins are re-rolled). Rows clone the
-- template UiTemplates.Lobby.ShopOddsRow. Used by the Shop and the Season Pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)

local OddsList = {}

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
	for i, e in SkinCases.contents(case.id) do
		local tier = Skins.TIERS[e.tier]
		local row = template:Clone()
		row.Name = "Row" .. i
		row.LayoutOrder = i;
		(child(row, "Cell") :: Frame).BackgroundColor3 = tier.color
		local name = child(row, "Name") :: TextLabel
		name.Text = SkinCases.name(e.gun, e.line)
		name.TextColor3 = tier.color;
		(child(row, "Sub") :: TextLabel).Text =
			string.format("%s SKIN  ·  %s", tier.name, string.upper(e.gun));
		(child(row, "Pct") :: TextLabel).Text = ShopCatalog.formatOdds(e.odds)
		row.Parent = list
	end
	list.CanvasPosition = Vector2.zero
end

return OddsList
