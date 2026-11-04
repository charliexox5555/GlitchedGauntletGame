--!strict
-- Builds the third-person locomotion clips (R15 KeyframeSequences, legs and
-- hips only: the arms and chest belong to the gun-holding aim layers) and
-- saves each as a Studio-serialized .rbxm in art-source/animations/ through
-- tools/studio/receive_server.py. Run in Studio (Edit) via the MCP or the
-- Command Bar, then upload each with:
--     python tools/opencloud/upload_asset.py --group 11116787 --type Animation \
--         art-source/animations/GG_RunF.rbxm "GG RunF"
-- and put the ids in src/shared/Config/Animations.luau (LOCOMOTION).
--
-- Conventions as in MakePoseAnimations: pose CFrames are joint Transforms;
-- +X rotation swings a leg forward; on LowerTorso it leans the body back;
-- a negative knee pitch bends the knee. Angles in degrees.
--
-- The four run directions share one length, so blended together (Simulation/
-- Poses) their feet stay in step. Each cycle is one full stride (two steps).

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local RECEIVER = "http://127.0.0.1:34999/save?path=art-source/animations/"
local SAMPLES = 16 -- keyframes per cycle

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
		p.EasingStyle = Enum.PoseEasingStyle.Linear
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
	length: number,
	loop: boolean,
	times: { number }?
): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = loop
	ks.Priority = priority
	for i, frame in frames do
		local t = if times
			then times[i]
			elseif #frames == 1 then 0
			else (i - 1) / (#frames - 1) * length
		keyframe(t, frame).Parent = ks
	end
	if #frames == 1 then
		keyframe(length, frames[1]).Parent = ks
	end
	return ks
end

-- A cycle sampled SAMPLES times, the last frame equal to the first (seamless).
local function cycle(at: (phase: number) -> Frame): { Frame }
	local frames = {}
	for i = 0, SAMPLES do
		table.insert(frames, at(i / SAMPLES * math.pi * 2))
	end
	return frames
end

-- Gait ----------------------------------------------------------------------------

export type Gait = {
	swing: number, -- hip swing each way (deg)
	lift: number, -- extra knee bend at mid-swing (deg)
	knee: number, -- knee bend while planted (deg)
	lean: number, -- body lean forward (deg, + = forward)
	bob: number, -- hip drop at each footfall (studs)
	twist: number, -- hip yaw following the legs (deg)
	backward: boolean?, -- the leg travels backward through the air (backpedal)
}

-- One leg at `p`: hip angle, knee, ankle. In the air while the leg swings
-- the way we travel; bent most at mid-swing.
local function leg(g: Gait, p: number): (number, number, number)
	local hip = g.swing * math.sin(p)
	local swinging = if g.backward then -math.cos(p) else math.cos(p)
	local knee = -(g.knee + g.lift * math.max(swinging, 0))
	-- Keep the foot near flat, with a little toe-off behind the body.
	local ankle = -(hip + knee - g.lean) * 0.75 + (if hip < 0 then -hip * 0.25 else 0)
	return hip, knee, ankle
end

local function forwardGait(g: Gait): (phase: number) -> Frame
	return function(p: number): Frame
		local rh, rk, ra = leg(g, p)
		local lh, lk, la = leg(g, p + math.pi)
		-- The hips drop at each footfall (twice a stride) and turn with the legs.
		local drop = -g.bob * (0.5 + 0.5 * math.cos(2 * p))
		return {
			LowerTorso = { -g.lean, g.twist * math.sin(p), 0, 0, drop, 0 },
			RightUpperLeg = { rh, 0, 0 },
			RightLowerLeg = { rk, 0, 0 },
			RightFoot = { ra, 0, 0 },
			LeftUpperLeg = { lh, 0, 0 },
			LeftLowerLeg = { lk, 0, 0 },
			LeftFoot = { la, 0, 0 },
		}
	end
end

-- Strafing: the legs swing sideways (roll) instead of forward, the lead leg
-- stepping out while the other closes; the body leans into the move. `side`
-- is +1 for right, -1 for left.
local function strafeGait(side: number): (phase: number) -> Frame
	local swing, lift, lean, bob = 22, 55, 7, 0.16
	return function(p: number): Frame
		local function sideLeg(q: number): (number, number, number, number)
			local out = swing * math.sin(q)
			local inAir = math.max(math.cos(q), 0)
			local knee = -(10 + lift * inAir)
			local hip = 8 + 20 * inAir -- lift the knee a little forward while stepping
			local ankle = -(hip + knee) * 0.75
			return out, hip, knee, ankle
		end
		local ro, rh, rk, ra = sideLeg(p)
		local lo, lh, lk, la = sideLeg(p + math.pi)
		local drop = -bob * (0.5 + 0.5 * math.cos(2 * p))
		return {
			LowerTorso = { -4, 0, -lean * side, 0, drop, 0 },
			RightUpperLeg = { rh, 0, -ro * side },
			RightLowerLeg = { rk, 0, 0 },
			RightFoot = { ra, 0, ro * side * 0.5 },
			LeftUpperLeg = { lh, 0, -lo * side },
			LeftLowerLeg = { lk, 0, 0 },
			LeftFoot = { la, 0, lo * side * 0.5 },
		}
	end
end

-- Clips ---------------------------------------------------------------------------

local RUN: Gait = { swing = 34, lift = 78, knee = 10, lean = 6, bob = 0.18, twist = 8 }
local BACK: Gait =
	{ swing = 26, lift = 60, knee = 12, lean = -4, bob = 0.14, twist = 6, backward = true }
local SPRINT: Gait = { swing = 50, lift = 105, knee = 12, lean = 14, bob = 0.26, twist = 12 }

local RUN_LENGTH = 0.62 -- seconds per stride at Config/Animations LOCOMOTION.runSpeed
local SPRINT_LENGTH = 0.56

-- Idle: a ready stance, feet apart, knees soft, a slow breath in the hips.
local function idle(p: number): Frame
	local breath = 0.04 * math.sin(p)
	return {
		LowerTorso = { -3, 0, 0, 0, -0.12 + breath, 0 },
		RightUpperLeg = { 8, -6, -5 },
		RightLowerLeg = { -14, 0, 0 },
		RightFoot = { 4, 6, 5 },
		LeftUpperLeg = { -2, 10, 6 },
		LeftLowerLeg = { -10, 0, 0 },
		LeftFoot = { 10, -10, -6 },
	}
end

local function idleCycle(): { Frame }
	local frames = {}
	for i = 0, 4 do
		table.insert(frames, idle(i / 4 * math.pi * 2))
	end
	return frames
end

-- Jump: knees drawn up, one leg ahead. Fall: legs hanging, reaching down.
local JUMP: Frame = {
	LowerTorso = { -6, 0, 0 },
	RightUpperLeg = { 58, 0, -3 },
	RightLowerLeg = { -78, 0, 0 },
	RightFoot = { 18, 0, 0 },
	LeftUpperLeg = { 18, 0, 3 },
	LeftLowerLeg = { -96, 0, 0 },
	LeftFoot = { 35, 0, 0 },
}
local FALL: Frame = {
	LowerTorso = { 4, 0, 0 },
	RightUpperLeg = { 26, 0, -4 },
	RightLowerLeg = { -34, 0, 0 },
	RightFoot = { 6, 0, 0 },
	LeftUpperLeg = { -8, 0, 4 },
	LeftLowerLeg = { -22, 0, 0 },
	LeftFoot = { 14, 0, 0 },
}

-- Land: a quick knee dip that springs back (a one-shot over the run).
local LAND_DIP: Frame = {
	LowerTorso = { -10, 0, 0, 0, -0.55, 0 },
	RightUpperLeg = { 38, 0, -4 },
	RightLowerLeg = { -62, 0, 0 },
	RightFoot = { 22, 0, 0 },
	LeftUpperLeg = { 26, 0, 4 },
	LeftLowerLeg = { -56, 0, 0 },
	LeftFoot = { 28, 0, 0 },
}
local LAND_REST: Frame = {
	LowerTorso = { -3, 0, 0, 0, -0.1, 0 },
	RightUpperLeg = { 6, 0, 0 },
	RightLowerLeg = { -10, 0, 0 },
	RightFoot = { 4, 0, 0 },
	LeftUpperLeg = { 4, 0, 0 },
	LeftLowerLeg = { -10, 0, 0 },
	LeftFoot = { 6, 0, 0 },
}

local MOVEMENT = Enum.AnimationPriority.Movement
local IDLE = Enum.AnimationPriority.Idle
local ACTION3 = Enum.AnimationPriority.Action3

local sequences = {
	sequence("GG_RunF", MOVEMENT, cycle(forwardGait(RUN)), RUN_LENGTH, true),
	sequence("GG_RunB", MOVEMENT, cycle(forwardGait(BACK)), RUN_LENGTH, true),
	sequence("GG_RunR", MOVEMENT, cycle(strafeGait(1)), RUN_LENGTH, true),
	sequence("GG_RunL", MOVEMENT, cycle(strafeGait(-1)), RUN_LENGTH, true),
	sequence("GG_SprintRun", MOVEMENT, cycle(forwardGait(SPRINT)), SPRINT_LENGTH, true),
	sequence("GG_Idle", IDLE, idleCycle(), 3.2, true),
	sequence("GG_Jump", MOVEMENT, { JUMP }, 1, true),
	sequence("GG_Fall", MOVEMENT, { FALL }, 1, true),
	sequence(
		"GG_Land",
		ACTION3,
		{ LAND_REST, LAND_DIP, LAND_REST },
		0.32,
		false,
		{ 0, 0.07, 0.32 }
	),
	-- Animate's walk / run are pointed at this: the directional set above
	-- carries the legs instead.
	sequence("GG_Null", MOVEMENT, { {} }, 1, true),
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
