--!strict
-- First-person viewmodel (Gunplay.md §6), RIVALS style:
--  * a scaled copy of the equipped gun in front of the camera, playing its own
--    Blender Fire/Reload clips on its Motor6D rig (GunAnimator);
--  * blocky arms dressed as the player (skin colour + classic Shirt template on
--    the sleeves), solved with two-bone IK onto the gun's RightGrip/LeftGrip
--    every frame, with the hands following the mag/pump/bolt during clips;
--  * keyframed tracks (equip, inspect, reload body motion) and blended poses
--    (sprint, slide, crouch, air) from Config/Viewmodel, plus speed-driven bob,
--    turn sway and recoil springs.
-- Guns with two models (Dual Boot) hold one in each hand, the left one mirrored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local Types = require(ReplicatedStorage.Shared.Types)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)
local MovementController = require(script.Parent.MovementController)

type WeaponConfig = Types.WeaponConfig

export type Side = "Right" | "Left"

local ViewmodelController = {}

local player = Players.LocalPlayer

-- A hand target that rides on a rig joint: `offset` is in that joint's space.
type Anchor = { part: BasePart, offset: Vector3 }

-- While clip `clip` plays, `hand` moves to `anchor` during [from, to] (0..1).
type FollowRule = { clip: string, hand: Side, anchor: Anchor, from: number, to: number }

-- One held model. A normal gun has only `Right`; Dual Boot has both.
type Gun = {
	model: Model,
	handle: BasePart,
	animator: GunAnimator.GunAnimator,
	rightGrip: Anchor?,
	leftGrip: Anchor?,
	muzzle: Attachment?,
	aimRel: Vector3, -- sight position relative to the grip, at rest (ADS alignment)
	centerRel: Vector3, -- middle of the gun relative to the grip (inspect pivot)
	follow: { FollowRule },
	adsHide: { BasePart },
	adsDim: { BasePart },
	reticle: SurfaceGui?,
	recoil: Spring.Spring,
}

type Arm = { upper: Part, lower: Part, hand: Part }

type Playing = { track: VM.Track, time: number, length: number, weight: number, fading: boolean }

local guns: { [Side]: Gun } = {}
local config: WeaponConfig? = nil
local arms: { [Side]: Arm } = {}
local armsModel: Model? = nil
local armsLook = "" -- shirt + colours the arms were built with
local nextLookCheck = 0

local playing: { [string]: Playing } = {}
local poseWeights: { [string]: { x: number, v: number } } = {}

local adsAlpha = 0
local hidden = false
local bobPhase = 0
local bobAmount = { x = 0, v = 0 }
local lastCamera: CFrame? = nil
local lastState = "Idle"
local lastVelocity = Vector3.zero

local sway = Spring.new(VM.SWAY_STIFFNESS, VM.SWAY_DAMPING)
local move = Spring.new(VM.SWAY_STIFFNESS * 0.6, VM.SWAY_DAMPING * 0.8)

local DEG = math.pi / 180

-- Small helpers ----------------------------------------------------------------

local function ease(t: number): number
	-- Blend between linear and smoothstep.
	local s = t * t * (3 - 2 * t)
	return t + (s - t) * VM.ADS_EASE
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Critically damped scalar spring toward `target`.
local function approach(
	s: { x: number, v: number },
	target: number,
	stiffness: number,
	dt: number
): number
	local damping = 2 * math.sqrt(stiffness)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		s.v += ((target - s.x) * stiffness - s.v * damping) * h
		s.x += s.v * h
	end
	return s.x
end

local function angles(rot: Vector3): CFrame
	return CFrame.Angles(rot.X * DEG, rot.Y * DEG, rot.Z * DEG)
end

-- Reflects a camera-space offset across the screen's vertical axis (left gun).
local function mirrorPos(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

local function mirrorRot(v: Vector3): Vector3
	return Vector3.new(v.X, -v.Y, -v.Z)
end

local function aroundPivot(pivot: Vector3, cf: CFrame): CFrame
	return CFrame.new(pivot) * cf * CFrame.new(-pivot)
end

-- Keyframed tracks -----------------------------------------------------------

local function sample(track: VM.Track, t: number): (Vector3, Vector3)
	local keys = track.keys
	local prev = keys[1]
	if t <= prev.t then
		return prev.pos, prev.rot
	end
	for i = 2, #keys do
		local k = keys[i]
		if t <= k.t then
			local span = k.t - prev.t
			local a = if span > 0 then (t - prev.t) / span else 1
			a = TweenService:GetValue(
				a,
				k.style or Enum.EasingStyle.Sine,
				k.dir or Enum.EasingDirection.InOut
			)
			return prev.pos:Lerp(k.pos, a), prev.rot:Lerp(k.rot, a)
		end
		prev = k
	end
	return prev.pos, prev.rot
end

local function playTrack(slot: string, trackName: string, duration: number?)
	local track = VM.TRACKS[trackName]
	if not track then
		return
	end
	playing[slot] = {
		track = track,
		time = 0,
		length = if duration and duration > 0 then duration else track.length,
		weight = 1,
		fading = false,
	}
end

local function fadeTrack(slot: string)
	local p = playing[slot]
	if p then
		p.fading = true
	end
end

local function stepTracks(dt: number)
	for slot, p in playing do
		p.time += dt
		if p.fading then
			p.weight -= dt / VM.CANCEL_TIME
			if p.weight <= 0 then
				playing[slot] = nil
			end
		elseif p.time >= p.length then
			playing[slot] = nil
		end
	end
end

-- The combined track offset for one gun, around its pivots.
local function trackOffset(gun: Gun, mirror: boolean): CFrame
	local cf = CFrame.identity
	for _, p in playing do
		local pos, rot = sample(p.track, math.clamp(p.time / p.length, 0, 1))
		local w = smoothstep(p.weight)
		if mirror then
			pos, rot = mirrorPos(pos), mirrorRot(rot)
		end
		local pivot = if p.track.pivot == "Center" then gun.centerRel else Vector3.zero
		cf *= aroundPivot(pivot, CFrame.new(pos * w) * angles(rot * w))
	end
	return cf
end

-- Arms -------------------------------------------------------------------------

local SHIRT_FACES: { [string]: Enum.NormalId } = {
	F = Enum.NormalId.Front,
	B = Enum.NormalId.Back,
	R = Enum.NormalId.Right,
	L = Enum.NormalId.Left,
	U = Enum.NormalId.Top,
	D = Enum.NormalId.Bottom,
}

-- Colour of one arm segment: the avatar's own body part, else BodyColors.
local function segmentColor(character: Model?, side: Side, segment: string): Color3
	if character then
		local r15 = character:FindFirstChild(side .. segment)
		if r15 and r15:IsA("BasePart") then
			return r15.Color
		end
		local r6 = character:FindFirstChild(side .. " Arm")
		if r6 and r6:IsA("BasePart") then
			return r6.Color
		end
		local colors = character:FindFirstChildOfClass("BodyColors")
		if colors then
			return if side == "Right" then colors.RightArmColor3 else colors.LeftArmColor3
		end
	end
	return Color3.fromRGB(234, 184, 146)
end

local function shirtTemplate(character: Model?): string
	local shirt = character and character:FindFirstChildOfClass("Shirt")
	return if shirt then shirt.ShirtTemplate else ""
end

local function lookSignature(): string
	local character = player.Character
	local parts = { shirtTemplate(character) }
	for _, side in { "Right", "Left" } do
		for _, segment in { "UpperArm", "LowerArm", "Hand" } do
			table.insert(parts, segmentColor(character, side :: Side, segment):ToHex())
		end
	end
	return table.concat(parts, "|")
end

-- Puts the shirt template's arm faces on a segment covering the arm's height
-- from `a` to `b` (0 = shoulder, 1 = hand), like Roblox does on blocky arms.
-- Each face is a Decal cropped to its template region with UVScale/UVOffset.
local function dress(part: Part, side: Side, template: string, a: number, b: number)
	local faces = VM.SHIRT_FACES[side]
	local image = VM.SHIRT_SIZE
	for faceKey, normal in SHIRT_FACES do
		local origin = faces[faceKey]
		local y0, h = origin.Y + a * 128, (b - a) * 128
		if faceKey == "U" or faceKey == "D" then
			if (faceKey == "U" and a > 0) or (faceKey == "D" and b < 1) then
				continue
			end
			y0, h = origin.Y, 64
		end
		local decal = Instance.new("Decal")
		decal.Face = normal
		decal.Texture = template
		decal.UVScale = Vector2.new(64 / image.X, h / image.Y)
		decal.UVOffset = Vector2.new(origin.X / image.X, y0 / image.Y)
		decal.Parent = part
	end
end

local function armPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Size = size
	p.Parent = parent
	return p
end

local function buildArms()
	if armsModel then
		armsModel:Destroy()
	end
	local character = player.Character
	local template = shirtTemplate(character)
	local model = Instance.new("Model")
	model.Name = "ViewmodelArms"
	local w = VM.ARM_WIDTH
	local split = VM.ARM_SPLIT
	arms = {}
	for _, side: Side in { "Right", "Left" } :: { Side } do
		local upper = armPart(
			side .. "UpperArm",
			Vector3.new(w, VM.UPPER_LENGTH + VM.ELBOW_OVERLAP, w),
			segmentColor(character, side, "UpperArm"),
			model
		)
		local lower = armPart(
			side .. "LowerArm",
			Vector3.new(w * 0.96, VM.LOWER_LENGTH, w * 0.96),
			segmentColor(character, side, "LowerArm"),
			model
		)
		local hand = armPart(
			side .. "Hand",
			Vector3.new(w, VM.HAND_LENGTH, w),
			segmentColor(character, side, "Hand"),
			model
		)
		if template ~= "" then
			dress(upper, side, template, 0, split[1])
			dress(lower, side, template, split[1], split[2])
			dress(hand, side, template, split[2], 1)
		end
		arms[side] = { upper = upper, lower = lower, hand = hand }
	end
	armsModel = model
	armsLook = lookSignature()
end

local function setArmsVisible(visible: boolean)
	local m = if visible then 0 else 1
	for _, d in if armsModel then armsModel:GetDescendants() else {} do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = m
		end
	end
end

-- A block running from `from` (toward the shoulder) to `to`, its X axis on the
-- elbow's hinge so the shirt's front faces the way the arm bends.
local function segment(part: Part, from: Vector3, to: Vector3, hinge: Vector3, length: number)
	local y = from - to
	if y.Magnitude < 1e-4 then
		return
	end
	y = y.Unit
	local x = hinge - y * hinge:Dot(y)
	if x.Magnitude < 1e-4 then
		x = y:Cross(Vector3.zAxis)
	end
	x = x.Unit
	local center = from - y * (length / 2)
	part.CFrame = CFrame.fromMatrix(center, x, y, x:Cross(y))
end

-- Two-bone IK: shoulder → elbow → wrist, hand centred on `grip`.
local function solveArm(arm: Arm, shoulder: Vector3, grip: Vector3, hint: Vector3)
	local l1, l2 = VM.UPPER_LENGTH, VM.LOWER_LENGTH
	local toGrip = grip - shoulder
	if toGrip.Magnitude < 1e-3 then
		return
	end
	local wrist = grip - toGrip.Unit * (VM.HAND_LENGTH / 2)
	local toWrist = wrist - shoulder
	local d = toWrist.Magnitude
	-- Out of reach: the (off-screen) shoulder slides forward instead of the
	-- hand letting go of the gun.
	local reach = (l1 + l2) * 0.995
	if d > reach then
		shoulder += toWrist.Unit * (d - reach)
		toWrist = wrist - shoulder
		d = reach
	end
	d = math.max(d, math.abs(l1 - l2) + 0.02)
	local dir = toWrist.Unit
	local cosA = math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local pole = hint - dir * hint:Dot(dir)
	if pole.Magnitude < 1e-4 then
		pole = -Vector3.yAxis
	end
	pole = pole.Unit
	local elbow = shoulder + dir * (l1 * cosA) + pole * (l1 * sinA)
	local hinge = pole:Cross(dir)

	local upperLen = l1 + VM.ELBOW_OVERLAP
	segment(arm.upper, shoulder, shoulder + (elbow - shoulder).Unit * upperLen, hinge, upperLen)
	segment(arm.lower, elbow, wrist, hinge, l2)
	local forearm = wrist - elbow
	local handEnd = wrist
		+ (if forearm.Magnitude > 1e-4 then forearm.Unit else dir) * VM.HAND_LENGTH
	segment(arm.hand, wrist, handEnd, hinge, VM.HAND_LENGTH)
end

-- Guns -------------------------------------------------------------------------

local function weaponsFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("Weapons")
end

local function attachment(m: Model, name: string): Attachment?
	local a = m:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

local function rigJoint(m: Model, name: string): BasePart?
	local rig = m:FindFirstChild("Rig")
	local p = rig and rig:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- Grips sitting on the (static) Handle ride on the Rig's Root joint instead,
-- so hands follow the gun's own kick and swing clips.
local function anchorFor(m: Model, handle: BasePart, a: Attachment?): Anchor?
	if not a then
		return nil
	end
	local carrier = a.Parent
	if carrier == handle or not (carrier and carrier:IsA("BasePart")) then
		carrier = rigJoint(m, "Root") or handle
	end
	local part = carrier :: BasePart
	return { part = part, offset = part.CFrame:PointToObjectSpace(a.WorldPosition) }
end

-- The visible parts welded to a rig joint, as a box in that joint's space.
local function jointBounds(m: Model, joint: BasePart): (Vector3?, Vector3?)
	local low, high
	for _, d in m:GetDescendants() do
		if (d:IsA("Weld") or d:IsA("Motor6D")) and d.Part0 == joint then
			local p = d.Part1
			if p and p.Parent ~= joint.Parent and p.Transparency < 1 then
				local half = p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner = joint.CFrame:PointToObjectSpace(
								p.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
							)
							low = if low then low:Min(corner) else corner
							high = if high then high:Max(corner) else corner
						end
					end
				end
			end
		end
	end
	return low, high
end

local function followAnchor(gun: Gun, rule: VM.Follow): Anchor?
	local joint = rigJoint(gun.model, rule.joint)
	if not joint then
		return nil
	end
	if rule.grab == "Grip" then
		local left = gun.leftGrip
		if not left then
			return nil
		end
		local world = left.part.CFrame:PointToWorldSpace(left.offset)
		return { part = joint, offset = joint.CFrame:PointToObjectSpace(world) }
	end
	local low, high = jointBounds(gun.model, joint)
	if not low or not high then
		return { part = joint, offset = Vector3.zero }
	end
	local center = (low + high) / 2
	local offset = if rule.grab == "Bottom" then Vector3.new(center.X, low.Y, center.Z) else center
	return { part = joint, offset = offset }
end

local function addFollow(gun: Gun, clip: string, hand: Side, rule: VM.Follow): boolean
	local from, to = gun.animator:activity(clip, rule.joint)
	if not from or not to then
		return false
	end
	-- One part at a time per hand: skip rules that overlap an earlier one.
	for _, r in gun.follow do
		if r.clip == clip and r.hand == hand and from < r.to and to > r.from then
			return false
		end
	end
	local anchor = followAnchor(gun, rule)
	if not anchor then
		return false
	end
	table.insert(gun.follow, { clip = clip, hand = hand, anchor = anchor, from = from, to = to })
	return true
end

local function buildFollow(gun: Gun, weapon: WeaponConfig, dual: boolean)
	if dual or weapon.fireMode == "Melee" then
		return -- each hand is busy holding its own gun / nothing to work
	end
	for _, rule in VM.RELOAD_FOLLOW do
		addFollow(gun, "Reload", "Left", rule)
	end
	if weapon.fireMode == "Pump" then
		addFollow(gun, "Fire", "Left", VM.PUMP_FOLLOW)
	elseif weapon.fireMode == "Bolt" then
		addFollow(gun, "Fire", "Right", VM.BOLT_FOLLOW)
	end
end

-- 0..1: how much a hand is on a follow rule's part at clip progress `t`.
local function followWeight(rule: FollowRule, t: number): number
	local lead = VM.FOLLOW_LEAD
	local inStart = math.max(0, rule.from - lead)
	local inLength = math.max(rule.from - inStart, lead * 0.5)
	local outEnd = math.min(1, rule.to + lead)
	local outLength = math.max(outEnd - rule.to, lead * 0.5)
	return smoothstep((t - inStart) / inLength) * smoothstep((outEnd - t) / outLength)
end

local function anchorPosition(a: Anchor): Vector3
	return a.part.CFrame:PointToWorldSpace(a.offset)
end

local function handTarget(gun: Gun, hand: Side, base: Vector3): Vector3
	local clip = gun.animator.clipName
	if not clip then
		return base
	end
	local t = gun.animator:progress()
	local pos = base
	for _, rule in gun.follow do
		if rule.clip == clip and rule.hand == hand then
			local w = followWeight(rule, t)
			if w > 0 then
				pos = pos:Lerp(anchorPosition(rule.anchor), w)
			end
		end
	end
	return pos
end

local function sightPart(
	name: string,
	size: Vector3,
	cf: CFrame,
	joint: BasePart,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromHex("14161D")
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = joint
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

-- A holographic sight on top of the gun (for guns whose own sight is a closed
-- box): a tinted glass pane in a thin frame, with a dot-and-ring reticle.
local function buildReticle(m: Model, h: BasePart, r: Types.Reticle, scale: number): SurfaceGui
	local joint = rigJoint(m, "Root") or h
	local size = r.size * scale
	local cf = h.CFrame * CFrame.new(r.center * scale)
	local folder = Instance.new("Folder")
	folder.Name = "HoloSight"
	folder.Parent = m
	if r.frame ~= false then
		local bar = 0.012
		local depth = 0.02
		sightPart(
			"Top",
			Vector3.new(size.X + bar * 2, bar, depth),
			cf * CFrame.new(0, (size.Y + bar) / 2, 0),
			joint,
			folder
		)
		sightPart(
			"Left",
			Vector3.new(bar, size.Y, depth),
			cf * CFrame.new(-(size.X + bar) / 2, 0, 0),
			joint,
			folder
		)
		sightPart(
			"Right",
			Vector3.new(bar, size.Y, depth),
			cf * CFrame.new((size.X + bar) / 2, 0, 0),
			joint,
			folder
		)
		sightPart(
			"Base",
			Vector3.new(size.X + bar * 2, bar * 1.5, depth * 2.5),
			cf * CFrame.new(0, -(size.Y + bar * 1.5) / 2, 0),
			joint,
			folder
		)
	end
	local glass = sightPart("Glass", Vector3.new(size.X, size.Y, 0.004), cf, joint, folder)
	glass.Color = r.color
	glass.Transparency = if r.frame == false then 1 else 0.9
	glass.Material = Enum.Material.Glass

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Reticle"
	gui.Face = Enum.NormalId.Back -- faces the camera (barrel along -Z)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 2000
	gui.Enabled = false
	local function circle(px: number, stroke: boolean): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(px, px)
		f.BackgroundColor3 = r.color
		f.BackgroundTransparency = if stroke then 1 else 0
		f.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		if stroke then
			local s = Instance.new("UIStroke")
			s.Color = r.color
			s.Thickness = 5
			s.Parent = f
		end
		f.Parent = gui
		return f
	end
	local ring = size.Y * 2000 * 0.55
	circle(ring, true)
	circle(ring * 0.12, false)
	gui.Parent = glass
	return gui
end

local function buildGun(templateId: string, name: string, weapon: WeaponConfig, dual: boolean): Gun?
	local folder = weaponsFolder()
	local template = folder and folder:FindFirstChild(templateId)
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("[Viewmodel] no model for " .. templateId)
		return nil
	end
	local m = template:Clone()
	m.Name = name
	local scale = weapon.viewmodelScale or VM.SCALE
	m:ScaleTo(scale)
	local h = m.PrimaryPart :: BasePart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == h
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	local aim = attachment(m, "AimPoint")
	local boxCf = m:GetBoundingBox()
	local reticle = if weapon.adsReticle then buildReticle(m, h, weapon.adsReticle, scale) else nil
	-- Faded while aiming: the gun's adsHide parts, and anything entirely behind
	-- the sight (stocks), which otherwise fills the bottom of the sight picture.
	local hide: { BasePart } = {}
	local dim: { BasePart } = {}
	local aimZ = if aim then h.CFrame:PointToObjectSpace(aim.WorldPosition).Z else math.huge
	local named = weapon.adsHide or {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= h and d.Transparency < 1 then
			local nearZ, farZ = math.huge, -math.huge
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = h.CFrame:PointToObjectSpace(
							d.CFrame:PointToWorldSpace(d.Size / 2 * Vector3.new(sx, sy, sz))
						)
						nearZ = math.min(nearZ, corner.Z)
						farZ = math.max(farZ, corner.Z)
					end
				end
			end
			if table.find(named, d.Name) or nearZ > aimZ + VM.ADS_HIDE_BEHIND then
				table.insert(hide, d)
			elseif d.Material == Enum.Material.Neon and farZ > aimZ then
				table.insert(dim, d) -- glow strips running past the eye glare in ADS
			end
		end
	end
	local gun: Gun = {
		model = m,
		handle = h,
		animator = GunAnimator.new(m, templateId, scale),
		rightGrip = anchorFor(m, h, attachment(m, "RightGrip")),
		leftGrip = anchorFor(m, h, attachment(m, "LeftGrip")),
		muzzle = attachment(m, "Muzzle"),
		aimRel = if weapon.adsReticle
			then weapon.adsReticle.center * scale
			elseif aim then h.CFrame:PointToObjectSpace(aim.WorldPosition)
			else Vector3.new(0, 0.3, 0),
		centerRel = h.CFrame:PointToObjectSpace(boxCf.Position),
		follow = {},
		adsHide = hide,
		adsDim = dim,
		reticle = reticle,
		recoil = Spring.new(VM.RECOIL_STIFFNESS, VM.RECOIL_DAMPING),
	}
	buildFollow(gun, weapon, dual)
	return gun
end

local function setGunsVisible(visible: boolean)
	local modifier = if visible then 0 else 1
	for _, gun in guns do
		for _, d in gun.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = modifier
			end
		end
	end
end

-- API ----------------------------------------------------------------------------

function ViewmodelController.unequip()
	for _, gun in guns do
		gun.model:Destroy()
	end
	guns = {}
	config = nil
	table.clear(playing)
	if armsModel then
		armsModel.Parent = nil
	end
end

function ViewmodelController.equip(weapon: WeaponConfig)
	ViewmodelController.unequip()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local models = weapon.models
	local dual = models ~= nil and models.left ~= nil
	local right = buildGun(if models then models.right else weapon.id, "Viewmodel", weapon, dual)
	if not right then
		return
	end
	guns.Right = right
	if models and models.left then
		guns.Left = buildGun(models.left, "ViewmodelLeft", weapon, dual)
	end
	for _, gun in guns do
		gun.model.Parent = cam
	end

	if not armsModel or armsLook ~= lookSignature() then
		buildArms()
	end
	if armsModel then
		armsModel.Parent = cam
	end

	config = weapon
	hidden = false
	setArmsVisible(true)
	playTrack("Equip", "Equip", math.max(weapon.equipTime * 1.4, VM.TRACKS.Equip.length))
end

-- `side`: which gun fired (Dual Boot alternates); normal guns are "Right".
function ViewmodelController.fire(kickScale: number, side: Side?)
	local gun = guns[side or "Right"] or guns.Right
	if not gun then
		return
	end
	fadeTrack("Inspect")
	gun.animator:play("Fire")
	local up = if config then config.recoil.up else 1
	local k = math.clamp(up, 0.3, 4) * kickScale
	gun.recoil:impulse(
		Vector3.new(
			VM.KICK_BACK * 40 * k,
			VM.KICK_ROTATE * 40 * k,
			(math.random() - 0.5) * VM.KICK_ROTATE * 20 * k
		)
	)
end

function ViewmodelController.reload(duration: number)
	fadeTrack("Inspect")
	for _, gun in guns do
		gun.animator:play("Reload", duration)
	end
	playTrack("Reload", "Reload", duration)
end

function ViewmodelController.cancelReload()
	for _, gun in guns do
		if gun.animator:isPlaying("Reload") then
			gun.animator:stop()
		end
	end
	fadeTrack("Reload")
end

-- Melee swing uses the weapon's Fire clip.
function ViewmodelController.swing()
	fadeTrack("Inspect")
	if guns.Right then
		guns.Right.animator:play("Fire")
	end
end

-- Plays the inspect (Valorant / Phantom Forces style). Returns false when the
-- gun is busy (equipping, reloading, firing a clip, aiming).
function ViewmodelController.inspect(): boolean
	local c = config
	if not c or not guns.Right or hidden or adsAlpha > 0.05 then
		return false
	end
	if playing.Equip or playing.Reload or playing.Inspect then
		return false
	end
	for _, gun in guns do
		if gun.animator:isPlaying() then
			return false
		end
	end
	playTrack("Inspect", if c.fireMode == "Melee" then "InspectMelee" else "Inspect")
	return true
end

function ViewmodelController.cancelInspect()
	fadeTrack("Inspect")
end

function ViewmodelController.isInspecting(): boolean
	local p = playing.Inspect
	return p ~= nil and not p.fading
end

function ViewmodelController.setAds(alpha: number)
	adsAlpha = alpha
	if alpha > 0.05 then
		fadeTrack("Inspect")
	end
end

function ViewmodelController.setHidden(value: boolean)
	if hidden ~= value then
		hidden = value
		setGunsVisible(not value)
		setArmsVisible(not value)
	end
end

function ViewmodelController.muzzleCFrame(side: Side?): CFrame?
	local gun = guns[side or "Right"] or guns.Right
	if gun and gun.muzzle then
		return gun.muzzle.WorldCFrame
	end
	return nil
end

function ViewmodelController.isEquipped(): boolean
	return guns.Right ~= nil
end

-- Per frame ----------------------------------------------------------------------

local function poseOffset(mirror: boolean, weights: { [string]: number }): CFrame
	local cf = CFrame.identity
	for name, pose in VM.POSES do
		local w = weights[name]
		if w and math.abs(w) > 1e-3 then
			local pos, rot = pose.pos, pose.rot
			if mirror then
				pos, rot = mirrorPos(pos), mirrorRot(rot)
			end
			cf *= CFrame.new(pos * w) * angles(rot * w)
		end
	end
	return cf
end

-- How much of each pose (Config/Viewmodel POSES) the movement state asks for.
local function poseTarget(name: string, state: string): number
	if state ~= name then
		return 0
	elseif name == "Sprint" then
		return 1 - adsAlpha
	elseif name == "Slide" then
		return 1 - 0.75 * adsAlpha
	end
	return 1 - 0.8 * adsAlpha
end

local weights: { [string]: number } = {}

local function updatePoseWeights(dt: number, state: string): { [string]: number }
	for name in VM.POSES do
		local s = poseWeights[name]
		if not s then
			s = { x = 0, v = 0 }
			poseWeights[name] = s
		end
		weights[name] = approach(s, poseTarget(name, state), VM.POSE_STIFFNESS, dt)
	end
	return weights
end

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local right = guns.Right
	local c = config
	if not cam or not right or not c then
		lastCamera = cam and cam.CFrame
		return
	end
	dt = math.min(dt, 0.1)
	local camCf = cam.CFrame
	local now = os.clock()

	-- Rebuild the arms if the avatar's shirt or colours changed (appearance
	-- loads in after spawn).
	if now >= nextLookCheck then
		nextLookCheck = now + 1
		if lookSignature() ~= armsLook then
			buildArms()
			if armsModel then
				armsModel.Parent = cam
			end
			setArmsVisible(not hidden)
		end
	end

	local state = MovementController.getState()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local velocity = if root and root:IsA("BasePart")
		then root.AssemblyLinearVelocity
		else Vector3.zero
	local localVel = camCf:VectorToObjectSpace(velocity)
	local adsDamp = 1 - adsAlpha * (1 - VM.ADS_SWAY_SCALE)

	-- Sway from how fast the view turns, plus a roll when strafing.
	if lastCamera then
		local delta = lastCamera:ToObjectSpace(camCf)
		local rx, ry = delta:ToEulerAnglesYXZ()
		local rate = 1 / math.max(dt, 1 / 240)
		local max = VM.SWAY_MAX
		sway.target = Vector3.new(
			math.clamp(-rx * rate * VM.SWAY_AMOUNT, -max, max),
			math.clamp(-ry * rate * VM.SWAY_AMOUNT, -max, max),
			math.clamp(-localVel.X * VM.STRAFE_ROLL, -max, max)
		) * adsDamp
	end
	lastCamera = camCf
	local s = sway:update(dt)

	-- Positional lag: falling/rising, and a dip when landing.
	local airborne = state == "Air"
	if lastState == "Air" and not airborne then
		local fall = math.clamp(-lastVelocity.Y / 50, 0, 1)
		move:impulse(Vector3.new(0, -VM.LAND_KICK * fall, 0))
	end
	lastState = state
	lastVelocity = velocity
	move.target = Vector3.new(0, math.clamp(-velocity.Y * VM.FALL_LAG, -0.08, 0.08), 0) * adsDamp
	local m = move:update(dt)

	-- Bob follows real ground speed so it eases in and out.
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = not airborne and state ~= "Slide"
	local bobTarget = if grounded then math.clamp(flatSpeed / VM.BOB_WALK_SPEED, 0, 1.6) else 0
	local bobW = approach(bobAmount, bobTarget, 60, dt)
	bobPhase += dt * flatSpeed * VM.BOB_FREQUENCY * math.pi
	updatePoseWeights(dt, state)
	local sprintW = math.clamp(weights.Sprint or 0, 0, 1)
	local bobScale = bobW
		* (1 + (VM.SPRINT_BOB_SCALE - 1) * sprintW)
		* (1 - adsAlpha * (1 - VM.ADS_BOB_SCALE))
	local sinP, cos2P = math.sin(bobPhase), math.cos(2 * bobPhase)
	local bobPos = Vector3.new(sinP * VM.BOB_AMOUNT.X, cos2P * VM.BOB_AMOUNT.Y, 0) * bobScale
	local bobRot = Vector3.new(
		cos2P * VM.BOB_ROTATION.X,
		sinP * VM.BOB_ROTATION.Y,
		sinP * VM.BOB_ROTATION.Z
	) * bobScale

	stepTracks(dt)

	-- Shared motion of the whole viewmodel (also carries a free hand).
	local shared = CFrame.new(m + bobPos)
		* angles(bobRot)
		* CFrame.Angles(s.X, s.Y, s.Y * 0.4 + s.Z)

	local adsT = ease(adsAlpha)
	for side, gun in guns do
		local mirror = side == "Left"
		local offset = c.viewmodelOffset
		local hipRot = c.viewmodelRotation or VM.HIP_ROTATION
		if mirror then
			hipRot = mirrorRot(hipRot)
		end
		local hip = CFrame.new(if mirror then mirrorPos(offset) else offset) * angles(hipRot)
		local ads = CFrame.new(c.adsOffset or Vector3.zero)
			* CFrame.new(0, 0, -(c.adsDistance or VM.ADS_DISTANCE))
			* CFrame.new(-gun.aimRel)
		local base = hip:Lerp(ads, adsT)
		local r = gun.recoil:update(dt)
		local recoilCf = CFrame.new(0, 0, r.X * 0.1) * CFrame.Angles(r.Y * 0.1, 0, r.Z * 0.1)
		gun.handle.CFrame = camCf
			* shared
			* base
			* poseOffset(mirror, weights)
			* trackOffset(gun, mirror)
			* recoilCf
		gun.animator:update(dt)

		if gun.reticle then
			gun.reticle.Enabled = adsAlpha > 0.4 and not hidden
		end

		-- Fade parts that block the sight picture while aiming.
		if not hidden then
			local fade = smoothstep((adsAlpha - 0.35) / 0.45)
			for _, p in gun.adsHide do
				p.LocalTransparencyModifier = fade
			end
			for _, p in gun.adsDim do
				p.LocalTransparencyModifier = fade * VM.ADS_NEON_DIM
			end
		end
	end

	-- Arms onto the grips (after the guns and their clips have moved).
	if hidden then
		return
	end
	local rightArm, leftArm = arms.Right, arms.Left
	local hintR = camCf:VectorToWorldSpace(VM.ELBOW_HINT_RIGHT:Lerp(VM.ADS_ELBOW_HINT_RIGHT, adsT))
	local hintL = camCf:VectorToWorldSpace(VM.ELBOW_HINT_LEFT:Lerp(VM.ADS_ELBOW_HINT_LEFT, adsT))
	local spread = VM.ADS_SHOULDER_SPREAD * adsT
	local shoulderR = camCf:PointToWorldSpace(VM.SHOULDER_RIGHT + spread)
	local shoulderL = camCf:PointToWorldSpace(VM.SHOULDER_LEFT + mirrorPos(spread))
	if rightArm and right.rightGrip then
		local grip = handTarget(right, "Right", anchorPosition(right.rightGrip))
		solveArm(rightArm, shoulderR, grip, hintR)
	end
	if leftArm then
		local left = guns.Left
		local grip: Vector3
		if left and left.rightGrip then
			grip = anchorPosition(left.rightGrip) -- Dual Boot: the left gun's grip
		elseif c.fireMode == "Melee" or not right.leftGrip then
			grip = (camCf * shared):PointToWorldSpace(VM.FREE_HAND)
		else
			local leftGrip = right.leftGrip :: Anchor
			local base = anchorPosition(leftGrip)
			local rightGrip = right.rightGrip
			-- Pistols: both grips in one spot, so the support hand cups below.
			if rightGrip and (base - anchorPosition(rightGrip)).Magnitude < 0.12 then
				base = right.handle.CFrame:PointToWorldSpace(
					right.handle.CFrame:PointToObjectSpace(base) + VM.SUPPORT_HAND_OFFSET
				)
			end
			grip = handTarget(right, "Left", base)
		end
		solveArm(leftArm, shoulderL, grip, hintL)
	end
end

function ViewmodelController.start()
	RunService:BindToRenderStep("GGViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
	player.CharacterRemoving:Connect(function()
		ViewmodelController.unequip()
		if armsModel then
			armsModel:Destroy()
			armsModel = nil
			arms = {}
			armsLook = ""
		end
	end)
end

return ViewmodelController
