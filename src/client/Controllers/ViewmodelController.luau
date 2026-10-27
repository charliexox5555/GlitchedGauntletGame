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
local MagDrop = require(script.Parent.Parent.Util.MagDrop)
local ViewmodelArms = require(script.Parent.Parent.Util.ViewmodelArms)
local ViewmodelMotion = require(script.Parent.Parent.Util.ViewmodelMotion)
local ViewmodelRig = require(script.Parent.Parent.Util.ViewmodelRig)
local MovementController = require(script.Parent.MovementController)

type WeaponConfig = Types.WeaponConfig

export type Side = "Right" | "Left"

local ViewmodelController = {}

local player = Players.LocalPlayer

-- A hand target that rides on a rig joint: `offset` is in that joint's space.
-- `reach`: the arm's direction (gun space) while the hand is on this part:
-- away from the surface it touches, so the hand block rests flat on it.
-- `frame`: when set, `offset` is a vector in that part's space (the gun's
-- Root) from `part`'s position: the hand follows the part's travel but not
-- its spin (a spinning cylinder would swing it through the gun).
type Anchor = { part: BasePart, offset: Vector3, reach: Vector3?, frame: BasePart? }

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
	mags: { Mag }, -- removable mags / belt boxes: dropped on reloads (Util/MagDrop)
	key: string, -- pool key for its dropped mags
	lockPending: boolean, -- the last round went: lock the action once the Fire clip's recoil peaks
	recoil: Spring.Spring, -- hip kick
	adsRecoil: Spring.Spring, -- aimed kick (stiff, critically damped)
}

type Prop = { motor: Motor6D, parts: { BasePart }, limit: number, hiddenNow: boolean }

-- A mag during a reload clip: hidden from `outAt` (a copy drops) until the new
-- one shows at `inAt` (0..1 through `clip`).
type Mag = {
	bone: string,
	parts: { BasePart },
	clip: string?,
	timing: MagDrop.Timing?,
	gone: boolean,
}

-- `rotScale`: how much of the track's rotation applies (0 = position only, when a
-- gun clip of the same move already turns the gun).
type Playing = {
	track: VM.Track,
	time: number,
	length: number,
	weight: number,
	fading: boolean,
	rotScale: number,
}

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
local heavyUntil = 0 -- knife heavy stab: both hands on the handle until then
local turnToken = 0 -- bumped to cancel akimbo turns waiting to start (playTurns)
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

-- Held Mods: the gun lowered (spring 0..1) and the Mod's item in the right
-- hand (its own WorldModel under the camera, like the guns).
local lowered = false
local lowerX, lowerV = 0, 0
local item: WorldModel? = nil
local raiseX, raiseV = 0, 0 -- the item's own (underdamped) raise
local actionKind: string? = nil
local actionAt = -math.huge
local itemHidden = false

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

local function playTrack(slot: string, trackName: string, duration: number?, rotScale: number?)
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
		rotScale = rotScale or 1,
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

-- A gun's extra lift for one track slot (config.trackLift, e.g. a bullpup
-- raised so its reload shows), eased in and out over the track's ends.
local LIFT_EASE = 0.15
local function liftFor(slot: string, t: number): (Vector3, Vector3)
	local lifts = config and config.trackLift
	local lift = lifts and lifts[slot]
	-- Studio only: Workspace VmLift<slot> (Vector3) tunes it live.
	local live = if studio then Workspace:GetAttribute("VmLift" .. slot) else nil
	if typeof(live) == "Vector3" then
		lift = { pos = live, rot = if lift then lift.rot else nil }
	end
	if not lift then
		return Vector3.zero, Vector3.zero
	end
	local e = smoothstep(math.clamp(math.min(t, 1 - t) / LIFT_EASE, 0, 1))
	return lift.pos * e, (lift.rot or Vector3.zero) * e
end

-- Track slots akimbo guns take turns on (see playTurns).
local TURN_SLOTS = { Equip = true, Reload = true, Inspect = true }

-- The combined track offset for one gun, around its pivots.
local function trackOffset(gun: Gun, mirror: boolean): CFrame
	local cf = CFrame.identity
	-- Akimbo guns take turns (playTurns): the right gun's half, then the left's.
	local turn = if guns.Left then (if mirror then 1 else 0) else nil
	for slot, p in playing do
		local t = math.clamp(p.time / p.length, 0, 1)
		if turn and TURN_SLOTS[slot] then
			t = math.clamp(t * 2 - turn, 0, 1)
		end
		local pos, rot = sample(p.track, t)
		local liftPos, liftRot = liftFor(slot, t)
		rot *= p.rotScale
		pos += liftPos
		rot += liftRot
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
-- Bounds of the parts on `joint`, in `frame` (default: the joint's own).
local function jointBounds(m: Model, joint: BasePart, frame: CFrame?): (Vector3?, Vector3?)
	local space = frame or joint.CFrame
	local low: Vector3?, high: Vector3? = nil, nil
	for _, d in m:GetDescendants() do
		if (d:IsA("Weld") or d:IsA("Motor6D")) and d.Part0 == joint then
			local p = d.Part1
			if p and p.Parent ~= joint.Parent and p.Transparency < 1 then
				local half = p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local corner = space:PointToObjectSpace(
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

-- Where `hand` takes hold of `rule`'s part (nil: it can't, e.g. a part on
-- the far side of the gun, which the other hand works).
local function followAnchor(gun: Gun, rule: VM.Follow, hand: Side): Anchor?
	local joint = rigJoint(gun.model, rule.joint)
	if not joint then
		return nil
	end
	local handle = gun.model.PrimaryPart
	local point = if rule.point then attachment(gun.model, rule.point) else nil
	local grip = if rule.grab == "Grip" and gun.leftGrip
		then gun.leftGrip.part.CFrame:PointToWorldSpace(gun.leftGrip.offset)
		else nil
	local held = if point then point.WorldPosition else grip
	if held or rule.grab == "Grip" then
		if not held then
			return nil
		end
		-- A grip that moves (a pump, break-action barrels): the hand holds it
		-- the way it holds the handguard (RIFLE_LEFT_HAND), riding the joint.
		-- On a pistol (a revolver's crane, a pocket shotgun's barrels) it
		-- takes it from the left side instead.
		local world = held
		local reach: Vector3? = nil
		if handle and hand == "Left" then
			local hold = if gun.pistol then VM.PISTOL_FOLLOW_HAND else VM.RIFLE_LEFT_HAND
			world += handle.CFrame:VectorToWorldSpace(hold.offset)
			reach = hold.direction
		end
		return { part = joint, offset = joint.CFrame:PointToObjectSpace(world), reach = reach }
	end
	-- Measured in gun space (the Handle), so "Bottom" is the gun's down.
	local frame = if handle then handle.CFrame else joint.CFrame
	local low, high = jointBounds(gun.model, joint, frame)
	if not low or not high then
		return { part = joint, offset = Vector3.zero }
	end
	local center = (low + high) / 2
	local at = if rule.grab == "Bottom" then Vector3.new(center.X, low.Y, center.Z) else center
	local reach: Vector3? = nil
	if handle then
		-- The hand block is wide: stop it FOLLOW_CLEARANCE outside the part
		-- (below a mag; beside anything else, from the hand's own side) with
		-- the arm pointing away from it, so the block rests on the part
		-- instead of swallowing it. A side part on the far side of the gun
		-- belongs to the other hand.
		local handSide = if hand == "Right" then 1 else -1
		if
			rule.grab ~= "Bottom"
			and math.abs(at.X) > VM.FOLLOW_SIDE
			and math.sign(at.X) ~= handSide
		then
			return nil
		end
		local out = if rule.grab == "Bottom"
			then Vector3.new(0, -1, 0)
			else Vector3.new(handSide, 0, 0)
		local side = out.X ~= 0
		local edge = if out.X > 0 then high.X elseif out.X < 0 then low.X else at.X
		-- From the side the hand takes the part a little low, elbow out.
		local y = if side then at.Y - VM.FOLLOW_SIDE_DROP else at.Y
		at = Vector3.new(edge, y, at.Z)
			+ out * (if side then VM.FOLLOW_SIDE_CLEARANCE else VM.FOLLOW_CLEARANCE)
		reach = (out + (if side
			then Vector3.new(0, VM.FOLLOW_SIDE_DROPS[1], VM.FOLLOW_SIDE_BACK)
			else VM.FOLLOW_REACH_BIAS)).Unit
		-- From the side, keep clear of the gun's other moving parts (a wide
		-- drum just under a charging handle): lift the hand until it is, then
		-- let the forearm hang as steeply as it can without passing through
		-- them (FOLLOW_SIDE_DROPS, steepest first).
		if side then
			-- One box per visible part of the gun (gun space), except those on
			-- the part being worked and on FOLLOW_IGNORE_JOINTS.
			local others = {}
			for _, d in gun.model:GetDescendants() do
				if (d:IsA("Weld") or d:IsA("Motor6D")) and d.Part0 and d.Part0 ~= joint then
					local p = d.Part1
					local carrier = d.Part0
					if
						p
						and p:IsA("BasePart")
						and p.Parent ~= carrier.Parent
						and p.Transparency < 1
						and not table.find(VM.FOLLOW_IGNORE_JOINTS, carrier.Name)
					then
						local half = p.Size / 2
						local ol: Vector3?, oh: Vector3? = nil, nil
						for _, sx in { -1, 1 } do
							for _, sy in { -1, 1 } do
								for _, sz in { -1, 1 } do
									local corner = frame:PointToObjectSpace(
										p.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
									)
									ol = if ol then ol:Min(corner) else corner
									oh = if oh then oh:Max(corner) else corner
								end
							end
						end
						table.insert(others, { ol, oh })
					end
				end
			end
			-- How deep a cube of half-size `r` around `c` sinks into the part
			-- boxes (0 = clear).
			local function depth(c: Vector3, r: number): number
				local worst = 0
				for _, box in others do
					local ol, oh = box[1], box[2]
					local d = math.min(
						c.X + r - ol.X,
						oh.X - (c.X - r),
						c.Y + r - ol.Y,
						oh.Y - (c.Y - r),
						c.Z + r - ol.Z,
						oh.Z - (c.Z - r)
					)
					if d > worst then
						worst = d
					end
				end
				return worst
			end
			for _ = 1, VM.FOLLOW_LIFT_STEPS do
				if
					depth(
						at + (reach :: Vector3) * VM.FOLLOW_LIFT_PUSH,
						VM.ARM_WIDTH / 2 - VM.FOLLOW_LIFT_BEVEL
					) <= 0
				then
					break
				end
				at += Vector3.new(0, VM.FOLLOW_LIFT_STEP, 0)
			end
			-- Pick the forearm (FOLLOW_SIDE_DROPS, steepest first) and how far
			-- out the hand steps (FOLLOW_SIDE_STEPS) that sink least into the
			-- gun's other parts, preferring steep and close: the first clear
			-- one, else the least deep (a step out costs FOLLOW_STEP_COST per stud).
			-- (The square block turns about the arm: its edges reach out
			-- further than its half-width, hence the margin.)
			local base = at
			local r = VM.ARM_WIDTH / 2 + VM.FOLLOW_ARM_MARGIN
			local best = math.huge
			for _, drop in VM.FOLLOW_SIDE_DROPS do
				local dir = (out + Vector3.new(0, drop, VM.FOLLOW_SIDE_BACK)).Unit
				for _, extra in VM.FOLLOW_SIDE_STEPS do
					local spot = base + out * extra
					local worst = 0
					for k = 1, VM.FOLLOW_ARM_SAMPLES do
						-- From the block's tip (it ends HAND_OVERSHOOT past the hand) up the arm.
						local along = (k - 1) * VM.FOLLOW_ARM_STEP
							- VM.ARM_WIDTH * VM.HAND_OVERSHOOT
						worst = math.max(worst, depth(spot + dir * along, r))
					end
					local score = worst + extra * VM.FOLLOW_STEP_COST
					if score < best - 1e-4 then
						best, at, reach = score, spot, dir
					end
					if worst <= 0 then
						break -- clear: no need to step further out
					end
				end
				if best <= 0 then
					break
				end
			end
		end
	end
	local world = frame:PointToWorldSpace(at)
	local root = rigJoint(gun.model, "Root")
	if root and root ~= joint then
		return {
			part = joint,
			offset = root.CFrame:VectorToObjectSpace(world - joint.Position),
			reach = reach,
			frame = root,
		}
	end
	return { part = joint, offset = joint.CFrame:PointToObjectSpace(world), reach = reach }
end

-- Which side of the gun a "Center" rule's part sits on: 1 right, -1 left,
-- 0 on the centre line (or not a side part).
local function partSide(gun: Gun, rule: VM.Follow): number
	local joint = rigJoint(gun.model, rule.joint)
	local handle = gun.model.PrimaryPart
	if rule.grab ~= "Center" or rule.point or not joint or not handle then
		return 0
	end
	local low, high = jointBounds(gun.model, joint, handle.CFrame)
	if not low or not high then
		return 0
	end
	local x = (low.X + high.X) / 2
	return if math.abs(x) > VM.FOLLOW_SIDE then math.sign(x) else 0
end

local function addFollow(gun: Gun, clip: string, hand: Side, rule: VM.Follow): boolean
	local from, to = gun.animator:activity(clip, rule.joint)
	if not from or not to then
		return false
	end
	-- A dropped mag (MagDrop): the hand takes the new one from the clip's
	-- MagIn marker, not the old one falling below the view.
	if rule.joint == "Mag" or rule.joint == "AmmoBox" then
		local data = gun.animator.clips and (gun.animator.clips :: any)[clip]
		local magIn = data and data.markers and data.markers.MagIn
		if typeof(magIn) == "number" and magIn > from and magIn < to then
			from = magIn
		end
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
	local anchor = followAnchor(gun, rule, hand)
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
	-- The support hand works the gun in every handling clip it has (on a
	-- lever-action the trigger hand works the lever, which drives the bolt).
	local lever = rigJoint(gun.model, "Lever") ~= nil
	for _, clip in VM.HAND_CLIPS do
		if lever then
			addFollow(gun, clip, "Right", VM.LEVER_FOLLOW)
		end
		for _, rule in VM.RELOAD_FOLLOW do
			-- A part on the right of the gun (a bolt handle) is the trigger
			-- hand's: the support hand would reach through the gun.
			-- (A lever or a pump drives the bolt: nobody works it by hand.)
			if not ((lever or weapon.fireMode == "Pump") and rule.joint == "Bolt") then
				local hand: Side = if not lever and partSide(gun, rule) > 0 then "Right" else "Left"
				addFollow(gun, clip, hand, rule)
			end
		end
	end
	if weapon.fireMode == "Pump" then
		addFollow(gun, "Fire", "Left", VM.PUMP_FOLLOW)
	elseif weapon.fireMode == "Bolt" then
		addFollow(gun, "Fire", "Right", if lever then VM.LEVER_FOLLOW else VM.BOLT_FOLLOW)
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
	local frame = a.frame
	if frame then
		local fcf = if rig then rig.world[frame] or frame.CFrame else frame.CFrame
		return cf.Position + fcf:VectorToWorldSpace(a.offset)
	end
	return cf:PointToWorldSpace(a.offset)
end

-- Where a hand is this frame, how far (0..1) it is off its grip working a
-- part of the gun, and the arm direction that part asks for (if any).
local function handTarget(gun: Gun, hand: Side, base: Vector3): (Vector3, number, Vector3?)
	local clip = gun.animator.clipName
	if not clip then
		return base, 0, nil
	end
	local t = gun.animator:progress()
	local pos = base
	local working = 0
	local reach: Vector3? = nil
	for _, rule in gun.follow do
		if rule.clip == clip and rule.hand == hand then
			local w = followWeight(rule, t)
			if w > 0 then
				pos = pos:Lerp(anchorPosition(gun, rule.anchor), w)
				if w >= working then
					reach = rule.anchor.reach
				end
				working = math.max(working, w)
			end
		end
	end
	return pos, working, reach
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
		mags = {},
		key = name .. weapon.id,
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
	-- Mags and belt boxes, with whatever rides them (a belt on its box).
	for _, jointName in VM.MAG_DROP.bones do
		local joint = rigJoint(m, jointName)
		if joint then
			local parts: { BasePart } = {}
			local joints = { joint }
			local i = 1
			while joints[i] do
				local j = joints[i]
				for _, d in m:GetDescendants() do
					if (d:IsA("Weld") or d:IsA("Motor6D")) and d.Part0 == j then
						local p = d.Part1
						if p and p.Parent == j.Parent then
							table.insert(joints, p) -- a child joint
						elseif p and p.Transparency < 1 then
							table.insert(parts, p)
						end
					end
				end
				i += 1
			end
			if #parts > 0 then
				table.insert(
					gun.mags,
					{ parts = parts, clip = nil, timing = nil, gone = false, bone = jointName }
				)
			end
		end
	end
	return gun
end

-- Eye to AimPoint while aiming. Studio only: a Workspace number attribute
-- VmAdsDistance overrides it (re-draw to refresh the sight-line hiding).
local function adsDistanceOf(weapon: WeaponConfig): number
	local live = if studio then Workspace:GetAttribute("VmAdsDistance") else nil
	if typeof(live) == "number" then
		return live
	end
	return weapon.adsDistance or VM.ADS_DISTANCE
end

-- Called once the gun is in the workspace (raycasts need it there).
local function finishGun(gun: Gun, weapon: WeaponConfig)
	if not weapon.noAds then
		local distance = adsDistanceOf(weapon)
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
	turnToken += 1
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
	-- Mags and belt boxes: out as they start moving, in as they stop. A belt
	-- feed cover opens, then latches shut (a shell-in click).
	for _, joint in { "Mag", "AmmoBox" } do
		local magFrom, magTo = animator:activity(clip, joint)
		if magFrom and magTo then
			table.insert(beats, { at = magFrom + VM.BEAT_MAG_OUT, sound = "MagOut" })
			table.insert(beats, { at = math.max(magTo - VM.BEAT_MAG_IN, magFrom), sound = "MagIn" })
		end
	end
	local coverFrom, coverTo = animator:activity(clip, "FeedCover")
	if coverFrom and coverTo then
		table.insert(beats, { at = coverFrom + VM.BEAT_MAG_OUT, sound = "Open" })
		table.insert(beats, { at = math.max(coverTo - VM.BEAT_RACK, coverFrom), sound = "ShellIn" })
	end
	for _, joint in { "ChargingHandle", "Bolt", "Slide", "Lever" } do
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
	-- Rounds going in: the clip's ShellIn marker (set in Blender) when it has
	-- one, else as each round prop stops moving.
	local data = animator.clips and (animator.clips :: any)[clip]
	local shellMark = data and data.markers and data.markers.ShellIn
	if typeof(shellMark) == "number" then
		table.insert(beats, { at = shellMark, sound = "ShellIn" })
		return beats
	end
	for _, shell in { "ShellUpper", "ShellLower", "Shell", "Rounds", "RoundUpper", "RoundLower" } do
		local _, to = animator:activity(clip, shell)
		if to then
			table.insert(beats, { at = math.max(to - VM.BEAT_MAG_IN, 0), sound = "ShellIn" })
		end
	end
	return beats
end

-- Akimbo guns take turns, never both at once: the right gun's clip over the
-- first half of `duration`, then the left gun's over the second. `onStart`
-- runs as each gun's clip starts. Other guns just play it.
local function playTurns(clip: string, duration: number, onStart: ((Gun) -> ())?)
	turnToken += 1
	local right, left = guns.Right, guns.Left
	if not right then
		return
	end
	local function start(gun: Gun, time: number)
		gun.animator:play(clip, time)
		if onStart then
			onStart(gun)
		end
	end
	if not left then
		start(right, duration)
		return
	end
	local half = duration / 2
	start(right, half)
	local token = turnToken
	task.delay(half, function()
		if turnToken == token and guns.Left == left then
			start(left, half)
		end
	end)
end

-- A clip's foley cues for the whole turn-taking span: akimbo guns hear the
-- right gun's cues in the first half and the left gun's in the second.
local function turnBeats(beats: { Beat }): { Beat }
	if not guns.Left then
		return beats
	end
	local out: { Beat } = {}
	for _, b in beats do
		table.insert(out, { at = b.at * 0.5, sound = b.sound })
		table.insert(out, { at = 0.5 + b.at * 0.5, sound = b.sound })
	end
	return out
end

-- Equips `weapon`: every equip plays the gun's "Draw" clip (raise and rack
-- the action), when it has one; otherwise a quick raise.
-- `duration`: the client's ready time. Returns the clip's foley cues.
function ViewmodelController.equip(weapon: WeaponConfig, duration: number?): { Beat }
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
	if right.animator:has("Draw") then
		playTurns("Draw", time)
		playTrack("Equip", "Draw", time)
		return turnBeats(clipBeats(right, "Draw"))
	end
	playTrack("Equip", "Equip", math.max(time * 1.4, VM.TRACKS.Equip.length))
	return {}
end

-- `side`: which gun fired (akimbo guns alternate); normal guns are "Right".
-- `empty`: that was the last round (guns with lockOnEmpty lock the action open).
-- The trigger on an empty gun: the gun's DryFire clip, when it has one.
function ViewmodelController.dryFire()
	for _, gun in guns do
		if gun.animator:has("DryFire") and not gun.animator:isPlaying() then
			gun.animator:play("DryFire")
		end
	end
end

function ViewmodelController.isHidden(): boolean
	return hidden
end

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
	playTurns(clip, duration, function(gun)
		local data = gun.animator.clips and (gun.animator.clips :: any)[clip]
		for _, mag in gun.mags do
			mag.clip = clip
			mag.timing = if data then MagDrop.timing(data, mag.bone) else nil
		end
	end)
	playTrack("Reload", if clip == "ReloadEmpty" then "ReloadEmpty" else "Reload", duration)
	return turnBeats(clipBeats(right, clip))
end

local RELOAD_CLIPS = { "Reload", "ReloadEmpty", "ReloadStart", "ReloadInsert", "ReloadEnd" }

function ViewmodelController.cancelReload()
	turnToken += 1
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
-- A melee attack: `attack` is "Slash1".."Slash3" or "HeavyStab". The knife's
-- clip of that name drives it when it has one (Blender); else its Fire clip
-- under the placeholder camera track of that name. Returns the seconds until
-- the blade lands (the clip's Hit marker), for the impact effects.
function ViewmodelController.swing(attack: string?): number
	ViewmodelController.cancelInspect()
	local right = guns.Right
	local hitDelay = 0
	local length = attack and VM.TRACKS[attack] and VM.TRACKS[attack].length or 0
	if right then
		local clips = right.animator.clips :: any
		local data = attack and clips and clips[attack]
		if data then
			-- The Blender clip turns the blade at the wrist; the camera track
			-- adds the arm's sweep (position only), over the clip's length.
			right.animator:play(attack :: string)
			length = math.max(data.frames - 1, 1) / clips.fps
			local hit = data.markers and data.markers.Hit
			hitDelay = if typeof(hit) == "number" then hit * length else 0
			if VM.TRACKS[attack :: string] then
				playTrack("Swing", attack :: string, length, 0)
			end
		else
			right.animator:play("Fire")
			if attack and VM.TRACKS[attack] then
				playTrack("Swing", attack)
			end
		end
	end
	heavyUntil = if attack == "HeavyStab" then os.clock() + length else 0
	return hitDelay
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
	-- Akimbo: each gun gets a whole inspect, one after the other.
	local length = VM.TRACKS[track].length * (if guns.Left then 2 else 1)
	-- A knife's own Inspect clip turns the blade; the track only lifts it into view.
	local clipTurns = c.fireMode == "Melee" and guns.Right.animator:has("Inspect")
	playTrack("Inspect", track, length, if clipTurns then 0 else 1)
	-- The gun's own Inspect clip (a press check, the charm swinging) runs
	-- alongside, over the same time.
	if guns.Right.animator:has("Inspect") then
		playTurns("Inspect", length)
	end
	return true
end

function ViewmodelController.cancelInspect()
	if playing.Inspect then
		turnToken += 1
	end
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

-- Held Mods ---------------------------------------------------------------------

-- Drops the gun (and the arms on it) out of view, or brings it back.
function ViewmodelController.setLowered(value: boolean)
	lowered = value
end

-- Puts a Mod's item (a Model; cloned) in the right hand, raised as the gun
-- lowers. Its pivot is the grip. nil takes it away.
function ViewmodelController.holdItem(template: Model?)
	if item then
		item:Destroy()
		item = nil
	end
	local cam = Workspace.CurrentCamera
	actionKind = nil
	itemHidden = false
	raiseX, raiseV = 0, 0
	if not template or not cam then
		return
	end
	local world = Instance.new("WorldModel")
	world.Name = "ViewmodelItem"
	local copy = template:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	copy.Parent = world
	world.Parent = cam
	item = world
end

-- A use, keyframed on the held item (Config/Viewmodel ITEM_ACTIONS): "Throw"
-- (the item leaves the hand at the release), "Place" or "Heal".
function ViewmodelController.itemAction(kind: string)
	if VM.ITEM_ACTIONS[kind] then
		actionKind = kind
		actionAt = os.clock()
	end
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The action's offset at `now` (identity when none is playing), and whether
-- the item has left the hand.
local function actionOffset(now: number): (CFrame, boolean)
	local action = if actionKind then VM.ITEM_ACTIONS[actionKind] else nil
	if not action then
		return CFrame.identity, false
	end
	local t = (now - actionAt) / action.length
	local gone = action.hideAt ~= nil and t >= action.hideAt
	if t >= 1 then
		return CFrame.identity, gone
	end
	local keys = action.keys
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			local k = smooth((t - a.t) / math.max(b.t - a.t, 1e-3))
			local pos = a.pos:Lerp(b.pos, k)
			local rot = a.rot:Lerp(b.rot, k)
			return CFrame.new(pos) * angles(rot), gone
		end
	end
	return CFrame.identity, gone
end

-- One step of a damped spring with ratio `zeta` (below 1 overshoots).
local function springStep(
	x: number,
	v: number,
	goal: number,
	w: number,
	zeta: number,
	dt: number
): (number, number)
	-- Sub-steps keep it stable at low frame rates.
	local steps = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / steps
	for _ = 1, steps do
		local a = w * w * (goal - x) - 2 * zeta * w * v
		v += a * h
		x += v * h
	end
	return x, v
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

-- Drops the old mag as it leaves the gun and hides it until the new one
-- comes up (MagDrop.timing). Runs after the clip has posed the joints.
local function showMag(mag: Mag, visible: boolean)
	mag.gone = not visible
	for _, p in mag.parts do
		p.LocalTransparencyModifier = if visible and not hidden then 0 else 1
	end
end

local function stepMags(gun: Gun)
	for _, mag in gun.mags do
		local timing = mag.timing
		if not timing then
			continue
		end
		if not gun.animator:isPlaying(mag.clip) then
			-- Finished or cancelled: the gun has a mag again.
			mag.timing = nil
			if mag.gone then
				showMag(mag, true)
			end
			continue
		end
		local t = gun.animator:progress()
		if not mag.gone and t >= timing.outAt and t < timing.inAt then
			MagDrop.drop(gun.key, mag.parts)
			showMag(mag, false)
		elseif mag.gone and t >= timing.inAt then
			mag.timing = nil
			showMag(mag, true)
		end
	end
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
-- Studio only: a Workspace Vector3 attribute overrides a hold value live
-- (VmOffset, VmRotation, VmRightHand, VmRightDir, VmLeftHand, VmLeftDir), for
-- tuning a gun's hold without restarting. Unset = the config value.
local function tuned(name: string, value: Vector3): Vector3
	if studio then
		local v = Workspace:GetAttribute(name)
		if typeof(v) == "Vector3" then
			return v
		end
	end
	return value
end

local function tunedHand(hand: VM.Hand, side: string): VM.Hand
	if not studio then
		return hand
	end
	return {
		offset = tuned("Vm" .. side .. "Hand", hand.offset),
		direction = tuned("Vm" .. side .. "Dir", hand.direction),
	}
end

local function holdPose(
	gun: Gun,
	c: WeaponConfig,
	mirror: boolean,
	adsT: number,
	dt: number
): CFrame
	local hipPos = tuned("VmOffset", c.viewmodelOffset)
	local hipRot = tuned("VmRotation", c.viewmodelRotation or Vector3.zero)
	if mirror then
		hipPos, hipRot = mirrorPos(hipPos), mirrorRot(hipRot)
	end
	local hip = CFrame.new(hipPos) * angles(hipRot) * CFrame.new(-gun.hipRel)
	local base = hip
	if adsT > 0 then
		local ads = CFrame.new(c.adsOffset or Vector3.zero)
			* CFrame.new(0, 0, -adsDistanceOf(c))
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
	local point, working, partReach = handTarget(gun, side, grip + gunCf:VectorToWorldSpace(offset))
	if working > 0 then
		-- Reaching for a part: the arm turns away from the part's surface
		-- (its anchor's reach), or comes up from below on its own side
		-- instead of running back across the screen (REACH_DIRECTION is the
		-- left hand's; the right hand, e.g. working a bolt, mirrors it).
		local reach = partReach
			or (if side == "Right" then mirrorPos(VM.REACH_DIRECTION) else VM.REACH_DIRECTION)
		direction = direction:Lerp(reach, working)
		-- On the way (between the grip and the part) the hand swings out
		-- sideways and down along its arm (not back, where the mag is),
		-- around the gun rather than through it.
		-- (Beside the gun it swings straight out, never down past a drum or mag.)
		local swing = Vector3.new(
			reach.X,
			if math.abs(reach.X) > 0.5 then math.max(reach.Y, 0) else reach.Y,
			0
		)
		if swing.Magnitude > 1e-3 then
			point += gunCf:VectorToWorldSpace(swing.Unit) * (VM.FOLLOW_ARC * 4 * working * (1 - working))
		end
	end
	-- A reaching arm must never run back through the eye: from inside the
	-- block every face is a back face and the whole arm draws nothing, and
	-- just under the eye it walls off the view. If it would pass within
	-- ARM_EYE_CLEARANCE of the camera, bend it to point at least ARM_MIN_DROP
	-- down the screen and at most ARM_MAX_BACK toward the camera, the rest out
	-- to the hand's own side (a hand on a turned or rolled gun's handle).
	local along = gunCf:VectorToWorldSpace(direction)
	local cam = Workspace.CurrentCamera
	if cam and working > 0 and along.Magnitude > 1e-4 then
		local unit = along.Unit
		local toEye = cam.CFrame.Position - point
		local t = math.clamp(toEye:Dot(unit), 0, VM.ARM_REACH_LENGTH)
		local c0 = cam.CFrame:VectorToObjectSpace(unit)
		-- (A hand working a part beside the gun always reaches up from below
		-- the screen, like a support hand racking a handle: across the view
		-- the block would hide the gun.)
		local across = partReach ~= nil and (c0.Y > -VM.ARM_MIN_DROP or c0.Z > VM.ARM_MAX_BACK)
		if across or (toEye - unit * t).Magnitude < VM.ARM_EYE_CLEARANCE then
			local c = cam.CFrame:VectorToObjectSpace(unit)
			local y = math.min(c.Y, -VM.ARM_MIN_DROP)
			local z = math.min(c.Z, VM.ARM_MAX_BACK)
			local sideSign = if math.abs(c.X) > 1e-3
				then math.sign(c.X)
				elseif side == "Right" then 1
				else -1
			local x = sideSign * math.sqrt(math.max(1 - y * y - z * z, 0))
			along = unit:Lerp(cam.CFrame:VectorToWorldSpace(Vector3.new(x, y, z)), working)
		end
	end
	ViewmodelArms.place(a, side, point, point + along, gunCf.RightVector)
end

local handleCFrames: { [Side]: CFrame } = {}

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local right = guns.Right
	local c = config
	dt = math.min(dt, 0.1)
	if studio then
		-- Studio only: Workspace attribute VfxTimeScale slows or freezes the
		-- viewmodel too (with the shot effects), for reviewing animations.
		local scale = Workspace:GetAttribute("VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	MagDrop.step(dt) -- dropped mags keep falling after a swap
	if not cam or not right or not c then
		motion.lastCamera = cam and cam.CFrame
		return
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

	-- Held Mod: the gun drops away, the item comes up.
	lowerX, lowerV =
		ViewmodelMotion.spring(lowerX, lowerV, if lowered then 1 else 0, VM.LOWER_FREQUENCY, dt)
	local lowerT = math.clamp(lowerX, 0, 1)
	local lowerCf = if lowerT > 1e-3
		then CFrame.new(VM.LOWER.pos * lowerT) * angles(VM.LOWER.rot * lowerT)
		else CFrame.identity

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
			stepMags(gun)
			for _, prop in gun.props do
				local away = prop.motor.Transform.Position.Magnitude > prop.limit
				if away ~= prop.hiddenNow then
					prop.hiddenNow = away
					for _, p in prop.parts do
						p.LocalTransparencyModifier = if away or hidden then 1 else 0
					end
				end
			end
			local handleCf = root * lowerCf * holdPose(gun, c, side == "Left", adsT, dt)
			ViewmodelRig.solve(rig, handleCf, 1 - (1 - VM.ADS_CLIP_KICK) * adsT)
			-- The hands hold the gun's body: the handle frame plus the clip's
			-- Root motion, so when a clip rolls the gun in the hands (a draw,
			-- an inspect) the arms turn with it instead of the gun turning
			-- into them.
			local rootMotor = rig.rootMotor
			local body = rootMotor and rootMotor.Part1 and rig.world[rootMotor.Part1]
			handleCFrames[side] = if body and rootMotor
				then body * rootMotor.C1 * rootMotor.C0:Inverse()
				else handleCf

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
		holdWith(a, "Right", right, rightCf, gripR, tunedHand(rightHand, "Right"), false)

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
				tunedHand({
					offset = VM.RIFLE_LEFT_HAND.offset + (c.leftHandOffset or Vector3.zero),
					direction = VM.RIFLE_LEFT_HAND.direction,
				}, "Left"),
				false
			)
		elseif os.clock() < heavyUntil and right.rightGrip then
			-- Knife heavy stab: both hands on the handle.
			holdWith(a, "Left", right, rightCf, gripR, VM.MELEE_TWO_HAND, false)
		else
			-- Melee: the free hand is a guard, riding the root.
			local point = root:PointToWorldSpace(VM.FREE_HAND.offset)
			local toward = point + root:VectorToWorldSpace(VM.FREE_HAND.direction)
			ViewmodelArms.place(a, "Left", point, toward, root.RightVector)
		end
	end

	-- 3b. A held Mod's item, in the right hand.
	local held = item
	if held then
		local model = held:FindFirstChildOfClass("Model")
		if model then
			-- Raise (overshoots a little), breathing idle, then the use.
			raiseX, raiseV = springStep(
				raiseX,
				raiseV,
				if lowered then 1 else 0,
				VM.ITEM_RAISE_FREQUENCY,
				VM.ITEM_RAISE_DAMPING,
				dt
			)
			local idle = VM.ITEM_IDLE
			local phase = now * idle.rate * math.pi * 2
			local idleCf = CFrame.new(
				idle.pos * Vector3.new(math.sin(phase * 0.5), math.sin(phase), 0)
			) * angles(
				idle.rot
					* Vector3.new(math.sin(phase), math.sin(phase * 0.5), math.cos(phase * 0.5))
			)
			local useCf, gone = actionOffset(now)
			if gone ~= itemHidden then
				itemHidden = gone
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = if gone then 1 else 0
					end
				end
			end
			local pos = VM.ITEM_OFFSET + VM.ITEM_FROM * (1 - raiseX)
			local itemCf = root * CFrame.new(pos) * useCf * idleCf * angles(VM.ITEM_ROTATION)
			local offset = model:GetAttribute("HoldOffset")
			model:PivotTo(
				if typeof(offset) == "Vector3" then itemCf * CFrame.new(offset) else itemCf
			)
			if a and lowerT > 0.05 then
				local hand = itemCf.Position
				ViewmodelArms.place(
					a,
					"Right",
					hand,
					hand + root:VectorToWorldSpace(VM.ITEM_ARM),
					root.RightVector
				)
			end
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
		ViewmodelController.holdItem(nil)
		lowered = false
		lowerX, lowerV = 0, 0
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
