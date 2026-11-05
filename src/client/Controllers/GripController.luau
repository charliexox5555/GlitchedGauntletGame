--!strict
-- Hands on the gun for every character this client can see (other players,
-- AI bots and test-range dummies, both in Workspace.Dummies): an IKControl puts the left hand on
-- the held gun's LeftGrip attachment (slid back along the barrel when a long
-- gun's grip is out of the arm's reach), and on each shot (ShotFx) a second
-- IKControl pulls the right forearm back with the gun so the arms take the
-- kick (Config/Animations GRIP, FIRE_KICK). Cosmetic and local: the clips
-- (Simulation/Poses) already hold the gun two-handed for the reference guns;
-- this lands the hand exactly on each gun's own grip.
--
-- IK and not more clips (2026-11-04, lane D): scripted joint Transforms don't
-- stick on these AnimationConstraint rigs (the Animator overwrites them), but
-- IKControl solves after the Animator on server and client alike.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Health = require(ReplicatedStorage.Shared.Health)
local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local GripController = {}

local GRIP = Animations.GRIP
local SCAN = 0.5 -- seconds between looks for new characters

type Rig = {
	character: Model,
	humanoid: Humanoid,
	left: IKControl,
	leftTarget: Attachment, -- on UpperTorso, moved each frame
	leftPole: Attachment,
	right: IKControl,
	rightTarget: Attachment, -- on UpperTorso
	rightRest: CFrame?, -- the hand in UpperTorso space when the kick started
	gun: Model?,
	handle: BasePart?,
	probe: BasePart?, -- a visible part of the gun (the Handle itself is invisible)
	grip: Attachment?,
	class: string,
	reach: number, -- longest shoulder-to-hand distance for this rig's left arm
	weight: number,
	kickAt: number,
	kick: { back: number, rise: number, recover: number },
	kickForward: Vector3,
}

local rigs: { [Model]: Rig } = {}

local function attributeSource(character: Model): Instance
	return Players:GetPlayerFromCharacter(character) or character
end

-- The left arm's length, shoulder to hand centre (avatars differ).
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
		return 1.86 -- a default R15 arm
	end
	return (e1 - s).Magnitude + (w1 - e2).Magnitude + w2.Magnitude
end

local function newRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso")
	local upperL = character:FindFirstChild("LeftUpperArm")
	local handL = character:FindFirstChild("LeftHand")
	local upperR = character:FindFirstChild("RightUpperArm")
	local lowerR = character:FindFirstChild("RightLowerArm")
	local handR = character:FindFirstChild("RightHand")
	if
		not humanoid
		or not (torso and torso:IsA("BasePart"))
		or not (upperL and upperL:IsA("BasePart"))
		or not (handL and handL:IsA("BasePart"))
		or not (upperR and upperR:IsA("BasePart"))
		or not (lowerR and lowerR:IsA("BasePart"))
		or not (handR and handR:IsA("BasePart"))
	then
		return nil
	end
	local pole = Instance.new("Attachment")
	pole.Name = "GGLeftPole"
	pole.Position = GRIP.leftPole
	pole.Parent = torso
	-- IK targets are read against the animated (pre-IK) pose, so the left
	-- hand's target lives on the chest and is placed where the gun will be
	-- this frame, kick included (a target on the gun would miss the kick).
	local leftTarget = Instance.new("Attachment")
	leftTarget.Name = "GGLeftHold"
	leftTarget.Parent = torso
	local left = Instance.new("IKControl")
	left.Name = "GGLeftGrip"
	left.Type = Enum.IKControlType.Transform
	left.ChainRoot = upperL
	left.EndEffector = handL
	left.Target = leftTarget
	left.Pole = pole
	left.Weight = 0
	left.Enabled = false -- (an enabled IKControl bends the arm even at Weight 0)
	left.Priority = 1
	left.SmoothTime = 0 -- follow the gun exactly (the default 0.05 s lags it)
	left.Parent = humanoid
	local rightTarget = Instance.new("Attachment")
	rightTarget.Name = "GGRightKick"
	rightTarget.Parent = torso
	local right = Instance.new("IKControl")
	right.Name = "GGRightKick"
	right.Type = Enum.IKControlType.Transform
	right.ChainRoot = upperR -- (rooted at the forearm only the wrist turns)
	right.EndEffector = handR
	right.Target = rightTarget
	right.Weight = 0
	right.Enabled = false
	right.Priority = 2 -- before the left hand, which follows the gun
	right.SmoothTime = 0
	right.Parent = humanoid
	local rig: Rig = {
		character = character,
		humanoid = humanoid,
		left = left,
		leftTarget = leftTarget,
		leftPole = pole,
		right = right,
		rightTarget = rightTarget,
		rightRest = nil,
		gun = nil,
		handle = nil,
		probe = nil,
		grip = nil,
		class = "",
		reach = armLength(character) * GRIP.reachFraction,
		weight = 0,
		kickAt = -math.huge,
		kick = Animations.FIRE_KICK.Rifle,
		kickForward = Vector3.new(0, 0, -1),
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
		rig.right:Destroy()
		rig.leftTarget:Destroy()
		rig.leftPole:Destroy()
		rig.rightTarget:Destroy()
		rigs[character] = nil
	end
end

local function watch(character: Model)
	if rigs[character] or character == Players.LocalPlayer.Character then
		return
	end
	local rig = newRig(character)
	if rig then
		rigs[character] = rig
	end
end

local function scan()
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer and player.Character then
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

-- The held gun (rebuilt by WeaponService on every swap).
local function refreshGun(rig: Rig)
	local gun = rig.character:FindFirstChild("WorldWeapon")
	if gun == rig.gun then
		return
	end
	rig.gun = if gun and gun:IsA("Model") then gun else nil
	rig.handle = nil
	rig.probe = nil
	rig.grip = nil
	rig.rightRest = nil
	rig.kickAt = -math.huge
	if not rig.gun then
		return
	end
	local handle = (rig.gun :: Model).PrimaryPart
	local grip = (rig.gun :: Model):FindFirstChild("LeftGrip", true)
	local id = (rig.gun :: Model):GetAttribute("WeaponId")
	local config = if typeof(id) == "string" then Weapons.get(id) else nil
	rig.class = if config then config.class else ""
	rig.kick = Animations.FIRE_KICK[rig.class] or Animations.FIRE_KICK.Rifle
	-- Akimbo holds a gun in each hand; the knife has no grip.
	local akimbo = rig.character:FindFirstChild("WorldWeaponLeft") ~= nil
	if handle and grip and grip:IsA("Attachment") and not akimbo then
		rig.handle = handle
		rig.grip = grip
	end
	local muzzle = (rig.gun :: Model):FindFirstChild("Muzzle", true)
	if handle and muzzle and muzzle:IsA("Attachment") then
		local toMuzzle = handle.CFrame:PointToObjectSpace(muzzle.WorldPosition)
		rig.kickForward = if toMuzzle.Magnitude > 0.05 then toMuzzle.Unit else Vector3.new(0, 0, -1)
	end
end

-- Whether the left hand belongs on the gun right now.
local function wantsGrip(rig: Rig): boolean
	if not rig.grip or not Health.isAlive(rig.humanoid) then
		return false
	end
	local src = attributeSource(rig.character)
	local held = src:GetAttribute("ModHeld")
	if typeof(held) == "number" and held ~= 0 then
		return false
	end
	-- The reload clip takes the left hand to the mag.
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

-- Where the left hand goes: the grip (cupping the grip hand on a sidearm),
-- slid back along the barrel until the left shoulder can reach it.
local function placeLeftTarget(rig: Rig, torso: BasePart, h: CFrame)
	local handle = rig.handle :: BasePart
	local grip = (rig.grip :: Attachment).WorldPosition
	local gripAt = h:PointToWorldSpace(handle.CFrame:PointToObjectSpace(grip))
	local shoulder = rig.character:FindFirstChild("LeftUpperArm")
	local shoulderAtt = shoulder and shoulder:FindFirstChild("LeftShoulderRigAttachment")
	local style = if rig.class == "Sidearm" then GRIP.sidearm else GRIP.long
	local base = gripAt - h.UpVector * style.under + h.RightVector * style.side
	local target = base
	if shoulderAtt and shoulderAtt:IsA("Attachment") then
		local from = shoulderAtt.WorldPosition
		local reach = rig.reach
		local excess = (target - from).Magnitude - reach
		if excess > 0 then
			-- Solve |base - fwd * t - from| = reach for the smallest t >= 0.
			local fwd = h.LookVector
			local rel = base - from
			local b = rel:Dot(fwd)
			local c = rel:Dot(rel) - reach * reach
			local disc = b * b - c
			local t = if disc >= 0 then b - math.sqrt(disc) else b
			target = base - fwd * math.clamp(t, 0, GRIP.maxSlide)
		end
	end
	local world = CFrame.fromMatrix(target, h.LookVector:Cross(h.UpVector), h.UpVector)
		* CFrame.Angles(0, 0, math.rad(style.palm))
	rig.leftTarget.CFrame = torso.CFrame:ToObjectSpace(world)
end

local function kickAmount(rig: Rig, now: number): number
	local t = now - rig.kickAt
	if t < 0 then
		return 0
	end
	local rise = Animations.FIRE_KICK_RISE
	if t < rise then
		local u = t / rise
		return 1 - (1 - u) * (1 - u) -- fast out
	end
	return math.exp(-rig.kick.recover * (t - rise))
end

local function stepRig(rig: Rig, dt: number, now: number, camPos: Vector3)
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

	-- The kick: the right hand pulled back along the barrel and the muzzle
	-- flipped up, in UpperTorso space so the body's pose still carries it.
	local upper = rig.character:FindFirstChild("UpperTorso")
	local hand = rig.character:FindFirstChild("RightHand")
	local handle = rig.handle
	if
		not (upper and upper:IsA("BasePart"))
		or not (hand and hand:IsA("BasePart"))
		or not handle
	then
		rig.left.Enabled = false
		rig.right.Enabled = false
		return
	end
	local k = if far then 0 else kickAmount(rig, now)
	local handNow = hand.CFrame
	if k < 0.01 then
		rig.right.Enabled = false
		rig.rightRest = nil
	else
		if not rig.rightRest then
			rig.rightRest = upper.CFrame:ToObjectSpace(hand.CFrame)
		end
		local rest = upper.CFrame * (rig.rightRest :: CFrame)
		local back = handle.CFrame:VectorToWorldSpace(-rig.kickForward) * rig.kick.back * k
		local axis = handle.CFrame:VectorToWorldSpace(rig.kickForward):Cross(Vector3.yAxis)
		local flip = if axis.Magnitude > 1e-3
			then CFrame.fromAxisAngle(axis.Unit, math.rad(rig.kick.rise) * k)
			else CFrame.identity
		handNow = CFrame.new(rest.Position + back) * flip * rest.Rotation
		rig.rightTarget.CFrame = upper.CFrame:ToObjectSpace(handNow)
		rig.right.Weight = 1
		-- (Enabled only once the target is placed, so the first frame can't
		-- reach for the attachment's old spot.)
		rig.right.Enabled = true
	end

	-- The left hand follows the gun where the right hand puts it this frame.
	if rig.weight > 0 then
		placeLeftTarget(rig, upper, handNow * hand.CFrame:ToObjectSpace(handle.CFrame))
	end
	rig.left.Weight = rig.weight
	rig.left.Enabled = rig.weight > 0
end

local function onShotFx(shooter: unknown, weaponId: unknown)
	if typeof(shooter) ~= "Instance" or typeof(weaponId) ~= "string" then
		return
	end
	local character: Instance? = if shooter:IsA("Player") then shooter.Character else shooter
	local rig = if character and character:IsA("Model") then rigs[character] else nil
	if not rig then
		return
	end
	local config = Weapons.get(weaponId)
	if not config or config.fireMode == "Melee" then
		return
	end
	rig.kickAt = os.clock()
end

function GripController.start()
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
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
		local now = os.clock()
		local camPos = cam.CFrame.Position
		for _, rig in rigs do
			stepRig(rig, dt, now, camPos)
		end
	end)
end

return GripController
