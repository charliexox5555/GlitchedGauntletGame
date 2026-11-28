--!strict
-- Third-person pose tracks (Config/Animations): holding the gun (a blend of
-- three pitch poses), the run's upper body, crouch / crouch-walk and slide, and
-- the Mods: a hold pose while a held Mod is up (player attribute ModHeld)
-- and a one-shot throw / place / heal on each use (ModUseKind / ModUseAt,
-- written by ModService; the character attribute PoseUseSeen remembers the
-- last one played). Updraft's Crash Down: a dive pose while UpdraftSlam is
-- "Down" and a landing clip once per UpdraftSlamAt.
--
-- Stepped inside the Server Authority simulation, the same way Roblox's own
-- Animate module works: the server poses every player, each client predicts
-- its own character. Both sides read the same inputs (MoveState from
-- Simulation/Movement, the AimPitch input action, the equipped weapon and
-- ground speed), so the prediction matches. Tracks played only on a client
-- get stopped by the server. Weights move through the Animator's own fades,
-- so state changes blend instead of popping.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Authority = require(script.Parent.Parent.Authority)
local Health = require(script.Parent.Parent.Health)
local Fields = require(script.Parent.Fields)
local Pawns = require(script.Parent.Pawns)
local Animations = require(script.Parent.Parent.Config.Animations)
local TpIk = require(script.Parent.Parent.Config.TpIk)
local Weapons = require(script.Parent.Parent.Config.Weapons)

local PoseSim = {}

type Spec = { priority: Enum.AnimationPriority, fade: number }

local FADE = Animations.FADE
local SPECS: { [string]: Spec } = {
	AimUp = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	AimLevel = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	AimDown = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	Sprint = { priority = Enum.AnimationPriority.Action2, fade = FADE.sprint },
	SprintPistol = { priority = Enum.AnimationPriority.Action2, fade = FADE.sprint },
	SprintKnife = { priority = Enum.AnimationPriority.Action2, fade = FADE.sprint },
	SprintUnarmed = { priority = Enum.AnimationPriority.Action2, fade = FADE.sprint },
	-- Nothing in hand (the lobby): the upper body over the Core idle and the legs.
	UnarmedIdle = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	UnarmedWalk = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	UnarmedRun = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	UnarmedCrouch = { priority = Enum.AnimationPriority.Action, fade = FADE.crouch },
	Crouch = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch },
	Slide = { priority = Enum.AnimationPriority.Action3, fade = FADE.slide },
	SlidePistol = { priority = Enum.AnimationPriority.Action3, fade = FADE.slide },
	SlideKnife = { priority = Enum.AnimationPriority.Action3, fade = FADE.slide },
	SlideUnarmed = { priority = Enum.AnimationPriority.Action3, fade = FADE.slide },
	ModHold = { priority = Enum.AnimationPriority.Action, fade = Animations.MOD_FADE },
	UpdraftSlam = { priority = Enum.AnimationPriority.Action4, fade = Animations.SLAM_FADE },
	SprintRun = { priority = Enum.AnimationPriority.Movement, fade = FADE.run },
	AdsUp = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	AdsLevel = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	AdsDown = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	PistolAimUp = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	PistolAimLevel = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	PistolAimDown = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	PistolAdsUp = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	PistolAdsLevel = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	PistolAdsDown = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	KnifeReady = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
}
-- The eight move directions every leg set has a clip for (tools/anim/tp_clips.py
-- dir_clips), clockwise from straight ahead, 45 degrees apart.
local DIR8 = { "F", "FR", "R", "BR", "B", "BL", "L", "FL" }
local function legSet(prefix: string, forward: string): { string }
	local out = {}
	for _, dir in DIR8 do
		table.insert(out, if dir == "F" then forward else prefix .. dir)
	end
	return out
end
local WALK_SET = legSet("Walk", "WalkF")
local RUN_SET = legSet("Run", "RunF")
local CROUCH_SET = legSet("CrouchWalk", "CrouchWalk")
-- Every standing leg cycle. They share one stride phase (the right foot lands
-- at phase 0 in each), so cross-fades keep the feet in step.
local GAIT_SET = table.clone(WALK_SET)
for _, name in RUN_SET do
	table.insert(GAIT_SET, name)
end
table.insert(GAIT_SET, "SprintRun")
table.insert(GAIT_SET, "SprintRunUnarmed") -- nothing in hand: its own easier stride
for _, name in GAIT_SET do
	SPECS[name] = { priority = Enum.AnimationPriority.Movement, fade = FADE.run }
end
for _, name in CROUCH_SET do
	SPECS[name] = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch }
end
-- The slide's weapon kinds: the rifle's (""), the sidearm's and knife's own
-- arms, and nothing in hand.
local SLIDE_KINDS = { "", "Pistol", "Knife", "Unarmed" }
-- The run's upper body, one per kind of weapon (long guns, sidearms, knife, none).
local SPRINT_SET = { "Sprint", "SprintPistol", "SprintKnife", "SprintUnarmed" }
-- The unarmed arm swings that follow the leg cycle's phase.
local UNARMED_SWING = { "UnarmedWalk", "UnarmedRun" }
-- The holds on the move (2026-11-28, tools/anim/tp_clips.py stride_hold): the
-- level hip hold of each weapon kind with the chest, gun and head swinging in
-- step with the legs. They take the level hold's share while you move, on
-- the legs' stride clock. "" until uploaded: then the still hold stays on.
local MOVE_OF: { [string]: string } = {
	AimLevel = "AimMove",
	PistolAimLevel = "PistolAimMove",
	KnifeReady = "KnifeMove",
}
local MOVE_SET: { string } = {}
for _, name in MOVE_OF do
	local animId = (Animations.POSES :: any)[name]
	if typeof(animId) == "string" and animId ~= "" then
		SPECS[name] = { priority = Enum.AnimationPriority.Action, fade = FADE.move }
		table.insert(MOVE_SET, name)
	end
end
local IDS: { [string]: string } = table.clone(Animations.POSES :: any)
for _, name in GAIT_SET do
	IDS[name] = (Animations.LOCOMOTION :: any)[name]
end
for _, name in { "AdsUp", "AdsLevel", "AdsDown", "KnifeReady" } do
	IDS[name] = (Animations.COMBAT :: any)[name]
end
IDS.ModHold = Animations.MODS.ModHold
-- The hold sets (tools/studio/MakeHoldAnimations): long guns, and sidearms'
-- own two-handed hold ("" until uploaded: then sidearms borrow the long set).
local PISTOL_SET = Animations.POSES.PistolAimLevel ~= ""
local HOLD_SETS: { [string]: { string } } = {
	long = { "AimUp", "AimLevel", "AimDown", "AdsUp", "AdsLevel", "AdsDown" },
	pistol = {
		"PistolAimUp",
		"PistolAimLevel",
		"PistolAimDown",
		"PistolAdsUp",
		"PistolAdsLevel",
		"PistolAdsDown",
	},
}
if not PISTOL_SET then
	for _, name in HOLD_SETS.pistol do
		IDS[name] = nil
	end
	HOLD_SETS.pistol = nil :: any
end
-- The Crash Down clips are "" until uploaded (the dive borrows Crouch).
local SLAM_POSE = Animations.MODS.UpdraftSlam ~= ""
if SLAM_POSE then
	IDS.UpdraftSlam = Animations.MODS.UpdraftSlam
end
-- One-shots on a use, by ModUseKind.
local USE_IDS: { [string]: string } = {
	Throw = Animations.MODS.Throw,
	Lob = Animations.MODS.Lob, -- a held throw's underhand (Molly RMB)
	Cast = Animations.MODS.Cast, -- HeldSteer: the free hand pushes out (Firewall)
	Place = Animations.MODS.Place,
	Heal = Animations.MODS.Heal,
	-- Dash leans (Mods/Dash), by direction relative to the body.
	DashForward = Animations.MODS.DashForward,
	DashBack = Animations.MODS.DashBack,
	DashLeft = Animations.MODS.DashLeft,
	DashRight = Animations.MODS.DashRight,
	Updraft = Animations.MODS.Updraft, -- knees tuck on the launch (Mods/Updraft)
	Land = Animations.LOCOMOTION.Land, -- a knee dip on touching down
	SlideIn = Animations.LOCOMOTION.SlideIn, -- the kick-out and drop into a slide
	SlideOut = Animations.LOCOMOTION.SlideOut, -- the push back up when a slide ends on your feet
	-- ...with a sidearm or the knife out (their own arms; the rifle's otherwise).
	SlideInPistol = Animations.LOCOMOTION.SlideInPistol,
	SlideOutPistol = Animations.LOCOMOTION.SlideOutPistol,
	SlideInKnife = Animations.LOCOMOTION.SlideInKnife,
	SlideOutKnife = Animations.LOCOMOTION.SlideOutKnife,
	SlideInUnarmed = Animations.LOCOMOTION.SlideInUnarmed,
	SlideOutUnarmed = Animations.LOCOMOTION.SlideOutUnarmed,
	Reload = Animations.COMBAT.Reload, -- at the gun's reload time (ReloadAt / ReloadFor)
	PistolReload = Animations.COMBAT.PistolReload, -- ...a sidearm's
	Flinch = Animations.COMBAT.Flinch, -- hit (HitAt), at FLINCH_WEIGHT
	Draw = Animations.COMBAT.Draw, -- a weapon swap (at the gun's equipTime)
	KnifeSlash = Animations.COMBAT.KnifeSlash, -- a knife swing (SwingAt): SwingStep 1, forehand
	KnifeSlash2 = Animations.COMBAT.KnifeSlash2, -- SwingStep 2: backhand
	KnifeSlash3 = Animations.COMBAT.KnifeSlash3, -- SwingStep 3: the overhead chop
	KnifeHeavy = Animations.COMBAT.KnifeHeavy, -- ...the heavy one (SwingHeavy)
}
if Animations.MODS.UpdraftSlamLand ~= "" then
	USE_IDS.UpdraftSlamLand = Animations.MODS.UpdraftSlamLand -- Crash Down's landing
end
-- A fading layer's floor (setWeight stops a layer once it's faded out).
local OFF = 0.001

local connection: RBXScriptConnection? = nil
local animations: { [string]: Animation } = {}
local retryDue: (id: string) -> boolean
local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local primed: { [Animator]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- The last Crash Down landing (UpdraftSlamAt) posed per character. Kept here,
-- not as an attribute (a character's attributes are nearly full: Mod System →
-- Character attribute budget); only a clearly later landing plays, so a
-- rollback that rewrites the same value can't replay it.
local slamSeen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Run only where this side simulates the character (the server for
-- everyone, a client for its own character), like Animate does.
local function isSimulated(instance: Instance): boolean
	-- Server Authority off (shared/Authority): nothing is predicted, so the
	-- Animator reports PredictionStatus.None and this used to skip every
	-- player's poses (2026-11-12: players stood in the idle with the gun
	-- hanging). `step` already picks who poses whom in that mode: a client
	-- its own character, the server its bots.
	if not Authority.server() then
		return true
	end
	local ok, status = pcall(RunService.GetPredictionStatus, RunService, instance)
	return not ok or status ~= Enum.PredictionStatus.None
end

local function animationFor(name: string): Animation
	local a = animations[name]
	if not a then
		a = Instance.new("Animation")
		a.Name = name
		a.AnimationId = IDS[name]
		animations[name] = a
	end
	return a
end

-- Failed animation downloads: when each animation id may be loaded again (shared by every rig, so a bad minute
-- costs one request per id per try, not one per rig per frame). Backs off 3, 6, 12 ... 60 s.
local retryAt: { [string]: number } = {}
local retryGap: { [string]: number } = {}
local FIRST_GRACE = 3 -- seconds a fresh track may take to load before it counts as failed
local firstSeen: { [string]: number } = {}

function retryDue(id: string): boolean
	local now = os.clock()
	local seen = firstSeen[id]
	if not seen then
		firstSeen[id] = now
		return false
	end
	if now - seen < FIRST_GRACE or now < (retryAt[id] or 0) then
		return false
	end
	local gap = math.min((retryGap[id] or 1.5) * 2, 60)
	retryGap[id] = gap
	retryAt[id] = now + gap
	return true
end

-- The playing track for pose `name`, loading and starting it if needed.
local function trackFor(animator: Animator, name: string): AnimationTrack
	local byName = cache[animator]
	if not byName then
		byName = {}
		cache[animator] = byName
	end
	local track = byName[name]
	if track then
		-- Loaded once per Animator and replayed, never loaded again (2026-11-23: a track that wasn't
		-- playing was re-loaded every step, so one failed download re-requested the asset every frame for
		-- every rig: a flood of "Animation failed to load" that also starved the server's DataStore reads).
		-- A load that failed (no length after a while) gets ONE fresh try per animation at a time, backing off
		-- (retryDue), so a server that couldn't fetch assets for a minute recovers instead of T-posing.
		if track.Length == 0 and retryDue(IDS[name]) then
			track:Stop(0)
			track:Destroy()
			byName[name] = nil
		else
			if not track.IsPlaying then
				track:Play(0, OFF, 1)
			end
			return track
		end
	end
	-- After a rollback the Animator may already hold a matching track.
	for _, t in animator:GetPlayingAnimationTracks() do
		if t.Animation and t.Animation.AnimationId == IDS[name] then
			track = t
			break
		end
	end
	local t = track or animator:LoadAnimation(animationFor(name))
	-- Set explicitly so both sides agree (Animate does the same).
	t.Priority = SPECS[name].priority
	t.Looped = true
	if not t.IsPlaying then
		t:Play(0, OFF, 1)
	end
	byName[name] = t
	return t
end

-- Plays a one-shot clip (Action4, over everything else), at `speed` and
-- `weight` (default 1).
-- The one-shot track for `kind` on this Animator: one per clip, loaded once
-- and replayed.
local function useTrack(animator: Animator, kind: string): AnimationTrack?
	local animId = USE_IDS[kind]
	if not animId then
		return nil
	end
	local key = "Use" .. kind
	local a = animations[key]
	if not a then
		a = Instance.new("Animation")
		a.Name = key
		a.AnimationId = animId
		animations[key] = a
	end
	local byName = cache[animator]
	if not byName then
		byName = {}
		cache[animator] = byName
	end
	local track = byName[key]
	if not track then
		track = animator:LoadAnimation(a :: Animation)
		byName[key] = track
	end
	return track
end

local function playOnce(
	animator: Animator,
	kind: string,
	speed: number?,
	weight: number?,
	start: number?
)
	local t = useTrack(animator, kind)
	if not t then
		return
	end
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = false
	t:Play(if start then Animations.MOD_USE_FADE else 0.05, weight or 1, speed or 1)
	if start then
		t.TimePosition = start
	end
end

-- The cached track for `name` if it's playing (nil when it's stopped).
local function playing(animator: Animator, name: string): AnimationTrack?
	local byName = cache[animator]
	local track = byName and byName[name]
	return if track and track.IsPlaying then track else nil
end

-- Fades a layer toward `weight`. A layer that's off fades out and then
-- stops: an Animator runs at most 16 tracks at once (measured 2026-11-04:
-- a 17th reports IsPlaying but never plays), so idle layers can't sit at a
-- tiny weight any more; one comes back (from 0, fading in) when it's needed.
local function setWeight(animator: Animator, name: string, weight: number)
	local step = Animations.WEIGHT_STEP
	local w = math.clamp(math.floor(weight / step + 0.5) * step, OFF, 1)
	if w <= OFF then
		local track = playing(animator, name)
		if track then
			if track.WeightCurrent <= 0.01 then
				track:Stop(0)
				local byName = cache[animator]
				if byName then
					byName[name] = nil
				end
			elseif math.abs(track.WeightTarget - OFF) > 1e-3 then
				track:AdjustWeight(OFF, SPECS[name].fade)
			end
		end
		return
	end
	local track = trackFor(animator, name)
	if math.abs(track.WeightTarget - w) > 1e-3 then
		track:AdjustWeight(w, SPECS[name].fade)
	end
end

-- Pose tracks the cache no longer drives (2026-11-13, measured: a track
-- stopped and re-adopted in the same step, or one started past the Animator's
-- 16-track limit, kept playing at 0.001, or stuck at full weight, for good).
-- They hold the Animator's track slots and, at weight, pose the body. Fade
-- each out and stop it.
local function sweep(animator: Animator)
	local byName = cache[animator]
	for _, t in animator:GetPlayingAnimationTracks() do
		local a = t.Animation
		local name = a and a.Name
		if name and IDS[name] and (not byName or byName[name] ~= t) then
			if t.WeightCurrent <= 0.02 then
				t:Stop(0)
			elseif t.WeightTarget > OFF then
				t:AdjustWeight(OFF, FADE.run)
			end
		end
	end
end

-- Config/TpIk's switch (Studio: the Workspace attribute wins). Mirrors
-- Controllers/TpIkController. Read here, outside the simulation callback:
-- GetService is not allowed inside one (2026-11-20: calling it there threw
-- every step and the client stopped posing its own character).
local tpIkDev: boolean? = nil
if RunService:IsStudio() then
	local Workspace = game:GetService("Workspace")
	local function readDev()
		local dev = Workspace:GetAttribute(TpIk.DEV_ATTRIBUTE)
		tpIkDev = if typeof(dev) == "boolean" then dev else nil
	end
	readDev()
	Workspace:GetAttributeChangedSignal(TpIk.DEV_ATTRIBUTE):Connect(readDev)
end
local function tpIkOn(): boolean
	if tpIkDev ~= nil then
		return tpIkDev
	end
	return TpIk.ENABLED
end

local function aimPitch(player: Player): number
	local context = player:FindFirstChild("PlayContext")
	local action = context and context:FindFirstChild("AimPitch")
	if action and action:IsA("InputAction") then
		local v = action:GetState()
		if typeof(v) == "number" and v == v then
			-- Up and down poses are baked at different angles (Config/Animations
			-- AIM_PITCH_UP / AIM_PITCH_DOWN); the pose holds past them.
			local deg = v * 90
			local range = if deg >= 0 then Animations.AIM_PITCH_UP else Animations.AIM_PITCH_DOWN
			return math.clamp(deg / range, -1, 1)
		end
	end
	return 0
end

-- The pitch each character is posed with, eased toward its AimPitch input.
local posedPitch: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- How far each character is between the hip hold (0) and the sights (1).
local posedAds: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- The last reload (ReloadAt) and hit (HitAt) posed per character.
local reloadSeen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local hitSeen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local swingSeen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- The weapon each character was last posed with (for the draw on a swap).
local weaponSeen: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any

local function aiming(player: Player): boolean
	local context = player:FindFirstChild("PlayContext")
	local action = context and context:FindFirstChild("Aim")
	return action ~= nil and action:IsA("InputAction") and action:GetState() == true
end

-- A server time stamp (player attribute) newer than the last one posed. The
-- first look at a character only sets the mark (to the stamp, or -1 when it
-- has none yet), so an old one doesn't replay on join but the first real
-- one after that plays.
local function newMark(seen: { [Model]: number }, character: Model, value: unknown): boolean
	local stamp = if typeof(value) == "number" then value else -1
	local last = seen[character]
	seen[character] = stamp
	return last ~= nil and stamp > last
end

-- Whether each character was in the air last step, and since when
-- (os.clock), for the landing clip.
local wasAir: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local airSince: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- Whether each character was sliding last step (the slide's way in and out).
local wasSlide: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Whether each character was crouched last step (the stride clocks' hand-over).
local wasCrouched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Which way the body moves relative to where it faces, as the shares of the
-- two DIR8 clips either side of it (`index` 1..8 into DIR8, weight of the
-- next one clockwise). Standing still counts as forward.
local function direction8(root: BasePart): (number, number)
	local flat = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity * Vector3.new(1, 0, 1))
	if flat.Magnitude < 1e-3 then
		return 1, 0
	end
	local steps = (math.deg(math.atan2(flat.X, -flat.Z)) % 360) / 45
	local i = math.floor(steps)
	-- Near one clip's direction, that clip alone: an Animator plays at most
	-- 16 tracks (a 17th never plays, never fades and never stops), and a
	-- second leg clip at a sliver of weight for every small drift pushed the
	-- body past that (measured 18 in a strafing test, 2026-11-13).
	local next = steps - i
	local snap = Animations.DIRECTION_SNAP
	if next < snap then
		next = 0
	elseif next > 1 - snap then
		next = 1
	end
	return i % 8 + 1, next
end

-- Weights a leg set's eight clips toward `total`, split between the two
-- either side of the move direction.
local function setDirections(
	animator: Animator,
	set: { string },
	total: number,
	index: number,
	next: number,
	skip: string?
)
	for i, name in set do
		local w = if i == index then 1 - next elseif i == index % 8 + 1 then next else 0
		setWeight(animator, name, if name == skip then 0 else total * w)
	end
end

-- One stride clock per Animator and leg set (the standing gaits, the crouch
-- walk): its phase (0..1, the right foot lands at 0) and cycles a second. Every
-- clip of the set, and the arms that swing with it, is driven to this clock.
-- (2026-11-28, the "upper body restarts" bug: the clips used to follow the
-- heaviest playing clip's phase, and a clip that had just started (at time 0)
-- often became the heaviest one, so every other leg clip and the run's
-- gun-holding upper body snapped back to the start of the cycle mid-stride,
-- measured up to 0.6 of a cycle on the server and on every watcher.)
type Clock = { phase: number, cycles: number, at: number }
local clocks: { [Animator]: { [string]: Clock } } = setmetatable({}, { __mode = "k" }) :: any

-- The clips a fresh clock may take its phase from: the set's legs and every
-- swing that follows them (2026-11-28: a clock seeded from the legs alone
-- started at 0 when no leg clip was playing yet, and the arms snapped to it).
local SEED: { [string]: { string } } =
	{ gait = table.clone(GAIT_SET), crouch = table.clone(CROUCH_SET) }
for _, list in { SPRINT_SET, MOVE_SET, UNARMED_SWING } do
	for _, name in list do
		table.insert(SEED.gait, name)
	end
end
for _, name in MOVE_SET do
	table.insert(SEED.crouch, name)
end

local function clockFor(animator: Animator, key: string): Clock
	local seedFrom = SEED[key]
	local byKey = clocks[animator]
	if not byKey then
		byKey = {}
		clocks[animator] = byKey
	end
	local clock = byKey[key]
	if not clock then
		-- A fresh clock takes the phase of a clip already playing (after a
		-- respawn of this module's state), so nothing jumps.
		local phase, heaviest = 0, 0
		for _, name in seedFrom do
			local t = playing(animator, name)
			if t and t.Length > 0 and t.WeightCurrent > heaviest then
				phase, heaviest = t.TimePosition / t.Length, t.WeightCurrent
			end
		end
		clock = { phase = phase, cycles = 0, at = os.clock() }
		byKey[key] = clock
	end
	return clock
end

-- Moves a clock on at `cycles` a second (time since it last moved, capped, so
-- a set that was off resumes where it stopped).
local function advance(clock: Clock, cycles: number)
	local now = os.clock()
	local dt = math.clamp(now - clock.at, 0, Animations.STRIDE_CLOCK.maxStep)
	clock.at = now
	clock.cycles = cycles
	clock.phase = (clock.phase + cycles * dt) % 1
end

-- Drives each playing clip of `names` to the clock: a clip still fading in
-- (too light to see) is set straight onto the phase; one at weight is pulled
-- in by running it a little faster or slower, so it never pops. Only a big
-- drift at weight is snapped. `rate` clamps the base speed (the leg clips).
local function lockTo(
	animator: Animator,
	names: { string },
	clock: Clock,
	rate: { min: number, max: number }?
)
	local tuning = Animations.STRIDE_CLOCK
	for _, name in names do
		local t = playing(animator, name)
		if t and t.Length > 0 then
			local base = clock.cycles * t.Length
			if rate then
				base = math.clamp(base, rate.min, rate.max)
			end
			local drift = (t.TimePosition / t.Length - clock.phase + 0.5) % 1 - 0.5 -- -0.5..0.5 cycles
			if
				(t.WeightCurrent < tuning.setBelowWeight and math.abs(drift) > 0.01)
				or math.abs(drift) > tuning.snap
			then
				t.TimePosition = clock.phase * t.Length
				drift = 0
			end
			local want = base * (1 - math.clamp(drift * tuning.pull, -0.5, 0.5))
			if math.abs(t.Speed - want) > 0.01 then
				t:AdjustSpeed(want)
			end
		end
	end
end

-- Keeps a set of looping leg clips on one cycle: the set's clock runs at
-- `cycles` a second and every clip follows it.
local function inStep(animator: Animator, key: string, set: { string }, cycles: number): Clock
	local clock = clockFor(animator, key)
	advance(clock, cycles)
	lockTo(animator, set, clock, Animations.RUN_RATE)
	return clock
end

-- Studs one cycle of each leg clip covers (its made-for speed x its length),
-- so a blend of gaits plays at one shared cycle rate.
local function strideOf(name: string, length: number): number
	if string.sub(name, 1, 4) == "Walk" then
		return Animations.WALK_CLIP_SPEED * length
	elseif name == "SprintRun" or name == "SprintRunUnarmed" then
		return Animations.SPRINT_RUN_SPEED * length
	end
	return Animations.RUN_SPEED * length
end

-- The legs: a walk set (slow, aimed movement) and a run set, each blended by
-- where the body moves relative to where it faces (forward / back / left /
-- right), cross-faded by ground speed (Animations.WALK_RUN); the sprint
-- stride when sprinting forward. All off while crouched, sliding or in the
-- air. Every leg clip plays at one cycle rate (ground speed over the blended
-- stride) and on one phase (the heaviest clip leads, the rest follow it), so
-- the planted feet stay locked to the ground through any blend
-- (LihFolk "Locomotion Systems": gaits that cannot slide, phase-preserving
-- gait swaps).
local function stepLegs(
	animator: Animator,
	root: BasePart,
	state: unknown,
	speed: number,
	alive: boolean,
	airborne: boolean,
	unarmed: boolean
)
	-- (Off the floor the run stops whatever the move state says: holding
	-- forward through a jump stays "Sprint", and the legs used to keep
	-- running in mid-air over the jump and fall poses.)
	local onFeet = alive
		and not airborne
		and (state == "Walk" or state == "Sprint" or state == "Idle" or state == nil)
	local legs = if onFeet
		then math.clamp(
			(speed - Animations.RUN_FROM) / (Animations.RUN_FULL - Animations.RUN_FROM),
			0,
			1
		)
		else 0
	local index, next = direction8(root)
	local band = Animations.WALK_RUN
	local runShare = math.clamp((speed - band.from) / (band.to - band.from), 0, 1)
	local sprint = if state == "Sprint" then 1 else 0
	local forward = if index == 1 then 1 - next elseif index == 8 then next else 0
	setDirections(animator, WALK_SET, legs * (1 - runShare), index, next, nil)
	-- Sprinting, the forward share runs the sprint stride instead.
	setDirections(
		animator,
		RUN_SET,
		legs * runShare,
		index,
		next,
		if sprint > 0 then "RunF" else nil
	)
	local sprintLegs = legs * runShare * forward * sprint
	setWeight(animator, "SprintRun", if unarmed then 0 else sprintLegs)
	setWeight(animator, "SprintRunUnarmed", if unarmed then sprintLegs else 0)
	if legs <= 0 then
		return
	end
	-- One cycle rate for all of them: ground speed over the blended stride.
	local stride, total = 0, 0
	for _, name in GAIT_SET do
		local t = playing(animator, name)
		if t and t.Length > 0 then
			local w = t.WeightTarget
			stride += strideOf(name, t.Length) * w
			total += w
		end
	end
	if total > 0 and stride > 0 then
		local clock = inStep(animator, "gait", GAIT_SET, speed / (stride / total))
		-- The run's upper body swings with the stride, on the same clock (its
		-- right-foot beat is phase 0 like the legs').
		lockTo(animator, SPRINT_SET, clock, nil)
	end
end

-- Keeps arm swings on the legs' stride clock (the right foot lands at phase 0
-- in every one).
local function followStride(animator: Animator, names: { string })
	local byKey = clocks[animator]
	local clock = byKey and byKey.gait
	if clock and clock.cycles > 0 then
		lockTo(animator, names, clock, nil)
	end
end

-- Sets the stride clock so the right footfall (phase 0) comes `inSeconds`
-- from now (SlideOut ends in that footfall), and every leg clip onto it.
local function footfallIn(animator: Animator, inSeconds: number)
	local clock = clockFor(animator, "gait")
	if clock.cycles <= 0 then
		return -- (no stride yet: nothing to line up, and phase 0 would snap the arms)
	end
	clock.phase = (-inSeconds * clock.cycles) % 1
	clock.at = os.clock()
	for _, name in GAIT_SET do
		local t = playing(animator, name)
		if t and t.Length > 0 then
			t.TimePosition = clock.phase * t.Length
		end
	end
end

local function stepCharacter(player: Player, character: Model, dt: number)
	if not Fields.ready(character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not root or not root:IsA("BasePart") or not animator then
		return
	end
	if not isSimulated(root) or not isSimulated(animator) then
		return
	end
	-- Load every one-shot on a new Animator (loaded, not playing: no track
	-- slot used), so its first use doesn't find it still loading (length 0)
	-- and skip. ContentProvider's preload only helps on clients.
	if not primed[animator] then
		primed[animator] = true
		for kind in USE_IDS do
			useTrack(animator, kind)
		end
	end
	sweep(animator)

	local alive = Health.isAlive(humanoid)
	local state = if alive then StateValues.get(character, "MoveState") else nil
	local weaponId = StateValues.get(player, "WeaponId")
	local config = if typeof(weaponId) == "string" then Weapons.get(weaponId) else nil
	-- The knife has no two-handed hold; it keeps the default arm swing.
	local held = StateValues.get(player, "ModHeld")
	local holding = alive and typeof(held) == "number" and held ~= 0
	local armed = if alive and config and config.fireMode ~= "Melee" and not holding then 1 else 0
	local target = aimPitch(player)
	local previous = posedPitch[character] or target
	local pitch = previous + (target - previous) * (1 - math.exp(-Animations.AIM_SMOOTHING * dt))
	posedPitch[character] = pitch
	-- Third-person IK mode (Config/TpIk, a prototype, off by default): the
	-- watchers' TpIkController pitches the waist and neck and places the gun
	-- from the aim, so the holds stay level here.
	local holdPitch = if tpIkOn() then 0 else pitch
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	-- Crouch blends into crouch-walk over a small speed range instead of a
	-- hard switch at MOVING_SPEED.
	local moving =
		math.clamp((speed - Animations.MOVING_SPEED * 0.5) / Animations.MOVING_SPEED, 0, 1)
	-- Crash Down's dive (simulation-written UpdraftSlam).
	local diving = alive and StateValues.get(character, "UpdraftSlam") == "Down"
	local crouch = if state == "Crouch" or (diving and not SLAM_POSE) then 1 else 0
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	-- The holds on the move take over from the still level hold by speed, on
	-- your feet (walking, running or crouch-walking; not in the air or a slide).
	local onFoot = alive
		and not airborne
		and (
			state == "Walk"
			or state == "Sprint"
			or state == "Idle"
			or state == "Crouch"
			or state == nil
		)
	local strideShare = if onFoot then moving else 0

	-- Aim: a blend space of three held poses (Action priority).
	-- Hip hold and sights blend by the Aim input (smoothed like the pitch).
	local adsTarget = if armed > 0 and aiming(player) and state ~= "Sprint" then 1 else 0
	local adsWas = posedAds[character] or adsTarget
	local ads = adsWas + (adsTarget - adsWas) * (1 - math.exp(-Animations.ADS_SMOOTHING * dt))
	posedAds[character] = ads
	local hip = armed * (1 - ads)
	local sights = armed * ads
	-- Sidearms, and Akimbo (a gun in each hand): the two-handed set, whose
	-- hands sit side by side and face forward, so both guns point ahead.
	local pistol = PISTOL_SET
		and config ~= nil
		and (config.class == "Sidearm" or (config.models ~= nil and config.models.left ~= nil))
	local knife = alive and config ~= nil and config.fireMode == "Melee" and not holding
	-- Nothing in hand (the lobby, no gun drawn): relaxed arms, an arm swing.
	local unarmed = alive and config == nil and not holding
	-- The slide's arms follow the weapon kind ("" = the rifle's).
	local slideKind = if knife
		then "Knife"
		elseif pistol then "Pistol"
		elseif unarmed then "Unarmed"
		else ""
	for setName, names in HOLD_SETS do
		local on = if (setName == "pistol") == pistol then 1 else 0
		setWeight(animator, names[1], on * hip * math.max(holdPitch, 0))
		local level = on * hip * (1 - math.abs(holdPitch))
		local move = MOVE_OF[names[2]]
		if move and SPECS[move] then
			setWeight(animator, names[2], level * (1 - strideShare))
			setWeight(animator, move, level * strideShare)
		else
			setWeight(animator, names[2], level)
		end
		setWeight(animator, names[3], on * hip * math.max(-holdPitch, 0))
		setWeight(animator, names[4], on * sights * math.max(holdPitch, 0))
		setWeight(animator, names[5], on * sights * (1 - math.abs(holdPitch)))
		setWeight(animator, names[6], on * sights * math.max(-holdPitch, 0))
	end
	-- A reload (timed to the gun) and a flinch when hit, from the server.
	if
		newMark(reloadSeen, character, StateValues.get(player, "ReloadAt"))
		and alive
		and armed > 0
	then
		local duration = StateValues.get(player, "ReloadFor")
		if typeof(duration) == "number" and duration > 0.1 then
			playOnce(
				animator,
				if pistol then "PistolReload" else "Reload",
				Animations.RELOAD_LENGTH / duration
			)
		end
	end
	if newMark(hitSeen, character, StateValues.get(player, "HitAt")) and alive then
		-- A stream of hits (an SMG, a burn) doesn't restart the flinch from its
		-- start every hit (2026-11-28: measured restarting every 0.25 s at 0.8
		-- weight, a stutter of the whole upper body); it plays on and only a hit
		-- after FLINCH_RETRIGGER of the clip starts it again.
		local byName = cache[animator]
		local flinch = byName and byName.UseFlinch
		local busy = flinch ~= nil
			and flinch.IsPlaying
			and flinch.Length > 0
			and flinch.TimePosition < flinch.Length * Animations.FLINCH_RETRIGGER
		if not busy then
			playOnce(animator, "Flinch", 1, Animations.FLINCH_WEIGHT)
		end
	end
	-- A weapon swap: the new gun comes up (not on the first look).
	if typeof(weaponId) == "string" then
		local was = weaponSeen[character]
		weaponSeen[character] = weaponId
		if was ~= nil and was ~= weaponId and armed > 0 and config then
			playOnce(animator, "Draw", Animations.DRAW_LENGTH / math.max(config.equipTime, 0.1))
		end
	end
	-- The knife: its ready hold while it's out, and each swing (also a quick
	-- melee with a gun out).
	local knifeOn = if knife then 1 else 0
	if SPECS.KnifeMove then
		setWeight(animator, "KnifeReady", knifeOn * (1 - strideShare))
		setWeight(animator, "KnifeMove", knifeOn * strideShare)
	else
		setWeight(animator, "KnifeReady", knifeOn)
	end
	if newMark(swingSeen, character, StateValues.get(player, "SwingAt")) and alive then
		local step = StateValues.get(player, "SwingStep")
		playOnce(
			animator,
			if StateValues.get(player, "SwingHeavy") == true
				then "KnifeHeavy"
				elseif step == 2 then "KnifeSlash2"
				elseif step == 3 then "KnifeSlash3"
				else "KnifeSlash"
		)
	end
	-- Movement (Action2 / Action3) layers over the aim and the walk cycle.
	local sprintPose = if knife
		then "SprintKnife"
		elseif pistol then "SprintPistol"
		elseif unarmed then "SprintUnarmed"
		else "Sprint"
	-- Unarmed: idle, walk and run arms by speed (the sprint and slide have
	-- their own above), the crouch's own arms.
	local u = if unarmed and state ~= "Slide" then 1 else 0
	local band = Animations.WALK_RUN
	local runShare = math.clamp((speed - band.from) / (band.to - band.from), 0, 1)
	setWeight(animator, "UnarmedIdle", u * (1 - crouch) * (1 - moving))
	setWeight(animator, "UnarmedWalk", u * (1 - crouch) * moving * (1 - runShare))
	setWeight(animator, "UnarmedRun", u * (1 - crouch) * moving * runShare)
	setWeight(animator, "UnarmedCrouch", u * crouch)
	for _, name in SPRINT_SET do
		setWeight(animator, name, if state == "Sprint" and name == sprintPose then 1 else 0)
	end
	setWeight(animator, "Crouch", crouch * (1 - moving))
	-- Crouch-walking blends its eight directions like the run.
	local index, next = direction8(root)
	setDirections(animator, CROUCH_SET, crouch * moving, index, next, nil)
	for _, kind in SLIDE_KINDS do
		setWeight(
			animator,
			"Slide" .. kind,
			if state == "Slide" and kind == slideKind then 1 else 0
		)
	end
	setWeight(animator, "ModHold", if holding then 1 else 0)
	if SLAM_POSE then
		setWeight(animator, "UpdraftSlam", if diving then 1 else 0)
	end
	if diving then
		-- The launch tuck gives way to the dive.
		local byName = cache[animator]
		local tuck = byName and byName.UseUpdraft
		if tuck and tuck.IsPlaying then
			tuck:Stop(Animations.SLAM_FADE)
		end
	end

	-- A dash (simulation-written DashStart): lean into it. A new character
	-- starts its mark at 0, so its first dash plays.
	local dashStart = StateValues.get(character, "DashStart")
	local dashMark = if typeof(dashStart) == "number" then dashStart else 0
	local dashSeen = StateValues.get(character, "PoseDashSeen")
	if dashSeen ~= dashMark then
		StateValues.set(character, "PoseDashSeen", dashMark)
		local velocity = StateValues.get(character, "DashVelocity")
		if typeof(dashSeen) == "number" and alive and typeof(velocity) == "Vector3" then
			local rel = root.CFrame:VectorToObjectSpace(velocity)
			playOnce(
				animator,
				if math.abs(rel.X) > math.abs(rel.Z)
					then (if rel.X > 0 then "DashRight" else "DashLeft")
					else (if rel.Z < 0 then "DashForward" else "DashBack")
			)
		end
	end

	-- An Updraft (simulation-written UpdraftAt): the tuck, the same way.
	local updraftAt = StateValues.get(character, "UpdraftAt")
	local updraftMark = if typeof(updraftAt) == "number" then updraftAt else 0
	local updraftSeen = StateValues.get(character, "PoseUpdraftSeen")
	if updraftSeen ~= updraftMark then
		StateValues.set(character, "PoseUpdraftSeen", updraftMark)
		if typeof(updraftSeen) == "number" and alive then
			playOnce(animator, "Updraft")
		end
	end

	-- A Crash Down landing: the slam clip once (the first value seen only
	-- sets the mark).
	local slamAt = StateValues.get(character, "UpdraftSlamAt")
	if typeof(slamAt) == "number" then
		-- (A re-simulated landing a few ms off isn't a new one.)
		local last = slamSeen[character]
		if last == nil or slamAt > last + 0.05 then
			slamSeen[character] = slamAt
			if last ~= nil and alive then
				playOnce(animator, "UpdraftSlamLand")
			end
		end
	end

	-- A Mod use: its clip once. The first value seen (a new character) only
	-- sets the mark, so an old use isn't replayed.
	local useAt = StateValues.get(player, "ModUseAt")
	if typeof(useAt) == "number" then
		local seenAt = StateValues.get(character, "PoseUseSeen")
		if seenAt ~= useAt then
			StateValues.set(character, "PoseUseSeen", useAt)
			local kind = StateValues.get(player, "ModUseKind")
			if typeof(seenAt) == "number" and alive and typeof(kind) == "string" then
				-- (A throw joins its clip mid-coil: ModUseAt is the release.)
				playOnce(animator, kind, nil, nil, Animations.MOD_USE_START[kind])
			end
		end
	end

	stepLegs(animator, root, state, speed, alive, airborne, unarmed)
	if unarmed then
		followStride(animator, UNARMED_SWING)
	end
	-- Touching down: a squash over whatever the legs are doing, full when you
	-- land slow and none at a run (the run's own bounce carries it, and frozen
	-- legs would skate), and only after a real jump or fall (a step off a
	-- ledge or a bump in the floor is airborne for a moment too).
	local inAir = airborne or state == "Air"
	local now = os.clock()
	if inAir and not wasAir[character] then
		airSince[character] = now
	end
	if wasAir[character] and not inAir and alive then
		local land = Animations.LAND
		local weight = 1
			- math.clamp((speed - land.fullBelow) / (land.noneAbove - land.fullBelow), 0, 1)
		if now - (airSince[character] or now) >= land.minAir and weight > 0.05 then
			playOnce(animator, "Land", 1, weight)
		end
	end
	wasAir[character] = inAir
	-- The slide: dropping into it, and getting up out of it when it ends on
	-- your feet (a slide-jump has the jump; into a crouch, the crouch fades in).
	-- The first look at a character only sets the mark.
	local sliding = state == "Slide"
	local slidWas = wasSlide[character]
	if sliding and slidWas == false and alive then
		playOnce(animator, "SlideIn" .. slideKind)
	elseif
		slidWas
		and not sliding
		and alive
		and (state == "Walk" or state == "Sprint" or state == "Idle")
	then
		for _, kind in SLIDE_KINDS do
			local into = playing(animator, "UseSlideIn" .. kind)
			if into then
				into:Stop(0.05) -- a very short slide
			end
		end
		playOnce(animator, "SlideOut" .. slideKind)
		-- It ends in the run's right footfall: the run lands there too.
		footfallIn(animator, Animations.SLIDE_OUT_LENGTH)
	end
	wasSlide[character] = sliding
	-- The hold's scrape chatter calms as the slide slows.
	local hold = playing(animator, "Slide" .. slideKind)
	local chatter =
		math.clamp(speed / Animations.SLIDE_CHATTER_SPEED, Animations.SLIDE_CHATTER_MIN, 1)
	if hold and math.abs(hold.Speed - chatter) > 0.05 then
		hold:AdjustSpeed(chatter)
	end

	-- Crouch-walk stride speed follows the ground speed, all eight in step
	-- (one length, so one cycle rate).
	local crouchLength = Animations.CROUCH_WALK_LENGTH
	-- Crouching or standing up hands the stride's phase to the other set's clock,
	-- so the holds on the move (which follow whichever legs walk) never jump.
	local crouched = crouch > 0
	local crouchedWas = wasCrouched[character]
	if crouchedWas ~= nil and crouchedWas ~= crouched then
		local from = if crouched then clockFor(animator, "gait") else clockFor(animator, "crouch")
		local to = if crouched then clockFor(animator, "crouch") else clockFor(animator, "gait")
		to.phase = from.phase
		to.at = os.clock()
	end
	wasCrouched[character] = crouched
	local crouchClock = inStep(
		animator,
		"crouch",
		CROUCH_SET,
		speed / (Animations.CROUCH_WALK_SPEED * crouchLength)
	)
	-- The holds on the move swing on the stride of whichever legs are walking.
	if crouch > 0 then
		if crouchClock.cycles > 0 then
			lockTo(animator, MOVE_SET, crouchClock, nil)
		end
	else
		followStride(animator, MOVE_SET)
	end
end

local function step(dt: number)
	if RunService:IsServer() then
		-- Real players only under Server Authority (shared/Authority). Without
		-- it each client poses its own character, and the tracks a client
		-- plays on its own Animator replicate to everyone, as in any classic
		-- Roblox game; the server posing them too (from inputs it can't see)
		-- would play a second, standing-still set over them.
		if Authority.server() then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character then
					stepCharacter(player, character, dt)
				end
			end
		end
		-- AI bots (Simulation/Pawns): posed from their owner's attributes.
		for _, pawn in Pawns.list() do
			stepCharacter(pawn.owner :: any, pawn.character, dt)
		end
	else
		local player = Players.LocalPlayer
		local character = player and player.Character
		if character then
			stepCharacter(player, character, dt)
		end
	end
end

-- The same legs for a character no player drives (a bot): call
-- it from its own loop on the server; it moves on foot whenever it has speed.
function PoseSim.legs(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not root or not root:IsA("BasePart") or not animator then
		return
	end
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	stepLegs(
		animator,
		root,
		"Walk",
		speed,
		Health.isAlive(humanoid),
		humanoid.FloorMaterial == Enum.Material.Air
	)
end

-- Call once on the server and once on each client.
function PoseSim.initialize()
	if connection and connection.Connected then
		return
	end
	-- Classic client ownership runs pose work in PreAnimation. Restricted
	-- simulation callbacks reject animation initialization writes in this mode.
	connection = if Authority.server()
		then RunService:BindToSimulation(step, Enum.StepFrequency.Hz60, 4000)
		else RunService.PreAnimation:Connect(step)
	-- Visible locomotion warms naturally as its Animator starts the tracks.
	-- Prime only the first local one-shots before the player needs them.
	task.spawn(function()
		local list: { Instance } = {}
		for _, kind in
			{
				"Land",
				"SlideInUnarmed",
				"SlideOutUnarmed",
				"SlideIn",
				"SlideOut",
				"DashForward",
				"Updraft",
			}
		do
			local id = USE_IDS[kind]
			if id then
				local a = Instance.new("Animation")
				a.AnimationId = id
				table.insert(list, a)
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, animation in list do
			animation:Destroy()
		end
	end)
end

return PoseSim
