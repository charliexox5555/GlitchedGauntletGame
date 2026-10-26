--!strict
-- First-person viewmodel (Gunplay.md §6), RIVALS style. One rigid rig, built
-- the standard way (EgoMoose, "Writing an FPS framework"):
--
--   root = camera * motion        bob, breathing, sway, tilt (Util/ViewmodelMotion)
--   gun  = root * hold            hip/ADS, sprint/slide poses, equip/inspect/
--                                 reload tracks, recoil kick
--   hand = gun * grip * hand      hands sit on the gun's grips in gun space, and
--                                 follow the mag/pump/bolt during its clips
--   arm  = hand + direction       each block runs from its hand along a fixed
--                                 gun-space direction (rigid with the gun)
--
-- Everything is computed in that order every render frame, right after the
-- camera, then every part (gun, its moving joints, both arms) is moved at the
-- end of the same step with BulkMoveTo, so nothing can lag a frame or drift
-- relative to anything else. Each gun and the arms live in their own
-- WorldModel under the Camera: under Server Authority the Workspace snaps part
-- positions to a coarse grid (up to ~0.006 studs depending on where you
-- stand), which made every viewmodel part jitter on its own; WorldModels keep
-- exact positions and still render.
-- Guns point straight down the view (barrel parallel to the camera) with
-- their sight (pistols and melee: their grip) at the gun's `viewmodelOffset`;
-- perspective does the rest.
-- Guns with two models (akimbo) hold one in each hand, the left mirrored.

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
local ViewmodelMotion = require(script.Parent.Parent.Util.ViewmodelMotion)
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

-- One held model. A normal gun has only `Right`; akimbo guns have both.
type Gun = {
	model: WorldModel, -- named "Viewmodel" / "ViewmodelLeft" (EffectsController finds it)
	handle: BasePart,
	rig: ViewmodelRig.ViewmodelRig?, -- built once the gun is in the workspace
	animator: GunAnimator.GunAnimator,
	rightGrip: Anchor?,
	leftGrip: Anchor?,
	muzzle: Attachment?,
	pistol: boolean, -- both grips in one spot: a two-handed pistol hold
	aimRel: Vector3, -- sight position relative to the grip, at rest (ADS alignment)
	hipRel: Vector3, -- the point placed at viewmodelOffset at the hip (see buildGun)
	centerRel: Vector3, -- middle of the gun relative to the grip (inspect pivot)
	follow: { FollowRule },
	adsHide: { BasePart }, -- parts that block the sight line, faded while aiming
	adsFade: number, -- last fade written to adsHide
	reticle: SurfaceGui?,
	props: { Prop }, -- parts hidden while their joint is far from rest (config hideBeyond)
	lockPending: boolean, -- the last round went: lock the action once the Fire clip's recoil peaks
	recoil: Spring.Spring, -- hip kick
	adsRecoil: Spring.Spring, -- aimed kick (stiff, critically damped)
}

type Prop = { motor: Motor6D, parts: { BasePart }, limit: number, hiddenNow: boolean }

type Playing = { track: VM.Track, time: number, length: number, weight: number, fading: boolean }

-- A foley cue inside a clip: `at` is 0..1 through it.
export type Beat = { at: number, sound: "MagOut" | "MagIn" | "Rack" | "Open" | "ShellIn" }

type PoseWeight = { x: number, v: number, goal: number }

local SIDES: { Side } = { "Right", "Left" }

local guns: { [Side]: Gun } = {}
local config: WeaponConfig? = nil
local arms: ViewmodelArms.Arms? = nil
local armsLook = "" -- what the arms were built from
local nextLookCheck = 0

local playing: { [string]: Playing } = {}
local poseWeights: { [string]: PoseWeight } = {}
local weights: { [string]: number } = {}

local adsAlpha = 0
local hidden = false
local motion = ViewmodelMotion.new()
local motionInput: ViewmodelMotion.Input = {
	camera = CFrame.identity,
	velocity = Vector3.zero,
	grounded = true,
	sprinting = false,
	ads = 0,
}

local DEG = math.pi / 180
local studio = RunService:IsStudio()

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
	local point = if rule.point then attachment(gun.model, rule.point) else nil
	if point then
		return { part = joint, offset = joint.CFrame:PointToObjectSpace(point.WorldPosition) }
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
	-- The support hand works the gun in every handling clip it has.
	for _, clip in VM.HAND_CLIPS do
		for _, rule in VM.RELOAD_FOLLOW do
			addFollow(gun, clip, "Left", rule)
		end
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

-- Where an anchor is this frame: from the rig's freshly solved joint CFrames
-- (the same pass that places the gun), so a hand can never drift off it.
local function anchorPosition(gun: Gun, a: Anchor): Vector3
	local rig = gun.rig
	local cf = if rig then rig.world[a.part] or a.part.CFrame else a.part.CFrame
	return cf:PointToWorldSpace(a.offset)
end

-- Where a hand is this frame, and how far (0..1) it is off its grip working
-- a part of the gun.
local function handTarget(gun: Gun, hand: Side, base: Vector3): (Vector3, number)
	local clip = gun.animator.clipName
	if not clip then
		return base, 0
	end
	local t = gun.animator:progress()
	local pos = base
	local working = 0
	for _, rule in gun.follow do
		if rule.clip == clip and rule.hand == hand then
			local w = followWeight(rule, t)
			if w > 0 then
				pos = pos:Lerp(anchorPosition(gun, rule.anchor), w)
				working = math.max(working, w)
			end
		end
	end
	return pos, working
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
			local result = gun.model:Raycast(eye, dir, params)
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
	local clone = template:Clone()
	local scale = weapon.viewmodelScale or VM.SCALE
	clone:ScaleTo(scale)
	local h = clone.PrimaryPart :: BasePart
	-- Same contents, but in a WorldModel (exact part positions, see the top).
	local m = Instance.new("WorldModel")
	m.Name = name
	for key, value in clone:GetAttributes() do
		m:SetAttribute(key, value)
	end
	for _, child in clone:GetChildren() do
		child.Parent = m
	end
	m.PrimaryPart = h
	clone:Destroy()
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
		hipRel = Vector3.zero,
		centerRel = h.CFrame:PointToObjectSpace(boxCf.Position),
		follow = {},
		adsHide = hide,
		adsFade = 0,
		reticle = reticle,
		props = {},
		lockPending = false,
		recoil = Spring.new(VM.RECOIL_STIFFNESS, VM.RECOIL_DAMPING),
		adsRecoil = Spring.new(VM.ADS_RECOIL_STIFFNESS, 2 * math.sqrt(VM.ADS_RECOIL_STIFFNESS)),
	}
	local rg, lg = gun.rightGrip, gun.leftGrip
	gun.pistol = rg ~= nil
		and lg ~= nil
		and (rg.part.CFrame:PointToWorldSpace(rg.offset) - lg.part.CFrame:PointToWorldSpace(
				lg.offset
			)).Magnitude
			< 0.2 * scale
	-- Sidearms, melee and akimbo guns are placed by their grip: the hands are
	-- what you see, so they land the same on every one. Long guns are placed
	-- by their sight line at their grip's depth: every rifle's top edge sits
	-- at the same height, and a sight mounted far forward or back on the
	-- model doesn't push the gun into the camera or away from it.
	gun.hipRel = if weapon.class == "Sidearm"
			or weapon.fireMode == "Melee"
			or dual
		then Vector3.zero
		else Vector3.new(0, gun.aimRel.Y, 0)
	buildFollow(gun, weapon, dual) -- reads the welds, so before the rig drops them
	-- Props hidden far from rest (also reads the welds).
	local motors = m:FindFirstChild("Rig") and (m :: any).Rig:FindFirstChild("Motors")
	for jointName, limit in weapon.hideBeyond or {} do
		local joint = rigJoint(m, jointName)
		local motor = motors and motors:FindFirstChild(jointName)
		if joint and motor and motor:IsA("Motor6D") then
			local parts: { BasePart } = {}
			for _, d in m:GetDescendants() do
				if (d:IsA("Weld") or d:IsA("Motor6D")) and d.Part0 == joint then
					local p = d.Part1
					if p and p.Parent ~= joint.Parent and p.Transparency < 1 then
						table.insert(parts, p)
					end
				end
			end
			table.insert(
				gun.props,
				{ motor = motor, parts = parts, limit = limit * scale, hiddenNow = false }
			)
		end
	end
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

-- Foley cues read off a clip: the mag leaving and seating, the charging
-- handle (or bolt, or a pistol's slide) slamming home. Empty when the gun has no such clip.
local function clipBeats(gun: Gun, clip: string): { Beat }
	local beats: { Beat } = {}
	local animator = gun.animator
	local magFrom, magTo = animator:activity(clip, "Mag")
	if magFrom and magTo then
		table.insert(beats, { at = magFrom + VM.BEAT_MAG_OUT, sound = "MagOut" })
		table.insert(beats, { at = math.max(magTo - VM.BEAT_MAG_IN, magFrom), sound = "MagIn" })
	end
	for _, joint in { "ChargingHandle", "Bolt", "Slide" } do
		local _, to = animator:activity(clip, joint)
		if to then
			table.insert(beats, { at = math.max(to - VM.BEAT_RACK, 0), sound = "Rack" })
			break
		end
	end
	-- Break-actions and revolvers: open as the barrels drop / the cylinder
	-- swings out, shut (a rack) as they close, the spent cases out as a
	-- revolver's ejector rod pushes, and a shell-in as each round settles.
	for _, joint in { "Barrels", "Crane" } do
		local openFrom, openTo = animator:activity(clip, joint)
		if openFrom and openTo then
			table.insert(beats, { at = openFrom + VM.BEAT_MAG_OUT, sound = "Open" })
			table.insert(beats, { at = math.max(openTo - VM.BEAT_RACK, openFrom), sound = "Rack" })
		end
	end
	local ejectFrom = animator:activity(clip, "EjectorRod")
	if ejectFrom then
		table.insert(beats, { at = ejectFrom + VM.BEAT_MAG_OUT, sound = "MagOut" })
	end
	for _, shell in { "ShellUpper", "ShellLower", "Shell", "Rounds" } do
		local _, to = animator:activity(clip, shell)
		if to then
			table.insert(beats, { at = math.max(to - VM.BEAT_MAG_IN, 0), sound = "ShellIn" })
		end
	end
	return beats
end

-- Equips `weapon`. `first`: its first draw this life, which racks the action
-- (the gun's "Draw" clip, when it has one); otherwise a quick raise.
-- `duration`: the client's ready time. Returns the clip's foley cues.
function ViewmodelController.equip(
	weapon: WeaponConfig,
	first: boolean?,
	duration: number?
): { Beat }
	ViewmodelController.unequip()
	local cam = Workspace.CurrentCamera
	if not cam then
		return {}
	end
	local models = weapon.models
	local dual = models ~= nil and models.left ~= nil
	local right = buildGun(if models then models.right else weapon.id, "Viewmodel", weapon, dual)
	if not right then
		return {}
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
	local time = duration or weapon.equipTime
	if first and right.animator:has("Draw") then
		for _, gun in guns do
			gun.animator:play("Draw", time)
		end
		playTrack("Equip", "Draw", time)
		return clipBeats(right, "Draw")
	end
	playTrack("Equip", "Equip", math.max(time * 1.4, VM.TRACKS.Equip.length))
	return {}
end

-- `side`: which gun fired (akimbo guns alternate); normal guns are "Right".
-- `empty`: that was the last round (guns with lockOnEmpty lock the action open).
function ViewmodelController.fire(kickScale: number, side: Side?, empty: boolean?)
	local gun = guns[side or "Right"] or guns.Right
	if not gun then
		return
	end
	if playing.Inspect then
		ViewmodelController.cancelInspect()
	end
	gun.animator:play("Fire")
	gun.lockPending = empty == true
		and config ~= nil
		and config.lockOnEmpty == true
		and gun.animator:has("ReloadEmpty")
	local up = if config then config.recoil.up else 1
	local k = math.clamp(up, 0.3, 4) * kickScale
	gun.recoil:impulse(
		Vector3.new(
			VM.KICK_BACK * 40 * k,
			VM.KICK_ROTATE * 40 * k,
			(math.random() - 0.5) * VM.KICK_ROTATE * 20 * k
		)
	)
	-- Aimed kick: sized so its peak is ADS_KICK_* (a critically damped
	-- spring hit by v peaks at v / (omega * e)).
	local peak = math.sqrt(VM.ADS_RECOIL_STIFFNESS) * math.exp(1) * k
	gun.adsRecoil:impulse(
		Vector3.new(
			VM.ADS_KICK_BACK,
			VM.ADS_KICK_ROTATE,
			(math.random() - 0.5) * VM.ADS_KICK_ROTATE
		) * peak
	)
end

-- `empty`: the mag ran dry, so the reload ends by racking the action (the
-- gun's "ReloadEmpty" clip, when it has one). Returns the clip's foley cues.
function ViewmodelController.reload(duration: number, empty: boolean?): { Beat }
	ViewmodelController.cancelInspect()
	local right = guns.Right
	if not right then
		return {}
	end
	local clip = if empty and right.animator:has("ReloadEmpty") then "ReloadEmpty" else "Reload"
	for _, gun in guns do
		gun.animator:play(clip, duration)
	end
	playTrack("Reload", if clip == "ReloadEmpty" then "ReloadEmpty" else "Reload", duration)
	return clipBeats(right, clip)
end

local RELOAD_CLIPS = { "Reload", "ReloadEmpty", "ReloadStart", "ReloadInsert", "ReloadEnd" }

function ViewmodelController.cancelReload()
	for _, gun in guns do
		for _, clip in RELOAD_CLIPS do
			if gun.animator:isPlaying(clip) then
				gun.animator:stop()
				break
			end
		end
	end
	fadeTrack("Reload")
end

-- Plays one of the gun's clips over `duration` (the parts of a shell-by-shell
-- reload). Returns its foley cues.
function ViewmodelController.playClip(clip: string, duration: number): { Beat }
	ViewmodelController.cancelInspect()
	local right = guns.Right
	if not right or not right.animator:has(clip) then
		return {}
	end
	for _, gun in guns do
		gun.animator:play(clip, duration)
	end
	return clipBeats(right, clip)
end

-- Melee swing uses the weapon's Fire clip.
function ViewmodelController.swing()
	ViewmodelController.cancelInspect()
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
	local track = if c.fireMode == "Melee" then "InspectMelee" else "Inspect"
	playTrack("Inspect", track)
	-- The gun's own Inspect clip (a press check, the charm swinging) runs
	-- alongside, over the same time.
	for _, gun in guns do
		if gun.animator:has("Inspect") then
			gun.animator:play("Inspect", VM.TRACKS[track].length)
		end
	end
	return true
end

function ViewmodelController.cancelInspect()
	fadeTrack("Inspect")
	for _, gun in guns do
		if gun.animator:isPlaying("Inspect") then
			gun.animator:stop()
		end
	end
end

function ViewmodelController.isInspecting(): boolean
	local p = playing.Inspect
	return p ~= nil and not p.fading
end

function ViewmodelController.setAds(alpha: number)
	adsAlpha = alpha
	if alpha > 0.05 and playing.Inspect then
		ViewmodelController.cancelInspect()
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

-- `name`: a muzzle other than "Muzzle" (a double barrel's "MuzzleLower").
function ViewmodelController.muzzleCFrame(side: Side?, name: string?): CFrame?
	local gun = guns[side or "Right"] or guns.Right
	local muzzle = if gun
			and name
			and name ~= "Muzzle"
		then attachment(gun.model, name)
		else gun and gun.muzzle
	if muzzle then
		return muzzle.WorldCFrame
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
			s = { x = 0, v = 0, goal = 0 }
			poseWeights[name] = s
		end
		-- The goal eases toward the target first, so a pose starts with no
		-- sudden acceleration (an S-curve, not a kick).
		s.goal += (poseTarget(name, state) - s.goal) * (1 - math.exp(-VM.POSE_FREQUENCY * dt))
		s.x, s.v = ViewmodelMotion.spring(s.x, s.v, s.goal, VM.POSE_FREQUENCY, dt)
		weights[name] = s.x
	end
end

-- Where the gun sits relative to the rig's root: hip or ADS, then the
-- movement poses, keyframed tracks and recoil, all around the grip.
local function holdPose(
	gun: Gun,
	c: WeaponConfig,
	mirror: boolean,
	adsT: number,
	dt: number
): CFrame
	local hipPos = c.viewmodelOffset
	local hipRot = c.viewmodelRotation or Vector3.zero
	if mirror then
		hipPos, hipRot = mirrorPos(hipPos), mirrorRot(hipRot)
	end
	local hip = CFrame.new(hipPos) * angles(hipRot) * CFrame.new(-gun.hipRel)
	local base = hip
	if adsT > 0 then
		local ads = CFrame.new(c.adsOffset or Vector3.zero)
			* CFrame.new(0, 0, -(c.adsDistance or VM.ADS_DISTANCE))
			* CFrame.new(-gun.aimRel)
		base = hip:Lerp(ads, adsT)
	end
	local r = gun.recoil:update(dt) * 0.1 * (1 - adsT)
	local a = gun.adsRecoil:update(dt) * adsT
	local kick = r + a
	local recoilCf = CFrame.new(0, 0, kick.X) * CFrame.Angles(kick.Y, 0, kick.Z)
	return base * poseOffset(mirror) * trackOffset(gun, mirror) * recoilCf
end

local function mirrorHand(hand: VM.Hand, mirror: boolean): (Vector3, Vector3)
	if mirror then
		return mirrorPos(hand.offset), mirrorPos(hand.direction)
	end
	return hand.offset, hand.direction
end

-- Puts one arm on a gun: `grip` is the grip attachment's position this frame,
-- `hand` the hand's offset and arm direction in gun space. During the gun's
-- clips the hand moves toward the part it works (handTarget).
local function holdWith(
	a: ViewmodelArms.Arms,
	side: Side,
	gun: Gun,
	gunCf: CFrame,
	grip: Vector3,
	hand: VM.Hand,
	mirror: boolean
)
	local offset, direction = mirrorHand(hand, mirror)
	local point, working = handTarget(gun, side, grip + gunCf:VectorToWorldSpace(offset))
	if working > 0 then
		-- Reaching for a part: the arm comes up from below instead of running
		-- back across the screen.
		local reach = if mirror then mirrorPos(VM.REACH_DIRECTION) else VM.REACH_DIRECTION
		direction = direction:Lerp(reach, working)
	end
	ViewmodelArms.place(
		a,
		side,
		point,
		point + gunCf:VectorToWorldSpace(direction),
		gunCf.RightVector
	)
end

local handleCFrames: { [Side]: CFrame } = {}

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local right = guns.Right
	local c = config
	if not cam or not right or not c then
		motion.lastCamera = cam and cam.CFrame
		return
	end
	dt = math.min(dt, 0.1)
	if studio then
		-- Studio only: Workspace attribute VfxTimeScale slows or freezes the
		-- viewmodel too (with the shot effects), for reviewing animations.
		local scale = Workspace:GetAttribute("VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	local camCf = cam.CFrame
	local now = os.clock()

	-- Rebuild the arms if the avatar's look changed (appearance loads late).
	if now >= nextLookCheck then
		nextLookCheck = now + 1
		if ViewmodelArms.signature(player.Character) ~= armsLook then
			rebuildArms(cam)
		end
	end

	-- 1. Root: the camera plus the rig's motion (bob, breathing, sway, tilt).
	local state = MovementController.getState()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local adsT = adsEase(adsAlpha)
	motionInput.camera = camCf
	motionInput.velocity = if rootPart and rootPart:IsA("BasePart")
		then rootPart.AssemblyLinearVelocity
		else Vector3.zero
	motionInput.grounded = state ~= "Air" and state ~= "Slide"
	motionInput.sprinting = state == "Sprint"
	motionInput.ads = adsT
	local root = camCf * ViewmodelMotion.step(motion, motionInput, dt)

	-- 2. Guns: root * hold pose, then every joint of the gun from its clip.
	updatePoseWeights(dt, state)
	stepTracks(dt)
	local fade = smoothstep((adsAlpha - 0.35) / 0.45)
	for _, side in SIDES do
		local gun = guns[side]
		local rig = gun and gun.rig
		if gun and rig then
			gun.animator:update(dt)
			if
				gun.lockPending
				and (not gun.animator:isPlaying("Fire") or gun.animator:progress() >= VM.LOCK_AT)
			then
				gun.lockPending = false
				gun.animator:holdStart("ReloadEmpty")
			end
			for _, prop in gun.props do
				local away = prop.motor.Transform.Position.Magnitude > prop.limit
				if away ~= prop.hiddenNow then
					prop.hiddenNow = away
					for _, p in prop.parts do
						p.LocalTransparencyModifier = if away or hidden then 1 else 0
					end
				end
			end
			local handleCf = root * holdPose(gun, c, side == "Left", adsT, dt)
			handleCFrames[side] = handleCf
			ViewmodelRig.solve(rig, handleCf, 1 - (1 - VM.ADS_CLIP_KICK) * adsT)

			if gun.reticle then
				gun.reticle.Enabled = adsAlpha > 0.4 and not hidden
			end
			-- Fade only the parts that block the sight line, while aiming.
			if not hidden and fade ~= gun.adsFade then
				gun.adsFade = fade
				for _, p in gun.adsHide do
					p.LocalTransparencyModifier = fade
				end
			end
		end
	end

	-- 3. Hands and arms on the grips: gun space, from the same pass.
	local a = arms
	local rightCf = handleCFrames.Right
	if a and rightCf and right.rig then
		local left = guns.Left
		local leftCf = handleCFrames.Left
		local pistol = right.pistol or left ~= nil -- akimbo: a pistol in each hand
		local rightHand = if c.fireMode == "Melee"
			then VM.MELEE_HAND
			elseif pistol then VM.PISTOL_RIGHT_HAND
			else VM.RIFLE_RIGHT_HAND
		local gripR = if right.rightGrip
			then anchorPosition(right, right.rightGrip)
			else rightCf.Position
		holdWith(a, "Right", right, rightCf, gripR, rightHand, false)

		if left and left.rightGrip and left.rig and leftCf then
			-- Akimbo: the left hand holds the left gun, mirrored.
			holdWith(
				a,
				"Left",
				left,
				leftCf,
				anchorPosition(left, left.rightGrip),
				VM.PISTOL_RIGHT_HAND,
				true
			)
		elseif c.fireMode ~= "Melee" and right.pistol and right.rightGrip then
			holdWith(a, "Left", right, rightCf, gripR, VM.PISTOL_LEFT_HAND, false)
		elseif c.fireMode ~= "Melee" and right.leftGrip then
			holdWith(
				a,
				"Left",
				right,
				rightCf,
				anchorPosition(right, right.leftGrip),
				VM.RIFLE_LEFT_HAND,
				false
			)
		else
			-- Melee: the free hand is a guard, riding the root.
			local point = root:PointToWorldSpace(VM.FREE_HAND.offset)
			local toward = point + root:VectorToWorldSpace(VM.FREE_HAND.direction)
			ViewmodelArms.place(a, "Left", point, toward, root.RightVector)
		end
	end

	-- 4. Move everything, all from this one solve.
	for _, side in SIDES do
		local gun = guns[side]
		local rig = gun and gun.rig
		if gun and rig then
			ViewmodelRig.apply(rig, gun.model)
		end
	end
	if a then
		ViewmodelArms.apply(a)
	end
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
		ViewmodelMotion.reset(motion)
		table.clear(poseWeights)
		table.clear(weights)
	end)
end

return ViewmodelController
