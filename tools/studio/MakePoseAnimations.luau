--!strict
-- Builds the third-person pose animations (R15 KeyframeSequences) and saves
-- each one as a Studio-serialized .rbxm in art-source/animations/ through
-- tools/studio/receive_server.py. Run in Studio (Edit) via the MCP or the
-- Command Bar, then upload with:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_Slide.rbxm "GG Slide"
-- and put the ids in src/shared/Config/Animations.luau.
--
-- Pose CFrames are joint Transforms (R15): +X rotation swings a limb forward
-- (arms up, legs forward); on LowerTorso (Root) it leans the body back, on
-- UpperTorso (Waist) it leans the chest back. Angles are in degrees.
--
-- Why animations and not scripted Transforms: with Server Authority on, the
-- Animator overwrites scripted joint writes (devforum t/4846108). Tracks
-- played on the player's own character also replicate to the server, so
-- server hitboxes crouch and slide too.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")

local RECEIVER = "http://127.0.0.1:34999/save?path=art-source/animations/"

type JointPose = { number } -- { pitch, yaw, roll } or { pitch, yaw, roll, x, y, z }
type Frame = { [string]: JointPose } -- keyed by part name (the joint's Part1)

local PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
}

local function cf(p: JointPose): CFrame
	local r = CFrame.Angles(0, math.rad(p[2] or 0), 0)
		* CFrame.Angles(math.rad(p[1]), 0, math.rad(p[3] or 0))
	return CFrame.new(p[4] or 0, p[5] or 0, p[6] or 0) * r
end

-- One Keyframe holding `frame`, with the parent chain each joint needs.
local function keyframe(time: number, frame: Frame): Keyframe
	local kf = Instance.new("Keyframe")
	kf.Time = time
	local poses: { [string]: Pose } = {}
	local function poseFor(name: string): Pose
		local existing = poses[name]
		if existing then
			return existing
		end
		local p = Instance.new("Pose")
		p.Name = name
		p.CFrame = CFrame.identity
		-- Parent-only poses don't drive their joint (weight 0).
		p.Weight = 0
		poses[name] = p
		local parentName = PARENT[name]
		p.Parent = if parentName then poseFor(parentName) else kf
		return p
	end
	for name, jp in frame do
		local p = poseFor(name)
		p.CFrame = cf(jp)
		p.Weight = 1
	end
	return kf
end

local function sequence(
	name: string,
	priority: Enum.AnimationPriority,
	frames: { Frame },
	length: number
): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = true
	ks.Priority = priority
	for i, frame in frames do
		local t = if #frames == 1 then 0 else (i - 1) / (#frames - 1) * length
		keyframe(t, frame).Parent = ks
	end
	if #frames == 1 then
		-- A static pose still needs a span to loop over.
		keyframe(length, frames[1]).Parent = ks
	end
	return ks
end

-- Poses ----------------------------------------------------------------------

-- Holding the gun at pitch `deg` (look up = +). 35% of the pitch goes into
-- the chest, the rest into the arms. Right hand on the grip, left hand
-- reaching across to the front of the gun.
local function aim(deg: number): Frame
	local arm = 90 + deg * 0.65
	return {
		UpperTorso = { deg * 0.35, 0, 0 },
		RightUpperArm = { arm, 8, 0 },
		RightLowerArm = { 0, 0, 0 },
		LeftUpperArm = { arm, -38, 0 },
		LeftLowerArm = { 18, 0, 0 },
	}
end

-- Sprint: gun lowered and angled across the body, chest leaning forward.
local SPRINT: Frame = {
	UpperTorso = { -12, 0, 0 },
	RightUpperArm = { 30, 28, -10 },
	RightLowerArm = { 45, 0, 0 },
	LeftUpperArm = { 42, -45, 0 },
	LeftLowerArm = { 55, 0, 0 },
}

-- Crouch: hips lowered and leaning forward a little, knees bent, feet flat.
local function crouch(swing: number, kneeSwing: number): Frame
	local lean, hip, knee = -8, 62, -88
	local function ankle(h: number, k: number): number
		return -(lean + h + k) -- keep the foot level with the ground
	end
	local rh, lh = hip + swing, hip - swing
	local rk, lk = knee + kneeSwing, knee - kneeSwing
	return {
		LowerTorso = { lean, 0, 0, 0, -0.75, 0 },
		RightUpperLeg = { rh, 0, 0 },
		RightLowerLeg = { rk, 0, 0 },
		RightFoot = { ankle(rh, rk), 0, 0 },
		LeftUpperLeg = { lh, 0, 0 },
		LeftLowerLeg = { lk, 0, 0 },
		LeftFoot = { ankle(lh, lk), 0, 0 },
	}
end

-- Crouch-walk: one full stride, legs swinging in opposite phase.
local function crouchWalk(): { Frame }
	local frames = {}
	for i = 0, 8 do
		local phase = i / 8 * math.pi * 2
		table.insert(frames, crouch(22 * math.sin(phase), 16 * math.cos(phase)))
	end
	return frames
end

-- Slide: low and leaning back, right leg out in front, left leg tucked under,
-- chest straightened so the gun stays level.
local SLIDE: Frame = {
	LowerTorso = { 18, 0, 0, 0, -1.45, 0.2 },
	UpperTorso = { -18, 0, 0 },
	RightUpperLeg = { 70, 0, -4 },
	RightLowerLeg = { -10, 0, 0 },
	RightFoot = { -20, 0, 0 },
	LeftUpperLeg = { 12, 0, 6 },
	LeftLowerLeg = { -105, 0, 0 },
	LeftFoot = { 60, 0, 0 },
}

local ACTION = Enum.AnimationPriority.Action
local ACTION2 = Enum.AnimationPriority.Action2
local ACTION3 = Enum.AnimationPriority.Action3

local sequences = {
	sequence("GG_AimUp", ACTION, { aim(70) }, 1),
	sequence("GG_AimLevel", ACTION, { aim(0) }, 1),
	sequence("GG_AimDown", ACTION, { aim(-70) }, 1),
	sequence("GG_Sprint", ACTION2, { SPRINT }, 1),
	sequence("GG_Crouch", ACTION2, { crouch(0, 0) }, 1),
	sequence("GG_CrouchWalk", ACTION2, crouchWalk(), 0.9),
	sequence("GG_Slide", ACTION3, { SLIDE }, 1),
}

local EncodingService = game:GetService("EncodingService")
local saved = {}
for _, ks in sequences do
	local blob = SerializationService:SerializeInstancesAsync({ ks })
	local res = HttpService:RequestAsync({
		Url = RECEIVER .. ks.Name .. ".rbxm",
		Method = "POST",
		Body = buffer.tostring(EncodingService:Base64Encode(blob)),
	})
	table.insert(saved, res.Body)
end
return table.concat(saved, " | ")
