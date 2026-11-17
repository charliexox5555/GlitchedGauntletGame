--!strict
-- The map vote screen, v2 (2026-11-16; plan and RIVALS study in vault/05
-- Production/Playtests/2026-11-16 Match Fixes Round 1.md → 7): fills the
-- Studio-built StarterGui.MapVote (backup tools/studio/BuildMapVote.luau)
-- from MatchState while the Phase is "Vote" (MapVoteService):
--   * one wide card per option ("VoteOptions": Random first, then the maps),
--     3 a row (2 x 2 for four), the map's name and team sizes from Config/Match
--     MAPS, its picture when the entry has an `image` (else a faint initial);
--   * every player's vote is their server-set "MapVote" attribute: each card's
--     foot fills to its share of the votes (its chance: every vote is a
--     ticket) with the %, and each voter is a small chip in their team colour;
--     your pick's fill is gold (the one gold thing) and its card sits a little
--     higher;
--   * no circle timer: a slanted bar under the title drains with the clock,
--     tenths under 5 s, red from 3 s;
--   * "VoteChosen" set: the other cards fade, the picked one moves to the
--     middle and grows, the title names the map.
-- Motion (Config/UiStyle, Shared/UiMotion: Quint, no overshoot, no sounds):
-- the world blurs; the header and the cards slide 12 px and fade in, cards
-- 0.04 s apart; hover lifts a card and grows it to 1.025; every vote change
-- eases (RIVALS redraws instantly).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)

local CameraController = require(script.Parent.CameraController)

local MapVoteController = {}

local DESIGN = Vector2.new(1920, 1080)
local ATTRIBUTE = "MapVote"
local K = UiStyle.KIT
local WHITE = K.color.white
local GOLD = K.color.gold
local URGENT = K.color.red
local SHARE = Color3.fromHex("2E2E34") -- a card's vote share (not yours)
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

-- Layout (design px, the builder's numbers).
local CELL = Vector2.new(470, 210)
local GAP = 26
local GRID_TOP, GRID_BOTTOM = 262, 1010 -- the cards sit centred between these

-- Motion (Soft Edge tokens).
local ENTER = 0.24 -- slide 12 px + fade in
local STAGGER = 0.04
local SLIDE = 12
local EXIT = 0.14
local CHANGE = 0.24 -- a vote share easing to its new size
local CHIP = 0.12
local HOVER = 1.025
local LIFT = 3 -- px a hovered card rises
local PICKED_LIFT = 6 -- px your pick sits higher
local WIN_MOVE = 0.5
local WIN_SCALE = 1.22
local BLUR = K.motion.blur
local BLUR_IN = 0.4

local player = Players.LocalPlayer
local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local cards: Frame
local grid: UIGridLayout
local stage: Frame
local head: Frame
local title: TextLabel
local sub: TextLabel
local clock: Frame
local fillClip: Frame
local fillSkin: ImageLabel
local seconds: TextLabel
local hint: TextLabel
local templates: Instance
local blur: BlurEffect

type Entry = {
	id: string,
	slot: Frame,
	card: CanvasGroup,
	pop: UIScale,
	share: Frame,
	chance: TextLabel,
	voters: Frame,
	chips: { [Player]: Frame },
	hovered: boolean,
	entered: boolean, -- its slide-in has started (settle waits for it)
}
local entries: { [string]: Entry } = {}
local order: { string } = {}
local shownChosen = ""
local openToken = 0
local isOpen = false

local function child(parent: Instance, name: string): Instance
	return parent:WaitForChild(name)
end

local function entryFor(id: string): Config.MapEntry?
	for _, e in Config.MAPS do
		if e.id == id then
			return e
		end
	end
	return nil
end

local function sizeText(e: Config.MapEntry?): string
	if not e then
		return "ANY MAP"
	end
	if e.minTeam == e.maxTeam then
		return string.format("%dV%d", e.minTeam, e.minTeam)
	end
	return string.format("%dV%d – %dV%d", e.minTeam, e.minTeam, e.maxTeam, e.maxTeam)
end

local function displayName(id: string): string
	if id == Config.VOTE.random then
		return "RANDOM"
	end
	local e = entryFor(id)
	local name = if e and e.name then e.name else (id:gsub("(%l)(%u)", "%1 %2"))
	return string.upper(name)
end

local function myVote(): string?
	local v = player:GetAttribute(ATTRIBUTE)
	return if typeof(v) == "string" then v else nil
end

-- A card's resting place in its cell: up a little when it's your pick or
-- hovered.
local function restPosition(e: Entry): UDim2
	local mine = e.id == myVote() and shownChosen == ""
	local lift = (if mine then PICKED_LIFT else 0) + (if e.hovered then LIFT else 0)
	return UDim2.new(0.5, 0, 0.5, -lift)
end

local function settle(e: Entry)
	if e.entered and shownChosen == "" then
		UiMotion.tween(e.card, K.motion.quick, { Position = restPosition(e) })
	end
end

-- A voter's chip: their head on a square in their team colour, popping in.
local function addChip(e: Entry, p: Player, index: number)
	local c = (child(templates, "Chip") :: Frame):Clone()
	c.LayoutOrder = index
	c.BackgroundColor3 = TeamColor.forTeam(Teams.of(p))
	local face = child(c, "Face") :: ImageLabel
	face.Image = string.format(HEADSHOT, math.max(p.UserId, 1))
	local pop = Instance.new("UIScale")
	pop.Scale = 0.5
	pop.Parent = c
	c.BackgroundTransparency = 1
	face.ImageTransparency = 1
	face.BackgroundTransparency = 1
	c.Parent = e.voters
	UiMotion.tween(pop, CHIP, { Scale = 1 })
	UiMotion.tween(c, CHIP, { BackgroundTransparency = 0 })
	UiMotion.tween(face, CHIP, { ImageTransparency = 0, BackgroundTransparency = 0 })
	e.chips[p] = c
end

local function dropChip(e: Entry, p: Player)
	local c = e.chips[p]
	e.chips[p] = nil
	if not c then
		return
	end
	local pop = c:FindFirstChildOfClass("UIScale")
	if pop then
		UiMotion.out(pop, { Scale = 0.5 }, 0.1)
	end
	UiMotion.out(c, { BackgroundTransparency = 1 }, 0.1)
	local face = c:FindFirstChild("Face")
	if face and face:IsA("ImageLabel") then
		UiMotion.out(face, { ImageTransparency = 1, BackgroundTransparency = 1 }, 0.1)
	end
	task.delay(0.12, c.Destroy, c)
end

-- Shares, chips and your pick, from every player's MapVote attribute. Every
-- change eases: shares grow or shrink, chips pop in and out.
local function refreshVotes()
	local byOption: { [string]: { Player } } = {}
	local total = 0
	for _, p in Players:GetPlayers() do
		local v = p:GetAttribute(ATTRIBUTE)
		if typeof(v) == "string" and entries[v] then
			byOption[v] = byOption[v] or {}
			table.insert(byOption[v], p)
			total += 1
		end
	end
	local mine = myVote()
	for id, e in entries do
		local list = byOption[id] or {}
		local here: { [Player]: boolean } = {}
		for i, p in list do
			here[p] = true
			if not e.chips[p] then
				addChip(e, p, i)
			end
		end
		for p in e.chips do
			if not here[p] then
				dropChip(e, p)
			end
		end
		local share = if total > 0 then #list / total else 0
		UiMotion.tween(e.share, CHANGE, {
			Size = UDim2.fromScale(share, 1),
			BackgroundColor3 = if id == mine then GOLD else SHARE,
		})
		e.chance.Text = if #list > 0
			then string.format("%d%%", math.floor(share * 100 + 0.5))
			else ""
		settle(e)
	end
end

local function clearCards()
	for _, e in entries do
		e.slot:Destroy()
		e.card:Destroy() -- a winner moved to the stage
	end
	table.clear(entries)
	table.clear(order)
end

-- The grid: 3 a row (2 x 2 for four), centred under the header.
local function placeGrid(count: number)
	local perRow = if count == 4 then 2 else 3
	grid.FillDirectionMaxCells = perRow
	local cols = math.min(count, perRow)
	local rows = math.max(1, math.ceil(count / perRow))
	local w = cols * CELL.X + (cols - 1) * GAP
	local h = rows * CELL.Y + (rows - 1) * GAP
	cards.Size = UDim2.fromOffset(w, h)
	cards.Position =
		UDim2.fromOffset(DESIGN.X / 2, GRID_TOP + math.max(0, (GRID_BOTTOM - GRID_TOP - h) / 2))
end

local function buildCards()
	clearCards()
	local raw = MatchState.get("VoteOptions")
	if typeof(raw) ~= "string" or raw == "" then
		return
	end
	local ids = string.split(raw, ",")
	placeGrid(#ids)
	for i, id in ids do
		local slot = (child(templates, "Slot") :: Frame):Clone()
		slot.Name = id
		slot.LayoutOrder = i
		local card = child(slot, "Card") :: CanvasGroup
		local pop = child(card, "Pop") :: UIScale
		local hit = child(card, "Hit") :: TextButton
		local e = entryFor(id)
		local isRandom = id == Config.VOTE.random
		local foot = child(card, "Foot") :: Frame;
		(child(card, "MapName") :: TextLabel).Text = displayName(id);
		(child(card, "Teams") :: TextLabel).Text = sizeText(e)
		local picture = child(card, "Picture") :: ImageLabel
		picture.Image = e and e.image or ""
		picture.Visible = picture.Image ~= ""
		local glyph = child(card, "Glyph") :: TextLabel
		glyph.Text = if isRandom then "?" else string.sub(displayName(id), 1, 1)
		glyph.Visible = not picture.Visible
		local entry: Entry = {
			id = id,
			slot = slot,
			card = card,
			pop = pop,
			share = child(foot, "Share") :: Frame,
			chance = child(foot, "Chance") :: TextLabel,
			voters = child(foot, "Voters") :: Frame,
			chips = {},
			hovered = false,
			entered = false,
		}
		UiMotion.button(hit, pop, function()
			if shownChosen == "" then
				Net.event("MapVote"):FireServer(id)
			end
		end, {
			card = true,
			hover = HOVER,
			enabled = function()
				return shownChosen == ""
			end,
			onHover = function(on)
				entry.hovered = on and shownChosen == ""
				settle(entry)
			end,
		})
		-- Enter: 12 px up and in from clear, one after another.
		card.GroupTransparency = 1
		card.Position = UDim2.new(0.5, 0, 0.5, SLIDE)
		slot.Parent = cards
		entries[id] = entry
		table.insert(order, id)
		task.delay(STAGGER * (i - 1), function()
			if entries[id] == entry and shownChosen == "" then
				entry.entered = true
				UiMotion.tween(
					card,
					ENTER,
					{ GroupTransparency = 0, Position = restPosition(entry) }
				)
			end
		end)
	end
	refreshVotes()
end

-- The winner moves from its cell to the middle of the screen (the stage) and
-- grows; the rest fade out.
local function showChosen()
	local chosen = MatchState.get("VoteChosen")
	chosen = if typeof(chosen) == "string" then chosen else ""
	if chosen == shownChosen then
		return
	end
	shownChosen = chosen
	if chosen == "" then
		return
	end
	title.Text = displayName(chosen)
	sub.Text = "LOADING MAP"
	UiMotion.out(clock, { Position = clock.Position + UDim2.fromOffset(0, -6) }, EXIT)
	for _, d in clock:GetDescendants() do
		if d:IsA("ImageLabel") then
			UiMotion.out(d, { ImageTransparency = 1 }, EXIT)
		elseif d:IsA("TextLabel") then
			UiMotion.out(d, { TextTransparency = 1 }, EXIT)
		end
	end
	UiMotion.out(hint, { TextTransparency = 1 }, EXIT)
	-- Random drew this map: the Random card wins on screen, now named.
	local winner = entries[chosen] or entries[Config.VOTE.random]
	for _, e in entries do
		e.hovered = false
		if e ~= winner then
			UiMotion.tween(
				e.card,
				EXIT,
				{ GroupTransparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			UiMotion.rest(e.pop, 0.96)
		end
	end
	if not winner then
		return
	end
	if winner.id ~= chosen then
		(child(winner.card, "MapName") :: TextLabel).Text = displayName(chosen);
		(child(winner.card, "Teams") :: TextLabel).Text = "RANDOM PICK"
	end
	-- From its cell to the stage at the same spot on screen, then to the middle.
	local card = winner.card
	local scale = math.max(fit.Scale, 1e-3)
	local centre = (card.AbsolutePosition + card.AbsoluteSize / 2 - canvas.AbsolutePosition) / scale
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.fromOffset(CELL.X, CELL.Y)
	card.Position = UDim2.fromOffset(centre.X, centre.Y)
	card.Parent = stage
	UiMotion.tween(
		card,
		WIN_MOVE,
		{ Position = UDim2.fromOffset(DESIGN.X / 2, 560), GroupTransparency = 0 }
	)
	UiMotion.rest(winner.pop, WIN_SCALE)
	UiMotion.tween(winner.share, CHANGE, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD })
end

local function matchLine(): string
	local size = MatchState.get("VoteTeamSize")
	local mode = if typeof(size) == "number" then string.format("%dV%d  ·  ", size, size) else ""
	return string.format("%sFIRST TO %d", mode, Config.ROUNDS_TO_WIN)
end

-- The header's words and the clock back to full (a vote can follow a vote).
local function resetHeader()
	clock.Position = UiMotion.home(clock)
	for _, d in clock:GetDescendants() do
		if d:IsA("ImageLabel") then
			d.ImageTransparency = if d.Name == "Gloss" then 0.55 else 0
		elseif d:IsA("TextLabel") then
			d.TextTransparency = 0
		end
	end
	hint.TextTransparency = 0
	title.Text = "VOTE FOR A MAP"
	sub.Text = matchLine()
end

local function open(on: boolean)
	if isOpen == on then
		return
	end
	isOpen = on
	openToken += 1
	local token = openToken
	-- The mouse is free to click a card while the vote is up.
	CameraController.freeMouse("MapVote", on)
	if on then
		gui.Enabled = true
		shownChosen = ""
		resetHeader()
		blur.Enabled = true
		UiMotion.tween(blur, BLUR_IN, { Size = BLUR })
		local backdrop = child(gui, "Backdrop") :: Frame
		backdrop.BackgroundTransparency = 1
		UiMotion.tween(backdrop, ENTER, { BackgroundTransparency = 0.12 })
		UiMotion.slideIn(head, 0, -SLIDE, 0, ENTER)
		buildCards()
		showChosen()
	else
		UiMotion.tween(blur, EXIT, { Size = 0 })
		local backdrop = child(gui, "Backdrop") :: Frame
		UiMotion.out(backdrop, { BackgroundTransparency = 1 }, EXIT)
		for _, e in entries do
			UiMotion.out(e.card, { GroupTransparency = 1 }, EXIT)
		end
		task.delay(EXIT + 0.02, function()
			if token ~= openToken then
				return -- opened again meanwhile
			end
			gui.Enabled = false
			blur.Enabled = false
			clearCards()
		end)
	end
end

-- The clock: the bar drains over the vote, the seconds count down (tenths
-- under 5 s), both red from 3 s.
local function tick()
	if shownChosen ~= "" then
		return
	end
	local endsAt = MatchState.get("EndsAt")
	local left = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
	left = math.max(0, left)
	fillClip.Size = UDim2.fromScale(math.clamp(left / Config.VOTE.seconds, 0, 1), 1)
	seconds.Text = if left < 5 then string.format("%.1f", left) else tostring(math.ceil(left))
	local urgent = left <= 3
	seconds.TextColor3 = if urgent then URGENT else WHITE
	fillSkin.ImageColor3 = if urgent then URGENT else WHITE
end

function MapVoteController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	-- The vote runs before anyone spawns, and StarterGui is only copied into
	-- PlayerGui on a spawn: take our own copy now, and drop the one Roblox
	-- adds at the first spawn.
	local source = StarterGui:WaitForChild("MapVote") :: ScreenGui
	gui = source:Clone()
	gui.Name = "MapVoteLive"
	gui.Enabled = false
	gui.Parent = playerGui
	local function dropCopy(c: Instance)
		if c.Name == "MapVote" and c:IsA("ScreenGui") then
			task.defer(c.Destroy, c)
		end
	end
	for _, c in playerGui:GetChildren() do
		dropCopy(c)
	end
	playerGui.ChildAdded:Connect(dropCopy)
	local folder = ReplicatedStorage:WaitForChild("UiTemplates")
	templates = folder:WaitForChild("MapVote")
	canvas = child(gui, "Canvas") :: Frame
	fit = child(canvas, "Fit") :: UIScale
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.35, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	cards = child(canvas, "Cards") :: Frame
	grid = child(cards, "Grid") :: UIGridLayout
	stage = child(canvas, "Stage") :: Frame
	hint = child(canvas, "Hint") :: TextLabel
	head = child(canvas, "Head") :: Frame
	UiMotion.home(head)
	title = child(child(head, "TitlePlate"), "Title") :: TextLabel
	sub = child(head, "Sub") :: TextLabel
	clock = child(head, "Clock") :: Frame
	UiMotion.home(clock)
	fillClip = child(clock, "FillClip") :: Frame
	fillSkin = child(child(fillClip, "Fill"), "Skin") :: ImageLabel
	seconds = child(clock, "Seconds") :: TextLabel

	-- The world behind the vote blurs (ours, only while it's up).
	blur = Instance.new("BlurEffect")
	blur.Name = "MapVoteBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	local function refresh()
		local on = MatchState.phase() == "Vote"
		open(on)
		if on then
			showChosen()
		end
	end
	MatchState.changed("Phase"):Connect(refresh)
	MatchState.changed("VoteOptions"):Connect(function()
		if isOpen and shownChosen == "" then
			buildCards()
		end
	end)
	MatchState.changed("VoteChosen"):Connect(function()
		if isOpen then
			showChosen()
		end
	end)
	local function watch(p: Player)
		p:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
			if isOpen and shownChosen == "" then
				refreshVotes()
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function()
		if isOpen and shownChosen == "" then
			task.defer(refreshVotes)
		end
	end)
	refresh()
	task.spawn(function()
		while true do
			if isOpen then
				tick()
			end
			task.wait(0.05)
		end
	end)
end

return MapVoteController
