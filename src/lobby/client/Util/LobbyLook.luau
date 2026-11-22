--!strict
-- One place that gives every lobby screen the chunky look (vault/02 Art/UI
-- Shop.md → Plate look pass 4): which cells get Util/Cards' skin, which
-- templates' clones do, and the text re-measure (Util/TextFit). Slanted
-- plates are finished by each screen's controller (Util/Plates.deepen).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

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
	Shop = join({ "Card", "CasePanel", "OddsPanel", "Plate", "View", "Back" }, range("Day", 7)), -- Plate: the tabs
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
	Profile = { "Card", "Stat1", "Stat2", "Stat3" },
}

-- No lobby words under this size (design px): Fredoka One smears below it,
-- and the player list's column heads were drawn at 8 px (overhaul review).
local TEXT_FLOOR = 12

-- Big white words get a dark outline, like RIVALS' headings (their file:
-- black, 2 px, on most words), so titles hold over art and bright plates.
-- Words on slanted plates are skipped: Util/Plates outlines those in the
-- plate's own colour.
local TITLE_SIZE = 26
local WHITE = Color3.new(1, 1, 1)

local function onPlate(d: Instance): boolean
	local p = d.Parent
	while p and not p:IsA("LayerCollector") do
		if p:FindFirstChild("CapL") or StateValues.get(p, "Plated") == true then
			return true
		end
		p = p.Parent
	end
	return false
end

local function floorText(d: Instance)
	if not (d:IsA("TextLabel") or d:IsA("TextButton")) then
		return
	end
	if not d.TextScaled and d.TextSize < TEXT_FLOOR then
		d.TextSize = TEXT_FLOOR
	end
	if
		d:IsA("TextLabel")
		and d.TextSize >= TITLE_SIZE
		and d.TextColor3 == WHITE
		and not d:FindFirstChildOfClass("UIStroke")
		and not onPlate(d)
	then
		local s = Instance.new("UIStroke")
		s.Name = "TitleOutline"
		s.Color = Color3.new(0, 0, 0)
		s.Transparency = 0.45
		s.Thickness = 2.5
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = d
	end
end

-- templates whose clones are cells wherever they land
local TEMPLATES = {
	"PlayerRow",
	"ShopContentCell",
	"PartyPlayerCard",
	"GunCard",
	"SkinTile",
	"SettingRow",
	"ProfileSkin",
	"RewardRow",
}

function LobbyLook.apply(playerGui: Instance)
	local folder = UiRoot.findTemplates(5)
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
