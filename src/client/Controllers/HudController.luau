--!strict
-- Combat HUD (Gunplay.md §5): dynamic crosshair, hit / headshot / kill
-- markers, stacking damage numbers, ammo + reload, health, low-HP vignette,
-- damage direction, sniper scope, kill feed and touch buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local Net = require(ReplicatedStorage.Shared.Net)
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
	crosshair: Frame,
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

	-- Crosshair: four lines that open with spread, plus a dot.
	local crosshair = centered(UDim2.fromOffset(120, 120), gui)
	local lines = {}
	for i = 1, 4 do
		local horizontal = i <= 2
		local line = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = if horizontal then UDim2.fromOffset(9, 2) else UDim2.fromOffset(2, 9),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, crosshair)
		stroke(line)
		lines[i] = line
	end
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, 2),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, crosshair)
	stroke(dot)

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
			Size = UDim2.fromOffset(700, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = WHITE,
			TextTransparency = 0.25,
			Text = "DEV  T/Y next primary/secondary  ·  1 2 3 slots  ·  R reload  ·  RMB aim  ·  Shift sprint  ·  C slide/crouch  ·  V melee",
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

function HudController.setWeapon(displayName: string, ammo: number, magSize: number)
	local r = refs
	if not r then
		return
	end
	r.weaponName.Text = string.upper(displayName)
	HudController.setAmmo(ammo, magSize)
end

function HudController.setAmmo(ammo: number, magSize: number)
	local r = refs
	if not r then
		return
	end
	if magSize <= 0 then
		r.ammo.Text = ""
		return
	end
	r.ammo.Text = string.format("%d <font size='22' transparency='0.4'>/ %d</font>", ammo, magSize)
	r.ammo.RichText = true
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

function HudController.setCrosshairVisible(visible: boolean)
	if refs then
		refs.crosshair.Visible = visible
	end
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

-- Loop -------------------------------------------------------------------------

local function update()
	local r = refs
	local cam = Workspace.CurrentCamera
	if not r or not cam then
		return
	end
	-- Crosshair gap from spread in degrees -> pixels at the current FOV.
	local half = cam.ViewportSize.Y / 2
	local gap = math.tan(math.rad(spreadDegrees)) / math.tan(math.rad(cam.FieldOfView / 2)) * half
	gap = math.clamp(gap + 4, 4, 140)
	local positions = {
		UDim2.new(0.5, -gap - 4, 0.5, 0),
		UDim2.new(0.5, gap + 4, 0.5, 0),
		UDim2.new(0.5, 0, 0.5, -gap - 4),
		UDim2.new(0.5, 0, 0.5, gap + 4),
	}
	for i, line in r.lines do
		line.Position = positions[i]
	end

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
