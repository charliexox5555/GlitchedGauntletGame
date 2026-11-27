--!strict
-- Movement simulation (vault/04 Tech/Architecture.md).
-- Runs inside RunService:BindToSimulation on BOTH the server (every player)
-- and the client (its own character, predicted). The server's result is the
-- truth; the client predicts the same steps so movement feels instant.
--
-- Server Authority off (shared/Authority, 2026-11-11): each client owns its
-- own character, so the server steps only the bots here, and the client's own
-- MoveState lives in this module (`ownState`): the server publishes the
-- state the client reports in a replicated value for
-- everyone else, and that echo, a round trip old, must not feed the next step.
--
-- Rules for this file: only simulation-safe reads/writes, time() for time,
-- and per-character state lives in precreated values.
-- Visual-only things (camera height, tilt, FOV) read these values in
-- RenderStepped (client MovementController).
--
-- Character state fields:
--   MoveState       "Idle" | "Walk" | "Sprint" | "Crouch" | "Slide" | "Air"
--   SlideStart      time() the current slide began
--   SlideDir        the line the current slide holds (unit, flat; nil when not sliding)
--   SlideEnd        time() the last slide ended (cooldown)
--   SlideJumpSpeed  speed carried through the air after a slide-jump (0 = none)
--   CrouchHeld      last step's crouch input (to detect presses)
--   CrouchPressAt   time() of the last crouch press not yet used by a slide (the slide buffer)
--   SprintBlock     time() until running is allowed again (firing cancels the run)
--   RunSince        time() you started moving forward this stretch (the run builds from it)
--   WasGrounded     last step's ground contact
--   AirSince        time() this stretch off the floor began (nil on the floor)
--
-- Player state fields read here (set by the server):
--   MoveMult, AdsMult  equipped weapon's movement multipliers (WeaponService)
--   StatusMoveMult, StatusJumpMult, StatusGravityMult   status effects
--                      (StatusService: Hinder's slow, lower jump and floaty
--                      fall; nil = 1)
--
-- The predicted Mods (Simulation/Abilities) step first, inside this same
-- step, so a dash and the walk speed it needs are decided together.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Authority = require(script.Parent.Parent.Authority)
local Health = require(script.Parent.Parent.Health)
local MatchState = require(script.Parent.Parent.MatchState)
local Movement = require(script.Parent.Parent.Config.Movement)
local AbilitiesSim = require(script.Parent.Abilities)
local Fields = require(script.Parent.Fields)
local Pawns = require(script.Parent.Pawns)

local MovementSim = {}

local STEP = 1 / 60 -- the simulation's fixed step (Hz60, initialize)

local connection: RBXScriptConnection? = nil

-- The local player's own state while the client owns its movement (see the top).
local ownState: string? = nil
local ownCharacter: Model? = nil
-- How far the local player's touch stick is pushed (0-1; 1 off touch).
local ownPush = 1

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
	if StateValues.get(model, name) ~= value then
		StateValues.set(model, name, value)
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
	if not Fields.ready(character) then
		return
	end
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
	local state = (StateValues.get(character, "MoveState") :: string?) or "Idle"
	if owned and ownCharacter == character and ownState then
		state = ownState
	end
	local slideStart = (StateValues.get(character, "SlideStart") :: number?) or 0
	local slideEnd = (StateValues.get(character, "SlideEnd") :: number?) or -math.huge
	local slideDirAttr = StateValues.get(character, "SlideDir")
	local slideDir: Vector3? = if typeof(slideDirAttr) == "Vector3" then slideDirAttr else nil
	local slideJump = (StateValues.get(character, "SlideJumpSpeed") :: number?) or 0
	local crouchHeld = (StateValues.get(character, "CrouchHeld") :: boolean?) == true
	local crouchPressAt = (StateValues.get(character, "CrouchPressAt") :: number?) or -math.huge
	local sprintBlock = (StateValues.get(character, "SprintBlock") :: number?) or 0
	local runSince = StateValues.get(character, "RunSince") :: number?
	local wasGrounded = (StateValues.get(character, "WasGrounded") :: boolean?) ~= false
	local airSince = StateValues.get(character, "AirSince") :: number?

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	-- In the air for the move state (Movement.AIR_RISE / AIR_GRACE): a jump
	-- at once, a ledge after a moment, a stair step not at all.
	if grounded then
		airSince = nil
	else
		airSince = airSince or now
	end
	-- (The floor reading lags a takeoff by about 60 ms, measured: the
	-- Humanoid's own Jumping state doesn't.)
	local airborne = (
		not grounded
		and (
			root.AssemblyLinearVelocity.Y > Movement.AIR_RISE
			or now - (airSince or now) >= Movement.AIR_GRACE
		)
	)
		or (
			humanoid:GetState() == Enum.HumanoidStateType.Jumping
			and root.AssemblyLinearVelocity.Y > Movement.AIR_RISE
		)
	local moveDir = humanoid.MoveDirection
	local moving = moveDir.Magnitude > 0.1
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local forward = moving and look.Magnitude > 0.01 and moveDir.Unit:Dot(look.Unit) > 0.15
	local flatSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	-- The Sprint key's one job (Movement.RUN_DELAY): held while you move, it
	-- overrides crouch, so you stand up and run. Crouch presses are still
	-- read from the key itself (`crouchRaw`): letting go of Sprint with C
	-- still down just crouches again, it doesn't count as a new press.
	local crouchIn = crouchRaw and not (sprintIn and moving)

	-- Firing cancels sprint instantly (Gunplay.md §1).
	if fireIn then
		sprintBlock = now + 0.25
	end

	local sliding = state == "Slide"
	local pressedCrouch = crouchRaw and not crouchHeld

	-- The slide's crouch press is buffered (SLIDE_BUFFER): a press a moment
	-- early (still turning into the run, the last slide's cooldown not over)
	-- still slides while C is held, instead of dropping into a crouch. The way
	-- in is the run you'd be in without the crouch key (the run is automatic).
	if pressedCrouch then
		crouchPressAt = now
	end
	-- Settings AUTO SPRINT off (the own client sets the character's
	-- AutoSprint attribute, Shared/SettingsApply): the run needs Sprint held.
	local autoRun = character:GetAttribute("AutoSprint") ~= false or sprintIn
	local couldRun = forward and not aimIn and now >= sprintBlock and autoRun
	local slideAsked = crouchRaw and now - crouchPressAt <= Movement.SLIDE_BUFFER
	-- While that press waits, the run keeps going (a crouch would slow you
	-- under SLIDE_MIN_SPEED before the cooldown ends).
	if slideAsked and couldRun and grounded and not sliding then
		crouchIn = false
	end

	-- Running: no sprint key (Movement.RUN_DELAY). Moving forward for a moment
	-- breaks into the run; a slide keeps the stretch going.
	-- A touch stick pushed only a little walks (Movement.TOUCH_RUN_PUSH).
	local push = if owned and ownCharacter == character then ownPush else 1
	local mayRun = forward
		and not aimIn
		and not crouchIn
		and now >= sprintBlock
		and autoRun
		and push >= Movement.TOUCH_RUN_PUSH
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
	if grounded and not wasGrounded and StateValues.get(character, "Updrafting") ~= true then
		slideJump = 0
	end

	-- Start / end a slide (the press buffered above).
	if not sliding and slideAsked and couldRun and grounded then
		if now - slideEnd > Movement.SLIDE_COOLDOWN and flatSpeed >= Movement.SLIDE_MIN_SPEED then
			crouchPressAt = -math.huge -- one slide per press
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
	elseif canSprint or airborne then
		-- The run builds from the walk instead of snapping to full speed.
		-- (Straight out of a slide it's already there.) A jump out of it
		-- keeps that speed in the air (it used to stay "Sprint" up there).
		local build = if now - slideEnd < Movement.RUN_RAMP
			then 1
			else math.clamp(runTime / Movement.RUN_RAMP, 0, 1)
		state = if airborne then "Air" else "Sprint"
		speed = if canSprint
			then lerp(Movement.WALK_SPEED, Movement.SPRINT_SPEED, build)
			else Movement.WALK_SPEED
	elseif moving then
		state = "Walk"
		speed = Movement.WALK_SPEED
	else
		state = "Idle"
		speed = Movement.WALK_SPEED
	end

	-- The touch stick's push scales the speeds you steer (not a slide, a
	-- jump's carry or a dash): easing the stick back slows you smoothly.
	-- Idle too, so the first frame off a resting stick isn't a walk-speed lurch.
	-- A plain jump too (not a slide-jump's carry): a light push used to jump
	-- at full walk speed.
	if
		push < 1
		and (
			state == "Idle"
			or state == "Walk"
			or state == "Sprint"
			or state == "Crouch"
			or (state == "Air" and slideJump <= 0)
		)
	then
		speed *= push
	end

	local moveMult = (StateValues.get(player, "MoveMult") :: number?) or 1
	local adsMult = (StateValues.get(player, "AdsMult") :: number?) or 1
	local statusMove = (StateValues.get(player, "StatusMoveMult") :: number?) or 1
	local mult = moveMult * statusMove
	if aimIn and state ~= "Slide" and state ~= "Air" then
		mult *= adsMult
	end
	local dashSpeed = AbilitiesSim.speedOverride(character, now)
	local walkSpeed = dashSpeed or speed * mult
	-- Spawn hold (select + 3-2-1): stand at the marker, look around only.
	-- Players and bots alike (bots step here on the server).
	-- (This player's own match: a lobby server can run several, MatchState.)
	local held = MatchState.isSpawnHold(if typeof(player) == "Instance" then player else nil)
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
	local jumpMult = (StateValues.get(player, "StatusJumpMult") :: number?) or 1
	local gravityMult = (StateValues.get(player, "StatusGravityMult") :: number?) or 1
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
	set(character, "CrouchPressAt", if crouchPressAt > -math.huge then crouchPressAt else nil)
	set(character, "SprintBlock", sprintBlock)
	set(character, "RunSince", runSince)
	set(character, "WasGrounded", grounded)
	set(character, "AirSince", airSince)
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
-- (nil until it has stepped).
function MovementSim.ownState(character: Model?): string?
	return if ownCharacter == character then ownState else nil
end

-- The local player's touch stick push, 0-1 (TouchController; 1 = full, and
-- for every other input).
function MovementSim.setOwnPush(push: number)
	ownPush = if push == push then math.clamp(push, 0, 1) else 1
end

-- Call once on the server and once on each client host.
function MovementSim.initialize()
	if connection and connection.Connected then
		return
	end
	AbilitiesSim.initialize()
	local ok, freq = pcall(function()
		return Enum.StepFrequency.Hz60
	end)
	connection = RunService:BindToSimulation(step, if ok then freq else nil)
end

return MovementSim
