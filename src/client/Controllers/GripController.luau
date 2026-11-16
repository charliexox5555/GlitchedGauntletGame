--!strict
-- The support hand on the gun, for every character this client can see
-- (other players, AI bots and test-range dummies, both in Workspace.Dummies):
-- an IKControl puts the end of the left forearm block on the held gun's
-- LeftGrip (slid back along the barrel when the arm can't reach it). Cosmetic
-- and local: the hold clips (Simulation/Poses) already put both hands on the
-- reference guns; this lands the hand on each gun's own grip.
--
-- The IK target is an Attachment on the RIGHT HAND, at the spot where the
-- gun's grip sits when the gun is at rest in that hand. So the support hand
-- follows the gun through every pose, and holds still while the gun kicks:
-- on a shot the gun jumps between two steady hands (EffectsController moves
-- it in the hand with a spring; Config/Juice WORLD_KICK). Until 2026-11-12
-- the target sat on the chest and a second IKControl pulled the right arm
-- back on every shot: that one switched on and off per shot and threw the
-- gun and both hands up to 1.2 studs in a frame (measured), which is what
-- read as jitter. A target on the gun itself was tried too: the solver
-- can't keep up with a kick and the hand twitched (0.7 studs off for a
-- frame). Nothing here moves or restarts on a shot now.
--
-- IK and not more clips: scripted joint Transforms don't stick on these
-- AnimationConstraint rigs (the Animator overwrites them), but IKControl
-- solves after the Animator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Health = require(ReplicatedStorage.Shared.Health)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local GripController = {}

local GRIP = Animations.GRIP
local SCAN = 0.5 -- seconds between looks for new characters

type Rig = {
	character: Model,
	humanoid: Humanoid,
	left: IKControl,
	leftPole: Attachment,
	target: Attachment?, -- on the right hand, moved along the barrel's line
	gun: Model?,
	hand: BasePart?, -- the right hand, which carries the gun
	rest: CFrame, -- the gun's handle in the hand's frame, at rest (no kick)
	probe: BasePart?, -- a visible part of the gun (the Handle itself is invisible)
	base: Vector3, -- where the hand goes, in the handle's frame, before any slide
	forward: Vector3, -- the barrel's direction, in the handle's frame
	slide: number, -- studs the hand has slid back from `base`
	reach: number, -- longest shoulder-to-block-end distance for this rig's left arm
	weight: number,
}

local rigs: { [Model]: Rig } = {}

local function attributeSource(character: Model): Instance
	return Players:GetPlayerFromCharacter(character) or character
end

-- The left arm's length, shoulder to the end of the forearm block.
local function armLength(character: Model): number
	local function at(partName: string, attName: string): Vector3?
		local part = character:FindFirstChild(partName)
		local att = part and part:FindFirstChild(attName)
		return if att and att:IsA("Attachment") then att.Position else nil
	end
	local s = at("LeftUpperArm", "LeftShoulderRigAttachment")
	local e1 = at("LeftUpperArm", "LeftElbowRigAttachment")
	local e2 = at("LeftLowerArm", "LeftElbowRigAttachment")
	local w1 = at("LeftLowerArm", "LeftWristRigAttachment")
	local w2 = at("LeftHand", "LeftWristRigAttachment")
	if not (s and e1 and e2 and w1 and w2) then
		return 1.86 + GRIP.tip -- a default R15 arm
	end
	return (e1 - s).Magnitude + (w1 - e2).Magnitude + w2.Magnitude + GRIP.tip
end

local function newRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso")
	local upperL = character:FindFirstChild("LeftUpperArm")
	local handL = character:FindFirstChild("LeftHand")
	if
		not humanoid
		or not (torso and torso:IsA("BasePart"))
		or not (upperL and upperL:IsA("BasePart"))
		or not (handL and handL:IsA("BasePart"))
	then
		return nil
	end
	local pole = Instance.new("Attachment")
	pole.Name = "GGLeftPole"
	pole.Position = GRIP.leftPole
	pole.Parent = torso
	local left = Instance.new("IKControl")
	left.Name = "GGLeftGrip"
	-- Position only: a full transform target asks for a palm angle the arm's
	-- joint cone limits refuse (measured 2026-11-05: the hand stopped 0.71
	-- studs short). The hold clips already set the hand's angle.
	left.Type = Enum.IKControlType.Position
	left.ChainRoot = upperL
	left.EndEffector = handL
	-- The visible forearm block ends past the hand part: that end goes to the grip.
	left.EndEffectorOffset = CFrame.new(0, -GRIP.tip, 0)
	-- With a Pole an IKControl bends the arm even at Weight 0 (LihFolk
	-- "IKControl Reference"), hence the Enabled switch in stepRig.
	left.Pole = pole
	left.Weight = 0
	left.Enabled = false
	left.SmoothTime = 0 -- follow the gun exactly (the default 0.05 s lags it)
	left.Parent = humanoid
	local rig: Rig = {
		character = character,
		humanoid = humanoid,
		left = left,
		leftPole = pole,
		target = nil,
		gun = nil,
		hand = nil,
		rest = CFrame.identity,
		probe = nil,
		base = Vector3.zero,
		forward = Vector3.new(0, 0, -1),
		slide = 0,
		reach = armLength(character) * GRIP.reachFraction,
		weight = 0,
	}
	character.Destroying:Once(function()
		rigs[character] = nil
	end)
	return rig
end

local function dropRig(character: Model)
	local rig = rigs[character]
	if rig then
		rig.left:Destroy()
		rig.leftPole:Destroy()
		if rig.target then
			rig.target:Destroy()
		end
		rigs[character] = nil
	end
end

-- Studio only: Workspace attribute DevThirdPerson (true) rigs your own
-- character too, for looking at it from outside (tools/studio/
-- ThirdPersonReviewRig.luau); it is first person otherwise, so its own grip
-- is never seen.
local function ownToo(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("DevThirdPerson") == true
end

local function watch(character: Model)
	if rigs[character] or (character == Players.LocalPlayer.Character and not ownToo()) then
		return
	end
	local rig = newRig(character)
	if rig then
		rigs[character] = rig
	end
end

local function scan()
	for _, player in Players:GetPlayers() do
		if player.Character then
			watch(player.Character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, model in dummies:GetChildren() do
			if model:IsA("Model") then
				watch(model)
			end
		end
	end
	for character, rig in rigs do
		if not character.Parent or not rig.humanoid.Parent then
			dropRig(character)
		end
	end
end

-- The held gun (rebuilt by WeaponService on every swap): a new target on it.
local function refreshGun(rig: Rig)
	local gun = rig.character:FindFirstChild("WorldWeapon")
	if gun == rig.gun then
		return
	end
	rig.gun = if gun and gun:IsA("Model") then gun else nil
	rig.hand = nil
	rig.probe = nil
	rig.slide = 0
	if rig.target then
		rig.target:Destroy()
		rig.target = nil
	end
	rig.left.Target = nil
	if not rig.gun then
		return
	end
	local handle = (rig.gun :: Model).PrimaryPart
	local hand = rig.character:FindFirstChild("RightHand")
	local motor = (rig.gun :: Model):FindFirstChild("WeaponGrip", true)
	local grip = (rig.gun :: Model):FindFirstChild("LeftGrip", true)
	local id = (rig.gun :: Model):GetAttribute("WeaponId")
	local config = if typeof(id) == "string" then Weapons.get(id) else nil
	-- A second gun in the left hand needs no grip; the knife has none.
	local second = rig.character:FindFirstChild("WorldWeaponLeft") ~= nil
	if
		not (handle and grip and grip:IsA("Attachment"))
		or not (hand and hand:IsA("BasePart"))
		or not (motor and motor:IsA("Motor6D"))
		or second
	then
		return
	end
	local style = if config and config.class == "Sidearm" then GRIP.sidearm else GRIP.long
	rig.hand = hand
	-- (C0 alone: the joint's C1 is identity at rest, and the kick lives in C1.)
	rig.rest = motor.C0
	rig.base = handle.CFrame:PointToObjectSpace(grip.WorldPosition)
		+ Vector3.new(style.side, -style.under, 0)
	local muzzle = (rig.gun :: Model):FindFirstChild("Muzzle", true)
	rig.forward = Vector3.new(0, 0, -1)
	if muzzle and muzzle:IsA("Attachment") then
		local toMuzzle = handle.CFrame:PointToObjectSpace(muzzle.WorldPosition)
		if toMuzzle.Magnitude > 0.05 then
			rig.forward = toMuzzle.Unit
		end
	end
	local target = Instance.new("Attachment")
	target.Name = "GGLeftHold"
	target.Position = rig.rest:PointToWorldSpace(rig.base)
	target.Parent = hand
	rig.target = target
	rig.left.Target = target
end

-- Whether the left hand belongs on the gun right now.
local function wantsGrip(rig: Rig): boolean
	if not rig.target or not Health.isAlive(rig.humanoid) then
		return false
	end
	-- The slide clip puts the left hand on the floor.
	if rig.character:GetAttribute("MoveState") == "Slide" then
		return false
	end
	local src = attributeSource(rig.character)
	local held = src:GetAttribute("ModHeld")
	if typeof(held) == "number" and held ~= 0 then
		return false
	end
	-- The reload clip takes the left hand to the magazine.
	local reloadAt = src:GetAttribute("ReloadAt")
	local reloadFor = src:GetAttribute("ReloadFor")
	if typeof(reloadAt) == "number" and typeof(reloadFor) == "number" then
		local since = Workspace:GetServerTimeNow() - reloadAt
		if since >= 0 and since < reloadFor + GRIP.regrip then
			return false
		end
	end
	local useAt = src:GetAttribute("ModUseAt")
	if typeof(useAt) == "number" then
		local since = Workspace:GetServerTimeNow() - useAt
		if since >= 0 and since < GRIP.afterModUse then
			return false
		end
	end
	-- WeaponService hides the gun (every part fully transparent) while a Mod
	-- is in the hand.
	local probe = rig.probe
	if not probe or probe.Transparency >= 1 then
		probe = nil
		for _, d in (rig.gun :: Model):GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				probe = d
				break
			end
		end
		rig.probe = probe
	end
	return probe ~= nil
end

-- How far the hand has to slide back from the grip, toward the handle, for
-- the left arm to reach it (0 when it reaches the grip itself).
local function slideFor(rig: Rig, hand: BasePart): number
	local shoulder = rig.character:FindFirstChild("LeftUpperArm")
	local shoulderAtt = shoulder and shoulder:FindFirstChild("LeftShoulderRigAttachment")
	if not (shoulderAtt and shoulderAtt:IsA("Attachment")) then
		return 0
	end
	-- (In the gun's frame at rest, so a kick doesn't change the answer.)
	local from = (hand.CFrame * rig.rest):PointToObjectSpace(shoulderAtt.WorldPosition)
	local rel = rig.base - from
	if rel.Magnitude <= rig.reach then
		return 0
	end
	-- Solve |base - forward * t - from| = reach for the smallest t >= 0.
	local b = rel:Dot(rig.forward)
	local c = rel:Dot(rel) - rig.reach * rig.reach
	local disc = b * b - c
	local t = if disc >= 0 then b - math.sqrt(disc) else b
	return math.clamp(t, 0, GRIP.maxSlide)
end

local function stepRig(rig: Rig, dt: number, camPos: Vector3)
	local root = rig.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local far = (root.Position - camPos).Magnitude > GRIP.maxDistance
	refreshGun(rig)
	local want = if not far and wantsGrip(rig) then 1 else 0
	local speed = if want > rig.weight then GRIP.fadeIn else GRIP.fadeOut
	rig.weight += (want - rig.weight) * (1 - math.exp(-speed * dt))
	if rig.weight < 0.01 and want == 0 then
		rig.weight = 0
	end
	local hand, target = rig.hand, rig.target
	if hand and target and rig.weight > 0 then
		-- Eased, so the hand glides along the barrel as the aim or the body
		-- changes what it can reach.
		local slide = slideFor(rig, hand)
		rig.slide += (slide - rig.slide) * (1 - math.exp(-GRIP.slideSmoothing * dt))
		target.Position = rig.rest:PointToWorldSpace(rig.base - rig.forward * rig.slide)
	end
	rig.left.Weight = rig.weight
	rig.left.Enabled = rig.weight > 0 and target ~= nil
end

function GripController.start()
	task.spawn(function()
		while true do
			scan()
			task.wait(SCAN)
		end
	end)
	RunService.PreRender:Connect(function(dt: number)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		for _, rig in rigs do
			stepRig(rig, dt, camPos)
		end
	end)
end

return GripController
