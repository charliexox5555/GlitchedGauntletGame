--!strict
-- The lobby main HUD, v6 (vault/02 Art/UI Lobby HUD.md): the player list
-- with level and win streak (top right), the bottom bar (Locker, Shop, Pass,
-- Range, Settings) with PLAY and your party slots, toasts and party invites.
-- The layout is built in Studio, one ScreenGui per part like the match
-- (StarterGui.LobbyTasks, LobbyPlayerList, LobbyBar, LobbyToast,
-- templates UiTemplates.Lobby.PlayerRow / PartySlot / PartyInviteRow, backup
-- tools/studio/BuildLobbyHud.luau); this fills and animates it on every
-- device (LobbyHud binds it). Sizing per device: Shared/UiLayout owns each
-- group's "Fit" UIScale.
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Pivot = require(script.Parent.Pivot)
local Plates = require(script.Parent.Plates)
local QueueState = require(script.Parent.QueueState)
local Router = require(script.Parent.Router)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M

local LobbyHudView = {}

local player = Players.LocalPlayer

local NAVY, NAVY_HI = Color3.fromHex("27272A"), Color3.fromHex("39393C")
local ALLY, GOLD = Color3.fromHex("3FE0F2"), Color3.fromHex("FFC83D")
local RED, WHITE, INK = Color3.fromHex("FF4D5E"), Color3.new(1, 1, 1), Color3.fromHex("1A1A1D")
local MAX_ROWS = 8
local ICON_SIZE, ICON_HOVER, LIFT = 74, 84, 10
local TAG_UP = 104 -- the name tag's height while its item is hovered (it grows up behind the icon)
local LIST_AWAY = 440 -- least px the player list slides right when hidden with Tab
local QUINT = Enum.EasingStyle.Quint
local IN, OUT = Enum.EasingDirection.In, Enum.EasingDirection.Out

-- Bar buttons → the Router's menus.
local MENUS: { [string]: string } = {
	Locker = "Locker",
	Shop = "Shop",
	Backpack = "Backpack", -- replaced the Battle Pass for the first release (owner 2026-11-20)
	Range = "Range",
	Settings = "Settings",
}

type State = {
	gui: ScreenGui,
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
	topbar: Frame,
	party: Frame,
	slotTemplate: Frame,
	slots: { [Player]: GuiObject },
	invite: Frame,
	invitePop: UIScale,
	inviteFrom: Player?,
	inviteUntil: number,
	playHover: boolean,
	lastStatus: string,
	toastToken: number,
}

local state: State? = nil

local tween = UiMotion.tween

-- Motion is clean, not bouncy (owner, 2026-11-15: "cleaner, less glitchy"):
-- Quint out for anything arriving, Quint in for leaving, no Back overshoot,
-- and nothing snaps to a start value while a tween on it is still running.

-- The scale a pop rests at (1, or its hover size), so a press returns there.
local function rest(p: UIScale?, scale: number)
	if p then
		UiMotion.rest(p, scale)
	end
end

-- A press: a quick dip from wherever it is, then an ease back to its rest.
local function press(p: UIScale?, _low: number?)
	if p then
		UiMotion.press(p)
	end
end

-- Pops in from nothing after `delay`.
local function popIn(pop: UIScale, delay: number?, time: number?)
	pop.Scale = 0
	task.delay(delay or 0, function()
		tween(pop, time or 0.34, { Scale = 1 }, QUINT, OUT)
	end)
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function numberAttr(p: Player, name: string, default: number): number
	local v = StateValues.get(p, name)
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
	local key = StateValues.get(player, "PartyKey")
	return not (typeof(key) == "string" and StateValues.get(p, "PartyKey") == key)
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
		partyRequest("invite", p.UserId)
		look()
	end)
end

-- Player list (level and win streak) -------------------------------------------------
local function whereOf(p: Player): (string, Color3)
	local status = StateValues.get(p, "QueueStatus")
	local mode = StateValues.get(p, "QueueMode")
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
		local t = tween(row, 0.32, { Size = UDim2.fromOffset(row.Size.X.Offset, h) }, QUINT, OUT)
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
				local ib = inviteB
				ib.MouseEnter:Connect(function()
					StateValues.set(ib, "Over", true)
				end)
				ib.MouseLeave:Connect(function()
					StateValues.set(ib, "Over", false)
				end)
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
		-- a click or tap on the row (not on its INVITE) opens their profile,
		-- like RIVALS' player list (Controllers/ProfileController)
		row.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
				return
			end
			local b = row:FindFirstChild("Invite")
			if b and b:IsA("GuiObject") and b.Visible and StateValues.get(b, "Over") == true then
				return -- that's the INVITE button's click
			end
			Router.open("Profile", p)
		end)
		row.Parent = s.list
		Plates.deepen(row) -- the level tag: one-piece plate (owner, 2026-11-16)
		seen[p.UserId] = true
		if not shownRows[p.UserId] and listIntro then
			openRow(row, if next(shownRows) then 0 else (i - 1) * 0.05)
		end
	end
	shownRows = seen
	s.more.Visible = #all > MAX_ROWS
	s.more.Text = string.format("+%d MORE", #all - MAX_ROWS)
end

local watched: { [Player]: RBXScriptConnection } = {}
local function watch(p: Player)
	if watched[p] then
		return
	end
	watched[p] = StateValues.anyChanged(p):Connect(function(name: string)
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
	-- the hover tick (owner 2026-11-20): bottom bar items are below the
	-- "big item" size UiSoundController ticks for on its own
	b:SetAttribute("UiHover", true)
	local icon = child(b, "Icon") :: ImageLabel
	local homeY = icon.Position.Y.Offset
	-- Hover (owner 2026-11-20: the old pop-up plate didn't line up with the
	-- name tag and felt chunky): the item's own name TAG grows up behind the
	-- icon, one plate the whole way, so plate and name can't misalign; the
	-- name stays at its foot, the » fades in at its top corner, one Quint ease
	-- each way. The old separate Plate stays hidden.
	local tag = b:FindFirstChild("Tag")
	local label = tag and tag:FindFirstChild("Label")
	local tagHome = if tag and tag:IsA("GuiObject") then tag.Size else UDim2.new()
	local chev: TextLabel? = nil
	local hoverToken = 0
	local chevAt = UDim2.new()
	if tag and tag:IsA("GuiObject") then
		local bottom = tag.Position.Y.Offset + tag.Size.Y.Offset
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.new(0.5, 0, 0, bottom)
		if label and label:IsA("GuiObject") then
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.new(0.5, 0, 1, -tagHome.Y.Offset / 2)
		end
		icon.ZIndex = math.max(icon.ZIndex, tag.ZIndex + 1)
		local plate = b:FindFirstChild("Plate")
		if plate and plate:IsA("GuiObject") then
			plate.Visible = false
			local c = plate:FindFirstChild("Chevrons")
			if c and c:IsA("TextLabel") then
				-- on the button, not inside the tag: a tag's children draw under
				-- the icon (sibling ZIndex), so the » sat behind it. It goes
				-- to the grown tag's top-right corner, above the icon.
				chevAt = UDim2.new(0.5, (tagHome.X.Offset + 8) / 2 + 6, 0, bottom - TAG_UP) -- where the old plate had it
				c.Parent = b
				c.AnchorPoint = Vector2.new(1, 0)
				c.Position = chevAt
				c.ZIndex = icon.ZIndex + 2
				-- white, as on the old plate
				c.TextTransparency = 1
				c.TextStrokeTransparency = 1
				-- its outline (LobbyLook's TitleOutline) would stay drawn while
				-- the text is hidden: the » showed on every idle tag
				for _, st in c:GetChildren() do
					if st:IsA("UIStroke") then
						st:Destroy()
					end
				end
				c.Visible = false
				chev = c
			end
		end
	end
	local function hover(on: boolean)
		tween(icon, 0.28, {
			Size = UDim2.fromOffset(
				if on then ICON_HOVER else ICON_SIZE,
				if on then ICON_HOVER else ICON_SIZE
			),
			Position = UDim2.new(0.5, 0, 0, homeY - (if on then LIFT else 0)),
		}, QUINT, OUT)
		if tag and tag:IsA("GuiObject") then
			tween(tag, 0.28, {
				Size = if on then UDim2.fromOffset(tagHome.X.Offset + 8, TAG_UP) else tagHome,
			}, QUINT, OUT)
		end
		local c = chev
		if c then
			hoverToken += 1
			local my = hoverToken
			if on then
				c.Visible = true
				c.Position = chevAt - UDim2.fromOffset(10, 0)
			end
			local t = tween(c, if on then 0.3 else 0.15, {
				TextTransparency = if on then 0 else 1,
				Position = chevAt,
			}, QUINT, OUT)
			if not on then
				t.Completed:Once(function()
					if my == hoverToken then
						c.Visible = false
					end
				end)
			end
		end
	end
	local pop = icon:FindFirstChild("Pop")
	b.MouseEnter:Connect(function()
		hover(true)
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
			Router.toggle(menu)
		end
	end)
	s.items[b.Name] = b
end

-- A hover lift for party circles (their ring's "Pop").
local function hoverLift(slot: GuiObject, pop: UIScale?)
	if not pop then
		return
	end
	slot.MouseEnter:Connect(function()
		rest(pop, KM.hover)
	end)
	slot.MouseLeave:Connect(function()
		rest(pop, 1)
	end)
end

-- Party ----------------------------------------------------------------------------
local function partyMates(): { Player }
	local key = StateValues.get(player, "PartyKey")
	local list: { Player } = {}
	if typeof(key) ~= "string" then
		return list
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and StateValues.get(p, "PartyKey") == key then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		if
			(StateValues.get(a, "PartyLeader") == true)
			~= (StateValues.get(b, "PartyLeader") == true)
		then
			return StateValues.get(a, "PartyLeader") == true
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

-- You first, then your Roblox party (leader first); friends pop in and out.
function LobbyHudView.renderParty()
	local s = state
	if not s then
		return
	end
	local mates = partyMates()
	local you = child(s.party, "You") :: GuiObject
	setLead(you, StateValues.get(player, "PartyLeader") == true)
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
			Plates.deepen(made)
			s.slots[m] = made
			slot = made
			local pop = slotPop(made)
			if pop then
				popIn(pop, 0.05 * (i - 1))
			end
			hoverLift(made, pop)
		end
		local sl = slot :: GuiObject
		sl.LayoutOrder = 1 + i
		setLead(sl, StateValues.get(m, "PartyLeader") == true)
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
	s.invitePop.Scale = 0.88
	tween(s.invitePop, 0.42, { Scale = 1 }, QUINT, OUT)
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

-- API -------------------------------------------------------------------------------

-- The Studio-built ScreenGuis (one per part), or nil if they aren't there.
local PARTS = { "LobbyTasks", "LobbyPlayerList", "LobbyBar", "LobbyToast", "LobbyTopbar" }
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
	local list = child(topRight, "PlayerList") :: Frame
	local head = child(list, "Head") :: Frame
	local play = child(bottom, "Play") :: TextButton
	local face = child(play, "Face") :: Frame
	local plate = child(toast, "Plate") :: Frame
	local s: State = {
		gui = gui,
		topRight = topRight,
		bottom = bottom,
		list = list,
		count = child(head, "Count"),
		more = child(list, "More"),
		rowTemplate = UiRoot.templates():WaitForChild("Lobby"):WaitForChild("PlayerRow") :: Frame,
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
		topHomes = {
			[topRight] = topRight.Position,
			[child(guis.LobbyTopbar, "Bar") :: Frame] = (child(guis.LobbyTopbar, "Bar") :: Frame).Position,
		},
		topbar = child(guis.LobbyTopbar, "Bar"),
		topShown = true,
		listShown = true,
		party = child(bottom, "Party"),
		slotTemplate = UiRoot.templates():WaitForChild("Lobby"):WaitForChild("PartySlot") :: Frame,
		slots = {},
		invite = child(toast, "Invite"),
		invitePop = child(child(toast, "Invite"), "Pop"),
		inviteFrom = nil,
		inviteUntil = 0,
		playHover = false,
		lastStatus = "idle",
		toastToken = 0,
	}
	state = s
	Pivot.centre(s.invite) -- the invite popup pops from its centre
	for name in MENUS do
		hookItem(s, child(bottom, name))
	end
	play.MouseEnter:Connect(function()
		s.playHover = true
		rest(s.playPop, KM.hoverCard)
	end)
	play.MouseLeave:Connect(function()
		s.playHover = false
		rest(s.playPop, 1)
	end)
	-- PLAY breathes now and then while idle, so the eye finds it
	task.spawn(function()
		while state == s do
			task.wait(3.2)
			local idle = QueueState.status() == "idle" and s.bottomShown
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
		if QueueState.status() == "idle" then
			Router.toggle("Queue")
		end
	end)
	local party = s.party
	local inviteSlot = child(party, "Invite") :: TextButton
	local invitePop = slotPop(inviteSlot)
	inviteSlot.MouseEnter:Connect(function()
		if invitePop then
			rest(invitePop, KM.hover)
		end
	end)
	inviteSlot.MouseLeave:Connect(function()
		if invitePop then
			rest(invitePop, 1)
		end
	end)
	inviteSlot.Activated:Connect(function()
		if invitePop then
			press(invitePop, 0.85)
		end
		Router.toggle("Party")
	end)
	local youSlot = child(party, "You") :: GuiObject
	hoverLift(youSlot, slotPop(youSlot))
	local you = child(child(child(youSlot, "Ring"), "Disc"), "Headshot") :: ImageLabel
	you.Image = headshot(player.UserId)
	-- invites you get
	local inviteBox = s.invite;
	(child(inviteBox, "Accept") :: TextButton).Activated:Connect(function()
		local from = s.inviteFrom
		if from then
			partyRequest("accept", from.UserId)
			hideInvite(s)
		end
	end);
	(child(inviteBox, "Decline") :: TextButton).Activated:Connect(function()
		local from = s.inviteFrom
		if from then
			partyRequest("decline", from.UserId)
			hideInvite(s)
		end
	end)
	LobbyNet.event("PartyEvent").OnClientEvent:Connect(onPartyEvent)
	-- Tab shows / hides the player list, like Roblox's own
	-- Tab, or the topbar's leaderboard button, shows / hides the list
	local boardButton = child(s.topbar, "Leaderboard") :: TextButton
	local boardIcon = child(child(boardButton, "Face"), "Icon") :: Frame
	local function boardLook()
		for _, bar in boardIcon:GetChildren() do
			if bar:IsA("Frame") then
				tween(bar, 0.15, { BackgroundTransparency = if s.listShown then 0 else 0.55 })
			end
		end
	end
	local function toggleList()
		s.listShown = not s.listShown
		LobbyHudView.placeCorners(true)
		boardLook()
		if s.listShown then
			-- coming back: the rows cascade in again, like the HUD's entrance
			-- (owner 2026-11-20: "bring the leaderboard animation back")
			listIntro = true
			table.clear(shownRows)
			renderList()
		end
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			toggleList()
		end
	end)
	-- topbar buttons: Roblox-style dark circles that lighten on hover
	local function hookTopbar(b: TextButton, onClick: () -> ())
		local disc = child(b, "Face") :: Frame
		local pop = child(disc, "Pop") :: UIScale
		b.MouseEnter:Connect(function()
			tween(disc, 0.12, { BackgroundTransparency = 0.12 })
		end)
		b.MouseLeave:Connect(function()
			tween(disc, 0.18, { BackgroundTransparency = 0.3 })
		end)
		b.Activated:Connect(function()
			press(pop, 0.86)
			onClick()
		end)
	end
	hookTopbar(boardButton, toggleList)
	hookTopbar(child(s.topbar, "Settings") :: TextButton, function()
		Router.toggle("Settings")
	end)
	boardLook()
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
	-- the lobby's slanted plates (PLAY, the bottom bar, the toast, the you
	-- slot's leader tag) are one-piece plates like the menus'
	for _, g in guis do
		Plates.deepen(g)
	end
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
	if status ~= s.lastStatus then
		local was = s.lastStatus
		s.lastStatus = status
		-- PLAY leaves while you're queued (the searching bar, Controllers/
		-- PlayMenuController, takes over) and comes back when you're idle
		if status == "idle" then
			s.play.Visible = true
			StateValues.set(s.playPop, "Rest", 1)
			s.playPop.Scale = 0
			tween(s.playPop, 0.36, { Scale = 1 }, QUINT, OUT)
		elseif was == "idle" then
			local t = tween(s.playPop, 0.2, { Scale = 0 }, QUINT, IN)
			t.Completed:Once(function(playback: Enum.PlaybackState)
				if playback == Enum.PlaybackState.Completed and QueueState.status() ~= "idle" then
					s.play.Visible = false
				end
			end)
		end
	end
	setFill(s.playBody, GOLD)
	s.playTitle.Text = "PLAY"
	s.playTitle.TextSize = 44
	s.playTitle.TextColor3 = INK
	s.playSub.Text = if QueueState.isLeader() then "1V1  ·  2V2  ·  3V3" else "YOUR LEADER STARTS"
	s.playSub.TextColor3 = INK
	-- the bottom group slides away while a menu or MATCH FOUND is up
	local away = Router.current() ~= nil or status == "found" or status == "teleporting"
	if away == s.bottomShown then
		s.bottomShown = not away
		tween(s.bottom, if away then 0.26 else 0.46, {
			Position = if away then s.bottomHome + UDim2.fromOffset(0, 360) else s.bottomHome,
		}, QUINT, if away then IN else OUT)
	end
	LobbyHudView.placeCorners(false)
end

-- The corners step up out of the way while a menu is open (its title and
-- close button live up there); the player list also slides right while
-- hidden with Tab. `force` animates even when only the Tab state changed.
function LobbyHudView.placeCorners(force: boolean)
	local s = state
	if not s then
		return
	end
	-- MATCH FOUND (Controllers/MatchFoundController) clears the screen too
	local status = QueueState.status()
	local menuOpen = Router.current() ~= nil or status == "found" or status == "teleporting"
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
			-- far enough to clear the screen's right edge at any HUD scale
			-- (big monitors scale the list up past the old fixed 440 px)
			local shift = g.Position.X.Offset - home.X.Offset
			local atHome = s.list.AbsolutePosition.X - shift
			local away = s.gui.AbsoluteSize.X - atHome + 40
			goal += UDim2.fromOffset(math.max(LIST_AWAY, away), 0)
		end
		local leaving = menuOpen or hiding
		-- Tab slides the list away with a soft stop (an accelerating exit
		-- read as a snap); a menu opening still clears the corners quickly
		local tabOnly = hiding and not menuOpen
		tween(
			g,
			if tabOnly then 0.36 elseif leaving then 0.24 else 0.45,
			{ Position = goal },
			QUINT,
			if leaving and not tabOnly then IN else OUT
		)
	end
end

-- Entrance: the corners drop in, the player list rows cascade, the bottom
-- rises and the bar icons pop up one by one, then PLAY lands.
function LobbyHudView.intro()
	local s = state
	if not s then
		return
	end
	for i, g in { s.topbar, s.topRight } do
		local home = s.topHomes[g]
		g.Position = home + UDim2.fromOffset(0, -140)
		task.delay((i - 1) * 0.06, function()
			tween(g, 0.5, { Position = home }, QUINT, OUT)
		end)
	end
	listIntro = true
	table.clear(shownRows)
	renderList()
	local home = s.bottomHome
	s.bottom.Position = home + UDim2.fromOffset(0, 300)
	task.delay(0.1, function()
		if s.bottomShown then
			tween(s.bottom, 0.5, { Position = home }, QUINT, OUT)
		end
	end)
	local order = { "Locker", "Shop", "Backpack", "Range", "Settings" }
	for i, name in order do
		local b = s.items[name]
		local pop = b and b:FindFirstChild("Icon") and (b :: any).Icon:FindFirstChild("Pop")
		if pop and pop:IsA("UIScale") then
			popIn(pop, 0.22 + (i - 1) * 0.05, 0.4)
		end
	end
	s.playPop.Scale = 0
	task.delay(0.42, function()
		tween(s.playPop, 0.45, { Scale = 1 }, QUINT, OUT)
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
	-- centre-anchored so its pop grows from the middle (owner rule)
	s.toastPlate.AnchorPoint = Vector2.new(0.5, 0.5)
	local home = UDim2.fromOffset(350, 140 + 26) -- the plate is 52 tall (auto width)
	s.toastPlate.Position = home + UDim2.fromOffset(0, -24)
	s.toastPop.Scale = 0.9
	tween(s.toastPlate, 0.4, { Position = home }, QUINT, OUT)
	tween(s.toastPop, 0.4, { Scale = 1 }, QUINT, OUT)
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

-- Red count badges on the bar (0 hides). ids: Locker, Shop, Backpack, Range, Settings.
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
