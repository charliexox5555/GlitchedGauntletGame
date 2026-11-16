--!strict
-- Movement simulation (vault/04 Tech/Architecture.md).
-- Runs inside RunService:BindToSimulation on BOTH the server (every player)
-- and the client (its own character, predicted). The server's result is the
-- truth; the client predicts the same steps so movement feels instant.
--
-- Server Authority off (shared/Authority, 2026-11-11): each client owns its
-- own character, so the server steps only the bots here, and the client's own
-- MoveState lives in this module (`ownState`), not in the attribute: the
-- server publishes the state the client reports on that attribute for
-- everyone else, and that echo, a round trip old, must not feed the next step.
--
-- Rules for this file: only simulation-safe reads/writes, time() for time,
-- and state lives in attributes on the character (written only here).
-- Visual-only things (camera height, tilt, FOV) read these attributes in
-- RenderStepped (client MovementController).
--
-- Character attributes:
--   MoveState       "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"
--   SlideStart      time() the current slide began
--   SlideDir        the line the current slide holds (unit, flat; nil when not sliding)
--   SlideEnd        time() the last slide ended (cooldown)
--   SlideJumpSpeed  speed carried through the air after a slide-jump (0 = none)
--   CrouchHeld      last step's crouch input (to detect presses)
--   SprintBlock     time() until running is allowed again (firing cancels the run)
--   RunSince        time() you started moving forward this stretch (the run builds from it)
--   WasGrounded     last step's ground contact
--
-- Player attributes read here (set by the server):
--   MoveMult, AdsMult  equipped weapon's movement multipliers (WeaponService)
--   StatusMoveMult, StatusJumpMult, StatusGravityMult   status effects
--                      (StatusService: Hinder's slow, lower jump and floaty
--                      fall; nil = 1)
--
-- The predicted Mods (Simulation/Abilities) step first, inside this same
-- step, so a dash and the walk speed it needs are decided together.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Authority = require(script.Parent.Parent.Authority)
local Health = require(script.Parent.Parent.Health)
local MatchState = require(script.Parent.Parent.MatchState)
local Movement = require(script.Parent.Parent.Config.Movement)
local AbilitiesSim = require(script.Parent.Abilities)
local Pawns = require(script.Parent.Pawns)

local MovementSim = {}

local STEP = 1 / 60 -- the simulation's fixed step (Hz60, initialize)

local connection: RBXScriptConnection? = nil

-- The local player's own state while the client owns its movement (see the top).
local ownState: string? = nil
local ownCharacter: Model? = nil

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

-- `exit`: the speed you'll move at when the slide ends (sprint, walk or
-- crouch), so the slide runs out into it with no dip and no jump in speed.
local function slideSpeed(now: number, start: number, exit: number): number
	local t = math.clamp((now - start) / Movement.SLIDE_TIME, 0, 1)
	-- Ease in: hold most of the burst early (so slide-jumps carry speed),
	-- then settle to the exit speed at the end.
	return lerp(Movement.SLIDE_START_SPEED, exit, t * t)
end

local function stepCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or not Health.isAlive(humanoid) then
		return
	end
	local context = player:FindFirstChild("PlayContext")
	local now = time()

	AbilitiesSim.stepCharacter(player, character, humanoid, root, context, now)

	local crouchRaw = actionDown(context, "Crouch")
	local sprintIn = actionDown(context, "Sprint")
	local aimIn = actionDown(context, "Aim")
	local fireIn = actionDown(context, "Fire")

	local owned = not RunService:IsServer() and not Authority.server()
	local state = (character:GetAttribute("MoveState") :: string?) or "Idle"
	if owned and ownCharacter == character and ownState then
		state = ownState
	end
	local slideStart = (character:GetAttribute("SlideStart") :: number?) or 0
	local slideEnd = (character:GetAttribute("SlideEnd") :: number?) or -math.huge
	local slideDirAttr = character:GetAttribute("SlideDir")
	local slideDir: Vector3? = if typeof(slideDirAttr) == "Vector3" then slideDirAttr else nil
	local slideJump = (character:GetAttribute("SlideJumpSpeed") :: number?) or 0
	local crouchHeld = (character:GetAttribute("CrouchHeld") :: boolean?) == true
	local sprintBlock = (character:GetAttribute("SprintBlock") :: number?) or 0
	local runSince = character:GetAttribute("RunSince") :: number?
	local wasGrounded = (character:GetAttribute("WasGrounded") :: boolean?) ~= false

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local moveDir = humanoid.MoveDirection
	local moving = moveDir.Magnitude > 0.1
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local forward = moving and look.Magnitude > 0.01 and moveDir.Unit:Dot(look.Unit) > 0.3
	local flatSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	-- The Sprint key's one job (Movement.RUN_DELAY): held while you move, it
	-- overrides crouch, so you stand up and run. Crouch presses are still
	-- read from the key itself (`crouchRaw`): letting go of Sprint with C
	-- still down just crouches again, it doesn't count as a new press.
	local crouchIn = crouchRaw and not (sprintIn and moving)

	-- Firing cancels sprint instantly (Gunplay.md §1).
	if fireIn then
		sprintBlock = now + 0.35
	end

	local sliding = state == "Slide"
	local pressedCrouch = crouchRaw and not crouchHeld

	-- Running: no sprint key (Movement.RUN_DELAY). Moving forward for a moment
	-- breaks into the run; a slide keeps the stretch going.
	local mayRun = forward and not aimIn and not crouchIn and now >= sprintBlock
	if mayRun then
		runSince = runSince or now
		if sprintIn then
			-- Asked for: no wait.
			runSince = math.min(runSince, now - Movement.RUN_DELAY)
		end
	elseif not sliding then
		runSince = nil
	end
	local runTime = if runSince then now - runSince - Movement.RUN_DELAY else -1
	local running = runTime >= 0 and forward
	-- What the slide runs out into: still holding C = crouched, sprint held
	-- and going forward = straight back into the run, else a walk.
	local slideExit = if crouchIn
		then Movement.CROUCH_SPEED
		elseif running and not aimIn then Movement.SPRINT_SPEED
		else Movement.WALK_SPEED

	-- Leaving the ground mid-slide = slide-jump: keep most of the speed.
	if sliding and wasGrounded and not grounded then
		slideJump = math.max(
			slideSpeed(now, slideStart, slideExit) * Movement.SLIDE_JUMP_KEEP,
			Movement.WALK_SPEED
		)
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
			-- The slide's line: the way you're moving right now.
			local flat = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			slideDir = if flat.Magnitude > 1
				then flat.Unit
				elseif moving then (moveDir * Vector3.new(1, 0, 1)).Unit
				else nil
		end
	end
	-- A slide runs its full time once started (a tap is enough); jumping out
	-- of it is the slide-jump above. It also ends when something stops it.
	local stalled = now - slideStart >= Movement.SLIDE_STALL_GRACE
		and flatSpeed < Movement.SLIDE_STALL_SPEED
	if sliding and (stalled or now - slideStart >= Movement.SLIDE_TIME) then
		sliding = false
		slideEnd = now
	end

	-- Pick the state and its speed.
	local speed: number
	local canSprint = running and mayRun
	if not grounded and slideJump > 0 then
		state = "Air"
		speed = slideJump
	elseif sliding then
		state = "Slide"
		speed = slideSpeed(now, slideStart, slideExit)
	elseif crouchIn then
		state = "Crouch"
		speed = Movement.CROUCH_SPEED
	elseif canSprint then
		state = "Sprint"
		-- It builds from the walk instead of snapping to full speed. (Straight
		-- out of a slide it's already there.)
		local build = if now - slideEnd < Movement.RUN_RAMP
			then 1
			else math.clamp(runTime / Movement.RUN_RAMP, 0, 1)
		speed = lerp(Movement.WALK_SPEED, Movement.SPRINT_SPEED, build)
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
	local statusMove = (player:GetAttribute("StatusMoveMult") :: number?) or 1
	local mult = moveMult * statusMove
	if aimIn and state ~= "Slide" and state ~= "Air" then
		mult *= adsMult
	end
	local dashSpeed = AbilitiesSim.speedOverride(character, now)
	local walkSpeed = dashSpeed or speed * mult
	-- Spawn hold (select + 3-2-1): stand at the marker, look around only.
	-- Players and bots alike (bots step here on the server).
	local held = MatchState.isSpawnHold()
	if held then
		walkSpeed = 0
	end
	if math.abs(humanoid.WalkSpeed - walkSpeed) > 1e-3 then
		humanoid.WalkSpeed = walkSpeed
	end

	-- A slide holds its line (Movement.SLIDE_STEER): the Humanoid would go
	-- wherever the move keys and the camera point, so the slide's velocity is
	-- set here every step, the way a dash's is. The keys only bend the line a
	-- little; turning the camera doesn't turn the slide.
	if state == "Slide" and slideDir and not dashSpeed then
		local dir = slideDir
		local want = moveDir * Vector3.new(1, 0, 1)
		if want.Magnitude > 0.1 and Movement.SLIDE_STEER > 0 then
			want = want.Unit
			local angle = math.acos(math.clamp(dir:Dot(want), -1, 1))
			-- (Straight back is no direction to bend toward.)
			if angle > 1e-3 and angle < 2.8 then
				local turn = math.min(angle, math.rad(Movement.SLIDE_STEER) * STEP)
				local bent = dir * math.sin(angle - turn) + want * math.sin(turn)
				if bent.Magnitude > 1e-4 then
					dir = bent.Unit
				end
			end
		end
		slideDir = dir
		local vel = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(dir.X * walkSpeed, vel.Y, dir.Z * walkSpeed)
	elseif state ~= "Slide" then
		slideDir = nil
	end

	-- Status jump and gravity (Hinder: lower and floatier). The Humanoid's
	-- takeoff uses full gravity, so for a peak of JUMP_HEIGHT * jump under
	-- gravity * g the height to ask for is JUMP_HEIGHT * jump * g. In the air,
	-- part of gravity is given back every step.
	local jumpMult = (player:GetAttribute("StatusJumpMult") :: number?) or 1
	local gravityMult = (player:GetAttribute("StatusGravityMult") :: number?) or 1
	local jumpHeight = if held then 0 else Movement.JUMP_HEIGHT * jumpMult * gravityMult
	if math.abs(humanoid.JumpHeight - jumpHeight) > 1e-3 then
		humanoid.JumpHeight = jumpHeight
	end
	if not grounded and gravityMult < 1 then
		root.AssemblyLinearVelocity += Vector3.new(
			0,
			workspace.Gravity * (1 - gravityMult) * STEP,
			0
		)
	end
	-- Falling: a little extra gravity (Movement.FALL_GRAVITY), so jumps land
	-- crisply instead of floating down.
	if not grounded and root.AssemblyLinearVelocity.Y < 0 and Movement.FALL_GRAVITY > 1 then
		root.AssemblyLinearVelocity -= Vector3.new(
			0,
			workspace.Gravity * gravityMult * (Movement.FALL_GRAVITY - 1) * STEP,
			0
		)
	end

	if owned then
		ownState = state
		ownCharacter = character
	end
	set(character, "MoveState", state)
	set(character, "SlideStart", slideStart)
	set(character, "SlideEnd", slideEnd)
	set(character, "SlideDir", slideDir)
	set(character, "SlideJumpSpeed", slideJump)
	set(character, "CrouchHeld", if crouchRaw then true else nil)
	set(character, "SprintBlock", sprintBlock)
	set(character, "RunSince", runSince)
	set(character, "WasGrounded", grounded)
end

local function step(_dt: number)
	if RunService:IsServer() then
		-- Real players only under Server Authority: without it the server has
		-- none of their inputs, and each client moves its own character.
		if Authority.server() then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character then
					stepCharacter(player, character)
				end
			end
		end
		-- AI bots: their owner stands in for the Player (Simulation/Pawns).
		for _, pawn in Pawns.list() do
			stepCharacter(pawn.owner :: any, pawn.character)
		end
	else
		local player = Players.LocalPlayer
		local character = player and player.Character
		if character then
			stepCharacter(player, character)
		end
	end
end

-- The local player's move state as this client's simulation last left it
-- (nil until it has stepped, or under Server Authority: read the attribute).
function MovementSim.ownState(character: Model?): string?
	return if ownCharacter == character then ownState else nil
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
