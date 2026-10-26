--!strict
-- Builds the third-person Mod animations (R15 KeyframeSequences), the same way
-- as tools/studio/MakePoseAnimations.luau, and saves each as a .rbxm in
-- art-source/animations/ through tools/studio/receive_server.py. Run in Studio
-- (Edit) via the MCP or the Command Bar, then upload each:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_ModThrow.rbxm "GG Mod Throw"
-- and put the ids in src/shared/Config/Animations.luau (MODS).
--
--   GG_ModHold   (looped)   right hand forward at chest height, holding a Mod
--   GG_ModThrow  (one-shot) wind back over the shoulder, release, follow through
--   GG_ModPlace  (one-shot) dip and push the object down in front
--   GG_ModHeal   (one-shot) thrust the device toward the target and back
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

local HOLD: Frame = {
	UpperTorso = { 2, 0, 0 },
	RightUpperArm = { 62, 12, 0 },
	RightLowerArm = { 38, 0, 0 },
	RightHand = { -10, 0, 0 },
	LeftUpperArm = { 18, -8, 0 },
	LeftLowerArm = { 20, 0, 0 },
}

local THROW_BACK: Frame = {
	UpperTorso = { 8, 22, 0 },
	RightUpperArm = { 150, 25, 25 },
	RightLowerArm = { 70, 0, 0 },
	LeftUpperArm = { 70, -10, 0 },
	LeftLowerArm = { 10, 0, 0 },
}
local THROW_RELEASE: Frame = {
	UpperTorso = { -14, -18, 0 },
	RightUpperArm = { 85, -5, 0 },
	RightLowerArm = { 5, 0, 0 },
	LeftUpperArm = { 30, -10, 0 },
	LeftLowerArm = { 20, 0, 0 },
}
local THROW_FOLLOW: Frame = {
	UpperTorso = { -8, -10, 0 },
	RightUpperArm = { 35, -20, 0 },
	RightLowerArm = { 25, 0, 0 },
	LeftUpperArm = { 15, -8, 0 },
	LeftLowerArm = { 20, 0, 0 },
}

local PLACE_DOWN: Frame = {
	LowerTorso = { -6, 0, 0, 0, -0.45, 0 },
	UpperTorso = { -22, 0, 0 },
	RightUpperArm = { 48, 8, 0 },
	RightLowerArm = { 12, 0, 0 },
	LeftUpperArm = { 20, -8, 0 },
	LeftLowerArm = { 20, 0, 0 },
}

local HEAL_PUSH: Frame = {
	UpperTorso = { -4, 0, 0 },
	RightUpperArm = { 92, 4, 0 },
	RightLowerArm = { 2, 0, 0 },
	RightHand = { -5, 0, 0 },
	LeftUpperArm = { 22, -8, 0 },
	LeftLowerArm = { 20, 0, 0 },
}

local ACTION = Enum.AnimationPriority.Action
local ACTION4 = Enum.AnimationPriority.Action4

local sequences = {
	sequence("GG_ModHold", ACTION, true, { { 0, HOLD }, { 1, HOLD } }),
	sequence("GG_ModThrow", ACTION4, false, {
		{ 0, HOLD },
		{ 0.13, THROW_BACK },
		{ 0.22, THROW_RELEASE },
		{ 0.42, THROW_FOLLOW },
	}),
	sequence("GG_ModPlace", ACTION4, false, {
		{ 0, HOLD },
		{ 0.16, PLACE_DOWN },
		{ 0.4, HOLD },
	}),
	sequence("GG_ModHeal", ACTION4, false, {
		{ 0, HOLD },
		{ 0.1, HEAL_PUSH },
		{ 0.38, HOLD },
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
