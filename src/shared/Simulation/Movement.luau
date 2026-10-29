--!strict
-- Movement simulation for Server Authority (vault/04 Tech/Architecture.md).
-- Runs inside RunService:BindToSimulation on BOTH the server (every player)
-- and the client (its own character, predicted). The server's result is the
-- truth; the client predicts the same steps so movement feels instant.
--
-- Rules for this file: only simulation-safe reads/writes, time() for time,
-- and state lives in attributes on the character (written only here).
-- Visual-only things (camera height, tilt, FOV) read these attributes in
-- RenderStepped (client MovementController).
--
-- Character attributes:
--   MoveState       "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"
--   SlideStart      time() the current slide began
--   SlideEnd        time() the last slide ended (cooldown)
--   SlideJumpSpeed  speed carried through the air after a slide-jump (0 = none)
--   CrouchHeld      last step's crouch input (to detect presses)
--   SprintBlock     time() until sprinting is allowed again (firing cancels sprint)
--   WasGrounded     last step's ground contact
--
-- Player attributes read here (set by the server):
--   MoveMult, AdsMult  equipped weapon's movement multipliers (WeaponService)
--   ModSpeedMult       Mod slows and boosts (ModService; Lag Field later)
--
-- The predicted Mods (Simulation/Abilities) step first, inside this same
-- step, so a dash and the walk speed it needs are decided together.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Movement = require(script.Parent.Parent.Config.Movement)
local AbilitiesSim = require(script.Parent.Abilities)

local MovementSim = {}

local connection: RBXScriptConnection? = nil

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function actionDown(context: Instance?, name: string): boolean
	local action = context and context:FindFirstChild(name)
	if action and action:IsA("InputAction") then
		return action:GetState() == true
	end
	return false
end

local function set(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

local function slideSpeed(now: number, start: number): number
	local t = math.clamp((now - start) / Movement.SLIDE_TIME, 0, 1)
	-- Ease in: hold most of the burst early (so slide-jumps carry speed),
	-- then drop into crouch speed at the end.
	return lerp(Movement.SLIDE_START_SPEED, Movement.CROUCH_SPEED, t * t)
end

local function stepCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end
	local context = player:FindFirstChild("PlayContext")
	local now = time()

	AbilitiesSim.stepCharacter(player, character, humanoid, root, context, now)

	local sprintIn = actionDown(context, "Sprint")
	local crouchIn = actionDown(context, "Crouch")
	local aimIn = actionDown(context, "Aim")
	local fireIn = actionDown(context, "Fire")

	local state = (character:GetAttribute("MoveState") :: string?) or "Idle"
	local slideStart = (character:GetAttribute("SlideStart") :: number?) or 0
	local slideEnd = (character:GetAttribute("SlideEnd") :: number?) or -math.huge
	local slideJump = (character:GetAttribute("SlideJumpSpeed") :: number?) or 0
	local crouchHeld = (character:GetAttribute("CrouchHeld") :: boolean?) == true
	local sprintBlock = (character:GetAttribute("SprintBlock") :: number?) or 0
	local wasGrounded = (character:GetAttribute("WasGrounded") :: boolean?) ~= false

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local moveDir = humanoid.MoveDirection
	local moving = moveDir.Magnitude > 0.1
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local forward = moving and look.Magnitude > 0.01 and moveDir.Unit:Dot(look.Unit) > 0.3
	local flatSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude

	-- Firing cancels sprint instantly (Gunplay.md §1).
	if fireIn then
		sprintBlock = now + 0.35
	end

	local sliding = state == "Slide"
	local pressedCrouch = crouchIn and not crouchHeld

	-- Leaving the ground mid-slide = slide-jump: keep most of the speed.
	if sliding and wasGrounded and not grounded then
		slideJump =
			math.max(slideSpeed(now, slideStart) * Movement.SLIDE_JUMP_KEEP, Movement.WALK_SPEED)
		sliding = false
		slideEnd = now
	end
	-- Landed (not on the step an Updraft leaves the floor: it ends itself on
	-- the real landing, before this runs).
	if grounded and not wasGrounded and character:GetAttribute("Updrafting") ~= true then
		slideJump = 0
	end

	-- Start / end a slide.
	if not sliding and pressedCrouch and state == "Sprint" and grounded then
		if now - slideEnd > Movement.SLIDE_COOLDOWN and flatSpeed >= Movement.SLIDE_MIN_SPEED then
			sliding = true
			slideStart = now
		end
	end
	if sliding and (not crouchIn or now - slideStart >= Movement.SLIDE_TIME) then
		sliding = false
		slideEnd = now
	end

	-- Pick the state and its speed.
	local speed: number
	local canSprint = sprintIn and forward and not aimIn and not crouchIn and now >= sprintBlock
	if not grounded and slideJump > 0 then
		state = "Air"
		speed = slideJump
	elseif sliding then
		state = "Slide"
		speed = slideSpeed(now, slideStart)
	elseif crouchIn then
		state = "Crouch"
		speed = Movement.CROUCH_SPEED
	elseif canSprint then
		state = "Sprint"
		speed = Movement.SPRINT_SPEED
	elseif not grounded then
		state = "Air"
		speed = Movement.WALK_SPEED
	elseif moving then
		state = "Walk"
		speed = Movement.WALK_SPEED
	else
		state = "Idle"
		speed = Movement.WALK_SPEED
	end

	local moveMult = (player:GetAttribute("MoveMult") :: number?) or 1
	local adsMult = (player:GetAttribute("AdsMult") :: number?) or 1
	local modMult = (player:GetAttribute("ModSpeedMult") :: number?) or 1
	local mult = moveMult * modMult
	if aimIn and state ~= "Slide" and state ~= "Air" then
		mult *= adsMult
	end
	local walkSpeed = AbilitiesSim.speedOverride(character, now) or speed * mult
	if math.abs(humanoid.WalkSpeed - walkSpeed) > 1e-3 then
		humanoid.WalkSpeed = walkSpeed
	end

	set(character, "MoveState", state)
	set(character, "SlideStart", slideStart)
	set(character, "SlideEnd", slideEnd)
	set(character, "SlideJumpSpeed", slideJump)
	set(character, "CrouchHeld", crouchIn)
	set(character, "SprintBlock", sprintBlock)
	set(character, "WasGrounded", grounded)
end

local function step(_dt: number)
	if RunService:IsServer() then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				stepCharacter(player, character)
			end
		end
	else
		local player = Players.LocalPlayer
		local character = player and player.Character
		if character then
			stepCharacter(player, character)
		end
	end
end

-- Call once on the server and once on each client.
function MovementSim.initialize()
	if connection then
		return
	end
	AbilitiesSim.initialize()
	local ok, freq = pcall(function()
		return Enum.StepFrequency.Hz60
	end)
	connection = RunService:BindToSimulation(step, if ok then freq else nil)
end

return MovementSim
