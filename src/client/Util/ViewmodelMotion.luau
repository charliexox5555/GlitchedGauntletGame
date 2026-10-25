--!strict
-- Procedural motion of the whole first-person rig (Gunplay.md §6): walk bob,
-- idle breathing, turn sway, strafe tilt, fall lift and landing dip. It all
-- adds up to ONE offset from the camera (the rig's root), so the gun and both
-- arms move together as a single unit. Numbers live in Config/Viewmodel.
--
-- Everything is frame-rate independent: springs are critically damped and
-- stepped with their exact solution, the bob phase advances by time (its
-- speed and size are eased, never jump), and sway is pushed by how far the
-- view turned rather than by a per-frame turn rate (which jitters with mouse
-- polling and high frame rates).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

export type Input = {
	camera: CFrame,
	velocity: Vector3, -- character velocity, world space
	grounded: boolean, -- walking on the ground (not jumping, falling or sliding)
	sprinting: boolean,
	ads: number, -- 0..1, eased
}

export type Motion = {
	velocity: Vector3, -- smoothed character velocity
	lastCamera: CFrame?,
	swayPos: Vector3, -- pitch, yaw (radians)
	swayVel: Vector3,
	tiltPos: Vector3, -- roll (radians), sideways drift (studs), lift (studs)
	tiltVel: Vector3,
	bobAmount: number, -- 0.. (1 = walk speed)
	bobAmountVel: number,
	bobSprint: number, -- 0..1 blend from the walk loop to the sprint loop
	bobSprintVel: number,
	bobPhase: number,
	breathPhase: number,
	wasGrounded: boolean,
}

local ViewmodelMotion = {}

local DEG = math.pi / 180
local TAU = 2 * math.pi

-- One exact step of a critically damped spring toward `target`.
local function spring(
	x: number,
	v: number,
	target: number,
	omega: number,
	dt: number
): (number, number)
	local d = x - target
	local j = (v + omega * d) * dt
	local e = math.exp(-omega * dt)
	return target + (d + j) * e, (v - omega * j) * e
end

local function spring3(
	x: Vector3,
	v: Vector3,
	target: Vector3,
	omega: number,
	dt: number
): (Vector3, Vector3)
	local d = x - target
	local j = (v + d * omega) * dt
	local e = math.exp(-omega * dt)
	return target + (d + j) * e, (v - j * omega) * e
end

ViewmodelMotion.spring = spring

-- Smoothly limits |x| to `max` (no hard corner when the sway saturates).
local function soft(x: number, max: number): number
	return max * math.tanh(x / max)
end

function ViewmodelMotion.new(): Motion
	return {
		velocity = Vector3.zero,
		lastCamera = nil,
		swayPos = Vector3.zero,
		swayVel = Vector3.zero,
		tiltPos = Vector3.zero,
		tiltVel = Vector3.zero,
		bobAmount = 0,
		bobAmountVel = 0,
		bobSprint = 0,
		bobSprintVel = 0,
		bobPhase = 0,
		breathPhase = 0,
		wasGrounded = true,
	}
end

function ViewmodelMotion.reset(m: Motion)
	local fresh = ViewmodelMotion.new()
	for k, v in fresh :: any do
		(m :: any)[k] = v
	end
end

-- Advances the motion by `dt` and returns the rig's root offset from the camera.
function ViewmodelMotion.step(m: Motion, input: Input, dt: number): CFrame
	local cam = input.camera
	local ads = input.ads
	m.velocity = m.velocity:Lerp(input.velocity, 1 - math.exp(-VM.VELOCITY_SMOOTHING * dt))
	local localVel = cam:VectorToObjectSpace(m.velocity)
	local flatSpeed = Vector2.new(m.velocity.X, m.velocity.Z).Magnitude

	-- Sway: the view turned by (pitch, yaw) since last frame; push the spring
	-- the other way so the gun trails the turn, then let it settle back.
	local last = m.lastCamera
	if last then
		local turnPitch, turnYaw = last:ToObjectSpace(cam):ToEulerAnglesYXZ()
		m.swayVel -= Vector3.new(turnPitch, turnYaw, 0) * VM.SWAY_GAIN
	end
	m.lastCamera = cam
	m.swayPos, m.swayVel = spring3(m.swayPos, m.swayVel, Vector3.zero, VM.SWAY_FREQUENCY, dt)
	local swayScale = 1 + (VM.ADS_SWAY_SCALE - 1) * ads
	local swayPitch = soft(m.swayPos.X, VM.SWAY_MAX) * swayScale
	local swayYaw = soft(m.swayPos.Y, VM.SWAY_MAX) * swayScale

	-- Strafe roll and drift, fall lift, landing dip (one spring, three axes).
	if input.grounded and not m.wasGrounded then
		local fall = math.clamp(-input.velocity.Y / 50, 0, 1)
		m.tiltVel -= Vector3.new(0, 0, VM.LAND_KICK * fall)
	end
	m.wasGrounded = input.grounded
	local moveScale = 1 + (VM.ADS_MOVE_SCALE - 1) * ads
	local tiltTarget = Vector3.new(
		-localVel.X * VM.STRAFE_ROLL,
		-localVel.X * VM.STRAFE_SHIFT,
		math.clamp(-m.velocity.Y * VM.FALL_LAG, -VM.FALL_LAG_MAX, VM.FALL_LAG_MAX)
	) * moveScale
	m.tiltPos, m.tiltVel = spring3(m.tiltPos, m.tiltVel, tiltTarget, VM.TILT_FREQUENCY, dt)

	-- Walk bob: the loop speed and size ease toward what the movement asks
	-- for, and the phase only ever moves forward smoothly.
	local amountTarget = if input.grounded
		then math.clamp(flatSpeed / VM.BOB_REFERENCE_SPEED, 0, 1.5)
		else 0
	m.bobAmount, m.bobAmountVel = spring(m.bobAmount, m.bobAmountVel, amountTarget, VM.BOB_EASE, dt)
	m.bobSprint, m.bobSprintVel =
		spring(m.bobSprint, m.bobSprintVel, if input.sprinting then 1 else 0, VM.BOB_EASE, dt)
	local sprint = math.clamp(m.bobSprint, 0, 1)
	local frequency = VM.BOB_WALK_FREQUENCY
		+ (VM.BOB_SPRINT_FREQUENCY - VM.BOB_WALK_FREQUENCY) * sprint
	m.bobPhase = (m.bobPhase + dt * frequency * TAU) % TAU
	-- Amplitude per unit of speed: the sprint loop is wider, but sprinting is
	-- also faster, so divide that back out to land on BOB_SPRINT at sprint speed.
	local amount = math.max(m.bobAmount, 0) * (1 + (VM.ADS_BOB_SCALE - 1) * ads)
	local sprintAmount = Movement.SPRINT_SPEED / VM.BOB_REFERENCE_SPEED
	local bobPos = VM.BOB_WALK.pos:Lerp(VM.BOB_SPRINT.pos / sprintAmount, sprint) * amount
	local bobRot = VM.BOB_WALK.rot:Lerp(VM.BOB_SPRINT.rot / sprintAmount, sprint) * amount
	local s1, c2 = math.sin(m.bobPhase), math.cos(2 * m.bobPhase)
	local bobOffset = Vector3.new(s1 * bobPos.X, -c2 * bobPos.Y, 0)
	local bobPitch = c2 * bobRot.X * DEG
	local bobYaw = s1 * bobRot.Y * DEG
	local bobRoll = -s1 * bobRot.Z * DEG

	-- Breathing: a slow drift, faded out while moving and calmer while aiming.
	m.breathPhase = (m.breathPhase + dt * VM.BREATH_RATE * TAU) % (TAU * 2)
	local breathScale = math.max(0, 1 - 0.7 * math.clamp(m.bobAmount, 0, 1))
		* (1 + (VM.ADS_BREATH_SCALE - 1) * ads)
	local breathOffset = Vector3.new(
		math.sin(m.breathPhase * 0.5) * VM.BREATH_AMOUNT.X,
		math.sin(m.breathPhase) * VM.BREATH_AMOUNT.Y,
		0
	) * breathScale
	local breathPitch = math.sin(m.breathPhase + 0.6) * VM.BREATH_ROTATION * DEG * breathScale

	local offset = bobOffset
		+ breathOffset
		+ Vector3.new(
			-swayYaw * VM.SWAY_SHIFT + m.tiltPos.Y,
			swayPitch * VM.SWAY_SHIFT + m.tiltPos.Z,
			0
		)
	local rotation = CFrame.Angles(
		swayPitch + bobPitch + breathPitch,
		swayYaw + bobYaw,
		m.tiltPos.X + bobRoll + swayYaw * 0.3
	)
	local pivot = VM.MOTION_PIVOT
	return CFrame.new(offset + pivot) * rotation * CFrame.new(-pivot)
end

return ViewmodelMotion
