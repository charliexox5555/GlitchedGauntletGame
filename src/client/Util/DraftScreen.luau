--!strict
-- The draft screen (vault/02 Art/UI Draft Screen.md, v4): three guns on top,
-- three ability columns (a new card, 2-3 upgrade half-cards, or MAXED) under
-- their Q / E / T tabs (an empty column's tab names the first empty slot: new powers
-- fill slots in draft order, vault/01 Design/Loadout and Power Deck.md), and a gold LOCK IN that names your picks. The layout
-- is built in Studio (StarterGui.DraftScreen, backup
-- tools/studio/BuildDraftScreen.luau); this module only fills and animates it.
-- DraftController owns the logic (offer, keys, remote calls, the hint text,
-- timeout rules) and feeds it through `show` and `refresh`.
-- Shared desktop, touch and controller layout.

local TweenService = game:GetService("TweenService")

local UiSound = require(script.Parent.UiSound)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module (lobby + match)
local WaitGui = require(script.Parent.WaitGui)
local InputGlyphs = require(game:GetService("ReplicatedStorage").Shared.InputGlyphs) -- key chips follow the input
local UiLayout = require(game:GetService("ReplicatedStorage").Shared.UiLayout)
local InputMode = require(game:GetService("ReplicatedStorage").Shared.InputMode)
local GuiService = game:GetService("GuiService")

local DraftScreen = {}

export type GunView = {
	id: string,
	name: string,
	image: string,
	shield: number, -- 0 hides the shield line
}

export type NewView = {
	key: string, -- the id sent to the server
	name: string,
	role: string,
	color: Color3,
	art: string,
	note: string,
	charges: string,
}

export type PathView = {
	key: string, -- "id:level", sent to the server
	name: string,
	tag: string,
	stat: string,
	color: Color3,
	art: string,
	glitch: boolean,
}

export type ColumnView = {
	new: NewView?,
	keySlot: number?, -- a new card: the slot it lands on (its tab shows that key); nil: the column's own
	paths: { PathView }?,
	maxed: { icon: string, sub: string }?,
}

export type EnemyView = { icon: string, color: Color3, level: number }

export type View = {
	guns: { GunView },
	columns: { ColumnView },
	enemy: { EnemyView },
	-- Onboarding (Config/Onboarding SCRIPT): only the columns with cards, centred, and moved up into the gun
	-- row's space (vault/01 Design/First Ten Minutes.md).
	focus: boolean?,
}

export type Handlers = {
	gun: (index: number) -> (),
	card: (key: string) -> (),
	lock: () -> (),
	canHover: () -> boolean,
}

local COL_W, CARD_H = 400, 500
local PATH_GAP = 26
local LIFT = 10 -- the picked card stays this far up
local FOCUS_LIFT = 82 -- focus mode: cards move up half the gun row's space (BuildDraftScreen CARD_Y - GUN_Y)
local HOVER_LIFT = 4
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(150, 155, 166) -- unpicked: a little darker, never muddy
local HOVER = Color3.fromRGB(205, 209, 217)
local NAVY, NAVY_HI = Color3.fromHex("262629"), Color3.fromHex("39393C")
local KEY_FACE, GOLD = Color3.fromHex("E9EDF3"), Color3.fromHex("FFC83D")
local MAGENTA, PINK = Color3.fromHex("E0249F"), Color3.fromHex("FF8BE0")
local WAIT_FILL = Color3.fromHex("616164") -- LOCK IN with nothing picked yet
local READY_FILL = Color3.fromHex("3FD68A") -- locked in
local INK = Color3.fromHex("1A1A1D")
local OPEN_TIME = 0.32
local CLOSE_TIME = 0.22
local STAGGER = 0.04

-- One pickable thing on screen: its hit area, the centred card and its state.
type Pickable = {
	button: TextButton,
	card: CanvasGroup,
	pop: UIScale,
	key: Frame?, -- its keycap (guns), turned gold when picked
	id: string,
	picked: boolean,
	hover: boolean,
	compact: boolean?,
	baseFill: Color3?, -- guns: the face colour (NAVY / NAVY_HI when picked)
}

type Column = {
	frame: Frame,
	home: UDim2, -- the Studio position (focus mode moves the column)
	tab: Frame,
	index: number, -- its own slot
	tabText: unknown, -- the tab's Studio KeyText (Q / E / T), used when a slot has no key bound
	new: Pickable,
	newCard: CanvasGroup,
	paths: { Pickable },
	ors: { TextLabel },
	maxed: Frame,
	shown: { Pickable }, -- the ones in use this draft
}

type State = {
	gui: ScreenGui,
	backdrop: TextButton,
	canvas: Frame,
	fit: UIScale,
	guns: { Pickable },
	gunShown: number,
	columns: { Column },
	lockButton: TextButton,
	lockHome: UDim2,
	lockFace: Frame,
	lockPop: UIScale,
	lockFill: { GuiObject },
	lockTitle: TextLabel,
	lockPicks: TextLabel,
	lockKey: Frame,
	hint: TextLabel,
	enemyLabel: TextLabel,
	enemy: { Frame },
	handlers: Handlers?,
	open: boolean,
	token: number,
	pulse: Tween?,
}

local state: State? = nil

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function setKey(key: Frame?, gold: boolean)
	if not key then
		return
	end
	local face = key:FindFirstChild("Face")
	if face and face:IsA("Frame") then
		face.BackgroundColor3 = if gold then GOLD else KEY_FACE
	end
end

-- Where a card sits: up by LIFT when picked, a little on hover.
local function place(p: Pickable, time: number)
	local liftMax = if p.compact then 5 else LIFT
	local hoverMax = if p.compact then 2 else HOVER_LIFT
	local lift = if p.picked then liftMax elseif p.hover then hoverMax else 0
	tween(p.card, time, {
		Position = UDim2.new(0.5, 0, 0.5, -lift),
		GroupColor3 = if p.picked then WHITE elseif p.hover then HOVER else DIM,
	})
	if p.baseFill then
		p.card.BackgroundColor3 = if p.picked then NAVY_HI else p.baseFill
	end
	setKey(p.key, p.picked)
end

local function popScale(scale: UIScale, peak: number)
	scale.Scale = 1
	tween(scale, 0.07, { Scale = peak }).Completed:Once(function(s)
		if s == Enum.PlaybackState.Completed then
			tween(scale, 0.25, { Scale = 1 })
		end
	end)
end

local function pickable(button: TextButton, key: Frame?): Pickable
	local card = child(button, "Card") :: CanvasGroup
	local p: Pickable = {
		button = button,
		card = card,
		pop = child(card, "Pop") :: UIScale,
		key = key,
		id = "",
		picked = false,
		hover = false,
	}
	return p
end

-- Hover lifts the card a little with a soft tick; a click picks it.
local function hook(p: Pickable, onPick: () -> ())
	p.button.MouseEnter:Connect(function()
		local s = state
		local h = s and s.handlers
		if not (s and s.open and h and h.canHover()) then
			return
		end
		p.hover = true
		if not p.picked then
			UiSound.play("Hover")
		end
		place(p, 0.12)
	end)
	p.button.MouseLeave:Connect(function()
		p.hover = false
		place(p, 0.15)
	end)
	p.button.Activated:Connect(function()
		local s = state
		if s and s.open then
			onPick()
		end
	end)
end

local function fitCanvas(s: State)
	if UiLayout.family() ~= "Phone" then
		if s.fit:GetAttribute("CustomFit") then
			s.fit:SetAttribute("CustomFit", nil)
			s.canvas.AnchorPoint = Vector2.new(0.5, 0.5)
			s.canvas.Size = UDim2.fromScale(1, 1)
			s.canvas.Position = UDim2.fromScale(0.5, 0.5)
			UiLayout.apply(s.gui)
		end
		return
	end
	local full = GuiService:GetInsetArea(Enum.ScreenInsets.None)
	local safe = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
	local left = math.max(0, safe.Min.X - full.Min.X) + 8
	local right = s.gui.AbsoluteSize.X - math.max(0, full.Max.X - safe.Max.X) - 8
	local topbar = GuiService.TopbarInset
	local top = math.max(safe.Min.Y - full.Min.Y, if topbar.Height > 0 then topbar.Max.Y else 0) + 6
	local bottom = s.gui.AbsoluteSize.Y - math.max(0, full.Max.Y - safe.Max.Y) - 8
	if right <= left or bottom <= top then
		return
	end
	s.fit:SetAttribute("CustomFit", true)
	-- Bounds of the visible cards, lock control and hint on the authored 1920×1080 canvas.
	s.fit.Scale = math.min((right - left) / 1300, (bottom - top) / 860)
	s.canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	s.canvas.Size = UDim2.fromScale(1, 1)
	s.canvas.Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2 - 16 * s.fit.Scale)
end

local function fitLabel(
	label: TextLabel,
	x: number,
	y: number,
	w: number,
	h: number,
	cap: number,
	wrap: boolean
)
	label.AnchorPoint = Vector2.zero
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextTruncate = Enum.TextTruncate.None
	label.TextWrapped = wrap
	label.TextScaled = true
	local bounds = label:FindFirstChildOfClass("UITextSizeConstraint")
		or Instance.new("UITextSizeConstraint")
	bounds.MinTextSize = 1
	bounds.MaxTextSize = cap
	bounds.Parent = label
end

local function bind(gui: ScreenGui)
	local canvas = child(gui, "Canvas") :: Frame
	local guns: { Pickable } = {}
	for i = 1, 3 do
		local button = child(canvas, "Gun" .. i) :: TextButton
		local p = pickable(button, nil)
		p.key = child(p.card, "Key") :: Frame
		p.baseFill = NAVY
		guns[i] = p
		hook(p, function()
			local s = state
			if s and s.handlers then
				s.handlers.gun(i)
			end
		end)
	end
	local columns: { Column } = {}
	for i = 1, 3 do
		local frame = child(canvas, "Col" .. i) :: Frame
		local newButton = child(frame, "New") :: TextButton
		local new = pickable(newButton, nil)
		local paths: { Pickable } = {}
		for p = 1, 3 do
			paths[p] = pickable(child(frame, "Path" .. p) :: TextButton, nil)
		end
		local col: Column = {
			frame = frame,
			home = frame.Position,
			tab = child(frame, "Key") :: Frame,
			index = i,
			tabText = (child(frame, "Key") :: Frame):GetAttribute("KeyText"),
			new = new,
			newCard = new.card,
			paths = paths,
			ors = { child(frame, "Or1") :: TextLabel, child(frame, "Or2") :: TextLabel },
			maxed = child(frame, "Maxed") :: Frame,
			shown = {},
		}
		columns[i] = col
		for _, p in { new, table.unpack(paths) } do
			hook(p, function()
				local s = state
				if s and s.handlers and p.id ~= "" then
					s.handlers.card(p.id)
				end
			end)
		end
	end
	local lockButton = child(canvas, "LockIn") :: TextButton
	local lockFace = child(lockButton, "Face") :: Frame
	local enemyRow = child(canvas, "Enemy") :: Frame
	local s: State = {
		gui = gui,
		backdrop = child(gui, "Backdrop") :: TextButton,
		canvas = canvas,
		fit = child(canvas, "Fit") :: UIScale,
		guns = guns,
		gunShown = 0,
		columns = columns,
		lockButton = lockButton,
		lockHome = lockButton.Position,
		lockFace = lockFace,
		lockPop = child(lockFace, "Pop") :: UIScale,
		lockFill = { child(lockFace, "Body"), child(lockFace, "CapL"), child(lockFace, "CapR") },
		lockTitle = child(lockFace, "Title") :: TextLabel,
		lockPicks = child(lockFace, "Picks") :: TextLabel,
		lockKey = child(lockFace, "Key") :: Frame,
		hint = child(canvas, "Hint") :: TextLabel,
		enemyLabel = child(enemyRow, "Label") :: TextLabel,
		enemy = { child(enemyRow, "E1"), child(enemyRow, "E2"), child(enemyRow, "E3") },
		handlers = nil,
		open = false,
		token = 0,
		pulse = nil,
	}
	lockButton.MouseEnter:Connect(function()
		if s.open and s.handlers and s.handlers.canHover() then
			UiSound.play("Hover")
		end
	end)
	lockButton.Activated:Connect(function()
		if s.open and s.handlers then
			s.handlers.lock()
		end
	end)
	fitCanvas(s)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitCanvas(s)
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		fitCanvas(s)
	end)
	InputMode.changed:Connect(function()
		fitCanvas(s)
	end)
	s.hint.AnchorPoint = Vector2.new(0.5, 0.5)
	s.hint.Position = UDim2.new(0.5, 0, 0.5, 405)
	s.hint.Size = UDim2.fromOffset(1180, 38)
	s.hint.AutomaticSize = Enum.AutomaticSize.None
	s.hint.TextTruncate = Enum.TextTruncate.None
	s.hint.TextWrapped = true
	s.hint.TextScaled = true
	s.hint.TextXAlignment = Enum.TextXAlignment.Center
	local hintBounds = s.hint:FindFirstChildOfClass("UITextSizeConstraint")
		or Instance.new("UITextSizeConstraint")
	hintBounds.MinTextSize = 1
	hintBounds.MaxTextSize = 20
	hintBounds.Parent = s.hint
	fitLabel(s.lockPicks, 104, 44, 232, 24, 16, false)
	s.lockPicks.TextXAlignment = Enum.TextXAlignment.Center
	gui.Enabled = false
	state = s
end

-- Binds the DraftScreen once it has been copied into PlayerGui (every device).
function DraftScreen.start(_isCompact: boolean?, onReady: () -> ())
	task.spawn(function()
		local gui = WaitGui("DraftScreen")
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		bind(gui)
		onReady()
	end)
end

function DraftScreen.active(): boolean
	return state ~= nil
end

function DraftScreen.hint(): TextLabel?
	local s = state
	return if s then s.hint else nil
end

-- The hit area for a gun or card id (gamepad selection starts there).
function DraftScreen.button(id: string): GuiObject?
	local s = state
	if not s then
		return nil
	end
	for i = 1, s.gunShown do
		if s.guns[i].id == id then
			return s.guns[i].button
		end
	end
	for _, col in s.columns do
		for _, p in col.shown do
			if p.id == id then
				return p.button
			end
		end
	end
	return nil
end

local function fillGun(p: Pickable, g: GunView)
	p.id = g.id
	local card = p.card
	local image = child(card, "Gun") :: ImageLabel
	image.Image = g.image
	local name = child(card, "GunName") :: TextLabel
	name.Text = string.upper(g.name)
	local shield = child(card, "Shield") :: TextLabel
	shield.Visible = g.shield > 0
	shield.Text = string.format("+%d SHIELD", g.shield)
end

local function fillNew(p: Pickable, n: NewView)
	p.id = n.key
	p.compact = false
	local c = p.card
	local art = child(c, "Art") :: ImageLabel
	art.Image = n.art
	local band = child(c, "Band") :: Frame
	band.BackgroundColor3 = n.color
	local title = child(c, "Title") :: TextLabel
	title.Text = string.upper(n.name)
	local role = child(c, "Role") :: TextLabel
	role.Text = string.upper(n.role)
	local note = child(c, "Note") :: TextLabel
	note.Text = n.note
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Top
	fitLabel(note, 24, 398, COL_W - 48, 58, 17, true)
	local charges = child(c, "Charges") :: TextLabel
	charges.Text = n.charges
end

local function constrain(label: TextLabel, minSize: number, maxSize: number, wrap: boolean)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextTruncate = Enum.TextTruncate.None
	label.TextWrapped = wrap
	label.TextScaled = true
	local bounds = label:FindFirstChildOfClass("UITextSizeConstraint")
		or Instance.new("UITextSizeConstraint")
	bounds.MinTextSize = minSize
	bounds.MaxTextSize = maxSize
	bounds.Parent = label
end

local function fillPath(p: Pickable, v: PathView, y: number, h: number, count: number)
	p.id = v.key
	p.compact = count >= 3
	p.button.Position = UDim2.fromOffset(0, y)
	p.button.Size = UDim2.fromOffset(COL_W, h)
	local c = p.card
	local oldBrief = c:FindFirstChild("Brief")
	if oldBrief then
		oldBrief:Destroy()
	end
	local art = child(c, "Art") :: ImageLabel
	art.Image = v.art
	art.ImageTransparency = 0
	local band = child(c, "Band") :: Frame
	band.AnchorPoint = Vector2.new(0.5, 1)
	band.Position = UDim2.new(0.5, 0, 1, 156)
	band.Size = UDim2.fromOffset(COL_W * 2, 260)
	band.Rotation = -4
	band.BackgroundColor3 = if v.glitch then MAGENTA else v.color
	local panel = child(c, "Panel") :: Frame
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.fromScale(0, 1)
	panel.Size = UDim2.new(1, 0, 0, 40)
	panel.BackgroundTransparency = 0
	local titlePos = {
		Title = UDim2.new(0, 24, 1, -84),
		GlitchA = UDim2.new(0, 21, 1, -85),
		GlitchB = UDim2.new(0, 27, 1, -83),
	}
	for _, name in { "Title", "GlitchA", "GlitchB" } do
		local t = child(c, name) :: TextLabel
		t.Text = string.upper(v.name)
		t.AnchorPoint = Vector2.zero
		t.Position = titlePos[name]
		t.Size = UDim2.fromOffset(198, 34)
		t.TextXAlignment = Enum.TextXAlignment.Left
		constrain(t, 1, 28, false)
		if name ~= "Title" then
			t.Visible = v.glitch
		end
	end
	local tag = child(c, "Tag") :: TextLabel
	tag.Text = v.tag
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Position = UDim2.new(1, -18, 1, -74)
	tag.Size = UDim2.fromOffset(160, 18)
	tag.TextXAlignment = Enum.TextXAlignment.Right
	constrain(tag, 1, 11, false)
	local stat = child(c, "Stat") :: TextLabel
	stat.Text = v.stat
	stat.TextColor3 = if v.glitch then PINK else v.color
	stat.AnchorPoint = Vector2.zero
	stat.Position = UDim2.new(0, 18, 1, -35)
	stat.Size = UDim2.fromOffset(COL_W - 36, 30)
	stat.TextXAlignment = Enum.TextXAlignment.Left
	stat.TextYAlignment = Enum.TextYAlignment.Center
	constrain(stat, 1, 14, true)
	stat.Visible = v.stat ~= ""
end

local function fillColumn(col: Column, v: ColumnView)
	table.clear(col.shown)
	col.new.button.Visible = false
	col.maxed.Visible = false
	for _, p in col.paths do
		p.button.Visible = false
		p.id = ""
	end
	for _, o in col.ors do
		o.Visible = false
	end
	col.new.id = ""
	-- The tab names its slot's keyboard key (Settings kMod1-3); keyboard only, as built (the bumpers step cards).
	local keys = InputGlyphs.keysFor("Mod" .. (v.keySlot or col.index))
	local text = if keys[1] then InputGlyphs.keyName(keys[1]) else col.tabText
	if typeof(text) == "string" and col.tab:GetAttribute("KeyText") ~= text then
		col.tab:SetAttribute("KeyText", text)
		InputGlyphs.apply(col.tab)
	end
	local paths = v.paths or {}
	if v.new then
		fillNew(col.new, v.new)
		col.new.button.Visible = true
		table.insert(col.shown, col.new)
	elseif #paths > 0 then
		local n = math.min(#paths, #col.paths)
		local gap = if n == 3 then 22 else PATH_GAP
		local h = math.floor((CARD_H - gap * (n - 1)) / n)
		for i = 1, n do
			local p = col.paths[i]
			fillPath(p, paths[i], (i - 1) * (h + gap), h, n)
			p.button.Visible = true
			table.insert(col.shown, p)
			local orLabel = col.ors[i]
			if i < n and orLabel then
				orLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				orLabel.Size = UDim2.fromOffset(44, 14)
				orLabel.TextXAlignment = Enum.TextXAlignment.Center
				orLabel.Position = UDim2.fromOffset(COL_W / 2, i * (h + gap) - gap / 2)
				orLabel.Visible = true
			end
		end
	elseif v.maxed then
		col.maxed.Visible = true
		local icon = child(col.maxed, "Icon") :: ImageLabel
		icon.Image = v.maxed.icon
		local sub = child(col.maxed, "Sub") :: TextLabel
		sub.Text = v.maxed.sub
	end
	col.tab.Visible = (v.new ~= nil or #paths > 0 or v.maxed ~= nil) and InputGlyphs.shows(col.tab)
end

local function fillEnemy(s: State, entries: { EnemyView })
	s.enemyLabel.Text = if #entries > 0 then "ENEMY" else "ENEMY HAS NO POWERS YET"
	for i, tile in s.enemy do
		local e = entries[i]
		tile.Visible = e ~= nil
		if e then
			tile.BackgroundColor3 = e.color
			local icon = child(tile, "Icon") :: ImageLabel
			icon.Image = e.icon
			local level = child(tile, "Level") :: TextLabel
			level.Text = tostring(e.level)
		end
	end
end

-- Every pickable in use, guns first (for the open reveal).
local function shownList(s: State): { Pickable }
	local list: { Pickable } = {}
	for i = 1, s.gunShown do
		table.insert(list, s.guns[i])
	end
	for _, col in s.columns do
		for _, p in col.shown do
			table.insert(list, p)
		end
	end
	return list
end

function DraftScreen.show(view: View, handlers: Handlers)
	local s = state
	if not s then
		return
	end
	fitCanvas(s)
	s.handlers = handlers
	s.gunShown = math.min(#view.guns, #s.guns)
	for i, p in s.guns do
		local g = view.guns[i]
		p.button.Visible = g ~= nil
		p.picked, p.hover = false, false
		if g then
			fillGun(p, g)
		else
			p.id = ""
		end
	end
	for i, col in s.columns do
		fillColumn(col, view.columns[i] or {})
	end
	-- Focus: the columns with cards side by side in the middle, lifted into the empty gun row's space.
	local inUse: { Column } = {}
	for _, col in s.columns do
		col.frame.Visible = not view.focus or #col.shown > 0
		if col.frame.Visible then
			table.insert(inUse, col)
		end
	end
	if view.focus and #inUse > 0 then
		local home1, home2 = s.columns[1].home, s.columns[2].home
		local step = home2.X.Offset - home1.X.Offset -- one column + its gap
		local middle = home2.X.Offset -- the centre column's place
		for i, col in inUse do
			local x = middle + (i - (#inUse + 1) / 2) * step
			col.frame.Position =
				UDim2.new(col.home.X.Scale, x, col.home.Y.Scale, col.home.Y.Offset - FOCUS_LIFT)
		end
		s.lockButton.Position = s.lockHome - UDim2.fromOffset(0, FOCUS_LIFT)
	else
		for _, col in s.columns do
			col.frame.Position = col.home
		end
		s.lockButton.Position = s.lockHome
	end
	fillEnemy(s, view.enemy)
end

-- Marks the picked gun and card, and sets LOCK IN (ready / locked / waiting).
function DraftScreen.refresh(
	gun: string?,
	card: string?,
	ready: boolean,
	locked: boolean,
	picks: string
)
	local s = state
	if not s then
		return
	end
	for i = 1, s.gunShown do
		local p = s.guns[i]
		local was = p.picked
		p.picked = p.id == gun
		place(p, if was == p.picked then 0.15 else 0.2)
		if p.picked and not was and s.open then
			popScale(p.pop, 1.04)
		end
	end
	for _, col in s.columns do
		local any = false
		local topLifted = false
		for i, p in col.shown do
			local was = p.picked
			p.picked = p.id ~= "" and p.id == card
			any = any or p.picked
			if i == 1 then
				topLifted = p.picked
			end
			place(p, 0.2)
			if p.picked and not was and s.open then
				popScale(p.pop, if p.compact then 1.02 else 1.04)
			end
		end
		setKey(col.tab, any)
		local tabLift = if topLifted
			then (if col.shown[1] and col.shown[1].compact then 5 else LIFT)
			else 0
		tween(col.tab, 0.2, { Position = UDim2.fromOffset(COL_W / 2, -2 - tabLift) })
	end
	local fill = if locked then READY_FILL elseif ready or gun ~= nil then GOLD else WAIT_FILL
	for _, part in s.lockFill do
		if part:IsA("ImageLabel") then
			part.ImageColor3 = fill
		else
			part.BackgroundColor3 = fill
		end
	end
	s.lockTitle.Text = if locked then "LOCKED IN" else "LOCK IN"
	s.lockTitle.TextColor3 = INK
	s.lockPicks.Text = picks
	s.lockKey.Visible = not locked and InputGlyphs.shows(s.lockKey) -- no shortcut chip on touch
	-- A slow breathe while it's ready, so the eye finds it (from the centre).
	if ready and not s.pulse then
		local t = TweenService:Create(
			s.lockPop,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.03 }
		)
		t:Play()
		s.pulse = t
	elseif not ready and s.pulse then
		s.pulse:Cancel()
		s.pulse = nil
		s.lockPop.Scale = 1
	end
end

-- LOCK IN pressed: a pop when it locks, a "no" shake when it can't.
function DraftScreen.press(ok: boolean)
	local s = state
	if not s then
		return
	end
	if ok then
		if s.pulse then
			s.pulse:Cancel()
			s.pulse = nil
		end
		popScale(s.lockPop, 1.08)
		return
	end
	for i, dx in { -10, 8, -5, 0 } do
		task.delay((i - 1) * 0.04, function()
			s.lockFace.Position = UDim2.new(0.5, dx, 0.5, 0)
		end)
	end
end

-- Opens with the backdrop fading in and the cards popping in from their
-- centres one after another; closes with a quick fade.
function DraftScreen.setOpen(value: boolean)
	local s = state
	if not s or s.open == value then
		return
	end
	s.open = value
	s.token += 1
	local token = s.token
	s.backdrop.Modal = value -- frees the mouse in first person
	local cards = shownList(s)
	if value then
		s.gui.Enabled = true
		s.backdrop.BackgroundTransparency = 1
		tween(s.backdrop, OPEN_TIME, { BackgroundTransparency = 0.2 })
		s.canvas.Visible = true
		for i, p in cards do
			p.card.GroupTransparency = 1
			p.pop.Scale = 0.92
			task.delay((i - 1) * STAGGER, function()
				if token ~= s.token then
					return
				end
				tween(p.card, OPEN_TIME, { GroupTransparency = 0 })
				tween(p.pop, OPEN_TIME, { Scale = 1 })
			end)
		end
		s.lockPop.Scale = 0.92
		tween(s.lockPop, OPEN_TIME, { Scale = 1 })
	else
		tween(
			s.backdrop,
			CLOSE_TIME,
			{ BackgroundTransparency = 1 },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)
		for _, p in cards do
			p.hover = false
			tween(
				p.card,
				CLOSE_TIME,
				{ GroupTransparency = 1 },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
		end
		task.delay(CLOSE_TIME * 0.6, function()
			if token == s.token then
				s.canvas.Visible = false
			end
		end)
		task.delay(CLOSE_TIME + 0.02, function()
			if token == s.token then
				s.gui.Enabled = false
			end
		end)
	end
end

return DraftScreen
