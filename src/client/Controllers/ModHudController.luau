--!strict
-- The Mod HUD (Mods.md → Controls): 3 slots bottom-centre with their key, the
-- icon, a radial cooldown sweep with the seconds left, charges, a highlight
-- while held, a pulse when one comes back, and the held hint above them
-- ("LMB Throw · RMB Lob · E Cancel"). Touch adds an arc of 3 Mod buttons by
-- Fire and a context button (lob / heal self) while a Mod is held.
-- Everything is read from ModController each frame; GUI properties are only
-- written when they change.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Mods)

local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local ModController = require(script.Parent.ModController)

local ModHudController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local MUTED = Color3.fromHex("C9CCD1")
local AMBER = Color3.fromHex("F2C94C")
local RED = Color3.fromHex("EB5757")
local BACK = Color3.fromHex("16181B")
local CYAN = Config.COLORS.ally
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local SLOT_SIZE = 62
local SLOT_GAP = 16
local MAX_PIPS = 3
local PULSE = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RING = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Sweep = { left: UIGradient, right: UIGradient, root: Frame, fill: Frame }

type SlotUi = {
	root: Frame,
	scale: UIScale,
	face: CanvasGroup,
	glyph: TextLabel,
	icon: ImageLabel,
	sweep: Sweep,
	seconds: TextLabel,
	border: UIStroke,
	key: TextLabel,
	name: TextLabel,
	pips: { Frame },
	ring: Frame,
	ringStroke: UIStroke,
	-- Last written, to skip unchanged writes.
	shownId: string?,
	shownKey: string,
	shownSeconds: string,
	shownCharges: number,
	shownMax: number,
	wasCooling: boolean,
	activeFill: Frame, -- effect running (Overclock, a pad, a zone): drains
	activeBack: Frame,
	activeTotal: number,
	activeUntil: number,
	held: boolean,
	deniedAt: number,
	-- Touch arc button (nil off touch).
	button: TextButton?,
	buttonText: TextLabel?,
	shownTouch: string,
}

local bar: Frame? = nil
local hint: TextLabel? = nil
local slowedLabel: TextLabel? = nil
local altButton: TextButton? = nil
local slots: { SlotUi } = {}
local shownHint = ""

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

local function text(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	local label = make("TextLabel", props, parent)
	make("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.55 }, label)
	return label
end

-- Radial sweep: a dark wedge of `share` x 360 degrees from 12 o'clock going
-- counter-clockwise, so the bright part grows clockwise as it recharges.
-- Built from two clipped halves, each a square with a hard-edged gradient.
local function buildSweep(parent: Instance): Sweep
	local root = make("Frame", {
		Name = "Sweep",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, parent)
	-- The recharged part reads lighter: a pale fill under the dark wedge.
	local fill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CYAN,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, root)
	local function half(isLeft: boolean): UIGradient
		local clip = make("Frame", {
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(if isLeft then 0 else 0.5, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 3,
		}, root)
		local disc = make("Frame", {
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(if isLeft then 0 else -1, 0),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, clip)
		-- Left half: the opaque side starts on the right (hidden); right half:
		-- it starts on the left. Rotating counter-clockwise reveals a wedge.
		local a, b = if isLeft then 1 else 0, if isLeft then 0 else 1
		return make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, a),
				NumberSequenceKeypoint.new(0.499, a),
				NumberSequenceKeypoint.new(0.501, b),
				NumberSequenceKeypoint.new(1, b),
			}),
		}, disc)
	end
	return { left = half(true), right = half(false), root = root, fill = fill }
end

local function setSweep(s: Sweep, share: number)
	share = math.clamp(share, 0, 1)
	s.root.Visible = share > 0.001
	local angle = share * 360
	s.left.Rotation = -math.min(angle, 180)
	-- At rotation 0 each half's opaque side is out of its clip (shows nothing).
	s.right.Rotation = -math.max(angle - 180, 0)
end

local function buildSlot(index: number, parent: Instance): SlotUi
	local root = make("Frame", {
		Name = "Slot" .. index,
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE + 26),
		BackgroundTransparency = 1,
		LayoutOrder = index,
	}, parent)
	local scale = make("UIScale", { Scale = 1 }, root)
	local face = make("CanvasGroup", {
		Name = "Face",
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, face)
	-- The shading is its own frame: a UIGradient on a CanvasGroup would tint
	-- everything in it.
	local shade = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, face)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromHex("2E333B"), Color3.fromHex("121417")),
	}, shade)
	local glyph = text({
		Size = UDim2.fromScale(1, 1),
		FontFace = HEAVY,
		TextSize = 34,
		Text = "",
		ZIndex = 2,
	}, face)
	local icon = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
	}, face)
	local sweep = buildSweep(face)
	local seconds = text({
		Size = UDim2.fromScale(1, 1),
		FontFace = HEAVY,
		TextSize = 22,
		Text = "",
		ZIndex = 4,
	}, face)
	-- Border (outside the CanvasGroup so the stroke isn't clipped).
	local frame = make("Frame", {
		Name = "Border",
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
	local border = make("UIStroke", {
		Color = WHITE,
		Thickness = 1.5,
		Transparency = 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	-- Ready ring: grows out and fades when a charge comes back.
	local ring = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(SLOT_SIZE / 2, SLOT_SIZE / 2),
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, ring)
	local ringStroke = make("UIStroke", {
		Color = CYAN,
		Thickness = 2,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, ring)
	-- Key chip, top-left corner.
	local chip = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(22, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromHex("E8EAED"),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, chip)
	local key = make("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		TextSize = 14,
		TextColor3 = BACK,
		Text = "",
		ZIndex = 7,
	}, chip)
	-- Charges (pips) and the name under the slot.
	local pipRow = make("Frame", {
		Position = UDim2.fromOffset(0, SLOT_SIZE + 5),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundTransparency = 1,
	}, root)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
	}, pipRow)
	local pips = {}
	for i = 1, MAX_PIPS do
		local pip = make("Frame", {
			Size = UDim2.fromOffset(12, 4),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			LayoutOrder = i,
		}, pipRow)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, pip)
		pips[i] = pip
	end
	-- Effect running: a thin bar above the slot that drains.
	local activeBack = make("Frame", {
		Position = UDim2.fromOffset(6, -8),
		Size = UDim2.new(1, -12, 0, 3),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, activeBack)
	local activeFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
	}, activeBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, activeFill)
	local name = text({
		Position = UDim2.fromOffset(-20, SLOT_SIZE + 10),
		Size = UDim2.new(1, 40, 0, 14),
		FontFace = BOLD,
		TextSize = 12,
		TextColor3 = MUTED,
		Text = "",
	}, root)
	return {
		root = root,
		scale = scale,
		face = face,
		glyph = glyph,
		icon = icon,
		sweep = sweep,
		seconds = seconds,
		border = border,
		key = key,
		name = name,
		pips = pips,
		ring = ring,
		ringStroke = ringStroke,
		shownId = "?",
		shownKey = "",
		shownSeconds = "",
		shownCharges = -1,
		shownMax = -1,
		wasCooling = false,
		activeFill = activeFill,
		activeBack = activeBack,
		activeTotal = 0,
		activeUntil = 0,
		held = false,
		deniedAt = -math.huge,
		button = nil,
		buttonText = nil,
		shownTouch = "",
	}
end

local function pulse(ui: SlotUi)
	ModAudio.play(ModAudio.SOUNDS.Ready)
	ui.scale.Scale = 1.14
	TweenService:Create(ui.scale, PULSE, { Scale = if ui.held then 1.08 else 1 }):Play()
	ui.ring.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	ui.ringStroke.Transparency = 0
	TweenService:Create(ui.ring, RING, { Size = UDim2.fromOffset(SLOT_SIZE + 26, SLOT_SIZE + 26) })
		:Play()
	TweenService:Create(ui.ringStroke, RING, { Transparency = 1 }):Play()
end

local function build(): ScreenGui
	local screen = make("ScreenGui", {
		Name = "ModHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
	}, player:WaitForChild("PlayerGui"))
	local width = SLOT_SIZE * Config.SLOTS + SLOT_GAP * (Config.SLOTS - 1)
	local row = make("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.fromOffset(width, SLOT_SIZE + 26),
		BackgroundTransparency = 1,
	}, screen)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, SLOT_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	bar = row
	for i = 1, Config.SLOTS do
		slots[i] = buildSlot(i, row)
	end
	hint = text({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(SLOT_SIZE + 66)),
		Size = UDim2.fromOffset(640, 22),
		FontFace = MEDIUM,
		TextSize = 17,
		Text = "",
		Visible = false,
	}, screen)
	-- A Lag Field is slowing you.
	slowedLabel = text({
		Name = "Slowed",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(SLOT_SIZE + 92)),
		Size = UDim2.fromOffset(200, 22),
		FontFace = HEAVY,
		TextSize = 18,
		TextColor3 = Config.COLORS.enemy,
		Text = "SLOWED",
		Visible = false,
	}, screen)

	local layer = HudController.touchLayer()
	if layer then
		local function touchButton(name: string, pos: UDim2, size: number): (TextButton, TextLabel)
			local b = make("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = pos,
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = BACK,
				BackgroundTransparency = 0.35,
				Text = "",
				AutoButtonColor = true,
			}, layer)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
			make("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.6 }, b)
			make("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.62, 0.62),
				BackgroundTransparency = 1,
				Image = "",
			}, b)
			local label = text({
				Size = UDim2.fromScale(1, 1),
				FontFace = HEAVY,
				TextSize = 18,
				Text = "",
				ZIndex = 2,
			}, b)
			return b, label
		end
		-- An arc above and left of Fire (HudController puts Fire at 1,-110 / 1,-210).
		local arc = {
			UDim2.new(1, -300, 1, -300),
			UDim2.new(1, -250, 1, -362),
			UDim2.new(1, -180, 1, -398),
		}
		for i = 1, Config.SLOTS do
			local b, label = touchButton("Mod" .. i .. "Button", arc[i], 58)
			slots[i].button = b
			slots[i].buttonText = label
		end
		local alt, altLabel = touchButton("ModAltButton", UDim2.new(1, -140, 1, -300), 56)
		altLabel.TextSize = 13
		altLabel.Text = "ALT"
		alt.Visible = false
		alt.Activated:Connect(function()
			ModController.useAlt()
		end)
		altButton = alt
		-- The Mod buttons drive the Mod1/2/3 input actions (Config/Input touch).
		InputController.bindTouchButtons(layer)
	end
	return screen
end

local function writeSlot(ui: SlotUi, view: ModController.SlotView, slot: number, now: number)
	local id = view.id
	if id ~= ui.shownId then
		ui.shownId = id
		local def = view.def
		ui.root.Visible = true
		ui.glyph.Text = if def then def.glyph else ""
		ui.name.Text = if def then string.upper(def.name) else ""
		local iconId = def and def.icon or ""
		ui.icon.Image = iconId
		ui.icon.Visible = iconId ~= ""
		ui.glyph.Visible = iconId == ""
		ui.face.GroupTransparency = if def then 0 else 0.55
		ui.shownCharges = -1
		ui.shownMax = -1
	end
	local key = ModController.keyLabel(slot)
	if key ~= ui.shownKey then
		ui.shownKey = key
		ui.key.Text = key
	end

	-- Out of charges: a recharging Mod sweeps and counts down; a per-round
	-- one just stays dimmed until the next refill.
	local cooling = id ~= nil
		and view.charges < 1
		and player:GetAttribute("ModUnlimitedCharges") ~= true
	local recharging = cooling and view.cooldown > 0
	local share = if recharging then view.remaining / view.cooldown else 0
	setSweep(ui.sweep, share)
	local secs = ""
	if recharging then
		secs = if view.remaining >= 1
			then tostring(math.ceil(view.remaining))
			else string.format("%.1f", view.remaining)
	end
	if secs ~= ui.shownSeconds then
		ui.shownSeconds = secs
		ui.seconds.Text = secs
	end
	ui.glyph.TextTransparency = if cooling then 0.55 else 0
	ui.icon.ImageTransparency = if cooling then 0.55 else 0
	if ui.wasCooling and not cooling and id ~= nil then
		pulse(ui)
	end
	ui.wasCooling = cooling

	local private = ModController.privateState()
	local activeUntil = private and private:GetAttribute("Mod" .. slot .. "ActiveUntil")
	local serverNow = workspace:GetServerTimeNow()
	if typeof(activeUntil) == "number" and activeUntil ~= ui.activeUntil then
		ui.activeUntil = activeUntil
		ui.activeTotal = math.max(activeUntil - serverNow, 0.01)
	end
	local activeLeft = if typeof(activeUntil) == "number" then activeUntil - serverNow else 0
	ui.activeBack.Visible = activeLeft > 0
	if activeLeft > 0 then
		ui.activeFill.Size = UDim2.fromScale(math.clamp(activeLeft / ui.activeTotal, 0, 1), 1)
	end

	if view.max ~= ui.shownMax or view.charges ~= ui.shownCharges then
		ui.shownMax = view.max
		ui.shownCharges = view.charges
		for i, pip in ui.pips do
			pip.Visible = view.max > 1 and i <= view.max
			pip.BackgroundTransparency = if i <= view.charges then 0 else 0.7
		end
	end

	-- Held: cyan border, slightly bigger. Denied: a red flash and a shake.
	if view.held ~= ui.held then
		ui.held = view.held
		TweenService:Create(ui.scale, PULSE, { Scale = if view.held then 1.08 else 1 }):Play()
	end
	local sinceDeny = now - ui.deniedAt
	if sinceDeny < 0.35 then
		ui.border.Color = RED
		ui.border.Transparency = 0
		ui.border.Thickness = 2
		ui.face.Position =
			UDim2.fromOffset(math.sin(sinceDeny * 60) * 4 * (1 - sinceDeny / 0.35), 0)
	elseif view.held then
		ui.border.Color = CYAN
		ui.border.Transparency = 0
		ui.border.Thickness = 2.5
		ui.face.Position = UDim2.fromOffset(0, 0)
	else
		ui.border.Color = WHITE
		ui.border.Transparency = if cooling or id == nil then 0.82 else 0.55
		ui.border.Thickness = 1.5
		ui.face.Position = UDim2.fromOffset(0, 0)
	end

	-- Touch button: written only when something it shows changed.
	local button, label = ui.button, ui.buttonText
	local touchKey =
		string.format("%s|%s|%s|%s", tostring(id), secs, tostring(cooling), tostring(view.held))
	if button and label and touchKey ~= ui.shownTouch then
		ui.shownTouch = touchKey
		button.Visible = id ~= nil
		local icon = button:FindFirstChild("Icon")
		local iconId = if view.def then view.def.icon else ""
		if icon and icon:IsA("ImageLabel") then
			icon.Image = iconId
			icon.ImageTransparency = if cooling then 0.7 else 0
		end
		local glyph = if view.def and iconId == "" then view.def.glyph else ""
		label.Text = if cooling then secs else glyph
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if view.held then CYAN else WHITE
			stroke.Transparency = if view.held then 0 else 0.6
		end
	end
end

local function update(_dt: number)
	if not bar then
		return
	end
	local now = os.clock()
	local any = false
	for slot, ui in slots do
		local view = ModController.slot(slot)
		any = any or view.id ~= nil
		writeSlot(ui, view, slot, now)
	end
	bar.Visible = any
	local slowed = slowedLabel
	if slowed then
		local mult = player:GetAttribute("ModSpeedMult")
		slowed.Visible = typeof(mult) == "number" and mult < 1
	end

	local h = hint
	if h then
		local message, warning = ModController.hint()
		local shown = message or ""
		if shown ~= shownHint then
			shownHint = shown
			h.Text = shown
			h.Visible = shown ~= ""
			h.TextColor3 = if warning then AMBER else WHITE
		end
	end
	local alt = altButton
	if alt then
		local held = ModController.heldSlot()
		local view = if held ~= 0 then ModController.slot(held) else nil
		local altHint = view and view.def and view.def.hint.alt
		alt.Visible = altHint ~= nil
		local label = alt:FindFirstChildOfClass("TextLabel")
		if label and altHint then
			label.Text = string.upper(altHint)
		end
	end
end

function ModHudController.start()
	build()
	ModController.onDeny(function(slot: number, _reason: string)
		local ui = slots[slot]
		if ui then
			ui.deniedAt = os.clock()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return ModHudController
