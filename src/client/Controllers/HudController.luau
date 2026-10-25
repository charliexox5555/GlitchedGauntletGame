--!strict
-- Combat HUD (Gunplay.md §5): dynamic crosshair, hit / headshot / kill
-- markers, stacking damage numbers, ammo + reload, health, low-HP vignette,
-- damage direction, sniper scope, kill feed, touch buttons and the Studio
-- dev weapon menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local InputController = require(script.Parent.InputController)

local HudController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFC83D")
local NEON = Color3.fromHex("00E5FF")
local RED = Color3.fromHex("FF3355")
local DARK = Color3.fromHex("1C2030")
local FONT = Enum.Font.GothamBold

type Refs = {
	gui: ScreenGui,
	crosshair: CanvasGroup,
	lines: { Frame },
	hitMarker: Frame,
	killMarker: Frame,
	damageLabel: TextLabel,
	ammo: TextLabel,
	weaponName: TextLabel,
	reloadBar: Frame,
	reloadFill: Frame,
	healthFill: Frame,
	healthText: TextLabel,
	vignette: Frame,
	indicator: Frame,
	scope: Frame,
	feed: Frame,
}

local refs: Refs? = nil
local spreadDegrees = 1
local shownGap = 6
local crosshairWanted = true
local crosshairAlpha = 1
local stackedDamage = 0
local stackedAt = 0

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

local function stroke(parent: Instance, thickness: number?)
	make(
		"UIStroke",
		{ Color = Color3.new(0, 0, 0), Thickness = thickness or 1, Transparency = 0.3 },
		parent
	)
end

local function centered(size: UDim2, parent: Instance): Frame
	return make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundTransparency = 1,
	}, parent)
end

-- An X made of four short rotated bars.
local function xMarker(parent: Instance, size: number, color: Color3): Frame
	local holder = centered(UDim2.fromOffset(size * 2, size * 2), parent)
	holder.Visible = false
	for i = 0, 3 do
		local angle = 45 + 90 * i
		local rad = math.rad(angle)
		local dist = size * 0.55
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(rad) * dist, 0.5, math.sin(rad) * dist),
			Size = UDim2.fromOffset(size * 0.55, 3),
			Rotation = angle,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, holder)
		stroke(bar)
	end
	return holder
end

local function build(): Refs
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local gui = make("ScreenGui", {
		Name = "CombatHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- Low-HP vignette: four red edges that fade in as health drops.
	local vignette = make(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false },
		gui
	)
	for _, edge in
		{
			{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), -90 },
			{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180 },
		}
	do
		local f = make("Frame", {
			Size = edge[1],
			Position = edge[2],
			BackgroundColor3 = RED,
			BorderSizePixel = 0,
		}, vignette)
		make("UIGradient", {
			Rotation = edge[3],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, f)
	end

	-- Scope: a clear circle with everything around it blacked out.
	local scope = make(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false },
		gui
	)
	local hole = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
	}, scope)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, hole)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, hole)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1500 }, hole)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	}, hole)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	}, hole)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.fromHex("FF3DCB"),
		BorderSizePixel = 0,
	}, hole)

	-- Crosshair (CanvasGroup so it fades as one): a centre dot plus four short
	-- lines that open with spread. Thin black outline keeps it readable on
	-- bright and dark backgrounds.
	local crosshair = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(160, 160),
		BackgroundTransparency = 1,
	}, gui)
	local lines = {}
	for i = 1, 4 do
		local horizontal = i <= 2
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = if horizontal then UDim2.fromOffset(7, 2) else UDim2.fromOffset(2, 7),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, crosshair)
		make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.45 }, line)
		lines[i] = line
	end
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, crosshair)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.45 }, dot)

	local hitMarker = xMarker(gui, 16, WHITE)
	local killMarker = xMarker(gui, 24, NEON)

	local damageLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 26, 0.5, -18),
		Size = UDim2.fromOffset(120, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
		Text = "",
	}, gui)
	stroke(damageLabel, 2)

	-- Ammo (bottom right).
	local ammoPanel = make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -32, 1, -28),
		Size = UDim2.fromOffset(240, 80),
		BackgroundTransparency = 1,
	}, gui)
	local weaponName = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextColor3 = NEON,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, ammoPanel)
	stroke(weaponName)
	local ammo = make("TextLabel", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 40,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, ammoPanel)
	stroke(ammo, 2)
	local reloadBar = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 68),
		Size = UDim2.fromOffset(160, 5),
		BackgroundColor3 = DARK,
		BorderSizePixel = 0,
		Visible = false,
	}, ammoPanel)
	local reloadFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = NEON,
		BorderSizePixel = 0,
	}, reloadBar)

	-- Health (bottom left).
	local healthBar = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 32, 1, -36),
		Size = UDim2.fromOffset(260, 14),
		BackgroundColor3 = DARK,
		BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, healthBar)
	stroke(healthBar)
	local healthFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, healthBar)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, healthFill)
	local healthText = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -4),
		Size = UDim2.fromOffset(120, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 28,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "100",
	}, healthBar)
	stroke(healthText, 2)

	-- Damage direction indicator: a red bar orbiting the crosshair.
	local indicator = centered(UDim2.fromOffset(0, 0), gui)
	local wedge = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, -110),
		Size = UDim2.fromOffset(70, 6),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
	}, indicator)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, wedge)

	-- Kill feed (top right).
	local feed = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(360, 200),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, feed)

	-- Studio-only controls hint.
	if RunService:IsStudio() and Dev.WEAPON_PICKER then
		local hint = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(760, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = WHITE,
			TextTransparency = 0.25,
			Text = "DEV  P weapons  ·  T/Y next primary/secondary  ·  1 2 3 slots  ·  R reload  ·  RMB aim  ·  Shift sprint  ·  C slide/crouch  ·  V melee",
		}, gui)
		stroke(hint)
	end

	-- Touch buttons (names match Config/Input).
	if UserInputService.TouchEnabled then
		local function button(name: string, text: string, pos: UDim2, size: number)
			local b = make("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = pos,
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = DARK,
				BackgroundTransparency = 0.35,
				Font = FONT,
				TextSize = 14,
				TextColor3 = WHITE,
				Text = text,
				AutoButtonColor = true,
			}, gui)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
			make("UIStroke", { Color = NEON, Thickness = 2, Transparency = 0.2 }, b)
		end
		button("FireButton", "FIRE", UDim2.new(1, -110, 1, -210), 86)
		button("AimButton", "AIM", UDim2.new(1, -210, 1, -260), 64)
		button("ReloadButton", "R", UDim2.new(1, -60, 1, -310), 52)
		button("SlideButton", "SLIDE", UDim2.new(1, -200, 1, -150), 60)
		button("SwapButton", "SWAP", UDim2.new(1, -60, 1, -380), 52)
	end

	return {
		gui = gui,
		crosshair = crosshair,
		lines = lines,
		hitMarker = hitMarker,
		killMarker = killMarker,
		damageLabel = damageLabel,
		ammo = ammo,
		weaponName = weaponName,
		reloadBar = reloadBar,
		reloadFill = reloadFill,
		healthFill = healthFill,
		healthText = healthText,
		vignette = vignette,
		indicator = indicator,
		scope = scope,
		feed = feed,
	}
end

-- API ------------------------------------------------------------------------

-- `battery`: the magazine is a self-charging battery (Null), shown as a percentage.
function HudController.setWeapon(
	displayName: string,
	ammo: number,
	magSize: number,
	battery: boolean?
)
	local r = refs
	if not r then
		return
	end
	r.weaponName.Text = string.upper(displayName)
	HudController.setAmmo(ammo, magSize, battery)
end

function HudController.setAmmo(ammo: number, magSize: number, battery: boolean?)
	local r = refs
	if not r then
		return
	end
	if magSize <= 0 then
		r.ammo.Text = ""
		return
	end
	r.ammo.RichText = true
	if battery then
		r.ammo.Text = string.format(
			"%d<font size='22' transparency='0.4'>%%</font>",
			math.floor(ammo / magSize * 100)
		)
	else
		r.ammo.Text =
			string.format("%d <font size='22' transparency='0.4'>/ %d</font>", ammo, magSize)
	end
	r.ammo.TextColor3 = if ammo == 0 then RED elseif ammo <= magSize * 0.25 then GOLD else WHITE
end

-- `progress` 0..1 while reloading, nil when not.
function HudController.setReload(progress: number?)
	local r = refs
	if not r then
		return
	end
	r.reloadBar.Visible = progress ~= nil
	if progress then
		r.reloadFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	end
end

function HudController.setSpread(degrees: number)
	spreadDegrees = degrees
end

-- Fades rather than pops (ADS, scope, sprint).
function HudController.setCrosshairVisible(visible: boolean)
	crosshairWanted = visible
end

function HudController.setScope(visible: boolean)
	if refs then
		refs.scope.Visible = visible
	end
end

local function flash(marker: Frame, color: Color3?)
	marker.Visible = true
	for _, bar in marker:GetChildren() do
		if bar:IsA("Frame") then
			if color then
				bar.BackgroundColor3 = color
			end
			bar.BackgroundTransparency = 0
			TweenService
				:Create(bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				})
				:Play()
		end
	end
	marker.Size = UDim2.fromOffset(marker.Size.X.Offset * 1.25, marker.Size.Y.Offset * 1.25)
	local base = marker:GetAttribute("BaseSize") :: number?
	if not base then
		base = marker.Size.X.Offset / 1.25
		marker:SetAttribute("BaseSize", base)
	end
	TweenService:Create(marker, TweenInfo.new(0.12), { Size = UDim2.fromOffset(base, base) }):Play()
end

function HudController.hitMarker(headshot: boolean)
	if refs then
		flash(refs.hitMarker, if headshot then GOLD else WHITE)
	end
end

function HudController.killMarker()
	if refs then
		flash(refs.killMarker, NEON)
	end
end

-- Damage numbers stack while you keep hitting within a second.
function HudController.damageNumber(amount: number, headshot: boolean)
	local r = refs
	if not r then
		return
	end
	local now = os.clock()
	if now - stackedAt > 1 then
		stackedDamage = 0
	end
	stackedDamage += amount
	stackedAt = now
	local label = r.damageLabel
	label.Text = tostring(math.round(stackedDamage))
	label.TextColor3 = if headshot then GOLD else WHITE
	label.TextTransparency = 0
	label.TextSize = 30
	TweenService:Create(label, TweenInfo.new(0.15), { TextSize = 24 }):Play()
	task.delay(1, function()
		if os.clock() - stackedAt >= 0.99 then
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
end

function HudController.damageFrom(sourcePosition: Vector3)
	local r = refs
	local cam = Workspace.CurrentCamera
	if not r or not cam then
		return
	end
	local flat = (sourcePosition - cam.CFrame.Position) * Vector3.new(1, 0, 1)
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 or look.Magnitude < 0.1 then
		return
	end
	local angle = math.atan2(flat.Unit:Cross(look.Unit).Y, flat.Unit:Dot(look.Unit))
	r.indicator.Rotation = -math.deg(angle)
	local wedge = r.indicator:FindFirstChildWhichIsA("Frame")
	if wedge then
		wedge.BackgroundTransparency = 0.1
		TweenService:Create(wedge, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	end
end

function HudController.killFeed(text: string, highlight: boolean)
	local r = refs
	if not r then
		return
	end
	local entry = make("TextLabel", {
		Size = UDim2.fromOffset(360, 24),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.35,
		Font = FONT,
		TextSize = 16,
		TextColor3 = if highlight then NEON else WHITE,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = text .. "  ",
		LayoutOrder = -math.floor(os.clock() * 10),
	}, r.feed)
	task.delay(5, function()
		entry:Destroy()
	end)
end

-- Dev weapon menu (Studio only) ----------------------------------------------
-- P opens a panel with every weapon; clicking one hands its id to the pick
-- handler (WeaponController asks the server to equip it).

local TIER_COLORS: { [number]: Color3 } = {
	[1] = Color3.fromHex("AEB6CC"),
	[2] = NEON,
	[3] = GOLD,
	[4] = Color3.fromHex("FF3DCB"),
}
local CLASS_NAMES: { [string]: string } = { MachineGun = "Machine Gun", SMG = "SMG" }
local CARD = Color3.fromHex("252A3D")
local CARD_HOVER = Color3.fromHex("30364D")
local MUTED = Color3.fromHex("8A93AD")

type DevCard = { button: TextButton, stroke: UIStroke, name: TextLabel }
type DevMenu = { root: Frame, scale: UIScale, cards: { [string]: DevCard } }

local devMenu: DevMenu? = nil
local devMenuOpen = false
local devPick: ((id: string) -> ())? = nil

local function sortedWeapons(slot: string): { Types.WeaponConfig }
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

local function buildDevMenu(gui: ScreenGui): DevMenu
	-- Backdrop: a modal button, so the mouse is free while the menu is open
	-- (first person locks it otherwise). Clicking outside the panel closes it.
	local root = make("TextButton", {
		Name = "DevWeaponMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Modal = true,
		Text = "",
		Visible = false,
		ZIndex = 50,
	}, gui)
	root.Activated:Connect(function()
		HudController.toggleDevMenu()
	end)

	local panel = make("TextButton", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 600),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.04,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 51,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	make("UIStroke", { Color = NEON, Thickness = 1, Transparency = 0.55 }, panel)
	local scale = make("UIScale", {}, panel)

	make("TextLabel", {
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.fromOffset(400, 26),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "WEAPONS",
		ZIndex = 52,
	}, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(24, 46),
		Size = UDim2.fromOffset(500, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "DEV · STUDIO ONLY  —  click a weapon to equip it  ·  P to close",
		ZIndex = 52,
	}, panel)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = CARD,
		AutoButtonColor = true,
		Font = FONT,
		TextSize = 16,
		TextColor3 = WHITE,
		Text = "X",
		ZIndex = 52,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
	close.Activated:Connect(function()
		HudController.toggleDevMenu()
	end)

	local list = make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(20, 76),
		Size = UDim2.new(1, -40, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = NEON,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 52,
	}, panel)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, list)

	local cards: { [string]: DevCard } = {}
	for order, slot in { "Primary", "Secondary" } do
		make("TextLabel", {
			LayoutOrder = order * 2 - 1,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 14,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.upper(slot),
			ZIndex = 52,
		}, list)
		local grid = make("Frame", {
			Name = slot,
			LayoutOrder = order * 2,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 52,
		}, list)
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(184, 56),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for i, w in sortedWeapons(slot) do
			local tierColor = TIER_COLORS[w.tier] or WHITE
			local button = make("TextButton", {
				Name = w.id,
				LayoutOrder = i,
				BackgroundColor3 = CARD,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 53,
			}, grid)
			make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
			local cardStroke =
				make("UIStroke", { Color = NEON, Thickness = 2, Enabled = false }, button)
			make("Frame", {
				Position = UDim2.fromOffset(0, 8),
				Size = UDim2.new(0, 3, 1, -16),
				BackgroundColor3 = tierColor,
				BorderSizePixel = 0,
				ZIndex = 54,
			}, button)
			local name = make("TextLabel", {
				Position = UDim2.fromOffset(14, 9),
				Size = UDim2.new(1, -24, 0, 20),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 16,
				TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = w.displayName,
				ZIndex = 54,
			}, button)
			make("TextLabel", {
				Position = UDim2.fromOffset(14, 30),
				Size = UDim2.new(1, -24, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
				Text = string.format(
					"%s  ·  <font color='#%s'>TIER %d</font>",
					string.upper(CLASS_NAMES[w.class] or w.class),
					tierColor:ToHex(),
					w.tier
				),
				ZIndex = 54,
			}, button)
			button.MouseEnter:Connect(function()
				button.BackgroundColor3 = CARD_HOVER
			end)
			button.MouseLeave:Connect(function()
				button.BackgroundColor3 = CARD
			end)
			button.Activated:Connect(function()
				if devPick then
					devPick(w.id)
				end
				HudController.toggleDevMenu()
			end)
			cards[w.id] = { button = button, stroke = cardStroke, name = name }
		end
	end
	return { root = root, scale = scale, cards = cards }
end

-- Opens or closes the dev weapon menu. `held`: ids currently in the loadout
-- (highlighted).
function HudController.toggleDevMenu(held: { [string]: boolean }?)
	local r = refs
	if not r or not RunService:IsStudio() or not Dev.WEAPON_PICKER then
		return
	end
	local menu = devMenu
	if not menu then
		menu = buildDevMenu(r.gui)
		devMenu = menu
	end
	devMenuOpen = not devMenuOpen
	menu.root.Visible = devMenuOpen
	if devMenuOpen then
		for id, card in menu.cards do
			local on = held ~= nil and held[id] == true
			card.stroke.Enabled = on
			card.name.TextColor3 = if on then NEON else WHITE
			card.button.BackgroundColor3 = CARD
		end
		-- Fit small windows.
		local cam = Workspace.CurrentCamera
		local view = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
		menu.scale.Scale = math.min(1, (view.X - 32) / 820, (view.Y - 32) / 600)
	end
end

function HudController.onDevPick(handler: (id: string) -> ())
	devPick = handler
end

function HudController.isDevMenuOpen(): boolean
	return devMenuOpen
end

-- Loop -------------------------------------------------------------------------

local function update(dt: number)
	local r = refs
	local cam = Workspace.CurrentCamera
	if not r or not cam then
		return
	end
	-- Crosshair gap from spread in degrees -> pixels at the current FOV, eased.
	local half = cam.ViewportSize.Y / 2
	local gap = math.tan(math.rad(spreadDegrees)) / math.tan(math.rad(cam.FieldOfView / 2)) * half
	gap = math.clamp(gap + 3, 3, 70)
	shownGap += (gap - shownGap) * (1 - math.exp(-18 * dt))
	local g = math.floor(shownGap + 0.5) + 4
	r.lines[1].Position = UDim2.new(0.5, -g, 0.5, 0)
	r.lines[2].Position = UDim2.new(0.5, g, 0.5, 0)
	r.lines[3].Position = UDim2.new(0.5, 0, 0.5, -g)
	r.lines[4].Position = UDim2.new(0.5, 0, 0.5, g)
	crosshairAlpha += ((if crosshairWanted then 1 else 0) - crosshairAlpha) * (1 - math.exp(
		-20 * dt
	))
	r.crosshair.GroupTransparency = 1 - crosshairAlpha
	r.crosshair.Visible = crosshairAlpha > 0.02

	-- Health.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		r.healthFill.Size = UDim2.fromScale(frac, 1)
		r.healthFill.BackgroundColor3 = if frac < 0.35 then RED else WHITE
		r.healthText.Text = tostring(math.ceil(humanoid.Health))
		r.vignette.Visible = frac < 0.35 and frac > 0
	end
end

local function onKilled(victim: Model?, killer: Player?, weaponId: string, headshot: boolean)
	local config = Weapons.get(weaponId)
	local victimName = if victim then victim.Name else "?"
	local victimPlayer = victim and Players:GetPlayerFromCharacter(victim)
	if victimPlayer then
		victimName = victimPlayer.DisplayName
	end
	local killerName = if killer then killer.DisplayName else "?"
	local text = string.format(
		"%s  [%s%s]  %s",
		killerName,
		if config then config.displayName else weaponId,
		if headshot then " ◆" else "",
		victimName
	)
	HudController.killFeed(text, killer == player or victimPlayer == player)
end

-- Built in init so other controllers can update it from their start().
function HudController.init()
	refs = build()
end

function HudController.start()
	if refs and UserInputService.TouchEnabled then
		InputController.bindTouchButtons(refs.gui)
	end
	RunService.RenderStepped:Connect(update)
	Net.event("Killed").OnClientEvent:Connect(onKilled)
	Net.event("Damaged").OnClientEvent:Connect(function(from: Vector3)
		if typeof(from) == "Vector3" then
			HudController.damageFrom(from)
		end
	end)
end

return HudController
