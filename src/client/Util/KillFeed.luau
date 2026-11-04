--!strict
-- Kill feed (top right) and the ELIMINATED pop-up for your own kills, UI v1
-- (vault/02 Art/UI Design.md → HUD). Fed by the server's "Killed" event
-- (WeaponService.damage: gun and Mod kills), which every client hears.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mods = require(ReplicatedStorage.Shared.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Ui = require(script.Parent.Ui)

local KillFeed = {}

local player = Players.LocalPlayer
local C = Theme.COLORS
local make = Ui.make

local ROWS = 4
local ROW_W, ROW_H, ROW_GAP = 400, 44, 8
local ROW_LIFE = 5 -- seconds a row stays
local BANNER_HOLD = 1.6 -- seconds the pop-up stays before it fades

local feed: Frame? = nil
local banner: CanvasGroup? = nil
local bannerScale: UIScale? = nil
local victimLabel: TextLabel? = nil
local headshotTag: Frame? = nil
local bannerToken = 0

local function nameOf(x: Instance?): string
	if not x then
		return "?"
	end
	if x:IsA("Player") then
		return if x == player then "YOU" else string.upper(x.DisplayName)
	end
	local owner = if x:IsA("Model") then Players:GetPlayerFromCharacter(x) else nil
	if owner then
		return if owner == player then "YOU" else string.upper(owner.DisplayName)
	end
	return string.upper(x.Name)
end

local function teamColor(x: Instance?): Color3
	if x == player or (x and x:IsA("Model") and Players:GetPlayerFromCharacter(x) == player) then
		return C.ally
	end
	return if Teams.isAlly(x, player) then C.ally else C.enemy
end

function KillFeed.build(gui: ScreenGui)
	local list = make("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -48, 0, 128),
		Size = UDim2.fromOffset(ROW_W, (ROW_H + ROW_GAP) * ROWS),
		BackgroundTransparency = 1,
	}, gui)
	Ui.fit(list)
	make("UIListLayout", {
		Padding = UDim.new(0, ROW_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	feed = list

	local group = make("CanvasGroup", {
		Name = "KillBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(520, 96),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
	}, gui)
	Ui.fit(group)
	local pop = make("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, group)
	bannerScale = make("UIScale", {}, pop)
	local slant = make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.IMAGE.slant,
		ImageColor3 = C.panel,
		ImageTransparency = 0.12,
	}, pop)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, slant)
	local diamond = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(114, 48),
		Size = UDim2.fromOffset(50, 50),
		Rotation = 45,
		BorderSizePixel = 0,
		BackgroundColor3 = C.enemy,
	}, pop)
	make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 36),
		Rotation = -45,
		BackgroundTransparency = 1,
		Image = Theme.ICON.Skull,
	}, diamond)
	Ui.text(pop, "ELIMINATED", "displayM", {
		Position = UDim2.fromOffset(170, 8),
		Size = UDim2.fromOffset(320, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	victimLabel = Ui.text(pop, "", "titleS", {
		Position = UDim2.fromOffset(172, 58),
		Size = UDim2.fromOffset(150, 26),
		TextColor3 = C.enemy,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	headshotTag = Ui.tag(pop, "Headshot", C.gold, { Position = UDim2.fromOffset(330, 60) }, true)
	banner = group
end

local function row(killer: Instance?, victim: Instance?, sourceId: string, headshot: boolean)
	local list = feed
	if not list then
		return
	end
	local mine = killer == player
	local holder = make("Frame", {
		Size = UDim2.fromOffset(ROW_W, ROW_H),
		BackgroundTransparency = 1,
		LayoutOrder = -math.floor(os.clock() * 100),
	}, list)
	-- The visible row slides in from the right inside its layout slot.
	local frame = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.fromOffset(ROW_W, ROW_H),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
	}, holder)
	Ui.tween(
		frame,
		Theme.MOTION.enter,
		{ Position = UDim2.fromOffset(0, 0) },
		Enum.EasingStyle.Quint
	)
	if mine then
		make("UIStroke", { Color = C.ally, Thickness = 1.5 }, frame)
	end
	make("Frame", {
		Size = UDim2.fromOffset(4, ROW_H),
		BorderSizePixel = 0,
		BackgroundColor3 = teamColor(killer),
	}, frame)
	Ui.text(frame, nameOf(killer), "titleS", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(118, 28),
		TextColor3 = teamColor(killer),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local def = Mods.def(sourceId)
	make("ImageLabel", {
		Position = UDim2.fromOffset(if def then 175 else 140, 8),
		Size = UDim2.fromOffset(if def then 28 else 100, 28),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = if def then def.icon else Theme.GUN[sourceId] or "",
	}, frame)
	if headshot then
		make("ImageLabel", {
			Position = UDim2.fromOffset(242, 12),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Image = Theme.ICON.Skull,
			ImageColor3 = C.gold,
		}, frame)
	end
	Ui.text(frame, nameOf(victim), "titleS", {
		Position = UDim2.fromOffset(266, 8),
		Size = UDim2.fromOffset(120, 28),
		TextColor3 = teamColor(victim),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	-- Oldest rows go first once the list is full.
	local rows = {}
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder > b.LayoutOrder
	end)
	for i = ROWS + 1, #rows do
		rows[i]:Destroy()
	end
	task.delay(ROW_LIFE, function()
		if holder.Parent then
			-- Out: slides back right, then goes.
			Ui.tween(
				frame,
				Theme.MOTION.exit,
				{ Position = UDim2.fromOffset(ROW_W, 0) },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
			task.delay(Theme.MOTION.exit, function()
				holder:Destroy()
			end)
		end
	end)
end

local function pop(victim: Instance?, headshot: boolean)
	local group, scale, label, tag = banner, bannerScale, victimLabel, headshotTag
	if not group or not scale or not label or not tag then
		return
	end
	bannerToken += 1
	local token = bannerToken
	label.Text = nameOf(victim)
	tag.Visible = headshot
	group.Visible = true
	group.GroupTransparency = 0
	scale.Scale = 1.25
	Ui.tween(scale, Theme.MOTION.enter, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(BANNER_HOLD, function()
		if token == bannerToken then
			Ui.tween(
				group,
				Theme.MOTION.exit * 2,
				{ GroupTransparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end
	end)
end

function KillFeed.kill(victim: unknown, attacker: unknown, sourceId: unknown, headshot: unknown)
	local v = if typeof(victim) == "Instance" then victim else nil
	local a = if typeof(attacker) == "Instance" then attacker else nil
	local id = if typeof(sourceId) == "string" then sourceId else ""
	local head = headshot == true
	row(a, v, id, head)
	if a == player then
		pop(v, head)
	end
end

return KillFeed
