--!strict
-- RIVALS-style movement on the local Humanoid (Gunplay.md §1): walk, sprint,
-- crouch, slide (sprint + crouch) and slide-jump. Weapons scale the speeds.
--
-- The client simulates its own character (Roblox default), so this is the
-- feel layer; the server bounds what matters (shots, damage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Movement = require(ReplicatedStorage.Shared.Config.Movement)

local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)

export type MoveState = "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"

local MovementController = {}

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local state: MoveState = "Idle"
local crouching = false
local sliding = false
local slideStart = 0
local slideEndedAt = -math.huge
local slideJumpSpeed: number? = nil
local sprintBlockedUntil = 0

local weaponMultiplier = 1
local adsMultiplier = 1
local aiming = false

local characterConnections: { RBXScriptConnection } = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function grounded(h: Humanoid): boolean
	return h.FloorMaterial ~= Enum.Material.Air
end

local function movingForward(h: Humanoid): boolean
	local cam = Workspace.CurrentCamera
	if not cam or h.MoveDirection.Magnitude < 0.1 then
		return false
	end
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		return true
	end
	return h.MoveDirection.Unit:Dot(look.Unit) > 0.3
end

local function wantsSprint(h: Humanoid): boolean
	if os.clock() < sprintBlockedUntil or aiming or crouching then
		return false
	end
	if not movingForward(h) then
		return false
	end
	if InputController.isDown("Sprint") then
		return true
	end
	-- Touch: auto-sprint with the stick pushed all the way.
	return UserInputService.TouchEnabled and h.MoveDirection.Magnitude > 0.95
end

local function startSlide()
	sliding = true
	crouching = true
	slideStart = os.clock()
end

local function endSlide()
	if sliding then
		sliding = false
		slideEndedAt = os.clock()
	end
end

local function slideSpeed(): number
	local t = math.clamp((os.clock() - slideStart) / Movement.SLIDE_TIME, 0, 1)
	-- Ease in: hold most of the burst early (so slide-jumps carry speed),
	-- then drop into crouch speed at the end.
	return lerp(Movement.SLIDE_START_SPEED, Movement.CROUCH_SPEED, t * t)
end

local function onCrouchPressed()
	local h = humanoid
	if not h or h.Health <= 0 then
		return
	end
	local canSlide = state == "Sprint"
		and grounded(h)
		and os.clock() - slideEndedAt > Movement.SLIDE_COOLDOWN
		and (
			root
			and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
				>= Movement.SLIDE_MIN_SPEED
		)
	if canSlide then
		startSlide()
	else
		crouching = true
	end
end

local function onCrouchReleased()
	crouching = false
	endSlide()
end

local function update(dt: number)
	local h = humanoid
	if not h or h.Health <= 0 or not h.Parent then
		return
	end
	local onGround = grounded(h)

	if sliding then
		if os.clock() - slideStart >= Movement.SLIDE_TIME then
			endSlide()
		end
	end

	local speed: number
	if not onGround and slideJumpSpeed then
		state = "Air"
		speed = slideJumpSpeed
	elseif sliding then
		state = "Slide"
		speed = slideSpeed()
	elseif crouching then
		state = "Crouch"
		speed = Movement.CROUCH_SPEED
	elseif wantsSprint(h) then
		state = "Sprint"
		speed = Movement.SPRINT_SPEED
	elseif not onGround then
		state = "Air"
		speed = Movement.WALK_SPEED
	elseif h.MoveDirection.Magnitude > 0.1 then
		state = "Walk"
		speed = Movement.WALK_SPEED
	else
		state = "Idle"
		speed = Movement.WALK_SPEED
	end

	local mult = weaponMultiplier
	if aiming and not sliding then
		mult *= adsMultiplier
	end
	h.WalkSpeed = speed * mult

	-- Crouch / slide camera height and tilt.
	local drop = if sliding
		then Movement.SLIDE_CAMERA_DROP
		elseif crouching then Movement.CROUCH_CAMERA_DROP
		else 0
	local target = Vector3.new(0, -drop, 0)
	h.CameraOffset = h.CameraOffset:Lerp(target, 1 - math.exp(-Movement.CAMERA_LERP * dt))
	CameraController.setRoll(if sliding then Movement.SLIDE_CAMERA_TILT else 0)
end

local function bindCharacter(character: Model)
	for _, c in characterConnections do
		c:Disconnect()
	end
	table.clear(characterConnections)
	local h = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local r = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not h or not r then
		return
	end
	humanoid = h
	root = r
	sliding = false
	crouching = false
	slideJumpSpeed = nil
	state = "Idle"

	table.insert(
		characterConnections,
		h.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				if sliding then
					-- Slide-jump: keep most of the slide's speed through the air.
					slideJumpSpeed =
						math.max(slideSpeed() * Movement.SLIDE_JUMP_KEEP, Movement.WALK_SPEED)
					endSlide()
					crouching = false
				end
			elseif
				new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
			then
				slideJumpSpeed = nil
			end
		end)
	)
end

-- API used by the weapon system ------------------------------------------------

function MovementController.getState(): MoveState
	return state
end

function MovementController.isSprinting(): boolean
	return state == "Sprint"
end

-- Firing cancels sprint instantly (Gunplay.md §1).
function MovementController.blockSprint(seconds: number)
	sprintBlockedUntil = math.max(sprintBlockedUntil, os.clock() + seconds)
end

function MovementController.setWeaponMultipliers(move: number, ads: number)
	weaponMultiplier = move
	adsMultiplier = ads
end

function MovementController.setAiming(value: boolean)
	aiming = value
end

function MovementController.start()
	InputController.onPressed("Crouch", onCrouchPressed)
	InputController.onReleased("Crouch", onCrouchReleased)
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	RunService.RenderStepped:Connect(update)
end

return MovementController
