--!strict
-- Combat HUD (Gunplay.md §5), the fresh-base version: a dynamic crosshair,
-- hit markers and damage numbers (Util/HitFeedback), ammo + reload, health,
-- a low-HP vignette, the damage direction and the touch buttons. Plain and
-- neutral: white text with a soft shadow, no neon. The full UI comes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local HitFeedback = require(script.Parent.Parent.Util.HitFeedback)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)

local HudController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local MUTED = Color3.fromHex("C9CCD1")
local AMBER = Color3.fromHex("F2C94C")
local RED = Color3.fromHex("EB5757")
local BACK = Color3.fromHex("16181B")
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local INDICATOR_TIME = 1.1 -- damage direction fade, seconds

type Refs = {
	gui: ScreenGui,
	crosshair: CanvasGroup,
	lines: { Frame },
	scope: Frame,
	ammo: TextLabel,
	mag: TextLabel,
	weaponName: TextLabel,
	reloadBar: Frame,
	reloadFill: Frame,
	healthFill: Frame,
	healthText: TextLabel,
	vignette: CanvasGroup,
	indicator: Frame,
	wedge: Frame,
}

local refs: Refs? = nil
local spreadDegrees = 1
local shownGap = 6
local crosshairWanted = true
local crosshairAlpha = 1
local indicatorAge = math.huge

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

-- Soft drop shadow on text: readable on bright sky and dark walls alike.
local function shadow(label: TextLabel, thickness: number?)
	make("UIStroke", {
		Color = BLACK,
		Thickness = thickness or 1.5,
		Transparency = 0.55,
	}, label)
end

local function text(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	local label = make("TextLabel", props, parent)
	shadow(label)
	return label
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

	-- Low-HP vignette: red edges that fade in as health drops.
	local vignette = make("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
	}, gui)
	for _, edge in
		{
			{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
			{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180 },
		}
	do
		local f = make("Frame", {
			Size = edge[1],
			Position = edge[2],
			BackgroundColor3 = Color3.fromHex("7A1010"),
			BorderSizePixel = 0,
		}, vignette)
		make("UIGradient", {
			Rotation = edge[3],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, f)
	end

	-- Sniper scope (config scope): black outside a round lens (a huge stroke
	-- drawn outward from a circle), a soft dark rim inside it, and a duplex
	-- reticle: thick posts from the edge, a fine cross and dot in the middle.
	local scope = make("Frame", {
		Name = "Scope",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local lens = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.96),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
	}, scope)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, lens)
	make("UIStroke", { Color = BLACK, Thickness = 4000 }, lens)
	local rim = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.97, 0.97),
		BackgroundTransparency = 1,
	}, lens)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, rim)
	make("UIStroke", { Color = BLACK, Thickness = 10, Transparency = 0.45 }, rim)
	for _, line in
		{
			-- size, position (fine cross across the lens, then the four posts)
			{ UDim2.new(1, 0, 0, 1), UDim2.fromScale(0.5, 0.5) },
			{ UDim2.new(0, 1, 1, 0), UDim2.fromScale(0.5, 0.5) },
			{ UDim2.new(0.38, 0, 0, 4), UDim2.fromScale(0.19, 0.5) },
			{ UDim2.new(0.38, 0, 0, 4), UDim2.fromScale(0.81, 0.5) },
			{ UDim2.new(0, 4, 0.38, 0), UDim2.fromScale(0.5, 0.81) },
		}
	do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = line[1],
			Position = line[2],
			BackgroundColor3 = BLACK,
			BorderSizePixel = 0,
		}, lens)
	end
	local scopeDot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
	}, lens)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, scopeDot)

	-- Crosshair (CanvasGroup so it fades as one): a centre dot plus four short
	-- lines that open with spread. A thin dark outline keeps it readable.
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
			Size = if horizontal then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, crosshair)
		make("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.5 }, line)
		lines[i] = line
	end
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, 2),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, crosshair)
	make("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.5 }, dot)

	-- Ammo (bottom right): rounds in the mag, big; the mag size and the gun's
	-- name small; a thin reload bar underneath.
	local ammoPanel = make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -36, 1, -30),
		Size = UDim2.fromOffset(220, 84),
		BackgroundTransparency = 1,
	}, gui)
	local weaponName = text({
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = MEDIUM,
		TextSize = 16,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, ammoPanel)
	local mag = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 30),
		Size = UDim2.fromOffset(52, 30),
		FontFace = MEDIUM,
		TextSize = 22,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, ammoPanel)
	local ammo = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 16),
		Size = UDim2.fromOffset(140, 48),
		FontFace = BOLD,
		TextSize = 46,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, ammoPanel)
	local reloadBar = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 72),
		Size = UDim2.fromOffset(150, 3),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
	}, ammoPanel)
	local reloadFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, reloadBar)

	-- Health (bottom left): the number, and a bar under it.
	local healthPanel = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 36, 1, -30),
		Size = UDim2.fromOffset(240, 70),
		BackgroundTransparency = 1,
	}, gui)
	local healthText = text({
		Size = UDim2.fromOffset(120, 48),
		Position = UDim2.fromOffset(0, 10),
		FontFace = BOLD,
		TextSize = 46,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "100",
	}, healthPanel)
	local healthBar = make("Frame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.fromOffset(220, 5),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, healthPanel)
	local healthFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, healthBar)

	-- Damage direction: a red arc segment orbiting the crosshair.
	local indicator = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	}, gui)
	local wedge = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, -120),
		Size = UDim2.fromOffset(80, 5),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
	}, indicator)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, wedge)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wedge)

	-- Touch buttons (names match Config/Input).
	if UserInputService.TouchEnabled then
		local function button(name: string, label: string, pos: UDim2, size: number)
			local b = make("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = pos,
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = BACK,
				BackgroundTransparency = 0.45,
				FontFace = BOLD,
				TextSize = 14,
				TextColor3 = WHITE,
				Text = label,
				AutoButtonColor = true,
			}, gui)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
			make("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.6 }, b)
		end
		button("FireButton", "FIRE", UDim2.new(1, -110, 1, -210), 86)
		button("AimButton", "AIM", UDim2.new(1, -210, 1, -260), 64)
		button("ReloadButton", "R", UDim2.new(1, -60, 1, -310), 52)
		button("SlideButton", "SLIDE", UDim2.new(1, -200, 1, -150), 60)
		button("SwapButton", "SWAP", UDim2.new(1, -60, 1, -380), 52)
		button("SprintButton", "RUN", UDim2.new(1, -290, 1, -200), 56)
	end

	return {
		gui = gui,
		crosshair = crosshair,
		lines = lines,
		scope = scope,
		ammo = ammo,
		mag = mag,
		weaponName = weaponName,
		reloadBar = reloadBar,
		reloadFill = reloadFill,
		healthFill = healthFill,
		healthText = healthText,
		vignette = vignette,
		indicator = indicator,
		wedge = wedge,
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
		r.mag.Text = ""
		return
	end
	r.ammo.Text = tostring(ammo)
	r.mag.Text = "/ " .. tostring(magSize)
	r.ammo.TextColor3 = if ammo == 0 then RED elseif ammo <= magSize * 0.25 then AMBER else WHITE
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

-- Fades rather than pops (ADS, sprint).
function HudController.setCrosshairVisible(visible: boolean)
	crosshairWanted = visible
end

-- The sniper scope overlay (WeaponController shows it once scoped in).
function HudController.setScope(visible: boolean)
	local r = refs
	if r then
		r.scope.Visible = visible
	end
end

-- Hit feedback (Util/HitFeedback): markers and damage numbers.
function HudController.hitMarker(headshot: boolean)
	HitFeedback.hit(headshot)
end

function HudController.killMarker()
	HitFeedback.kill()
end

-- Damage numbers stack while you keep hitting the same target, then fall off.
-- `position`: the world hit point (the number sits beside it).
function HudController.damageNumber(
	amount: number,
	headshot: boolean,
	position: Vector3?,
	killed: boolean?
)
	HitFeedback.damage(amount, headshot, position, killed)
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
	indicatorAge = 0
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
	local goal = if crosshairWanted then 1 else 0
	crosshairAlpha += (goal - crosshairAlpha) * (1 - math.exp(-20 * dt))
	r.crosshair.GroupTransparency = 1 - crosshairAlpha
	r.crosshair.Visible = crosshairAlpha > 0.02
	HitFeedback.step(dt)

	-- Damage direction: holds, then fades.
	indicatorAge += dt
	local k = indicatorAge / INDICATOR_TIME
	r.wedge.BackgroundTransparency = if k >= 1 then 1 else 0.05 + 0.95 * k * k

	-- Health.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		r.healthFill.Size = UDim2.fromScale(frac, 1)
		r.healthFill.BackgroundColor3 = if frac < 0.35 then RED else WHITE
		r.healthText.Text = tostring(math.ceil(humanoid.Health))
		local hurt = if frac > 0 then math.clamp((0.45 - frac) / 0.35, 0, 1) else 0
		r.vignette.GroupTransparency = 1 - hurt
	end
end

-- Built in init so other controllers can update it from their start().
function HudController.init()
	refs = build()
	HitFeedback.build((refs :: Refs).gui)
end

function HudController.start()
	if refs and UserInputService.TouchEnabled then
		InputController.bindTouchButtons(refs.gui)
	end
	RunService.RenderStepped:Connect(update)
	local lastHurt = 0
	Net.event("Damaged").OnClientEvent:Connect(function(from: Vector3)
		if typeof(from) == "Vector3" then
			HudController.damageFrom(from)
		end
		local now = os.clock()
		if now - lastHurt >= Audio.DAMAGE_MIN_GAP then
			lastHurt = now
			AudioController.play(
				Sounds.Damage,
				{ group = "Feedback", volume = Audio.DAMAGE_VOLUME }
			)
		end
	end)
end

return HudController
