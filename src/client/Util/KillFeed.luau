--!strict
-- Kill feed (top right) and the ELIMINATED pop-up for your own kills, UI v1
-- (vault/02 Art/UI Design.md → HUD). Fed by the server's "Killed" event
-- (WeaponService.damage: gun and Mod kills), which every client hears.
-- Your own kills also play the kill tone, a step higher for every kill in
-- the round (Config/Audio KILL_LADDER, Valorant-style), and light one more
-- pip on the pop-up (2026-11-09).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local Ui = require(script.Parent.Ui)
local Watched = require(script.Parent.Watched)

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
local assistPopup: CanvasGroup? = nil
local assistToken = 0
local pips: { Frame } = {}
-- Your kills this round (back to 0 when the round changes).
local roundKills = 0
-- Each watched fighter's kills this round (Util/Watched): their tone climbs
-- its own ladder, not yours.
local watchedKills: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local PIP_ON = Theme.COLORS.enemy
local PIP_OFF = Color3.new(1, 1, 1)
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
	local assist = make("CanvasGroup", {
		Name = "AssistPopup",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(120, 26),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.15,
		GroupTransparency = 1,
		Visible = false,
	}, gui)
	Ui.fit(assist)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, assist)
	Ui.text(assist, "+1 ASSIST", "label", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.ally,
	})
	assistPopup = assist

	local list = make("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		-- Under the top bar, which starts below Roblox's top bar (the player
		-- list is hidden in matches, so the corner is ours).
		Position = UDim2.new(1, -48, 0, 180),
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
	-- One pip per kill this round, under the skull.
	table.clear(pips)
	for i = 1, #Audio.KILL_LADDER do
		pips[i] = make("Frame", {
			Name = "Pip" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(114 + (i - 3) * 12, 89),
			Size = UDim2.fromOffset(9, 4),
			BorderSizePixel = 0,
			BackgroundColor3 = PIP_OFF,
			BackgroundTransparency = 0.7,
		}, pop)
	end
	banner = group
end

function KillFeed.assistInfo(payload: unknown): (number, boolean)
	local count, mine = 0, false
	if typeof(payload) == "table" then
		for _, id in payload do
			if typeof(id) == "number" then
				count += 1
				mine = mine or (id ~= 0 and id == player.UserId)
			end
		end
	end
	return count, mine
end

local function showAssist()
	local popup = assistPopup
	if not popup then
		return
	end
	assistToken += 1
	local token = assistToken
	popup.Visible = true
	Ui.tween(popup, Theme.MOTION.enter, { GroupTransparency = 0 })
	task.delay(1.25, function()
		if token ~= assistToken then
			return
		end
		Ui.tween(popup, Theme.MOTION.exit, { GroupTransparency = 1 })
		task.delay(Theme.MOTION.exit, function()
			if token == assistToken then
				popup.Visible = false
			end
		end)
	end)
end

local function row(
	killer: Instance?,
	victim: Instance?,
	sourceId: string,
	headshot: boolean,
	assists: number,
	myAssist: boolean
)
	local list = feed
	if not list or not list.Parent then
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
		Size = UDim2.fromOffset(if assists > 0 then 65 else 120, 28),
		TextColor3 = teamColor(victim),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if assists > 0 then
		Ui.text(frame, "+" .. assists .. " AST", "label", {
			Name = "AssistTag",
			Position = UDim2.fromOffset(336, 8),
			Size = UDim2.fromOffset(58, 28),
			TextColor3 = if myAssist then C.ally else C.textSecondary,
		})
	end
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

local function pop(victim: Instance?, headshot: boolean, count: number)
	local group, scale, label, tag = banner, bannerScale, victimLabel, headshotTag
	if not group or not scale or not label or not tag then
		return
	end
	bannerToken += 1
	local token = bannerToken
	label.Text = nameOf(victim)
	tag.Visible = headshot
	for i, pip in pips do
		local lit = i <= count
		pip.BackgroundColor3 = if lit then PIP_ON else PIP_OFF
		pip.BackgroundTransparency = if lit then 0 else 0.7
	end
	group.Visible = true
	group.GroupTransparency = 0
	-- Each kill in the round lands a little bigger.
	scale.Scale = 1.25 + 0.08 * (math.min(count, #pips) - 1)
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

MatchState.changed("Round"):Connect(function()
	roundKills = 0
	table.clear(watchedKills)
end)

function KillFeed.kill(
	victim: unknown,
	attacker: unknown,
	sourceId: unknown,
	headshot: unknown,
	assistIds: unknown
)
	local v = if typeof(victim) == "Instance" then victim else nil
	local a = if typeof(attacker) == "Instance" then attacker else nil
	local id = if typeof(sourceId) == "string" then sourceId else ""
	local head = headshot == true
	local assists, myAssist = KillFeed.assistInfo(assistIds)
	row(a, v, id, head, assists, myAssist)
	if myAssist then
		showAssist()
	end
	local kills: number? = nil
	if a == player then
		roundKills += 1
		kills = roundKills
	elseif a and Watched.is(a) and not Watched.is(v) then
		-- Spectating: the one you watch got the kill (its tone, as if yours).
		local holder = Watched.get()
		if holder then
			kills = (watchedKills[holder] or 0) + 1
			watchedKills[holder] = kills
		end
	end
	if kills then
		local step = math.min(kills, #Audio.KILL_LADDER)
		-- A learned signature cue: its pitch is the ladder step, never jittered.
		AudioController.play(if head then Sounds.KillHead else Sounds.Kill, {
			group = "Feedback",
			volume = Audio.KILL_VOLUME,
			pitch = Audio.KILL_LADDER[step],
			jitter = false,
		})
		pop(v, head, kills)
	end
end

return KillFeed
