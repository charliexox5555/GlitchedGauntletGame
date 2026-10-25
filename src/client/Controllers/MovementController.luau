--!strict
-- Client side of movement. The movement itself (sprint, crouch, slide,
-- slide-jump) runs in shared/Simulation/Movement under Server Authority:
-- this controller starts the client's predicted copy of it and turns the
-- simulated state into camera feel (crouch/slide height, slide tilt, FOV
-- kick). It never sets WalkSpeed itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local MovementSim = require(ReplicatedStorage.Shared.Simulation.Movement)

local CameraController = require(script.Parent.CameraController)

export type MoveState = "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"

local MovementController = {}

local player = Players.LocalPlayer

local state: MoveState = "Idle"
local cameraDrop = 0
local dropVelocity = 0

local function character(): Model?
	return player.Character
end

local function update(dt: number)
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not humanoid then
		return
	end
	state = ((c:GetAttribute("MoveState") :: string?) or "Idle") :: MoveState

	-- Camera height: a damped spring so crouch/slide dips feel weighty, not snappy.
	local target = if state == "Slide"
		then Movement.SLIDE_CAMERA_DROP
		elseif state == "Crouch" then Movement.CROUCH_CAMERA_DROP
		else 0
	local stiffness = Movement.CAMERA_STIFFNESS
	local damping = 2 * math.sqrt(stiffness) * Movement.CAMERA_DAMPING_RATIO
	local accel = (target - cameraDrop) * stiffness - dropVelocity * damping
	dropVelocity += accel * dt
	cameraDrop += dropVelocity * dt
	humanoid.CameraOffset = Vector3.new(0, -cameraDrop, 0)

	CameraController.setRoll(if state == "Slide" then Movement.SLIDE_CAMERA_TILT else 0)
	CameraController.setMoveFov(
		if state == "Slide"
			then Movement.SLIDE_FOV_KICK
			elseif state == "Sprint" then Movement.SPRINT_FOV_KICK
			else 0
	)
end

function MovementController.getState(): MoveState
	return state
end

function MovementController.isSprinting(): boolean
	return state == "Sprint"
end

function MovementController.start()
	MovementSim.initialize()
	RunService:BindToRenderStep("GGMovementView", Enum.RenderPriority.Camera.Value - 1, update)
	player.CharacterAdded:Connect(function()
		cameraDrop = 0
		dropVelocity = 0
	end)
end

return MovementController
