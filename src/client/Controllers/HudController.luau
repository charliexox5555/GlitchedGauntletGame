--!strict
-- Combat HUD (Gunplay.md §5): a dynamic crosshair, hit markers and damage
-- numbers (Util/HitFeedback), ammo + reload, health and shield in the UI v1
-- look (vault/02 Art/UI Design.md), a low-HP vignette, the damage direction
-- (the touch controls are TouchController). The kill feed is KillFeedController;
-- Util/KillFeed plays the kill sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Health = require(ReplicatedStorage.Shared.Health)
local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

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

local HudController = {}

local player = Players.LocalPlayer

type Refs = {
	gui: ScreenGui,
	scope: Frame,
	vignette: CanvasGroup,
}

local refs: Refs? = nil
local spreadDegrees = 1
local crosshairWanted = true
local crosshairSprint = false
local hitPulse = 0 -- the red edge pulse when hit (0..1), fades over Juice.FLINCH.pulseTime
-- The body whose health the HUD shows: the fighter you spectate, else yours.
local subject: Model? = nil

local make = Ui.make

local function build(): Refs
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local gui = make("ScreenGui", {
		Name = "CombatHud",
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, -- full-bleed overlays, under the notch too
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ClipToDeviceSafeArea = false,
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

	-- Health and ammo are the Studio-built bottom HUD (Util/BottomHud) or,
	-- on touch, the touch screen (Util/TouchHud); the old v1 panels are gone.

	-- Damage direction: red arcs round the crosshair (Util/DamageIndicator).
	DamageIndicator.build(gui)

	return {
		gui = gui,
		scope = scope,
		vignette = vignette,
	}
end

-- API ------------------------------------------------------------------------

function HudController.setWeapon(
	displayName: string,
	ammo: number,
	magSize: number,
	id: string?,
	reserve: number?
)
	BottomHud.setWeapon(displayName, id)
	HudController.setAmmo(ammo, magSize, reserve)
end

function HudController.setAmmo(ammo: number, magSize: number, reserve: number?)
	BottomHud.setAmmo(ammo, magSize, reserve)
end

-- `progress` 0..1 while reloading, nil when not.
function HudController.setReload(progress: number?)
	BottomHud.setReload(progress)
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
	local character = subject or player.Character
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

	-- Health (the spectated fighter's while you watch them).
	local character = subject or player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = math.clamp(Health.get(humanoid) / Health.max(humanoid), 0, 1)
		local shield = StateValues.get(humanoid, Combat.SHIELD_ATTRIBUTE)
		local hasShield = typeof(shield) == "number" and shield > 0
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
-- The fighter you spectate (SpectateController): the health and shield
-- panels, the low-health edge and the hit pulse follow them; nil: your own.
function HudController.setSubject(body: Model?)
	if subject == body then
		return
	end
	subject = body
	hitPulse = 0
end

function HudController.setSpectating(on: boolean)
	BottomHud.setSpectating(on)
end

function HudController.init()
	refs = build()
	HitFeedback.build((refs :: Refs).gui)
	BottomHud.start()
end

function HudController.start()
	RunService.RenderStepped:Connect(update)
	Net.event("Killed").OnClientEvent:Connect(KillFeed.kill)
	if RunService:IsStudio() then
		-- Studio only: Workspace DevDamageFrom (Vector3) shows the damage
		-- direction arc for a hit from that spot (no damage, no flinch).
		StateValues.changed(Workspace, "DevDamageFrom"):Connect(function()
			local from = StateValues.get(Workspace, "DevDamageFrom")
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
