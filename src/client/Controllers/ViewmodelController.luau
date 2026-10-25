--!strict
-- First-person viewmodel (Gunplay.md §6), RIVALS style:
--  * a scaled copy of the equipped gun in front of the camera, playing its own
--    Blender Fire/Reload clips (GunAnimator). Every part is anchored and posed
--    by hand each frame (Util/ViewmodelRig), so nothing lags the camera;
--  * RIVALS-style arms (Util/ViewmodelArms): one smooth bevelled block per
--    arm in the player's skin colour and shirt, pointing from off-screen into
--    the gun's RightGrip/LeftGrip, hands following the mag/pump/bolt in clips;
--  * keyframed tracks (equip, inspect, reload body motion) and blended poses
--    (sprint, slide, crouch, air) from Config/Viewmodel, plus speed-driven bob,
--    breathing, turn sway, movement lag and recoil springs, all kept (smaller)
--    while aiming so the sights move with you.
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
local ViewmodelArms = require(script.Parent.Parent.Util.ViewmodelArms)
local ViewmodelRig = require(script.Parent.Parent.Util.ViewmodelRig)
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
	rig: ViewmodelRig.ViewmodelRig?,
	animator: GunAnimator.GunAnimator,
	rightGrip: Anchor?,
	leftGrip: Anchor?,
	muzzle: Attachment?,
	pistol: boolean, -- both grips in one spot: a two-handed pistol hold
	aimRel: Vector3, -- sight position relative to the grip, at rest (ADS alignment)
	centerRel: Vector3, -- middle of the gun relative to the grip (inspect pivot)
	follow: { FollowRule },
	adsHide: { BasePart }, -- parts that block the sight line, faded while aiming
	adsFade: number, -- last fade written to adsHide
	reticle: SurfaceGui?,
	recoil: Spring.Spring,
}

type Playing = { track: VM.Track, time: number, length: number, weight: number, fading: boolean }

type Scalar = { x: number, v: number }

local guns: { [Side]: Gun } = {}
local config: WeaponConfig? = nil
local arms: ViewmodelArms.Arms? = nil
local armsLook = "" -- what the arms were built from
local nextLookCheck = 0

local playing: { [string]: Playing } = {}
local poseWeights: { [string]: Scalar } = {}
local weights: { [string]: number } = {}

local adsAlpha = 0
local hidden = false
local bobPhase = 0
local breathPhase = 0
local bobAmount: Scalar = { x = 0, v = 0 }
local lastCamera: CFrame? = nil
local lastState = "Idle"
local smoothVelocity = Vector3.zero

local sway = Spring.new(VM.SWAY_STIFFNESS, VM.SWAY_DAMPING)
local move = Spring.new(VM.MOVE_STIFFNESS, VM.MOVE_DAMPING)

local DEG = math.pi / 180

-- Small helpers ----------------------------------------------------------------

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- ADS blend: smootherstep, so it starts and lands without a jolt.
local function adsEase(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Critically damped scalar spring toward `target`.
local function approach(s: Scalar, target: number, stiffness: number, dt: number): number
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
		if mirror then
			pos, rot = mirrorPos(pos), mirrorRot(rot)
		end
		local pivot = if p.track.pivot == "Center" then gun.centerRel else Vector3.zero
		local full = aroundPivot(pivot, CFrame.new(pos) * angles(rot))
		-- A fading (cancelled) track blends out along the shortest rotation, so
		-- a knife mid-flip doesn't spin back a full turn.
		cf *= if p.weight >= 1 then full else CFrame.new():Lerp(full, smoothstep(p.weight))
	end
	return cf
end

-- Arms -------------------------------------------------------------------------

local function rebuildArms(cam: Camera?)
	if arms then
		arms.model:Destroy()
	end
	local built = ViewmodelArms.build(player.Character)
	arms = built
	armsLook = ViewmodelArms.signature(player.Character)
	if cam and guns.Right then
		built.model.Parent = cam
	end
	ViewmodelArms.setVisible(built, not hidden)
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
	local low: Vector3?, high: Vector3? = nil, nil
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
	-- One part at a time per hand: skip rules whose reach (window widened by
	-- the lead, as followWeight uses it) overlaps an earlier one.
	local lead = VM.FOLLOW_LEAD
	for _, r in gun.follow do
		if
			r.clip == clip
			and r.hand == hand
			and from - lead < r.to + lead
			and to + lead > r.from - lead
		then
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
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromHex("14161D")
	-- Only tells ViewmodelRig which joint it rides on (the rig anchors it).
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
		local bar = 0.024 * scale
		local depth = 0.04 * scale
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

	local pixelsPerStud = 2000
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Reticle"
	gui.Face = Enum.NormalId.Back -- faces the camera (barrel along -Z)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
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
			s.Thickness = 0.012 * scale * pixelsPerStud
			s.Parent = f
		end
		f.Parent = gui
		return f
	end
	local ring = size.Y * pixelsPerStud * 0.55
	circle(ring, true)
	circle(ring * 0.12, false)
	gui.Parent = glass
	return gui
end

-- Parts that really block the sight line: cast from the aiming eye toward
-- the sight and collect whatever sits in between. Sight parts themselves
-- (named "Sight…", or the holo sight) are meant to be on that line.
local function findOccluders(gun: Gun, distance: number, adsOffset: Vector3): { BasePart }
	local found: { BasePart } = {}
	local holo = gun.model:FindFirstChild("HoloSight")
	local candidates: { Instance } = {}
	for _, d in gun.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.CanQuery = true
			table.insert(candidates, d)
		end
	end
	local h = gun.handle.CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local spread = 0.012 -- a few rays around the eye line, not just one
	for _, offset in
		{
			Vector3.zero,
			Vector3.new(spread, 0, 0),
			Vector3.new(-spread, 0, 0),
			Vector3.new(0, spread, 0),
			Vector3.new(0, -spread, 0),
		}
	do
		-- The eye sits `distance` behind the sight, shifted by the gun's adsOffset.
		local eye =
			h:PointToWorldSpace(gun.aimRel - adsOffset + offset + Vector3.new(0, 0, distance))
		local dir = h.LookVector * (distance - 0.02)
		local remaining = table.clone(candidates)
		for _ = 1, 8 do
			params.FilterDescendantsInstances = remaining
			local result = Workspace:Raycast(eye, dir, params)
			if not result then
				break
			end
			local part = result.Instance
			local isSight = string.find(part.Name, "Sight") ~= nil
				or (holo ~= nil and part:IsDescendantOf(holo))
			if not isSight and part:IsA("BasePart") and not table.find(found, part) then
				table.insert(found, part)
			end
			local index = table.find(remaining, part)
			if not index then
				break
			end
			table.remove(remaining, index)
		end
	end
	for _, d in candidates do
		(d :: BasePart).CanQuery = false
	end
	return found
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
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	local aim = attachment(m, "AimPoint")
	local boxCf = m:GetBoundingBox()
	local reticle = if weapon.adsReticle then buildReticle(m, h, weapon.adsReticle, scale) else nil
	local hide: { BasePart } = {}
	for _, partName in weapon.adsHide or {} do
		for _, d in m:GetDescendants() do
			if d.Name == partName and d:IsA("BasePart") then
				table.insert(hide, d)
			end
		end
	end
	local gun: Gun = {
		model = m,
		handle = h,
		rig = nil,
		animator = GunAnimator.new(m, templateId, scale),
		rightGrip = anchorFor(m, h, attachment(m, "RightGrip")),
		leftGrip = anchorFor(m, h, attachment(m, "LeftGrip")),
		muzzle = attachment(m, "Muzzle"),
		pistol = false,
		aimRel = if weapon.adsReticle
			then weapon.adsReticle.center * scale
			elseif aim then h.CFrame:PointToObjectSpace(aim.WorldPosition)
			else Vector3.new(0, 0.3, 0),
		centerRel = h.CFrame:PointToObjectSpace(boxCf.Position),
		follow = {},
		adsHide = hide,
		adsFade = 0,
		reticle = reticle,
		recoil = Spring.new(VM.RECOIL_STIFFNESS, VM.RECOIL_DAMPING),
	}
	local rg, lg = gun.rightGrip, gun.leftGrip
	gun.pistol = rg ~= nil
		and lg ~= nil
		and (rg.part.CFrame:PointToWorldSpace(rg.offset) - lg.part.CFrame:PointToWorldSpace(
				lg.offset
			)).Magnitude
			< 0.2 * scale
	buildFollow(gun, weapon, dual) -- reads the welds, so before the rig drops them
	return gun
end

-- Called once the gun is in the workspace (raycasts need it there).
local function finishGun(gun: Gun, weapon: WeaponConfig)
	if not weapon.noAds then
		local distance = weapon.adsDistance or VM.ADS_DISTANCE
		for _, p in findOccluders(gun, distance, weapon.adsOffset or Vector3.zero) do
			if not table.find(gun.adsHide, p) then
				table.insert(gun.adsHide, p)
			end
		end
	end
	gun.rig = ViewmodelRig.new(gun.model, gun.handle)
end

local function setGunsVisible(visible: boolean)
	local modifier = if visible then 0 else 1
	for _, gun in guns do
		for _, d in gun.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = modifier
			end
		end
		gun.adsFade = -1 -- rewrite ADS fades next frame
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
	if arms then
		arms.model.Parent = nil
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
		finishGun(gun, weapon)
	end

	config = weapon
	hidden = false
	if not arms or armsLook ~= ViewmodelArms.signature(player.Character) then
		rebuildArms(cam)
	end
	local a = arms :: ViewmodelArms.Arms
	a.model.Parent = cam
	ViewmodelArms.setVisible(a, true)
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
		if arms then
			ViewmodelArms.setVisible(arms, not value)
		end
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

local function poseOffset(mirror: boolean): CFrame
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

local function updatePoseWeights(dt: number, state: string)
	for name in VM.POSES do
		local s = poseWeights[name]
		if not s then
			s = { x = 0, v = 0 }
			poseWeights[name] = s
		end
		weights[name] = approach(s, poseTarget(name, state), VM.POSE_STIFFNESS, dt)
	end
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

	-- Rebuild the arms if the avatar's look changed (appearance loads late).
	if now >= nextLookCheck then
		nextLookCheck = now + 1
		if ViewmodelArms.signature(player.Character) ~= armsLook then
			rebuildArms(cam)
		end
	end

	local state = MovementController.getState()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rawVelocity = if root and root:IsA("BasePart")
		then root.AssemblyLinearVelocity
		else Vector3.zero
	-- Low-pass the predicted velocity: it steps unevenly under Server Authority.
	smoothVelocity = smoothVelocity:Lerp(rawVelocity, 1 - math.exp(-VM.VELOCITY_SMOOTHING * dt))
	local velocity = smoothVelocity
	local localVel = camCf:VectorToObjectSpace(velocity)
	local adsT = adsEase(adsAlpha)
	local swayScale = 1 + (VM.ADS_SWAY_SCALE - 1) * adsT

	-- Turn sway: the gun lags how fast the view turns, plus a roll when strafing.
	if lastCamera then
		local delta = lastCamera:ToObjectSpace(camCf)
		local rx, ry = delta:ToEulerAnglesYXZ()
		local rate = 1 / math.max(dt, 1 / 240)
		local max = VM.SWAY_MAX
		sway.target = Vector3.new(
			math.clamp(-rx * rate * VM.SWAY_AMOUNT, -max, max),
			math.clamp(-ry * rate * VM.SWAY_AMOUNT, -max, max),
			math.clamp(-localVel.X * VM.STRAFE_ROLL, -max, max)
		) * swayScale
	end
	lastCamera = camCf
	local s = sway:update(dt)

	-- Movement lag: drifts against strafing and falling, dips on landing.
	local airborne = state == "Air"
	if lastState == "Air" and not airborne then
		local fall = math.clamp(-rawVelocity.Y / 50, 0, 1)
		move:impulse(Vector3.new(0, -VM.LAND_KICK * fall, 0))
	end
	lastState = state
	local moveScale = 1 + (VM.ADS_MOVE_SCALE - 1) * adsT
	move.target = Vector3.new(
		math.clamp(-localVel.X * VM.MOVE_LAG, -0.06, 0.06),
		math.clamp(-velocity.Y * VM.FALL_LAG, -0.08, 0.08),
		math.clamp(localVel.Z * VM.MOVE_LAG * 0.5, -0.04, 0.04)
	) * moveScale
	local m = move:update(dt)

	-- Walk bob follows real ground speed so it eases in and out; it stays
	-- (smaller) while aiming, so the sights sway side to side as you move.
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = not airborne and state ~= "Slide"
	local bobTarget = if grounded then math.clamp(flatSpeed / VM.BOB_WALK_SPEED, 0, 1.6) else 0
	local bobW = approach(bobAmount, bobTarget, 60, dt)
	bobPhase += dt * flatSpeed * VM.BOB_FREQUENCY * math.pi
	updatePoseWeights(dt, state)
	local sprintW = math.clamp(weights.Sprint or 0, 0, 1)
	local bobScale = bobW
		* (1 + (VM.SPRINT_BOB_SCALE - 1) * sprintW)
		* (1 + (VM.ADS_BOB_SCALE - 1) * adsT)
	local sinP, cos2P = math.sin(bobPhase), math.cos(2 * bobPhase)
	local bobPos = Vector3.new(sinP * VM.BOB_AMOUNT.X, cos2P * VM.BOB_AMOUNT.Y, 0) * bobScale
	local bobRot = Vector3.new(
		cos2P * VM.BOB_ROTATION.X,
		sinP * VM.BOB_ROTATION.Y,
		sinP * VM.BOB_ROTATION.Z
	) * bobScale

	-- Breathing: a slow idle drift, calmer while aiming.
	breathPhase += dt * VM.BREATH_RATE * 2 * math.pi
	local breathScale = 1 + (VM.ADS_BREATH_SCALE - 1) * adsT
	local breathPos = Vector3.new(
		math.sin(breathPhase * 0.5) * VM.BREATH_AMOUNT.X,
		math.sin(breathPhase) * VM.BREATH_AMOUNT.Y,
		0
	) * breathScale
	local breathRot = Vector3.new(math.sin(breathPhase + 0.6) * VM.BREATH_ROTATION, 0, 0)
		* breathScale

	stepTracks(dt)

	-- Shared motion of the whole viewmodel (also carries a free hand).
	local shared = CFrame.new(m + bobPos + breathPos)
		* angles(bobRot + breathRot)
		* CFrame.Angles(s.X, s.Y, s.Y * 0.4 + s.Z)

	local poseRight = poseOffset(false)
	local poseLeft = if guns.Left then poseOffset(true) else poseRight
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
		gun.animator:update(dt)
		local rig = gun.rig
		if rig then
			ViewmodelRig.pose(
				rig,
				camCf
					* shared
					* base
					* (if mirror then poseLeft else poseRight)
					* trackOffset(gun, mirror)
					* recoilCf
			)
		end

		if gun.reticle then
			gun.reticle.Enabled = adsAlpha > 0.4 and not hidden
		end

		-- Fade only the parts that block the sight line, while aiming.
		local fade = smoothstep((adsAlpha - 0.35) / 0.45)
		if not hidden and fade ~= gun.adsFade then
			gun.adsFade = fade
			for _, p in gun.adsHide do
				p.LocalTransparencyModifier = fade
			end
		end
	end

	-- Arms onto the grips (after the guns and their clips have moved).
	local a = arms
	if hidden or not a then
		return
	end
	-- Each arm runs from its grip down and back toward the (off-screen)
	-- shoulder along a fixed camera-space direction, eased to its ADS
	-- direction, so it enters the grip from below and frames the gun.
	local view = camCf * shared
	local rightVec = view.RightVector
	local eye = camCf.Position
	local pistol = right.pistol or guns.Left ~= nil -- Dual Boot: a pistol in each hand
	local function shoulderFrom(
		grip: Vector3,
		hip: Vector3,
		aimed: Vector3,
		pistolDir: Vector3
	): Vector3
		local dir = if pistol then pistolDir else hip:Lerp(aimed, adsT)
		return grip + view:VectorToWorldSpace(dir.Unit) * 3
	end
	local gripR = if right.rightGrip
		then handTarget(right, "Right", anchorPosition(right.rightGrip))
		else view:PointToWorldSpace(mirrorPos(VM.FREE_HAND))
	local shoulderR = shoulderFrom(
		gripR,
		VM.ARM_DIRECTION_RIGHT,
		VM.ADS_ARM_DIRECTION_RIGHT,
		VM.PISTOL_ARM_DIRECTION_RIGHT
	)
	-- Long guns: arms pushed back so the gun reads in front. Pistols: the hand
	-- wraps the front of the grip, as in RIVALS.
	local depth = if pistol then VM.PISTOL_ARM_DEPTH else VM.ARM_DEPTH
	ViewmodelArms.solve(a, 1, shoulderR, gripR, rightVec, eye, depth)

	local left = guns.Left
	local gripL: Vector3
	if left and left.rightGrip then
		gripL = anchorPosition(left.rightGrip) -- Dual Boot: the left gun's grip
	elseif c.fireMode == "Melee" or not right.leftGrip then
		gripL = view:PointToWorldSpace(VM.FREE_HAND)
	else
		local base = anchorPosition(right.leftGrip :: Anchor)
		-- Pistols: both grips in one spot, so the support hand sits below and
		-- left. Long guns: the hand holds the handguard from underneath.
		local offset = if right.pistol then VM.SUPPORT_HAND_OFFSET else VM.HANDGUARD_HAND_OFFSET
		base = right.handle.CFrame:PointToWorldSpace(
			right.handle.CFrame:PointToObjectSpace(base) + offset
		)
		if right.pistol then
			-- Pistols are held one-handed at the hip (RIVALS); the support
			-- hand rises in from below as you aim (and reaches for the mag
			-- from wherever it is during a reload).
			base = view:PointToWorldSpace(VM.PISTOL_REST_HAND):Lerp(base, adsT)
		end
		gripL = handTarget(right, "Left", base)
	end
	local shoulderL = shoulderFrom(
		gripL,
		VM.ARM_DIRECTION_LEFT,
		VM.ADS_ARM_DIRECTION_LEFT,
		VM.PISTOL_ARM_DIRECTION_LEFT
	)
	ViewmodelArms.solve(a, 3, shoulderL, gripL, rightVec, eye, depth)
	ViewmodelArms.apply(a)
end

function ViewmodelController.start()
	RunService:BindToRenderStep("GGViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
	player.CharacterRemoving:Connect(function()
		ViewmodelController.unequip()
		if arms then
			arms.model:Destroy()
			arms = nil
			armsLook = ""
		end
		-- Movement feel starts fresh next life (no landing dip from dying mid-air).
		lastState = "Idle"
		smoothVelocity = Vector3.zero
		lastCamera = nil
		table.clear(poseWeights)
		table.clear(weights)
		bobAmount.x, bobAmount.v = 0, 0
		for _, spring in { sway, move } do
			spring.position, spring.velocity, spring.target =
				Vector3.zero, Vector3.zero, Vector3.zero
		end
	end)
end

return ViewmodelController
