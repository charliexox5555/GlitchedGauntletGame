--!strict
-- The lobby's Settings screen (vault/02 Art/UI Lobby Overhaul.md → Missing
-- screens). Studio-built StarterGui.Settings + row templates
-- (tools/studio/BuildSettings.luau); this fills them through the shared kit
-- (Util/LobbyKit: page, tabs, slots, buttons, plates).
--
-- GENERAL: reduced motion (live: Shared/UiMotion's switch); camera
--   sensitivity and field of view are SOON (no system reads them yet).
-- CROSSHAIR: an editor over a copy of Config/Crosshair.DEFAULT (size, colour,
--   bars, gap, dot, outline, X shape, static, show while aiming) with a live
--   preview in the INSPECT panel. The copy lasts this session; saving it to
--   the profile and reading it in the match is parked (results note).
-- Like RIVALS' Settings: the list on the left, INSPECT explains the row you
-- point at.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UserInputService = game:GetService("UserInputService")

local Crosshair = require(ReplicatedStorage.Shared.Config.Crosshair)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Plates = require(script.Parent.Parent.Util.Plates)

local SettingsController = {}

local player = Players.LocalPlayer
local C = LobbyKit.C
local DESIGN = Vector2.new(1920, 1080)
local PREVIEW_ZOOM = 3 -- the preview draws the 1080p crosshair this much bigger

type Kind = "toggle" | "slider" | "swatches"
type Row = {
	name: string,
	desc: string,
	kind: Kind,
	soon: boolean?,
	get: (() -> any)?,
	set: ((any) -> ())?,
	min: number?,
	max: number?,
	step: number?,
	fmt: ((number) -> string)?,
	colors: { Color3 }?,
}

-- the session copy of the crosshair (deep: DEFAULT's inner tables)
local function copy<T>(t: T): T
	if typeof(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t :: any do
		out[k] = copy(v)
	end
	return out :: any
end
local ch = copy(Crosshair.DEFAULT)

local gui: ScreenGui
local list: ScrollingFrame
local head: TextLabel
local desc: TextLabel
local preview: Frame
local mark: Frame
local templates: Folder
local current = 1
local dragConns: { RBXScriptConnection } = {}
local redraw: () -> () = function() end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function one(n: number): string
	return string.format("%.1f", n)
end
local function whole(n: number): string
	return tostring(math.floor(n + 0.5))
end

local ROWS: { { Row } } = {
	{
		{
			name = "REDUCED MOTION",
			desc = "Fades instead of slides, pops and shakes in every menu. Starts from your Roblox setting.",
			kind = "toggle",
			get = UiMotion.reduced,
			set = function(on: boolean)
				UiMotion.setReduced(on)
			end,
		},
		{
			name = "CAMERA SENSITIVITY",
			desc = "How fast the match camera turns. Comes with the profile system, which saves it and hands it to the match.",
			kind = "slider",
			soon = true,
		},
		{
			name = "FIELD OF VIEW",
			desc = "The match camera's field of view. Comes with the profile system.",
			kind = "slider",
			soon = true,
		},
	},
	{
		{
			name = "SIZE",
			desc = "The whole crosshair, bigger or smaller.",
			kind = "slider",
			min = 0.5,
			max = 2,
			step = 0.1,
			fmt = one,
			get = function()
				return ch.scale
			end,
			set = function(v: number)
				ch.scale = v
			end,
		},
		{
			name = "COLOUR",
			desc = "Pick a colour that stands out on the maps you play. The dark outline keeps any colour readable.",
			kind = "swatches",
			colors = {
				Color3.fromHex("FFFFFF"),
				Color3.fromHex("3FE0F2"),
				Color3.fromHex("3FD45C"),
				Color3.fromHex("FFC83D"),
				Color3.fromHex("FF4D5E"),
				Color3.fromHex("FF6BD6"),
			},
			get = function()
				return ch.color
			end,
			set = function(c: Color3)
				ch.color = c
			end,
		},
		{
			name = "LENGTH",
			desc = "How long each bar is.",
			kind = "slider",
			min = 2,
			max = 16,
			step = 1,
			fmt = whole,
			get = function()
				return ch.bars.length
			end,
			set = function(v: number)
				ch.bars.length = v
			end,
		},
		{
			name = "THICKNESS",
			desc = "How thick each bar is.",
			kind = "slider",
			min = 1,
			max = 6,
			step = 1,
			fmt = whole,
			get = function()
				return ch.bars.thickness
			end,
			set = function(v: number)
				ch.bars.thickness = v
			end,
		},
		{
			name = "GAP",
			desc = "The space in the middle when you stand still. Moving and shooting still open it, unless it's STATIC.",
			kind = "slider",
			min = 0,
			max = 16,
			step = 1,
			fmt = whole,
			get = function()
				return ch.bars.spacing
			end,
			set = function(v: number)
				ch.bars.spacing = v
			end,
		},
		{
			name = "CENTRE DOT",
			desc = "A dot in the very middle.",
			kind = "toggle",
			get = function()
				return ch.dot.enabled
			end,
			set = function(on: boolean)
				ch.dot.enabled = on
			end,
		},
		{
			name = "OUTLINE",
			desc = "A dark edge around the bars and dot, so they read on bright walls and white flashes.",
			kind = "toggle",
			get = function()
				return ch.outline.enabled
			end,
			set = function(on: boolean)
				ch.outline.enabled = on
			end,
		},
		{
			name = "X SHAPE",
			desc = "Turns the crosshair 45 degrees into an X.",
			kind = "toggle",
			get = function()
				return ch.rotation ~= 0
			end,
			set = function(on: boolean)
				ch.rotation = if on then 45 else 0
			end,
		},
		{
			name = "STATIC",
			desc = "The gap stays put: moving and shooting don't open it.",
			kind = "toggle",
			get = function()
				return ch.static
			end,
			set = function(on: boolean)
				ch.static = on
			end,
		},
		{
			name = "SHOW WHILE AIMING",
			desc = "Keep the crosshair on screen while you aim down sights.",
			kind = "toggle",
			get = function()
				return ch.showWhileAiming
			end,
			set = function(on: boolean)
				ch.showWhileAiming = on
			end,
		},
	},
}

--------------------------------------------------------------------------------
-- The live crosshair preview

local function bar(
	parent: Instance,
	w: number,
	h: number,
	x: number,
	y: number,
	color: Color3,
	z: number
)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
end

local function drawCrosshair()
	mark:ClearAllChildren()
	mark.Rotation = ch.rotation
	local k = ch.scale * PREVIEW_ZOOM
	local len = math.max(1, math.floor(ch.bars.length * k + 0.5))
	local th = math.max(1, math.floor(ch.bars.thickness * k + 0.5))
	local gap = math.floor(ch.bars.spacing * k + 0.5)
	local o = if ch.outline.enabled
		then math.max(1, math.floor(ch.outline.thickness * k + 0.5))
		else 0
	local function piece(w: number, h: number, x: number, y: number)
		if o > 0 then
			bar(mark, w + o * 2, h + o * 2, x, y, ch.outline.color, 5)
		end
		bar(mark, w, h, x, y, ch.color, 6)
	end
	if ch.bars.enabled then
		local d = gap + len / 2
		if ch.bars.top then
			piece(th, len, 0, -d)
		end
		if ch.bars.bottom then
			piece(th, len, 0, d)
		end
		if ch.bars.left then
			piece(len, th, -d, 0)
		end
		if ch.bars.right then
			piece(len, th, d, 0)
		end
	end
	if ch.dot.enabled then
		local s = math.max(1, math.floor(ch.dot.size * k + 0.5))
		piece(s, s, 0, 0)
	end
end

--------------------------------------------------------------------------------
-- Rows

local function inspectRow(row: Row)
	head.Text = row.name
	desc.Text = if row.soon then row.desc .. "  (SOON)" else row.desc
end

local function soonLabel(control: Frame)
	local l = Instance.new("TextLabel")
	l.Name = "Soon"
	l.AnchorPoint = Vector2.new(1, 0.5)
	l.Position = UDim2.new(1, -16, 0.5, 0)
	l.Size = UDim2.fromOffset(160, 40)
	l.BackgroundTransparency = 1
	l.Text = "SOON"
	l.FontFace = LobbyKit.FONT
	l.TextSize = 24
	l.TextColor3 = C.muted
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.ZIndex = 6
	l.Parent = control
end

local function fillToggle(control: Frame, row: Row, rowButton: GuiButton)
	local t = (templates:WaitForChild("SettingToggle") :: Frame):Clone()
	t.Parent = control
	local switch = child(t, "Switch") :: TextButton
	local state = child(switch, "State") :: TextLabel
	Plates.finish(switch)
	local function look()
		local on = row.get and row.get() == true
		switch.BackgroundColor3 = if on then C.white else C.navyHi
		state.Text = if on then "ON" else "OFF"
		state.TextColor3 = if on then C.ink else C.muted
	end
	look()
	local function flip()
		if row.get and row.set then
			row.set(not row.get())
			look()
			redraw()
		end
	end
	LobbyKit.button(switch, flip)
	rowButton.Activated:Connect(flip)
end

local function fillSlider(control: Frame, row: Row)
	local s = (templates:WaitForChild("SettingSlider") :: Frame):Clone()
	s.Parent = control
	local track = child(s, "Track") :: TextButton
	local fill = child(track, "Fill") :: Frame
	local knob = child(track, "Knob") :: Frame
	local knobPop = child(knob, "Pop") :: UIScale
	local value = child(s, "Value") :: TextLabel
	local lo, hi, step = row.min or 0, row.max or 1, row.step or 0.1
	local function show(v: number)
		local a = (v - lo) / (hi - lo)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		value.Text = if row.fmt then row.fmt(v) else one(v)
	end
	show(if row.get then row.get() else lo)
	local function setFromX(x: number)
		local a =
			math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = math.clamp(lo + math.floor(a * (hi - lo) / step + 0.5) * step, lo, hi)
		if row.set then
			row.set(v)
		end
		show(v)
		redraw()
	end
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		setFromX(input.Position.X)
		UiMotion.rest(knobPop, LobbyKit.M.hover)
		for _, c in dragConns do
			c:Disconnect()
		end
		table.clear(dragConns)
		table.insert(
			dragConns,
			UserInputService.InputChanged:Connect(function(move: InputObject)
				if
					move.UserInputType == Enum.UserInputType.MouseMovement
					or move.UserInputType == Enum.UserInputType.Touch
				then
					setFromX(move.Position.X)
				end
			end)
		)
		table.insert(
			dragConns,
			UserInputService.InputEnded:Connect(function(done: InputObject)
				if done.UserInputType == t then
					UiMotion.rest(knobPop, 1)
					for _, c in dragConns do
						c:Disconnect()
					end
					table.clear(dragConns)
				end
			end)
		)
	end)
end

local function fillSwatches(control: Frame, row: Row)
	local s = (templates:WaitForChild("SettingSwatches") :: Frame):Clone()
	s.Parent = control
	local pattern = child(s, "Swatch") :: TextButton
	local pops: { [Color3]: UIScale } = {}
	local function look()
		local now = if row.get then row.get() else nil
		for c, pop in pops do
			UiMotion.rest(pop, if now == c then 1.2 else 1)
		end
	end
	for i, c in row.colors or {} do
		local b = pattern:Clone()
		b.Name = "Swatch" .. i
		b.LayoutOrder = i
		b.BackgroundColor3 = c
		b.Visible = true
		b.Parent = s
		pops[c] = child(b, "Pop") :: UIScale
		b.Activated:Connect(function()
			if row.set then
				row.set(c)
			end
			look()
			redraw()
		end)
	end
	look()
end

local function renderTab(i: number)
	current = i
	for _, c in dragConns do
		c:Disconnect()
	end
	table.clear(dragConns)
	LobbyKit.clearSlots(list)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	preview.Visible = i == 2
	local tpl = templates:WaitForChild("SettingRow") :: TextButton
	for n, row in ROWS[i] do
		local item = LobbyKit.slot(tpl, list, function(r: TextButton)
			r.Name = "Row" .. n
			r.LayoutOrder = n
			StateValues.set(r, "Slot", true)
			local nameLabel = child(r, "Name") :: TextLabel
			nameLabel.Text = row.name
			nameLabel.TextColor3 = if row.soon then C.muted else C.white
		end)
		local control = child(item, "Control") :: Frame
		if row.soon then
			soonLabel(control)
		elseif row.kind == "toggle" then
			fillToggle(control, row, item)
		elseif row.kind == "slider" then
			fillSlider(control, row)
		else
			fillSwatches(control, row)
		end
		LobbyKit.button(item, function() end, {
			card = true,
			onHover = function(on: boolean)
				if on then
					inspectRow(row)
				end
			end,
		})
		if n == 1 then
			inspectRow(row)
		end
	end
	list.CanvasPosition = Vector2.zero
	redraw()
end

function SettingsController.init()
	local g = player:WaitForChild("PlayerGui"):WaitForChild("Settings", 15)
	local folder = ReplicatedStorage:WaitForChild("UiTemplates", 15)
	local lobby = folder and folder:WaitForChild("Lobby", 15)
	if not (g and g:IsA("ScreenGui") and lobby) then
		warn(
			"[Settings] StarterGui.Settings or its templates missing (tools/studio/BuildSettings.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	templates = lobby :: Folder
	local canvas = child(gui, "Canvas") :: Frame
	list = child(canvas, "List") :: ScrollingFrame
	local inspect = child(canvas, "Inspect") :: Frame
	head = child(inspect, "Head") :: TextLabel
	desc = child(inspect, "Desc") :: TextLabel
	preview = child(inspect, "Preview") :: Frame
	mark = child(preview, "Crosshair") :: Frame
	redraw = drawCrosshair

	Plates.deepen(gui)
	local tabs = child(canvas, "Tabs") :: Frame
	local pick = LobbyKit.tabs(
		{ child(tabs, "GENERAL") :: GuiButton, child(tabs, "CROSSHAIR") :: GuiButton },
		renderTab
	)

	LobbyKit.page({
		name = "Settings",
		gui = gui,
		canvas = canvas,
		design = DESIGN,
		wash = child(gui, "Wash") :: Frame,
		close = child(canvas, "Close") :: GuiButton,
		focus = function()
			return list:FindFirstChildWhichIsA("GuiButton", true)
		end,
		-- phones: the title, tabs and list fill the screen (about 0.78 zoom on
		-- a 812 x 375 phone: 20 px words, 70 px rows); INSPECT steps aside
		phone = {
			region = Rect.new(130, 20, 1090, 500),
			arrange = function()
				inspect.Visible = false
				local close = child(canvas, "Close") :: GuiObject
				close.Position = UDim2.fromOffset(1040, 76)
				list.Size = UDim2.fromOffset(940, 270)
			end,
		},
		onOpen = function(arg: any?)
			if arg == "crosshair" then
				pick(2)
			elseif current == 0 then
				pick(1)
			else
				renderTab(current)
			end
		end,
	})
	current = 0
end

return SettingsController
