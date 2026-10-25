--!strict
-- Client side of the third-person poses. The pose tracks themselves run in
-- shared/Simulation/Poses under Server Authority (the server poses everyone;
-- this starts the client's predicted copy for its own character). Here we
-- only feed the camera pitch into the "AimPitch" input action, which is
-- simulation input, so the server poses our arms with the same pitch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PoseSim = require(ReplicatedStorage.Shared.Simulation.Poses)

local InputController = require(script.Parent.InputController)

local PoseController = {}

-- Only send a new pitch when it moved this much (fraction of 90 degrees).
local PITCH_STEP = 0.01

local lastSent = 0

local function update()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	-- Input actions take -1..1: pitch over 90 degrees.
	local pitch = math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)) / (math.pi / 2)
	if math.abs(pitch - lastSent) >= PITCH_STEP then
		lastSent = pitch
		InputController.action("AimPitch"):Fire(pitch)
	end
end

function PoseController.start()
	PoseSim.initialize()
	RunService:BindToRenderStep("GGPosePitch", Enum.RenderPriority.Camera.Value + 3, update)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		lastSent = 0
	end)
end

return PoseController
