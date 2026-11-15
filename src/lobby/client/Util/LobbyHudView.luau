--!strict
-- The lobby main HUD, v6 (vault/02 Art/UI Lobby HUD.md): the player list
-- with level and win streak (top right), the bottom bar (Locker, Shop, Pass,
-- Range, Settings) with PLAY and your party slots, toasts and party invites.
-- The layout is built in Studio, one ScreenGui per part like the match
-- (StarterGui.LobbyTasks, LobbyPlayerList, LobbyBar, LobbyToast,
-- templates UiTemplates.Lobby.PlayerRow / PartySlot / PartyInviteRow, backup
-- tools/studio/BuildLobbyHud.luau); this fills and animates it. LobbyHud
-- uses it on desktop; phones keep the old dock until the mobile pass.
--
-- Tab shows / hides the player list (like Roblox's). The party row shows you
-- and the friends in your Roblox party who are here (server attributes
-- PartyKey / PartyLeader from Matchmaking/Parties); the + opens a card to
-- invite players here (Services/PartyService: in-game invites, since Roblox
-- has no API to invite into a Roblox party) or friends to the game, or leave.
-- Hovering someone's row in the player list shows INVITE too; an invite you
-- get pops up with ACCEPT / DECLINE. Motion: things pop
-- from their centre with a short overshoot and settle (coil, snap, settle).
--
-- Data that doesn't exist yet stays hidden or a placeholder: level and XP (no
-- progression yet: the `Level` / `XpShare` / `WinStreak` player attributes are
-- read if they appear), daily tasks (`setTasks`), badges (`setBadge`) and the
-- callout (`callout`).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local QueueState = require(script.Parent.QueueState)
local Router = require(script.Parent.Router)
local Sound = require(script.Parent.Sound)

local LobbyHudView = {}

local player = Players.LocalPlayer

local DESIGN = Vector2.new(1920, 1080)
local NAVY, NAVY_HI = Color3.fromHex("1C2740"), Color3.fromHex("2B3A5A")
local ALLY, GOLD = Color3.fromHex("3FE0F2"), Color3.fromHex("FFC83D")
local RED, WHITE, INK = Color3.fromHex("FF4D5E"), Color3.new(1, 1, 1), Color3.fromHex("141A26")
local GREEN = Color3.fromHex("3FD68A")
local MAX_ROWS = 8
local ICON_SIZE, ICON_HOVER, LIFT = 74, 84, 10
local LIST_AWAY = 440 -- px the player list slides right when hidden with Tab
local BACK, QUINT = Enum.EasingStyle.Back, Enum.EasingStyle.Quint
local IN, OUT = Enum.EasingDirection.In, Enum.EasingDirection.Out

-- Bar buttons → the Router's menus.
local MENUS: { [string]: string } = {
	Locker = "Locker",
	Shop = "Shop",
	BattlePass = "BattlePass",
	Range = "Range",
	Settings = "Settings",
}

type State = {
	gui: ScreenGui,
	fits: { UIScale },
	topRight: Frame,
	bottom: Frame,
	list: Frame,
	count: TextLabel,
	more: TextLabel,
	rowTemplate: Frame,
	play: TextButton,
	playPop: UIScale,
	playBody: Frame,
	playTitle: TextLabel,
	playSub: TextLabel,
	items: { [string]: TextButton },
	callout: Frame,
	toastPlate: Frame,
	toastPop: UIScale,
	toastKind: Frame,
	toastLabel: TextLabel,
	bottomHome: UDim2,
	bottomShown: boolean,
	topHomes: { [Frame]: UDim2 },
	topShown: boolean,
	listShown: boolean,
	party: Frame,
	slotTemplate: Frame,
	slots: { [Player]: GuiObject },
	card: Frame,
	cardPop: UIScale,
	cardOpen: boolean,
	inviteRowTemplate: Frame,
	invite: Frame,
	invitePop: UIScale,
	inviteFrom: Player?,
	inviteUntil: number,
	playHover: boolean,
	lastStatus: string,
	timerConn: RBXScriptConnection?,
	toastToken: number,
	lastSecond: number,
}

local state: State? = nil

local function tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- A press: coil down fast, overshoot, settle (pivot = the UIScale's object anchor).
local function press(pop: UIScale, low: number?)
	pop.Scale = 1
	local t = tween(pop, 0.06, { Scale = low or 0.9 }, QUINT, OUT)
	t.Completed:Once(function()
		tween(pop, 0.32, { Scale = 1 }, BACK, OUT)
	end)
end

-- Pops in from nothing after `delay`.
local function popIn(pop: UIScale, delay: number?, time: number?)
	pop.Scale = 0
	task.delay(delay or 0, function()
		tween(pop, time or 0.38, { Scale = 1 }, BACK, OUT)
	end)
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function numberAttr(p: Player, name: string, default: number): number
	local v = p:GetAttribute(name)
	return if typeof(v) == "number" and v == v then v else default
end

-- A body with slant caps (CapL / CapR children): recolour them together.
local function setFill(body: GuiObject, color: Color3)
	body.BackgroundColor3 = color
	for _, c in body:GetChildren() do
		if c:IsA("ImageLabel") and (c.Name == "CapL" or c.Name == "CapR") then
			c.ImageColor3 = color
		end
	end
end

-- Party invites (Services/PartyService) -------------------------------------------
local function partyRequest(action: string, userId: number?)
	LobbyNet.event("PartyRequest"):FireServer(action, userId)
end

local sentAt: { [number]: number } = {} -- userId → when you invited them

-- Anyone here who isn't you or already in your party.
local function canInvite(p: Player): boolean
	if p == player then
		return false
	end
	local key = player:GetAttribute("PartyKey")
	return not (typeof(key) == "string" and p:GetAttribute("PartyKey") == key)
end

-- An INVITE button for `p`: reads SENT (navy) while that invite is open.
local function hookInvite(b: TextButton, p: Player)
	local label = b:FindFirstChild("Label")
	local function look()
		local at = sentAt[p.UserId]
		local sent = at ~= nil and os.clock() - at < Config.PARTY.inviteTtl
		setFill(b, if sent then NAVY_HI else GOLD)
		if label and label:IsA("TextLabel") then
			label.Text = if sent then "SENT" else "INVITE"
			label.TextColor3 = if sent then WHITE else INK
		end
	end
	look()
	b.Activated:Connect(function()
		local at = sentAt[p.UserId]
		if at and os.clock() - at < Config.PARTY.inviteTtl then
			return
		end
		sentAt[p.UserId] = os.clock()
		Sound.play("Select")
		partyRequest("invite", p.UserId)
		look()
	end)
end

-- The party card refills when the list changes (set once the card exists).
local refreshCard: () -> () = function() end

-- Player list (level and win streak) -------------------------------------------------
local function whereOf(p: Player): (string, Color3)
	local status = p:GetAttribute("QueueStatus")
	local mode = p:GetAttribute("QueueMode")
	if status == "searching" then
		return "QUEUED  ·  " .. string.upper(if typeof(mode) == "string" then mode else ""), GOLD
	elseif status == "found" or status == "teleporting" then
		return "JOINING A MATCH", GOLD
	end
	return "IN LOBBY", ALLY
end

local shownRows: { [number]: boolean } = {}
local listIntro = false -- the first fill cascades in

local function openRow(row: Frame, delay: number)
	local h = row.Size.Y.Offset
	row.ClipsDescendants = true
	row.Size = UDim2.fromOffset(row.Size.X.Offset, 0)
	task.delay(delay, function()
		local t = tween(row, 0.32, { Size = UDim2.fromOffset(row.Size.X.Offset, h) }, BACK, OUT)
		t.Completed:Once(function()
			row.ClipsDescendants = false
		end)
	end)
end

local function renderList()
	local s = state
	if not s then
		return
	end
	for _, c in s.list:GetChildren() do
		if c:IsA("Frame") and c.Name == "Row" then
			c:Destroy()
		end
	end
	local seen: { [number]: boolean } = {}
	local all = Players:GetPlayers()
	table.sort(all, function(a, b)
		if a == player then
			return true
		elseif b == player then
			return false
		end
		return a.DisplayName < b.DisplayName
	end)
	s.count.Text = string.format("%d HERE", #all)
	for i, p in all do
		if i > MAX_ROWS then
			break
		end
		local row = s.rowTemplate:Clone()
		row.Name = "Row"
		row.LayoutOrder = 10 + i
		local mine = p == player
		row.BackgroundColor3 = if mine then NAVY_HI else NAVY
		local shot = child(child(row, "Cell"), "Headshot") :: ImageLabel
		shot.Image = headshot(p.UserId)
		local name = child(row, "PlayerName") :: TextLabel
		name.Text = string.upper(p.DisplayName)
		name.TextColor3 = if mine then ALLY else WHITE
		local where, color = whereOf(p)
		local whereLabel = child(row, "Where") :: TextLabel
		whereLabel.Text = where
		whereLabel.TextColor3 = color
		local lv = child(child(row, "Level"), "Value") :: TextLabel
		lv.Text = tostring(numberAttr(p, "Level", 1))
		local streak = child(row, "Streak") :: Frame
		local value = numberAttr(p, "WinStreak", 0)
		local streakLabel = child(streak, "Value") :: TextLabel
		streakLabel.Text = tostring(value)
		-- no streak reads dimmer (the body and its slanted ends together)
		local dim = if value > 0 then 0 else 0.6
		streak.BackgroundTransparency = dim
		for _, c in streak:GetChildren() do
			if c:IsA("ImageLabel") then
				c.ImageTransparency = dim
			end
		end
		-- hovering someone you can invite shows INVITE over their tags
		local inviteB = row:FindFirstChild("Invite")
		if inviteB and inviteB:IsA("TextButton") then
			inviteB.Visible = false
			if canInvite(p) then
				hookInvite(inviteB, p)
				row.MouseEnter:Connect(function()
					inviteB.Visible = true
					tween(row, 0.12, { BackgroundColor3 = NAVY_HI })
				end)
				row.MouseLeave:Connect(function()
					inviteB.Visible = false
					tween(row, 0.18, { BackgroundColor3 = NAVY })
				end)
			end
		end
		row.Parent = s.list
		seen[p.UserId] = true
		if not shownRows[p.UserId] and listIntro then
			openRow(row, if next(shownRows) then 0 else (i - 1) * 0.05)
		end
	end
	shownRows = seen
	refreshCard()
	s.more.Visible = #all > MAX_ROWS
	s.more.Text = string.format("+%d MORE", #all - MAX_ROWS)
end

local watched: { [Player]: RBXScriptConnection } = {}
local function watch(p: Player)
	if watched[p] then
		return
	end
	watched[p] = p.AttributeChanged:Connect(function(name: string)
		if
			name == "QueueStatus"
			or name == "QueueMode"
			or name == "Level"
			or name == "WinStreak"
		then
			renderList()
		end
		if name == "PartyKey" or name == "PartyLeader" then
			LobbyHudView.renderParty()
			renderList()
		end
	end)
end

-- Bottom bar ------------------------------------------------------------------------
local function hookItem(s: State, b: TextButton)
	local icon = child(b, "Icon") :: ImageLabel
	local homeY = icon.Position.Y.Offset
	-- concept C's hover: the item's colour plate (with ») pops up behind the
	-- icon from its base; the name stays on its coloured tag (concept A)
	local plate = b:FindFirstChild("Plate")
	local platePop = plate and plate:FindFirstChild("Pop")
	local chevrons = plate and plate:FindFirstChild("Chevrons")
	local chevHome = if chevrons and chevrons:IsA("GuiObject")
		then chevrons.Position
		else UDim2.new()
	local hovered = false
	-- the tag's slanted ends have a dark edge fringe that shows on the same-
	-- colour plate, so they hide while it's up (the tag body merges into it)
	local tag = b:FindFirstChild("Tag")
	local function tagEnds(show: boolean)
		for _, c in if tag then tag:GetChildren() else {} do
			if c:IsA("ImageLabel") then
				c.ImageTransparency = if show then 0 else 1
			end
		end
	end
	local function hover(on: boolean)
		hovered = on
		if on then
			tagEnds(false)
		end
		tween(icon, if on then 0.22 else 0.18, {
			Size = UDim2.fromOffset(
				if on then ICON_HOVER else ICON_SIZE,
				if on then ICON_HOVER else ICON_SIZE
			),
			Position = UDim2.new(0.5, 0, 0, homeY - (if on then LIFT else 0)),
		}, if on then BACK else QUINT, OUT)
		if plate and plate:IsA("GuiObject") and platePop and platePop:IsA("UIScale") then
			if on then
				plate.Visible = true
				platePop.Scale = 0.7
				tween(platePop, 0.26, { Scale = 1 }, BACK, OUT)
				local chev = plate:FindFirstChild("Chevrons")
				if chev and chev:IsA("GuiObject") then
					chev.Position = chevHome - UDim2.fromOffset(18, 0)
					tween(chev, 0.34, { Position = chevHome }, BACK, OUT)
				end
			else
				local t = tween(platePop, 0.12, { Scale = 0.7 }, QUINT, IN)
				t.Completed:Once(function()
					if not hovered then
						plate.Visible = false
						tagEnds(true)
					end
				end)
			end
		end
	end
	local pop = icon:FindFirstChild("Pop")
	b.MouseEnter:Connect(function()
		hover(true)
		Sound.play("Hover")
	end)
	b.MouseLeave:Connect(function()
		hover(false)
	end)
	b.Activated:Connect(function()
		local menu = MENUS[b.Name]
		if pop and pop:IsA("UIScale") then
			press(pop, 0.82)
		end
		if menu then
			Sound.play("Select")
			Router.toggle(menu)
		end
	end)
	s.items[b.Name] = b
end

local function inviteFriends()
	Sound.play("Select")
	task.spawn(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			LobbyHudView.toast("Invites aren't available right now", "error")
		end
	end)
end

-- A hover lift for party circles (their ring's "Pop").
local function hoverLift(slot: GuiObject, pop: UIScale?)
	if not pop then
		return
	end
	slot.MouseEnter:Connect(function()
		tween(pop, 0.2, { Scale = 1.1 }, BACK, OUT)
	end)
	slot.MouseLeave:Connect(function()
		tween(pop, 0.18, { Scale = 1 }, QUINT, OUT)
	end)
end

-- Party ----------------------------------------------------------------------------
local function partyMates(): { Player }
	local key = player:GetAttribute("PartyKey")
	local list: { Player } = {}
	if typeof(key) ~= "string" then
		return list
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("PartyKey") == key then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		if (a:GetAttribute("PartyLeader") == true) ~= (b:GetAttribute("PartyLeader") == true) then
			return a:GetAttribute("PartyLeader") == true
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

local function setLead(slot: GuiObject, on: boolean)
	local ring = slot:FindFirstChild("Ring")
	local lead = ring and ring:FindFirstChild("Lead")
	if lead and lead:IsA("GuiObject") then
		lead.Visible = on
	end
end

local function slotPop(slot: GuiObject): UIScale?
	local ring = slot:FindFirstChild("Ring")
	local pop = ring and ring:FindFirstChild("Pop")
	return if pop and pop:IsA("UIScale") then pop else nil
end

local function fillCard(s: State)
	local mates = partyMates()
	local body = child(s.card, "Body") :: Frame
	local status = child(body, "Status") :: TextLabel
	local help = child(body, "Help") :: TextLabel
	local count = child(child(s.card, "Head"), "Count") :: TextLabel
	local full = #mates + 1 >= Config.PARTY.max
	if #mates == 0 then
		count.Text = "SOLO"
		status.Text = "NOT IN A PARTY"
		help.Text = "Invite players here, or friends to the game. A Roblox party joins you on its own. "
			.. "Your party queues together, on one team."
	else
		count.Text = string.format("%d / %d", #mates + 1, Config.PARTY.max)
		local leader = player
		for _, m in mates do
			if m:GetAttribute("PartyLeader") == true then
				leader = m
			end
		end
		status.Text = string.format("PARTY OF %d", #mates + 1)
		help.Text = if leader == player
			then "You lead: pick a mode and PLAY, and your party searches with you. Anyone can cancel."
			else string.upper(leader.DisplayName)
				.. " leads: they pick the mode and start the search. Anyone can cancel."
	end
	child(body, "Leave").Visible = #mates > 0
	-- the players here you can invite (up to 5)
	local here = child(body, "Here") :: Frame
	for _, c in here:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local list: { Player } = {}
	if not full then
		for _, p in Players:GetPlayers() do
			if canInvite(p) then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
	end
	for i, p in list do
		if i > 5 then
			break
		end
		local row = s.inviteRowTemplate:Clone()
		row.Name = "Row"
		row.LayoutOrder = i
		local shot = child(child(row, "Cell"), "Headshot") :: ImageLabel
		shot.Image = headshot(p.UserId)
		local name = child(row, "PlayerName") :: TextLabel
		name.Text = string.upper(p.DisplayName)
		local where = child(row, "Where") :: TextLabel
		where.Text = (whereOf(p))
		hookInvite(child(row, "Invite") :: TextButton, p)
		row.Parent = here
	end
	local empty = child(body, "Empty") :: TextLabel
	empty.Visible = #list == 0
	empty.Text = if full then "YOUR PARTY IS FULL" else "NO ONE ELSE IS HERE YET"
end

local function showCard(s: State, open: boolean)
	if open == s.cardOpen then
		return
	end
	s.cardOpen = open
	if open then
		fillCard(s)
		s.card.Visible = true
		s.cardPop.Scale = 0.6
		tween(s.cardPop, 0.34, { Scale = 1 }, BACK, OUT)
		Sound.play("Open")
	else
		local t = tween(s.cardPop, 0.14, { Scale = 0.7 }, QUINT, IN)
		t.Completed:Once(function()
			if not s.cardOpen then
				s.card.Visible = false
			end
		end)
	end
end

-- You first, then your Roblox party (leader first); friends pop in and out.
function LobbyHudView.renderParty()
	local s = state
	if not s then
		return
	end
	local mates = partyMates()
	local you = child(s.party, "You") :: GuiObject
	setLead(you, player:GetAttribute("PartyLeader") == true)
	local keep: { [Player]: boolean } = {}
	for i, m in mates do
		keep[m] = true
		local slot = s.slots[m]
		if not slot then
			local made = s.slotTemplate:Clone()
			made.Name = "Mate"
			local shot = child(child(child(made, "Ring"), "Disc"), "Headshot") :: ImageLabel
			shot.Image = headshot(m.UserId)
			made.Parent = s.party
			s.slots[m] = made
			slot = made
			local pop = slotPop(made)
			if pop then
				popIn(pop, 0.05 * (i - 1))
			end
			hoverLift(made, pop)
			Sound.play("CardIn")
		end
		local sl = slot :: GuiObject
		sl.LayoutOrder = 1 + i
		setLead(sl, m:GetAttribute("PartyLeader") == true)
	end
	for m, slot in s.slots do
		if not keep[m] then
			s.slots[m] = nil
			local pop = slotPop(slot)
			if pop then
				local t = tween(pop, 0.16, { Scale = 0 }, QUINT, IN)
				t.Completed:Once(function()
					slot:Destroy()
				end)
			else
				slot:Destroy()
			end
		end
	end
	if s.cardOpen then
		fillCard(s)
	end
end

-- Invites you get ------------------------------------------------------------------
local function hideInvite(s: State)
	s.inviteFrom = nil
	local t = tween(s.invitePop, 0.16, { Scale = 0.7 }, QUINT, IN)
	t.Completed:Once(function()
		if not s.inviteFrom then
			s.invite.Visible = false
		end
	end)
end

local function showInvite(s: State, from: Player, ttl: number)
	s.inviteFrom = from
	s.inviteUntil = os.clock() + ttl
	local shot = child(child(child(s.invite, "Cell"), "Disc"), "Headshot") :: ImageLabel
	shot.Image = headshot(from.UserId)
	local name = child(s.invite, "PlayerName") :: TextLabel
	name.Text = string.upper(from.DisplayName)
	local timer = child(s.invite, "Timer") :: TextLabel
	s.invite.Visible = true
	s.invitePop.Scale = 0.6
	tween(s.invitePop, 0.42, { Scale = 1 }, BACK, OUT)
	Sound.play("Banner")
	task.spawn(function()
		while s.inviteFrom == from do
			local left = s.inviteUntil - os.clock()
			if left <= 0 or from.Parent ~= Players then
				hideInvite(s)
				break
			end
			timer.Text = tostring(math.ceil(left))
			task.wait(0.2)
		end
	end)
end

local function onPartyEvent(payload: unknown)
	local s = state
	if not s or typeof(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: unknown }
	if data.kind == "invite" and typeof(data.from) == "number" then
		local from = Players:GetPlayerByUserId(data.from :: number)
		local ttl = if typeof(data.expiresIn) == "number"
			then data.expiresIn :: number
			else Config.PARTY.inviteTtl
		if from then
			showInvite(s, from, math.clamp(ttl, 1, 60))
		end
	elseif data.kind == "info" and typeof(data.text) == "string" then
		LobbyHudView.toast(data.text :: string, "info")
	end
end

-- Fit: each group keeps its corner, scaled like the rest of the HUD.
local function refit(s: State)
	local size = s.gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		local scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.6, 1.5)
		for _, f in s.fits do
			f.Scale = scale
		end
	end
end

-- PLAY's look by queue status, and the live timer.
local function updateTimer()
	local s = state
	if not s or QueueState.status() ~= "searching" then
		return
	end
	local second = math.floor(QueueState.elapsed())
	if second == s.lastSecond then
		return
	end
	s.lastSecond = second
	local mode = QueueState.mode()
	s.playSub.Text = string.format(
		"%s  ·  %s  ·  CLICK TO CANCEL",
		string.upper(mode or ""),
		clock(QueueState.elapsed())
	)
end

-- API -------------------------------------------------------------------------------

-- The Studio-built ScreenGuis (one per part), or nil if they aren't there.
local PARTS = { "LobbyTasks", "LobbyPlayerList", "LobbyBar", "LobbyToast" }
function LobbyHudView.guis(playerGui: Instance, wait: number): { [string]: ScreenGui }?
	local found: { [string]: ScreenGui } = {}
	for _, name in PARTS do
		local g = playerGui:WaitForChild(name, wait)
		if not g or not g:IsA("ScreenGui") then
			return nil
		end
		found[name] = g
	end
	return found
end

-- Binds the lobby HUD's ScreenGuis (from `guis`).
function LobbyHudView.bind(guis: { [string]: ScreenGui }): boolean
	local gui = guis.LobbyBar
	local topRight = child(guis.LobbyPlayerList, "TopRight") :: Frame
	local bottom = child(gui, "Bottom") :: Frame
	local toast = child(guis.LobbyToast, "Toast") :: Frame
	local tasksGroup = child(guis.LobbyTasks, "TopLeft") :: Frame
	local list = child(topRight, "PlayerList") :: Frame
	local head = child(list, "Head") :: Frame
	local play = child(bottom, "Play") :: TextButton
	local face = child(play, "Face") :: Frame
	local plate = child(toast, "Plate") :: Frame
	local s: State = {
		gui = gui,
		fits = {
			child(topRight, "Fit"),
			child(bottom, "Fit"),
			child(toast, "Fit"),
			child(tasksGroup, "Fit"),
		},
		topRight = topRight,
		bottom = bottom,
		list = list,
		count = child(head, "Count"),
		more = child(list, "More"),
		rowTemplate = ReplicatedStorage:WaitForChild("UiTemplates")
			:WaitForChild("Lobby")
			:WaitForChild("PlayerRow") :: Frame,
		play = play,
		playPop = child(face, "Pop"),
		playBody = child(face, "Body"),
		playTitle = child(face, "Title"),
		playSub = child(face, "Sub"),
		items = {},
		callout = child(bottom, "Callout"),
		toastPlate = plate,
		toastPop = child(plate, "Pop"),
		toastKind = child(plate, "Kind"),
		toastLabel = child(plate, "Label"),
		bottomHome = bottom.Position,
		bottomShown = true,
		topHomes = { [topRight] = topRight.Position },
		topShown = true,
		listShown = true,
		party = child(bottom, "Party"),
		slotTemplate = ReplicatedStorage:WaitForChild("UiTemplates")
			:WaitForChild("Lobby")
			:WaitForChild("PartySlot") :: Frame,
		slots = {},
		card = child(bottom, "PartyCard"),
		cardPop = child(child(bottom, "PartyCard"), "Pop"),
		cardOpen = false,
		inviteRowTemplate = ReplicatedStorage:WaitForChild("UiTemplates")
			:WaitForChild("Lobby")
			:WaitForChild("PartyInviteRow") :: Frame,
		invite = child(toast, "Invite"),
		invitePop = child(child(toast, "Invite"), "Pop"),
		inviteFrom = nil,
		inviteUntil = 0,
		playHover = false,
		lastStatus = "idle",
		timerConn = nil,
		toastToken = 0,
		lastSecond = -1,
	}
	state = s
	refit(s)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refit(s)
	end)
	for name in MENUS do
		hookItem(s, child(bottom, name))
	end
	play.MouseEnter:Connect(function()
		s.playHover = true
		tween(s.playPop, 0.2, { Scale = 1.05 }, BACK, OUT)
		Sound.play("Hover")
	end)
	play.MouseLeave:Connect(function()
		s.playHover = false
		tween(s.playPop, 0.18, { Scale = 1 }, QUINT, OUT)
	end)
	-- PLAY breathes now and then while idle, so the eye finds it
	task.spawn(function()
		while state == s do
			task.wait(3.2)
			local idle = QueueState.status() == "idle" and s.bottomShown and not s.cardOpen
			if idle and not s.playHover and s.playPop.Scale == 1 then
				local t = tween(s.playPop, 0.3, { Scale = 1.035 }, Enum.EasingStyle.Sine, OUT)
				t.Completed:Wait()
				if not s.playHover then
					tween(
						s.playPop,
						0.55,
						{ Scale = 1 },
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					)
				end
			end
		end
	end)
	play.Activated:Connect(function()
		press(s.playPop, 0.92)
		Sound.play("Select")
		showCard(s, false)
		if QueueState.status() == "searching" then
			QueueState.leave()
		else
			Router.toggle("Queue")
		end
	end)
	local party = s.party
	local inviteSlot = child(party, "Invite") :: TextButton
	local invitePop = slotPop(inviteSlot)
	inviteSlot.MouseEnter:Connect(function()
		if invitePop then
			tween(invitePop, 0.2, { Scale = 1.1 }, BACK, OUT)
		end
		Sound.play("Hover")
	end)
	inviteSlot.MouseLeave:Connect(function()
		if invitePop then
			tween(invitePop, 0.18, { Scale = 1 }, QUINT, OUT)
		end
	end)
	inviteSlot.Activated:Connect(function()
		if invitePop then
			press(invitePop, 0.85)
		end
		Sound.play("Select")
		showCard(s, not s.cardOpen)
	end)
	local cardBody = child(s.card, "Body")
	local friendsButton = child(cardBody, "InviteFriends") :: TextButton
	friendsButton.Activated:Connect(function()
		showCard(s, false)
		inviteFriends()
	end)
	local leaveButton = child(cardBody, "Leave") :: TextButton
	leaveButton.Activated:Connect(function()
		Sound.play("Close")
		showCard(s, false)
		partyRequest("leave")
	end)
	refreshCard = function()
		if s.cardOpen then
			fillCard(s)
		end
	end
	local youSlot = child(party, "You") :: GuiObject
	hoverLift(youSlot, slotPop(youSlot))
	local you = child(child(child(youSlot, "Ring"), "Disc"), "Headshot") :: ImageLabel
	you.Image = headshot(player.UserId)
	-- invites you get
	local inviteBox = s.invite;
	(child(inviteBox, "Accept") :: TextButton).Activated:Connect(function()
		local from = s.inviteFrom
		if from then
			Sound.play("LockIn")
			partyRequest("accept", from.UserId)
			hideInvite(s)
		end
	end);
	(child(inviteBox, "Decline") :: TextButton).Activated:Connect(function()
		local from = s.inviteFrom
		if from then
			Sound.play("Close")
			partyRequest("decline", from.UserId)
			hideInvite(s)
		end
	end)
	LobbyNet.event("PartyEvent").OnClientEvent:Connect(onPartyEvent)
	-- Tab shows / hides the player list, like Roblox's own
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			s.listShown = not s.listShown
			LobbyHudView.placeCorners(true)
		end
	end)
	-- Roblox's player list steps aside for ours.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(function(p)
		watch(p)
		renderList()
	end)
	Players.PlayerRemoving:Connect(function(p)
		local c = watched[p]
		if c then
			c:Disconnect()
			watched[p] = nil
		end
		task.defer(renderList)
	end)
	renderList()
	LobbyHudView.renderParty()
	for name, g in guis do
		g.Enabled = name ~= "LobbyTasks" -- tasks wait for a tasks system
	end
	return true
end

function LobbyHudView.active(): boolean
	return state ~= nil
end

-- Queue status or menu changed: PLAY's look, and the bottom group steps aside
-- while a menu or MATCH FOUND owns the screen.
function LobbyHudView.refresh()
	local s = state
	if not s then
		return
	end
	local status = QueueState.status()
	local mode = QueueState.mode()
	s.lastSecond = -1
	if status ~= s.lastStatus then
		s.lastStatus = status
		s.playPop.Scale = 0.88
		tween(s.playPop, 0.42, { Scale = 1 }, BACK, OUT)
	end
	if status == "idle" then
		setFill(s.playBody, GOLD)
		s.playTitle.Text = "PLAY"
		s.playTitle.TextSize = 44
		s.playTitle.TextColor3 = INK
		s.playSub.Text = if QueueState.isLeader()
			then "1V1  ·  2V2  ·  3V3"
			else "YOUR LEADER STARTS"
		s.playSub.TextColor3 = INK
	elseif status == "searching" then
		setFill(s.playBody, NAVY_HI)
		s.playTitle.Text = "SEARCHING"
		s.playTitle.TextSize = 30
		s.playTitle.TextColor3 = WHITE
		s.playSub.TextColor3 = ALLY
		updateTimer()
	else
		setFill(s.playBody, GREEN)
		s.playTitle.Text = "MATCH FOUND"
		s.playTitle.TextSize = 30
		s.playTitle.TextColor3 = INK
		s.playSub.Text = string.upper(mode or "")
		s.playSub.TextColor3 = INK
	end
	-- the bottom group slides away while a menu or MATCH FOUND is up
	local away = Router.current() ~= nil or status == "found" or status == "teleporting"
	if away then
		showCard(s, false)
	end
	if away == s.bottomShown then
		s.bottomShown = not away
		tween(s.bottom, if away then 0.26 else 0.46, {
			Position = if away then s.bottomHome + UDim2.fromOffset(0, 360) else s.bottomHome,
		}, if away then QUINT else BACK, if away then IN else OUT)
	end
	LobbyHudView.placeCorners(false)
	if status == "searching" and not s.timerConn then
		s.timerConn = RunService.Heartbeat:Connect(updateTimer)
	elseif status ~= "searching" and s.timerConn then
		s.timerConn:Disconnect()
		s.timerConn = nil
	end
end

-- The corners step up out of the way while a menu is open (its title and
-- close button live up there); the player list also slides right while
-- hidden with Tab. `force` animates even when only the Tab state changed.
function LobbyHudView.placeCorners(force: boolean)
	local s = state
	if not s then
		return
	end
	local menuOpen = Router.current() ~= nil
	if menuOpen ~= s.topShown and not force then
		return
	end
	s.topShown = not menuOpen
	for g, home in s.topHomes do
		local goal = home
		if menuOpen then
			goal += UDim2.fromOffset(0, -260)
		end
		local hiding = g == s.topRight and not s.listShown
		if hiding then
			goal += UDim2.fromOffset(LIST_AWAY, 0)
		end
		local leaving = menuOpen or hiding
		tween(
			g,
			if leaving then 0.24 else 0.42,
			{ Position = goal },
			if leaving then QUINT else BACK,
			if leaving then IN else OUT
		)
	end
	if force then
		Sound.play(if s.listShown then "Open" else "Close")
	end
end

-- Entrance: the corners drop in, the player list rows cascade, the bottom
-- rises and the bar icons pop up one by one, then PLAY lands.
function LobbyHudView.intro()
	local s = state
	if not s then
		return
	end
	for i, g in { s.topRight } do
		local home = s.topHomes[g]
		g.Position = home + UDim2.fromOffset(0, -140)
		task.delay((i - 1) * 0.06, function()
			tween(g, 0.5, { Position = home }, BACK, OUT)
		end)
	end
	listIntro = true
	table.clear(shownRows)
	renderList()
	local home = s.bottomHome
	s.bottom.Position = home + UDim2.fromOffset(0, 300)
	task.delay(0.1, function()
		if s.bottomShown then
			tween(s.bottom, 0.5, { Position = home }, BACK, OUT)
		end
	end)
	local order = { "Locker", "Shop", "BattlePass", "Range", "Settings" }
	for i, name in order do
		local b = s.items[name]
		local pop = b and b:FindFirstChild("Icon") and (b :: any).Icon:FindFirstChild("Pop")
		if pop and pop:IsA("UIScale") then
			popIn(pop, 0.22 + (i - 1) * 0.05, 0.4)
		end
	end
	s.playPop.Scale = 0
	task.delay(0.42, function()
		tween(s.playPop, 0.45, { Scale = 1 }, BACK, OUT)
	end)
	local youPop = slotPop(child(s.party, "You"))
	if youPop then
		popIn(youPop, 0.5)
	end
end

-- A short message at the top. kind: "error" (red) or "info" (cyan).
function LobbyHudView.toast(text: string, kind: string?)
	local s = state
	if not s then
		return
	end
	s.toastToken += 1
	local token = s.toastToken
	local color = if kind == "error" then RED else ALLY
	s.toastKind.BackgroundColor3 = color
	local cap = s.toastKind:FindFirstChild("Cap")
	if cap and cap:IsA("ImageLabel") then
		cap.ImageColor3 = color
	end
	s.toastLabel.Text = string.upper(text)
	s.toastPlate.Visible = true
	local home = UDim2.fromOffset(350, 140)
	s.toastPlate.Position = home + UDim2.fromOffset(0, -24)
	s.toastPop.Scale = 0.7
	tween(s.toastPlate, 0.4, { Position = home }, BACK, OUT)
	tween(s.toastPop, 0.4, { Scale = 1 }, BACK, OUT)
	Sound.play(if kind == "error" then "Denied" else "Banner")
	task.delay(4, function()
		if token ~= s.toastToken then
			return
		end
		tween(s.toastPlate, 0.22, { Position = home + UDim2.fromOffset(0, -30) }, QUINT, IN)
		local t = tween(s.toastPop, 0.22, { Scale = 0.6 }, QUINT, IN)
		t.Completed:Once(function()
			if token == s.toastToken then
				s.toastPlate.Visible = false
			end
		end)
	end)
end

-- Red count badges on the bar (0 hides). ids: Locker, Shop, BattlePass, Range, Settings.
function LobbyHudView.setBadge(id: string, count: number)
	local s = state
	local b = s and s.items[id]
	local badge = b and b:FindFirstChild("Badge")
	if badge and badge:IsA("Frame") then
		badge.Visible = count > 0
		local n = badge:FindFirstChild("N")
		if n and n:IsA("TextLabel") then
			n.Text = tostring(math.min(count, 99))
		end
	end
end

-- A callout over a bar item ("NEW SKIN UNLOCKED"), or nil to hide it.
function LobbyHudView.callout(id: string?, text: string?)
	local s = state
	if not s then
		return
	end
	local b = if id then s.items[id] else nil
	s.callout.Visible = b ~= nil and text ~= nil
	if b and text then
		local label = s.callout:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.Text = string.upper(text)
		end
		s.callout.Position = UDim2.fromOffset(b.Position.X.Offset, s.callout.Position.Y.Offset)
	end
end

-- Daily tasks: not built yet (no tasks system); the panel stays hidden.
function LobbyHudView.setTasks(_tasks: { any })
	-- Filled once a tasks system exists (vault/05 Production/Bugs & Ideas.md).
end

return LobbyHudView
