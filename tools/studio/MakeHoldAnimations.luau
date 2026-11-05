--!strict
-- Builds the third-person gun holds (R15 KeyframeSequences) by solving them on
-- a real rig with a real gun. Run in Studio (Edit) via the MCP or the Command
-- Bar; it returns one line of pose text per clip. Save that to a file and run
--     python tools/studio/pose_text_to_rbxm.py poses.txt
-- (the Studio assistant's HTTP allowlist blocks the old localhost receiver),
-- then upload each with:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_AimLevel.rbxm "GG AimLevel"
-- and put the ids in src/shared/Config/Animations.luau.
--
-- Why solved, not hand-keyed (2026-11-04, lane D): the old hold put the gun at
-- arm's length, so the left grip was 3.8 studs from the left shoulder (the arm
-- reaches 1.86) and the off hand never touched the gun. Here each hold is
-- described as where the gun sits relative to the right shoulder, and an exact
-- two-bone IK puts the right hand on the grip and the left hand on the gun's
-- LeftGrip (slid back along the barrel when a long gun's grip is out of reach).
-- The reference guns are the Vandal (long guns) and the Sheriff (sidearms);
-- GripController IKs the left hand onto each gun's own grip in play.
--
-- Pose CFrames are joint Transforms, written as { pitch, yaw, roll } in
-- degrees (CFrame.fromEulerAnglesYXZ), like the other Make*Animations tools.
-- Builds a temporary rig in Workspace and removes it at the end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- The third-person gun's weld (WeaponService GRIP_C0).
local GRIP_C0 = CFrame.new(0, -0.15, -0.05) * CFrame.Angles(-math.pi / 2, 0, 0)
local ROOT = CFrame.new(0, 500, 0)

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
}
local ORDER = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
}

local function cf(p: JointPose): CFrame
	return CFrame.new(p[4] or 0, p[5] or 0, p[6] or 0)
		* CFrame.fromEulerAnglesYXZ(math.rad(p[1]), math.rad(p[2] or 0), math.rad(p[3] or 0))
end

local function toPose(t: CFrame): JointPose
	local x, y, z = t:ToEulerAnglesYXZ()
	return { math.deg(x), math.deg(y), math.deg(z) }
end

-- Rig ---------------------------------------------------------------------------

local rig = Players:CreateHumanoidModelFromDescription(
	Instance.new("HumanoidDescription"),
	Enum.HumanoidRigType.R15
)
rig.Name = "GGHoldRig"
for _, d in rig:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
rig.Parent = workspace

local joints: { [string]: AnimationConstraint } = {}
for _, c in rig:GetDescendants() do
	if c:IsA("AnimationConstraint") and c.Attachment1 then
		joints[(c.Attachment1 :: Attachment).Parent.Name] = c
	end
end

local function part(name: string): BasePart
	local p = rig:FindFirstChild(name)
	assert(p and p:IsA("BasePart"), name)
	return p
end

local gun: Model? = nil
local function setGun(id: string)
	if gun then
		gun:Destroy()
	end
	local m = (ReplicatedStorage:WaitForChild("Weapons"):WaitForChild(id) :: Model):Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = rig
	gun = m
end

local function grip(name: string): Attachment
	for _, d in (gun :: Model):GetDescendants() do
		if d.Name == name and d:IsA("Attachment") then
			return d
		end
	end
	error("no " .. name)
end

-- Forward kinematics: places the rig's parts for `frame` (joint Transforms).
local function apply(frame: Frame)
	part("HumanoidRootPart").CFrame = ROOT
	for _, n in ORDER do
		local c = joints[n]
		local a0, a1 = c.Attachment0 :: Attachment, c.Attachment1 :: Attachment
		local t = if frame[n] then cf(frame[n]) else CFrame.identity
		part(n).CFrame = (a0.Parent :: BasePart).CFrame * a0.CFrame * t * a1.CFrame:Inverse()
	end
	local m = gun :: Model
	local handle = m.PrimaryPart :: BasePart
	local target = part("RightHand").CFrame * GRIP_C0
	m:PivotTo(target * handle.CFrame:ToObjectSpace(m:GetPivot()))
end

local function frameOf(y: Vector3, hint: Vector3): CFrame
	local yu = y.Unit
	local x = (hint - yu * hint:Dot(yu)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, yu, x:Cross(yu))
end

-- Exact two-bone IK: the `side` hand to `hand` (its Hand part CFrame), the
-- elbow toward `pole` (world direction). Writes the arm's three joints.
local function ik(frame: Frame, side: string, hand: CFrame, pole: Vector3)
	apply(frame)
	local sh, el, wr =
		joints[side .. "UpperArm"], joints[side .. "LowerArm"], joints[side .. "Hand"]
	local shA0, shA1 = sh.Attachment0 :: Attachment, sh.Attachment1 :: Attachment
	local elA0, elA1 = el.Attachment0 :: Attachment, el.Attachment1 :: Attachment
	local wrA0, wrA1 = wr.Attachment0 :: Attachment, wr.Attachment1 :: Attachment
	local s = shA0.WorldPosition
	local a = (elA0.Position - shA1.Position).Magnitude
	local b = (wrA0.Position - elA1.Position).Magnitude
	local w = (hand * wrA1.CFrame).Position
	local v = w - s
	local d = math.clamp(v.Magnitude, 0.05, a + b - 1e-3)
	local dir = v.Unit
	local x = (a * a - b * b + d * d) / (2 * d)
	local h = math.sqrt(math.max(a * a - x * x, 0))
	local perp = (pole - dir * pole:Dot(dir)).Unit
	local e = s + dir * x + perp * h
	local wc = s + dir * d
	local hinge = (e - s):Cross(wc - e)
	hinge = if hinge.Magnitude < 1e-4 then part("UpperTorso").CFrame.RightVector else -hinge.Unit
	local function boneCF(from: Vector3, to: Vector3, att: Attachment, attEnd: Attachment): CFrame
		local rot = frameOf(from - to, hinge)
			* frameOf(-(attEnd.Position - att.Position), Vector3.xAxis):Inverse()
		return CFrame.new(from) * rot * CFrame.new(-att.Position)
	end
	local function transform(c: AnimationConstraint, partCF: CFrame): CFrame
		local a0, a1 = c.Attachment0 :: Attachment, c.Attachment1 :: Attachment
		return ((a0.Parent :: BasePart).CFrame * a0.CFrame):Inverse() * partCF * a1.CFrame
	end
	frame[side .. "UpperArm"] = toPose(transform(sh, boneCF(s, e, shA1, elA0)).Rotation)
	apply(frame)
	frame[side .. "LowerArm"] = toPose(transform(el, boneCF(e, wc, elA1, wrA0)).Rotation)
	apply(frame)
	frame[side .. "Hand"] = toPose(transform(wr, hand).Rotation)
	apply(frame)
end

-- Holds -------------------------------------------------------------------------

export type Hold = {
	chest: { number }, -- UpperTorso { pitch, yaw, roll } before the aim pitch
	head: { number },
	hold: Vector3, -- the grip (handle) from the right shoulder, in body space
	gunPitch: number?, -- extra gun pitch / yaw (the sprint carry points it down and across)
	gunYaw: number?,
	poleR: Vector3, -- elbow directions, body space
	poleL: Vector3,
	palm: number, -- left hand roll around the barrel (90: palm up under the guard)
	under: number, -- left hand centre below the grip line
	side: number, -- ...and to the gun's right (-: left, cupping a pistol grip)
	reach: number, -- longest left shoulder-to-hand distance before sliding back
	chestShare: number?, -- share of the aim pitch the chest takes (default 0.35)
}

local function solve(p: Hold, pitch: number): Frame
	local share = p.chestShare or 0.35
	local frame: Frame = {
		UpperTorso = { p.chest[1] + pitch * share, p.chest[2], p.chest[3] },
		Head = { p.head[1] + pitch * (1 - share) * 0.5, p.head[2], p.head[3] },
	}
	apply(frame)
	local rs = (joints.RightUpperArm.Attachment0 :: Attachment).WorldPosition
	local aim = ROOT.Rotation * CFrame.Angles(math.rad(pitch), 0, 0)
	local at = (CFrame.new(rs) * aim * CFrame.new(p.hold)).Position
	local handle = CFrame.new(at)
		* aim
		* CFrame.fromEulerAnglesYXZ(math.rad(p.gunPitch or 0), math.rad(p.gunYaw or 0), 0)
	ik(frame, "Right", handle * GRIP_C0:Inverse(), ROOT:VectorToWorldSpace(p.poleR))
	local h = ((gun :: Model).PrimaryPart :: BasePart).CFrame
	local ls = (joints.LeftUpperArm.Attachment0 :: Attachment).WorldPosition
	local base = grip("LeftGrip").WorldPosition - h.UpVector * p.under + h.RightVector * p.side
	local target, back = base, 0
	while (target - ls).Magnitude > p.reach and back < 1.5 do
		back += 0.02
		target = base - h.LookVector * back
	end
	local hand = CFrame.fromMatrix(target, h.LookVector:Cross(h.UpVector), h.UpVector)
		* CFrame.Angles(0, 0, math.rad(p.palm))
	ik(frame, "Left", hand, ROOT:VectorToWorldSpace(p.poleL))
	return frame
end

-- Long guns: shouldered, chest bladed ~26 deg (right shoulder back), head
-- counter-turned onto the stock line, right elbow down.
local LONG_HIP: Hold = {
	chest = { 2, -26, 0 },
	head = { -10, 22, 8 },
	hold = Vector3.new(-0.5, -0.38, -1.25),
	poleR = Vector3.new(0.5, -1, 0.3),
	poleL = Vector3.new(-0.2, -1, -0.2),
	palm = 90,
	under = 0.14,
	side = 0,
	reach = 1.8,
}
-- Sights: the gun up to the cheek, more square, head down on the stock.
local LONG_ADS: Hold = {
	chest = { 4, -20, 0 },
	head = { -16, 14, 14 },
	hold = Vector3.new(-0.62, -0.08, -1.15),
	poleR = Vector3.new(0.6, -1, 0.3),
	poleL = Vector3.new(-0.2, -1, -0.2),
	palm = 90,
	under = 0.14,
	side = 0,
	reach = 1.8,
}
-- Sidearms: square two-handed hold, arms forward, the left hand cupping the
-- grip hand.
local PISTOL_HIP: Hold = {
	chest = { 0, -6, 0 },
	head = { -6, 6, 0 },
	hold = Vector3.new(-0.85, -0.36, -1.55),
	poleR = Vector3.new(0.8, -1, 0),
	poleL = Vector3.new(-0.8, -1, 0),
	palm = 0,
	under = 0.1,
	side = -0.16,
	reach = 1.8,
}
local PISTOL_ADS: Hold = {
	chest = { 2, -4, 0 },
	head = { -10, 4, 4 },
	hold = Vector3.new(-0.95, -0.02, -1.62),
	poleR = Vector3.new(0.9, -1, 0),
	poleL = Vector3.new(-0.9, -1, 0),
	palm = 0,
	under = 0.1,
	side = -0.16,
	reach = 1.8,
}
-- Sprint: low-ready carry, the muzzle down and across the body, chest leaning
-- into the run (one pose, no pitch).
local SPRINT: Hold = {
	chest = { -12, -18, 0 },
	head = { 6, 16, 0 },
	hold = Vector3.new(-0.55, -0.85, -0.8),
	gunPitch = -38,
	gunYaw = 28,
	poleR = Vector3.new(0.6, -1, 0.6),
	poleL = Vector3.new(-0.3, -1, 0),
	palm = 90,
	under = 0.14,
	side = 0,
	reach = 1.8,
	chestShare = 0,
}

-- Clips -------------------------------------------------------------------------

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
	end
	return kf
end

local function held(name: string, priority: Enum.AnimationPriority, frame: Frame): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = true
	ks.Priority = priority
	keyframe(0, frame).Parent = ks
	keyframe(1, frame).Parent = ks
	return ks
end

local ACTION = Enum.AnimationPriority.Action
local ACTION2 = Enum.AnimationPriority.Action2
local PITCH = 70 -- Config/Animations AIM_PITCH_RANGE

local sequences: { KeyframeSequence } = {}
setGun("Vandal")
for _, set in { { "Aim", LONG_HIP }, { "Ads", LONG_ADS } } do
	local prefix, hold = set[1] :: string, set[2] :: Hold
	table.insert(sequences, held("GG_" .. prefix .. "Up", ACTION, solve(hold, PITCH)))
	table.insert(sequences, held("GG_" .. prefix .. "Level", ACTION, solve(hold, 0)))
	table.insert(sequences, held("GG_" .. prefix .. "Down", ACTION, solve(hold, -PITCH)))
end
table.insert(sequences, held("GG_Sprint", ACTION2, solve(SPRINT, 0)))
setGun("Sheriff")
for _, set in { { "PistolAim", PISTOL_HIP }, { "PistolAds", PISTOL_ADS } } do
	local prefix, hold = set[1] :: string, set[2] :: Hold
	table.insert(sequences, held("GG_" .. prefix .. "Up", ACTION, solve(hold, PITCH)))
	table.insert(sequences, held("GG_" .. prefix .. "Level", ACTION, solve(hold, 0)))
	table.insert(sequences, held("GG_" .. prefix .. "Down", ACTION, solve(hold, -PITCH)))
end
rig:Destroy()

-- One line per clip: Name|Priority|Joint:pitch,yaw,roll;... (a held pose).
local lines = {}
for _, ks in sequences do
	local parts = {}
	for _, p in (ks:GetKeyframes()[1] :: Keyframe):GetDescendants() do
		if p:IsA("Pose") and p.Weight > 0 then
			local x, y, z = p.CFrame:ToEulerAnglesYXZ()
			table.insert(
				parts,
				string.format("%s:%.2f,%.2f,%.2f", p.Name, math.deg(x), math.deg(y), math.deg(z))
			)
		end
	end
	table.sort(parts)
	table.insert(lines, ks.Name .. "|" .. ks.Priority.Name .. "|" .. table.concat(parts, ";"))
end
return table.concat(lines, "\n")
