--!strict
-- Builds the third-person combat poses (R15 KeyframeSequences) others see on
-- you: aiming down sights (three pitch poses, like the hip aim set in
-- MakePoseAnimations), a reload one-shot, a hit flinch, going down, a draw
-- on a weapon swap, and the knife's ready hold, slash and heavy. Run in Studio
-- (Edit) via the MCP or the Command Bar: it returns pose text; build the .rbxm
-- files with tools/studio/pose_text_to_rbxm.py, upload with
-- tools/opencloud/upload_asset.py --type Animation,
-- and put the ids in src/shared/Config/Animations.luau (COMBAT).
--
-- Conventions as in MakePoseAnimations: pose CFrames are joint Transforms;
-- +X swings an arm forward/up; on UpperTorso it leans the chest back.
-- Angles in degrees. The reload is made 1 s long and played at the gun's
-- reload time (Simulation/Poses adjusts its speed).

type JointPose = { number }
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
	local r = CFrame.Angles(0, math.rad(p[2] or 0), 0)
		* CFrame.Angles(math.rad(p[1]), 0, math.rad(p[3] or 0))
	return CFrame.new(p[4] or 0, p[5] or 0, p[6] or 0) * r
end

local function keyframe(time: number, frame: Frame, easing: Enum.PoseEasingStyle?): Keyframe
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
		p.EasingStyle = easing or Enum.PoseEasingStyle.Cubic
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

-- The hip hold, so the clips start and end on it: the level pose solved by
-- tools/studio/MakeHoldAnimations (GG_AimLevel, both hands on the gun).
local function hip(): Frame
	return {
		UpperTorso = { 2, -10, 0 },
		Head = { -6, 8, 0 },
		RightUpperArm = { -26.33, -82.27, -100.45 },
		RightLowerArm = { -5.45, -2.25, 22.49 },
		RightHand = { 6.08, 117.06, 8.31 },
		LeftUpperArm = { -53.44, 77.76, 105.54 },
		LeftLowerArm = { -3.81, 1.57, -22.42 },
		LeftHand = { -59.8, -51.09, -32.26 },
	}
end

-- Reload (1 s at speed 1): the gun tips in and down, the support hand drops
-- to the magazine, pulls it, comes back up with the new one and seats it.
local function reloadFrames(): ({ Frame }, { number })
	local start = hip()
	local tilt: Frame = {
		UpperTorso = { -6, 8, 0 },
		RightUpperArm = { 72, 22, 18 },
		RightLowerArm = { 30, 0, 0 },
		LeftUpperArm = { 58, -30, 0 },
		LeftLowerArm = { 62, 0, 0 },
	}
	local magOut: Frame = {
		UpperTorso = { -8, 10, 0 },
		Head = { -14, 8, 0 },
		RightUpperArm = { 70, 24, 20 },
		RightLowerArm = { 32, 0, 0 },
		LeftUpperArm = { 18, -18, 8 },
		LeftLowerArm = { 46, 0, 0 },
	}
	local magIn: Frame = {
		UpperTorso = { -7, 9, 0 },
		Head = { -12, 6, 0 },
		RightUpperArm = { 72, 22, 18 },
		RightLowerArm = { 30, 0, 0 },
		LeftUpperArm = { 52, -26, 0 },
		LeftLowerArm = { 70, 0, 0 },
	}
	local seat: Frame = {
		UpperTorso = { -4, 6, 0 },
		Head = { -6, 2, 0 },
		RightUpperArm = { 80, 18, 10 },
		RightLowerArm = { 18, 0, 0 },
		LeftUpperArm = { 70, -32, 0 },
		LeftLowerArm = { 48, 0, 0 },
	}
	local back = hip()
	return { start, tilt, magOut, magIn, seat, back }, { 0, 0.14, 0.38, 0.62, 0.8, 1 }
end

-- Flinch (0.3 s): the chest and head snap back, then settle. Only those two
-- joints, so it plays over whatever the arms are doing.
local FLINCH_HIT: Frame = { UpperTorso = { 11, 4, -3 }, Head = { 14, -5, 4 } }
local FLINCH_REST: Frame = { UpperTorso = { 0, 0, 0 }, Head = { 0, 0, 0 } }

-- Going down (DeathFxController plays it on the still copy of a downed
-- body, before the copy tips over): knees buckle, the gun arm drops, the
-- head and chest fold forward. Not looped; holds its last frame.
local DEATH_START: Frame = {
	LowerTorso = { 0, 0, 0 },
	UpperTorso = { 0, 0, 0 },
	Head = { 0, 0, 0 },
	RightUpperArm = { 90, 8, 0 },
	LeftUpperArm = { 90, -38, 0 },
	RightUpperLeg = { 0, 0, 0 },
	RightLowerLeg = { 0, 0, 0 },
	LeftUpperLeg = { 0, 0, 0 },
	LeftLowerLeg = { 0, 0, 0 },
}
local DEATH_BUCKLE: Frame = {
	LowerTorso = { -14, 6, 4, 0, -0.9, 0 },
	UpperTorso = { -22, -8, 6 },
	Head = { -28, 10, -8 },
	RightUpperArm = { 30, 20, -10 },
	RightLowerArm = { 20, 0, 0 },
	LeftUpperArm = { 15, -10, 14 },
	LeftLowerArm = { 25, 0, 0 },
	RightUpperLeg = { 48, 0, -6 },
	RightLowerLeg = { -78, 0, 0 },
	RightFoot = { 30, 0, 0 },
	LeftUpperLeg = { 30, 0, 8 },
	LeftLowerLeg = { -92, 0, 0 },
	LeftFoot = { 50, 0, 0 },
}
local DEATH_DOWN: Frame = {
	LowerTorso = { -26, 10, 6, 0, -1.6, 0 },
	UpperTorso = { -30, -10, 10 },
	Head = { -35, 14, -12 },
	RightUpperArm = { 10, 26, -24 },
	RightLowerArm = { 12, 0, 0 },
	LeftUpperArm = { 0, -14, 22 },
	LeftLowerArm = { 18, 0, 0 },
	RightUpperLeg = { 80, 0, -8 },
	RightLowerLeg = { -112, 0, 0 },
	RightFoot = { 40, 0, 0 },
	LeftUpperLeg = { 66, 0, 10 },
	LeftLowerLeg = { -120, 0, 0 },
	LeftFoot = { 55, 0, 0 },
}

-- The knife (2026-11-04). Yaw (+Y) turns a joint left; a right arm at yaw
-- -55 is out to the right, at +45 across the body.
-- Ready: knife low and forward, the free hand up as a guard, a slow breath.
local function knifeReady(breath: number): Frame
	return {
		-- (2026-11-05, match body: the guard arm lowered; it was raised to the face.)
		UpperTorso = { 2 + breath * 1.5, -8, 0 },
		Head = { -breath, 8, 0 },
		RightUpperArm = { 45 + breath * 2, 8, 0 },
		RightLowerArm = { 55, 0, 0 },
		RightHand = { -10, 0, 0 },
		LeftUpperArm = { 28 + breath * 2, -12, -6 },
		LeftLowerArm = { 58, 0, 0 },
		LeftHand = { 0, 0, 0 },
	}
end
local KNIFE = knifeReady(0)
-- Slash: the arm swings out to the right with the chest, then cuts across
-- to the left and follows through.
local SLASH_WIND: Frame = {
	UpperTorso = { 2, -26, 0 },
	Head = { 0, 20, 0 },
	RightUpperArm = { 82, -58, 0 },
	RightLowerArm = { 24, 0, 0 },
	RightHand = { 0, -20, 0 },
	LeftUpperArm = { 66, -10, 0 },
	LeftLowerArm = { 66, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local SLASH_CUT: Frame = {
	UpperTorso = { -6, 24, 0 },
	Head = { 0, -18, 0 },
	RightUpperArm = { 86, 44, 0 },
	RightLowerArm = { 8, 0, 0 },
	RightHand = { 0, 20, 0 },
	LeftUpperArm = { 40, -30, 0 },
	LeftLowerArm = { 70, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local SLASH_FOLLOW: Frame = {
	UpperTorso = { -8, 30, 0 },
	Head = { 0, -22, 0 },
	RightUpperArm = { 70, 60, 0 },
	RightLowerArm = { 26, 0, 0 },
	RightHand = { 0, 14, 0 },
	LeftUpperArm = { 34, -30, 0 },
	LeftLowerArm = { 68, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
-- Heavy (alt): the knife comes up high, then drives down and forward.
local HEAVY_RAISE: Frame = {
	UpperTorso = { 8, -10, 0 },
	Head = { -4, 8, 0 },
	RightUpperArm = { 158, 0, 0 },
	RightLowerArm = { 62, 0, 0 },
	RightHand = { 20, 0, 0 },
	LeftUpperArm = { 70, -24, 0 },
	LeftLowerArm = { 60, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local HEAVY_STRIKE: Frame = {
	UpperTorso = { -20, 8, 0 },
	Head = { 14, -6, 0 },
	RightUpperArm = { 64, 10, 0 },
	RightLowerArm = { 2, 0, 0 },
	RightHand = { -30, 0, 0 },
	LeftUpperArm = { 30, -24, 0 },
	LeftLowerArm = { 60, 0, 0 },
	LeftHand = { 0, 0, 0 },
}

-- Draw (0.5 s at speed 1, played at the gun's equip time): the new gun
-- comes in low, rises a touch past the hold and settles on it.
local DRAW_LOW: Frame = {
	UpperTorso = { -4, 0, 0 },
	RightUpperArm = { 34, 10, 0 },
	RightLowerArm = { 30, 0, 0 },
	LeftUpperArm = { 26, -20, 0 },
	LeftLowerArm = { 44, 0, 0 },
}
local DRAW_RISE: Frame = hip()
DRAW_RISE.UpperTorso = { 6, -8, 0 } -- a touch past the hold, then settle

local ACTION = Enum.AnimationPriority.Action
local ACTION4 = Enum.AnimationPriority.Action4

local reload, reloadTimes = reloadFrames()
local sequences = {
	-- GG_AdsUp / Level / Down: tools/studio/MakeHoldAnimations (2026-11-04).
	sequence("GG_Reload", ACTION4, reload, reloadTimes, false),
	sequence(
		"GG_Flinch",
		ACTION4,
		{ FLINCH_REST, FLINCH_HIT, FLINCH_REST },
		{ 0, 0.05, 0.3 },
		false
	),
	sequence("GG_Draw", ACTION4, { DRAW_LOW, DRAW_RISE, hip() }, { 0, 0.32, 0.5 }, false),
	-- GG_KnifeReady / GG_KnifeSlash / GG_KnifeHeavy below are superseded
	-- (2026-11-05) by tools/studio/make_knife_poses.py (GG_KnifeReady,
	-- GG_KnifeSlash1-3, GG_KnifeHeavy; the ids in Config/Animations).
	sequence("GG_KnifeReady", ACTION, { KNIFE, knifeReady(1), KNIFE }, { 0, 1.2, 2.4 }, true),
	sequence(
		"GG_KnifeSlash",
		ACTION4,
		{ KNIFE, SLASH_WIND, SLASH_CUT, SLASH_FOLLOW, KNIFE },
		{ 0, 0.07, 0.13, 0.22, 0.42 },
		false
	),
	sequence(
		"GG_KnifeHeavy",
		ACTION4,
		{ KNIFE, HEAVY_RAISE, HEAVY_STRIKE, HEAVY_STRIKE, KNIFE },
		{ 0, 0.14, 0.24, 0.36, 0.62 },
		false
	),
	sequence(
		"GG_Death",
		ACTION4,
		{ DEATH_START, DEATH_BUCKLE, DEATH_DOWN },
		{ 0, 0.16, 0.34 },
		false
	),
}

-- Pose text for tools/studio/pose_text_to_rbxm.py (the Studio assistant's
-- HTTP allowlist blocks the old localhost receiver), one clip per line:
-- Name|Priority|Loop|Length|t>Joint:pitch,yaw,roll[,x,y,z];...|t>...
local lines = {}
for _, ks in sequences do
	local keys = {}
	local length = 0
	for _, kf in ks:GetKeyframes() do
		local k = kf :: Keyframe
		length = math.max(length, k.Time)
		local parts = {}
		for _, p in k:GetDescendants() do
			if p:IsA("Pose") and p.Weight > 0 then
				local x, y, z = p.CFrame:ToEulerAnglesYXZ()
				local pos = p.CFrame.Position
				local text = string.format(
					"%s:%.2f,%.2f,%.2f",
					p.Name,
					math.deg(x),
					math.deg(y),
					math.deg(z)
				)
				if pos.Magnitude > 1e-4 then
					text ..= string.format(",%.3f,%.3f,%.3f", pos.X, pos.Y, pos.Z)
				end
				table.insert(parts, text)
			end
		end
		table.insert(keys, string.format("%g>", k.Time) .. table.concat(parts, ";"))
	end
	local loop = if ks.Loop then "1" else "0"
	table.insert(
		lines,
		table.concat({ ks.Name, ks.Priority.Name, loop, string.format("%g", length) }, "|")
			.. "|"
			.. table.concat(keys, "|")
	)
end
return table.concat(lines, "\n")
