--!strict
-- A player's profile card (vault/02 Art/UI Lobby Overhaul.md → Missing
-- screens): Studio-built StarterGui.Profile + UiTemplates.Lobby.ProfileSkin
-- (tools/studio/BuildProfileRewards.luau). Opened with a Player from their
-- row in the player list (Util/LobbyHudView), like RIVALS' ViewProfile.
-- Shows what the lobby really knows: portrait, names, level and win streak
-- (player attributes), the skins they have on (LockerSkins, with
-- each line's emblem); match stats wait for the profile system and say so.
-- The button: OPEN LOCKER on your own card, INVITE TO PARTY on someone
-- else's (the same request the player list's INVITE sends; the server
-- validates and rate-limits it: server/Services/PartyService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Lobby.Config)
local Locker = require(ReplicatedStorage.Shared.Locker)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Plates = require(script.Parent.Parent.Util.Plates)
local Router = require(script.Parent.Parent.Util.Router)

local ProfileController = {}

local player = Players.LocalPlayer
local C = LobbyKit.C
local MAX_SKINS = 4

local gui: ScreenGui
local card: Frame
local skinTemplate: Frame
local shown: Player? = nil
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
	setTag(child(tags, "Streak"), "STREAK " .. numberAttr(p, "WinStreak", 0))

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
			gunLabel.Text = string.upper(s.gun)
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
	LobbyKit.page({
		name = "Profile",
		gui = gui,
		canvas = canvas,
		design = Vector2.new(1920, 1080),
		wash = child(gui, "Wash") :: Frame,
		close = child(canvas, "Close") :: GuiButton,
		focus = function()
			return action
		end,
		-- phones: a shorter card (the match stats wait for the profile system
		-- anyway), about 0.63 zoom on a 812 x 375 phone; the button grows to
		-- stay a 44 px+ target
		phone = {
			region = Rect.new(450, 190, 1470, 790),
			arrange = function()
				local stats = child(card, "Stats") :: GuiObject
				local note = child(card, "StatsNote") :: GuiObject
				stats.Visible = false
				note.Visible = false
				local skinsTitle = child(card, "SkinsTitle") :: GuiObject
				local skins = child(card, "Skins") :: GuiObject
				skinsTitle.Position = UDim2.fromOffset(56, 262)
				skins.Position = UDim2.fromOffset(56, 302)
				action.Position = UDim2.fromOffset(490, 476)
				action.Size = UDim2.fromOffset(420, 78)
				card.Size = UDim2.fromOffset(980, 560)
				card.Position = UDim2.fromOffset(960, 490)
				local close = child(canvas, "Close") :: GuiObject
				close.Position = UDim2.fromOffset(1420, 250)
			end,
		},
		onOpen = function(arg: any?)
			local p = if typeof(arg) == "Instance" and arg:IsA("Player") then arg else player
			fill(p)
		end,
	})
	-- someone leaving while you look at them closes their card
	Players.PlayerRemoving:Connect(function(p: Player)
		if shown == p and Router.current() == "Profile" then
			Router.close()
		end
	end)
end

return ProfileController
