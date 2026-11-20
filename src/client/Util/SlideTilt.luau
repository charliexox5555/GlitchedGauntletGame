--!strict
-- The slide's lean, one signal for everything that leans with it (owner
-- 2026-11-20: "the viewmodel must follow that roll so it looks seamless"):
-- the camera roll (CameraController), the crosshair and hit-marker tilt
-- (Util/Crosshair), the sniper reticle (Util/ScopeOverlay) and the gun's cant
-- on screen (ViewmodelController, VM.SLIDE_CANT). Each multiplies amount()
-- by its own size, so they all move on the same curve, in the same frame.
--
-- The curve (Juice.SLIDE): into the slide a quick underdamped spring (the
-- ~60-90 ms snap, a touch past and settle); out of it RIVALS' slower camera
-- spring (speed 15, damper 0.5: it swings ~16 % past and settles). It was
-- two curves: the crosshair jumped on in one frame while the camera took
-- ~160 ms, and the gun didn't lean at all.
--
-- Stepped once per frame at RenderPriority.First, so every reader in the
-- frame (camera, viewmodel, HUD) sees the same value.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)

local SlideTilt = {}

local target = 0
local x = 0
local v = 0
local started = false

-- 1 while sliding, 0 otherwise (any 0..1 works).
function SlideTilt.set(amount: number)
	target = if amount == amount then math.clamp(amount, 0, 1) else 0
end

-- The lean this frame: 0 upright, 1 full (a touch more on the overshoot,
-- a touch below 0 on the way back).
function SlideTilt.amount(): number
	return x
end

-- Advances the spring by `dt` (also used by captures to sample the curve).
function SlideTilt.step(dt: number)
	local s = Juice.SLIDE
	local entering = target > 0
	local w = if entering then s.rollInSpeed else s.rollSpeed
	local c = 2 * (if entering then s.rollInDamping else s.rollDamping) * w
	local steps = math.max(1, math.ceil(math.min(dt, 0.1) / (1 / 240)))
	local h = math.min(dt, 0.1) / steps
	for _ = 1, steps do
		v += ((target - x) * w * w - v * c) * h
		x += v * h
	end
	if target == 0 and math.abs(x) < 1e-4 and math.abs(v) < 1e-3 then
		x, v = 0, 0
	end
end

function SlideTilt.start()
	if started then
		return
	end
	started = true
	RunService:BindToRenderStep("GGSlideTilt", Enum.RenderPriority.First.Value, SlideTilt.step)
end

return SlideTilt
