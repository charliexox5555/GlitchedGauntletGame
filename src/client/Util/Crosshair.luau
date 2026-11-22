--!strict
-- The crosshair (numbers in Config/Crosshair; HudController owns when it
-- shows). A centre dot and four bars whose inner ends sit on the edge of the
-- gun's real spread cone (+ spacing), so the gap opens when you move, jump or
-- spray and closes as it settles. Built from plain Frames, not a CanvasGroup
-- (that renders to a texture and can blur thin lines), with every size and
-- position rounded to whole pixels and even line widths centred on a whole
-- pixel, so it stays crisp at any resolution. Sizes scale with the screen
-- height between Config minScale and maxScale.
-- `apply(config)` takes another table of the same shape (the later
-- customisation screen).
-- 2026-11-15 (RIVALS pass): state reactions on springs (Config `motion`): it
-- tilts 20 degrees while you slide, opens in the air, kicks open on a Dash
-- and on every shot (bloom), and aiming pulls the bars into the dot as it
-- fades. Each spring snaps to a bigger target at once and eases back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CrosshairConfig = require(ReplicatedStorage.Shared.Config.Crosshair)
local ScreenPoint = require(ReplicatedStorage.Shared.ScreenPoint)
local SlideTilt = require(script.Parent.SlideTilt)

type Config = CrosshairConfig.Crosshair

local Crosshair = {}

type Part = { frame: Frame, stroke: UIStroke }

local config: Config = CrosshairConfig.DEFAULT
local root: Frame? = nil
local bars: { Part } = {} -- right, left, bottom, top
local dot: Part? = nil
local shownGap = 0
local primed = false
local alpha = 1

-- Reaction springs (scalar, sub-stepped like Shared/Util/Spring).
type Spring = { x: number, v: number, target: number }
local function newSpring(): Spring
	return { x = 0, v = 0, target = 0 }
end
local airSpring = newSpring() -- px
local kickSpring = newSpring() -- px: Dash and shot kicks (target stays 0)
local airborne = false
local aimBlend = 0

local function stepSpring(sp: Spring, dt: number)
	local m = config.motion
	if m.snapUp and sp.target > sp.x then
		sp.x = sp.target
		sp.v = math.min(sp.v, 0)
	end
	local w = m.speed
	local k, c = w * w, 2 * m.damping * w
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		sp.v += ((sp.target - sp.x) * k - sp.v * c) * h
		sp.x += sp.v * h
	end
end

-- Unit directions of the four bars before rotation (screen y points down).
local DIRECTIONS = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }

local function newPart(parent: Instance): Part
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.ZIndex = 3
	f.Parent = parent
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Miter -- square corners on 2 px lines
	s.Parent = f
	return { frame = f, stroke = s }
end

-- Whole even pixels, at least 2 (an even width centred on a whole pixel has
-- whole-pixel edges).
local function evenPx(v: number): number
	return math.max(2, 2 * math.floor(v / 2 + 0.5))
end

local function sideOn(i: number): boolean
	local b = config.bars
	return if i == 1 then b.right elseif i == 2 then b.left elseif i == 3 then b.bottom else b.top
end

local function paint(p: Part, on: boolean)
	p.frame.Visible = on
	p.frame.BackgroundColor3 = config.color
	p.stroke.Enabled = config.outline.enabled
	p.stroke.Color = config.outline.color
	p.stroke.Thickness = config.outline.thickness
end

-- Use another crosshair config (customisation); nil: the default.
function Crosshair.apply(new: Config?)
	config = new or CrosshairConfig.DEFAULT
	for i, p in bars do
		paint(p, config.bars.enabled and sideOn(i))
	end
	if dot then
		paint(dot, config.dot.enabled)
	end
end

-- Movement state for the reactions: airborne opens it. (The slide's tilt
-- comes from Util/SlideTilt, the curve the camera roll and the gun share.)
-- `aim`: how far into the sights (0..1), for the ADS collapse.
function Crosshair.setState(_isSliding: boolean, isAirborne: boolean, aim: number)
	airborne = isAirborne
	aimBlend = if aim == aim then math.clamp(aim, 0, 1) else 0
end

-- A shot: the gap kicks open by the gun's kick (`recoilUp`, Weapons recoil.up)
-- and eases back; a spray stacks up to `bloomMax`.
function Crosshair.shot(recoilUp: number)
	local m = config.motion
	if m.shotGap <= 0 or recoilUp ~= recoilUp then
		return
	end
	local kick = math.clamp(m.shotGap * recoilUp, m.shotGapMin, m.shotGapMax)
	kickSpring.x = math.min(math.max(kickSpring.x, 0) + kick, m.bloomMax)
end

-- A Dash: the gap kicks wide and eases back.
function Crosshair.dash()
	local m = config.motion
	kickSpring.x = math.min(math.max(kickSpring.x, 0) + m.dashGap, m.bloomMax + m.dashGap)
end

-- The crosshair's current extra rotation, degrees (the hit marker turns with it).
-- Read live from Util/SlideTilt, so a reader before or after the HUD's step
-- gets this frame's lean.
function Crosshair.tilt(): number
	return math.floor(config.motion.slideTilt * SlideTilt.amount() + 0.5)
end

function Crosshair.build(gui: ScreenGui)
	local r = Instance.new("Frame")
	r.Name = "Crosshair"
	r.BackgroundTransparency = 1
	r.Size = UDim2.fromOffset(0, 0)
	r.ZIndex = 3
	r.Parent = gui
	root = r
	for i = 1, 4 do
		bars[i] = newPart(r)
	end
	dot = newPart(r)
	Crosshair.apply(config)
end

-- `spreadDegrees`: the next shot's cone (half-angle); `wanted`: shown (not
-- aiming down sights, unless the config says so); `sprinting`: the gap opens
-- by the config's sprintGap (the crosshair stays up while you run).
function Crosshair.step(
	dt: number,
	spreadDegrees: number,
	wanted: boolean,
	aiming: boolean?,
	sprinting: boolean?
)
	local r = root
	local cam = Workspace.CurrentCamera
	if not r or not cam then
		return
	end
	local c = config
	local m = c.motion
	airSpring.target = if airborne then m.airGap else 0
	stepSpring(airSpring, dt)
	stepSpring(kickSpring, dt)
	-- Whole degrees (RIVALS rounds too): fewer half-pixel edges while it turns.
	local shownTilt = Crosshair.tilt()
	local show = wanted or (aiming == true and c.showWhileAiming)
	alpha += ((if show then 1 else 0) - alpha) * (1 - math.exp(-c.fadeRate * dt))
	r.Visible = alpha > 0.02
	if not r.Visible then
		return
	end
	local vp = cam.ViewportSize
	-- The centre on a whole pixel (the camera's aim point, rounded). Through
	-- ScreenPoint: on a phone the viewport is the safe area, not the screen.
	local space = r.Parent
	local aimAt = if space and space:IsA("GuiBase2d") then ScreenPoint.centre(space) else vp / 2
	r.Position = UDim2.fromOffset(math.floor(aimAt.X), math.floor(aimAt.Y))
	local px = math.clamp(vp.Y / c.designHeight, c.minScale, c.maxScale) * c.scale

	-- The gap: the spread cone's edge in pixels at the current FOV, eased.
	local spreadPx = 0
	if not c.static then
		spreadPx = math.tan(math.rad(spreadDegrees))
			/ math.tan(math.rad(cam.FieldOfView / 2))
			* (vp.Y / 2)
	end
	local sprint = if sprinting and not c.static then c.sprintGap * px else 0
	local react = if c.static then 0 else (airSpring.x + math.max(kickSpring.x, 0)) * px
	local goal = math.min(c.bars.spacing * px + spreadPx + sprint, c.maxGap * px) + react
	-- ADS: the bars close into the dot as it fades (RIVALS).
	local collapse = if m.adsCollapse and not c.showWhileAiming then 1 - aimBlend else 1
	if not primed then
		shownGap = goal -- the first frame starts on the cone, not easing in from 0
		primed = true
	end
	shownGap += (goal - shownGap) * (1 - math.exp(-c.followRate * dt))
	local inner = math.floor(shownGap * collapse + 0.5)

	local length = evenPx(c.bars.length * px) -- even: whole-pixel ends (5 px landed on half pixels)
	local thick = evenPx(c.bars.thickness * px)
	local seen = alpha * collapse
	local fill = 1 - (1 - c.transparency) * seen
	local line = 1 - (1 - c.outline.transparency) * seen
	local rotation = c.rotation + shownTilt
	local rad = math.rad(rotation)
	local cos, sin = math.cos(rad), math.sin(rad)
	for i, p in bars do
		if not p.frame.Visible then
			continue
		end
		local d = DIRECTIONS[i]
		local dir = Vector2.new(d.X * cos - d.Y * sin, d.X * sin + d.Y * cos)
		local centre = dir * (inner + length / 2)
		p.frame.Position = UDim2.fromOffset(centre.X, centre.Y)
		local horizontal = d.Y == 0
		p.frame.Size = if horizontal
			then UDim2.fromOffset(length, thick)
			else UDim2.fromOffset(thick, length)
		p.frame.Rotation = rotation
		p.frame.BackgroundTransparency = fill
		p.stroke.Transparency = line
	end
	local d = dot
	if d and d.frame.Visible then
		local size = evenPx(c.dot.size * px)
		d.frame.Size = UDim2.fromOffset(size, size)
		d.frame.Position = UDim2.fromOffset(0, 0)
		d.frame.BackgroundTransparency = fill
		d.stroke.Transparency = line
	end
end

return Crosshair
