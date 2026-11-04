--!strict
-- Builds the third-person slide (R15 KeyframeSequences, hips, chest and legs
-- only: the arms stay on the gun-holding aim layers) and saves each as a
-- Studio-serialized .rbxm in art-source/animations/ through
-- tools/studio/receive_server.py. Run in Studio (Edit) via the MCP or the
-- Command Bar, upload with tools/opencloud/upload_asset.py --type Animation,
-- and put the ids in src/shared/Config/Animations.luau (POSES.Slide,
-- LOCOMOTION.SlideIn / SlideOut).
--
--   GG_SlideIn   one-shot as the slide starts: the plant, the kick-out and a
--                drop a little past the hold that settles into it
--   GG_Slide     the hold (Action3, looped): low, leaning back, front leg
--                out, back leg folded under, with a small scrape chatter;
--                Simulation/Poses slows it with the slide's speed
--   GG_SlideOut  one-shot when a slide ends on your feet: the front foot
--                plants and pushes you back up into the run
--
-- Conventions as in MakePoseAnimations: pose CFrames are joint Transforms;
-- +X swings a leg forward; on LowerTorso it leans the body back; a negative
-- knee pitch bends the knee. Angles in degrees.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local RECEIVER = "http://127.0.0.1:34999/save?path=art-source/animations/"

type JointPose = { number } -- { pitch, yaw, roll } or { pitch, yaw, roll, x, y, z }
type Frame = { [string]: JointPose }

local PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
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
		p.EasingStyle = Enum.PoseEasingStyle.Cubic
		p.EasingDirection = Enum.PoseEasingDirection.InOut
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
	times: { number },
	loop: boolean
): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = loop
	ks.Priority = priority
	for i, frame in frames do
		keyframe(times[i], frame).Parent = ks
	end
	return ks
end

-- The hold: low and leaning back, a slight roll toward the folded leg, the
-- chest straightened so the gun stays level. `chatter` (-1..1) is the scrape:
-- the hips buzz a little and the front heel skips.
local function hold(chatter: number): Frame
	return {
		LowerTorso = { 18, 0, 5 + chatter * 1.2, 0, -1.45 - math.abs(chatter) * 0.04, 0.2 },
		UpperTorso = { -18, 0, -4 - chatter * 0.8 },
		RightUpperLeg = { 70 + chatter * 2, 0, -4 },
		RightLowerLeg = { -10 - chatter * 3, 0, 0 },
		RightFoot = { -20 + chatter * 4, 0, 0 },
		LeftUpperLeg = { 12, -6, 8 },
		LeftLowerLeg = { -105, 0, 0 },
		LeftFoot = { 60, 0, 0 },
	}
end

-- Mid-sprint (where a slide starts and the run picks up after one).
local STRIDE: Frame = {
	LowerTorso = { -10, 0, 0, 0, -0.2, 0 },
	UpperTorso = { 4, 0, 0 },
	RightUpperLeg = { 32, 0, 0 },
	RightLowerLeg = { -44, 0, 0 },
	RightFoot = { 10, 0, 0 },
	LeftUpperLeg = { -16, 0, 0 },
	LeftLowerLeg = { -52, 0, 0 },
	LeftFoot = { 22, 0, 0 },
}

-- In: the front leg kicks out as the hips drop, past the hold, then settle.
local KICK: Frame = {
	LowerTorso = { 8, 0, 3, 0, -0.95, 0.1 },
	UpperTorso = { -10, 0, -2 },
	RightUpperLeg = { 58, 0, -4 },
	RightLowerLeg = { -26, 0, 0 },
	RightFoot = { -8, 0, 0 },
	LeftUpperLeg = { 4, -4, 6 },
	LeftLowerLeg = { -84, 0, 0 },
	LeftFoot = { 44, 0, 0 },
}
local DROP: Frame = {
	LowerTorso = { 23, 0, 7, 0, -1.65, 0.26 },
	UpperTorso = { -23, 0, -5 },
	RightUpperLeg = { 76, 0, -4 },
	RightLowerLeg = { -5, 0, 0 },
	RightFoot = { -25, 0, 0 },
	LeftUpperLeg = { 14, -7, 9 },
	LeftLowerLeg = { -110, 0, 0 },
	LeftFoot = { 62, 0, 0 },
}

-- Out: the front foot plants under you and drives you up, chest forward.
local PLANT: Frame = {
	LowerTorso = { 2, 0, 3, 0, -1.05, 0.1 },
	UpperTorso = { -6, 0, -2 },
	RightUpperLeg = { 48, 0, -3 },
	RightLowerLeg = { -62, 0, 0 },
	RightFoot = { 16, 0, 0 },
	LeftUpperLeg = { 2, -3, 5 },
	LeftLowerLeg = { -88, 0, 0 },
	LeftFoot = { 40, 0, 0 },
}
local RISE: Frame = {
	LowerTorso = { -12, 0, 0, 0, -0.35, 0 },
	UpperTorso = { 6, 0, 0 },
	RightUpperLeg = { 14, 0, 0 },
	RightLowerLeg = { -40, 0, 0 },
	RightFoot = { 18, 0, 0 },
	LeftUpperLeg = { -20, 0, 0 },
	LeftLowerLeg = { -36, 0, 0 },
	LeftFoot = { 14, 0, 0 },
}

local ACTION3 = Enum.AnimationPriority.Action3
local ACTION4 = Enum.AnimationPriority.Action4

local sequences = {
	sequence(
		"GG_SlideIn",
		ACTION4,
		{ STRIDE, KICK, DROP, hold(0) },
		{ 0, 0.08, 0.16, 0.28 },
		false
	),
	sequence(
		"GG_Slide",
		ACTION3,
		{ hold(0), hold(1), hold(-0.6), hold(0.4), hold(0) },
		{ 0, 0.06, 0.13, 0.19, 0.26 },
		true
	),
	sequence(
		"GG_SlideOut",
		ACTION4,
		{ hold(0), PLANT, RISE, STRIDE },
		{ 0, 0.09, 0.2, 0.3 },
		false
	),
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
	ks.Parent = game:GetService("ServerStorage")
end
return table.concat(saved, " | ")
