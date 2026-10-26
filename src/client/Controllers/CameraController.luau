--!strict
-- Owns the local camera on top of Roblox's first-person camera module:
-- field of view (base + ADS zoom), recoil, shake, slide tilt, and smoothing
-- the followed position (Server Authority moves the character in uneven steps).
--
-- Recoil works by nudging Camera.CFrame after the camera module updates. The
-- module builds next frame's view from the current look vector, so a nudge
-- sticks (that's the part you have to pull down), while the "kick" part is
-- applied and then removed again over a few frames.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraConfig = require(ReplicatedStorage.Shared.Config.Camera)

local CameraController = {}

local baseFov: number = CameraConfig.DEFAULT_FOV
local zoomFov: number? = nil
local zoomAlpha = 0
local roll = 0
local targetRoll = 0
local moveFov = 0
local targetMoveFov = 0
local MOVE_FOV_RATE = 8
-- A one-off FOV kick (a Blink dash): rises fast, then eases back.
local punchDegrees = 0
local punchAt = -math.huge
local punchTime = 0.3
-- The OS cursor stays hidden (the HUD draws a crosshair) unless a menu needs it.
local cursorVisible = false

-- Recoil state, radians.
local pendingPitch = 0 -- not yet applied (smoothed in over a few frames)
local pendingYaw = 0
local kickPitch = 0 -- applied, and recovering back to 0 once firing stops
local kickYaw = 0
local kickRecoverTime = 0.3 -- the last shot's gun recoverTime
local lastKickAt = -math.huge
-- Recovery waits this long after a kick (so it starts when the spray stops).
local KICK_HOLD = 0.12

-- Shake on fire: a small noisy wobble that dies away (applied and removed again
-- each frame, so it never moves the aim).
-- Smoothed position the camera follows (see Config/Camera FOLLOW_*).
local followPos: Vector3? = nil
local followLast = Vector3.zero
local followVelocity = Vector3.zero
local followDt = 1 / 60

local shakeAmp = 0 -- radians
local shakePitch = 0 -- currently applied
local shakeYaw = 0
local SHAKE_DECAY = 16
local SHAKE_MAX = math.rad(1.2)
local SHAKE_FREQ = 38

local KICK_APPLY_RATE = 45
local ROLL_RATE = 10

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Sets the player's preferred FOV (from settings), clamped to the allowed range.
function CameraController.setBaseFov(fov: number)
	if fov ~= fov or fov == math.huge or fov == -math.huge then
		return
	end
	baseFov = math.clamp(fov, CameraConfig.MIN_FOV, CameraConfig.MAX_FOV)
end

function CameraController.getBaseFov(): number
	return baseFov
end

-- ADS zoom: `alpha` 0..1 blends from the base FOV to `fov`.
function CameraController.setZoom(fov: number?, alpha: number)
	zoomFov = fov
	zoomAlpha = math.clamp(alpha, 0, 1)
end

function CameraController.currentFov(): number
	local cam = Workspace.CurrentCamera
	return if cam then cam.FieldOfView else baseFov
end

-- One shot of recoil. `up`/`side` in degrees; `recover` = share that comes
-- back by itself, over `recoverTime` once the shooting stops.
function CameraController.kick(up: number, side: number, recover: number, recoverTime: number?)
	local upRad = math.rad(up)
	local sideRad = math.rad(side)
	pendingPitch += upRad
	pendingYaw += sideRad
	kickPitch += upRad * recover
	kickYaw += sideRad * recover
	kickRecoverTime = math.max(recoverTime or 0.3, 0.05)
	lastKickAt = os.clock()
end

-- Camera shake, in degrees of wobble (stacks up to a cap and dies away fast).
function CameraController.shake(degrees: number)
	if degrees ~= degrees or degrees <= 0 then
		return
	end
	shakeAmp = math.min(shakeAmp + math.rad(degrees), SHAKE_MAX)
end

-- Shows the OS cursor while a menu is open (the dev weapon menu).
function CameraController.setCursorVisible(visible: boolean)
	cursorVisible = visible
end

function CameraController.setRoll(degrees: number)
	targetRoll = math.rad(degrees)
end

-- Extra FOV from movement (sprint/slide kick), eased in and out. Faded out while aiming.
function CameraController.setMoveFov(degrees: number)
	targetMoveFov = degrees
end

-- A quick FOV kick of `degrees` over `duration` seconds (Mod dashes).
function CameraController.punchFov(degrees: number, duration: number)
	if degrees ~= degrees or duration ~= duration or duration <= 0 then
		return
	end
	punchDegrees = degrees
	punchAt = os.clock()
	punchTime = duration
end

local function punchNow(): number
	local t = (os.clock() - punchAt) / punchTime
	if t >= 1 or t < 0 then
		return 0
	elseif t < 0.2 then
		return punchDegrees * t / 0.2
	end
	local k = 1 - (t - 0.2) / 0.8
	return punchDegrees * k * k
end

-- Moves the camera by how far the smoothed character position is from the
-- predicted one, so walking renders at an even pace. The prediction uses a
-- velocity measured from the positions themselves and a smoothed frame time:
-- the raw frame dt jitters (about 15%) and the root's AssemblyLinearVelocity
-- reads non-zero Y even standing still, and either one makes the camera shake.
local function smoothFollow(cam: Camera, dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		followPos = nil
		return
	end
	local raw = root.Position
	local current = followPos
	if not current or (raw - current).Magnitude > CameraConfig.FOLLOW_SNAP or dt <= 0 then
		followPos = raw
		followLast = raw
		followVelocity = Vector3.zero
		return
	end
	followVelocity = followVelocity:Lerp(
		(raw - followLast) / dt,
		1 - math.exp(-CameraConfig.FOLLOW_VELOCITY_RATE * dt)
	)
	followLast = raw
	followDt += (dt - followDt) * (1 - math.exp(-CameraConfig.FOLLOW_VELOCITY_RATE * dt))
	local predicted = current + followVelocity * followDt
	local smoothed = predicted:Lerp(raw, 1 - math.exp(-CameraConfig.FOLLOW_CORRECTION * followDt))
	followPos = smoothed
	cam.CFrame += smoothed - raw
end

local function step(dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	smoothFollow(cam, dt)

	-- FOV
	moveFov = lerp(moveFov, targetMoveFov, 1 - math.exp(-MOVE_FOV_RATE * dt))
	local zoomed = if zoomFov then lerp(baseFov, zoomFov, zoomAlpha) else baseFov
	local fov = zoomed + (moveFov + punchNow()) * (1 - zoomAlpha)
	cam.FieldOfView = fov
	-- First person: the game draws its own crosshair, so hide the OS cursor.
	UserInputService.MouseIconEnabled = cursorVisible
	-- Keep aim speed consistent when zoomed.
	UserInputService.MouseDeltaSensitivity = math.clamp(zoomed / baseFov, 0.2, 1)

	-- Recoil: smooth the new kick in, then recover the recoverable share.
	local applyT = 1 - math.exp(-KICK_APPLY_RATE * dt)
	local dPitch = pendingPitch * applyT
	local dYaw = pendingYaw * applyT
	pendingPitch -= dPitch
	pendingYaw -= dYaw
	-- 95% of the recoverable climb returns within the gun's recoverTime.
	local recovering = os.clock() - lastKickAt > KICK_HOLD
	local recoverT = if recovering then 1 - math.exp(-3 / kickRecoverTime * dt) else 0
	local rPitch = kickPitch * recoverT
	local rYaw = kickYaw * recoverT
	kickPitch -= rPitch
	kickYaw -= rYaw
	local pitch = dPitch - rPitch
	local yaw = dYaw - rYaw

	-- Shake: swap last frame's offset for this frame's.
	shakeAmp *= math.exp(-SHAKE_DECAY * dt)
	local t = os.clock() * SHAKE_FREQ
	local sp = if shakeAmp > 1e-5 then math.noise(t, 0.31) * shakeAmp else 0
	local sy = if shakeAmp > 1e-5 then math.noise(0.73, t) * shakeAmp else 0
	local shakeRoll = if shakeAmp > 1e-5 then math.noise(t, 2.17) * shakeAmp * 1.5 else 0
	pitch += sp - shakePitch
	yaw += sy - shakeYaw
	shakePitch = sp
	shakeYaw = sy

	roll = lerp(roll, targetRoll, 1 - math.exp(-ROLL_RATE * dt))

	local totalRoll = roll + shakeRoll
	if math.abs(pitch) > 1e-6 or math.abs(yaw) > 1e-6 or math.abs(totalRoll) > 1e-5 then
		local cf = cam.CFrame
		local rotation = CFrame.Angles(0, -yaw, 0) * (cf - cf.Position) * CFrame.Angles(pitch, 0, 0)
		cam.CFrame = CFrame.new(cf.Position) * rotation * CFrame.Angles(0, 0, totalRoll)
	end
end

function CameraController.start()
	RunService:BindToRenderStep("GGCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraController
