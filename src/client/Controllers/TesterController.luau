--!strict
-- Tester tools for the test range (test mode only, shared/TestMode):
--   • a menu (B, D-pad up, or the TEST button) with four pages: Loadout (any
--     gun into its slot), Range (refill ammo, reset dummies and stats, dummy
--     behaviours), Settings (FOV, panels) and Controls (keys + how to play);
--   • a stats panel: DPS, damage, time-to-kill, accuracy, headshots, kills
--     and the last hit's damage and distance, all measured by the server
--     (TesterStats). Nothing here decides anything: it asks the server
--     (Tester remote) and shows what comes back.
-- Works with mouse, gamepad (D-pad/stick selection, B closes) and touch.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraConfig = require(Shared.Config.Camera)
local Input = require(Shared.Config.Input)
local Net = require(Shared.Net)
local TestMode = require(Shared.TestMode)
local TestRange = require(Shared.Config.TestRange)
local Types = require(Shared.Types)
local Weapons = require(Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local RangeController = require(script.Parent.RangeController)

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig

local TesterController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local NEON = Color3.fromHex("00E5FF")
local GOLD = Color3.fromHex("FFC83D")
local MAGENTA = Color3.fromHex("FF3DCB")
local DARK = Color3.fromHex("1C2030")
local PANEL = Color3.fromHex("56607C")
local CARD = Color3.fromHex("252A3D")
local CARD_HOVER = Color3.fromHex("30364D")
local MUTED = Color3.fromHex("8A93AD")
local FONT = Enum.Font.GothamBold

local TIER_COLORS: { [number]: Color3 } = {
	[1] = Color3.fromHex("AEB6CC"),
	[2] = NEON,
	[3] = GOLD,
	[4] = MAGENTA,
}
local CLASS_NAMES: { [string]: string } = { MachineGun = "Machine Gun" }
local SLOTS: { Slot } = { "Primary", "Secondary", "Melee" }
local MENU_NAME = "Tester"
local PANEL_SIZE = Vector2.new(940, 620)

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

type Card = { button: TextButton, stroke: UIStroke, name: TextLabel }
type StatRow = { value: TextLabel }

local backdrop: TextButton? = nil
local panelScale: UIScale? = nil
local firstSelectable: GuiObject? = nil
local menuOpen = false
local openTween: Tween? = nil

local loadout: { [Slot]: string } = {}
local cards: { [string]: Card } = {}
local slotChips: { [Slot]: TextLabel } = {}
local showSlot: (Slot) -> () = function() end

local statsPanel: Frame? = nil
local statRows: { [string]: StatRow } = {}
local dpsFill: Frame? = nil

-- Helpers --------------------------------------------------------------------------

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function text(
	parent: Instance,
	value: string,
	size: number,
	color: Color3?,
	font: Enum.Font?,
	props: { [string]: any }?
): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = font or FONT,
		TextSize = size,
		TextColor3 = color or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		Text = value,
	}, parent)
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	return label
end

-- A button with hover, press pop and gamepad selection highlight.
local function button(
	parent: Instance,
	label: string,
	accent: Color3?,
	props: { [string]: any }?
): TextButton
	local b = make("TextButton", {
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		Font = FONT,
		TextSize = 15,
		TextColor3 = WHITE,
		Text = label,
		Size = UDim2.fromOffset(180, 40),
	}, parent)
	corner(b)
	local s = make("UIStroke", {
		Color = accent or NEON,
		Thickness = 1,
		Transparency = 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	local scale = make("UIScale", {}, b)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	local base = b.BackgroundColor3
	local function hover(on: boolean)
		b.BackgroundColor3 = if on then CARD_HOVER else base
		s.Transparency = if on then 0 else 0.5
	end
	b.MouseEnter:Connect(function()
		hover(true)
	end)
	b.MouseLeave:Connect(function()
		hover(false)
	end)
	b.SelectionGained:Connect(function()
		hover(true)
	end)
	b.SelectionLost:Connect(function()
		hover(false)
	end)
	b.Activated:Connect(function()
		scale.Scale = 0.94
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end)
	return b
end

local function tester(action: Types.TesterAction, a: any?, b: any?)
	Net.event("Tester"):FireServer(action, a, b)
end

local function rpm(config: WeaponConfig): number
	return math.round(60 / math.max(config.fireInterval, 0.001))
end

-- One line of numbers for a weapon card.
local function statLine(w: WeaponConfig): string
	if w.melee then
		return string.format("%d dmg · %d backstab", w.damage.body, w.melee.backDamage)
	end
	if w.beam then
		return string.format("%d→%d dps beam · battery", w.beam.dpsStart, w.beam.dpsEnd)
	end
	local dmg = if w.pellets > 1
		then string.format("%d×%d", w.pellets, w.damage.body)
		else string.format("%d/%d", w.damage.body, w.damage.head)
	local fall = if w.falloff
		then string.format(" · falloff %d–%d", w.falloff.start, w.falloff.finish)
		else ""
	return string.format("%s dmg · %d rpm · %d rds%s", dmg, rpm(w), w.magSize, fall)
end

local function weaponsFor(slot: Slot): { WeaponConfig }
	local list = {}
	for _, w in Weapons.list do
		if w.slot == slot then
			table.insert(list, w)
		end
	end
	table.sort(list, function(a, b)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.displayName < b.displayName
	end)
	return list
end

-- Highlights the guns currently in the loadout.
local function refreshLoadout()
	local held: { [string]: boolean } = {}
	for _, id in loadout do
		held[id] = true
	end
	for id, card in cards do
		card.stroke.Enabled = held[id] == true
		card.name.TextColor3 = if held[id] then NEON else WHITE
	end
	for slot, chip in slotChips do
		local config = loadout[slot] and Weapons.get(loadout[slot])
		chip.Text = if config then config.displayName else "—"
	end
end

-- Menu pages --------------------------------------------------------------------------

local function pageFrame(parent: Instance, name: string): ScrollingFrame
	local page = make("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = NEON,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Selectable = false,
	}, parent)
	make(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) },
		page
	)
	make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, page)
	return page
end

local function heading(parent: Instance, value: string, order: number)
	text(parent, value, 13, MUTED, FONT, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order })
end

local function row(parent: Instance, order: number, height: number): Frame
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, f)
	return f
end

local function buildLoadoutPage(page: ScrollingFrame)
	heading(
		page,
		"YOUR LOADOUT  —  pick a slot, then a gun. It's yours until you change it, even after dying.",
		1
	)
	local chips = row(page, 2, 56)
	local slotButtons: { [Slot]: TextButton } = {}
	for i, slot in SLOTS do
		local b = button(
			chips,
			"",
			NEON,
			{ Name = "Slot_" .. slot, Size = UDim2.fromOffset(176, 54), LayoutOrder = i }
		)
		text(b, string.upper(slot), 11, MUTED, FONT, {
			Position = UDim2.fromOffset(12, 7),
			Size = UDim2.new(1, -24, 0, 14),
		})
		slotChips[slot] = text(b, "—", 17, WHITE, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(12, 22),
			Size = UDim2.new(1, -24, 0, 24),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		slotButtons[slot] = b
		b.Activated:Connect(function()
			showSlot(slot)
		end)
	end
	local refill = button(
		chips,
		"REFILL AMMO",
		GOLD,
		{ Name = "Refill", Size = UDim2.fromOffset(140, 54), LayoutOrder = 10 }
	)
	refill.Activated:Connect(function()
		tester("Refill")
	end)

	local grids: { [Slot]: Frame } = {}
	for i, slot in SLOTS do
		local grid = make("Frame", {
			Name = slot,
			LayoutOrder = 3 + i,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = false,
		}, page)
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(222, 74),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for order, w in weaponsFor(slot) do
			local tierColor = TIER_COLORS[w.tier] or WHITE
			local b = make("TextButton", {
				Name = w.id,
				LayoutOrder = order,
				BackgroundColor3 = CARD,
				AutoButtonColor = false,
				Text = "",
			}, grid)
			corner(b)
			local s = make("UIStroke", {
				Color = NEON,
				Thickness = 2,
				Enabled = false,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, b)
			make("Frame", {
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.new(0, 3, 1, -20),
				BackgroundColor3 = tierColor,
				BorderSizePixel = 0,
			}, b)
			local name = text(b, w.displayName, 16, WHITE, FONT, {
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -24, 0, 20),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			text(
				b,
				string.format(
					"%s · <font color='#%s'>TIER %d</font>",
					string.upper(CLASS_NAMES[w.class] or w.class),
					tierColor:ToHex(),
					w.tier
				),
				11,
				MUTED,
				Enum.Font.GothamMedium,
				{ Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -24, 0, 14) }
			)
			text(b, statLine(w), 11, Color3.fromHex("C9D0E3"), Enum.Font.Gotham, {
				Position = UDim2.fromOffset(14, 48),
				Size = UDim2.new(1, -24, 0, 14),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local function hover(on: boolean)
				b.BackgroundColor3 = if on then CARD_HOVER else CARD
			end
			b.MouseEnter:Connect(function()
				hover(true)
			end)
			b.MouseLeave:Connect(function()
				hover(false)
			end)
			b.SelectionGained:Connect(function()
				hover(true)
			end)
			b.SelectionLost:Connect(function()
				hover(false)
			end)
			b.Activated:Connect(function()
				tester("SetWeapon", w.slot, w.id)
				-- Shown right away; the server's WeaponState confirms it.
				loadout[w.slot] = w.id
				refreshLoadout()
			end)
			cards[w.id] = { button = b, stroke = s, name = name }
		end
		grids[slot] = grid
	end

	showSlot = function(slot: Slot)
		for s, grid in grids do
			grid.Visible = s == slot
		end
		for s, b in slotButtons do
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if s == slot then 2 else 1
			end
		end
	end
	showSlot("Primary")
end

-- A labelled on/off switch. Returns a setter for outside changes.
local function toggleRow(
	parent: Instance,
	order: number,
	label: string,
	hint: string,
	onChange: (boolean) -> ()
): (boolean) -> ()
	local b = button(parent, "", NEON, {
		Name = "Toggle_" .. string.gsub(label, "%s", ""),
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = order,
	})
	b.TextXAlignment = Enum.TextXAlignment.Left
	text(
		b,
		label,
		15,
		WHITE,
		FONT,
		{ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -100, 0, 18) }
	)
	text(
		b,
		hint,
		12,
		MUTED,
		Enum.Font.Gotham,
		{ Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -100, 0, 14) }
	)
	local track = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
		BackgroundColor3 = DARK,
		BorderSizePixel = 0,
	}, b)
	corner(track, 12)
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = MUTED,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 9)
	local state = false
	local function set(on: boolean)
		state = on
		TweenService:Create(knob, FAST, {
			Position = if on then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = if on then DARK else MUTED,
		}):Play()
		TweenService:Create(track, FAST, { BackgroundColor3 = if on then NEON else DARK }):Play()
	end
	b.Activated:Connect(function()
		set(not state)
		onChange(state)
	end)
	return set
end

local function buildRangePage(page: ScrollingFrame)
	heading(page, "ACTIONS", 1)
	local actions = row(page, 2, 44)
	local refill = button(actions, "REFILL AMMO", GOLD, { Name = "Refill", LayoutOrder = 1 })
	refill.Activated:Connect(function()
		tester("Refill")
	end)
	local reset = button(actions, "RESET DUMMIES", NEON, { Name = "ResetDummies", LayoutOrder = 2 })
	reset.Activated:Connect(function()
		tester("ResetDummies")
	end)
	local stats = button(actions, "RESET MY STATS", PANEL, { Name = "ResetStats", LayoutOrder = 3 })
	stats.Activated:Connect(function()
		tester("ResetStats")
	end)

	heading(page, "DUMMY BEHAVIOUR  —  shared with everyone in this server", 3)
	local state = ReplicatedStorage:WaitForChild("TestRangeState", 10)
	for i, b in TestRange.BEHAVIOURS do
		local set = toggleRow(page, 3 + i, b.label, b.hint, function(on)
			tester("SetBehaviour", b.id, on)
		end)
		if state then
			local function sync()
				set(state:GetAttribute(b.id) == true)
			end
			sync()
			state:GetAttributeChangedSignal(b.id):Connect(sync)
		else
			set(b.default)
		end
	end

	heading(page, "DUMMIES", 20)
	local legend = make("Frame", {
		LayoutOrder = 21,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, page)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(222, 54),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, legend)
	local notes: { [string]: string } = {
		Idle = "Stands still. One per distance marker: falloff.",
		Strafe = "Runs left and right at walk speed.",
		StrafeJump = "Strafes and jumps at random.",
		Crouch = "Crouch-walks: a smaller, lower target.",
		LongRange = "150 studs on the back platform.",
		Shooter = "Fires harmless tracers at you.",
	}
	for i, kindName in { "Idle", "Strafe", "StrafeJump", "Crouch", "LongRange", "Shooter" } do
		local kind = (TestRange.KINDS :: any)[kindName]
		local cell = make("Frame", { BackgroundColor3 = CARD, LayoutOrder = i }, legend)
		corner(cell)
		make("Frame", {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(0, 3, 1, -20),
			BackgroundColor3 = kind.accent,
			BorderSizePixel = 0,
		}, cell)
		text(cell, kind.label, 13, kind.accent, Enum.Font.GothamBlack, {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -20, 0, 16),
		})
		text(cell, notes[kindName], 11, MUTED, Enum.Font.Gotham, {
			Position = UDim2.fromOffset(14, 27),
			Size = UDim2.new(1, -20, 0, 20),
			TextWrapped = true,
		})
	end
end

local function buildSettingsPage(page: ScrollingFrame)
	heading(page, "FIELD OF VIEW", 1)
	local fovRow = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = CARD,
	}, page)
	corner(fovRow)
	local minus = button(fovRow, "–", NEON, {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(40, 40),
		TextSize = 22,
	})
	local plus = button(fovRow, "+", NEON, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -86, 0, 8),
		Size = UDim2.fromOffset(40, 40),
		TextSize = 22,
	})
	local value = text(fovRow, "", 18, NEON, Enum.Font.GothamBlack, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(64, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local track = make("TextButton", {
		Position = UDim2.new(0, 66, 0.5, -4),
		Size = UDim2.new(1, -66 - 142, 0, 8),
		BackgroundColor3 = DARK,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
	}, fovRow)
	corner(track, 4)
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = NEON,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 4)
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 10)

	local lo, hi = CameraConfig.MIN_FOV, CameraConfig.MAX_FOV
	local function show(fov: number)
		local a = (fov - lo) / (hi - lo)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		value.Text = string.format("%d°", fov)
	end
	local function setFov(fov: number)
		local clamped = math.clamp(math.round(fov), lo, hi)
		CameraController.setBaseFov(clamped)
		show(clamped)
	end
	show(CameraController.getBaseFov())
	minus.Activated:Connect(function()
		setFov(CameraController.getBaseFov() - 1)
	end)
	plus.Activated:Connect(function()
		setFov(CameraController.getBaseFov() + 1)
	end)
	local dragging = false
	local function dragTo(x: number)
		local a =
			math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		setFov(lo + a * (hi - lo))
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	text(
		page,
		string.format("%d to %d. Aiming zooms in from here.", lo, hi),
		12,
		MUTED,
		Enum.Font.Gotham,
		{
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 14),
		}
	)

	heading(page, "SCREEN", 4)
	local setStats = toggleRow(
		page,
		5,
		"Stats panel",
		"Damage, TTK, accuracy and DPS on the left",
		function(on)
			if statsPanel then
				statsPanel.Visible = on
			end
		end
	)
	setStats(true)
	local setBars = toggleRow(page, 6, "Dummy health bars", "Health over every dummy", function(on)
		RangeController.setBarsVisible(on)
	end)
	setBars(RangeController.barsVisible())
end

-- Readable key names for the controls page.
local KEY_NAMES: { [string]: string } = {
	MouseLeftButton = "Left click",
	MouseRightButton = "Right click",
	LeftShift = "Shift",
	LeftControl = "Ctrl",
	One = "1",
	Two = "2",
	Three = "3",
	ButtonR2 = "RT",
	ButtonL2 = "LT",
	ButtonR1 = "RB",
	ButtonL1 = "LB",
	ButtonR3 = "Right stick click",
	ButtonL3 = "Left stick click",
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	DPadUp = "D-pad up",
	DPadDown = "D-pad down",
	DPadLeft = "D-pad left",
	DPadRight = "D-pad right",
}
local TOUCH_NAMES: { [string]: string } = {
	FireButton = "FIRE",
	AimButton = "AIM",
	ReloadButton = "R",
	SprintButton = "RUN",
	SlideButton = "SLIDE",
	SwapButton = "SWAP",
}

local function keys(list: { Enum.KeyCode }): string
	local names = {}
	for _, k in list do
		table.insert(names, KEY_NAMES[k.Name] or k.Name)
	end
	return if #names > 0 then table.concat(names, " / ") else "—"
end

local function binding(name: string): (string, string, string)
	local b = Input[name]
	if not b then
		return "—", "—", "—"
	end
	return keys(b.keys), keys(b.gamepad), if b.touch then TOUCH_NAMES[b.touch] or b.touch else "—"
end

local function buildControlsPage(page: ScrollingFrame)
	local rows: { { string } } = {
		{ "Move", "W A S D", "Left stick", "Thumbstick" },
		{ "Look", "Mouse", "Right stick", "Drag the screen" },
		{ "Jump", "Space", "A", "Jump button" },
	}
	local function add(label: string, name: string, touchOverride: string?)
		local k, g, t = binding(name)
		table.insert(rows, { label, k, g, touchOverride or t })
	end
	add("Fire", "Fire")
	add("Aim down sights", "Aim")
	add("Reload", "Reload")
	add("Sprint", "Sprint")
	add("Crouch (slide while sprinting)", "Crouch")
	table.insert(rows, {
		"Primary / secondary / melee",
		"1 / 2 / 3",
		keys(Input.CycleWeapon.gamepad) .. " cycles",
		"SWAP",
	})
	add("Quick melee", "QuickMelee")
	add("Inspect gun", "Inspect")
	add("Tester menu", "TesterMenu", "TEST (top of the screen)")
	table.insert(rows, { "Take a gun from a rack", "E", "D-pad right", "Tap the prompt" })

	heading(page, "CONTROLS", 1)
	local table_ = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, page)
	make(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) },
		table_
	)
	local columns = { 0, 0.34, 0.56, 0.76 }
	local widths = { 0.33, 0.21, 0.19, 0.24 }
	local headerRow = { "ACTION", "KEYBOARD & MOUSE", "GAMEPAD", "TOUCH" }
	for i, r in { headerRow, table.unpack(rows) } do
		local line = make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = CARD,
			BackgroundTransparency = if i == 1 then 1 elseif i % 2 == 0 then 0 else 0.5,
		}, table_)
		corner(line, 4)
		for c = 1, 4 do
			text(
				line,
				r[c],
				if i == 1 then 11 else 13,
				if i == 1 then MUTED elseif c == 1 then WHITE else NEON,
				if c == 1 or i == 1 then FONT else Enum.Font.GothamMedium,
				{
					Position = UDim2.new(columns[c], 10, 0, 0),
					Size = UDim2.new(widths[c], -10, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
				}
			)
		end
	end

	heading(page, "HOW IT WORKS", 3)
	local tips = {
		"<b>Damage falls off with distance.</b> Shoot the static dummies at 10, 25, 50 and 100 studs and watch <b>Last hit</b> on the stats panel.",
		"<b>Headshots</b> do about 1.5× damage, legs a little less than the body.",
		"<b>Moving and jumping</b> widen your spread; aiming and standing still tighten it. The crosshair shows it.",
		"<b>Slide:</b> sprint, then crouch. Jump out of a slide to carry its speed (the gap course on the right).",
		"<b>ThinWall</b> (the glowing glass on the left) lets some guns shoot through; solid walls stop everything except guns that ignore walls.",
		"<b>Time-to-kill</b> runs from your first hit on a dummy to the kill. Turn on <b>Dummies heal</b> to start each test from full health.",
		"Every number here is measured by the server: what you see is what a real match counts.",
	}
	for i, tip in tips do
		text(page, "•  " .. tip, 13, Color3.fromHex("C9D0E3"), Enum.Font.Gotham, {
			LayoutOrder = 3 + i,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
		})
	end
end

-- Menu shell -------------------------------------------------------------------------

local function fitScale(): number
	local cam = Workspace.CurrentCamera
	local view = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	return math.min(1, (view.X - 24) / PANEL_SIZE.X, (view.Y - 24) / PANEL_SIZE.Y)
end

local function setOpen(open: boolean)
	local root = backdrop
	local scale = panelScale
	if not root or not scale or open == menuOpen then
		return
	end
	menuOpen = open
	HudController.setMenuOpen(MENU_NAME, open)
	if openTween then
		openTween:Cancel()
	end
	if open then
		refreshLoadout()
		root.Visible = true
		local target = fitScale()
		scale.Scale = target * 0.94
		root.BackgroundTransparency = 1
		openTween = TweenService:Create(scale, POP, { Scale = target });
		(openTween :: Tween):Play()
		TweenService:Create(root, FAST, { BackgroundTransparency = 0.45 }):Play()
		-- Gamepad: start selection on the first tab.
		if UserInputService.GamepadEnabled and firstSelectable then
			GuiService.SelectedObject = firstSelectable
		end
	else
		root.Visible = false
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
	end
end

local function toggle()
	setOpen(not menuOpen)
end

local function buildMenu(parent: ScreenGui)
	local root = make("TextButton", {
		Name = "TesterMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Modal = true,
		Text = "",
		Visible = false,
		Selectable = false,
		ZIndex = 1,
	}, parent)
	root.Activated:Connect(function()
		setOpen(false)
	end)
	local panel = make("TextButton", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.03,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
	}, root)
	corner(panel, 10)
	make("UIStroke", { Color = NEON, Thickness = 1, Transparency = 0.55 }, panel)
	panelScale = make("UIScale", {}, panel)

	text(panel, "TESTER TOOLS", 24, WHITE, Enum.Font.GothamBlack, {
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(400, 28),
	})
	text(panel, "TEST RANGE  ·  B / D-pad up / TEST to close", 12, MUTED, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(24, 44),
		Size = UDim2.fromOffset(500, 16),
	})
	local close = button(panel, "X", NEON, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(36, 36),
	})
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- Tabs down the left, pages on the right.
	local tabs = make("Frame", {
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(0, 150, 1, -92),
		BackgroundTransparency = 1,
	}, panel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, tabs)
	local content = make("Frame", {
		Position = UDim2.fromOffset(182, 76),
		Size = UDim2.new(1, -198, 1, -92),
		BackgroundTransparency = 1,
	}, panel)

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function showPage(name: string)
		for n, page in pages do
			page.Visible = n == name
		end
		for n, b in tabButtons do
			b.TextColor3 = if n == name then NEON else WHITE
			local s = b:FindFirstChildOfClass("UIStroke")
			if s then
				s.Thickness = if n == name then 2 else 1
			end
		end
	end
	local defs: { { string } } = {
		{ "Loadout", "LOADOUT" },
		{ "Range", "RANGE" },
		{ "Settings", "SETTINGS" },
		{ "Controls", "CONTROLS" },
	}
	for i, def in defs do
		local name = def[1]
		local b = button(
			tabs,
			def[2],
			NEON,
			{ Name = "Tab_" .. name, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = i }
		)
		tabButtons[name] = b
		pages[name] = pageFrame(content, name)
		b.Activated:Connect(function()
			showPage(name)
		end)
		if i == 1 then
			firstSelectable = b
		end
	end
	buildLoadoutPage(pages.Loadout)
	buildRangePage(pages.Range)
	buildSettingsPage(pages.Settings)
	buildControlsPage(pages.Controls)
	showPage("Loadout")
	backdrop = root
end

-- Stats panel ---------------------------------------------------------------------------

local STAT_ORDER = { "Dps", "Damage", "Ttk", "Accuracy", "Headshots", "Kills", "LastHit" }
local STAT_LABELS: { [string]: string } = {
	Dps = "DPS",
	Damage = "DAMAGE",
	Ttk = "LAST TTK",
	Accuracy = "ACCURACY",
	Headshots = "HEADSHOTS",
	Kills = "KILLS",
	LastHit = "LAST HIT",
}

local function buildStats(parent: ScreenGui)
	local panel = make("Frame", {
		Name = "RangeStats",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.42, 0),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
	}, parent)
	corner(panel, 8)
	make("UIStroke", { Color = NEON, Thickness = 1, Transparency = 0.7 }, panel)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	}, panel)
	make(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) },
		panel
	)
	-- Small screens: shrink it.
	local scale = make("UIScale", {}, panel)
	local function rescale()
		local cam = Workspace.CurrentCamera
		local view = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
		scale.Scale = math.clamp(view.Y / 900, 0.7, 1)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	text(
		panel,
		"RANGE STATS",
		12,
		NEON,
		Enum.Font.GothamBlack,
		{ Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0 }
	)
	for i, key in STAT_ORDER do
		local line = make("Frame", {
			Size = UDim2.new(1, 0, 0, if key == "Dps" then 24 else 18),
			BackgroundTransparency = 1,
			LayoutOrder = i * 2,
		}, panel)
		text(line, STAT_LABELS[key], 11, MUTED, FONT, { Size = UDim2.new(0.38, 0, 1, 0) })
		local value =
			text(line, "—", if key == "Dps" then 20 else 14, WHITE, Enum.Font.GothamBlack, {
				Position = UDim2.fromScale(0.38, 0),
				Size = UDim2.new(0.62, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		statRows[key] = { value = value }
		if key == "Dps" then
			local bar = make("Frame", {
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundColor3 = Color3.fromHex("2B3147"),
				BorderSizePixel = 0,
				LayoutOrder = i * 2 + 1,
			}, panel)
			corner(bar, 2)
			dpsFill = make("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = NEON,
				BorderSizePixel = 0,
			}, bar)
			corner(dpsFill :: Frame, 2)
		end
	end
	text(panel, "Measured by the server", 10, MUTED, Enum.Font.Gotham, {
		Size = UDim2.new(1, 0, 0, 12),
		LayoutOrder = 100,
	})
	statsPanel = panel
end

local function weaponName(id: string?): string
	local config = id and Weapons.get(id)
	return if config then config.displayName elseif id then id else ""
end

local function onStats(s: Types.TesterStats)
	if typeof(s) ~= "table" then
		return
	end
	local function set(key: string, value: string)
		local r = statRows[key]
		if r then
			r.value.Text = value
		end
	end
	set(
		"Dps",
		string.format("%.0f  <font size='11' color='#8A93AD'>peak %.0f</font>", s.dps, s.peakDps)
	)
	set("Damage", string.format("%.0f", s.damage))
	if s.lastTtk and s.lastTtkShots then
		set(
			"Ttk",
			string.format(
				"%.2f s  <font size='11' color='#8A93AD'>%d shot%s · %s</font>",
				s.lastTtk,
				s.lastTtkShots,
				if s.lastTtkShots == 1 then "" else "s",
				weaponName(s.lastTtkWeapon)
			)
		)
	else
		set("Ttk", "—")
	end
	local accuracy = if s.shots > 0 then math.min(s.hits / s.shots, 1) * 100 else 0
	set(
		"Accuracy",
		string.format(
			"%.0f%%  <font size='11' color='#8A93AD'>%d / %d</font>",
			accuracy,
			s.hits,
			s.shots
		)
	)
	set("Headshots", tostring(s.headshots))
	set("Kills", tostring(s.kills))
	local hit = s.lastHit
	if hit then
		local zoneColor = if hit.zone == "Head"
			then "#FFC83D"
			elseif hit.zone == "Legs" then "#AEB6CC"
			else "#FFFFFF"
		set(
			"LastHit",
			string.format(
				"<font color='%s'>%.0f %s</font>  <font size='11' color='#8A93AD'>@ %.0f studs</font>",
				zoneColor,
				hit.damage,
				string.upper(hit.zone),
				hit.distance
			)
		)
	end
	local fill = dpsFill
	if fill then
		local fraction = if s.peakDps > 0 then math.clamp(s.dps / s.peakDps, 0, 1) else 0
		TweenService:Create(fill, FAST, { Size = UDim2.fromScale(fraction, 1) }):Play()
		fill.BackgroundColor3 = if fraction > 0.85 then GOLD else NEON
	end
end

-- Top-centre pill: a button on touch, a key hint otherwise.
local function buildHint(parent: ScreenGui)
	local b = make("TextButton", {
		Name = "TestButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		AutoButtonColor = true,
		Font = FONT,
		TextSize = 14,
		TextColor3 = WHITE,
		Selectable = false,
	}, parent)
	corner(b, 16)
	make("UIStroke", {
		Color = NEON,
		Thickness = 1,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, b)
	b.Activated:Connect(toggle)
	local function relabel()
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			b.Text = "TEST TOOLS"
		elseif string.find(last.Name, "Gamepad") then
			b.Text = "<font color='#00E5FF'>D-PAD UP</font>  TESTER TOOLS"
		else
			b.Text = "<font color='#00E5FF'>B</font>  TESTER TOOLS"
		end
	end
	b.RichText = true
	relabel()
	UserInputService.LastInputTypeChanged:Connect(relabel)
end

-- Lifecycle -----------------------------------------------------------------------------

local function onWeaponState(state: Types.WeaponState)
	if typeof(state) ~= "table" or typeof(state.slots) ~= "table" then
		return
	end
	for _, slot in SLOTS do
		local s = state.slots[slot]
		if typeof(s) == "table" and typeof(s.id) == "string" then
			loadout[slot] = s.id
		end
	end
	refreshLoadout()
end

local function waitForTestMode(): boolean
	local deadline = os.clock() + 15
	while Workspace:GetAttribute(TestMode.ATTRIBUTE) == nil and os.clock() < deadline do
		task.wait(0.25)
	end
	return TestMode.isOn()
end

function TesterController.start()
	if not waitForTestMode() then
		return
	end
	local screen = make("ScreenGui", {
		Name = "TesterTools",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))
	buildStats(screen)
	buildHint(screen)
	buildMenu(screen)

	Net.event("WeaponState").OnClientEvent:Connect(onWeaponState)
	Net.event("TesterStats").OnClientEvent:Connect(onStats)
	InputController.onPressed("TesterMenu", toggle)
	UserInputService.InputBegan:Connect(function(input)
		if menuOpen and input.KeyCode == Enum.KeyCode.ButtonB then
			setOpen(false)
		end
	end)
	-- Keep the menu sized to the window.
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if menuOpen and panelScale then
				panelScale.Scale = fitScale()
			end
		end)
	end
end

return TesterController
