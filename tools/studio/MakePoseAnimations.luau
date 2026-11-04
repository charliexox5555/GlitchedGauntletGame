--!strict
-- Builds the third-person pose animations (R15 KeyframeSequences) and saves
-- each one as a Studio-serialized .rbxm in art-source/animations/ through
-- tools/studio/receive_server.py. Run in Studio (Edit) via the MCP or the
-- Command Bar, then upload with:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_Sprint.rbxm "GG Sprint"
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

-- Crouch-walking backward: the same stride with the lift on the backswing
-- (the foot travels back through the air), a little more upright.
local function crouchWalkBack(): { Frame }
	local frames = {}
	for i = 0, 8 do
		local phase = i / 8 * math.pi * 2
		local f = crouch(18 * math.sin(phase), -16 * math.cos(phase))
		f.LowerTorso = { -4, 0, 0, 0, -0.75, 0 }
		table.insert(frames, f)
	end
	return frames
end

-- Crouch-walking sideways (`side` +1 right, -1 left): at crouch height the
-- legs step out and close (roll), the stepping knee lifts, the body leans a
-- little into the move.
local function crouchWalkSide(side: number): { Frame }
	local frames = {}
	for i = 0, 8 do
		local phase = i / 8 * math.pi * 2
		local f = crouch(0, 0)
		local function step(q: number): (number, number)
			return 14 * math.sin(q), math.max(math.cos(q), 0)
		end
		local ro, rAir = step(phase)
		local lo, lAir = step(phase + math.pi)
		f.LowerTorso = { -8, 0, -4 * side, 0, -0.75, 0 }
		f.RightUpperLeg = { 62 + 6 * rAir, 0, -ro * side }
		f.RightLowerLeg = { -88 - 14 * rAir, 0, 0 }
		f.RightFoot = { -(-8 + 62 + 6 * rAir - 88 - 14 * rAir), 0, ro * side * 0.6 }
		f.LeftUpperLeg = { 62 + 6 * lAir, 0, -lo * side }
		f.LeftLowerLeg = { -88 - 14 * lAir, 0, 0 }
		f.LeftFoot = { -(-8 + 62 + 6 * lAir - 88 - 14 * lAir), 0, lo * side * 0.6 }
		table.insert(frames, f)
	end
	return frames
end

-- (The slide's hold, in and out: tools/studio/MakeSlideAnimations.luau.)

local ACTION = Enum.AnimationPriority.Action
local ACTION2 = Enum.AnimationPriority.Action2

local sequences = {
	sequence("GG_AimUp", ACTION, { aim(70) }, 1),
	sequence("GG_AimLevel", ACTION, { aim(0) }, 1),
	sequence("GG_AimDown", ACTION, { aim(-70) }, 1),
	sequence("GG_Sprint", ACTION2, { SPRINT }, 1),
	sequence("GG_Crouch", ACTION2, { crouch(0, 0) }, 1),
	sequence("GG_CrouchWalk", ACTION2, crouchWalk(), 0.9),
	-- The other directions share the stride length, so blended feet stay in step.
	sequence("GG_CrouchWalkB", ACTION2, crouchWalkBack(), 0.9),
	sequence("GG_CrouchWalkL", ACTION2, crouchWalkSide(-1), 0.9),
	sequence("GG_CrouchWalkR", ACTION2, crouchWalkSide(1), 0.9),
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
