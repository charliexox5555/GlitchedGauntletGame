--!strict
-- Client side of movement. The movement itself (sprint, crouch, slide,
-- slide-jump) runs in shared/Simulation/Movement under Server Authority:
-- this controller starts the client's predicted copy of it and turns the
-- simulated state into camera feel (crouch/slide height, slide tilt, FOV
-- kick). It never sets WalkSpeed itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraDrop = require(ReplicatedStorage.Shared.CameraDrop)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local MovementSim = require(ReplicatedStorage.Shared.Simulation.Movement)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local InputMode = require(ReplicatedStorage.Shared.InputMode)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local ModFeelController = require(script.Parent.ModFeelController)

export type MoveState = "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"

local MovementController = {}

local player = Players.LocalPlayer

local state: MoveState = "Idle"
local cameraDrop = CameraDrop.new() -- crouch/slide eye height (shared/CameraDrop)
local fallSpeed = 0 -- the fastest downward speed of this time in the air
local groundFov = 0 -- the movement FOV kick we had when we last stood on something
-- Jump buffer and coyote time (Config/Movement JUMP_BUFFER, COYOTE_TIME).
local jumpAskedAt = -math.huge -- os.clock() of the last jump press
local groundedAt = -math.huge -- the last time we stood on something
local jumpedAt = -math.huge -- the last time the Humanoid actually jumped

local function character(): Model?
	return player.Character
end

-- The lobby hub's stick push for the simulation (Simulation/Movement
-- setLobbyPush): on a controller a light push walks slowly and the run needs
-- Movement.TOUCH_RUN_PUSH. The hub walks on Roblox's engine controls (no
-- PlayerModule to ask), so the push is read from the left stick itself,
-- rescaled past the player's STICK DEADZONE setting. Keys, rebound keys
-- (Shared/SettingsApply) and Roblox's touch thumbstick (which reports no push)
-- are a full push.
local function lobbyPush(): number
	if not InputMode.gamepad() then
		return 1
	end
	local zone = math.clamp((tonumber(SettingsApply.get("stickDeadzone")) or 0) / 100, 0, 0.9)
	for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local m = Vector2.new(input.Position.X, input.Position.Y).Magnitude
			if m ~= m or m <= zone then
				return 1 -- the stick isn't steering (a D-pad or keys might be)
			end
			return math.clamp((m - zone) / (1 - zone), 0, 1)
		end
	end
	return 1
end

local function update(dt: number)
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not humanoid then
		return
	end
	local previous = state
	if PlayZone.get(player) == "Lobby" then
		MovementSim.setLobbyPush(lobbyPush())
	end
	-- Our own simulation's state when this client owns its movement (the
	-- attribute also carries the server's echo of what we reported).
	state = (
		MovementSim.ownState(c)
		or (StateValues.get(c, "MoveState") :: string?)
		or "Idle"
	) :: MoveState
	local root = c:FindFirstChild("HumanoidRootPart")
	local vy = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Y else 0
	if state == "Air" and previous ~= "Air" and vy > Juice.JUMP.minRise then
		local jump = Juice.JUMP.sound
		AudioController.play(jump.id, { group = "Foley", volume = jump.volume, pitch = jump.pitch })
		-- The takeoff coil: the eye trails the body for a moment.
		CameraDrop.takeoff(cameraDrop, Juice.JUMP.takeoffDip)
	end
	if state == "Air" then
		fallSpeed = math.max(fallSpeed, -vy)
	elseif previous == "Air" then
		-- Landed: the camera dips by how fast we fell (k^2), with a thud.
		local land = Juice.LAND
		-- An impulse on the height spring (shared/CameraDrop.land).
		local k = CameraDrop.land(cameraDrop, fallSpeed)
		if k > 0 then
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
		-- The view leads into the slide, then settles (position only).
		local flat = velocity * Vector3.new(1, 0, 1)
		if flat.Magnitude > 1 then
			CameraController.lunge(flat.Unit * slide.lunge, slide.lungeTime)
		end
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

	-- Camera height: a damped spring so crouch/slide dips feel weighty, not
	-- snappy (shared/CameraDrop: spectators run the same spring on our MoveState).
	humanoid.CameraOffset = Vector3.new(0, -CameraDrop.step(cameraDrop, state, dt), 0)

	CameraController.setRoll(if state == "Slide" then Movement.SLIDE_CAMERA_TILT else 0)
	-- In the air the view keeps the FOV it left the ground with (plus a
	-- touch): a jump out of a run used to snap it back to walking FOV.
	if state ~= "Air" then
		groundFov = if state == "Slide"
			then Movement.SLIDE_FOV_KICK
			elseif state == "Sprint" then Movement.SPRINT_FOV_KICK
			else 0
	end
	CameraController.setMoveFov(
		if state == "Air" then groundFov + Movement.AIR_FOV_KICK else groundFov
	)

	-- Jump buffer and coyote time: a jump asked for just before landing, or
	-- just after running off an edge, still happens.
	local now = os.clock()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded then
		groundedAt = now
	end
	local asked = now - jumpAskedAt
	if asked <= math.max(Movement.JUMP_BUFFER, Movement.COYOTE_TIME) and now - jumpedAt > 0.25 then
		local buffered = grounded and asked <= Movement.JUMP_BUFFER
		local coyote = not grounded
			and now - groundedAt <= Movement.COYOTE_TIME
			and groundedAt > jumpedAt
		if (buffered or coyote) and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
			jumpAskedAt = -math.huge
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end

function MovementController.getState(): MoveState
	return state
end

function MovementController.isSprinting(): boolean
	return state == "Sprint"
end

-- Our touch Jump button (TouchController) sets Humanoid.Jump itself, which
-- fires no JumpRequest: it asks here so touch jumps get the same buffer and
-- coyote time as a key press.
function MovementController.requestJump()
	jumpAskedAt = os.clock()
end

function MovementController.start()
	RunService:BindToRenderStep("GGMovementView", Enum.RenderPriority.Camera.Value - 1, update)
	-- The lobby hub's glide (Simulation/Movement), every frame after Roblox's
	-- controls (Input) and Shared/SettingsApply's rebinds (Input + 1).
	RunService:BindToRenderStep(
		"GGLobbyGlide",
		Enum.RenderPriority.Input.Value + 2,
		MovementSim.lobbyGlideStep
	)
	local function watchJumps(c: Model)
		local humanoid = c:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					jumpedAt = os.clock()
				end
			end)
		end
	end
	player.CharacterAdded:Connect(function(c)
		CameraDrop.reset(cameraDrop)
		task.spawn(watchJumps, c)
	end)
	if player.Character then
		task.spawn(watchJumps, player.Character)
	end
	UserInputService.JumpRequest:Connect(function()
		jumpAskedAt = os.clock()
	end)
end

return MovementController
