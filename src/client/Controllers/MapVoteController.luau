--!strict
-- The map vote screen, v3 (2026-11-16, owner's notes on v2 with a RIVALS
-- screenshot; vault/05 Production/Playtests/2026-11-16 Match Fixes Round 1.md
-- → 7): fills the Studio-built StarterGui.MapVote (backup
-- tools/studio/BuildMapVote.luau) from MatchState while the Phase is "Vote"
-- (MapVoteService):
--   * the world is blurred and covered (nothing reads through), every other
--     HUD screen sits under it, and the match top bar (TopBarController) sits
--     over it with the vote's clock;
--   * one card per option ("VoteOptions": Random first, then the maps): the
--     map's picture (Config/Match MAPS `image`), a name band in the card's
--     colour (1v1 maps green, team maps red, Random grey) with diagonal
--     stripes and the name plus its chance ("Arena [50%]": every vote is a
--     ticket);
--   * every player's vote is their server-set "MapVote" attribute: a square
--     avatar tile in their team colour, centred on that card's picture; more
--     votes share the space in a centred grid (smaller tiles, two rows from
--     five) instead of stacking; your pick's band and edge turn white;
--   * "VoteChosen" set: the other cards fade, the picked one moves to the
--     middle and grows; a Random win shows the drawn map on the Random card.
-- Motion (Shared/UiMotion: Quint, no overshoot, no sounds): cards grow in from
-- 0.9 and fade, 0.04 s apart; hover 1.025; tiles pop in and out; the winner
-- moves 0.5 s.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local CoreUi = require(ReplicatedStorage.Shared.CoreUi)
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
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local BOT_HEADSHOT = "rbxassetid://119185654291939" -- the top bar's helmet stand-in

-- Card colours (the band, its edge): 1v1 maps, team maps, Random; your pick.
local BAND_SMALL = Color3.fromHex("3E9E46")
local BAND_TEAM = Color3.fromHex("C8453A")
local BAND_RANDOM = Color3.fromHex("2A2A30")
local MINE = Color3.fromHex("F4F6F9")
local INK = K.color.ink
local WHITE = K.color.white

-- Layout (design px): the cards fill the space under the top bar.
local TOP, BOTTOM = 132, 1052
local WIDTH = 1820
local GAP = 18
local ASPECT = 0.6 -- card height / width
local MAX_W = 600

-- Motion.
local ENTER = 0.24
local STAGGER = 0.04
local EXIT = 0.14
local TILE = 0.14
local HOVER = 1.025
local WIN_MOVE = 0.5
local WIN_SCALE = 1.2
local BLUR = K.motion.blur
local BLUR_IN = 0.4

local player = Players.LocalPlayer
local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local cards: Frame
local grid: UIGridLayout
local stage: Frame
local backdrop: Frame
local templates: Instance
local blur: BlurEffect
local cell = Vector2.new(560, 330)

type Entry = {
	id: string,
	slot: Frame,
	card: CanvasGroup,
	pop: UIScale,
	band: Frame,
	title: TextLabel,
	outline: UIStroke,
	edge: UIStroke,
	votes: Frame,
	voteGrid: UIGridLayout,
	color: Color3,
	name: string, -- shown in the band (a Random win changes it)
	tiles: { [Player]: Frame },
}
local entries: { [string]: Entry } = {}
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

-- "OldTown" → "Old Town" (a MAPS `name` wins).
local function displayName(id: string): string
	if id == Config.VOTE.random then
		return "Random"
	end
	local e = entryFor(id)
	return if e and e.name then e.name else (id:gsub("(%l)(%u)", "%1 %2"))
end

local function myVote(): string?
	local v = player:GetAttribute(ATTRIBUTE)
	return if typeof(v) == "string" then v else nil
end

local function colorFor(id: string): Color3
	if id == Config.VOTE.random then
		return BAND_RANDOM
	end
	local e = entryFor(id)
	return if e and e.minTeam >= 2 then BAND_TEAM else BAND_SMALL
end

-- Your pick's band and edge turn white with dark words; the rest wear their
-- colour.
local function paint(e: Entry, mine: boolean)
	UiMotion.tween(e.band, K.motion.quick, { BackgroundColor3 = if mine then MINE else e.color })
	UiMotion.tween(e.edge, K.motion.quick, {
		Color = if mine then MINE else e.color,
		Thickness = if mine then 3 else 2,
	})
	UiMotion.tween(e.title, K.motion.quick, { TextColor3 = if mine then INK else WHITE })
	e.outline.Enabled = not mine
end

-- The tiles' size for `count` votes on a card: one row up to four, then two
-- rows, then three; they shrink to fit, centred.
local function tileLayout(e: Entry, count: number)
	local h = cell.Y
	local rows = if count <= 4 then 1 elseif count <= 8 then 2 else 3
	local perRow = math.ceil(math.max(count, 1) / rows)
	local byHeight = h * (if rows == 1 then 0.36 elseif rows == 2 then 0.26 else 0.19)
	local byWidth = (cell.X * 0.86) / perRow * 0.88
	local size = math.floor(math.min(byHeight, byWidth))
	local pad = math.max(4, math.floor(size * 0.12))
	e.voteGrid.CellSize = UDim2.fromOffset(size, size)
	e.voteGrid.CellPadding = UDim2.fromOffset(pad, pad)
	e.voteGrid.FillDirectionMaxCells = perRow -- even rows (3 + 3, not 5 + 1)
end

local function addTile(e: Entry, p: Player, index: number)
	local t = (child(templates, "Voter") :: Frame):Clone()
	t.LayoutOrder = index
	t.BackgroundColor3 = TeamColor.forTeam(Teams.of(p))
	local face = child(t, "Face") :: ImageLabel
	face.Image = if p.UserId > 0 then string.format(HEADSHOT, p.UserId) else BOT_HEADSHOT
	local pop = child(t, "Pop") :: UIScale
	pop.Scale = 0.5
	t.BackgroundTransparency = 1
	face.ImageTransparency = 1
	t.Parent = e.votes
	UiMotion.tween(pop, TILE, { Scale = 1 })
	UiMotion.tween(t, TILE, { BackgroundTransparency = 0 })
	UiMotion.tween(face, TILE, { ImageTransparency = 0 })
	e.tiles[p] = t
end

local function dropTile(e: Entry, p: Player)
	local t = e.tiles[p]
	e.tiles[p] = nil
	if not t then
		return
	end
	local pop = t:FindFirstChild("Pop")
	if pop and pop:IsA("UIScale") then
		UiMotion.out(pop, { Scale = 0.5 }, 0.1)
	end
	UiMotion.out(t, { BackgroundTransparency = 1 }, 0.1)
	local face = t:FindFirstChild("Face")
	if face and face:IsA("ImageLabel") then
		UiMotion.out(face, { ImageTransparency = 1 }, 0.1)
	end
	task.delay(0.12, t.Destroy, t)
end

-- Tiles, chances and your pick, from every player's MapVote attribute.
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
			if not e.tiles[p] then
				addTile(e, p, i)
			end
		end
		for p in e.tiles do
			if not here[p] then
				dropTile(e, p)
			end
		end
		tileLayout(e, #list)
		e.title.Text = if #list > 0 and total > 0
			then string.format("%s [%d%%]", e.name, math.floor(#list / total * 100 + 0.5))
			else e.name
		if shownChosen == "" then
			paint(e, id == mine)
		end
	end
end

local function clearCards()
	for _, e in entries do
		e.slot:Destroy()
		e.card:Destroy() -- a winner moved to the stage
	end
	table.clear(entries)
end

-- 3 a row (2 x 2 for four, 3 x 3 for nine, else 4 a row), as big as fits
-- under the top bar, centred.
local function placeGrid(count: number)
	local perRow = if count == 4 then 2 elseif count <= 6 or count == 9 then 3 else 4
	local rows = math.max(1, math.ceil(count / perRow))
	local w = math.min(MAX_W, (WIDTH - (perRow - 1) * GAP) / perRow)
	local h = w * ASPECT
	local room = BOTTOM - TOP
	if rows * h + (rows - 1) * GAP > room then
		h = (room - (rows - 1) * GAP) / rows
		w = h / ASPECT
	end
	w, h = math.floor(w), math.floor(h)
	cell = Vector2.new(w, h)
	grid.CellSize = UDim2.fromOffset(w, h)
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.FillDirectionMaxCells = perRow
	local cols = math.min(count, perRow)
	local totalW = cols * w + (cols - 1) * GAP
	local totalH = rows * h + (rows - 1) * GAP
	cards.Size = UDim2.fromOffset(totalW, totalH)
	cards.Position = UDim2.fromOffset(DESIGN.X / 2, TOP + math.max(0, (room - totalH) / 2))
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
		local band = child(card, "Band") :: Frame
		local title = child(band, "Title") :: TextLabel
		local votes = child(card, "Votes") :: Frame
		local map = entryFor(id)
		local picture = child(card, "Picture") :: ImageLabel
		picture.Image = if map and map.image then map.image else ""
		picture.Visible = picture.Image ~= "";
		(child(card, "Glyph") :: TextLabel).Visible = id == Config.VOTE.random
		local e: Entry = {
			id = id,
			slot = slot,
			card = card,
			pop = pop,
			band = band,
			title = title,
			outline = child(title, "Outline") :: UIStroke,
			edge = child(card, "Edge") :: UIStroke,
			votes = votes,
			voteGrid = child(votes, "Grid") :: UIGridLayout,
			color = colorFor(id),
			name = displayName(id),
			tiles = {},
		}
		title.Text = e.name
		band.BackgroundColor3 = e.color
		e.edge.Color = e.color
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
		})
		-- Enter: grows in from 0.9 and fades in, one after another.
		card.GroupTransparency = 1
		pop.Scale = 0.9
		slot.Parent = cards
		entries[id] = e
		task.delay(STAGGER * (i - 1), function()
			if entries[id] == e and shownChosen == "" then
				UiMotion.tween(card, ENTER, { GroupTransparency = 0 })
				UiMotion.tween(pop, ENTER, { Scale = 1 })
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
	-- Random drew this map: the Random card wins on screen, with its picture.
	local winner = entries[chosen] or entries[Config.VOTE.random]
	for _, e in entries do
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
	local map = entryFor(chosen)
	if winner.id ~= chosen then
		winner.name = displayName(chosen)
		local picture = child(winner.card, "Picture") :: ImageLabel
		picture.Image = if map and map.image then map.image else ""
		picture.Visible = picture.Image ~= "";
		(child(winner.card, "Glyph") :: TextLabel).Visible = not picture.Visible
		winner.color = colorFor(chosen)
	end
	winner.title.Text = winner.name
	paint(winner, false)
	-- From its cell to the stage at the same spot on screen, then the middle.
	local card = winner.card
	local scale = math.max(fit.Scale, 1e-3)
	local centre = (card.AbsolutePosition + card.AbsoluteSize / 2 - canvas.AbsolutePosition) / scale
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.fromOffset(cell.X, cell.Y)
	card.Position = UDim2.fromOffset(centre.X, centre.Y)
	card.Parent = stage
	UiMotion.tween(card, WIN_MOVE, {
		Position = UDim2.fromOffset(DESIGN.X / 2, (TOP + BOTTOM) / 2),
		GroupTransparency = 0,
	})
	UiMotion.rest(winner.pop, math.min(WIN_SCALE, 620 / math.max(cell.X, 1) * WIN_SCALE))
end

local function open(on: boolean)
	if isOpen == on then
		return
	end
	isOpen = on
	openToken += 1
	local token = openToken
	-- The mouse is free to click a card while the vote is up; Roblox's chat
	-- and player list step aside.
	CameraController.freeMouse("MapVote", on)
	CoreUi.menuMode(on)
	if on then
		gui.Enabled = true
		shownChosen = ""
		blur.Enabled = true
		UiMotion.tween(blur, BLUR_IN, { Size = BLUR })
		backdrop.BackgroundTransparency = 1
		UiMotion.tween(backdrop, ENTER, { BackgroundTransparency = 0.1 })
		buildCards()
		showChosen()
	else
		UiMotion.tween(blur, EXIT, { Size = 0 })
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
	backdrop = child(gui, "Backdrop") :: Frame
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
end

return MapVoteController
