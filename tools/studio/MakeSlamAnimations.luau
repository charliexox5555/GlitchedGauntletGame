--!strict
-- Builds Updraft Crash Down's third-person clips (R15 KeyframeSequences), the
-- same way as tools/studio/MakeModAnimations.luau, and saves each as a .rbxm
-- in art-source/animations/ through tools/studio/receive_server.py. Run in
-- Studio (Edit) via the MCP or the Command Bar with the receiver listening,
-- then upload each:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_UpdraftSlam.rbxm "GG Updraft Slam"
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_UpdraftSlamLand.rbxm "GG Updraft Slam Land"
-- and put the ids in src/shared/Config/Animations.luau (MODS.UpdraftSlam /
-- UpdraftSlamLand). Simulation/Poses plays them (the dive borrows the Crouch
-- pose until then).
--
--   GG_UpdraftSlam      (looped, Action4) the dive: hunched over, knees drawn
--                       up under you, the right fist cocked high to punch the
--                       floor, the left arm out for balance, a small shudder
--   GG_UpdraftSlamLand  (one-shot, Action4) the landing: hips drop, right knee
--                       down, the right fist driven into the floor, left arm
--                       thrown back; held a beat, then up
--
-- Joint angles in degrees (R15 Transforms): +X swings a limb forward (arms
-- up); on UpperTorso (Waist) it leans the chest back.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local RECEIVER = "http://127.0.0.1:34999/save?path=art-source/animations/"

type JointPose = { number } -- { pitch, yaw, roll } or { pitch, yaw, roll, x, y, z }
type Frame = { [string]: JointPose }

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
	local r = CFrame.Angles(0, math.rad(p[2] or 0), 0) * CFrame.Angles(math.rad(p[1]), 0, math.rad(p[3] or 0))
	return CFrame.new(p[4] or 0, p[5] or 0, p[6] or 0) * r
end

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
		p.EasingStyle = Enum.PoseEasingStyle.Cubic
		p.EasingDirection = Enum.PoseEasingDirection.InOut
	end
	return kf
end

-- `keys`: { time, frame } pairs.
local function sequence(name: string, priority: Enum.AnimationPriority, loop: boolean, keys: { { any } }): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = loop
	ks.Priority = priority
	for _, k in keys do
		keyframe(k[1], k[2]).Parent = ks
	end
	return ks
end

-- Poses -------------------------------------------------------------------------

local REST: Frame = {
	LowerTorso = { 0, 0, 0 },
	UpperTorso = { 0, 0, 0 },
	Head = { 0, 0, 0 },
	RightUpperArm = { 0, 0, 0 },
	RightLowerArm = { 0, 0, 0 },
	LeftUpperArm = { 0, 0, 0 },
	LeftLowerArm = { 0, 0, 0 },
	RightUpperLeg = { 0, 0, 0 },
	RightLowerLeg = { 0, 0, 0 },
	LeftUpperLeg = { 0, 0, 0 },
	LeftLowerLeg = { 0, 0, 0 },
}

-- The dive: hunched, knees up, right fist cocked overhead.
local DIVE: Frame = {
	LowerTorso = { -14, 0, 0 },
	UpperTorso = { -22, 8, 0 },
	Head = { 18, 0, 0 },
	RightUpperArm = { 150, 10, 18 },
	RightLowerArm = { 75, 0, 0 },
	RightHand = { 10, 0, 0 },
	LeftUpperArm = { 25, -10, -55 },
	LeftLowerArm = { 25, 0, 0 },
	RightUpperLeg = { 75, 0, 6 },
	RightLowerLeg = { -95, 0, 0 },
	LeftUpperLeg = { 30, 0, -6 },
	LeftLowerLeg = { -70, 0, 0 },
}
-- The same with the fist a little higher and the knees a little tighter (the shudder).
local DIVE_2: Frame = table.clone(DIVE)
DIVE_2.RightUpperArm = { 158, 10, 20 }
DIVE_2.RightUpperLeg = { 80, 0, 6 }
DIVE_2.UpperTorso = { -25, 8, 0 }

-- The landing: hips drop, right knee down, the fist in the floor in front.
local SLAM: Frame = {
	LowerTorso = { -18, 0, 0, 0, -1.1, 0 },
	UpperTorso = { -30, -6, 0 },
	Head = { 22, 0, 0 },
	RightUpperArm = { 35, 0, 8 },
	RightLowerArm = { 5, 0, 0 },
	RightHand = { -15, 0, 0 },
	LeftUpperArm = { -35, 0, -35 },
	LeftLowerArm = { 20, 0, 0 },
	RightUpperLeg = { 20, 0, 4 },
	RightLowerLeg = { -110, 0, 0 },
	LeftUpperLeg = { 95, 0, -6 },
	LeftLowerLeg = { -90, 0, 0 },
}

local ACTION4 = Enum.AnimationPriority.Action4

local sequences = {
	sequence("GG_UpdraftSlam", ACTION4, true, {
		{ 0, DIVE },
		{ 0.1, DIVE_2 },
		{ 0.2, DIVE },
	}),
	sequence("GG_UpdraftSlamLand", ACTION4, false, {
		{ 0, DIVE },
		{ 0.05, SLAM },
		{ 0.32, SLAM },
		{ 0.6, REST },
	}),
}

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
