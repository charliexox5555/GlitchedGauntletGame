--!strict
-- Third-person IK hands, the RIVALS way: a prototype behind Config/TpIk
-- (OFF by default; how to flip it is at the top of that file).
--
-- RIVALS (vault/03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md):
-- other players' guns sit at the head, turned by the replicated aim, and the
-- avatar's hands reach them by IKControls; the waist and neck take 0.25 /
-- 0.75 of the aim pitch through the joints' attachments.
--
-- Here, on our block body, for every watched character holding a gun:
--   * the gun's handle is placed from the aim: the head's position, the
--     body's yaw, the aim pitch swung about the right shoulder, hip and
--     sights blended (Config/TpIk offsets, measured from the hold clips);
--   * the right hand goes onto the gun by an IKControl (Transform, pole
--     down and out). GripController's IK keeps the left hand on the gun:
--     its target rides the right hand, which now sits on the gun;
--   * the waist and neck pitch with the aim, written to the joints'
--     Attachment0 (a Transform write doesn't stick on these
--     AnimationConstraint joints, Third Person Overhaul §22).
-- Nothing switches: one weight per character blends the gun between the
-- hand (the clip) and the aim place, and the right IK with it, so a reload,
-- slide, sprint, Mod or swap fades the clip back in instead of popping.
-- The fire kick still moves the gun in the WeaponGrip's C1
-- (EffectsController), between two hands that hold still.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Health = require(ReplicatedStorage.Shared.Health)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local TpIk = require(ReplicatedStorage.Shared.Config.TpIk)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local TpIkController = {}

local GRIP = Animations.GRIP
local SCAN = 0.5

type Joint = {
	attachment: Attachment,
	origin: CFrame,
}

type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	shoulder: Attachment?, -- UpperTorso's RightShoulderRigAttachment: where the gun swings
	torso: BasePart,
	hand: BasePart,
	ik: IKControl,
	pole: Attachment,
	target: Attachment,
	waist: Joint?,
	neck: Joint?,
	-- The right arm's joint limits (the engine's BallSocketConstraints): off
	-- while the IK holds the arm, or the wrist's 10-degree twist limit kept
	-- the fist 67 degrees off the grip (measured, 2026-11-20). RIVALS does
	-- the same (Arms: the sockets switch with the IK).
	sockets: { [BallSocketConstraint]: boolean },
	socketsOff: boolean,
	gun: Model?,
	motor: Motor6D?,
	rest: CFrame, -- the WeaponGrip's C0 as the server made it (hand -> handle)
	gunAt: number, -- os.clock() when this gun appeared
	pistol: boolean,
	moved: boolean, -- the motor hangs off the root (not the hand) right now
	progress: number, -- 0..1, linear; the weight is its smoothstep
	pitch: number,
	ads: number,
}

local rigs: { [Model]: Rig } = {}
local active = false
-- 0..1, the whole mode's share (linear; eased where used): switching the
-- mode fades every rig and the waist / neck pitch instead of snapping.
local mode = 0

local function enabled(): boolean
	if RunService:IsStudio() then
		local dev = Workspace:GetAttribute(TpIk.DEV_ATTRIBUTE)
		if typeof(dev) == "boolean" then
			return dev
		end
	end
	return TpIk.ENABLED
end

local function holderOf(character: Model): Instance
	return Players:GetPlayerFromCharacter(character) or character
end

local function ownToo(): boolean
	return RunService:IsStudio() and StateValues.get(Workspace, "DevThirdPerson") == true
end

-- A joint's parent-side attachment (AnimationConstraint) and its rest CFrame.
local function jointOf(part: Instance?, name: string): Joint?
	local joint = part and part:FindFirstChild(name)
	if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		return {
			attachment = joint.Attachment0 :: Attachment,
			origin = (joint.Attachment0 :: Attachment).CFrame,
		}
	end
	return nil
end

local function restoreJoint(joint: Joint?)
	if joint and joint.attachment.Parent then
		joint.attachment.CFrame = joint.origin
	end
end

local function part(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function newRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root, head = part(character, "HumanoidRootPart"), part(character, "Head")
	local torso, upper, hand =
		part(character, "UpperTorso"),
		part(character, "RightUpperArm"),
		part(character, "RightHand")
	if not (humanoid and root and head and torso and upper and hand) then
		return nil
	end
	local pole = Instance.new("Attachment")
	pole.Name = "GGTpIkPole"
	pole.Position = TpIk.RIGHT_POLE
	pole.Parent = torso
	local target = Instance.new("Attachment")
	target.Name = "GGTpIkTarget"
	target.Parent = root
	local ik = Instance.new("IKControl")
	ik.Name = "GGTpIkRight"
	ik.Type = Enum.IKControlType.Transform
	ik.ChainRoot = upper
	ik.EndEffector = hand
	ik.Target = target
	ik.Pole = pole
	ik.SmoothTime = 0 -- on the gun exactly, every frame (RIVALS uses 0 too)
	ik.Priority = -1 -- before GripController's left hand, whose target rides this hand
	ik.Weight = 0
	ik.Enabled = false
	ik.Parent = humanoid
	local rig: Rig = {
		character = character,
		humanoid = humanoid,
		root = root,
		head = head,
		shoulder = (function(): Attachment?
			local a = torso:FindFirstChild("RightShoulderRigAttachment")
			return if a and a:IsA("Attachment") then a else nil
		end)(),
		torso = torso,
		hand = hand,
		ik = ik,
		pole = pole,
		target = target,
		waist = jointOf(torso, "Waist"),
		neck = jointOf(head, "Neck"),
		sockets = {},
		socketsOff = false,
		gun = nil,
		motor = nil,
		rest = CFrame.identity,
		gunAt = 0,
		pistol = false,
		moved = false,
		progress = 0,
		pitch = 0,
		ads = 0,
	}
	for _, name in { "RightShoulderBallSocket", "RightElbowBallSocket", "RightWristBallSocket" } do
		local socket = character:FindFirstChild(name, true)
		if socket and socket:IsA("BallSocketConstraint") then
			rig.sockets[socket] = socket.Enabled
		end
	end
	return rig
end

local function setSockets(rig: Rig, off: boolean)
	if rig.socketsOff == off then
		return
	end
	rig.socketsOff = off
	for socket, was in rig.sockets do
		if socket.Parent then
			socket.Enabled = if off then false else was
		end
	end
end

-- Puts the gun back in the hand, exactly as the server made it.
local function handBack(rig: Rig)
	local motor = rig.motor
	if motor and rig.moved and motor.Parent then
		motor.Part0 = rig.hand
		motor.C0 = rig.rest
	end
	rig.moved = false
end

local function dropRig(character: Model)
	local rig = rigs[character]
	if not rig then
		return
	end
	handBack(rig)
	setSockets(rig, false)
	restoreJoint(rig.waist)
	restoreJoint(rig.neck)
	rig.ik:Destroy()
	rig.pole:Destroy()
	rig.target:Destroy()
	rigs[character] = nil
end

local function watch(character: Model)
	if rigs[character] or (character == Players.LocalPlayer.Character and not ownToo()) then
		return
	end
	local rig = newRig(character)
	if rig then
		rigs[character] = rig
		character.Destroying:Once(function()
			rigs[character] = nil
		end)
	end
end

local function scan()
	if not active then
		return
	end
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

local function refreshGun(rig: Rig)
	local gun = rig.character:FindFirstChild("WorldWeapon")
	local model = if gun and gun:IsA("Model") then gun else nil
	if model == rig.gun then
		return
	end
	handBack(rig)
	rig.gun = model
	rig.motor = nil
	rig.progress = 0
	rig.gunAt = os.clock()
	if not model then
		return
	end
	local motor = model:FindFirstChild("WeaponGrip", true)
	if motor and motor:IsA("Motor6D") and motor.Part0 == rig.hand then
		rig.motor = motor
		rig.rest = motor.C0
	end
	local id = StateValues.get(model, "WeaponId")
	local config = if typeof(id) == "string" then Weapons.get(id) else nil
	rig.pistol = config ~= nil and config.class == "Sidearm"
end

-- Whether the hold (and so the IK) should own the arms now.
local function wants(rig: Rig, holder: Instance): boolean
	if not rig.motor or not Health.isAlive(rig.humanoid) then
		return false
	end
	-- A new gun: leave its grip alone for a moment, so GripController reads
	-- the server's hand -> handle C0 first (it keeps that as the gun's rest).
	if os.clock() - rig.gunAt < TpIk.NEW_GUN_WAIT then
		return false
	end
	if rig.character:FindFirstChild("WorldWeaponLeft") then
		return false -- Akimbo: two guns, the clips hold them
	end
	-- The held gun's own id: a bot's owner lives on the server, so its
	-- WeaponId never reaches clients (BotService mirrors only some states).
	local gun = rig.gun
	local weaponId = if gun then StateValues.get(gun, "WeaponId") else nil
	if typeof(weaponId) ~= "string" then
		weaponId = StateValues.get(holder, "WeaponId")
	end
	local config = if typeof(weaponId) == "string" then Weapons.get(weaponId) else nil
	if not config or config.fireMode == "Melee" then
		return false
	end
	local state = StateValues.get(rig.character, "MoveState")
	if state == "Slide" or state == "Sprint" then
		return false
	end
	local held = StateValues.get(holder, "ModHeld")
	if typeof(held) == "number" and held ~= 0 then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	local reloadAt, reloadFor =
		StateValues.get(holder, "ReloadAt"), StateValues.get(holder, "ReloadFor")
	if typeof(reloadAt) == "number" and typeof(reloadFor) == "number" then
		local since = now - reloadAt
		if since >= 0 and since < reloadFor + GRIP.regrip then
			return false
		end
	end
	local useAt = StateValues.get(holder, "ModUseAt")
	if typeof(useAt) == "number" then
		local since = now - useAt
		if since >= 0 and since < GRIP.afterModUse then
			return false
		end
	end
	return true
end

-- The gun's handle where the aim puts it (world), before any fire kick.
local function aimPlace(rig: Rig): CFrame
	local look = rig.root.CFrame.LookVector
	local yaw = CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
	local hip = if rig.pistol then TpIk.PISTOL_HIP else TpIk.LONG_HIP
	local sights = if rig.pistol then TpIk.PISTOL_ADS else TpIk.LONG_ADS
	local offset = hip:Lerp(sights, rig.ads)
	local pitch = CFrame.Angles(math.clamp(rig.pitch, -TpIk.PITCH_MAX, TpIk.PITCH_MAX), 0, 0)
	-- Swung about the real right shoulder joint, which the waist pitch moves
	-- too, so the stock stays in the shoulder (round 2: anchored at the head,
	-- the head and the gun's pivot drifted apart as the neck pitched).
	local shoulder = rig.shoulder
	if shoulder and shoulder.Parent then
		return CFrame.new(shoulder.WorldPosition) * yaw * pitch * CFrame.new(offset)
	end
	local fallback = if rig.pistol then TpIk.PISTOL_HIP_HEAD else TpIk.LONG_HIP_HEAD
	return CFrame.new(rig.head.Position) * yaw * pitch * CFrame.new(fallback)
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Turns a joint's parent-side attachment about a world axis (pitch), and
-- optionally about a second one (the head's roll onto the stock at sights).
local function pitchJoint(
	joint: Joint?,
	frame: BasePart,
	axisWorld: Vector3,
	angle: number,
	rollWorld: Vector3?,
	roll: number
)
	if not joint or not joint.attachment.Parent then
		return
	end
	if math.abs(angle) < 1e-4 and math.abs(roll) < 1e-4 then
		joint.attachment.CFrame = joint.origin
		return
	end
	local turn = CFrame.fromAxisAngle(frame.CFrame:VectorToObjectSpace(axisWorld), angle)
	if rollWorld and math.abs(roll) >= 1e-4 then
		turn = CFrame.fromAxisAngle(frame.CFrame:VectorToObjectSpace(rollWorld), roll) * turn
	end
	local o = joint.origin
	joint.attachment.CFrame = CFrame.new(o.Position) * turn * o.Rotation
end

local function stepRig(rig: Rig, dt: number, on: boolean)
	refreshGun(rig)
	local holder = holderOf(rig.character)
	local _, lookPitch = Fighters.lookOf(holder, rig.character)
	rig.pitch += (lookPitch - rig.pitch) * (1 - math.exp(-TpIk.PITCH_SMOOTHING * dt))
	local adsTarget = if StateValues.get(holder, "Aiming") == true then 1 else 0
	rig.ads += (adsTarget - rig.ads) * (1 - math.exp(-TpIk.ADS_SMOOTHING * dt))

	local want = on and wants(rig, holder)
	local fade = if want then TpIk.FADE_IN else TpIk.FADE_OUT
	rig.progress = math.clamp(rig.progress + (if want then dt else -dt) / fade, 0, 1)
	local w = smooth(rig.progress)

	-- Waist and neck take the aim pitch (always, like RIVALS' Joints): Poses
	-- holds the level clip while this mode is on.
	local right = rig.root.CFrame.RightVector
	local lower = rig.character:FindFirstChild("LowerTorso")
	local share = smooth(mode)
	if lower and lower:IsA("BasePart") then
		pitchJoint(rig.waist, lower, right, rig.pitch * TpIk.WAIST_SHARE * share, nil, 0)
	end
	pitchJoint(
		rig.neck,
		rig.torso,
		right,
		rig.pitch * TpIk.NECK_SHARE * share,
		rig.root.CFrame.LookVector,
		math.rad(TpIk.NECK_ADS_ROLL) * rig.ads * share
	)

	local motor = rig.motor
	if not motor or not motor.Parent or w <= 0 then
		handBack(rig)
		setSockets(rig, false)
		rig.ik.Weight = 0
		rig.ik.Enabled = false
		return
	end
	-- The gun between the hand (last frame's) and the aim place: at w = 1 it
	-- is all aim (no feedback), at 0 all hand, in between it settles at once.
	local inHand = rig.hand.CFrame * rig.rest
	local place = inHand:Lerp(aimPlace(rig), w)
	if (place.Position - rig.root.Position).Magnitude > TpIk.MAX_GUN_DISTANCE then
		handBack(rig)
		setSockets(rig, false)
		rig.ik.Weight = 0
		rig.ik.Enabled = false
		return
	end
	motor.Part0 = rig.root
	motor.C0 = rig.root.CFrame:ToObjectSpace(place)
	rig.moved = true
	rig.target.WorldCFrame = place * rig.rest:Inverse()
	setSockets(rig, true)
	rig.ik.Weight = w
	rig.ik.Enabled = true
end

local function stopAll()
	for character in rigs do
		dropRig(character)
	end
end

function TpIkController.start()
	task.spawn(function()
		while true do
			scan()
			task.wait(SCAN)
		end
	end)
	-- Before the Animator and the IK solve, so the target is this frame's.
	RunService.PreAnimation:Connect(function(dt: number)
		local on = enabled()
		if on then
			active = true
		end
		if not active then
			return
		end
		mode = math.clamp(mode + (if on then dt else -dt) / TpIk.FADE_IN, 0, 1)
		local busy = false
		for character, rig in rigs do
			if character.Parent and rig.root.Parent and rig.hand.Parent then
				stepRig(rig, dt, on)
				busy = busy or rig.progress > 0
			end
		end
		-- Switched off and every rig has faded back to its clips: let go.
		if not on and mode <= 0 and not busy then
			active = false
			stopAll()
		end
	end)
end

return TpIkController
