--!strict
-- The Party menu (vault/02 Art/UI Play and Party Menus.md), opened by the
-- party + on the HUD as the Router's "Party" menu. Studio-built
-- (StarterGui.PartyMenu, template UiTemplates.Lobby.PartyPlayerCard; backup
-- tools/studio/BuildLobbyMenus.luau); this fills and animates it.
--
-- Left: your party (you and the players grouped with you by the server:
-- Matchmaking/Parties sets PartyKey / PartyLeader), INVITE FRIENDS (Roblox's
-- invite picker) and LEAVE PARTY. Right: a search box, ALL / FRIENDS / LOBBY,
-- and a card per player:
--   * someone here: INVITE sends an in-game party invite (PartyRequest, checked
--     by Services/PartyService; they get ACCEPT / DECLINE);
--   * an online friend who isn't here: INVITE opens Roblox's invite prompt for
--     that friend (SocialService:PromptGameInvite with InviteUser).
-- Friend data (Player:GetFriendsOnlineAsync, cached 30 s by Roblox) is shown
-- only to you (LihFolk: Avatar Context Menus Profiles and Social Surfaces;
-- Friend Invites Referrals and Experience Invites).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local Layout = require(script.Parent.Parent.Util.Layout)
local Plates = require(script.Parent.Parent.Util.Plates)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M

local PartyMenuController = {}

local player = Players.LocalPlayer
local DESIGN = Vector2.new(1920, 1080)
local QUINT = Enum.EasingStyle.Quint
local IN = Enum.EasingDirection.In
local ALLY, GOLD, GREEN =
	Color3.fromHex("3FE0F2"), Color3.fromHex("FFC83D"), Color3.fromHex("3FD68A")
local MUTED, INK, WHITE = Color3.fromHex("B8B8BB"), Color3.fromHex("1A1A1D"), Color3.new(1, 1, 1)
local NAVY_HI = Color3.fromHex("39393C")
local CARD_T, CARD_HOVER_T = 0.15, 0.02
local FRIENDS_TTL = 30 -- seconds between friend lookups (Roblox caches 30 s too)
local STAGGER_MAX = 12 -- cards past this appear together

type Entry = {
	userId: number,
	name: string,
	display: string,
	here: Player?,
	friend: boolean,
	where: string,
	whereColor: Color3,
	order: number,
}

local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local scrim: Frame
local left: Frame
local slots: { Frame } = {}
local countLabel: TextLabel
local leaveButton: TextButton
local grid: ScrollingFrame
local emptyLabel: TextLabel
local searchBox: TextBox
local filterRow: Frame
local template: Frame
local isOpen = false
local openToken = 0
local filter = "ALL"
local resetClose: () -> () = function() end

local sentAt: { [number]: number } = {} -- userId → when you sent them a party invite
local friends: { { [string]: any } } = {}
local friendsAt = -math.huge
local friendsLoading = false

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function press(p: UIScale?, _low: number?)
	if p then
		UiMotion.press(p)
	end
end

local function rest(p: UIScale?, scale: number)
	if p then
		UiMotion.rest(p, scale)
	end
end

-- A button with a Pop UIScale: hover grows it a touch, a press dips it.
local function hookButton(b: GuiButton, onClick: () -> ())
	local pop = b:FindFirstChild("Pop")
	b.MouseEnter:Connect(function()
		if pop and pop:IsA("UIScale") then
			rest(pop, KM.hover)
		end
	end)
	b.MouseLeave:Connect(function()
		if pop and pop:IsA("UIScale") then
			rest(pop, 1)
		end
	end)
	b.Activated:Connect(function()
		if pop and pop:IsA("UIScale") then
			press(pop)
		end
		onClick()
	end)
end

-- A body with slant caps (CapL / CapR): recolour / show them together.
local function setTab(tab: GuiObject, on: boolean)
	tween(tab, 0.15, { BackgroundTransparency = if on then 0 else 1 })
	for _, c in tab:GetChildren() do
		if c:IsA("ImageLabel") then
			tween(c, 0.15, { ImageTransparency = if on then 0 else 1 })
		elseif c:IsA("TextLabel") then
			tween(c, 0.15, { TextColor3 = if on then INK else MUTED })
		end
	end
end

--------------------------------------------------------------------------------
-- Party state (server-owned attributes)

local function myKey(): string?
	local key = player:GetAttribute("PartyKey")
	return if typeof(key) == "string" then key else nil
end

-- You and your party, the leader first.
local function members(): { Player }
	local key = myKey()
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p == player or (key and p:GetAttribute("PartyKey") == key) then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		local la, lb = a:GetAttribute("PartyLeader") == true, b:GetAttribute("PartyLeader") == true
		if la ~= lb then
			return la
		end
		if (a == player) ~= (b == player) then
			return a == player
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

local function inMyParty(p: Player): boolean
	local key = myKey()
	return key ~= nil and p:GetAttribute("PartyKey") == key
end

local function whereHere(p: Player): (string, Color3)
	local status = p:GetAttribute("QueueStatus")
	local mode = p:GetAttribute("QueueMode")
	if status == "searching" then
		return "QUEUED  ·  " .. string.upper(if typeof(mode) == "string" then mode else ""), GOLD
	elseif status == "found" or status == "teleporting" then
		return "JOINING A MATCH", GOLD
	end
	return "IN LOBBY", ALLY
end

local function whereFriend(f: { [string]: any }): string
	local loc = f.LocationType
	if loc == 4 or loc == 1 or loc == 5 then
		return if f.GameId == game.GameId then "IN GAUNTLET" else "PLAYING"
	elseif loc == 3 or loc == 6 then
		return "IN STUDIO"
	end
	return "ONLINE"
end

--------------------------------------------------------------------------------
-- Friends (yields; refreshed at most every FRIENDS_TTL seconds)

local renderList: () -> ()

local function loadFriends()
	if friendsLoading or os.clock() - friendsAt < FRIENDS_TTL then
		return
	end
	friendsLoading = true
	task.spawn(function()
		local ok, result = pcall(function()
			return player:GetFriendsOnlineAsync(200)
		end)
		friendsLoading = false
		friendsAt = os.clock()
		if ok and typeof(result) == "table" then
			friends = result :: { { [string]: any } }
			if isOpen then
				renderList()
			end
		end
	end)
end

local function inviteFriend(userId: number?)
	task.spawn(function()
		local ok, can = pcall(function()
			if userId then
				return SocialService:CanSendGameInviteAsync(player, userId)
			end
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if not (ok and can) then
			LobbyHud.toast("Invites aren't available right now", "error")
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		if userId then
			options.InviteUser = userId
		end
		options.PromptMessage = "Come party up in Gauntlet"
		pcall(SocialService.PromptGameInvite, SocialService, player, options)
	end)
end

--------------------------------------------------------------------------------
-- Building the lists

local function entries(): { Entry }
	local out: { Entry } = {}
	local byId: { [number]: Entry } = {}
	local wantHere = filter ~= "FRIENDS"
	local wantFriends = filter ~= "LOBBY"
	local friendIds: { [number]: { [string]: any } } = {}
	for _, f in friends do
		if typeof(f.VisitorId) == "number" then
			friendIds[f.VisitorId] = f
		end
	end
	for _, p in Players:GetPlayers() do
		local isFriend = friendIds[p.UserId] ~= nil
		if p ~= player and (wantHere or isFriend) then
			local where, color = whereHere(p)
			local e: Entry = {
				userId = p.UserId,
				name = p.Name,
				display = p.DisplayName,
				here = p,
				friend = isFriend,
				where = if isFriend then where .. "  ·  FRIEND" else where,
				whereColor = color,
				order = if isFriend then 1 else 2,
			}
			table.insert(out, e)
			byId[p.UserId] = e
		end
	end
	if wantFriends then
		for id, f in friendIds do
			if not byId[id] then
				local where = whereFriend(f)
				table.insert(out, {
					userId = id,
					name = if typeof(f.UserName) == "string" then f.UserName else "",
					display = if typeof(f.DisplayName) == "string" then f.DisplayName else "",
					here = nil,
					friend = true,
					where = where,
					whereColor = if where == "IN GAUNTLET" then GREEN else MUTED,
					order = if where == "IN GAUNTLET" then 3 else 4,
				})
			end
		end
	end
	local q = string.lower(searchBox.Text)
	if q ~= "" then
		local kept: { Entry } = {}
		for _, e in out do
			local hay = string.lower(e.display .. " " .. e.name)
			if string.find(hay, q, 1, true) then
				table.insert(kept, e)
			end
		end
		out = kept
	end
	table.sort(out, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return string.lower(a.display) < string.lower(b.display)
	end)
	return out
end

local function styleInvite(b: TextButton, sent: boolean)
	b.BackgroundColor3 = if sent then NAVY_HI else WHITE
	local label = b:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = if sent then "SENT" else "INVITE"
		label.TextColor3 = if sent then WHITE else INK
	end
end

local function fillCard(card: Frame, e: Entry, full: boolean)
	(child(child(card, "Cell"), "Headshot") :: ImageLabel).Image = headshot(e.userId);
	(child(card, "PlayerName") :: TextLabel).Text = string.upper(e.display);
	(child(card, "Sub") :: TextLabel).Text = "@" .. e.name
	local where = child(card, "Where") :: TextLabel
	where.Text = e.where
	where.TextColor3 = e.whereColor
	local invite = child(card, "Invite") :: TextButton
	local state = child(card, "State") :: TextLabel
	local here = e.here
	if here and inMyParty(here) then
		invite.Visible = false
		state.Visible = true
		state.Text = "IN YOUR PARTY"
		state.TextColor3 = GREEN
	elseif here and full then
		invite.Visible = false
		state.Visible = true
		state.Text = "YOUR PARTY IS FULL"
		state.TextColor3 = MUTED
	else
		invite.Visible = true
		state.Visible = false
		local at = sentAt[e.userId]
		styleInvite(invite, here ~= nil and at ~= nil and os.clock() - at < Config.PARTY.inviteTtl)
	end
	hookButton(invite, function()
		if here then
			if here.Parent ~= Players then
				return
			end
			local at = sentAt[e.userId]
			if at and os.clock() - at < Config.PARTY.inviteTtl then
				return
			end
			sentAt[e.userId] = os.clock()
			LobbyNet.event("PartyRequest"):FireServer("invite", e.userId)
			styleInvite(invite, true)
			task.delay(Config.PARTY.inviteTtl, function()
				if invite.Parent and sentAt[e.userId] == at then
					styleInvite(invite, false)
				end
			end)
		else
			inviteFriend(e.userId)
		end
	end)
	card.MouseEnter:Connect(function()
		tween(card, 0.15, { BackgroundTransparency = CARD_HOVER_T })
	end)
	card.MouseLeave:Connect(function()
		tween(card, 0.2, { BackgroundTransparency = CARD_T })
	end)
end

local function renderParty()
	local list = members()
	local inParty = #list > 1
	countLabel.Text = string.format("%d / %d", #list, Config.PARTY.max)
	for i, slot in slots do
		local p = list[i]
		local cell = child(slot, "Cell") :: Frame
		local name = child(slot, "PlayerName") :: TextLabel
		local sub = child(slot, "Sub") :: TextLabel
		local lead = child(slot, "Lead") :: GuiObject
		local empty = child(slot, "Empty") :: GuiObject
		cell.Visible = p ~= nil
		name.Visible = p ~= nil
		sub.Visible = p ~= nil
		empty.Visible = p == nil
		lead.Visible = p ~= nil and inParty and p:GetAttribute("PartyLeader") == true
		slot.BackgroundTransparency = if p then CARD_T else 0.55
		if p then
			(child(cell, "Headshot") :: ImageLabel).Image = headshot(p.UserId)
			name.Text = string.upper(p.DisplayName)
			name.TextColor3 = if p == player then ALLY else WHITE
			sub.Text = "@" .. p.Name
		end
	end
	leaveButton.Visible = inParty
end

renderList = function()
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") and c.Name == "Card" then
			c:Destroy()
		end
	end
	local full = #members() >= Config.PARTY.max
	local list = entries()
	for i, e in list do
		local card = template:Clone()
		card.Name = "Card"
		card.LayoutOrder = i
		fillCard(card, e, full)
		card.Parent = grid
	end
	emptyLabel.Visible = #list == 0
	emptyLabel.Text = if searchBox.Text ~= ""
		then "NO ONE MATCHES THAT NAME"
		elseif filter == "FRIENDS" then "NO FRIENDS ONLINE RIGHT NOW"
		else "NO ONE TO INVITE YET"
end

local function render()
	if not isOpen then
		return
	end
	renderParty()
	renderList()
end

--------------------------------------------------------------------------------
-- Open / close

local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(size.X / DESIGN.X, size.Y / DESIGN.Y)
	end
end

local function slideIn(o: GuiObject, dx: number, dy: number, delay: number)
	local h = o:GetAttribute("Home")
	local home = if typeof(h) == "UDim2" then h else o.Position
	o:SetAttribute("Home", home)
	o.Position = home + UDim2.fromOffset(dx, dy)
	task.delay(delay, function()
		if isOpen then
			tween(o, 0.42, { Position = home })
		end
	end)
end

local function open()
	openToken += 1
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	refit()
	resetClose()
	loadFriends()
	render()
	scrim.BackgroundTransparency = 1
	tween(scrim, 0.25, { BackgroundTransparency = 0.45 })
	slideIn(child(canvas, "Title"), -40, 0, 0)
	slideIn(left, -40, 0, 0.02)
	slideIn(child(canvas, "Search"), 0, 24, 0.04)
	slideIn(filterRow, 0, 24, 0.04)
	slideIn(grid, 0, 36, 0.06)
	-- the cards rise one after another (only on open, not on every refresh)
	local n = 0
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") and c.Name == "Card" and n < STAGGER_MAX then
			n += 1
			local pop = Instance.new("UIScale")
			pop.Scale = 0.94
			pop.Parent = c
			task.delay(0.06 + n * 0.025, function()
				tween(pop, 0.32, { Scale = 1 })
			end)
		end
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	openToken += 1
	local token = openToken
	searchBox:ReleaseFocus()
	tween(scrim, 0.16, { BackgroundTransparency = 1 }, QUINT, IN)
	local home = grid:GetAttribute("Home")
	if typeof(home) == "UDim2" then
		tween(grid, 0.16, { Position = home + UDim2.fromOffset(0, 18) }, QUINT, IN)
	end
	task.delay(0.17, function()
		if openToken == token and not isOpen then
			gui.Enabled = false
		end
	end)
end

--------------------------------------------------------------------------------

function PartyMenuController.init()
	if Layout.isPhone() then
		return -- the phone pass gives phones their own party screen
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("PartyMenu", 15)
	local t = ReplicatedStorage:WaitForChild("UiTemplates")
		:WaitForChild("Lobby")
		:WaitForChild("PartyPlayerCard", 15)
	if not g or not g:IsA("ScreenGui") or not t or not t:IsA("Frame") then
		warn(
			"[PartyMenu] StarterGui.PartyMenu / PartyPlayerCard missing (tools/studio/BuildLobbyMenus.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	template = t
	canvas = child(gui, "Canvas")
	fit = child(canvas, "Fit")
	scrim = child(gui, "Scrim")
	left = child(canvas, "Left")
	countLabel = child(left, "Count")
	local slotFolder = child(left, "Slots") :: Frame
	for i = 1, 3 do
		table.insert(slots, child(slotFolder, "Slot" .. i))
	end
	leaveButton = child(left, "Leave")
	grid = child(canvas, "Grid")
	emptyLabel = child(canvas, "Empty")
	searchBox = child(child(canvas, "Search"), "Box")
	filterRow = child(canvas, "Filters")
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	resetClose = CloseButton.hook(child(canvas, "Close") :: GuiButton, function()
		Router.close()
	end)
	hookButton(child(left, "InviteFriends") :: TextButton, function()
		inviteFriend(nil)
	end)
	hookButton(leaveButton, function()
		LobbyNet.event("PartyRequest"):FireServer("leave")
	end)
	for _, tab in filterRow:GetChildren() do
		if tab:IsA("TextButton") then
			tab.Activated:Connect(function()
				if filter == tab.Name then
					return
				end
				filter = tab.Name
				for _, other in filterRow:GetChildren() do
					if other:IsA("TextButton") then
						setTab(other, other == tab)
					end
				end
				render()
			end)
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #searchBox.Text > 20 then
			searchBox.Text = string.sub(searchBox.Text, 1, 20)
			return
		end
		render()
	end)
	Plates.deepen(gui)
	Router.register("Party", { open = open, close = close })
end

function PartyMenuController.start()
	if not gui then
		return
	end
	-- anyone's party or queue state changing can change a card
	local queued = false
	local function soon()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			render()
		end)
	end
	local function watch(p: Player)
		p.AttributeChanged:Connect(function(name: string)
			if
				name == "PartyKey"
				or name == "PartyLeader"
				or name == "QueueStatus"
				or name == "QueueMode"
			then
				soon()
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(function(p)
		watch(p)
		soon()
	end)
	Players.PlayerRemoving:Connect(function(p)
		sentAt[p.UserId] = nil
		soon()
	end)
end

return PartyMenuController
