--!strict
-- Feeds the Mod UI (Mods.md → Controls) from ModController each frame. The
-- screens themselves are Studio-built: the bottom HUD's Mod cells on desktop
-- (Util/BottomHud), the touch screen's Mod buttons and alt button on touch
-- (Util/TouchHud), and the held hint ("LMB Throw · RMB Lob · E Cancel") on the
-- status tray (Util/StatusTray). Also plays the ready sound when a Mod comes
-- back. A charged Mod (Recon) still shows a code-built charge meter under the
-- crosshair (no Studio screen yet): power fill with ticks and the picked
-- bounces. GUI properties are only written when they change.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Shared.Config.Mods)

local BottomHud = require(script.Parent.Parent.Util.BottomHud)
local Watched = require(script.Parent.Parent.Util.Watched)
local Charges = require(ReplicatedStorage.Shared.Mods.Charges)
local Mods = require(ReplicatedStorage.Shared.Mods)
local StatusTray = require(script.Parent.Parent.Util.StatusTray)
local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local TouchHud = require(script.Parent.Parent.Util.TouchHud)
local ModController = require(script.Parent.ModController)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Ui = require(script.Parent.Parent.Util.Ui)

local ModHudController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local MUTED = Color3.fromHex("CCCCCF")
local BACK = Theme.COLORS.panel
local CYAN = Config.COLORS.ally
local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)

-- Per-slot state: the change-detection keys and the touch Mod button.
type SlotState = {
	wasCooling: boolean, -- for the ready sound when a charge comes back
	activeTotal: number, -- effect running (a zone, a heal): its full length
	activeUntil: number,
	deniedAt: number,
	-- Touch Mod button (nil off touch).
	button: GuiButton?,
	buttonText: TextLabel?,
	shownTouch: string,
}

-- The charge meter (Recon).
type Meter = {
	group: CanvasGroup,
	fill: Frame,
	gradient: UIGradient,
	percent: TextLabel,
	pips: { Frame },
	shown: number, -- the fill drawn (eased toward the charge)
	alpha: number, -- group fade 0 (shown) .. 1
	bounces: number, -- the count last shown, and when it changed (the pips pop)
	popAt: number,
	fullAt: number, -- when the charge reached full (one flash, then held)
}
local meter: Meter? = nil
local METER_WIDTH = 240
local METER_MAX_PIPS = 3
local altButton: GuiButton? = nil
local slots: { SlotState } = {}
local started = false

local make = Ui.make

local function text(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	local label = make("TextLabel", props, parent)
	make("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.55 }, label)
	return label
end

-- Charge meter: under the crosshair, faded in while a charged Mod is up.
local function buildMeter()
	local screen = make("ScreenGui", {
		Name = "ChargeMeter",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
	}, player:WaitForChild("PlayerGui"))
	local group = make("CanvasGroup", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 58),
		Size = UDim2.fromOffset(METER_WIDTH + 80, 58),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
	}, screen)
	text({
		Name = "Label",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 40, 0, 14),
		Size = UDim2.fromOffset(100, 14),
		FontFace = HEAVY,
		TextSize = 12,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "POWER",
	}, group)
	local percent = text({
		Name = "Percent",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0, 40 + METER_WIDTH, 0, 14),
		Size = UDim2.fromOffset(80, 14),
		FontFace = HEAVY,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0%",
	}, group)
	local track = make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(40, 18),
		Size = UDim2.fromOffset(METER_WIDTH, 8),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, group)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
	make("UIStroke", { Color = WHITE, Thickness = 1, Transparency = 0.55 }, track)
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
	local gradient = make("UIGradient", {
		Color = ColorSequence.new(CYAN:Lerp(BLACK, 0.25), CYAN:Lerp(WHITE, 0.35)),
	}, fill)
	for _, at in { 0.25, 0.5, 0.75 } do
		make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(at, 0, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, track)
	end
	text({
		Name = "BouncesLabel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(40, 34),
		Size = UDim2.fromOffset(80, 14),
		FontFace = HEAVY,
		TextSize = 12,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "BOUNCES",
	}, group)
	local pips = {}
	for i = 1, METER_MAX_PIPS do
		local pip = make("Frame", {
			Name = "Bounce" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(40 + 80 + (i - 1) * 20, 41),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = CYAN,
			BorderSizePixel = 0,
		}, group)
		make("UIStroke", { Color = WHITE, Thickness = 1, Transparency = 0.4 }, pip)
		pips[i] = pip
	end
	meter = {
		group = group,
		fill = fill,
		gradient = gradient,
		percent = percent,
		pips = pips,
		shown = 0,
		alpha = 1,
		bounces = 0,
		popAt = -math.huge,
		fullAt = -math.huge,
	}
end

local function build()
	buildMeter()
	for i = 1, Config.SLOTS do
		slots[i] = {
			wasCooling = false,
			activeTotal = 0,
			activeUntil = 0,
			deniedAt = -math.huge,
			button = nil,
			buttonText = nil,
			shownTouch = "",
		}
	end

	-- Touch: the Studio-built Mod buttons on the touch screen (UI.Match.Touch,
	-- Util/TouchHud). TouchController links them to the Mod1/2/3 actions; here
	-- they get their icon, cooldown seconds and held state.
	for i = 1, Config.SLOTS do
		local b = TouchHud.find("Mod" .. i .. "Button")
		local label = b and b:FindFirstChild("Label", true)
		if b and b:IsA("GuiButton") and label and label:IsA("TextLabel") then
			slots[i].button = b
			slots[i].buttonText = label
		end
	end
	local alt = TouchHud.find("ModAltButton")
	if alt and alt:IsA("GuiButton") then
		alt.Visible = false
		alt.Activated:Connect(function()
			ModController.useAlt()
		end)
		altButton = alt
	end
end

local function writeSlot(ui: SlotState, view: ModController.SlotView, slot: number, now: number)
	local id = view.id
	local key = ModController.keyLabel(slot)

	-- Out of charges: a recharging Mod sweeps and counts down; a per-round
	-- one just stays dimmed until the next refill.
	local cooling = id ~= nil
		and view.charges < 1
		and StateValues.get(player, "ModUnlimitedCharges") ~= true
	local recharging = cooling and view.cooldown > 0
	local share = if recharging then view.remaining / view.cooldown else 0
	local secs = ""
	if recharging then
		secs = if view.remaining >= 1
			then tostring(math.ceil(view.remaining))
			else string.format("%.1f", view.remaining)
	end
	if ui.wasCooling and not cooling and id ~= nil then
		ModAudio.play(ModAudio.SOUNDS.Ready)
	end
	ui.wasCooling = cooling

	local private = ModController.privateState()
	local activeUntil = private and StateValues.get(private, "Mod" .. slot .. "ActiveUntil")
	local serverNow = workspace:GetServerTimeNow()
	if typeof(activeUntil) == "number" and activeUntil ~= ui.activeUntil then
		ui.activeUntil = activeUntil
		ui.activeTotal = math.max(activeUntil - serverNow, 0.01)
	end
	local activeLeft = if typeof(activeUntil) == "number" then activeUntil - serverNow else 0

	-- The Studio-built bottom HUD (desktop) shows the slot; touch uses the
	-- touch screen's Mod buttons below.
	if not TouchHud.active() and BottomHud.active() then
		BottomHud.setMod(slot, {
			id = id,
			icon = if view.def then view.def.icon or "" else "",
			role = if view.def then view.def.role else nil,
			level = view.level,
			key = key,
			cooling = cooling,
			share = share,
			seconds = secs,
			charges = view.charges,
			max = view.max,
			held = view.held,
			denied = now - ui.deniedAt,
			active = if activeLeft > 0 then activeLeft / ui.activeTotal else 0,
		})
	end

	-- Touch button: written only when something it shows changed.
	local button, label = ui.button, ui.buttonText
	local touchKey =
		string.format("%s|%s|%s|%s", tostring(id), secs, tostring(cooling), tostring(view.held))
	if button and label and touchKey ~= ui.shownTouch then
		ui.shownTouch = touchKey
		button.Visible = id ~= nil
		local icon = button:FindFirstChild("Icon", true)
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

-- The charge meter: fades in with a charged Mod up, the fill eases to the
-- charge, flashes white at full; the pips show the picked bounces.
local function updateMeter(dt: number, now: number)
	local m = meter
	if not m then
		return
	end
	local state = ModController.chargeState()
	m.alpha = math.clamp(m.alpha + (if state then -dt / 0.12 else dt / 0.2), 0, 1)
	m.group.GroupTransparency = m.alpha
	m.group.Visible = m.alpha < 1
	if not state then
		return
	end
	local k = 1 - math.exp(-30 * dt)
	m.shown += (state.charge - m.shown) * k
	if not state.charging then
		m.shown = 0
	end
	m.fill.Size = UDim2.fromScale(m.shown, 1)
	local full = state.charge >= 1
	-- At full: one plain-white flash (the gradient off), then held cyan.
	if full and m.fullAt == -math.huge then
		m.fullAt = now
	elseif not full then
		m.fullAt = -math.huge
	end
	m.gradient.Enabled = not (full and now - m.fullAt < 0.12)
	m.percent.Text = if full then "MAX" else string.format("%d%%", math.floor(state.charge * 100))
	m.percent.TextColor3 = if full then CYAN else WHITE
	-- A new bounce count: the pips pop (Quint out, no overshoot).
	if state.bounces ~= m.bounces then
		m.bounces = state.bounces
		m.popAt = now
	end
	local pop = 1 - math.clamp((now - m.popAt) / 0.18, 0, 1)
	local size = 9 + 5 * pop ^ 5
	for i, pip in m.pips do
		pip.Visible = i <= state.maxBounces
		local on = i <= state.bounces
		pip.BackgroundColor3 = if on then CYAN else BACK
		pip.BackgroundTransparency = if on then 0 else 0.3
		pip.Size = UDim2.fromOffset(size, size)
	end
end

-- While you spectate: the watched fighter's slot, from their public kit
-- (`Mod<n>Id` / `Level`, `ModHeld`) and the charges the server sent only to
-- their spectators (Util/Watched, SpectateFeed "Mods").
local function subjectView(slot: number): ModController.SlotView?
	local holder = Watched.get()
	if not holder then
		return nil
	end
	local row = Watched.modRow(slot)
	local p = "Mod" .. slot
	local idValue = if row then row.id else StateValues.get(holder, p .. "Id")
	local levelValue = if row then row.level else StateValues.get(holder, p .. "Level")
	local level = if typeof(levelValue) == "string" then levelValue else "L1"
	local view: ModController.SlotView = {
		id = nil,
		level = level,
		def = nil,
		stats = nil,
		charges = 0,
		max = 0,
		remaining = 0,
		cooldown = 0,
		held = false,
		built = false,
	}
	if typeof(idValue) ~= "string" then
		return view
	end
	local def = Mods.def(idValue)
	local stats = Mods.stats(idValue, level)
	if not def or not stats then
		return view
	end
	view.id, view.def, view.stats = idValue, def, stats
	view.max, view.cooldown, view.built = stats.charges, stats.cooldown, Mods.isBuilt(idValue)
	view.held = StateValues.get(holder, "ModHeld") == slot
	local charges = if row then row.charges else stats.charges
	local rechargeAt = if row then row.rechargeAt else nil
	if rechargeAt then
		local now = workspace:GetServerTimeNow()
		charges, rechargeAt =
			Charges.settle(charges, rechargeAt, stats.charges, stats.cooldown, now)
		view.remaining = Charges.remaining(charges, rechargeAt, stats.charges, stats.cooldown, now)
	end
	view.charges = charges
	return view
end

local function update(dt: number)
	if not started then
		return
	end
	local now = os.clock()
	updateMeter(dt, now)
	local any = false
	local watching = BottomHud.isSpectating()
	for slot, ui in slots do
		local view = (if watching then subjectView(slot) else nil) or ModController.slot(slot)
		any = any or view.id ~= nil
		writeSlot(ui, view, slot, now)
	end
	-- Yours, or the watched fighter's while you spectate.
	BottomHud.setModsVisible(any)

	-- The held hint sits on its plate over the status tray (no-op until bound).
	local message, warning = ModController.hint()
	StatusTray.setHint(message or "", warning == true)

	local alt = altButton
	if alt then
		local held = ModController.heldSlot()
		local view = if held ~= 0 then ModController.slot(held) else nil
		local altHint = view and view.def and view.def.hint.alt
		alt.Visible = altHint ~= nil
		local label = alt:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") and altHint then
			label.Text = string.upper(altHint)
		end
	end
end

function ModHudController.start()
	build()
	started = true
	StatusTray.start()
	-- A denied use: the bottom HUD's Mod cell flashes red and shakes.
	ModController.onDeny(function(slot: number, _reason: string)
		local ui = slots[slot]
		if ui then
			ui.deniedAt = os.clock()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return ModHudController
