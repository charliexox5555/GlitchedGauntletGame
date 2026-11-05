--!strict
-- The match's on-screen state, v2 look (vault/01 Design/Match HUD.md; v1 layout
-- in vault/02 Art/UI Design.md): the top bar
-- (both team plates with names and health, the score, first-to-5 diamonds, the
-- round and weapon phase, the clock) and the full-width banners (get ready,
-- countdown, fight, round won / lost, match end). It only shows what
-- MatchState says; the server decides all of it. The top bar sits above the
-- draft screen, which has none of its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Health = require(ReplicatedStorage.Shared.Health)
local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)

local Ui = require(script.Parent.Parent.Util.Ui)
local UiSound = require(script.Parent.Parent.Util.UiSound)

local MatchHudController = {}

local player = Players.LocalPlayer
local C = Theme.COLORS
local make = Ui.make

local TICK = 0.1 -- seconds between refreshes
local HEALTH_TICK = 0.25 -- seconds between team health scans
local FIGHT_MESSAGE_TIME = 1 -- seconds "FIGHT" stays up
local RESET_TRIES = 10
local BAR_W = 220
local BAND_SIZE = UDim2.fromScale(1, 260 / 1080)
local TICK_FROM: { [string]: number } = { Draft = 5, Countdown = 3, Live = 5 } -- seconds left when the clock ticks
local URGENT_LIVE = 10 -- the round clock turns red this many seconds from the end

-- The sound a banner makes as it comes in (by its title).
local BANNER_SOUND: { [string]: string } = {
	["GET READY"] = "Banner",
	FIGHT = "Fight",
	["ROUND WON"] = "RoundWon",
	["ROUND LOST"] = "RoundLost",
	DRAW = "Banner",
	VICTORY = "Victory",
	DEFEAT = "RoundLost",
}

type Side = {
	name: TextLabel,
	score: TextLabel,
	scorePop: UIScale,
	fill: Frame,
	pips: { Frame },
	shown: number, -- the score drawn (-1 before the first refresh)
}
type Ui = {
	bar: Frame,
	clock: TextLabel,
	clockPop: UIScale,
	round: TextLabel,
	ally: Side,
	enemy: Side,
	band: Frame,
	bandGradient: UIGradient,
	lines: { Frame },
	content: Frame,
	pop: UIScale,
	kicker: TextLabel,
	title: TextLabel,
	sub: TextLabel,
	shownTitle: string,
}

-- A rounded v2 plate behind part of the top bar (team plates get their team
-- colour as a soft outline).
local function plate(bar: Frame, name: string, x: number, w: number, h: number, edge: Color3?)
	local p = Ui.cut(bar, {
		Name = name,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(w, h),
	}, {
		radius = UiStyle.RADIUS.lg,
		color = C.panel,
		transparency = 0.02, -- opaque: bright world signs must not show through
		line = edge or C.white,
		lineTransparency = if edge then 0.5 else UiStyle.ALPHA.stroke,
	})
	UiKit.shadow(p, UiStyle.RADIUS.lg, 0.7)
end

local function side(bar: Frame, enemy: boolean): Side
	local color = if enemy then C.enemy else C.ally
	local name = Ui.text(bar, "", "label", {
		Position = UDim2.fromOffset(if enemy then 824 else 56, 8),
		Size = UDim2.fromOffset(BAR_W, 16),
		TextColor3 = color,
		TextXAlignment = if enemy then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
	})
	local back = make("Frame", {
		Position = UDim2.fromOffset(if enemy then 824 else 56, 46),
		Size = UDim2.fromOffset(BAR_W, 8),
		BorderSizePixel = 0,
		BackgroundColor3 = C.lineSoft,
		ClipsDescendants = true,
	}, bar)
	UiKit.corner(back, 4)
	local fill = make("Frame", {
		AnchorPoint = Vector2.new(if enemy then 1 else 0, 0),
		Position = UDim2.fromScale(if enemy then 1 else 0, 0),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = color,
	}, back)
	UiKit.corner(fill, 4)
	local score = Ui.text(bar, "0", "displayM", {
		-- Centre-anchored: its pop (a UIScale) grows from the middle.
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(if enemy then 752 else 348, 34),
		Size = UDim2.fromOffset(60, 56),
		TextSize = 48,
		TextColor3 = color,
	})
	local pips = {}
	for i = 1, Config.ROUNDS_TO_WIN do
		-- Ally diamonds fill toward the clock from the left, enemy from the right.
		local x = if enemy then 560 + (i - 1) * 14 else 476 + (Config.ROUNDS_TO_WIN - i) * 14
		pips[i] = make("Frame", {
			Position = UDim2.fromOffset(x, 90),
			Size = UDim2.fromOffset(8, 8),
			Rotation = 45,
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
		}, bar)
	end
	return {
		name = name,
		score = score,
		scorePop = make("UIScale", {}, score),
		fill = fill,
		pips = pips,
		shown = -1,
	}
end

local function build(): Ui
	-- Core-UI safe area: the bar starts under Roblox's top bar instead of
	-- sitting in its strip (LihFolk: Safe Areas and Insets). The banner is
	-- full-width art in the same gui (nothing to press).
	local gui = make("ScreenGui", {
		Name = "MatchHud",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9, -- above the draft screen (8)
	}, player:WaitForChild("PlayerGui"))

	local bar = make("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(1100, 110),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	-- Three separate plates, 8 px apart (v1 overlapped angled images).
	plate(bar, "AllyPlate", 0, 404, 70, C.ally)
	plate(bar, "EnemyPlate", 696, 404, 70, C.enemy)
	plate(bar, "ClockPlate", 412, 276, 104)
	local round = Ui.text(bar, "", "label", {
		Position = UDim2.fromOffset(412, 12),
		Size = UDim2.fromOffset(276, 18),
		TextColor3 = C.textSecondary,
	})
	local clock = Ui.text(bar, "", "timer", {
		-- Centre-anchored: its pop (a UIScale) grows from the middle.
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(550, 56),
		Size = UDim2.fromOffset(276, 52),
	})

	-- Banner: a full-width band in the result's colour, its words in a
	-- design-size frame in the middle.
	local band = make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.45),
		Size = BAND_SIZE,
		ClipsDescendants = true,
		BorderSizePixel = 0,
		BackgroundColor3 = C.white,
		Visible = false,
	}, gui)
	local bandGradient = make("UIGradient", {}, band)
	local lines = {}
	for i, y in { 0, 1 } do
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 3),
			BorderSizePixel = 0,
			BackgroundColor3 = C.white,
		}, band)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, line)
		lines[i] = line
	end
	local content = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 260),
		BackgroundTransparency = 1,
	}, band)
	Ui.fit(content)
	local inner = make("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, content)
	local pop = make("UIScale", {}, inner)
	local kicker = Ui.text(inner, "", "label", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.fromOffset(1920, 16),
		TextColor3 = C.textSecondary,
	})
	local title = Ui.text(inner, "", "displayXL", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.fromOffset(1920, 150),
	})
	local sub = Ui.text(inner, "", "displayM", {
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.fromOffset(1920, 44),
		TextSize = 34,
		RichText = true,
	})

	local ally, enemy = side(bar, false), side(bar, true)
	Ui.fit(bar)
	return {
		bar = bar,
		clock = clock,
		clockPop = make("UIScale", {}, clock),
		round = round,
		ally = ally,
		enemy = enemy,
		band = band,
		bandGradient = bandGradient,
		lines = lines,
		content = content,
		pop = pop,
		kicker = kicker,
		title = title,
		sub = sub,
		shownTitle = "",
	}
end

local function myTeam(): number
	return Teams.of(player) or 1
end

local function clockText(seconds: number): string
	local whole = math.ceil(seconds)
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function phaseName(round: number): string
	local found = Config.PHASES[1]
	for _, p in Config.PHASES do
		if round >= p.fromRound then
			found = p
		end
	end
	return string.upper(found.name)
end

-- Every fighter on a team: players' characters, plus dummies with a TeamId
-- (the test opponent, in Workspace.Dummies). Health share 0..1, and the names.
local function teamState(team: number): (number, { string })
	local health, max = 0, 0
	local names: { string } = {}
	for _, p in Players:GetPlayers() do
		if Teams.of(p) == team then
			table.insert(names, if p == player then "YOU" else string.upper(p.DisplayName))
			local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				health += Health.get(humanoid)
				max += Health.max(humanoid)
			end
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	for _, model in if dummies then dummies:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("TeamId") == team then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				table.insert(names, string.upper(model.Name))
				health += Health.get(humanoid)
				max += Health.max(humanoid)
			end
		end
	end
	return if max > 0 then health / max else 1, names
end

local liveSince = -math.huge
local lastHealth = -math.huge
local lastTick = -1
local bandToken = 0

-- A quick pop through a UIScale.
local function pop(scale: UIScale, peak: number)
	scale.Scale = peak
	Ui.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function setSide(s: Side, score: number, share: number?, names: { string }?)
	s.score.Text = tostring(score)
	for i, pip in s.pips do
		pip.BackgroundTransparency = if i <= score then 0 else 0.75
	end
	if s.shown >= 0 and score > s.shown then
		-- A point: the new diamond and the number pop.
		local pip = s.pips[score]
		if pip then
			pip.Size = UDim2.fromOffset(16, 16)
			pip.Position -= UDim2.fromOffset(4, 4)
			local home = pip.Position + UDim2.fromOffset(4, 4)
			Ui.tween(
				pip,
				0.35,
				{ Size = UDim2.fromOffset(8, 8), Position = home },
				Enum.EasingStyle.Back
			)
		end
		pop(s.scorePop, 1.4)
		UiSound.play("Score")
	end
	s.shown = score
	if share then
		s.fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	end
	if names then
		s.name.Text = if #names == 0
			then ""
			elseif #names == 1 then names[1]
			else table.concat(names, " · ")
	end
end

-- The band's look: a colour that fades out to both sides.
local function tintBand(ui: Ui, color: Color3)
	-- Neutral banners (countdown, GET READY, FIGHT) are just a dark band.
	local edge = if color == C.white then C.scrim else color
	ui.bandGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, edge),
		ColorSequenceKeypoint.new(0.5, C.scrim),
		ColorSequenceKeypoint.new(1, edge),
	})
	ui.bandGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, line in ui.lines do
		line.BackgroundColor3 = if color == C.white then C.lineStrong else color
	end
	ui.title.TextColor3 = if color == C.white then C.text else color
end

local function refresh(ui: Ui)
	local phase = MatchState.phase()
	ui.bar.Visible = phase ~= nil and phase ~= "Waiting"
	local mine = myTeam()
	local theirs = if mine == 1 then 2 else 1
	local scoreOne = MatchState.get("Score1") or 0
	local scoreTwo = MatchState.get("Score2") or 0
	local now = os.clock()
	if now - lastHealth > HEALTH_TICK then
		lastHealth = now
		local myShare, myNames = teamState(mine)
		local theirShare, theirNames = teamState(theirs)
		setSide(ui.ally, if mine == 1 then scoreOne else scoreTwo, myShare, myNames)
		setSide(ui.enemy, if mine == 1 then scoreTwo else scoreOne, theirShare, theirNames)
	end
	local left = MatchState.timeLeft()
	ui.clock.Text = clockText(left)
	-- The last seconds: the clock ticks (sound + pop) and goes red.
	local second = math.ceil(left)
	local from = TICK_FROM[phase or ""]
	if from and second >= 1 and second <= from and second ~= lastTick then
		lastTick = second
		UiSound.play(if second == 1 then "TickFinal" else "Tick")
		pop(ui.clockPop, 1.18)
	elseif not from or second > from then
		lastTick = -1
	end
	local urgent = (phase == "Draft" and second <= TICK_FROM.Draft)
		or phase == "Countdown"
		or (phase == "Live" and second <= URGENT_LIVE)
	ui.clock.TextColor3 = if urgent and second > 0 then C.enemy else C.text
	local round = MatchState.get("Round") or 0
	ui.round.Text = if round > 0
		then string.format("ROUND %d  //  %s", round, phaseName(round))
		else string.format("FIRST TO %d", Config.ROUNDS_TO_WIN)

	local kicker, title, sub, color = "", "", "", C.white
	local myScore = if mine == 1 then scoreOne else scoreTwo
	local theirScore = if mine == 1 then scoreTwo else scoreOne
	local scoreLine = string.format(
		'<font color="#%s">%d</font>   —   <font color="#%s">%d</font>',
		C.ally:ToHex(),
		myScore,
		C.enemy:ToHex(),
		theirScore
	)
	if phase == "Waiting" then
		title = "WAITING FOR OPPONENT"
	elseif phase == "Ready" then
		kicker, title, sub =
			string.format("FIRST TO %d", Config.ROUNDS_TO_WIN),
			"GET READY",
			tostring(math.ceil(left))
	elseif phase == "Draft" then
		-- The draft screen covers the middle until you've locked in.
		if player:GetAttribute("DraftLocked") == true then
			kicker, title, sub =
				string.format("ROUND %d", round), "LOCKED IN", "Waiting for the other players"
			color = C.ready
		end
	elseif phase == "Countdown" then
		kicker, title = string.format("ROUND %d", round), tostring(math.max(math.ceil(left), 1))
	elseif phase == "Live" then
		if now - liveSince < FIGHT_MESSAGE_TIME then
			kicker, title = string.format("ROUND %d", round), "FIGHT"
		end
	elseif phase == "RoundEnd" then
		local winner = MatchState.get("RoundWinner") or 0
		kicker = string.format("ROUND %d", round)
		if winner == 0 then
			title, sub = "DRAW", "No point for either side"
		elseif winner == mine then
			title, sub, color = "ROUND WON", scoreLine, C.ally
		else
			title, sub, color = "ROUND LOST", scoreLine, C.enemy
		end
	elseif phase == "MatchEnd" then
		local won = MatchState.get("MatchWinner") == mine
		kicker, title, sub, color =
			"MATCH OVER",
			if won then "VICTORY" else "DEFEAT",
			scoreLine,
			if won then C.ally else C.enemy
	end

	ui.kicker.Text = kicker
	ui.sub.Text = sub
	if title ~= ui.shownTitle then
		local was = ui.shownTitle
		ui.shownTitle = title
		bandToken += 1
		local token = bandToken
		if title == "" then
			-- Out: the band folds shut, then hides.
			Ui.tween(
				ui.band,
				Theme.MOTION.exit,
				{ Size = UDim2.fromScale(1, 0) },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
			task.delay(Theme.MOTION.exit, function()
				if token == bandToken then
					ui.band.Visible = false
				end
			end)
			return
		end
		ui.title.Text = title
		tintBand(ui, color)
		if was == "" then
			-- In: the band opens from its middle line.
			ui.band.Size = UDim2.fromScale(1, 0)
			ui.band.Visible = true
			Ui.tween(ui.band, 0.22, { Size = BAND_SIZE }, Enum.EasingStyle.Quint)
		end
		ui.pop.Scale = 1.15
		Ui.tween(ui.pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		local sound = BANNER_SOUND[title]
		if sound then
			UiSound.play(sound)
		end
	end
end

-- One life per round, so no Reset Character in a match. SetCore isn't ready
-- right at startup, so it takes a few tries.
local function disableReset()
	for _ = 1, RESET_TRIES do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(1)
	end
end

-- Roblox's own UI in a match (Config/UiStyle FLAGS): the player list steps
-- aside for the top bar and kill feed, and the chat window moves to the left
-- middle, so nothing of ours sits under either (LihFolk: Safe Areas and Insets).
local function arrangeCoreUi()
	local flags = UiStyle.FLAGS
	if flags.matchHidePlayerList then
		for _ = 1, RESET_TRIES do
			local ok =
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			if ok then
				break
			end
			task.wait(1)
		end
	end
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window then
		pcall(function()
			(window :: any).VerticalAlignment = (Enum.VerticalAlignment :: any)[flags.matchChatVertical]
		end)
	end
end

function MatchHudController.start()
	local ui = build()
	task.spawn(arrangeCoreUi)
	if not TestMode.isOn() then
		task.spawn(disableReset)
	end
	MatchState.changed("Phase"):Connect(function()
		if MatchState.phase() == "Live" then
			liveSince = os.clock()
		end
	end)
	while true do
		refresh(ui)
		task.wait(TICK)
	end
end

return MatchHudController
