--!strict
-- Third-person poses. Every armed character (players and test dummies,
-- marked by the server with a "WeaponId" attribute) gets its arms raised to
-- hold the gun, pitched by the replicated "AimPitch". Characters with a
-- "MoveState" (written by the movement simulation) also get crouch, slide and
-- sprint poses, blended smoothly so a state change never pops. Runs after
-- the Animator each frame (PreSimulation), so it layers over walk/idle.
--
-- Known engine issue (Oct 2026): with Server Authority on, the Animator
-- writes joints inside the simulation step, after PreSimulation, so these
-- writes only show on joints no AnimationTrack is driving (e.g. a dummy with
-- its idle stopped). Roblox has acknowledged it and plans a new API:
-- devforum.roblox.com/t/4846108

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PoseController = {}

local IDENTITY = CFrame.identity

-- Joint-space poses (R15). +X rotation swings a limb forward (arms up, legs
-- forward); on the Root joint it leans the whole body back.

-- Holding the gun: the right hand holds the grip; the left reaches across
-- toward the front of the gun.
local RIGHT_YAW = math.rad(8)
local LEFT_YAW = math.rad(-38)
local LEFT_ELBOW = CFrame.Angles(math.rad(18), 0, 0)
local WAIST_SHARE = 0.35

-- Sprint: gun lowered and angled across the body, slight forward lean.
local SPRINT_RIGHT_SHOULDER = CFrame.Angles(0, math.rad(28), 0)
	* CFrame.Angles(math.rad(30), 0, math.rad(-10))
local SPRINT_LEFT_SHOULDER = CFrame.Angles(0, math.rad(-45), 0) * CFrame.Angles(math.rad(42), 0, 0)
local SPRINT_RIGHT_ELBOW = CFrame.Angles(math.rad(45), 0, 0)
local SPRINT_LEFT_ELBOW = CFrame.Angles(math.rad(55), 0, 0)
local SPRINT_ROOT = CFrame.Angles(math.rad(-9), 0, 0)
local SPRINT_WAIST = math.rad(-4)

-- Crouch: hips lowered, knees bent, chest slightly forward.
local CROUCH_ROOT = CFrame.new(0, -0.75, 0) * CFrame.Angles(math.rad(-8), 0, 0)
local CROUCH_HIP = CFrame.Angles(math.rad(62), 0, 0)
local CROUCH_KNEE = CFrame.Angles(math.rad(-88), 0, 0)
local CROUCH_WAIST = math.rad(-6)

-- Slide: low, leaning back, right leg out in front, left leg tucked under.
local SLIDE_ROOT = CFrame.new(0, -1.45, 0.2) * CFrame.Angles(math.rad(18), 0, 0)
local SLIDE_RIGHT_HIP = CFrame.Angles(math.rad(70), 0, math.rad(-4))
local SLIDE_RIGHT_KNEE = CFrame.Angles(math.rad(-10), 0, 0)
local SLIDE_LEFT_HIP = CFrame.Angles(math.rad(12), 0, math.rad(6))
local SLIDE_LEFT_KNEE = CFrame.Angles(math.rad(-105), 0, 0)
local SLIDE_WAIST = math.rad(-18) -- keeps the chest (and gun) facing forward

-- Blend speeds (per second, exponential approach).
local POSE_RATE = { crouch = 12, slide = 14, sprint = 9 }
local PITCH_RATE = 15

-- R15 joints are Motor6Ds on older rigs and AnimationConstraints on current
-- avatars; both expose the same Transform property.
type Joint = Instance

type Rig = {
	rightShoulder: Joint?,
	leftShoulder: Joint?,
	leftElbow: Joint?,
	waist: Joint?,
	rightElbow: Joint?,
	root: Joint?,
	rightHip: Joint?,
	rightKnee: Joint?,
	leftHip: Joint?,
	leftKnee: Joint?,
}

-- Smoothed per-character pose state.
type Blend = {
	crouch: number,
	slide: number,
	sprint: number,
	pitch: number,
	-- For layering on top of the Animator (see `layer`).
	written: { [Joint]: CFrame },
	base: { [Joint]: CFrame },
}

local rigs: { [Model]: Rig } = {}
local blends: { [Model]: Blend } = {}

local function motor(model: Model, partName: string, jointName: string): Joint?
	local part = model:FindFirstChild(partName)
	local m = part and part:FindFirstChild(jointName)
	if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then
		return m
	end
	return nil
end

local function setTransform(joint: Joint?, cf: CFrame)
	if joint then
		(joint :: any).Transform = cf
	end
end

-- Puts `offset` on top of what the Animator wrote this frame. If the
-- Animator didn't touch the joint (Transform still equals what we wrote
-- last frame), reuse last frame's base so offsets never pile up. Fuzzy:
-- Transform doesn't read back bit-identical.
local function layer(blend: Blend, joint: Joint?, offset: CFrame)
	if not joint then
		return
	end
	local current: CFrame = (joint :: any).Transform
	local written = blend.written[joint]
	local base = if written and current:FuzzyEq(written, 1e-4)
		then blend.base[joint] or current
		else current
	local out = base * offset
	setTransform(joint, out)
	blend.written[joint] = out
	blend.base[joint] = base
end

local function live(m: Joint?): boolean
	return m ~= nil and m.Parent ~= nil
end

-- Every joint found and still in the rig (Humanoids can rebuild their joints,
-- and streaming can swap parts, so a cached joint may go stale).
local function complete(r: Rig): boolean
	return live(r.rightShoulder)
		and live(r.leftShoulder)
		and live(r.leftElbow)
		and live(r.waist)
		and live(r.rightElbow)
		and live(r.root)
		and live(r.rightHip)
		and live(r.rightKnee)
		and live(r.leftHip)
		and live(r.leftKnee)
end

-- With StreamingEnabled a model's limbs can arrive after the model itself,
-- so keep looking until every joint has been found.
local function rigFor(model: Model): Rig
	local r = rigs[model]
	if r and not complete(r) then
		rigs[model] = nil
		r = nil
	end
	if not r then
		r = {
			rightShoulder = motor(model, "RightUpperArm", "RightShoulder"),
			leftShoulder = motor(model, "LeftUpperArm", "LeftShoulder"),
			leftElbow = motor(model, "LeftLowerArm", "LeftElbow"),
			waist = motor(model, "UpperTorso", "Waist"),
			rightElbow = motor(model, "RightLowerArm", "RightElbow"),
			root = motor(model, "LowerTorso", "Root"),
			rightHip = motor(model, "RightUpperLeg", "RightHip"),
			rightKnee = motor(model, "RightLowerLeg", "RightKnee"),
			leftHip = motor(model, "LeftUpperLeg", "LeftHip"),
			leftKnee = motor(model, "LeftLowerLeg", "LeftKnee"),
		}
		rigs[model] = r
		if complete(r) then
			model.Destroying:Once(function()
				rigs[model] = nil
				blends[model] = nil
			end)
		end
	end
	return r
end

local function blendFor(model: Model): Blend
	local b = blends[model]
	if not b then
		b = { crouch = 0, slide = 0, sprint = 0, pitch = 0, written = {}, base = {} }
		blends[model] = b
	end
	return b
end

local function approach(value: number, target: number, rate: number, dt: number): number
	return value + (target - value) * (1 - math.exp(-rate * dt))
end

local function pose(model: Model, dt: number)
	-- Players carry their cosmetic state on the Player; dummies on the model.
	local owner = Players:GetPlayerFromCharacter(model)
	local source: Instance = owner or model
	if not source:GetAttribute("WeaponId") or not model:FindFirstChild("WorldWeapon") then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local r = rigFor(model)
	local b = blendFor(model)

	-- Movement state (dummies have none and just stand).
	local moveState = model:GetAttribute("MoveState") :: string?
	b.crouch = approach(b.crouch, if moveState == "Crouch" then 1 else 0, POSE_RATE.crouch, dt)
	b.slide = approach(b.slide, if moveState == "Slide" then 1 else 0, POSE_RATE.slide, dt)
	b.sprint = approach(b.sprint, if moveState == "Sprint" then 1 else 0, POSE_RATE.sprint, dt)
	-- AimPitch replicates ~10 times a second; smooth it so the arms glide.
	b.pitch = approach(b.pitch, (source:GetAttribute("AimPitch") :: number?) or 0, PITCH_RATE, dt)
	local c, s, p = b.crouch, b.slide, b.sprint

	-- Arms: aim pose, lowered toward the sprint pose.
	local pitch = b.pitch * (1 - p)
	local armPitch = pitch * (1 - WAIST_SHARE)
	local aimRight = CFrame.Angles(0, RIGHT_YAW, 0) * CFrame.Angles(math.pi / 2 + armPitch, 0, 0)
	local aimLeft = CFrame.Angles(0, LEFT_YAW, 0) * CFrame.Angles(math.pi / 2 + armPitch, 0, 0)
	setTransform(r.rightShoulder, aimRight:Lerp(SPRINT_RIGHT_SHOULDER, p))
	setTransform(r.leftShoulder, aimLeft:Lerp(SPRINT_LEFT_SHOULDER, p))
	setTransform(r.leftElbow, LEFT_ELBOW:Lerp(SPRINT_LEFT_ELBOW, p))
	setTransform(
		r.waist,
		CFrame.Angles(
			pitch * WAIST_SHARE + CROUCH_WAIST * c + SLIDE_WAIST * s + SPRINT_WAIST * p,
			0,
			0
		)
	)

	-- Body and legs: layered on the walk/idle animation, only for characters
	-- that move. Our own body is invisible in first person and simulated
	-- locally, so it's left alone (moving its torso could fight physics).
	if moveState == nil or owner == Players.LocalPlayer then
		return
	end
	layer(b, r.rightElbow, IDENTITY:Lerp(SPRINT_RIGHT_ELBOW, p))
	local root = IDENTITY:Lerp(CROUCH_ROOT, c):Lerp(SLIDE_ROOT, s) * IDENTITY:Lerp(SPRINT_ROOT, p)
	layer(b, r.root, root)
	layer(b, r.rightHip, IDENTITY:Lerp(CROUCH_HIP, c):Lerp(SLIDE_RIGHT_HIP, s))
	layer(b, r.rightKnee, IDENTITY:Lerp(CROUCH_KNEE, c):Lerp(SLIDE_RIGHT_KNEE, s))
	layer(b, r.leftHip, IDENTITY:Lerp(CROUCH_HIP, c):Lerp(SLIDE_LEFT_HIP, s))
	layer(b, r.leftKnee, IDENTITY:Lerp(CROUCH_KNEE, c):Lerp(SLIDE_LEFT_KNEE, s))
end

local function step(dt: number)
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			pose(c, dt)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			if d:IsA("Model") then
				pose(d, dt)
			end
		end
	end
end

function PoseController.start()
	RunService.PreSimulation:Connect(step)
end

return PoseController
