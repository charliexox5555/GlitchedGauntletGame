--!strict
-- Third-person pose tracks (Config/Animations): holding the gun (a blend of
-- three pitch poses), the sprint carry, crouch / crouch-walk and slide.
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
}
local IDS = Animations.POSES :: { [string]: string }
-- A weight of exactly 0 lets the Animator drop the track; stay just above.
local OFF = 0.001

local connection: RBXScriptConnection? = nil
local animations: { [string]: Animation } = {}
local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

-- Run only where this side simulates the character (the server for
-- everyone, a client for its own character), like Animate does.
local function isSimulated(instance: Instance): boolean
	local ok, status = pcall(function()
		return RunService:GetPredictionStatus(instance)
	end)
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
	local armed = if alive and config and config.fireMode ~= "Melee" then 1 else 0
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
