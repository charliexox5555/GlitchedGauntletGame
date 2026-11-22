--!strict
-- The map vote screen, v4 (2026-11-16: v3 followed the owner's RIVALS
-- screenshot, v4 gives it our own character; vault/05 Production/Playtests/
-- 2026-11-16 Match Fixes Round 1.md → 7): fills the Studio-built StarterGui.MapVote (backup
-- tools/studio/BuildMapVote.luau) from MatchState while the Phase is "Vote"
-- (MapVoteService):
--   * the world is blurred and covered (nothing reads through), every other
--     HUD screen sits under it, and the match top bar (TopBarController) sits
--     over it with the vote's clock;
--   * one card per option ("VoteOptions": Random first, then the maps), each
--     with our cut top-right corner: the map's picture (Config/Match MAPS
--     `image`), a charcoal name band with a coloured slash (1v1 maps green,
--     team maps red, Random grey), the team sizes over the uppercase name and
--     the chance on the right (every vote is a ticket);
--   * every player's vote is their server-set "MapVote" attribute: an avatar
--     tile in their team colour (the same cut corner), centred on that card's
--     picture; more votes share the space in a centred grid (smaller tiles,
--     even rows) instead of stacking; your pick's band turns gold;
--   * "VoteChosen" set: the other cards fade, the picked one moves to the
--     middle and grows; a Random win shows the drawn map on the Random card.
-- Motion (Shared/UiMotion: Quint, no overshoot, no sounds): cards grow in from
-- 0.9 and fade, 0.04 s apart; hover 1.025; tiles pop in and out; the winner
-- moves 0.5 s.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local HealthLog = require(ReplicatedStorage.Shared.HealthLog)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local Config = require(ReplicatedStorage.Shared.Config.Match)
local CoreUi = require(ReplicatedStorage.Shared.CoreUi)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSound = require(script.Parent.Parent.Util.UiSound)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)

local CameraController = require(script.Parent.CameraController)

local MapVoteController = {}

local DESIGN = Vector2.new(1920, 1080)
local ATTRIBUTE = "MapVote"
local K = UiStyle.KIT
local BOT_HEADSHOT = "rbxassetid://119185654291939" -- the top bar's helmet stand-in

-- The band's slash: 1v1 maps, team maps, Random. The band is charcoal; your
-- pick's band is gold (the one gold thing) with dark words.
local SLASH_SMALL = Color3.fromHex("3E9E46")
local SLASH_TEAM = Color3.fromHex("C8453A")
local SLASH_RANDOM = Color3.fromHex("6E6E78")
local BAND = K.color.navy
local MINE = K.color.gold
local INK = K.color.ink
local WHITE = K.color.white
local MUTED = K.color.muted
local MUTED_ON_GOLD = Color3.fromHex("5A4716")
-- Our cut corner (design px at the card's size): cards and voter tiles.
local CARD_CUT = 34
local TILE_CUT_SHARE = 0.15

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
	slash: Frame,
	title: TextLabel,
	teams: TextLabel,
	chance: TextLabel,
	votes: Frame,
	voteGrid: UIGridLayout,
	color: Color3,
	name: string, -- shown in the band (a Random win changes it)
	sizes: string, -- the team sizes line
	tiles: { [Instance]: CanvasGroup },
	selected: boolean?,
	tileCount: number?,
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

-- "OldTown" → "OLD TOWN" (a MAPS `name` wins).
local function displayName(id: string): string
	if id == Config.VOTE.random then
		return "RANDOM"
	end
	local e = entryFor(id)
	return string.upper(if e and e.name then e.name else (id:gsub("(%l)(%u)", "%1 %2")))
end

local function sizeText(id: string): string
	local e = entryFor(id)
	if not e then
		return "ANY MAP"
	end
	if e.minTeam == e.maxTeam then
		return string.format("%dV%d", e.minTeam, e.minTeam)
	end
	return string.format("%dV%d – %dV%d", e.minTeam, e.minTeam, e.maxTeam, e.maxTeam)
end

-- Puts a `Cut` gradient's hard step on the top-right corner's diagonal, `a`
-- px in on a `w` x `h` box (the builder's cut()).
local function setCut(gradient: Instance?, a: number, w: number, h: number)
	if gradient and gradient:IsA("UIGradient") and w > 0 and h > 0 then
		gradient.Offset = Vector2.new(0.5 - a / w / 2, -(0.5 - a / h / 2))
	end
end

local function myVote(): string?
	local v = StateValues.get(player, ATTRIBUTE)
	return if typeof(v) == "string" then v else nil
end

local function colorFor(id: string): Color3
	if id == Config.VOTE.random then
		return SLASH_RANDOM
	end
	local e = entryFor(id)
	return if e and e.minTeam >= 2 then SLASH_TEAM else SLASH_SMALL
end

-- Your pick's band turns gold with dark words and slash; the rest are
-- charcoal with the card's coloured slash.
local function paint(e: Entry, mine: boolean)
	if e.selected == mine then
		return
	end
	e.selected = mine
	local q = K.motion.quick
	UiMotion.tween(e.band, q, { BackgroundColor3 = if mine then MINE else BAND })
	UiMotion.tween(e.slash, q, { BackgroundColor3 = if mine then INK else e.color })
	UiMotion.tween(e.title, q, { TextColor3 = if mine then INK else WHITE })
	UiMotion.tween(e.chance, q, { TextColor3 = if mine then INK else WHITE })
	UiMotion.tween(e.teams, q, { TextColor3 = if mine then MUTED_ON_GOLD else MUTED })
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
	for _, t in e.tiles do
		setCut(t:FindFirstChild("Cut"), size * TILE_CUT_SHARE, size, size)
	end
end

local function addTile(e: Entry, p: Instance, index: number): CanvasGroup
	local t = (child(templates, "Voter") :: CanvasGroup):Clone()
	t.LayoutOrder = index
	local fill = child(t, "Fill") :: Frame
	local team = StateValues.get(p, Teams.ATTRIBUTE)
	fill.BackgroundColor3 = TeamColor.forTeam(if typeof(team) == "number" then team else nil)
	local pop = child(t, "Pop") :: UIScale
	pop.Scale = 0.5
	t.GroupTransparency = 1
	t.Parent = e.votes
	UiMotion.tween(pop, TILE, { Scale = 1 })
	UiMotion.tween(t, TILE, { GroupTransparency = 0 })
	e.tiles[p] = t
	return t
end

local function dropTile(e: Entry, p: Instance)
	local t = e.tiles[p]
	e.tiles[p] = nil
	if not t then
		return
	end
	local pop = t:FindFirstChild("Pop")
	if pop and pop:IsA("UIScale") then
		UiMotion.out(pop, { Scale = 0.5 }, 0.1)
	end
	UiMotion.out(t, { GroupTransparency = 1 }, 0.1)
	task.delay(0.12, t.Destroy, t)
end

-- Tiles, odds and your pick, from player and bot-seat votes.
local function refreshVotes()
	local byOption: { [string]: { Instance } } = {}
	local total = 0
	local function addVote(p: Instance)
		local v = StateValues.get(p, ATTRIBUTE)
		if typeof(v) == "string" and entries[v] then
			byOption[v] = byOption[v] or {}
			table.insert(byOption[v], p)
			total += 1
		end
	end
	for _, p in Players:GetPlayers() do
		addVote(p)
	end
	for _, seat in MatchState.botSeats() do
		addVote(seat)
	end
	local mine = myVote()
	for id, e in entries do
		local list = byOption[id] or {}
		local here: { [Instance]: boolean } = {}
		for i, p in list do
			here[p] = true
			local tile = e.tiles[p] or addTile(e, p, i)
			local face = child(tile, "Face") :: ImageLabel
			local userId = if p:IsA("Player")
				then p.UserId
				else StateValues.get(p, "PortraitUserId")
			PlayerTags.loadHeadshot(face, userId, BOT_HEADSHOT)
		end
		for p in e.tiles do
			if not here[p] then
				dropTile(e, p)
			end
		end
		if e.tileCount ~= #list then
			e.tileCount = #list
			tileLayout(e, #list)
		end
		e.title.Text = e.name
		e.chance.Text = if #list > 0 and total > 0
			then string.format("%d%%", math.floor(#list / total * 100 + 0.5))
			else ""
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
	-- In canvas fractions: the canvas is a fit canvas (Shared/UiLayout).
	cards.Position = UDim2.fromScale(0.5, (TOP + math.max(0, (room - totalH) / 2)) / DESIGN.Y)
end

local function buildCards()
	clearCards()
	local ids = MatchState.getList("VoteOptions")
	if #ids == 0 then
		return
	end
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
			slash = child(band, "Slash") :: Frame,
			title = title,
			teams = child(band, "Teams") :: TextLabel,
			chance = child(band, "Chance") :: TextLabel,
			votes = votes,
			voteGrid = child(votes, "Grid") :: UIGridLayout,
			color = colorFor(id),
			name = displayName(id),
			sizes = sizeText(id),
			tiles = {},
		}
		title.Text = e.name
		e.teams.Text = e.sizes
		e.slash.BackgroundColor3 = e.color
		setCut(card:FindFirstChild("Cut"), CARD_CUT, cell.X, cell.Y)
		UiMotion.button(hit, pop, function()
			if shownChosen == "" then
				UiSound.play("Select")
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
		winner.teams.Text = "RANDOM PICK"
	end
	winner.title.Text = winner.name
	winner.chance.Text = ""
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
		task.spawn(function()
			while token == openToken and shownChosen == "" do
				task.wait(0.25)
				if token == openToken and shownChosen == "" then
					refreshVotes()
				end
			end
		end)
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
	local source = UiRoot.source("Match", "MapVote")
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
	local folder = UiRoot.templates()
	templates = folder:WaitForChild("MapVote")
	backdrop = child(gui, "Backdrop") :: Frame
	canvas = child(gui, "Canvas") :: Frame
	fit = child(canvas, "Fit") :: UIScale
	-- A fit canvas (Shared/UiLayout); this copy is ours, so watch it here.
	UiLayout.watch(gui)
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
		StateValues.changed(p, ATTRIBUTE):Connect(function()
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

	-- Signal after the screen and phase listeners are installed. Retry until
	-- the server acknowledges it in case its startup is still in progress.
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	-- The server answers with this match's id (a pad duel's MatchId, "server" for a whole-server match), so a token
	-- left from an earlier pad duel never counts (Bots/MatchPlan).
	-- The range has no match to start: nothing to signal.
	if PlayZone.get(player) == "Range" then
		return
	end
	local matchId = PlayZone.matchId(player) or "server"
	local ready = Net.event("MatchReady")
	while StateValues.get(player, "MatchVoteReady") ~= matchId do
		local phase = MatchState.phase()
		if phase ~= nil and phase ~= "Waiting" then
			break
		end
		ready:FireServer()
		task.wait(0.5)
	end
	HealthLog.stage("match screens ready", player, matchId)
	-- The loading screens' "match is set up" stage (src/first/LoadingScreen, DuelLoadingController); local only.
	player:SetAttribute("MatchScreensReady", matchId)
end

return MapVoteController
