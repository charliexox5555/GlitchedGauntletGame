--!strict
-- Third-person pose tracks (Config/Animations): holding the gun (a blend of
-- three pitch poses), the sprint carry, crouch / crouch-walk and slide, and
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

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Health = require(script.Parent.Parent.Health)
local Pawns = require(script.Parent.Pawns)
local Animations = require(script.Parent.Parent.Config.Animations)
local Weapons = require(script.Parent.Parent.Config.Weapons)

local PoseSim = {}

type Spec = { priority: Enum.AnimationPriority, fade: number }

local FADE = Animations.FADE
local SPECS: { [string]: Spec } = {
	AimUp = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	AimLevel = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	AimDown = { priority = Enum.AnimationPriority.Action, fade = FADE.aim },
	Sprint = { priority = Enum.AnimationPriority.Action2, fade = FADE.sprint },
	Crouch = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch },
	CrouchWalk = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch },
	CrouchWalkB = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch },
	CrouchWalkL = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch },
	CrouchWalkR = { priority = Enum.AnimationPriority.Action2, fade = FADE.crouch },
	Slide = { priority = Enum.AnimationPriority.Action3, fade = FADE.slide },
	ModHold = { priority = Enum.AnimationPriority.Action, fade = Animations.MOD_FADE },
	UpdraftSlam = { priority = Enum.AnimationPriority.Action4, fade = Animations.SLAM_FADE },
	RunF = { priority = Enum.AnimationPriority.Movement, fade = FADE.run },
	RunB = { priority = Enum.AnimationPriority.Movement, fade = FADE.run },
	RunL = { priority = Enum.AnimationPriority.Movement, fade = FADE.run },
	RunR = { priority = Enum.AnimationPriority.Movement, fade = FADE.run },
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
local RUN_SET = { "RunF", "RunB", "RunL", "RunR" }
local CROUCH_SET = { "CrouchWalk", "CrouchWalkB", "CrouchWalkL", "CrouchWalkR" }
local IDS: { [string]: string } = table.clone(Animations.POSES :: any)
for _, name in { "RunF", "RunB", "RunL", "RunR", "SprintRun" } do
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
	Reload = Animations.COMBAT.Reload, -- at the gun's reload time (ReloadAt / ReloadFor)
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

-- The playing track for pose `name`, loading and starting it if needed.
local function trackFor(animator: Animator, name: string): AnimationTrack
	local byName = cache[animator]
	if not byName then
		byName = {}
		cache[animator] = byName
	end
	local track = byName[name]
	if track and track.IsPlaying then
		return track
	end
	-- After a rollback the Animator may already hold a matching track.
	track = nil
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

local function playOnce(animator: Animator, kind: string, speed: number?, weight: number?)
	local t = useTrack(animator, kind)
	if not t then
		return
	end
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = false
	t:Play(0.05, weight or 1, speed or 1)
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

-- Whether each character was in the air last step (for the landing clip).
local wasAir: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Whether each character was sliding last step (the slide's way in and out).
local wasSlide: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- How much the body moves forward / back / left / right relative to where
-- it faces (shares summing to 1; standing still counts as forward).
local function directions(root: BasePart): (number, number, number, number)
	local flat = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity * Vector3.new(1, 0, 1))
	local f, b = math.max(-flat.Z, 0), math.max(flat.Z, 0)
	local r, l = math.max(flat.X, 0), math.max(-flat.X, 0)
	local sum = f + b + r + l
	if sum > 1e-3 then
		return f / sum, b / sum, l / sum, r / sum
	end
	return 1, 0, 0, 0
end

-- The legs: the run set blended by where the body moves relative to where it
-- faces (forward / back / left / right), the sprint stride when sprinting
-- forward, all off while crouched, sliding or in the air. The clips share
-- one length so blended feet stay in step; their rate follows ground speed.
local function stepLegs(
	animator: Animator,
	root: BasePart,
	state: unknown,
	speed: number,
	alive: boolean
)
	local onFeet = alive
		and (state == "Walk" or state == "Sprint" or state == "Idle" or state == nil)
	local run = if onFeet
		then math.clamp(
			(speed - Animations.RUN_FROM) / (Animations.RUN_FULL - Animations.RUN_FROM),
			0,
			1
		)
		else 0
	local f, b, l, r = directions(root)
	local sprint = if state == "Sprint" then 1 else 0
	setWeight(animator, "RunF", run * f * (1 - sprint))
	setWeight(animator, "SprintRun", run * f * sprint)
	setWeight(animator, "RunB", run * b)
	setWeight(animator, "RunL", run * l)
	setWeight(animator, "RunR", run * r)
	if run > 0 then
		local rate = Animations.RUN_RATE
		local runRate = math.clamp(speed / Animations.RUN_SPEED, rate.min, rate.max)
		for _, name in RUN_SET do
			local t = playing(animator, name)
			if t and math.abs(t.Speed - runRate) > 0.05 then
				t:AdjustSpeed(runRate)
			end
		end
		local sprintTrack = playing(animator, "SprintRun")
		local sprintRate = math.clamp(speed / Animations.SPRINT_RUN_SPEED, rate.min, rate.max)
		if sprintTrack and math.abs(sprintTrack.Speed - sprintRate) > 0.05 then
			sprintTrack:AdjustSpeed(sprintRate)
		end
	end
end

local function stepCharacter(player: Player, character: Model, dt: number)
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

	local alive = Health.isAlive(humanoid)
	local state = if alive then character:GetAttribute("MoveState") else nil
	local weaponId = player:GetAttribute("WeaponId")
	local config = if typeof(weaponId) == "string" then Weapons.get(weaponId) else nil
	-- The knife has no two-handed hold; it keeps the default arm swing.
	local held = player:GetAttribute("ModHeld")
	local holding = alive and typeof(held) == "number" and held ~= 0
	local armed = if alive and config and config.fireMode ~= "Melee" and not holding then 1 else 0
	local target = aimPitch(player)
	local previous = posedPitch[character] or target
	local pitch = previous + (target - previous) * (1 - math.exp(-Animations.AIM_SMOOTHING * dt))
	posedPitch[character] = pitch
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	-- Crouch blends into crouch-walk over a small speed range instead of a
	-- hard switch at MOVING_SPEED.
	local moving =
		math.clamp((speed - Animations.MOVING_SPEED * 0.5) / Animations.MOVING_SPEED, 0, 1)
	-- Crash Down's dive (simulation-written UpdraftSlam).
	local diving = alive and character:GetAttribute("UpdraftSlam") == "Down"
	local crouch = if state == "Crouch" or (diving and not SLAM_POSE) then 1 else 0

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
	for setName, names in HOLD_SETS do
		local on = if (setName == "pistol") == pistol then 1 else 0
		setWeight(animator, names[1], on * hip * math.max(pitch, 0))
		setWeight(animator, names[2], on * hip * (1 - math.abs(pitch)))
		setWeight(animator, names[3], on * hip * math.max(-pitch, 0))
		setWeight(animator, names[4], on * sights * math.max(pitch, 0))
		setWeight(animator, names[5], on * sights * (1 - math.abs(pitch)))
		setWeight(animator, names[6], on * sights * math.max(-pitch, 0))
	end
	-- A reload (timed to the gun) and a flinch when hit, from the server.
	if newMark(reloadSeen, character, player:GetAttribute("ReloadAt")) and alive and armed > 0 then
		local duration = player:GetAttribute("ReloadFor")
		if typeof(duration) == "number" and duration > 0.1 then
			playOnce(animator, "Reload", Animations.RELOAD_LENGTH / duration)
		end
	end
	if newMark(hitSeen, character, player:GetAttribute("HitAt")) and alive then
		playOnce(animator, "Flinch", 1, Animations.FLINCH_WEIGHT)
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
	local knife = alive and config ~= nil and config.fireMode == "Melee" and not holding
	setWeight(animator, "KnifeReady", if knife then 1 else 0)
	if newMark(swingSeen, character, player:GetAttribute("SwingAt")) and alive then
		local step = player:GetAttribute("SwingStep")
		playOnce(
			animator,
			if player:GetAttribute("SwingHeavy") == true
				then "KnifeHeavy"
				elseif step == 2 then "KnifeSlash2"
				elseif step == 3 then "KnifeSlash3"
				else "KnifeSlash"
		)
	end
	-- Movement (Action2 / Action3) layers over the aim and the walk cycle.
	setWeight(animator, "Sprint", if state == "Sprint" then 1 else 0)
	setWeight(animator, "Crouch", crouch * (1 - moving))
	-- Crouch-walking blends its four directions like the run.
	local wf, wb, wl, wr = directions(root)
	local walking = crouch * moving
	setWeight(animator, "CrouchWalk", walking * wf)
	setWeight(animator, "CrouchWalkB", walking * wb)
	setWeight(animator, "CrouchWalkL", walking * wl)
	setWeight(animator, "CrouchWalkR", walking * wr)
	setWeight(animator, "Slide", if state == "Slide" then 1 else 0)
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
	local dashStart = character:GetAttribute("DashStart")
	local dashMark = if typeof(dashStart) == "number" then dashStart else 0
	local dashSeen = character:GetAttribute("PoseDashSeen")
	if dashSeen ~= dashMark then
		character:SetAttribute("PoseDashSeen", dashMark)
		local velocity = character:GetAttribute("DashVelocity")
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
	local updraftAt = character:GetAttribute("UpdraftAt")
	local updraftMark = if typeof(updraftAt) == "number" then updraftAt else 0
	local updraftSeen = character:GetAttribute("PoseUpdraftSeen")
	if updraftSeen ~= updraftMark then
		character:SetAttribute("PoseUpdraftSeen", updraftMark)
		if typeof(updraftSeen) == "number" and alive then
			playOnce(animator, "Updraft")
		end
	end

	-- A Crash Down landing: the slam clip once (the first value seen only
	-- sets the mark).
	local slamAt = character:GetAttribute("UpdraftSlamAt")
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
	local useAt = player:GetAttribute("ModUseAt")
	if typeof(useAt) == "number" then
		local seenAt = character:GetAttribute("PoseUseSeen")
		if seenAt ~= useAt then
			character:SetAttribute("PoseUseSeen", useAt)
			local kind = player:GetAttribute("ModUseKind")
			if typeof(seenAt) == "number" and alive and typeof(kind) == "string" then
				playOnce(animator, kind)
			end
		end
	end

	stepLegs(animator, root, state, speed, alive)
	-- Touching down: a quick knee dip over whatever the legs are doing.
	local inAir = state == "Air"
	if wasAir[character] and not inAir and alive then
		playOnce(animator, "Land")
	end
	wasAir[character] = inAir
	-- The slide: dropping into it, and getting up out of it when it ends on
	-- your feet (a slide-jump has the jump; into a crouch, the crouch fades in).
	-- The first look at a character only sets the mark.
	local sliding = state == "Slide"
	local slidWas = wasSlide[character]
	if sliding and slidWas == false and alive then
		playOnce(animator, "SlideIn")
	elseif
		slidWas
		and not sliding
		and alive
		and (state == "Walk" or state == "Sprint" or state == "Idle")
	then
		local into = playing(animator, "UseSlideIn")
		if into then
			into:Stop(0.05) -- a very short slide
		end
		playOnce(animator, "SlideOut")
	end
	wasSlide[character] = sliding
	-- The hold's scrape chatter calms as the slide slows.
	local hold = playing(animator, "Slide")
	local chatter =
		math.clamp(speed / Animations.SLIDE_CHATTER_SPEED, Animations.SLIDE_CHATTER_MIN, 1)
	if hold and math.abs(hold.Speed - chatter) > 0.05 then
		hold:AdjustSpeed(chatter)
	end

	-- Crouch-walk stride speed follows the ground speed.
	local stride = math.clamp(speed / Animations.CROUCH_WALK_SPEED, 0.4, 1.6)
	for _, name in CROUCH_SET do
		local walk = playing(animator, name)
		if walk and math.abs(walk.Speed - stride) > 0.1 then
			walk:AdjustSpeed(stride)
		end
	end
end

local function step(dt: number)
	if RunService:IsServer() then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				stepCharacter(player, character, dt)
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
	stepLegs(animator, root, "Walk", speed, Health.isAlive(humanoid))
end

-- Call once on the server and once on each client.
function PoseSim.initialize()
	if connection then
		return
	end
	-- Priority 4000 runs after the movement step (default 2000) has written
	-- this tick's MoveState, like Animate.
	connection = RunService:BindToSimulation(step, Enum.StepFrequency.Hz60, 4000)
	-- Load every clip up front: a one-shot that isn't loaded yet has length
	-- 0 and ends at once, so the first slide / landing / dash would skip it.
	task.spawn(function()
		local list: { Instance } = {}
		for name in IDS do
			table.insert(list, animationFor(name))
		end
		for kind, animId in USE_IDS do
			local key = "Use" .. kind
			if not animations[key] then
				local a = Instance.new("Animation")
				a.Name = key
				a.AnimationId = animId
				animations[key] = a
			end
			table.insert(list, animations[key])
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

return PoseSim
