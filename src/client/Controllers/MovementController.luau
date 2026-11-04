--!strict
-- Client side of movement. The movement itself (sprint, crouch, slide,
-- slide-jump) runs in shared/Simulation/Movement under Server Authority:
-- this controller starts the client's predicted copy of it and turns the
-- simulated state into camera feel (crouch/slide height, slide tilt, FOV
-- kick). It never sets WalkSpeed itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local MovementSim = require(ReplicatedStorage.Shared.Simulation.Movement)

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local ModFeelController = require(script.Parent.ModFeelController)

export type MoveState = "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"

local MovementController = {}

local player = Players.LocalPlayer

local state: MoveState = "Idle"
local cameraDrop = 0
local dropVelocity = 0
local fallSpeed = 0 -- the fastest downward speed of this time in the air

local function character(): Model?
	return player.Character
end

local function update(dt: number)
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not humanoid then
		return
	end
	local previous = state
	state = ((c:GetAttribute("MoveState") :: string?) or "Idle") :: MoveState
	local root = c:FindFirstChild("HumanoidRootPart")
	local vy = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Y else 0
	if state == "Air" and previous ~= "Air" and vy > Juice.JUMP.minRise then
		local jump = Juice.JUMP.sound
		AudioController.play(jump.id, { group = "Foley", volume = jump.volume, pitch = jump.pitch })
	end
	if state == "Air" then
		fallSpeed = math.max(fallSpeed, -vy)
	elseif previous == "Air" then
		-- Landed: the camera dips by how fast we fell (k^2), with a thud.
		local land = Juice.LAND
		if fallSpeed > land.minFall then
			local k = math.min(fallSpeed / land.fullFall, 1)
			-- An impulse on the height spring: its peak is about v / (omega * e).
			dropVelocity += land.dip * k * k * math.sqrt(Movement.CAMERA_STIFFNESS) * math.exp(1)
			if fallSpeed > land.soundFrom then
				AudioController.play(
					land.sound.id,
					{ group = "Foley", volume = land.sound.volume * (0.6 + 0.4 * k) }
				)
			end
		end
		fallSpeed = 0
	end
	if state == "Slide" and previous ~= "Slide" then
		-- Slide start: a quick FOV punch and the scrape.
		local slide = Juice.SLIDE
		CameraController.punchFov(slide.fovPunch, slide.punchTime)
		local cam = workspace.CurrentCamera
		local velocity = if root and root:IsA("BasePart")
			then root.AssemblyLinearVelocity
			else Vector3.zero
		ModFeelController.streaks(
			if cam
				then cam.CFrame:VectorToObjectSpace(velocity * Vector3.new(1, 0, 1))
				else Vector3.new(0, 0, -1),
			slide.streaks
		)
		AudioController.play(
			slide.sound.id,
			{ group = "Foley", volume = slide.sound.volume, cut = slide.sound.cut }
		)
	end

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
