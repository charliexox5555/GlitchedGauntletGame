--!strict
-- The match end screen (vault/02 Art/UI Match End.md): the result and final
-- score, the round history, the scoreboard, your build and the PLAY AGAIN /
-- REMATCH / LEAVE buttons, plus name plates over the cheering winners. The
-- layout is built in Studio (StarterGui.MatchEndScreen, templates in
-- ReplicatedStorage.UiTemplates.MatchEnd, backup
-- tools/studio/BuildMatchEndScreen.luau); this fills and animates it.
-- MatchEndController owns when it shows and what the buttons do (the server
-- decides everything). Desktop only for now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Mods = require(ReplicatedStorage.Shared.Mods)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiSound = require(script.Parent.UiSound)

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
}

export type PlateData = { model: Model, name: string, ally: boolean, mvp: boolean }

local player = Players.LocalPlayer

local DESIGN = Vector2.new(1920, 1080)
local NAVY, NAVY_HI = Color3.fromHex("1C2740"), Color3.fromHex("2B3A5A")
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local ALLY_CELL, ENEMY_CELL = Color3.fromHex("0D5C7A"), Color3.fromHex("8A1C24")
local GOLD, MUTED, WHITE = Color3.fromHex("FFC83D"), Color3.fromHex("8E98A8"), Color3.new(1, 1, 1)
local KEY_FACE = Color3.fromHex("E9EDF3")
local MINE_H, ROW_H = 58, 46

-- Entrance beats (seconds): the result slams in, then the history, the
-- scoreboard rows one by one, then the right column.
local SLAM, SLAM_FROM, SLAM_UNDER = 0.08, 1.6, 0.88
local REBOUND, REBOUND_TO, SETTLE = 0.1, 1.05, 0.18
local HISTORY_AT = 0.35
local ROWS_AT, ROW_STEP = 0.5, 0.05
local RIGHT_AT, CARD_STEP = 0.7, 0.06

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
	token: number,
}

local state: State? = nil

local function tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
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
	local function at(t: number, fn: () -> ())
		task.delay(t, function()
			if token == s.token then
				fn()
			end
		end)
	end
	-- The result slams in: big, under, rebound, settle.
	local pop = child(s.result, "Pop") :: UIScale
	local strip = child(s.result, "Strip") :: CanvasGroup
	pop.Scale = SLAM_FROM
	strip.GroupTransparency = 0.6
	tween(strip, SLAM, { GroupTransparency = 0 }, Enum.EasingStyle.Linear)
	tween(pop, SLAM, { Scale = SLAM_UNDER }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	at(SLAM, function()
		tween(pop, REBOUND, { Scale = REBOUND_TO }, Enum.EasingStyle.Quad).Completed:Once(function()
			if token == s.token then
				tween(pop, SETTLE, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			end
		end)
	end)
	-- The round history drops in.
	local rStrip = child(s.rounds, "Strip") :: CanvasGroup
	rStrip.GroupTransparency = 1
	rStrip.Position = UDim2.new(0.5, 0, 0, -10)
	at(HISTORY_AT, function()
		tween(rStrip, 0.3, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0) })
	end)
	-- Scoreboard rows slide in from the left, one after another.
	for i, holder in rows do
		local body = holder:FindFirstChild("Body")
		if body and body:IsA("CanvasGroup") then
			body.GroupTransparency = 1
			body.Position = UDim2.fromOffset(-40, 0)
			at(ROWS_AT + (i - 1) * ROW_STEP, function()
				tween(body, 0.3, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
			end)
		else
			holder.Visible = false -- a header: it appears with its rows
			at(ROWS_AT + (i - 1) * ROW_STEP, function()
				holder.Visible = true
			end)
		end
	end
	-- The right column: build cards pop, then the buttons.
	local build = child(s.right, "Build") :: Frame
	for i = 1, 3 do
		local card = child(child(build, "Mod" .. i) :: Frame, "Card") :: CanvasGroup
		local cardPop = child(card, "Pop") :: UIScale
		card.GroupTransparency = 1
		cardPop.Scale = 0.7
		at(RIGHT_AT + (i - 1) * CARD_STEP, function()
			tween(card, 0.2, { GroupTransparency = 0 })
			tween(cardPop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	local n = 0
	for _, b in s.buttons do
		n += 1
		local bPop = child(b, "Pop") :: UIScale
		bPop.Scale = 0
		at(RIGHT_AT + 0.15 + n * CARD_STEP, function()
			tween(bPop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	-- Shadows: measured once the result has settled (it's scaled mid-slam).
	local shadowList = {
		child(s.result, "Shadow") :: ImageLabel,
		child(s.canvas, "BoardShadow") :: ImageLabel,
		child(s.canvas, "RightShadow") :: ImageLabel,
	}
	for _, sh in shadowList do
		sh.ImageTransparency = 1
	end
	at(SLAM + REBOUND + SETTLE + 0.05, function()
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
		templates = ReplicatedStorage:WaitForChild("UiTemplates"):WaitForChild("MatchEnd") :: Folder,
		buttons = {},
		onChoice = nil,
		plates = {},
		plateConn = nil,
		token = 0,
	}
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.5, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refit()
		task.defer(shadows, s)
	end)
	hookButton(s, "PlayAgain", child(child(right, "PlayAgain"), "Button"))
	local choices = child(right, "Choices") :: Frame
	hookButton(s, "Rematch", child(child(choices, "Rematch"), "Button"))
	hookButton(s, "Leave", child(child(choices, "Leave"), "Button"))
	gui.Enabled = false
	state = s
end

-- API -------------------------------------------------------------------------------

function MatchEndScreen.start(isCompact: boolean)
	if isCompact then
		return -- phones keep the old screen for now
	end
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchEndScreen", 30)
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
	fillResult(s, d)
	fillRounds(s, d.rounds)
	local rows = fillBoard(s, d)
	fillBuild(s, d.build)
	s.gui.Enabled = true
	animateIn(s, rows)
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
	tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
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
			label.Text = if on then "JOINING…" else "PLAY AGAIN"
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
			if onScreen then
				item.strip.Position = UDim2.fromOffset(point.X, point.Y)
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
	if s.plateConn then
		s.plateConn:Disconnect()
		s.plateConn = nil
	end
	for _, p in s.plates do
		p:Destroy()
	end
	table.clear(s.plates)
end

return MatchEndScreen
