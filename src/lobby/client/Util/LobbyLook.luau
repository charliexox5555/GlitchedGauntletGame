--!strict
-- One place that gives every lobby screen the chunky look (vault/02 Art/UI
-- Shop.md → Plate look pass 4): which cells get Util/Cards' skin, which
-- templates' clones do, and the text re-measure (Util/TextFit). Slanted
-- plates are finished by each screen's controller (Util/Plates.deepen).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(script.Parent.Cards)
local TextFit = require(script.Parent.TextFit)

local LobbyLook = {}

local function range(prefix: string, n: number): { string }
	local out = {}
	for i = 1, n do
		table.insert(out, prefix .. i)
	end
	return out
end

local function join(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		for _, s in list do
			table.insert(out, s)
		end
	end
	return out
end

-- ScreenGui → the named cells in it
local CELLS: { [string]: { string } } = {
	Shop = join(
		{ "Card", "CasePanel", "OddsPanel", "ItemCard", "Plate", "View", "Back" },
		range("Day", 7)
	), -- Plate: the tabs
	BattlePass = join(
		{ "FreeBadge", "PremiumBadge", "Box", "Prev", "Next", "OddsPanel", "Card" },
		range("Free", 7),
		range("Premium", 7)
	),
	PlayMenu = { "1v1", "2v2", "3v3", "4v4", "5v5", "Beginner2v2" },
	PartyMenu = join(range("Slot", 3), { "Search", "Invite", "InviteFriends", "Leave" }),
	Locker = { "SKIN", "CHARM", "FINISHER" },
	LobbyPlayerList = { "Head" },
	LobbyToast = { "Accept", "Decline" },
	LobbySearch = { "Bar", "Cancel" }, -- the searching bar and its cancel
	Settings = { "Inspect" },
}

-- No lobby words under this size (design px): Fredoka One smears below it,
-- and the player list's column heads were drawn at 8 px (overhaul review).
local TEXT_FLOOR = 12

local function floorText(d: Instance)
	if
		(d:IsA("TextLabel") or d:IsA("TextButton"))
		and not d.TextScaled
		and d.TextSize < TEXT_FLOOR
	then
		d.TextSize = TEXT_FLOOR
	end
end

-- templates whose clones are cells wherever they land
local TEMPLATES =
	{ "PlayerRow", "ShopContentCell", "PartyPlayerCard", "GunCard", "SkinTile", "SettingRow" }

function LobbyLook.apply(playerGui: Instance)
	local folder = ReplicatedStorage:FindFirstChild("UiTemplates")
	local lobby = folder and folder:FindFirstChild("Lobby")
	if lobby then
		for _, name in TEMPLATES do
			local t = lobby:FindFirstChild(name)
			if t then
				Cards.mark(t)
				for _, d in t:GetDescendants() do
					floorText(d)
				end
			end
		end
	end
	local seen: { [Instance]: boolean } = {}
	local function take(g: Instance)
		if g:IsA("ScreenGui") and not seen[g] then
			seen[g] = true
			Cards.watch(g, CELLS[g.Name] or {})
			for _, d in g:GetDescendants() do
				floorText(d)
			end
			g.DescendantAdded:Connect(floorText)
		end
	end
	for _, g in playerGui:GetChildren() do
		take(g)
	end
	playerGui.ChildAdded:Connect(take) -- screens copied in after this runs
	TextFit.watch(playerGui)
end

return LobbyLook
