--!strict
-- Combat HUD (Gunplay.md §5): a dynamic crosshair, hit markers and damage
-- numbers (Util/HitFeedback), ammo + reload, health and shield in the UI v1
-- look (vault/02 Art/UI Design.md), a low-HP vignette, the damage direction
-- and the touch buttons. The kill feed and kill banner are Util/KillFeed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Health = require(ReplicatedStorage.Shared.Health)
local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local BottomHud = require(script.Parent.Parent.Util.BottomHud)
local AimVignette = require(script.Parent.Parent.Util.AimVignette)
local Crosshair = require(script.Parent.Parent.Util.Crosshair)
local DamageIndicator = require(script.Parent.Parent.Util.DamageIndicator)
local HitFeedback = require(script.Parent.Parent.Util.HitFeedback)
local KillFeed = require(script.Parent.Parent.Util.KillFeed)
local ScopeOverlay = require(script.Parent.Parent.Util.ScopeOverlay)
local Ui = require(script.Parent.Parent.Util.Ui)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)

local HudController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local AMBER = Color3.fromHex("F2C94C")
local RED = Color3.fromHex("EB5757")
local BACK = Color3.fromHex("18181B")
local T = Theme.COLORS
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)

-- Touch layout: designed for a 760-px-tall screen, scaled down to fit (never
-- below TOUCH_SCALE_MIN) and never up. Positions are offsets from the
-- layer's bottom-right corner.
local TOUCH_LAYER = Vector2.new(480, 480)
local TOUCH_DESIGN_HEIGHT = 760
local TOUCH_SCALE_MIN = 0.62
local TOUCH_MIN_BUTTON = 72 -- design px (Util/Device mirrors the layer numbers)

local touchLayer: Frame? = nil

-- Touch controls are built on touch devices, and in Studio when the Workspace
-- attribute ForceTouchUI is ticked (to check the layout on a PC).
local function touchUi(): boolean
	return UserInputService.TouchEnabled
		or (RunService:IsStudio() and Workspace:GetAttribute("ForceTouchUI") == true)
end

type Refs = {
	gui: ScreenGui,
	scope: Frame,
	ammo: TextLabel,
	mag: TextLabel,
	gunPicture: ImageLabel,
	shieldBadge: ImageLabel,
	weaponName: TextLabel,
	reloadBar: Frame,
	reloadFill: Frame,
	healthFill: Frame,
	healthChip: Frame, -- the health just lost, which drains after a beat
	healthText: TextLabel,
	shieldText: TextLabel,
	shieldBar: Frame,
	shieldFill: Frame,
	vignette: CanvasGroup,
}

local refs: Refs? = nil
local spreadDegrees = 1
local crosshairWanted = true
local crosshairSprint = false
local hitPulse = 0 -- the red edge pulse when hit (0..1), fades over Juice.FLINCH.pulseTime
-- Health chip: the bar's lost part stays red for CHIP_HOLD, then drains.
local CHIP_HOLD = 0.4
local CHIP_DRAIN = 0.35
local shownHealth = -1
local chipFrac = 1
local chipHoldUntil = 0

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

	-- Aimed: the screen's edges darken (Util/AimVignette).
	AimVignette.build(gui)
	-- Sniper scope (config scope): Util/ScopeOverlay (numbers in Config/Scope).
	local scope = ScopeOverlay.build(gui)

	-- Crosshair: Util/Crosshair (numbers in Config/Crosshair).
	Crosshair.build(gui)

	-- Ammo (bottom right, UI v1): the gun's picture, rounds in the mag big, the
	-- mag size and the gun's name small, a thin reload bar. Design px, scaled.
	local ammoPanel = make("Frame", {
		Name = "Ammo",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -40),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
	}, gui)
	Ui.fit(ammoPanel)
	local ammoBack = make("Frame", {
		Name = "Back", -- PhoneHudController trims it on phones
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.fromOffset(420, 120),
		BorderSizePixel = 0,
		BackgroundColor3 = T.panel,
	}, ammoPanel)
	make("UIGradient", { Transparency = NumberSequence.new(1, 0.15) }, ammoBack)
	local gunPicture = make("ImageLabel", {
		Name = "Gun",
		Position = UDim2.fromOffset(190, 14),
		Size = UDim2.fromOffset(210, 62),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
	}, ammoPanel)
	local weaponName = Ui.text(ammoPanel, "", "label", {
		Name = "WeaponName",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(404, 178),
		Size = UDim2.fromOffset(220, 16),
		TextColor3 = T.textSecondary,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local mag = Ui.text(ammoPanel, "", "titleS", {
		Position = UDim2.fromOffset(330, 134),
		Size = UDim2.fromOffset(80, 28),
		TextColor3 = T.textSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local ammo = Ui.text(ammoPanel, "", "numberHud", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(322, 88),
		Size = UDim2.fromOffset(200, 84),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local reloadBar = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(404, 170),
		Size = UDim2.fromOffset(220, 4),
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
		Visible = false,
	}, ammoPanel)
	local reloadFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, reloadBar)

	-- Health (bottom left, UI v1): a shield badge with the shield in it, the
	-- health number big, a shield bar over the health bar.
	local healthPanel = make("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 48, 1, -40),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
	}, gui)
	Ui.fit(healthPanel)
	local healthBack = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = T.panel,
	}, healthPanel)
	make("UIGradient", { Transparency = NumberSequence.new(0.15, 1) }, healthBack)
	local badge = make("ImageLabel", {
		Name = "ShieldBadge",
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.fromOffset(60, 76),
		BackgroundTransparency = 1,
		Image = Theme.IMAGE.shieldFill,
		ImageColor3 = T.ally,
		ImageTransparency = 0.82,
	}, healthPanel)
	make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.IMAGE.shieldLine,
		ImageColor3 = T.ally,
	}, badge)
	local shieldText = Ui.text(badge, "0", "titleS", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.fromOffset(60, 28),
		TextColor3 = T.ally,
	})
	local healthText = Ui.text(healthPanel, "100", "numberHud", {
		Position = UDim2.fromOffset(96, 2),
		Size = UDim2.fromOffset(170, 84),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Ui.text(healthPanel, "HEALTH", "label", {
		Name = "Caption",
		Position = UDim2.fromOffset(250, 34),
		Size = UDim2.fromOffset(100, 16),
		TextColor3 = T.textSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local shieldBar = make("Frame", {
		Position = UDim2.fromOffset(96, 84),
		Size = UDim2.fromOffset(300, 6),
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
		Visible = false,
	}, healthPanel)
	local shieldFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.ally,
		BorderSizePixel = 0,
	}, shieldBar)
	local healthBar = make("Frame", {
		Position = UDim2.fromOffset(96, 96),
		Size = UDim2.fromOffset(300, 10),
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
	}, healthPanel)
	local healthChip = make("Frame", {
		Name = "Chip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
	}, healthBar)
	local healthFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, healthBar)

	-- Damage direction: red arcs round the crosshair (Util/DamageIndicator).
	DamageIndicator.build(gui)

	-- Touch buttons (names match Config/Input), on their own layer: a
	-- bottom-right frame in a ScreenGui that respects the device's safe area
	-- (notches, rounded corners), scaled to the screen height so the whole
	-- cluster (and the Mod arc ModHudController adds to it) fits a small
	-- phone and stays the same shape everywhere.
	if touchUi() then
		local touchGui = make("ScreenGui", {
			Name = "TouchControls",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			DisplayOrder = 4,
		}, player:WaitForChild("PlayerGui"))
		local layer = make("Frame", {
			Name = "Layer",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(TOUCH_LAYER.X, TOUCH_LAYER.Y),
			BackgroundTransparency = 1,
		}, touchGui)
		local scale = make("UIScale", { Scale = 1 }, layer)
		local function rescale()
			local cam = Workspace.CurrentCamera
			local h = if cam then cam.ViewportSize.Y else TOUCH_DESIGN_HEIGHT
			scale.Scale = math.clamp(h / TOUCH_DESIGN_HEIGHT, TOUCH_SCALE_MIN, 1)
		end
		rescale()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
		touchLayer = layer
		local function button(name: string, label: string, pos: UDim2, size: number)
			-- 72 design px at least: 44+ px drawn at the layer's 0.62 floor
			-- (LihFolk: Responsive UI, 44 px tap minimum).
			size = math.max(size, TOUCH_MIN_BUTTON)
			local b = make("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = pos,
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = BACK,
				BackgroundTransparency = 0.25, -- readable over snow and bright walls
				FontFace = BOLD,
				TextSize = 22, -- 13.6 px drawn at the 0.62 floor
				TextColor3 = WHITE,
				Text = label,
				AutoButtonColor = true,
			}, layer)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
			make("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.35 }, b)
		end
		button("FireButton", "FIRE", UDim2.new(1, -110, 1, -210), 86)
		button("AimButton", "AIM", UDim2.new(1, -210, 1, -260), 64)
		button("ReloadButton", "R", UDim2.new(1, -60, 1, -310), 52)
		button("SlideButton", "SLIDE", UDim2.new(1, -200, 1, -150), 60)
		button("SwapButton", "SWAP", UDim2.new(1, -60, 1, -392), 52) -- 8 px clear of R at 72 px
		button("SprintButton", "RUN", UDim2.new(1, -290, 1, -200), 56)
	end

	return {
		gui = gui,
		scope = scope,
		ammo = ammo,
		mag = mag,
		weaponName = weaponName,
		reloadBar = reloadBar,
		reloadFill = reloadFill,
		healthFill = healthFill,
		healthChip = healthChip,
		healthText = healthText,
		shieldText = shieldText,
		shieldBar = shieldBar,
		shieldFill = shieldFill,
		vignette = vignette,
		gunPicture = gunPicture,
		shieldBadge = badge,
	}
end

-- API ------------------------------------------------------------------------

-- The touch controls' layer (nil off touch): ModHudController puts its Mod
-- arc here so it lines up with Fire at every scale.
function HudController.touchLayer(): Frame?
	return touchLayer
end

function HudController.setWeapon(displayName: string, ammo: number, magSize: number, id: string?)
	BottomHud.setWeapon(displayName, id)
	local r = refs
	if not r then
		return
	end
	r.weaponName.Text = string.upper(displayName)
	r.gunPicture.Image = if id then Theme.GUN[id] or "" else ""
	HudController.setAmmo(ammo, magSize)
end

function HudController.setAmmo(ammo: number, magSize: number)
	BottomHud.setAmmo(ammo, magSize)
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
	BottomHud.setReload(progress)
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

-- Fades rather than pops (ADS). `sprinting`: it stays up and opens wider.
function HudController.setCrosshairVisible(visible: boolean, sprinting: boolean?)
	crosshairWanted = visible
	crosshairSprint = sprinting == true
end

-- Crosshair reactions (Config/Crosshair motion): sliding tilts it, the air
-- opens it, aiming (0..1) pulls the bars into the dot as it fades.
function HudController.setCrosshairState(sliding: boolean, airborne: boolean, aim: number)
	Crosshair.setState(sliding, airborne, aim)
end

-- A shot: the crosshair blooms by the gun's kick (recoil.up).
function HudController.crosshairShot(recoilUp: number)
	Crosshair.shot(recoilUp)
end

-- A Dash: the crosshair kicks open.
function HudController.crosshairDash()
	Crosshair.dash()
end

-- The sniper scope overlay (WeaponController shows it once scoped in).
function HudController.setScope(visible: boolean)
	ScopeOverlay.set(visible)
end

-- How far into the sights the gun is, 0..1: the screen's edges darken with it.
function HudController.setAim(alpha: number)
	AimVignette.set(alpha)
end

-- A shot fired while scoped in: the scope picture jolts.
function HudController.scopeShot()
	ScopeOverlay.shot()
end

-- Hit feedback (Util/HitFeedback): markers and damage numbers.
function HudController.hitMarker(headshot: boolean)
	HitFeedback.hit(headshot)
end

function HudController.killMarker()
	HitFeedback.kill()
end

-- One damage number per target: it keeps counting while you keep hitting
-- them, then falls off. `position`: the world hit point; `target`: who was
-- hit (the number sits over their head).
function HudController.damageNumber(
	amount: number,
	headshot: boolean,
	position: Vector3?,
	killed: boolean?,
	target: Instance?
)
	HitFeedback.damage(amount, headshot, position, killed, target)
end

-- An arc on the side the hit came from; it follows that spot as you turn
-- and move, and is bigger the closer it is.
function HudController.damageFrom(sourcePosition: Vector3)
	DamageIndicator.hit(sourcePosition)
end

-- Getting hit: the camera is pushed a little away from the shot and rolls
-- (never turned, so your aim stays put), and the screen edges pulse red.
function HudController.flinch(sourcePosition: Vector3, amount: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local f = Juice.FLINCH
	local s = math.clamp(amount / f.fullDamage, 0.25, 1)
	local away = (cam.CFrame.Position - sourcePosition) * Vector3.new(1, 0, 1)
	if away.Magnitude > 0.1 then
		CameraController.lunge(away.Unit * f.offset * s, 0.25)
		-- Roll away from the side the shot came from.
		local side = cam.CFrame.RightVector:Dot(-away.Unit)
		CameraController.rollKick((if side >= 0 then 1 else -1) * f.roll * s, 0.3)
	end
	-- The pulse follows the share of your health the hit took (RIVALS).
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local before = if humanoid then Health.get(humanoid) + amount else f.fullDamage * 2
	local share = math.clamp(amount / math.max(before, 1), 0, 1)
	hitPulse = math.max(hitPulse, math.min(f.pulse + f.pulsePerShare * share, f.pulseMax))
end

-- Loop -------------------------------------------------------------------------

local function update(dt: number)
	local r = refs
	local cam = Workspace.CurrentCamera
	if not r or not cam then
		return
	end
	-- Crosshair: the gap follows the spread cone and opens on a sprint; it
	-- fades for ADS.
	Crosshair.step(dt, spreadDegrees, crosshairWanted, nil, crosshairSprint)
	HitFeedback.step(dt)
	ScopeOverlay.step(dt)

	DamageIndicator.step(dt)

	-- Health.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = math.clamp(Health.get(humanoid) / Health.max(humanoid), 0, 1)
		r.healthFill.Size = UDim2.fromScale(frac, 1)
		r.healthFill.BackgroundColor3 = if frac < 0.35 then RED else WHITE
		local health = math.ceil(Health.get(humanoid))
		if health ~= shownHealth then
			if shownHealth >= 0 and health < shownHealth then
				-- Hit: the number flashes red and the chip holds the lost part.
				chipHoldUntil = os.clock() + CHIP_HOLD
				r.healthText.TextColor3 = RED
				Ui.tween(r.healthText, 0.4, { TextColor3 = WHITE })
			end
			shownHealth = health
			r.healthText.Text = tostring(health)
		end
		if frac >= chipFrac then
			chipFrac = frac -- healed (or a new life): no chip
		elseif os.clock() >= chipHoldUntil then
			chipFrac = math.max(frac, chipFrac - dt / CHIP_DRAIN)
		end
		r.healthChip.Size = UDim2.fromScale(chipFrac, 1)
		local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
		local hasShield = typeof(shield) == "number" and shield > 0
		r.shieldBar.Visible = hasShield
		r.shieldBadge.Visible = hasShield
		r.shieldText.Text = if hasShield then tostring(math.ceil(shield :: number)) else ""
		if hasShield then
			r.shieldFill.Size =
				UDim2.fromScale(math.clamp((shield :: number) / Combat.MAX_SHIELD, 0, 1), 1)
		end
		BottomHud.setHealth(
			Health.get(humanoid),
			Health.max(humanoid),
			if hasShield then shield :: number else 0,
			dt
		)
		local fl = Juice.FLINCH
		local hurt = if frac > 0
			then math.clamp((fl.lowFrom - frac) / (fl.lowFrom - fl.lowFull), 0, 1)
			else 0
		hitPulse = math.max(hitPulse - dt / Juice.FLINCH.pulseTime, 0)
		r.vignette.GroupTransparency = 1 - math.max(hurt, hitPulse)
	end
end

-- Built in init so other controllers can update it from their start().
-- Spectating: your own health and ammo panels hide (the spectate bar shows
-- who you're watching instead).
function HudController.setSpectating(on: boolean)
	BottomHud.setSpectating(on)
	local r = refs
	if not r then
		return
	end
	for _, name in { "Health", "Ammo" } do
		local panel = r.gui:FindFirstChild(name)
		if panel and panel:IsA("GuiObject") then
			panel.Visible = not on and not BottomHud.active()
		end
	end
end

function HudController.init()
	refs = build()
	HitFeedback.build((refs :: Refs).gui)
	KillFeed.build((refs :: Refs).gui)
	-- The Studio-built bottom HUD (desktop) replaces the old health and ammo panels.
	BottomHud.start()
	BottomHud.onActive(function()
		local r = refs
		if not r then
			return
		end
		for _, name in { "Health", "Ammo" } do
			local panel = r.gui:FindFirstChild(name)
			if panel and panel:IsA("GuiObject") then
				panel.Visible = false
			end
		end
	end)
end

function HudController.start()
	local layer = touchLayer
	if layer then
		InputController.bindTouchButtons(layer)
	end
	RunService.RenderStepped:Connect(update)
	Net.event("Killed").OnClientEvent:Connect(KillFeed.kill)
	if RunService:IsStudio() then
		-- Studio only: Workspace DevDamageFrom (Vector3) shows the damage
		-- direction arc for a hit from that spot (no damage, no flinch).
		Workspace:GetAttributeChangedSignal("DevDamageFrom"):Connect(function()
			local from = Workspace:GetAttribute("DevDamageFrom")
			if typeof(from) == "Vector3" then
				HudController.damageFrom(from)
			end
		end)
	end
	local lastHurt = 0
	Net.event("Damaged").OnClientEvent:Connect(function(from: Vector3, amount: number?)
		if typeof(from) == "Vector3" then
			HudController.damageFrom(from)
			HudController.flinch(
				from,
				if typeof(amount) == "number" and amount == amount then amount else 20
			)
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
