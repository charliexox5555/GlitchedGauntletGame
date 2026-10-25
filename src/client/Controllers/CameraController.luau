--!strict
-- Owns the local camera on top of Roblox's first-person camera module:
-- field of view (base + ADS zoom), recoil and slide tilt.
--
-- Recoil works by nudging Camera.CFrame after the camera module updates. The
-- module builds next frame's view from the current look vector, so a nudge
-- sticks (that's the part you have to pull down), while the "kick" part is
-- applied and then removed again over a few frames.

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
-- The OS cursor stays hidden (the HUD draws a crosshair) unless a menu needs it.
local cursorVisible = false

-- Recoil state, radians.
local pendingPitch = 0 -- not yet applied (smoothed in over a few frames)
local pendingYaw = 0
local kickPitch = 0 -- applied, and recovering back to 0
local kickYaw = 0

local KICK_APPLY_RATE = 45
local KICK_RECOVER_RATE = 9
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

-- One shot of recoil. `up`/`side` in degrees; `recover` = share that comes back by itself.
function CameraController.kick(up: number, side: number, recover: number)
	local upRad = math.rad(up)
	local sideRad = math.rad(side)
	pendingPitch += upRad
	pendingYaw += sideRad
	kickPitch += upRad * recover
	kickYaw += sideRad * recover
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

local function step(dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end

	-- FOV
	moveFov = lerp(moveFov, targetMoveFov, 1 - math.exp(-MOVE_FOV_RATE * dt))
	local zoomed = if zoomFov then lerp(baseFov, zoomFov, zoomAlpha) else baseFov
	local fov = zoomed + moveFov * (1 - zoomAlpha)
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
	local recoverT = 1 - math.exp(-KICK_RECOVER_RATE * dt)
	local rPitch = kickPitch * recoverT
	local rYaw = kickYaw * recoverT
	kickPitch -= rPitch
	kickYaw -= rYaw
	local pitch = dPitch - rPitch
	local yaw = dYaw - rYaw

	roll = lerp(roll, targetRoll, 1 - math.exp(-ROLL_RATE * dt))

	if math.abs(pitch) > 1e-6 or math.abs(yaw) > 1e-6 or math.abs(roll) > 1e-5 then
		local cf = cam.CFrame
		local rotation = CFrame.Angles(0, -yaw, 0) * (cf - cf.Position) * CFrame.Angles(pitch, 0, 0)
		cam.CFrame = CFrame.new(cf.Position) * rotation * CFrame.Angles(0, 0, roll)
	end
end

function CameraController.start()
	RunService:BindToRenderStep("GGCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraController
