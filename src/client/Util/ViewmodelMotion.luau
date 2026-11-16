--!strict
-- Procedural motion of the whole first-person rig (Gunplay.md §6): walk bob,
-- the sprint swing, idle breathing, turn sway, strafe tilt (aimed: a lean into
-- the strafe), fore-aft weight, fall lift and landing dip, and the slide's
-- kick and scrape chatter. It all adds up to ONE offset from the camera (the
-- rig's root), so the gun and both arms move together as a single unit.
-- Numbers live in Config/Viewmodel.
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
	sliding: boolean,
	crouching: boolean,
	ads: number, -- 0..1, eased
}

export type Motion = {
	velocity: Vector3, -- smoothed character velocity
	lastCamera: CFrame?,
	swayPos: Vector3, -- pitch, yaw (radians)
	swayVel: Vector3,
	tiltPos: Vector3, -- roll (radians), sideways drift (studs), lift (studs)
	tiltVel: Vector3,
	surgePos: number, -- forward speed the fore-aft weight has caught up with (studs/s)
	surgeVel: number,
	airPos: Vector3, -- in the air: muzzle tip, outward roll (radians), flare 0..1
	airVel: Vector3,
	wasCrouching: boolean,
	bouncePos: number, -- the springy up-down channel (studs, + = up)
	bounceVel: number,
	slide: number, -- 0..1, eased: how much of the slide chatter shows
	slideVel: number,
	slidePhase: number,
	wasSliding: boolean,
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
ViewmodelMotion.spring3 = spring3

-- One exact step of an underdamped spring toward 0 (`zeta` < 1): it
-- overshoots and rings. `omega` in rad/s.
local function bounce(
	x: number,
	v: number,
	omega: number,
	zeta: number,
	dt: number
): (number, number)
	local decay = zeta * omega
	local wd = omega * math.sqrt(1 - zeta * zeta)
	local e = math.exp(-decay * dt)
	local c, s = math.cos(wd * dt), math.sin(wd * dt)
	local b = (v + decay * x) / wd
	return e * (x * c + b * s), e * ((b * wd - decay * x) * c - (x * wd + decay * b) * s)
end

ViewmodelMotion.bounce = bounce

-- A melee hit's drag (VM.HIT_DRAG): the share of normal speed a move plays
-- at with `left` of `total` seconds of the drag to go. It dips smoothly to
-- the floor and eases back, so the move never holds a frame.
function ViewmodelMotion.dragRate(left: number, total: number): number
	local d = VM.HIT_DRAG
	if total <= 0 or left <= 0 then
		return 1
	end
	local k = math.clamp(1 - left / total, 0, 1)
	local dip = if k < d.into then k / d.into else 1 - (k - d.into) / (1 - d.into)
	dip = dip * dip * (3 - 2 * dip)
	return 1 - (1 - d.floor) * dip
end

-- How long a drag lasts for an attack whose hit-stop is `seconds`.
function ViewmodelMotion.dragTime(seconds: number): number
	local d = VM.HIT_DRAG
	return math.clamp(seconds * d.stretch, 0, d.max)
end

-- The velocity that makes that spring peak at 1 (from rest).
local function bounceKick(omega: number, zeta: number): number
	local root = math.sqrt(1 - zeta * zeta)
	return omega / math.exp(-zeta * math.atan2(root, zeta) / root)
end

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
		surgePos = 0,
		surgeVel = 0,
		airPos = Vector3.zero,
		airVel = Vector3.zero,
		wasCrouching = false,
		bouncePos = 0,
		bounceVel = 0,
		slide = 0,
		slideVel = 0,
		slidePhase = 0,
		wasSliding = false,
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
	local bounceOmega = VM.BOUNCE_FREQUENCY * TAU
	local kick = bounceKick(bounceOmega, VM.BOUNCE_DAMPING)
	if input.grounded and not m.wasGrounded and not m.wasSliding then
		local fall = math.clamp(-input.velocity.Y / 50, 0, 1)
		m.tiltVel -= Vector3.new(0, 0, VM.LAND_KICK * fall)
		-- ...and it bounces: down by how hard you landed, then back up past rest.
		m.bounceVel -= math.max(VM.BOUNCE_LAND * fall, VM.BOUNCE_LAND_MIN) * kick
	elseif not input.grounded and m.wasGrounded and not input.sliding and input.velocity.Y > 5 then
		-- Pushing off for a jump: the gun dips, then floats up after you.
		m.bounceVel -= VM.BOUNCE_JUMP * kick
	end
	m.wasGrounded = input.grounded
	-- Crouching dips the gun, standing lifts it; both settle with a wobble.
	if input.crouching ~= m.wasCrouching then
		m.wasCrouching = input.crouching
		m.bounceVel += (if input.crouching then -1 else 1) * VM.CROUCH_BOUNCE * kick
	end
	-- In the air: the muzzle tips with your vertical speed, and falling rolls
	-- the gun out and flares the elbows (ViewmodelController reads airPos.Z).
	local airborne = not input.grounded and not input.sliding
	local vy = m.velocity.Y
	local falling = math.clamp(-vy / VM.AIR_FALL_SPEED, 0, 1)
	local airTarget = if airborne
		then Vector3.new(
			math.clamp(vy * VM.AIR_PITCH, -VM.AIR_PITCH_MAX, VM.AIR_PITCH_MAX) * DEG,
			falling * VM.AIR_ROLL * DEG,
			0.25 + 0.75 * falling
		)
		else Vector3.zero
	m.airPos, m.airVel = spring3(m.airPos, m.airVel, airTarget, VM.AIR_FREQUENCY, dt)
	local airScale = 1 + (VM.ADS_MOVE_SCALE - 1) * ads
	m.bouncePos, m.bounceVel = bounce(m.bouncePos, m.bounceVel, bounceOmega, VM.BOUNCE_DAMPING, dt)
	local bounceLift = m.bouncePos * (1 + (VM.BOUNCE_ADS - 1) * ads)
	-- Strafing: the gun lags behind the motion and its top leans back against
	-- it, easing back when you stop. Aimed, the sights follow the same way
	-- but less, turning around the sight so the front post stays near the
	-- crosshair.
	local moveScale = 1 + (VM.ADS_MOVE_SCALE - 1) * ads
	-- Hip: the top leans back against the strafe. Aimed: the gun leans into
	-- it (A left, D right), soft-limited, around the sight line.
	local hipRoll = localVel.X * VM.STRAFE_ROLL
	local adsRoll = soft(localVel.X * VM.ADS_STRAFE_ROLL, VM.ADS_STRAFE_ROLL_MAX * DEG)
	local strafeShift = VM.STRAFE_SHIFT + (VM.ADS_STRAFE_SHIFT - VM.STRAFE_SHIFT) * ads
	local tiltTarget = Vector3.new(
		hipRoll + (adsRoll - hipRoll) * ads,
		-localVel.X * strafeShift,
		math.clamp(-m.velocity.Y * VM.FALL_LAG, -VM.FALL_LAG_MAX, VM.FALL_LAG_MAX) * moveScale
	)
	-- Slide: the gun drops in with a kick (a little roll, a drift to the left
	-- and a dip), and pops back up as the slide ends.
	if input.sliding ~= m.wasSliding then
		m.wasSliding = input.sliding
		-- (Aimed, the kicks all but go: the sights stay on the crosshair.)
		local kickScale = 1 - 0.9 * ads
		if input.sliding then
			m.tiltVel += kickScale * Vector3.new(
				-VM.SLIDE_ENTER_KICK.X,
				-VM.SLIDE_ENTER_KICK.Y,
				-VM.SLIDE_ENTER_KICK.Z
			)
		else
			m.tiltVel += Vector3.new(0, 0, VM.SLIDE_EXIT_KICK * kickScale)
		end
	end
	m.tiltPos, m.tiltVel = spring3(m.tiltPos, m.tiltVel, tiltTarget, VM.TILT_FREQUENCY, dt)

	-- Fore-aft weight: the gun settles back as you move forward (its muzzle
	-- dipping a touch) and pushes out as you backpedal.
	m.surgePos, m.surgeVel =
		spring(m.surgePos, m.surgeVel, -localVel.Z * moveScale, VM.SURGE_FREQUENCY, dt)
	local surgeShift = m.surgePos * VM.SURGE_SHIFT
	local surgePitch = -m.surgePos * VM.SURGE_PITCH

	-- Slide chatter: two sines that never line up, so the scrape reads rough
	-- rather than as a hum; sized and paced by how fast you're sliding.
	m.slide, m.slideVel =
		spring(m.slide, m.slideVel, if input.sliding then 1 else 0, VM.BOB_EASE * 2, dt)
	local chatter = VM.SLIDE_CHATTER
	local slideSpeed = math.clamp(flatSpeed / VM.SLIDE_REFERENCE_SPEED, 0, 1)
	m.slidePhase = (m.slidePhase + dt * chatter.rate * (0.5 + 0.5 * slideSpeed) * TAU) % (TAU * 100)
	local slideAmount = math.clamp(m.slide, 0, 1) * slideSpeed * (1 - ads)
	local rough = math.sin(m.slidePhase) + 0.6 * math.sin(m.slidePhase * 1.37 + 1.3)
	local chatterLift = rough * chatter.pos * slideAmount
	local chatterRoll = math.sin(m.slidePhase * 0.73 + 0.4) * chatter.roll * DEG * slideAmount

	-- Walk bob: the loop speed and size ease toward what the movement asks
	-- for, and the phase only ever moves forward smoothly.
	local amountTarget = if input.grounded
		then math.clamp(flatSpeed / VM.BOB_REFERENCE_SPEED, 0, 1.5)
		else 0
	m.bobAmount, m.bobAmountVel = spring(m.bobAmount, m.bobAmountVel, amountTarget, VM.BOB_EASE, dt)
	m.bobSprint, m.bobSprintVel =
		spring(m.bobSprint, m.bobSprintVel, if input.sprinting then 1 else 0, VM.BOB_EASE, dt)
	local sprint = math.clamp(m.bobSprint, 0, 1)
	-- One loop is two steps, at the footsteps' stride for this speed.
	local stride = VM.BOB_WALK_STRIDE + (VM.BOB_SPRINT_STRIDE - VM.BOB_WALK_STRIDE) * sprint
	local frequency = math.max(flatSpeed / (2 * stride), VM.BOB_MIN_FREQUENCY)
	m.bobPhase = (m.bobPhase + dt * frequency * TAU) % TAU
	-- Amplitude per unit of speed: the sprint loop is wider, but sprinting is
	-- also faster, so divide that back out to land on BOB_SPRINT at sprint speed.
	local amount = math.max(m.bobAmount, 0) * (1 + (VM.ADS_BOB_SCALE - 1) * ads)
	local sprintAmount = Movement.SPRINT_SPEED / VM.BOB_REFERENCE_SPEED
	local bobPos = VM.BOB_WALK.pos:Lerp(VM.BOB_SPRINT.pos / sprintAmount, sprint) * amount
	local bobRot = VM.BOB_WALK.rot:Lerp(VM.BOB_SPRINT.rot / sprintAmount, sprint) * amount
	-- The swing hangs at each side (a squashed sine); each step rises slowly
	-- and drops quickly onto the footfall (VM.BOB_HANG / BOB_STEP).
	local s1 = math.tanh(VM.BOB_HANG * math.sin(m.bobPhase)) / math.tanh(VM.BOB_HANG)
	-- Walking dips as the swing crosses the middle; running dips at the ends
	-- of the swing, where the body is lowest and furthest over the foot
	-- (VM.BOB_RUN_SHIFT), so every step lands the same.
	local stepPhase = m.bobPhase + VM.BOB_RUN_SHIFT * sprint * math.pi * 0.5
	local step = (stepPhase / math.pi) % 1 -- 0..1 through one step
	local dip = math.sin(math.pi * step ^ VM.BOB_STEP)
	local c2 = 1 - 2 * dip * dip -- 1 on the footfall (the low point), -1 at the top of the step
	local bobOffset = Vector3.new(s1 * bobPos.X, -c2 * bobPos.Y, math.cos(m.bobPhase) * bobPos.Z)
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

	-- Aimed, what's left of a drift or dip (a slide's kick, a landing) is
	-- mostly taken out, so the sights come onto the crosshair with the aim.
	local settle = 1 - 0.85 * ads
	local offset = bobOffset
		+ breathOffset
		+ Vector3.new(
			-swayYaw * VM.SWAY_SHIFT + m.tiltPos.Y * settle,
			swayPitch * VM.SWAY_SHIFT + m.tiltPos.Z * settle + chatterLift + bounceLift,
			surgeShift
		)
	local rotation = CFrame.Angles(
		swayPitch + breathPitch + surgePitch + bounceLift * VM.BOUNCE_PITCH + m.airPos.X * airScale,
		swayYaw,
		m.tiltPos.X + swayYaw * 0.3 + chatterRoll - m.airPos.Y * airScale
	)
	local pivot = VM.MOTION_PIVOT:Lerp(VM.ADS_MOTION_PIVOT, ads)
	-- The walk / run bob rocks the gun around the hand that holds it
	-- (VM.BOB_PIVOT), so the hand's dip is the same on every step and the
	-- rock shows on the barrel.
	local bobPivot = VM.BOB_PIVOT:Lerp(VM.ADS_MOTION_PIVOT, ads)
	return CFrame.new(offset + pivot)
		* rotation
		* CFrame.new(bobPivot - pivot)
		* CFrame.Angles(bobPitch, bobYaw, bobRoll)
		* CFrame.new(-bobPivot)
end

return ViewmodelMotion
