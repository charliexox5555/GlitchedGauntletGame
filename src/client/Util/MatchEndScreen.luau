--!strict
-- The match end screen (vault/02 Art/UI Match End.md): the result and final
-- score, the round history, the scoreboard, your build and the PLAY AGAIN /
-- REMATCH / LEAVE buttons, plus name plates over the cheering winners. The
-- layout is built in Studio (StarterGui.MatchEndScreen, templates in
-- ReplicatedStorage.UiTemplates.MatchEnd, backup
-- tools/studio/BuildMatchEndScreen.luau); this fills and animates it.
-- MatchEndController owns when it shows and what the buttons do (the server
-- decides everything). Desktop only for now.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScreenPoint = require(ReplicatedStorage.Shared.ScreenPoint)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiWait = require(ReplicatedStorage.Shared.Util.UiWait)
local InputMode = require(ReplicatedStorage.Shared.InputMode)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Mods = require(ReplicatedStorage.Shared.Mods)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiSound = require(script.Parent.UiSound)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module (lobby + match)
local WaitGui = require(script.Parent.WaitGui)

local MatchEndScreen = {}

export type RowData = {
	name: string,
	ally: boolean,
	image: string,
	stats: { number }, -- eliminations, deaths, assists, damage
	mine: boolean,
	mvp: boolean,
}

export type Round = { won: boolean, draw: boolean, tier: string }

export type Data = {
	won: boolean,
	us: number,
	them: number,
	rounds: { Round },
	allies: { RowData },
	enemies: { RowData },
	build: { { id: string, level: string } },
	gift: boolean?, -- a new player's first match: NEXT MATCH / LOBBY, no rematch
}

export type PlateData = { model: Model, name: string, ally: boolean, mvp: boolean }
-- A winner's card (owner 2026-11-20: a card with stats under each winning
-- player, a bigger MVP card): `lead` = the best of the winners (the big card),
-- `mvp` = the match MVP (the badge).
export type CardData = {
	model: Model,
	name: string,
	portrait: string,
	ally: boolean,
	lead: boolean,
	mvp: boolean,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
}

local DESIGN = Vector2.new(1920, 1080)
local NAVY, NAVY_HI = Color3.fromHex("262629"), Color3.fromHex("39393C")
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local ALLY_CELL, ENEMY_CELL = Color3.fromHex("0D5C7A"), Color3.fromHex("8A1C24")
local GOLD, MUTED, WHITE = Color3.fromHex("FFC83D"), Color3.fromHex("97979A"), Color3.new(1, 1, 1)
local KEY_FACE = Color3.fromHex("E9EDF3")
local MINE_H, ROW_H = 58, 46

-- Entrance (2026-11-20, owner): no results UI during the win cutscene; when
-- it lands on its final pose everything comes in together, one beat, Quint
-- Out, no overshoot (Shared/UiMotion). The result grows from ENTER_FROM, the
-- columns rise ENTER_RISE px, the build cards and buttons grow in.
local ENTER = 0.45
local ENTER_FROM = 0.94
local ENTER_RISE = 14

type State = {
	gui: ScreenGui,
	canvas: Frame,
	fit: UIScale,
	result: Frame,
	rounds: Frame,
	board: Frame,
	right: Frame,
	templates: Folder,
	buttons: { [string]: TextButton },
	onChoice: ((name: string) -> ())?,
	plates: { Instance },
	plateConn: RBXScriptConnection?,
	cards: { Instance },
	token: number,
	gift: boolean, -- a new player's first match (Data.gift): NEXT MATCH / LOBBY
	rematchRow: GuiObject?,
}

local state: State? = nil

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return UiWait.child(parent, name) :: T -- a timeout and a clear error, not a hang (code audit 2026-11-27)
end

-- A soft shadow behind a piece, sized from where the piece really is.
local function fitShadow(s: State, shadow: ImageLabel, target: GuiObject, parentOf: GuiObject)
	local scale = s.fit.Scale
	if scale <= 0 then
		return
	end
	local rel = (target.AbsolutePosition - parentOf.AbsolutePosition) / scale
	local size = target.AbsoluteSize / scale
	shadow.AnchorPoint = Vector2.zero
	shadow.Position = UDim2.fromOffset(rel.X - 30, rel.Y - 22)
	shadow.Size = UDim2.fromOffset(size.X + 60, size.Y + 60)
end

local function shadows(s: State)
	local strip = child(s.result, "Strip") :: GuiObject
	fitShadow(s, child(s.result, "Shadow"), strip, s.result)
	fitShadow(s, child(s.canvas, "BoardShadow"), s.board, s.canvas)
	fitShadow(s, child(s.canvas, "RightShadow"), s.right, s.canvas)
end

local function clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Result -------------------------------------------------------------------------
local function fillResult(s: State, d: Data)
	local strip = child(s.result, "Strip") :: CanvasGroup
	local team = child(strip, "Team") :: Frame
	local color = if d.won then ALLY else ENEMY
	team.BackgroundColor3 = color
	local cap = child(strip, "Cap") :: ImageLabel
	cap.ImageColor3 = color
	local word = if d.won then "VICTORY" else "DEFEAT"
	for _, name in { "Label", "SplitA", "SplitB" } do
		local t = child(team, name) :: TextLabel
		t.Text = word
		if name ~= "Label" then
			t.Visible = not d.won -- the glitch split on DEFEAT
		end
	end
	local us = child(strip, "Us") :: TextLabel
	us.Text = tostring(d.us)
	local them = child(strip, "Them") :: TextLabel
	them.Text = tostring(d.them)
end

-- Round history: chips in the winner's colour, grouped by gun tier.
local function fillRounds(s: State, rounds: { Round })
	local strip = child(s.rounds, "Strip") :: CanvasGroup
	clear(strip)
	s.rounds.Visible = #rounds > 0
	local tierT = child(s.templates, "Tier") :: Frame
	local chipT = child(s.templates, "Chip") :: Frame
	local group: Frame? = nil
	local last = ""
	for i, r in rounds do
		if r.tier ~= last or not group then
			last = r.tier
			local g = tierT:Clone()
			g.LayoutOrder = i
			local label = child(g, "Label") :: TextLabel
			label.Text = string.upper(r.tier)
			g.Parent = strip
			group = g
		end
		local chips = child(group :: Frame, "Chips") :: Frame
		local chip = chipT:Clone()
		chip.Name = "R" .. i
		chip.LayoutOrder = i
		chip.BackgroundColor3 = if r.won then ALLY elseif r.draw then MUTED else ENEMY
		local n = child(chip, "N") :: TextLabel
		n.Text = tostring(i)
		chip.Parent = chips
	end
end

-- Scoreboard ----------------------------------------------------------------------
local function header(s: State, order: number, label: string, color: Color3)
	local h = (child(s.templates, "Header") :: Frame):Clone()
	h.LayoutOrder = order
	local team = child(h, "Team") :: Frame
	team.BackgroundColor3 = color
	local text = child(team, "Label") :: TextLabel
	text.Text = label
	local cap = child(h, "Cap") :: ImageLabel
	cap.ImageColor3 = color
	h.Parent = s.board
	return h
end

local function row(s: State, order: number, r: RowData): Frame
	local holder = (child(s.templates, "Row") :: Frame):Clone()
	holder.LayoutOrder = order
	local h = if r.mine then MINE_H else ROW_H
	holder.Size = UDim2.fromOffset(holder.Size.X.Offset, h)
	local body = child(holder, "Body") :: CanvasGroup
	body.BackgroundColor3 = if r.mine then NAVY_HI else NAVY
	local cell = child(body, "Cell") :: Frame
	cell.Size = UDim2.new(0, h, 1, 0)
	cell.BackgroundColor3 = if r.ally then ALLY_CELL else ENEMY_CELL
	local headshot = child(cell, "Headshot") :: ImageLabel
	headshot.Image = r.image
	local line = child(body, "NameLine") :: Frame
	line.Position = UDim2.new(0, h + 14, 0.5, 0)
	local name = child(line, "PlayerName") :: TextLabel
	name.Text = string.upper(r.name)
	name.TextSize = if r.mine then 20 else 16
	name.Size = UDim2.fromOffset(0, name.TextSize + 4)
	name.TextColor3 = if r.ally then ALLY else ENEMY
	local shard = child(line, "Shard") :: ImageLabel
	shard.Visible = r.mvp
	local mvp = child(line, "Mvp") :: TextLabel
	mvp.Visible = r.mvp
	for i, v in r.stats do
		local stat = body:FindFirstChild("Stat" .. i)
		if stat and stat:IsA("TextLabel") then
			stat.Text = tostring(math.floor(v + 0.5))
			stat.TextSize = if r.mine then 22 else 17
		end
	end
	holder.Parent = s.board
	return holder
end

local function fillBoard(s: State, d: Data): { Frame }
	clear(s.board)
	local rows: { Frame } = {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	table.insert(rows, header(s, nextOrder(), "YOUR TEAM", ALLY))
	for _, r in d.allies do
		table.insert(rows, row(s, nextOrder(), r))
	end
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.LayoutOrder = nextOrder()
	spacer.Size = UDim2.fromOffset(10, 14)
	spacer.BackgroundTransparency = 1
	spacer.Parent = s.board
	table.insert(rows, header(s, nextOrder(), "ENEMY", ENEMY))
	for _, r in d.enemies do
		table.insert(rows, row(s, nextOrder(), r))
	end
	return rows
end

-- Your build: the Mods you drafted, with their path and level.
local function fillBuild(s: State, build: { { id: string, level: string } })
	local holder = child(s.right, "Build") :: Frame
	local head = child(s.right, "BuildHeader") :: Frame
	holder.Visible = #build > 0
	head.Visible = #build > 0
	for i = 1, 3 do
		local slot = child(holder, "Mod" .. i) :: Frame
		local b = build[i]
		local def = if b then Mods.def(b.id) else nil
		slot.Visible = def ~= nil
		if b and def then
			local card = child(slot, "Card") :: CanvasGroup
			local art = child(card, "Art") :: ImageLabel
			art.Image = Theme.CARD_ART[b.id] or def.icon
			local band = child(card, "Band") :: Frame
			band.BackgroundColor3 = Theme.ROLE[def.role] or ALLY
			local letter = string.sub(b.level, 1, 1)
			local pathName = if letter ~= "L" then (def.paths :: any)[letter] else nil
			local path = child(card, "Path") :: TextLabel
			path.Text = string.upper(pathName or def.name)
			local level = child(card, "Level") :: TextLabel
			level.Text = "LV " .. (tonumber(string.sub(b.level, 2, 2)) or 1)
		end
	end
end

-- Entrance --------------------------------------------------------------------------
local function animateIn(s: State, rows: { Frame })
	s.token += 1
	local token = s.token
	-- the result: grows a touch and fades in
	local pop = child(s.result, "Pop") :: UIScale
	local strip = child(s.result, "Strip") :: CanvasGroup
	pop.Scale = ENTER_FROM
	strip.GroupTransparency = 1
	tween(pop, ENTER, { Scale = 1 })
	tween(strip, ENTER, { GroupTransparency = 0 })
	-- the round history drops the same beat
	local rStrip = child(s.rounds, "Strip") :: CanvasGroup
	rStrip.GroupTransparency = 1
	rStrip.Position = UDim2.new(0.5, 0, 0, -ENTER_RISE)
	tween(rStrip, ENTER, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0) })
	-- the scoreboard rows rise together (headers with them)
	for _, holder in rows do
		local body = holder:FindFirstChild("Body")
		if body and body:IsA("CanvasGroup") then
			body.GroupTransparency = 1
			body.Position = UDim2.fromOffset(0, ENTER_RISE)
			tween(body, ENTER, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
		else
			holder.Visible = true
		end
	end
	-- the right column: build cards and buttons grow in
	local build = child(s.right, "Build") :: Frame
	for i = 1, 3 do
		local card = child(child(build, "Mod" .. i) :: Frame, "Card") :: CanvasGroup
		local cardPop = child(card, "Pop") :: UIScale
		card.GroupTransparency = 1
		cardPop.Scale = ENTER_FROM
		tween(card, ENTER, { GroupTransparency = 0 })
		tween(cardPop, ENTER, { Scale = 1 })
	end
	for _, b in s.buttons do
		local bPop = child(b, "Pop") :: UIScale
		bPop.Scale = 0
		tween(bPop, ENTER, { Scale = 1 })
	end
	-- shadows: measured once everything is at full size
	local shadowList = {
		child(s.result, "Shadow") :: ImageLabel,
		child(s.canvas, "BoardShadow") :: ImageLabel,
		child(s.canvas, "RightShadow") :: ImageLabel,
	}
	for _, sh in shadowList do
		sh.ImageTransparency = 1
	end
	task.delay(ENTER, function()
		if token ~= s.token then
			return
		end
		shadows(s)
		for _, sh in shadowList do
			tween(sh, 0.3, { ImageTransparency = 0.45 })
		end
	end)
end

-- Buttons: hover lift, press pop, then the controller decides.
local function hookButton(s: State, name: string, b: TextButton)
	s.buttons[name] = b
	local pop = child(b, "Pop") :: UIScale
	b.MouseEnter:Connect(function()
		if b.Active then
			UiSound.play("Hover")
			tween(pop, 0.12, { Scale = 1.03 })
		end
	end)
	b.MouseLeave:Connect(function()
		tween(pop, 0.15, { Scale = 1 })
	end)
	b.Activated:Connect(function()
		MatchEndScreen.press(name)
	end)
end

local function bind(gui: ScreenGui)
	local canvas = child(gui, "Canvas") :: Frame
	local fit = child(canvas, "Fit") :: UIScale
	local right = child(canvas, "Right") :: Frame
	local s: State = {
		gui = gui,
		canvas = canvas,
		fit = fit,
		result = child(canvas, "Result"),
		rounds = child(canvas, "Rounds"),
		board = child(canvas, "Board"),
		right = right,
		templates = UiWait.child(UiRoot.templates(), "MatchEnd") :: Folder,
		buttons = {},
		onChoice = nil,
		plates = {},
		plateConn = nil,
		cards = {},
		token = 0,
		gift = false,
		rematchRow = nil,
	}
	-- A fit canvas: Shared/UiLayout sizes it per device; the shadows follow.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(shadows, s)
	end)
	hookButton(s, "PlayAgain", child(child(right, "PlayAgain"), "Button"))
	local choices = child(right, "Choices") :: Frame
	local rematchRow = child(choices, "Rematch") :: Instance
	s.rematchRow = if rematchRow:IsA("GuiObject") then rematchRow else nil
	hookButton(s, "Rematch", child(rematchRow, "Button"))
	hookButton(s, "Leave", child(child(choices, "Leave"), "Button"))
	gui.Enabled = false
	state = s
end

-- API -------------------------------------------------------------------------------

function MatchEndScreen.start(_isCompact: boolean?)
	task.spawn(function()
		local gui = WaitGui("MatchEndScreen")
		if gui and gui:IsA("ScreenGui") then
			bind(gui)
		end
	end)
end

function MatchEndScreen.active(): boolean
	return state ~= nil
end

function MatchEndScreen.show(d: Data, onChoice: (name: string) -> ())
	local s = state
	if not s then
		return
	end
	s.onChoice = onChoice
	-- A new player's first match (vault/01 Design/First Ten Minutes.md): no dead REMATCH; the gold button is
	-- NEXT MATCH (queues match 2 from the lobby) and the other LOBBY (owner 2026-11-26: no auto-start). No free
	-- case any more (owner 2026-11-27).
	s.gift = d.gift == true
	if s.rematchRow then
		s.rematchRow.Visible = not s.gift
	end
	local leave = s.buttons.Leave
	if leave then
		(child(leave, "Label") :: TextLabel).Text = if s.gift then "LOBBY" else "LEAVE"
	end
	fillResult(s, d)
	fillRounds(s, d.rounds)
	local rows = fillBoard(s, d)
	fillBuild(s, d.build)
	s.gui.Enabled = true
	animateIn(s, rows)
	-- A controller starts on PLAY AGAIN (the D-pad reaches REMATCH and LEAVE;
	-- X and Y are shortcuts), and the selection stays on this screen.
	s.gui.SelectionGroup = true
	if InputMode.gamepad() then
		local first = s.buttons.PlayAgain
		if first then
			GuiService.SelectedObject = first
		end
	end
end

-- A button or its key: a press pop, then the controller's choice.
function MatchEndScreen.press(name: string)
	local s = state
	if not s or not s.gui.Enabled then
		return
	end
	local b = s.buttons[name]
	if not b or not b.Active then
		UiSound.play("Denied")
		return
	end
	local pop = child(b, "Pop") :: UIScale
	pop.Scale = 0.94
	tween(pop, 0.25, { Scale = 1 })
	local fn = s.onChoice
	if fn then
		fn(name)
	end
end

-- Votes, the lobby countdown and the picked button (called a few times a second).
function MatchEndScreen.refresh(
	rematchOpen: boolean,
	votes: number,
	needed: number,
	secondsLeft: number,
	picked: string?
)
	local s = state
	if not s then
		return
	end
	local rematch = s.buttons.Rematch
	if rematch then
		rematch.Active = rematchOpen
		rematch.BackgroundTransparency = if rematchOpen then 0 else 0.45
		local sub = child(rematch, "Sub") :: TextLabel
		sub.Text = if rematchOpen
			then string.format(
				"%s%d / %d VOTES",
				if picked == "Rematch" then "VOTED  ·  " else "",
				votes,
				needed
			)
			else "UNAVAILABLE"
		sub.TextColor3 = if rematchOpen then ALLY else MUTED
	end
	local leave = s.buttons.Leave
	if leave then
		local sub = child(leave, "Sub") :: TextLabel
		sub.Text = string.format("LOBBY IN %d", math.max(0, math.ceil(secondsLeft)))
	end
	for name, b in s.buttons do
		local on = name == picked
		local label = child(b, "Label") :: TextLabel
		if name == "PlayAgain" then
			label.Text = if on then "JOINING…" elseif s.gift then "NEXT MATCH" else "PLAY AGAIN"
		else
			b.BackgroundColor3 = if on then NAVY_HI else NAVY
			label.TextColor3 = if on then GOLD else WHITE
		end
		local key = b:FindFirstChild("Key")
		local face = key and key:FindFirstChild("Face")
		if face and face:IsA("Frame") then
			face.BackgroundColor3 = if on then GOLD else KEY_FACE
		end
	end
end

-- Name plates over the cheering winners (client-only copies in the scene),
-- drawn in this ScreenGui and placed over each head every frame (the
-- template's Strip; same look as the rest of the screen).
local PLATE_LIFT = 2.4 -- studs above the head

function MatchEndScreen.plates(list: { PlateData })
	local s = state
	if not s then
		return
	end
	local template = child(child(s.templates, "Plate"), "Strip") :: GuiObject
	local layer = s.gui:FindFirstChild("Plates") :: Frame?
	if not layer then
		local f = Instance.new("Frame")
		f.Name = "Plates"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		f.ZIndex = 0
		f.Parent = s.gui
		layer = f
	end
	local placed: { { strip: GuiObject, head: BasePart } } = {}
	for _, p in list do
		local head = p.model:FindFirstChild("Head") or p.model:FindFirstChild("HumanoidRootPart")
		if head and head:IsA("BasePart") then
			local strip = template:Clone()
			strip.AnchorPoint = Vector2.new(0.5, 1)
			strip.Visible = false
			local scale = Instance.new("UIScale")
			scale.Scale = s.fit.Scale
			scale.Parent = strip
			local team = child(strip, "Team") :: Frame
			local color = if p.ally then ALLY else ENEMY
			team.BackgroundColor3 = color
			local cap = child(strip, "Cap") :: ImageLabel
			cap.ImageColor3 = color
			local label = child(team, "Label") :: TextLabel
			label.Text = string.upper(p.name)
			for _, n in { "Shard", "Mvp" } do
				local part = strip:FindFirstChild(n)
				if part and part:IsA("GuiObject") then
					part.Visible = p.mvp
				end
			end
			strip.Parent = layer
			table.insert(s.plates, strip)
			table.insert(placed, { strip = strip, head = head })
		end
	end
	if s.plateConn then
		s.plateConn:Disconnect()
	end
	s.plateConn = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		for _, item in placed do
			local point, onScreen =
				cam:WorldToViewportPoint(item.head.Position + Vector3.new(0, PLATE_LIFT, 0))
			item.strip.Visible = onScreen and item.head.Parent ~= nil
			local space = item.strip.Parent
			if onScreen and space and space:IsA("GuiBase2d") then
				local at = ScreenPoint.toLocal(space, Vector2.new(point.X, point.Y))
				item.strip.Position = UDim2.fromOffset(at.X, at.Y)
			end
		end
	end)
end

function MatchEndScreen.hide()
	local s = state
	if not s then
		return
	end
	s.token += 1
	s.gui.Enabled = false
	local sel = GuiService.SelectedObject
	if sel and sel:IsDescendantOf(s.gui) then
		GuiService.SelectedObject = nil
	end
	if s.plateConn then
		s.plateConn:Disconnect()
		s.plateConn = nil
	end
	for _, p in s.plates do
		p:Destroy()
	end
	table.clear(s.plates)
	for _, c in s.cards do
		c:Destroy()
	end
	table.clear(s.cards)
	s.board.Visible = true
	local boardShadow = s.canvas:FindFirstChild("BoardShadow")
	if boardShadow and boardShadow:IsA("GuiObject") then
		boardShadow.Visible = true
	end
end

-- The winners' cards, in a row along the bottom, each under its winner (the
-- copies in the win cutscene's final shot), the best one's bigger with the
-- MVP badge when they are the match MVP; pushed apart so none overlap and
-- kept left of the right column. The scoreboard makes room (CARDS_KEEP_BOARD).
-- They come in with the rest of the screen: one beat, Quint, no overshoot.
local CARD_W, CARD_GAP, LEAD_SCALE = 260, 18, 1.14
local CARD_LIFT = 44 -- design px from the canvas bottom to the cards' bottom
local CARD_LEFT = 40 -- design px; the zone ends CARD_CLEAR left of the right column
local CARD_CLEAR = 24
local CARDS_KEEP_BOARD = false

local function number(n: number): string
	local str = tostring(math.floor(n + 0.5))
	local out = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function MatchEndScreen.cards(list: { CardData })
	local s = state
	if not s then
		return
	end
	local template = s.templates:FindFirstChild("Card")
	local cam = Workspace.CurrentCamera
	if not template or not template:IsA("GuiObject") or not cam or #list == 0 then
		return
	end
	for _, c in s.cards do
		c:Destroy()
	end
	table.clear(s.cards)
	-- where each winner is on the screen, in the canvas's design pixels
	-- The canvas is a fit canvas (Shared/UiLayout): it spans the screen, so its
	-- design width is the screen width / fit, and the zone stretches with it.
	local fit = s.fit.Scale
	local stretch = (s.canvas.AbsoluteSize.X / math.max(fit, 1e-3)) / DESIGN.X
	-- A boosted canvas (phones, Shared/UiLayout <Family>Boost) is shorter and
	-- narrower in design px than 1920 x 1080: the row keeps to its bottom and
	-- stops at the right column wherever that sits.
	local cardBottom = s.canvas.AbsoluteSize.Y / math.max(fit, 1e-3) - CARD_LIFT
	local column = s.canvas:FindFirstChild("Right")
	local zoneRight = if column and column:IsA("GuiObject")
		then (column.AbsolutePosition.X - s.canvas.AbsolutePosition.X) / math.max(fit, 1e-3) - CARD_CLEAR
		else (DESIGN.X - 484) * stretch
	local zoneLeft = CARD_LEFT * stretch
	type Slot = { data: CardData, x: number, w: number, scale: number }
	local slots: { Slot } = {}
	for _, d in list do
		local root = d.model:FindFirstChild("HumanoidRootPart")
		local x = DESIGN.X * stretch / 2
		if root and root:IsA("BasePart") then
			local p = cam:WorldToViewportPoint(root.Position)
			x = ScreenPoint.toLocal(s.canvas, Vector2.new(p.X, p.Y)).X / fit
		end
		local baseScale = if d.lead then LEAD_SCALE else 1
		table.insert(slots, { data = d, x = x, w = CARD_W * baseScale, scale = baseScale })
	end
	table.sort(slots, function(a, b)
		return a.x < b.x
	end)
	-- Fit within [zoneLeft, zoneRight]: shrink the whole row uniformly if needed,
	-- then pack forward and backward so no card overlaps another or enters the Right column.
	local zoneWidth = math.max(zoneRight - zoneLeft, 240)
	local baseTotal = CARD_GAP * math.max(#slots - 1, 0)
	for _, slot in slots do
		baseTotal += slot.w
	end
	local rowScale = if baseTotal > zoneWidth then math.clamp(zoneWidth / baseTotal, 0.5, 1) else 1
	local gap = CARD_GAP * rowScale
	for _, slot in slots do
		slot.w *= rowScale
		slot.scale *= rowScale
		slot.x = math.clamp(slot.x, zoneLeft + slot.w / 2, zoneRight - slot.w / 2)
	end
	for i = 2, #slots do
		local a, b = slots[i - 1], slots[i]
		b.x = math.max(b.x, a.x + (a.w + b.w) / 2 + gap)
	end
	slots[#slots].x = math.min(slots[#slots].x, zoneRight - slots[#slots].w / 2)
	for i = #slots - 1, 1, -1 do
		local a, b = slots[i], slots[i + 1]
		a.x = math.min(a.x, b.x - (a.w + b.w) / 2 - gap)
	end
	slots[1].x = math.max(slots[1].x, zoneLeft + slots[1].w / 2)
	local layer = s.canvas:FindFirstChild("Cards")
	if not layer then
		local f = Instance.new("Frame")
		f.Name = "Cards"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		f.ZIndex = 2
		f.Parent = s.canvas
		layer = f
	end
	for _, slot in slots do
		local d = slot.data
		local card = template:Clone() :: Frame
		local body = child(card, "Body") :: CanvasGroup
		local top = child(body, "Top") :: Frame
		local team = child(top, "Team") :: Frame
		local cap = child(top, "Cap") :: ImageLabel
		local color = if d.lead and d.mvp then GOLD elseif d.ally then ALLY else ENEMY
		team.BackgroundColor3 = color
		cap.ImageColor3 = color
		local nameLabel = child(team, "Name") :: TextLabel
		nameLabel.Text = string.upper(d.name)
		local portrait = child(team, "Portrait") :: ImageLabel
		portrait.Image = d.portrait
		local stats = child(body, "Stats") :: Frame
		for i, v in { d.eliminations, d.deaths, d.assists } do
			local value = child(child(stats, "Cell" .. i) :: Frame, "Value") :: TextLabel
			value.Text = number(v)
		end
		local dmg = child(body, "Damage") :: Frame
		local dealt = child(child(dmg, "Dealt") :: Frame, "Value") :: TextLabel
		dealt.Text = number(d.dealt)
		local taken = child(child(dmg, "Taken") :: Frame, "Value") :: TextLabel
		taken.Text = number(d.taken)
		local badge = child(card, "Badge") :: CanvasGroup
		badge.Visible = d.mvp
		local home = UDim2.fromOffset(slot.x, cardBottom)
		card.Position = home + UDim2.fromOffset(0, ENTER_RISE)
		local pop = child(card, "Pop") :: UIScale
		pop.Scale = slot.scale * ENTER_FROM
		body.GroupTransparency = 1
		badge.GroupTransparency = 1
		card.Parent = layer
		table.insert(s.cards, card)
		tween(card, ENTER, { Position = home })
		tween(pop, ENTER, { Scale = slot.scale })
		tween(body, ENTER, { GroupTransparency = 0 })
		tween(badge, ENTER, { GroupTransparency = 0 })
	end
	s.board.Visible = CARDS_KEEP_BOARD
	local boardShadow = s.canvas:FindFirstChild("BoardShadow")
	if boardShadow and boardShadow:IsA("GuiObject") then
		boardShadow.Visible = CARDS_KEEP_BOARD
	end
end

return MatchEndScreen
