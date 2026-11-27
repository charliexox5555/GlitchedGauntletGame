--!strict
-- A player's profile card (vault/02 Art/UI Lobby Overhaul.md → Missing
-- screens): Studio-built StarterGui.Profile + UiTemplates.Lobby.ProfileSkin
-- (tools/studio/BuildProfileRewards.luau). Opened with a Player from their
-- row in the player list (Util/LobbyHudView), like RIVALS' ViewProfile.
-- Shows what the lobby really knows: portrait, names, level and win streak
-- (player attributes), the skins they have on (LockerSkins, with
-- each line's emblem), and since progression (2026-11-22, vault/01 Design/Progression.md)
-- an XP bar, MATCHES / WINS / ELIMS and a best streak + win rate line, all from the
-- attributes Shared/PlayerData publishes on every player. The card refreshes while open.
-- The button: OPEN LOCKER on your own card, INVITE TO PARTY on someone
-- else's (the same request the player list's INVITE sends; the server
-- validates and rate-limits it: server/Services/PartyService).
-- Titles (2026-11-27, vault/04 Tech/Battle Pass Build Plan.md phase 5): the TITLE plate in
-- the tags row shows anyone's equipped title (the "Title" state value). On your own card
-- it reads NO TITLE when none is on, and a click opens TITLES: every title you own plus
-- NONE; a pick goes to LockerRequest ("title", name). A newly earned title toasts here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Lobby.Config)
local Locker = require(ReplicatedStorage.Shared.Locker)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local LobbyHud = require(script.Parent.LobbyHud)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Plates = require(script.Parent.Parent.Util.Plates)
local Router = require(script.Parent.Parent.Util.Router)

local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

local ProfileController = {}

local player = Players.LocalPlayer
local C = LobbyKit.C
local MAX_SKINS = 4
local STREAK_HOT = Color3.fromHex("FF7026")
local STREAK_COLD = Color3.fromHex("252528")
local TITLE_ON = Color3.fromHex("FFC83D")
local TITLE_OFF = Color3.fromHex("2A2A31")

local gui: ScreenGui
local card: Frame
local skinTemplate: Frame
local shown: Player? = nil
local titleList: Frame
local optionTemplate: TextButton
local sentAt: { [number]: number } = {}

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function numberAttr(p: Player, name: string, default: number): number
	local v = StateValues.get(p, name)
	return if typeof(v) == "number" and v == v then v else default
end

local function setTag(tag: Frame, text: string)
	local tagLabel = child(tag, "Label") :: TextLabel
	tagLabel.Text = text
end

-- The skins they have on, with Stock left out.
local function equipped(p: Player): { { gun: string, line: string } }
	local out = {}
	for gun, value in Locker.equipped(p) do
		if value ~= "Stock" and value ~= "" then
			table.insert(out, { gun = gun, line = value })
		end
	end
	table.sort(out, function(a, b)
		return a.gun < b.gun
	end)
	return out
end

local function fill(p: Player)
	shown = p
	local portrait = child(card, "Portrait") :: Frame
	local shot = child(portrait, "Headshot") :: ImageLabel
	shot.Image = ""
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(
				p.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size180x180
			)
		end)
		if ok and shown == p then
			shot.Image = img
		end
	end)
	local displayName = child(card, "DisplayName") :: TextLabel
	displayName.Text = string.upper(p.DisplayName)
	local username = child(card, "Username") :: TextLabel
	username.Text = "@" .. p.Name
	local tags = child(card, "Tags") :: Frame
	setTag(child(tags, "Level"), "LV " .. numberAttr(p, "Level", 1))
	local streakTag = child(tags, "Streak") :: Frame
	local streak = numberAttr(p, "WinStreak", 0)
	setTag(streakTag, "STREAK " .. streak)
	-- a live streak reads in the streak orange (the bar's SAVE WINSTREAK colour)
	local hot = streak > 0
	streakTag.BackgroundColor3 = if hot then STREAK_HOT else STREAK_COLD
	for _, d in streakTag:GetDescendants() do
		if d.Name == "Skin" and d:IsA("ImageLabel") then
			d.ImageColor3 = streakTag.BackgroundColor3
		end
	end
	local streakText = streakTag:FindFirstChild("Label")
	if streakText and streakText:IsA("TextLabel") then
		streakText.TextColor3 = if hot then C.ink else C.white
	end
	local titleTag = tags:FindFirstChild("Title")
	if titleTag and titleTag:IsA("Frame") then
		local title = PlayerData.title(p)
		local mine = p == player
		titleTag.Visible = mine or title ~= nil
		setTag(titleTag, title or "NO TITLE")
		local pickB = titleTag:FindFirstChild("Pick")
		if pickB and pickB:IsA("GuiObject") then
			pickB.Visible = mine
		end
		if not mine and titleList then
			titleList.Visible = false
		end
	end
	local xpBar = card:FindFirstChild("XpBar")
	if xpBar then
		local fillFrame = xpBar:FindFirstChild("Fill", true)
		if fillFrame and fillFrame:IsA("Frame") then
			fillFrame.Size = UDim2.fromScale(math.clamp(numberAttr(p, "XpShare", 0), 0, 1), 1)
		end
		local xpValue = xpBar:FindFirstChild("Value")
		if xpValue and xpValue:IsA("TextLabel") then
			xpValue.Text =
				string.format("%d / %d XP", numberAttr(p, "Xp", 0), numberAttr(p, "XpNeed", 100))
		end
	end
	local matches, wins = numberAttr(p, "Matches", 0), numberAttr(p, "Wins", 0)
	local stats = card:FindFirstChild("Stats")
	local values = { matches, wins, numberAttr(p, "Kills", 0) }
	for i, v in values do
		local cell = stats and stats:FindFirstChild("Stat" .. i)
		local value = cell and cell:FindFirstChild("Value")
		if value and value:IsA("TextLabel") then
			value.Text = tostring(v)
		end
	end
	local note = card:FindFirstChild("StatsNote")
	if note and note:IsA("TextLabel") then
		note.Text = string.format(
			"BEST STREAK %d  ·  WIN RATE %d%%",
			numberAttr(p, "BestStreak", 0),
			if matches > 0 then math.round(wins / matches * 100) else 0
		)
	end

	local skins = child(card, "Skins") :: Frame
	LobbyKit.clearSlots(skins)
	local list = equipped(p)
	local none = child(skins, "None") :: TextLabel
	none.Visible = #list == 0
	for i, s in list do
		if i > MAX_SKINS then
			break
		end
		LobbyKit.slot(skinTemplate, skins, function(cell: Frame)
			cell.Name = "Skin" .. i
			cell.LayoutOrder = i
			StateValues.set(cell, "Slot", true)
			local emblem = child(cell, "Emblem") :: ImageLabel
			emblem.Image = Locker.EMBLEMS[s.line] or ""
			emblem.ImageColor3 = Locker.COLORS[s.line] or C.white
			local gunLabel = child(cell, "Gun") :: TextLabel
			gunLabel.Text = string.upper(Weapons.nameOf(s.gun))
			local line = child(cell, "Line") :: TextLabel
			line.Text = string.upper(s.line)
			line.TextColor3 = Locker.COLORS[s.line] or C.muted
		end)
	end

	local action = child(card, "Action") :: TextButton
	local label = child(action, "Label") :: TextLabel
	if p == player then
		action.BackgroundColor3 = C.white
		label.Text = "OPEN LOCKER"
		label.TextColor3 = C.ink
	else
		local at = sentAt[p.UserId]
		local sent = at ~= nil and os.clock() - at < Config.PARTY.inviteTtl
		action.BackgroundColor3 = if sent then C.navyHi else C.white
		label.Text = if sent then "INVITE SENT" else "INVITE TO PARTY"
		label.TextColor3 = if sent then C.muted else C.ink
	end
end

-- Their numbers change while the card is open (a match result, a streak save).
local REFRESH: { [string]: boolean } = {
	Level = true,
	Xp = true,
	XpShare = true,
	WinStreak = true,
	BestStreak = true,
	Matches = true,
	Wins = true,
	Kills = true,
	Title = true,
}
local watching: RBXScriptConnection? = nil
local function watch(p: Player?)
	if watching then
		watching:Disconnect()
		watching = nil
	end
	if p then
		watching = StateValues.anyChanged(p):Connect(function(name: string)
			if REFRESH[name] and shown == p and Router.current() == "Profile" then
				fill(p)
			end
		end)
	end
end

-- TITLES: every owned title (the one on in gold), then NONE.
local function fillTitleList()
	for _, c in titleList:GetChildren() do
		if c:IsA("TextButton") and c ~= optionTemplate then
			c:Destroy()
		end
	end
	local titles = PlayerData.titles(player)
	local rows: { string? } = {}
	for _, name in titles.owned do
		table.insert(rows, name)
	end
	local function add(name: string?, order: number)
		local b = optionTemplate:Clone()
		b.Name = "Pick"
		b.LayoutOrder = order
		b.Visible = true
		local on = titles.on == name
		b.BackgroundColor3 = if on then TITLE_ON else TITLE_OFF
		local label = child(b, "Label") :: TextLabel
		label.Text = if name then string.upper(name) else "NONE"
		label.TextColor3 = if on then C.ink else C.white
		LobbyKit.button(b, function()
			titleList.Visible = false
			if not on then
				LobbyNet.event("LockerRequest"):FireServer("title", name or "")
			end
		end)
		b.Parent = titleList
	end
	for i, name in rows do
		add(name, i)
	end
	add(nil, #rows + 1)
end

local function toggleTitleList()
	if shown ~= player then
		return
	end
	if titleList.Visible then
		titleList.Visible = false
		return
	end
	if #PlayerData.titles(player).owned == 0 then
		LobbyHud.toast("No titles yet: the Task Path and the Season Pass give them", "info")
		return
	end
	fillTitleList()
	titleList.Visible = true
end

-- A title just earned: a toast, pointing to the profile when it didn't go on by itself.
local knownTitles: { [string]: boolean }? = nil
local function onTitles()
	if StateValues.get(player, "DataReady") ~= true then
		knownTitles = nil -- the save isn't in yet: what loads with it isn't new
		return
	end
	local titles = PlayerData.titles(player)
	local before = knownTitles
	knownTitles = {}
	for _, name in titles.owned do
		(knownTitles :: { [string]: boolean })[name] = true
		if before and not before[name] then
			LobbyHud.toast(
				if titles.on == name
					then `NEW TITLE: {string.upper(name)} (EQUIPPED)`
					else `NEW TITLE: {string.upper(name)}. EQUIP IT ON YOUR PROFILE`,
				"success"
			)
		end
	end
	if titleList and titleList.Visible then
		fillTitleList()
	end
end

local function act()
	local p = shown
	if not p then
		return
	end
	if p == player then
		Router.open("Locker")
		return
	end
	if not p.Parent then
		return -- they left
	end
	local at = sentAt[p.UserId]
	if at and os.clock() - at < Config.PARTY.inviteTtl then
		return
	end
	sentAt[p.UserId] = os.clock()
	LobbyNet.event("PartyRequest"):FireServer("invite", p.UserId)
	fill(p)
end

function ProfileController.init()
	local g = player:WaitForChild("PlayerGui"):WaitForChild("Profile", 15)
	local folder = UiRoot.findTemplates(15)
	local lobby = folder and folder:WaitForChild("Lobby", 15)
	local tpl = lobby and lobby:WaitForChild("ProfileSkin", 15)
	if not (g and g:IsA("ScreenGui") and tpl and tpl:IsA("Frame")) then
		warn(
			"[Profile] StarterGui.Profile or its template missing (tools/studio/BuildProfileRewards.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	skinTemplate = tpl
	local canvas = child(gui, "Canvas") :: Frame
	card = child(canvas, "Card") :: Frame
	Plates.deepen(gui)
	local action = child(card, "Action") :: TextButton
	LobbyKit.button(action, act)
	titleList = child(card, "TitleList") :: Frame
	titleList.Visible = false
	optionTemplate = child(titleList, "Option") :: TextButton
	optionTemplate.Visible = false
	local titleTag = child(child(card, "Tags"), "Title") :: Frame
	LobbyKit.button(child(titleTag, "Pick") :: GuiButton, toggleTitleList)
	LobbyKit.page({
		name = "Profile",
		gui = gui,
		wash = child(gui, "Wash") :: Frame,
		close = child(canvas, "Close") :: GuiButton,
		focus = function()
			return action
		end,
		onOpen = function(arg: any?)
			local p = if typeof(arg) == "Instance" and arg:IsA("Player") then arg else player
			fill(p)
			watch(p)
		end,
	})
	Router.onChanged(function(name: string?)
		if name ~= "Profile" then
			watch(nil)
			titleList.Visible = false
		end
	end)
	-- your titles: the list and the new-title toast follow the published value
	local function watchTitles(v: Instance)
		if v.Name == PlayerData.TITLES and v:IsA("StringValue") then
			v.Changed:Connect(onTitles)
			onTitles()
		end
	end
	local existing = player:FindFirstChild(PlayerData.TITLES)
	if existing then
		watchTitles(existing)
	else
		local conn: RBXScriptConnection
		conn = player.ChildAdded:Connect(function(v)
			if v.Name == PlayerData.TITLES then
				conn:Disconnect()
				watchTitles(v)
			end
		end)
	end
	-- someone leaving while you look at them closes their card
	Players.PlayerRemoving:Connect(function(p: Player)
		if shown == p and Router.current() == "Profile" then
			Router.close()
		end
	end)
end

return ProfileController
