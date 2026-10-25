--!strict
-- Owns the local camera's field of view. Each client gets its own Camera at
-- runtime, so the FOV has to be applied here rather than saved in the place.
-- First-person lock itself is StarterPlayer.CameraMode = LockFirstPerson.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CameraConfig = require(ReplicatedStorage.Shared.Config.Camera)

local CameraController = {}

local baseFov: number = CameraConfig.DEFAULT_FOV
local cameraConnection: RBXScriptConnection? = nil

local function applyFov()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = baseFov
	end
end

-- Sets the player's preferred FOV (from settings), clamped to the allowed range.
function CameraController.setBaseFov(fov: number)
	if fov ~= fov or fov == math.huge or fov == -math.huge then
		return
	end
	baseFov = math.clamp(fov, CameraConfig.MIN_FOV, CameraConfig.MAX_FOV)
	applyFov()
end

function CameraController.getBaseFov(): number
	return baseFov
end

function CameraController.start()
	applyFov()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFov)
end

return CameraController
