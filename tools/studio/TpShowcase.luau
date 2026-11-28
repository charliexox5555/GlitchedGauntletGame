--!strict
-- Third-person animation showcase (vault/02 Art/Third Person Animation Pass.md).
-- Run with the Studio MCP in the CLIENT datamodel during a playtest (a bot
-- match: Workspace ServerRole = "Match"). It copies a fighter's body
-- (Util/BodyClone, client-only), arms each copy with a Vandal and lays out
-- four lanes on a floor in the sky, each looping one vignette with the real
-- clips from Config/Animations:
--   1 idle (Idle + AimLevel)
--   2 walk (WalkF at 10 studs/s, back and forth, + AimLevel [+ AimMove])
--   3 crouch (Crouch idle, then CrouchWalk at 9 studs/s, + AimLevel [+ AimMove])
--   4 jump (Jump -> Fall -> Land on a 4.4-stud arc, + AimLevel)
-- The camera is scriptable, side-on three-quarter. The same script makes the
-- before and the after captures. Stop: Workspace attribute TpShowcaseStop = true
-- (or stop the playtest). Nothing here touches the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations) :: any
local player = Players.LocalPlayer
local BodyClone = require(player.PlayerScripts.Client.Util.BodyClone) :: any

local ORIGIN = Vector3.new(0, 600, 0)
local LANE_GAP = 30 -- wide, so a side-on camera on one lane doesn't look through another
local WALK_SPEED = Animations.WALK_CLIP_SPEED
local CROUCH_SPEED = Animations.CROUCH_WALK_SPEED
local LANE_LENGTH = 12

local old = Workspace:FindFirstChild("TpShowcase")
if old then
	old:Destroy()
end
Workspace:SetAttribute("TpShowcaseStop", nil)
local folder = Instance.new("Folder")
folder.Name = "TpShowcase"
folder.Parent = Workspace
local floor = Instance.new("Part")
floor.Anchored = true
floor.Size = Vector3.new(LANE_GAP * 3 + 40, 1, 50)
floor.CFrame = CFrame.new(ORIGIN + Vector3.new(LANE_GAP * 1.5, -0.5, -LANE_LENGTH / 2))
floor.Color = Color3.fromRGB(120, 124, 130)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = folder
-- Lane marks every 2 studs (to read foot slide).
for i = 0, 3 do
	for z = 0, LANE_LENGTH + 2, 2 do
		local mark = Instance.new("Part")
		mark.Anchored = true
		mark.CanCollide = false
		mark.Size = Vector3.new(2.4, 0.05, 0.12)
		mark.Color = Color3.fromRGB(90, 94, 100)
		mark.CFrame = CFrame.new(ORIGIN + Vector3.new(i * LANE_GAP, 0.02, -z + 1))
		mark.Parent = folder
	end
end

-- The source body: a bot, else your own character.
local source: Model? = nil
local dummies = Workspace:FindFirstChild("Dummies")
if dummies then
	source = dummies:FindFirstChildWhichIsA("Model")
end
source = source or player.Character
assert(source, "no body to copy")

local GRIP = Animations.GUN_WORLD_GRIP
local function arm(copy: Model)
	local old = copy:FindFirstChild("WorldWeapon")
	if old then
		old:Destroy()
	end
	local template = ReplicatedStorage:FindFirstChild("Weapons")
	template = template and template:FindFirstChild("Vandal")
	local hand = copy:FindFirstChild("RightHand")
	if not (template and template:IsA("Model") and hand and hand:IsA("BasePart")) then
		return
	end
	local model = template:Clone()
	local handle = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	model.Name = "WorldWeapon"
	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponGrip"
	motor.Part0 = hand
	motor.Part1 = handle
	motor.C0 = GRIP
	motor.Parent = handle
	handle.CFrame = hand.CFrame * GRIP
	model.Parent = copy
end

type Rig = { copy: Model, root: BasePart, animator: Animator, tracks: { [string]: AnimationTrack }, hip: number }

-- Ids to use instead of Config/Animations (the "before" capture: paste the old
-- ids here; an entry set to false leaves that clip out).
local OVERRIDE: { [string]: string | false } = {}

local function id(name: string): string?
	local forced = OVERRIDE[name]
	if forced ~= nil then
		return if forced then forced else nil
	end
	for _, group in { "POSES", "LOCOMOTION", "COMBAT", "MODS" } do
		local v = Animations[group] and Animations[group][name]
		if typeof(v) == "string" and v ~= "" then
			return v
		end
	end
	if name == "Idle" then
		return Animations.ANIMATE.idle
	elseif name == "Jump" then
		return Animations.ANIMATE.jump
	elseif name == "Fall" then
		return Animations.ANIMATE.fall
	end
	return nil
end

local PRIORITY = {
	Idle = Enum.AnimationPriority.Core,
	WalkF = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Movement,
	Fall = Enum.AnimationPriority.Movement,
	AimLevel = Enum.AnimationPriority.Action,
	AimMove = Enum.AnimationPriority.Action,
	Crouch = Enum.AnimationPriority.Action2,
	CrouchIdle = Enum.AnimationPriority.Action2,
	CrouchWalk = Enum.AnimationPriority.Action2,
	Land = Enum.AnimationPriority.Action4,
}

local function track(rig: Rig, name: string): AnimationTrack?
	local t = rig.tracks[name]
	if t then
		return t
	end
	local animId = id(name)
	if not animId then
		return nil
	end
	local a = Instance.new("Animation")
	a.AnimationId = animId
	t = rig.animator:LoadAnimation(a)
	t.Priority = PRIORITY[name] or Enum.AnimationPriority.Action
	t.Looped = name ~= "Land" and name ~= "Jump"
	rig.tracks[name] = t
	return t
end

-- Fades `name` toward `w` (playing it when needed).
local function weight(rig: Rig, name: string, w: number, fade: number?, speed: number?)
	local t = track(rig, name)
	if not t then
		return
	end
	if w > 0.001 and not t.IsPlaying then
		t:Play(fade or 0.15, w, speed or 1)
	elseif t.IsPlaying then
		if math.abs(t.WeightTarget - w) > 1e-3 then
			t:AdjustWeight(math.max(w, 0.001), fade or 0.15)
		end
		if speed and math.abs(t.Speed - speed) > 1e-3 then
			t:AdjustSpeed(speed)
		end
	end
end

local function make(i: number): Rig
	local copy = BodyClone.copy(source, "root", "Showcase" .. i)
	assert(copy, "copy failed")
	BodyClone.kinematic(copy)
	arm(copy)
	local root = copy:FindFirstChild("HumanoidRootPart")
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	assert(root and root:IsA("BasePart") and humanoid, "copy has no root or humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for _, t in animator:GetPlayingAnimationTracks() do
		t:Stop(0)
	end
	local hip = humanoid.HipHeight + root.Size.Y / 2
	copy.Parent = folder
	return { copy = copy, root = root, animator = animator :: Animator, tracks = {}, hip = hip }
end

local rigs = { make(1), make(2), make(3), make(4) }
local function place(rig: Rig, lane: number, z: number, y: number, back: boolean)
	local at = ORIGIN + Vector3.new(lane * LANE_GAP, rig.hip + y, -z)
	local face = if back then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
	rig.root.CFrame = CFrame.lookAt(at, at + face)
end

-- Camera: follows one vignette (Workspace attribute TpShowcaseFocus 1-4, 0 =
-- all four) from TpShowcaseOffset (a Vector3 from the body; default
-- three-quarter front-left). The HUD and the first-person gun are hidden.
local camera = Workspace.CurrentCamera
for _, gui in player.PlayerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		gui.Enabled = false
	end
end
local smooth: Vector3? = nil
local function steer(dt: number)
	local focus = Workspace:GetAttribute("TpShowcaseFocus")
	local offset = Workspace:GetAttribute("TpShowcaseOffset")
	local target = ORIGIN + Vector3.new(LANE_GAP * 1.5, 2.6, -LANE_LENGTH / 2)
	local from = Vector3.new(-26, 9, -24)
	local rig = if typeof(focus) == "number" then rigs[focus] else nil
	if rig then
		local p = rig.root.Position
		target = Vector3.new(p.X, ORIGIN.Y + 2.6, p.Z)
		from = if typeof(offset) == "Vector3" then offset else Vector3.new(-6.5, 1.6, -7)
	end
	smooth = if smooth then smooth:Lerp(target, 1 - math.exp(-8 * dt)) else target
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt((smooth :: Vector3) + from, smooth :: Vector3)
	camera.FieldOfView = 50
	for _, model in camera:GetChildren() do
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
end

local hasMove = id("AimMove") ~= nil
local t0 = os.clock()
local jumpWas = "idle"
local conn: RBXScriptConnection
conn = RunService.RenderStepped:Connect(function(dt)
	if Workspace:GetAttribute("TpShowcaseStop") == true or not folder.Parent then
		conn:Disconnect()
		folder:Destroy()
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	local t = os.clock() - t0
	-- 1 idle
	local r1 = rigs[1]
	place(r1, 0, LANE_LENGTH / 2, 0, false)
	weight(r1, "Idle", 1)
	weight(r1, "AimLevel", 1)
	-- 2 walk: there and back, a short stop at each end
	local r2 = rigs[2]
	local legTime = LANE_LENGTH / WALK_SPEED
	local cycle = 2 * (legTime + 0.6)
	local u = t % cycle
	local half = legTime + 0.6
	local back = u >= half
	local v = if back then u - half else u
	local moving = v < legTime
	local z = if moving then v * WALK_SPEED else LANE_LENGTH
	place(r2, 1, if back then LANE_LENGTH - z else z, 0, back)
	weight(r2, "Idle", 1)
	weight(r2, "WalkF", if moving then 1 else 0, 0.12, 1)
	weight(r2, "AimLevel", if hasMove and moving then 0 else 1, 0.12)
	if hasMove then
		weight(r2, "AimMove", if moving then 1 else 0, 0.12, 1)
	end
	-- 3 crouch: 2.4 s still, then a crouch walk down the lane and back
	local r3 = rigs[3]
	local crouchLeg = LANE_LENGTH / CROUCH_SPEED
	local cc = 2.4 + crouchLeg
	local u3 = t % (2 * cc)
	local back3 = u3 >= cc
	local v3 = if back3 then u3 - cc else u3
	local walking = v3 >= 2.4
	local z3 = if walking then (v3 - 2.4) * CROUCH_SPEED else 0
	place(r3, 2, if back3 then LANE_LENGTH - z3 else z3, 0, back3)
	weight(r3, "Idle", 1)
	weight(r3, "Crouch", if walking then 0 else 1, 0.15)
	weight(r3, "CrouchWalk", if walking then 1 else 0, 0.15, 1)
	weight(r3, "AimLevel", if hasMove and walking then 0 else 1, 0.15)
	if hasMove then
		-- (one AimMove cycle per crouch stride: 0.36 s clip, 0.3 s stride)
		weight(r3, "AimMove", if walking then 1 else 0, 0.15, 0.36 / 0.3)
	end
	-- 4 jump: every 1.8 s a 4.4-stud jump (rise 0.21 s, fall 0.17 s at 1.6x gravity)
	local r4 = rigs[4]
	local j = t % 1.8
	local rise, fall, height = 0.21, 0.17, 4.4
	local y = 0
	local state = "idle"
	if j < rise then
		local s = j / rise
		y = height * (1 - (1 - s) ^ 2)
		state = "jump"
	elseif j < rise + fall then
		local s = (j - rise) / fall
		y = height * (1 - s * s)
		state = if j < 0.31 then "jump" else "fall"
	end
	place(r4, 3, LANE_LENGTH / 2, y, false)
	weight(r4, "Idle", 1)
	weight(r4, "AimLevel", 1)
	if state == "jump" and jumpWas == "idle" then
		local jt = track(r4, "Jump")
		if jt then
			jt:Play(0.05, 1, 1)
		end
	end
	weight(r4, "Fall", if state == "fall" then 1 else 0, 0.1)
	if state == "idle" and jumpWas ~= "idle" then
		local jt = track(r4, "Jump")
		if jt and jt.IsPlaying then
			jt:Stop(0.05)
		end
		local land = track(r4, "Land")
		if land then
			land:Play(0.03, 1, 1)
		end
	end
	jumpWas = state
	steer(dt)
end)
return string.format("showcase from %s, AimMove: %s", source:GetFullName(), tostring(hasMove))
