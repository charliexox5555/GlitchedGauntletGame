--!strict
-- Builds the third-person Mod animations (R15 KeyframeSequences), the same way
-- as tools/studio/MakePoseAnimations.luau, and saves each as a .rbxm in
-- art-source/animations/ through tools/studio/receive_server.py. Run in Studio
-- (Edit) via the MCP or the Command Bar, then upload each:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_ModThrow.rbxm "GG Mod Throw"
-- and put the ids in src/shared/Config/Animations.luau (MODS).
--
--   GG_ModHold   (looped)   the item up by the right shoulder, the free hand
--                forward and open, a slow breath
--   GG_ModThrow  (one-shot) overhand: coil (chest right, item cocked behind
--                the head, free arm pointing), snap through, follow across
--   GG_ModLob    (one-shot) underhand: lean in, swing down and back, out soft
--   GG_ModCast   (one-shot) the free hand draws in, then shoves out palm
--                first and holds while the wall goes up (Firewall)
--   GG_ModPlace  (one-shot) a quick half-kneel, the item pressed down in front
--   GG_ModHeal   (one-shot) pull the device in, thrust it at the target
--   (The use clips end on the gun hold, which takes over after them. Pass 2,
--   2026-11-04; previewed as still poses and measured: hand positions, chest
--   yaw and planted feet.)
--   GG_DashForward / Back / Left / Right (one-shot) the body leans into a
--                dash and comes back (torso only: the arms keep the gun hold)
--   GG_Updraft   (one-shot) knees tuck up as you launch, then hang down for
--                the fall (legs and hips only: the arms keep the gun hold)
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
	local r = CFrame.Angles(0, math.rad(p[2] or 0), 0)
		* CFrame.Angles(math.rad(p[1]), 0, math.rad(p[3] or 0))
	return CFrame.new(p[4] or 0, p[5] or 0, p[6] or 0) * r
end

-- `ease` is how this key moves on to the next one ("in" speeds up into a
-- snap, "out" slows out of one; default ease in and out).
type Ease = "in" | "out" | "inOut"
local EASE: { [Ease]: Enum.PoseEasingDirection } = {
	["in"] = Enum.PoseEasingDirection.In,
	out = Enum.PoseEasingDirection.Out,
	inOut = Enum.PoseEasingDirection.InOut,
}

local function keyframe(time: number, frame: Frame, ease: Ease?): Keyframe
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
		p.EasingDirection = EASE[ease or "inOut"]
	end
	return kf
end

-- `keys`: { time, frame, ease? }.
local function sequence(
	name: string,
	priority: Enum.AnimationPriority,
	loop: boolean,
	keys: { { any } }
): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = loop
	ks.Priority = priority
	for _, k in keys do
		keyframe(k[1], k[2], k[3]).Parent = ks
	end
	return ks
end

-- Poses -------------------------------------------------------------------------

-- Yaw (+Y) turns a joint to the left, so a right-handed wind-up turns the
-- chest right (negative) and the release turns it left. The head turns
-- against the chest so the eyes stay on the target. Every one-shot ends on
-- the gun hold (MakePoseAnimations `aim(0)`), which is what takes over.

-- Holding a Mod: the item up by the right shoulder, ready to go; the free
-- hand forward and open. A slow breath (the loop).
local function hold(breath: number): Frame
	return {
		UpperTorso = { 2 + breath * 1.5, 0, 0 },
		Head = { -breath, 0, 0 },
		RightUpperArm = { 56 + breath * 2, 18, 0 },
		RightLowerArm = { 58, 0, 0 },
		RightHand = { -10, 0, 0 },
		LeftUpperArm = { 46 + breath * 2, -18, 0 },
		LeftLowerArm = { 38, 0, 0 },
		LeftHand = { -6, 0, 0 },
	}
end
local HOLD = hold(0)

local GUN: Frame = {
	UpperTorso = { 0, 0, 0 },
	Head = { 0, 0, 0 },
	RightUpperArm = { 90, 8, 0 },
	RightLowerArm = { 0, 0, 0 },
	RightHand = { 0, 0, 0 },
	LeftUpperArm = { 90, -38, 0 },
	LeftLowerArm = { 18, 0, 0 },
	LeftHand = { 0, 0, 0 },
}

-- Throw (overhand): coil (chest right, item cocked behind the head, the free
-- arm pointing at the target), snap through (chest left and forward, arm
-- out, wrist flick, the free arm pulled in), follow through across the body.
local THROW_COIL: Frame = {
	UpperTorso = { 6, -28, 0 },
	Head = { 0, 22, 0 },
	RightUpperArm = { 150, -10, 18 },
	RightLowerArm = { 82, 0, 0 },
	RightHand = { 10, 0, 0 },
	LeftUpperArm = { 94, 24, 0 },
	LeftLowerArm = { 6, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local THROW_COCK: Frame = {
	UpperTorso = { 9, -33, 0 },
	Head = { 2, 26, 0 },
	RightUpperArm = { 158, -12, 22 },
	RightLowerArm = { 90, 0, 0 },
	RightHand = { 16, 0, 0 },
	LeftUpperArm = { 96, 28, 0 },
	LeftLowerArm = { 4, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local THROW_RELEASE: Frame = {
	UpperTorso = { -14, 22, 0 },
	Head = { -4, -18, 0 },
	RightUpperArm = { 102, 10, 0 },
	RightLowerArm = { 8, 0, 0 },
	RightHand = { -24, 0, 0 },
	LeftUpperArm = { 32, -28, 0 },
	LeftLowerArm = { 72, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local THROW_FOLLOW: Frame = {
	UpperTorso = { -18, 28, 0 },
	Head = { -2, -22, 0 },
	RightUpperArm = { 42, 42, 0 },
	RightLowerArm = { 26, 0, 0 },
	RightHand = { -12, 0, 0 },
	LeftUpperArm = { 16, -18, 0 },
	LeftLowerArm = { 60, 0, 0 },
	LeftHand = { 0, 0, 0 },
}

-- Lob (underhand): lean in and swing the arm down and back, then up and out
-- soft, the arm following up high.
local LOB_BACK: Frame = {
	UpperTorso = { -12, -10, 0 },
	Head = { 10, 8, 0 },
	RightUpperArm = { -34, -6, 0 },
	RightLowerArm = { 12, 0, 0 },
	RightHand = { 0, 0, 0 },
	LeftUpperArm = { 56, 18, 0 },
	LeftLowerArm = { 24, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local LOB_RELEASE: Frame = {
	UpperTorso = { -4, 8, 0 },
	Head = { 2, -6, 0 },
	RightUpperArm = { 70, 6, 0 },
	RightLowerArm = { 6, 0, 0 },
	RightHand = { 16, 0, 0 },
	LeftUpperArm = { 30, -10, 0 },
	LeftLowerArm = { 40, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local LOB_FOLLOW: Frame = {
	UpperTorso = { 2, 10, 0 },
	Head = { -2, -8, 0 },
	RightUpperArm = { 108, 8, 0 },
	RightLowerArm = { 16, 0, 0 },
	RightHand = { 0, 0, 0 },
	LeftUpperArm = { 24, -10, 0 },
	LeftLowerArm = { 44, 0, 0 },
	LeftHand = { 0, 0, 0 },
}

-- Cast (Firewall): the free hand draws back to the chest (chest turned
-- left, left shoulder back), then shoves out palm first (chest right) and
-- holds there while the wall goes up.
local CAST_DRAW: Frame = {
	UpperTorso = { 4, 12, 0 },
	Head = { 0, -10, 0 },
	RightUpperArm = { 44, 16, 0 },
	RightLowerArm = { 50, 0, 0 },
	RightHand = { 0, 0, 0 },
	LeftUpperArm = { 40, 26, 0 },
	LeftLowerArm = { 96, 0, 0 },
	LeftHand = { 12, 0, 0 },
}
local function castPush(tremor: number): Frame
	return {
		UpperTorso = { -8 + tremor, -14, 0 },
		Head = { 4, 12, 0 },
		RightUpperArm = { 30, 10, 0 },
		RightLowerArm = { 40, 0, 0 },
		RightHand = { 0, 0, 0 },
		LeftUpperArm = { 92 - tremor, -8, 0 },
		LeftLowerArm = { 0, 0, 0 },
		LeftHand = { -36 + tremor * 2, 0, 0 },
	}
end

-- Place (Recall): a quick half-kneel, chest over the spot, the item pressed
-- down in front, the free hand on the knee; back up to the gun.
local function kneel(k: number): Frame
	local lean, hip, knee = -8 * k, 44 * k, -64 * k
	return {
		LowerTorso = { lean, 0, 0, 0, -0.42 * k, 0 },
		RightUpperLeg = { hip + 8 * k, 0, 0 },
		RightLowerLeg = { knee - 6 * k, 0, 0 },
		RightFoot = { -(lean + hip + knee - 2 * k), 0, 0 },
		LeftUpperLeg = { hip - 14 * k, 0, 0 },
		LeftLowerLeg = { knee + 4 * k, 0, 0 },
		LeftFoot = { -(lean + hip + knee - 10 * k), 0, 0 },
	}
end
local function with(a: Frame, b: Frame): Frame
	local out = table.clone(a)
	for k, v in b do
		out[k] = v
	end
	return out
end
local PLACE_DIP = with(kneel(1), {
	UpperTorso = { -26, 0, 0 },
	Head = { 18, 0, 0 },
	RightUpperArm = { 32, 6, 0 },
	RightLowerArm = { 22, 0, 0 },
	RightHand = { -26, 0, 0 },
	LeftUpperArm = { 24, -16, 0 },
	LeftLowerArm = { 30, 0, 0 },
	LeftHand = { 0, 0, 0 },
})
local PLACE_PRESS = with(kneel(1.05), {
	UpperTorso = { -28, 0, 0 },
	Head = { 20, 0, 0 },
	RightUpperArm = { 24, 6, 0 },
	RightLowerArm = { 20, 0, 0 },
	RightHand = { -38, 0, 0 },
	LeftUpperArm = { 24, -16, 0 },
	LeftLowerArm = { 30, 0, 0 },
	LeftHand = { 0, 0, 0 },
})
local HOLD_STAND = with(kneel(0), HOLD)
local GUN_STAND = with(kneel(0), GUN)

-- Heal (Heal Orb, the Recon launcher): pull the device in, thrust it out at
-- the target (right shoulder forward), hold a beat, back to the gun.
local HEAL_PULL: Frame = {
	UpperTorso = { 4, -8, 0 },
	Head = { 0, 8, 0 },
	RightUpperArm = { 58, 16, 0 },
	RightLowerArm = { 76, 0, 0 },
	RightHand = { 0, 0, 0 },
	LeftUpperArm = { 40, -16, 0 },
	LeftLowerArm = { 40, 0, 0 },
	LeftHand = { 0, 0, 0 },
}
local function healThrust(settle: number): Frame
	return {
		UpperTorso = { -8 + settle * 2, 10 - settle * 2, 0 },
		Head = { 2, -10 + settle * 2, 0 },
		RightUpperArm = { 95 - settle * 3, 5, 0 },
		RightLowerArm = { settle * 4, 0, 0 },
		RightHand = { -12, 0, 0 },
		LeftUpperArm = { 34, -14, 0 },
		LeftLowerArm = { 46, 0, 0 },
		LeftHand = { 0, 0, 0 },
	}
end

-- Dash leans: only the torso joints, so the arms keep holding the gun. Into
-- the dash for ~0.2 s, then back. LowerTorso roll +Z leans left.
local LEAN_REST: Frame = { LowerTorso = { 0, 0, 0 }, UpperTorso = { 0, 0, 0 }, Head = { 0, 0, 0 } }
local LEAN: { [string]: Frame } = {
	Forward = { LowerTorso = { -10, 0, 0 }, UpperTorso = { -16, 0, 0 }, Head = { 10, 0, 0 } },
	Back = { LowerTorso = { 6, 0, 0 }, UpperTorso = { 12, 0, 0 }, Head = { -6, 0, 0 } },
	Left = { LowerTorso = { -4, 0, 14 }, UpperTorso = { 0, 0, 8 }, Head = { 0, 0, -8 } },
	Right = { LowerTorso = { -4, 0, -14 }, UpperTorso = { 0, 0, -8 }, Head = { 0, 0, 8 } },
}

-- Updraft: legs tuck (knees up, shins back), a slight forward hunch.
local LEGS_REST: Frame = {
	LowerTorso = { 0, 0, 0 },
	RightUpperLeg = { 0, 0, 0 },
	RightLowerLeg = { 0, 0, 0 },
	LeftUpperLeg = { 0, 0, 0 },
	LeftLowerLeg = { 0, 0, 0 },
}
local UPDRAFT_TUCK: Frame = {
	LowerTorso = { -6, 0, 0 },
	RightUpperLeg = { 55, 0, 4 },
	RightLowerLeg = { -75, 0, 0 },
	LeftUpperLeg = { 40, 0, -4 },
	LeftLowerLeg = { -60, 0, 0 },
}

local ACTION = Enum.AnimationPriority.Action
local ACTION4 = Enum.AnimationPriority.Action4

local sequences = {
	sequence("GG_ModHold", ACTION, true, {
		{ 0, HOLD },
		{ 1.2, hold(1) },
		{ 2.4, HOLD },
	}),
	sequence("GG_ModThrow", ACTION4, false, {
		{ 0, HOLD },
		{ 0.12, THROW_COIL },
		{ 0.18, THROW_COCK, "in" },
		{ 0.23, THROW_RELEASE, "out" },
		{ 0.36, THROW_FOLLOW },
		{ 0.62, GUN },
	}),
	sequence("GG_ModLob", ACTION4, false, {
		{ 0, HOLD },
		{ 0.14, LOB_BACK, "in" },
		{ 0.26, LOB_RELEASE, "out" },
		{ 0.38, LOB_FOLLOW },
		{ 0.62, GUN },
	}),
	sequence("GG_ModCast", ACTION4, false, {
		{ 0, HOLD },
		{ 0.08, CAST_DRAW, "in" },
		{ 0.16, castPush(0), "out" },
		{ 0.4, castPush(1) },
		{ 0.7, castPush(0) },
		{ 1, GUN },
	}),
	sequence("GG_ModPlace", ACTION4, false, {
		{ 0, HOLD_STAND },
		{ 0.15, PLACE_DIP, "out" },
		{ 0.28, PLACE_PRESS },
		{ 0.4, PLACE_PRESS },
		{ 0.7, GUN_STAND },
	}),
	sequence("GG_ModHeal", ACTION4, false, {
		{ 0, HOLD },
		{ 0.07, HEAL_PULL, "in" },
		{ 0.14, healThrust(0), "out" },
		{ 0.32, healThrust(1) },
		{ 0.55, GUN },
	}),
}
table.insert(
	sequences,
	sequence("GG_Updraft", ACTION4, false, {
		{ 0, LEGS_REST },
		{ 0.08, UPDRAFT_TUCK },
		{ 0.32, UPDRAFT_TUCK },
		{ 0.6, LEGS_REST },
	})
)
for _, dir in { "Forward", "Back", "Left", "Right" } do
	table.insert(
		sequences,
		sequence("GG_Dash" .. dir, ACTION4, false, {
			{ 0, LEAN_REST },
			{ 0.06, LEAN[dir] },
			{ 0.2, LEAN[dir] },
			{ 0.36, LEAN_REST },
		})
	)
end

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
