--!strict
-- Third-person pose tracks (Config/Animations): holding the gun (a blend of
-- three pitch poses), the sprint carry, crouch / crouch-walk and slide, and
-- the Mods: a hold pose while a held Mod is up (player attribute ModHeld)
-- and a one-shot throw / place / heal on each use (ModUseKind / ModUseAt,
-- written by ModService; the character attribute PoseUseSeen remembers the
-- last one played).
--
-- Stepped inside the Server Authority simulation, the same way Roblox's own
-- Animate module works: the server poses every player, each client predicts
-- its own character. Both sides read the same inputs (MoveState from
-- Simulation/Movement, the AimPitch input action, the equipped weapon and
-- ground speed), so the prediction matches. Tracks played only on a client
-- get stopped by the server. Weights move through the Animator's own fades,
-- so state changes blend instead of popping.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
	Slide = { priority = Enum.AnimationPriority.Action3, fade = FADE.slide },
	ModHold = { priority = Enum.AnimationPriority.Action, fade = Animations.MOD_FADE },
}
local IDS: { [string]: string } = table.clone(Animations.POSES :: any)
IDS.ModHold = Animations.MODS.ModHold
-- One-shots on a use, by ModUseKind.
local USE_IDS: { [string]: string } = {
	Throw = Animations.MODS.Throw,
	Place = Animations.MODS.Place,
	Heal = Animations.MODS.Heal,
	-- Dash leans (Mods/Dash), by direction relative to the body.
	DashForward = Animations.MODS.DashForward,
	DashBack = Animations.MODS.DashBack,
	DashLeft = Animations.MODS.DashLeft,
	DashRight = Animations.MODS.DashRight,
}
-- A weight of exactly 0 lets the Animator drop the track; stay just above.
local OFF = 0.001

local connection: RBXScriptConnection? = nil
local animations: { [string]: Animation } = {}
local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

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

-- Plays a Mod use clip once (Action4, over everything else).
local function playOnce(animator: Animator, kind: string)
	local animId = USE_IDS[kind]
	if not animId then
		return
	end
	local a = animations["Use" .. kind]
	if not a then
		a = Instance.new("Animation")
		a.Name = "Use" .. kind
		a.AnimationId = animId
		animations["Use" .. kind] = a
	end
	-- One track per clip per Animator, loaded once and replayed.
	local byName = cache[animator]
	if not byName then
		byName = {}
		cache[animator] = byName
	end
	local key = "Use" .. kind
	local track = byName[key]
	if not track then
		track = animator:LoadAnimation(a :: Animation)
		byName[key] = track
	end
	local t = track :: AnimationTrack
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = false
	t:Play(0.05, 1, 1)
end

local function setWeight(animator: Animator, name: string, weight: number)
	local step = Animations.WEIGHT_STEP
	local w = math.clamp(math.floor(weight / step + 0.5) * step, OFF, 1)
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
			return math.clamp(v * 90 / Animations.AIM_PITCH_RANGE, -1, 1)
		end
	end
	return 0
end

local function stepCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not root or not root:IsA("BasePart") or not animator then
		return
	end
	if not isSimulated(root) or not isSimulated(animator) then
		return
	end

	local alive = humanoid.Health > 0
	local state = if alive then character:GetAttribute("MoveState") else nil
	local weaponId = player:GetAttribute("WeaponId")
	local config = if typeof(weaponId) == "string" then Weapons.get(weaponId) else nil
	-- The knife has no two-handed hold; it keeps the default arm swing.
	local held = player:GetAttribute("ModHeld")
	local holding = alive and typeof(held) == "number" and held ~= 0
	local armed = if alive and config and config.fireMode ~= "Melee" and not holding then 1 else 0
	local pitch = aimPitch(player)
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local moving = if speed > Animations.MOVING_SPEED then 1 else 0
	local crouch = if state == "Crouch" then 1 else 0

	-- Aim: a blend space of three held poses (Action priority).
	setWeight(animator, "AimUp", armed * math.max(pitch, 0))
	setWeight(animator, "AimDown", armed * math.max(-pitch, 0))
	setWeight(animator, "AimLevel", armed * (1 - math.abs(pitch)))
	-- Movement (Action2 / Action3) layers over the aim and the walk cycle.
	setWeight(animator, "Sprint", if state == "Sprint" then 1 else 0)
	setWeight(animator, "Crouch", crouch * (1 - moving))
	setWeight(animator, "CrouchWalk", crouch * moving)
	setWeight(animator, "Slide", if state == "Slide" then 1 else 0)
	setWeight(animator, "ModHold", if holding then 1 else 0)

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

	-- Crouch-walk stride speed follows the ground speed.
	local walk = trackFor(animator, "CrouchWalk")
	local stride = math.clamp(speed / Animations.CROUCH_WALK_SPEED, 0.4, 1.6)
	if math.abs(walk.Speed - stride) > 0.1 then
		walk:AdjustSpeed(stride)
	end
end

local function step(_dt: number)
	if RunService:IsServer() then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				stepCharacter(player, character)
			end
		end
	else
		local player = Players.LocalPlayer
		local character = player and player.Character
		if character then
			stepCharacter(player, character)
		end
	end
end

-- Call once on the server and once on each client.
function PoseSim.initialize()
	if connection then
		return
	end
	-- Priority 4000 runs after the movement step (default 2000) has written
	-- this tick's MoveState, like Animate.
	connection = RunService:BindToSimulation(step, Enum.StepFrequency.Hz60, 4000)
end

return PoseSim
