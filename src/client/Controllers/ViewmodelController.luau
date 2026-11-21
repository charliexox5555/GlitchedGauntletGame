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
--
-- Split out: the keyframed tracks (Util/ViewmodelTracks) and the held Mods:
-- lowered gun, item, gestures, free-hand poses (Util/ViewmodelHeldMods).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local RoundCarry = require(script.Parent.Parent.Util.RoundCarry)
local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local Types = require(ReplicatedStorage.Shared.Types)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)
local SkinPreview = require(ReplicatedStorage.Shared.SkinPreview)
local MeleeSkins = require(ReplicatedStorage.Shared.Config.MeleeSkins)

local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)
local MagDrop = require(script.Parent.Parent.Util.MagDrop)
local FanMotion = require(script.Parent.Parent.Util.FanMotion)
local KnifeSwipeFx = require(script.Parent.Parent.Util.KnifeSwipeFx)
local ShadowMistIdle = require(script.Parent.Parent.Util.ShadowMistIdle)
local TempestIdle = require(script.Parent.Parent.Util.TempestIdle)
local TempestKunai = require(script.Parent.Parent.Util.TempestKunai)
local SlipframeEffects = require(script.Parent.Parent.Util.SlipframeEffects)
local ShadowMistActions = require(script.Parent.Parent.Util.ShadowMistActions)
local ShadowMistStyle = require(ReplicatedStorage.Shared.Config.SkinPreview).SHADOW_MIST
local CosmeticInspect = require(script.Parent.Parent.Util.CosmeticInspect)
local LocalHide = require(script.Parent.Parent.Util.LocalHide)
local PopCircuitBat = require(script.Parent.Parent.Util.PopCircuitBat)
local RuinedReaver = require(script.Parent.Parent.Util.RuinedReaver)
local ViewmodelArms = require(script.Parent.Parent.Util.ViewmodelArms)
local ViewmodelHeldMods = require(script.Parent.Parent.Util.ViewmodelHeldMods)
local ViewmodelMotion = require(script.Parent.Parent.Util.ViewmodelMotion)
local SlideTilt = require(script.Parent.Parent.Util.SlideTilt)
local ViewmodelRig = require(script.Parent.Parent.Util.ViewmodelRig)
local ViewmodelTracks = require(script.Parent.Parent.Util.ViewmodelTracks)
local CameraController = require(script.Parent.CameraController)
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
-- `hold`: "both" stays on the part the whole clip; "out" / "in" skip the
-- ramp at that end (the hand carries on into / came from the next clip).
type FollowRule = {
	clip: string,
	hand: Side,
	anchor: Anchor,
	from: number,
	to: number,
	hold: string?,
}

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
	lensHide: { BasePart }, -- scoped guns: the scope's glass (VM.SCOPE_LENS)
	lensFade: number, -- last fade written to lensHide
	outline: Highlight?, -- the faint outline round the gun (VM.GUN_OUTLINE)
	outlineShown: number, -- the OutlineTransparency last written
	reticle: SurfaceGui?,
	props: { Prop }, -- parts hidden while their joint is far from rest (config hideBeyond)
	carries: { Carry }, -- rounds the support hand carries in during reloads (config carry)
	mags: { Mag }, -- removable mags / belt boxes: dropped on reloads (Util/MagDrop)
	key: string, -- pool key for its dropped mags
	lockPending: boolean, -- the last round went: lock the action once the Fire clip's recoil peaks
	recoil: Spring.Spring, -- hip kick
	adsRecoil: Spring.Spring, -- aimed kick (stiff, critically damped)
	-- Shot snap (VM.SHOT_PUNCH sizes, VM.SHOT_SNAP timing): each shot adds to
	-- a slow and a fast exponential; their difference is the kick (back studs,
	-- rise, yaw rad; and the twist), so it rises in ~13 ms and eases home.
	snapSlow: Vector3,
	snapFast: Vector3,
	snapRollSlow: number,
	snapRollFast: number,
	snapAttack: number, -- seconds
	snapDecay: number,
	snapHold: number, -- seconds the kick stays at its peak (VM.SHOT_SNAP `hold`)
	snapHeld: number, -- ...left of it
	climb: Spring.Spring, -- spray climb: rise, yaw (rad), follows `target`
	bounce: Spring.Spring, -- handling bounce (VM.HANDLE_BUMPS): drop (studs), pitch, roll (rad)
	lastShot: number, -- os.clock() of the last shot (the climb settles after a pause)
	sprayShots: number, -- shots in the current burst (VM.SPRAY_GAP starts a new one)
	batMotion: PopCircuitBat.Motion?,
	reaver: RuinedReaver.State?,
	batTrails: { Trail }?,
	fan: FanMotion.Fan?, -- the Giltfold Fan's ribs (Util/FanMotion)
	shadowMist: ShadowMistIdle.State?,
	tempest: TempestIdle.State?,
	slipframe: SlipframeEffects.State?,
	kunai: TempestKunai.State?, -- the Tempest-Strike Kunai-Katana (knife slot)
	shadowActions: ShadowMistActions.State?,
	cosmeticInspect: CosmeticInspect.State?,
}

type Prop = { motor: Motor6D, parts: { BasePart }, limit: number, hiddenNow: boolean }
type Carry = {
	joint: string,
	parts: { BasePart },
	show: string,
	hideAtRest: boolean,
	hiddenNow: boolean,
}

-- A mag during a reload clip: hidden from `outAt` (a copy drops) until the new
-- one shows at `inAt` (0..1 through `clip`).
type Mag = {
	bone: string,
	parts: { BasePart },
	clip: string?,
	timing: MagDrop.Timing?,
	seat: number?,
	empty: boolean?,
	seat: number?,
	gone: boolean,
}

-- A foley cue inside a clip: `at` is 0..1 through it.
export type Beat = {
	at: number,
	sound: "MagOut" | "MagIn" | "Rack" | "Open" | "Eject" | "ShellIn" | "Close",
}

type PoseWeight = { x: number, v: number, goal: number }

local SIDES: { Side } = { "Right", "Left" }

local guns: { [Side]: Gun } = {}
local config: WeaponConfig? = nil
local arms: ViewmodelArms.Arms? = nil
local armsLook = "" -- what the arms were built from
local nextLookCheck = 0

local playing: ViewmodelTracks.Set = {} -- keyframed tracks by slot (Util/ViewmodelTracks)
local poseWeights: { [string]: PoseWeight } = {}
local weights: { [string]: number } = {}

local adsAlpha = 0
-- The aim blend the gun is drawn at (VM.ADS_FEEL): the alpha's goal (0 hip, 1
-- sights) through an underdamped spring. May run a little past 0 or 1.
local adsGoal = 0
local adsBlend = 0
local adsBlendVel = 0
local adsZoom = 0 -- the camera's zoom blend: trails the gun (VM.ADS_FEEL zoomReach)
local adsZoomVel = 0
local adsStepAt = 0
local meleeIdle = 1 -- how much of the knife's idle drift shows (0 in a swing)
local hidden = false
local heavyFrom = 0 -- knife heavy stab: both hands on the handle from then...
local heavyUntil = 0 -- ...until then (VM.MELEE_HEAVY_HAND)
local freeHeavy = 0 -- knife free hand: 0 guard .. 1 on the handle (heavy stab)
local freeHidden = 0 -- knife free hand: 0 guard .. 1 dropped out of view (inspect)
local turnToken = 0 -- bumped to cancel akimbo turns waiting to start (playTurns)
local motion = ViewmodelMotion.new()
local motionInput: ViewmodelMotion.Input = {
	camera = CFrame.identity,
	velocity = Vector3.zero,
	grounded = true,
	sprinting = false,
	sliding = false,
	crouching = false,
	ads = 0,
}

-- Arm follow-through: each arm's direction (camera space) trails where the
-- gun asks it to point, on a critically damped spring (VM.ARM_FOLLOW). The
-- hand itself stays exactly on its grip; only the forearm lags, so a kick, a
-- sway or a pose change bends at the wrist instead of turning gun and arms as
-- one stiff piece. `frame` is the render frame it last ran (a gap = snap).
type ArmFollow = { dir: Vector3, vel: Vector3, frame: number }
local armFollow: { [Side]: ArmFollow } = {}
local frameIndex = 0
local frameDt = 1 / 60

local studio = RunService:IsStudio()

-- Held Mods: the gun lowered, the Mod's item in the right hand, gestures and
-- free-hand poses (Util/ViewmodelHeldMods).
local heldMods = ViewmodelHeldMods.new()

-- Small helpers ----------------------------------------------------------------

local angles = ViewmodelTracks.angles
local mirrorPos = ViewmodelTracks.mirrorPos
local mirrorRot = ViewmodelTracks.mirrorRot

-- Keyframed tracks (Util/ViewmodelTracks) -------------------------------------

-- The combined track offset for one gun (ViewmodelTracks.offset). `screen`:
-- only the tracks keyed on screen, which holdPose applies in camera axes.
local function trackOffset(gun: Gun, mirror: boolean, screen: boolean): CFrame
	return ViewmodelTracks.offset(playing, config, gun.centerRel, guns.Left ~= nil, mirror, screen)
end

-- Whose view this is: nil = yours; a fighter's body while you spectate them
-- in first person (SpectateController): their arms' look, their speed and
-- move state drive the rig.
local subject: Model? = nil
-- Whose skins the subject's gun wears: the player behind it (a replay copy
-- isn't a character, so ReplayController passes the killer); nil = stock.
local subjectOwner: Player? = nil

local function subjectBody(): Model?
	return subject or player.Character
end

-- Arms -------------------------------------------------------------------------

local function rebuildArms(cam: Camera?)
	if arms then
		arms.model:Destroy()
	end
	local built = ViewmodelArms.build(subjectBody())
	arms = built
	armsLook = ViewmodelArms.signature(subjectBody())
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
		-- Nothing visible rides this joint (the Ruin-Blighted guns have no bolt
		-- or charging handle to work: their clips still move the empty joint),
		-- so no hand goes to it. It used to go to the joint's origin, inside
		-- the receiver: the "arm goes through the gun" on the Ruin-Blighted
		-- Operator's bolt (owner 2026-11-21). First person only.
		return nil
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
	if gun.shadowActions and (rule.joint == "ChargingHandle" or rule.joint == "Mag") then
		return false
	end
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

-- A carried round's timing, with its pick-up moved VM.CARRY_JOIN of the
-- way in from the turnaround (the round stays hidden until then).
local function carryTiming(clip: any, joint: string, gunId: string): RoundCarry.Timing?
	local timing = RoundCarry.timing(clip, joint)
	local join = VM.CARRY_JOIN[gunId]
	if not timing or not join then
		return timing
	end
	local joined = table.clone(timing)
	joined.farTo = timing.farTo + (timing.arrive - timing.farTo) * math.clamp(join, 0, 0.9)
	return joined
end

local function buildFollow(gun: Gun, weapon: WeaponConfig, dual: boolean)
	if dual or weapon.fireMode == "Melee" then
		return -- each hand is busy holding its own gun / nothing to work
	end
	-- Carried rounds first: the support hand brings each fresh round in from
	-- off the screen (config carry), before it holds barrels or a crane.
	for _, entry in weapon.carry or {} do
		if entry.follow then
			for _, clip in { "Reload", "ReloadEmpty" } do
				local data = gun.animator.clips and (gun.animator.clips :: any)[clip]
				local timing = data and carryTiming(data, entry.joint, weapon.id)
				local anchor = timing
					and followAnchor(gun, { joint = entry.joint, grab = "Center" }, "Left")
				if timing and anchor then
					table.insert(gun.follow, {
						clip = clip,
						hand = "Left",
						anchor = anchor,
						from = timing.farTo,
						to = timing.arrive,
					})
				end
			end
		end
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
			-- hand's: the support hand would reach through the gun. On a lever
			-- gun the trigger hand works the lever, so only a round fed through
			-- a right-side gate (Shell) goes to it (round 3: the Marshal loads
			-- with the right hand while the left steadies the gun).
			-- (A lever or a pump drives the bolt: nobody works it by hand.)
			if not ((lever or weapon.fireMode == "Pump") and rule.joint == "Bolt") then
				local rightSide = partSide(gun, rule) > 0
				local hand: Side = if rule.joint == "Shell" and weapon.shellHand
					then weapon.shellHand
					elseif rightSide and (not lever or rule.joint == "Shell") then "Right"
					else "Left"
				addFollow(gun, clip, hand, rule)
			end
		end
	end
	-- Shell-by-shell loops (owner 2026-11-08: "the hand just jumps"): the
	-- loading hand stays at the gate for the whole loop, reaches it during
	-- ReloadStart and leaves it during ReloadEnd, instead of going back to its
	-- grip between shells.
	if weapon.shellReload then
		for _, rule in gun.follow do
			if rule.clip == "ReloadInsert" then
				rule.from, rule.to, rule.hold = 0, 1, "both"
				table.insert(gun.follow, {
					clip = "ReloadStart",
					hand = rule.hand,
					anchor = rule.anchor,
					from = VM.SHELL_GATE_REACH,
					to = 1,
					hold = "out",
				})
				table.insert(gun.follow, {
					clip = "ReloadEnd",
					hand = rule.hand,
					anchor = rule.anchor,
					from = 0,
					to = 1 - VM.SHELL_GATE_REACH,
					hold = "in",
				})
				break
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
	if rule.hold == "both" then
		return 1
	end
	local lead = VM.FOLLOW_LEAD
	local inStart = math.max(0, rule.from - lead)
	local inLength = math.max(rule.from - inStart, lead * 0.5)
	local outEnd = math.min(1, rule.to + lead)
	local outLength = math.max(outEnd - rule.to, lead * 0.5)
	local rampIn = if rule.hold == "in" then 1 else Ease.smooth((t - inStart) / inLength)
	local rampOut = if rule.hold == "out" then 1 else Ease.smooth((outEnd - t) / outLength)
	return rampIn * rampOut
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
	local actions = gun.shadowActions
	local cam = Workspace.CurrentCamera
	if not clip and hand == "Left" and actions and cam and actions.frame.spread > 0.001 then
		local spread = actions.frame.spread
		local release = cam.CFrame:VectorToWorldSpace(Vector3.new(-0.13, -0.28, 0.045))
		return base + release * spread, 0.46 * spread, nil
	end
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
	local rig = gun.rig
	if hand == "Left" and actions and actions.hand > 0 and rig then
		local well = actions.well
		local parent = well.Parent :: BasePart
		local cf = rig.world[parent] or parent.CFrame
		local magCf = rig.world[actions.mag] or actions.mag.CFrame
		local gather = cf:PointToWorldSpace(well.Position)
		local grip = magCf:PointToWorldSpace(actions.magGrip.Position)
		local target = gather:Lerp(grip, actions.handOnMag)
		if cam then
			-- Keep the wrist below the effect and route the forearm away from the magwell.
			local hold = actions.handOnMag
			local toss = actions.handCast
			local offset = Vector3.new(
				-0.03 - 0.035 * hold + 0.20 * toss,
				-0.25 + 0.16 * hold + 0.16 * toss,
				-0.028 - 0.08 * toss
			)
			target += cam.CFrame:VectorToWorldSpace(offset)
			local handle = rig.world[gun.handle] or gun.handle.CFrame
			reach = handle:VectorToObjectSpace(
				cam.CFrame:VectorToWorldSpace(Vector3.new(-0.64, -0.72, 0.2))
			).Unit
		end
		pos = pos:Lerp(target, actions.hand)
		working = math.max(working, actions.hand)
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
	-- Skin preview: the spectated player's pick when watching someone (a
	-- replay copy: the killer it was recorded from), else ours.
	local skinOwner: Player? = if subject then subjectOwner else player
	local botLine = SkinPreview.botLine(subject, templateId)
	if botLine then
		local variant, resolved = SkinPreview.resolve(templateId, botLine)
		template = variant or template
		botLine = resolved
	elseif SkinPreview.allowed() and skinOwner then
		template = SkinPreview.geometry(templateId, skinOwner) or template
	end
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("[Viewmodel] no model for " .. templateId)
		return nil
	end
	local clone = template:Clone()
	local skinItem = StateValues.get(template, "SkinItem")
	local scale = (weapon.viewmodelScale or VM.SCALE)
		* (if typeof(skinItem) == "string" then MeleeSkins.VIEWMODEL_SCALE[skinItem] or 1 else 1)
	local isBat = StateValues.get(template, "PreviewMeleeModel") == "Bat"
	clone:ScaleTo(if isBat then 1 else scale)
	local h = clone.PrimaryPart :: BasePart
	-- Same contents, but in a WorldModel (exact part positions, see the top).
	local m = Instance.new("WorldModel")
	m.Name = name
	StateValues.inheritDefaults(m, clone)
	for _, child in clone:GetChildren() do
		child.Parent = m
	end
	m.PrimaryPart = h
	StateValues.set(m, SkinPreview.OWNER_ATTRIBUTE, if skinOwner then skinOwner.UserId else 0)
	if botLine then
		StateValues.set(m, "SkinLine", botLine)
	end
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
	-- Scoped guns: the scope's glass leaves before its eyepiece reaches the
	-- middle of the view (owner 2026-11-20: a reflective part showed there).
	local lensHide: { BasePart } = {}
	if weapon.scope then
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and table.find(VM.SCOPE_LENS.names, d.Name) then
				table.insert(lensHide, d)
			end
		end
	end
	local gun: Gun = {
		model = m,
		handle = h,
		rig = nil,
		animator = GunAnimator.new(m, if isBat then "Bat" else templateId, scale),
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
		lensHide = lensHide,
		lensFade = 0,
		outline = nil,
		outlineShown = -1,
		reticle = reticle,
		props = {},
		carries = {},
		mags = {},
		key = name .. weapon.id,
		lockPending = false,
		recoil = Spring.new(VM.RECOIL_STIFFNESS, VM.RECOIL_DAMPING),
		adsRecoil = Spring.new(VM.ADS_RECOIL_STIFFNESS, 2 * math.sqrt(VM.ADS_RECOIL_STIFFNESS)),
		snapSlow = Vector3.zero,
		snapFast = Vector3.zero,
		snapRollSlow = 0,
		snapRollFast = 0,
		snapAttack = (VM.SHOT_SNAP.gun[weapon.id] or {}).attack or VM.SHOT_SNAP.attack,
		snapDecay = (VM.SHOT_SNAP.gun[weapon.id] or {}).decay
			or VM.SHOT_SNAP.decay[weapon.class]
			or VM.SHOT_SNAP.decay.Rifle,
		snapHold = (VM.SHOT_SNAP.gun[weapon.id] or {}).hold or 0,
		snapHeld = 0,
		climb = Spring.new(
			VM.CLIMB_STIFFNESS,
			2 * VM.CLIMB_DAMPING_RATIO * math.sqrt(VM.CLIMB_STIFFNESS)
		),
		bounce = Spring.new(VM.HANDLE_STIFFNESS, VM.HANDLE_DAMPING),
		lastShot = 0,
		sprayShots = 0,
	}
	if isBat then
		gun.batMotion = PopCircuitBat.play("Idle")
		local trails: { Trail } = {}
		for _, child in m:GetChildren() do
			if child:IsA("Trail") then
				table.insert(trails, child)
			end
		end
		gun.batTrails = trails
	end
	gun.fan = FanMotion.new(m)
	gun.reaver = RuinedReaver.new(m, scale)
	gun.shadowMist = if gun.reaver then nil else ShadowMistIdle.new(m, scale)
	gun.tempest = TempestIdle.new(m, scale)
	if templateId == "Guardian" and StateValues.get(m, "SkinLine") == "Slipframe" then
		gun.slipframe = SlipframeEffects.new(m, scale)
	end
	gun.kunai = TempestKunai.new(m, scale)
	gun.shadowActions = ShadowMistActions.new(m, scale, weapon.id)
	gun.cosmeticInspect = CosmeticInspect.new(m)
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
	for _, entry in weapon.carry or {} do
		local joint = rigJoint(m, entry.joint)
		if joint then
			local parts: { BasePart } = {}
			for _, d in m:GetDescendants() do
				if (d:IsA("Weld") or d:IsA("Motor6D")) and d.Part0 == joint then
					local p = d.Part1
					if p and p.Parent ~= joint.Parent and p.Transparency < 1 then
						table.insert(parts, p)
					end
				end
			end
			table.insert(gun.carries, {
				joint = entry.joint,
				parts = parts,
				show = entry.show,
				hideAtRest = weapon.carryHideAtRest == true,
				hiddenNow = false,
			})
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
local function adsDistanceOf(weapon: WeaponConfig, model: Model): number
	local live = if studio then StateValues.get(Workspace, "VmAdsDistance") else nil
	if typeof(live) == "number" then
		return live
	end
	local skinDistance = StateValues.get(model, "SkinAdsDistance")
	if typeof(skinDistance) == "number" then
		return skinDistance
	end
	return weapon.adsDistance or VM.ADS_DISTANCE
end

-- Stock parts that pass by the eye while aiming: reaching from behind the eye
-- to in front of it, the camera's near plane would slice them open, so they
-- fade out while aimed. (Only stocks: parts are merged by material, so a
-- receiver or sights mesh also runs past the eye; guns move the eye back
-- with adsDistance instead.)
-- In the ADS pose the gun is aligned with the camera, so a handle-space point
-- sits at depth distance - (p - aim).Z in front of the eye.
local function findNearPlaneParts(gun: Gun, distance: number, adsOffset: Vector3): { BasePart }
	local found: { BasePart } = {}
	local h = gun.handle.CFrame
	local eyeZ = gun.aimRel.Z - adsOffset.Z + distance
	for _, d in gun.model:GetDescendants() do
		local fades = false
		for _, prefix in VM.ADS_FADE_PREFIXES do
			if string.sub(d.Name, 1, #prefix) == prefix then
				fades = true
			end
		end
		if fades and d:IsA("BasePart") and d.Transparency < 1 then
			local near, far = math.huge, -math.huge
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = d.CFrame
							* Vector3.new(sx * d.Size.X, sy * d.Size.Y, sz * d.Size.Z)
							/ 2
						local depth = eyeZ - h:PointToObjectSpace(corner).Z
						near = math.min(near, depth)
						far = math.max(far, depth)
					end
				end
			end
			if near < VM.ADS_NEAR and far > VM.ADS_NEAR and near < 0 then
				table.insert(found, d)
			end
		end
	end
	return found
end

-- Called once the gun is in the workspace (raycasts need it there).
local function finishGun(gun: Gun, weapon: WeaponConfig)
	if not weapon.noAds then
		local distance = adsDistanceOf(weapon, gun.model)
		local offset = weapon.adsOffset or Vector3.zero
		for _, list in
			{ findOccluders(gun, distance, offset), findNearPlaneParts(gun, distance, offset) }
		do
			for _, p in list do
				if not table.find(gun.adsHide, p) then
					table.insert(gun.adsHide, p)
				end
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
				LocalHide.set(d, modifier)
			end
		end
		gun.adsFade = -1 -- rewrite ADS fades next frame
		gun.lensFade = -1
	end
end

-- API ----------------------------------------------------------------------------

-- The viewmodel's clock speed (the final-kill replay's slow motion: its
-- kick, sway and clips slow down with the world). 1 = real time.
local timeScale = 1
function ViewmodelController.setTimeScale(scale: number)
	timeScale = if scale == scale then math.clamp(scale, 0, 1) else 1
end
function ViewmodelController.unequip()
	turnToken += 1
	KnifeSwipeFx.cancel() -- a cut-short slash's streak goes with it
	ViewmodelHeldMods.dropGestureProp(heldMods)
	for _, gun in guns do
		if gun.shadowActions then
			ShadowMistActions.endInspect(gun.shadowActions)
		elseif gun.reaver then
			RuinedReaver.play(gun.reaver, "Idle")
		end
		gun.model:Destroy()
	end
	guns = {}
	config = nil
	table.clear(playing)
	if arms then
		arms.model.Parent = nil
	end
end

function ViewmodelController.hasShadowMist(): boolean
	local right = guns.Right
	return right ~= nil and right.shadowActions ~= nil
end

-- The clip markers (gg_markers, set in Blender) that are foley beats, and
-- the sound each plays. A clip with a marker uses it instead of guessing the
-- moment from its moving joints.
local MARKER_BEATS: { [string]: "MagOut" | "MagIn" | "Rack" | "Open" | "Eject" | "ShellIn" | "Close" } =
	{
		MagOut = "MagOut",
		MagIn = "MagIn",
		Open = "Open",
		RoundOut = "Eject",
		RoundIn = "ShellIn",
		ShellIn = "ShellIn",
		Close = "Close",
		Rack = "Rack",
	}

-- Foley cues read off a clip: the mag leaving and seating, the charging
-- handle (or bolt, or a pistol's slide) slamming home. Empty when the gun has no such clip.
local function clipBeats(gun: Gun, clip: string): { Beat }
	local beats: { Beat } = {}
	local animator = gun.animator
	local data = animator.clips and (animator.clips :: any)[clip]
	local marks: { [string]: any } = (data and data.markers) or {}
	for name, sound in MARKER_BEATS do
		local at = marks[name]
		if typeof(at) == "number" then
			-- 2026-11-13 (lane B, measured from the clip data): the exported
			-- MagIn markers sit mid-travel (Vandal .302, mag seated .454;
			-- Phantom .394 / .611; Classic .39 / .65), so the clack and the
			-- slap came before the mag reached the gun. The beat is where the
			-- mag stops moving.
			if sound == "MagIn" then
				for _, joint in { "Mag", "AmmoBox" } do
					local _, magTo = animator:activity(clip, joint)
					if magTo then
						at = math.max(at, magTo - VM.BEAT_MAG_IN)
						break
					end
				end
			end
			table.insert(beats, { at = at, sound = sound })
		end
	end
	local hasMark = function(...: string): boolean
		for _, name in { ... } do
			if typeof(marks[name]) == "number" then
				return true
			end
		end
		return false
	end
	-- Mags and belt boxes: out as they start moving, in as they stop. A belt
	-- feed cover opens, then latches shut.
	if not hasMark("MagOut", "MagIn") then
		for _, joint in { "Mag", "AmmoBox" } do
			local magFrom, magTo = animator:activity(clip, joint)
			if magFrom and magTo then
				table.insert(beats, { at = magFrom + VM.BEAT_MAG_OUT, sound = "MagOut" })
				table.insert(
					beats,
					{ at = math.max(magTo - VM.BEAT_MAG_IN, magFrom), sound = "MagIn" }
				)
			end
		end
	end
	local coverFrom, coverTo = animator:activity(clip, "FeedCover")
	if coverFrom and coverTo then
		table.insert(beats, { at = coverFrom + VM.BEAT_MAG_OUT, sound = "Open" })
		table.insert(beats, { at = math.max(coverTo - VM.BEAT_RACK, coverFrom), sound = "Close" })
	end
	for _, joint in { "ChargingHandle", "Bolt", "Slide", "Lever" } do
		local _, to = animator:activity(clip, joint)
		if to then
			table.insert(beats, { at = math.max(to - VM.BEAT_RACK, 0), sound = "Rack" })
			break
		end
	end
	-- Break-actions and revolvers: open as the barrels drop / the cylinder
	-- swings out, shut as they close, the spent cases out as a revolver's
	-- ejector rod pushes, and a shell-in as each round settles.
	if not hasMark("Open", "Close") then
		for _, joint in { "Barrels", "Crane" } do
			local openFrom, openTo = animator:activity(clip, joint)
			if openFrom and openTo then
				table.insert(beats, { at = openFrom + VM.BEAT_MAG_OUT, sound = "Open" })
				table.insert(
					beats,
					{ at = math.max(openTo - VM.BEAT_RACK, openFrom), sound = "Close" }
				)
			end
		end
	end
	local ejectFrom = animator:activity(clip, "EjectorRod")
	if ejectFrom and not hasMark("RoundOut") then
		table.insert(beats, { at = ejectFrom + VM.BEAT_MAG_OUT, sound = "Eject" })
	end
	-- Rounds going in: the clip's ShellIn / RoundIn marker when it has one,
	-- else as each round prop stops moving.
	if hasMark("ShellIn", "RoundIn") then
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

-- Handling bounce -----------------------------------------------------------------

-- A spring at rest hit by velocity v peaks at v * HANDLE_PEAK.
local HANDLE_PEAK = (function(): number
	local omega = math.sqrt(VM.HANDLE_STIFFNESS)
	local zeta = math.min(VM.HANDLE_DAMPING / (2 * omega), 0.99)
	local root = math.sqrt(1 - zeta * zeta)
	return math.exp(-zeta * math.atan2(root, zeta) / root) / omega
end)()

-- Beats still to come (os.clock() times); `token` is the turnToken they were
-- queued under, so a cancelled reload's kicks never land.
local pendingBumps: { { at: number, kind: string, token: number } } = {}

-- Kicks every gun's handling spring (VM.HANDLE_BUMPS): the snap on a beat.
local function bump(kind: string)
	-- Tempest-Strike: the shell, lever and revolver guns' beats as water (Util/TempestIdle)
	local right = guns.Right
	if right and right.tempest then
		TempestIdle.beat(right.tempest, kind)
	end
	if right and right.slipframe and kind == "MagIn" then
		SlipframeEffects.pulse(right.slipframe, "Seat")
	end
	local b = VM.HANDLE_BUMPS[kind]
	if not b then
		return
	end
	local v = Vector3.new(b.drop, math.rad(b.pitch), math.rad(b.roll)) / HANDLE_PEAK
	for _, gun in guns do
		gun.bounce:impulse(v)
	end
end

-- Queues a clip's beats (0..1 through `duration`) as kicks.
local function queueBumps(beats: { Beat }, duration: number)
	local now = os.clock()
	for _, beat in beats do
		table.insert(
			pendingBumps,
			{ at = now + duration * beat.at, kind = beat.sound, token = turnToken }
		)
	end
end

-- Queues one kick `delay` seconds from now.
local function queueBump(kind: string, delay: number)
	table.insert(pendingBumps, { at = os.clock() + delay, kind = kind, token = turnToken })
end

local function stepBumps(now: number)
	for i = #pendingBumps, 1, -1 do
		local p = pendingBumps[i]
		if p.token ~= turnToken then
			table.remove(pendingBumps, i)
		elseif now >= p.at then
			table.remove(pendingBumps, i)
			bump(p.kind)
		end
	end
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

-- Track beats that stand in for each other (revolvers, break-actions).
local MARK_STAND_INS: { [string]: { string } } = {
	MagOut = { "MagOut", "Open" },
	MagIn = { "MagIn", "Close" },
	Rack = { "Rack" },
}

-- Lines the track in `slot` up with the gun clip's beats (VM.Track marks):
-- its keys are time-warped, piecewise linear, so the track's mag slap lands
-- on the clip's mag going in and its muzzle kick on the clip's rack. Akimbo
-- pairs (beats in turns) and tracks without marks play as authored.
local function alignTrack(slot: string, beats: { Beat })
	local p = playing[slot]
	local marks = p and p.track.marks
	if not p or not marks or guns.Left then
		return
	end
	local anchors: { { number } } = {}
	for name, at in marks do
		for _, wanted in MARK_STAND_INS[name] or { name } do
			local found: number? = nil
			for _, b in beats do
				if b.sound == wanted and (found == nil or b.at < found) then
					found = b.at
				end
			end
			if found then
				table.insert(anchors, { at, found })
				break
			end
		end
	end
	if #anchors == 0 then
		return
	end
	table.sort(anchors, function(a, b)
		return a[1] < b[1]
	end)
	-- Keep the anchors whose clip times also rise (a beat out of order is
	-- dropped rather than folding the track back on itself).
	local map: { { number } } = { { 0, 0 } }
	for _, a in anchors do
		local last = map[#map]
		if a[1] > last[1] and a[2] > last[2] and a[1] < 1 and a[2] < 1 then
			table.insert(map, a)
		end
	end
	table.insert(map, { 1, 1 })
	local function warp(t: number): number
		for i = 2, #map do
			local a, b = map[i - 1], map[i]
			if t <= b[1] then
				return a[2] + (t - a[1]) / (b[1] - a[1]) * (b[2] - a[2])
			end
		end
		return t
	end
	local track = table.clone(p.track)
	local keys: { VM.Key } = {}
	for i, k in p.track.keys do
		local copy = table.clone(k)
		copy.t = warp(k.t)
		keys[i] = copy
	end
	track.keys = keys
	p.track = track
end

export type EquipOptions = {
	-- Already in their hands (spectating someone who has it out, a replay's
	-- start, a skin swap): the gun and arms come up at rest, with no draw.
	instant: boolean?,
}

-- Equips `weapon`: every equip plays the gun's "Draw" clip (raise and rack
-- the action), when it has one; otherwise a quick raise.
-- `duration`: the client's ready time. Returns the clip's foley cues.
function ViewmodelController.equip(
	weapon: WeaponConfig,
	duration: number?,
	opts: EquipOptions?
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
		if VM.GUN_OUTLINE.enabled then
			local h = Instance.new("Highlight")
			h.Name = "GunOutline"
			h.FillTransparency = 1
			h.OutlineColor = VM.GUN_OUTLINE.color
			h.OutlineTransparency = 1
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = gun.model
			gun.outline = h
		end
	end

	config = weapon
	hidden = false
	if not arms or armsLook ~= ViewmodelArms.signature(subjectBody()) then
		rebuildArms(cam)
	end
	local a = arms :: ViewmodelArms.Arms
	a.model.Parent = cam
	ViewmodelArms.setVisible(a, true)
	if opts and opts.instant then
		-- finishGun left each gun at its rest (the bat on its Idle); no Draw
		-- clip, track or landing bump, and the knife's free hand is up.
		freeHidden = 0
		return {}
	end
	local time = duration or weapon.equipTime
	if right.reaver then
		RuinedReaver.play(right.reaver, "Draw")
		return {}
	end
	if right.batMotion then
		-- The bat's own pull-out (Util/PopCircuitBat Draw), then its idle.
		right.batMotion = PopCircuitBat.play("Draw", time)
		return {}
	end
	-- The knife's pull-out is its own screen-keyed track (VM.MELEE_DRAW_TRACK;
	-- owner 2026-11-08: the Blender Draw clip's slow twirl read as an
	-- unnatural 360). The free arm starts out of view and comes up last.
	local drawTrack = VM.MELEE_DRAW_TRACK
	if right.fan then
		FanMotion.play(right.fan, "Draw", time)
	end
	if weapon.fireMode == "Melee" and VM.TRACKS[drawTrack] then
		ViewmodelTracks.play(playing, "Equip", drawTrack, time)
		freeHidden = 1
		return {}
	end
	if right.animator:has("Draw") then
		playTurns("Draw", time)
		-- Each class comes in its own way (VM.DRAW_TRACK).
		local tempestDraw = if right.tempest then TempestIdle.track(right.tempest, "draw") else nil
		local draw = if right.shadowActions
			then "DrawRuin" .. weapon.id
			elseif tempestDraw then tempestDraw
			else VM.DRAW_TRACK[weapon.class] or "Draw"
		ViewmodelTracks.play(playing, "Equip", draw, time)
		local beats = turnBeats(clipBeats(right, "Draw"))
		alignTrack("Equip", beats)
		queueBumps(beats, time)
		-- The gun lands in the hands with a bounce as it arrives (at the
		-- start it is still below the screen).
		queueBump(
			"Draw",
			time * (if right.shadowActions then ShadowMistStyle.DRAW_LOCK else VM.DRAW_BUMP_AT)
		)
		return beats
	end
	local raise = math.max(time * 1.4, VM.TRACKS.Equip.length)
	ViewmodelTracks.play(playing, "Equip", "Equip", raise)
	queueBump("Draw", raise * VM.DRAW_BUMP_AT)
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

-- The shot snap's peak as a share of what a shot adds (slow minus fast
-- exponential, attack a and decay d seconds), so SHOT_PUNCH stays the peak.
local function snapPeak(a: number, d: number): number
	if d <= a then
		return 1
	end
	local t = math.log(d / a) * a * d / (d - a)
	return math.exp(-t / d) - math.exp(-t / a)
end
local CLIMB_SETTLE_AFTER = 0.12 -- s without a shot before the spray climb starts settling

-- The shot punch for a gun: its own entry, else its class's (VM.SHOT_PUNCH).
local function shotPunch(c: WeaponConfig?): { [string]: number }?
	if not c then
		return nil
	end
	return VM.SHOT_PUNCH_GUN[c.id] or VM.SHOT_PUNCH[c.class]
end

-- `lean`: which way this shot's camera recoil pulls sideways (-1 left, 0
-- straight up, 1 right), so the gun's kick goes the same way.
function ViewmodelController.fire(kickScale: number, side: Side?, empty: boolean?, lean: number?)
	local gun = guns[side or "Right"] or guns.Right
	if not gun then
		return
	end
	if playing.Inspect then
		ViewmodelController.cancelInspect()
	end
	gun.animator:play("Fire")
	if gun.shadowActions then
		ShadowMistActions.fire(gun.shadowActions)
	end
	if gun.tempest then
		TempestIdle.fire(gun.tempest)
	end
	if gun.slipframe then
		SlipframeEffects.pulse(gun.slipframe, "Fire")
	end
	gun.lockPending = empty == true
		and config ~= nil
		and config.lockOnEmpty == true
		and gun.animator:has("ReloadEmpty")
	local up = if config then config.recoil.up else 1
	local k = math.clamp(up, 0.3, 4) * kickScale
	gun.recoil:impulse(Vector3.new(
		VM.KICK_BACK * 40 * k,
		VM.KICK_ROTATE * 40 * k,
		(math.random() - 0.5) * VM.KICK_ROTATE * 6 * k -- a small twist (was x20: it read as random)
	))
	-- Texture in a long spray (VM.SPRAY_FIRST, SHOT_VARY): the first shots of
	-- an automatic burst slam harder, and every shot's size varies a little,
	-- so a spray reads as shots, not as a hum.
	local now = os.clock()
	if now - gun.lastShot > VM.SPRAY_GAP then
		gun.sprayShots = 0
	end
	gun.sprayShots += 1
	local size = 1 + (math.random() * 2 - 1) * VM.SHOT_VARY
	if config and config.fireMode == "Auto" and VM.SPRAY_FIRST_SHOTS > 0 then
		local first = math.max(0, 1 - (gun.sprayShots - 1) / VM.SPRAY_FIRST_SHOTS)
		size *= 1 + (VM.SPRAY_FIRST - 1) * first
	end
	-- Aimed kick (VM.ADS_PUNCH): sized by class, not by the camera recoil, so
	-- an aimed shot pushes the gun toward your eye every time; its rise is
	-- small, so the sight stays on target. A critically damped spring hit by
	-- v peaks at v / (omega * e). `kickScale` arrives halved while aimed
	-- (WeaponController), so that is taken back out here.
	local aimed = if config then VM.ADS_PUNCH_GUN[config.id] or VM.ADS_PUNCH[config.class] else nil
	if aimed then
		local scale = kickScale / math.max(1 - 0.5 * adsAlpha, 0.5) * size
		local peak = math.sqrt(VM.ADS_RECOIL_STIFFNESS) * math.exp(1) * scale
		gun.adsRecoil:impulse(
			Vector3.new(
				aimed.back,
				math.rad(aimed.rise),
				(math.random() - 0.5) * math.rad(aimed.rise) * VM.ADS_PUNCH_TWIST
			) * peak
		)
	end
	-- The screen's own jolt (Juice SHOT_FEEL.viewPunch): look only, never the aim.
	if config then
		local feel = Juice.SHOT_FEEL
		local vp = feel.viewPunchGun[config.id] or feel.viewPunch[config.class]
		if vp then
			local aimScale = 1 - (1 - feel.adsScale) * adsAlpha
			CameraController.viewPunch(vp.degrees * aimScale * math.min(size, 1.4), vp.time)
		end
	end
	-- The shot punch: sized by class, not by the camera recoil. Its sideways
	-- part follows the spray (`lean`: the side the camera recoil pulls, -1
	-- left .. 1 right), with a little jitter; it never picks a side at random.
	local p = shotPunch(config)
	if p then
		-- kickScale already includes the gun's viewmodelKick (WeaponController).
		local s = kickScale * VM.PUNCH_SCALE
		local pull = math.clamp(lean or 0, -1, 1)
		local function jitter(): number
			return (math.random() - 0.5) * 2 * VM.PUNCH_JITTER
		end
		-- The muzzle goes the way the recoil pulls (a positive gun yaw is left).
		local turn = -(pull * VM.PUNCH_LEAN + jitter())
		local twist = -(pull * VM.PUNCH_ROLL_LEAN + jitter())
		-- A snap, not a spring (2026-11-14, owner's clips: every gun peaks in one
		-- frame and eases home in 0.1-0.2 s with no wobble; the spring peaked at
		-- ~42 ms and overshot): each shot adds to both exponentials.
		-- (A held kick reaches the whole of the slow one, so it needs no gain.)
		local gain = s / (if gun.snapHold > 0 then 1 else snapPeak(gun.snapAttack, gun.snapDecay))
		gun.snapHeld = gun.snapHold
		local add = Vector3.new(p.back * size, math.rad(p.rise) * size, math.rad(p.yaw) * turn)
			* gain
		gun.snapSlow += add
		gun.snapFast += add
		local twistAdd = math.rad(p.roll) * twist * gain
		gun.snapRollSlow += twistAdd
		gun.snapRollFast += twistAdd
		if p.climb > 0 then
			local t = gun.climb.target
			gun.climb.target = Vector3.new(
				math.min(t.X + math.rad(p.climb) * s, math.rad(p.climbMax) * VM.PUNCH_CLIMB_SCALE),
				math.clamp(
					t.Y + math.rad(p.climb) * 0.35 * turn,
					-math.rad(p.climbMax) * 0.5,
					math.rad(p.climbMax) * 0.5
				),
				0
			)
		end
	end
	gun.lastShot = now
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
	local beats = turnBeats(clipBeats(right, clip))
	local rackAt = 1
	for _, beat in beats do
		if beat.sound == "Rack" then
			rackAt = math.min(rackAt, beat.at)
		end
	end
	local seatAt: number? = nil
	local outAt: number? = nil
	playTurns(clip, duration, function(gun)
		local data = gun.animator.clips and (gun.animator.clips :: any)[clip]
		for _, mag in gun.mags do
			mag.clip = clip
			mag.timing = if data then MagDrop.timing(data, mag.bone) else nil
			mag.seat = nil
			mag.empty = empty == true
			local actions, timing = gun.shadowActions, mag.timing
			if actions and timing and mag.bone == "Mag" then
				if actions.hero then
					mag.timing = { outAt = timing.outAt, inAt = ShadowMistStyle.RELOAD_FORM }
					mag.seat = ShadowMistStyle.RELOAD_SEAT
				elseif timing.inAt - timing.outAt >= 0.10 then
					local seat =
						math.max(timing.inAt, math.min(actions.profile.seat, rackAt - 0.045))
					mag.seat = seat
					mag.timing = {
						outAt = timing.outAt,
						inAt = timing.outAt + (seat - timing.outAt) * actions.profile.form,
					}
				end
				seatAt = mag.seat
				outAt = timing.outAt
			end
		end
	end)
	-- A gun with its own reload track (VM.TRACKS["Reload" .. id], e.g. the
	-- Outlaw's break-action) uses it for both reloads; others share the one
	-- for their clip.
	local own = if config then VM.TRACKS["Reload" .. config.id] else nil
	local tempestReload = if right.tempest then TempestIdle.track(right.tempest, "reload") else nil
	local trackName = if right.shadowActions and right.shadowActions.hero
		then "ReloadShadowMist"
		elseif right.shadowActions and config then "ReloadRuin" .. config.id
		elseif tempestReload then tempestReload
		elseif own and config then "Reload" .. config.id
		elseif clip == "ReloadEmpty" then "ReloadEmpty"
		else "Reload"
	ViewmodelTracks.play(
		playing,
		"Reload",
		trackName,
		duration,
		if config
				and not tempestReload
				and (not right.shadowActions or right.shadowActions.hero)
			then VM.RELOAD_TRACK_TURN[config.id]
			else nil
	)
	if seatAt then
		for _, beat in beats do
			if beat.sound == "MagIn" then
				beat.at = seatAt
			elseif
				beat.sound == "MagOut"
				and outAt
				and not (right.shadowActions and right.shadowActions.hero)
			then
				beat.at = outAt
			end
		end
		table.sort(beats, function(a, b)
			return a.at < b.at
		end)
	end
	alignTrack("Reload", beats)
	queueBumps(beats, duration)
	return beats
end

local RELOAD_CLIPS = { "Reload", "ReloadEmpty", "ReloadStart", "ReloadInsert", "ReloadEnd" }

function ViewmodelController.cancelReload()
	turnToken += 1
	for _, gun in guns do
		local held = gun.animator.holding
		if held and table.find(RELOAD_CLIPS, held) then
			gun.animator:stop()
		end
		for _, clip in RELOAD_CLIPS do
			if gun.animator:isPlaying(clip) then
				gun.animator:stop()
				break
			end
		end
	end
	ViewmodelTracks.fade(playing, "Reload")
end

-- Plays one of the gun's clips over `duration` (the parts of a shell-by-shell
-- reload). Returns its foley cues.
function ViewmodelController.playClip(clip: string, duration: number): { Beat }
	ViewmodelController.cancelInspect()
	local right = guns.Right
	if not right or not right.animator:has(clip) then
		return {}
	end
	-- A shell loop's Start and Insert end in the loading pose the next clip
	-- starts from: hold it, or the gun snaps back to rest between shells.
	local holdEnd = clip == "ReloadStart" or clip == "ReloadInsert"
	for _, gun in guns do
		gun.animator:play(clip, duration, holdEnd)
	end
	local beats = clipBeats(right, clip)
	queueBumps(beats, duration)
	if clip == "ReloadEnd" then
		queueBump("Settle", duration * VM.SHELL_END_SETTLE_AT)
	end
	return beats
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
	local own = attack and VM.TRACKS[attack]
	local length = own and own.length or 0
	if right and right.reaver then
		return RuinedReaver.play(right.reaver, attack or "Slash1")
	end
	if right and right.batMotion then
		local heavy = attack == "HeavyStab"
		-- The side follows the combo step, like the knife's (Slash2 is the
		-- backhand): the view's lead, the streak and the wall mark are drawn
		-- for that step's path. (Until 2026-11-15 the bat took turns on its
		-- own, so it could swing backhand under a forehand's camera and streak.)
		local name = if heavy
			then "Smash"
			elseif attack == "Slash2" then "SlashRight"
			else "SlashLeft"
		local bat = PopCircuitBat.play(name, if length > 0 then length else nil)
		right.batMotion = bat
		return PopCircuitBat.hitDelay(bat)
	end
	if right and own and own.own then
		-- The keyed track is the whole attack (Config/Viewmodel, 2026-11-05).
		if right.animator:isPlaying() then
			right.animator:stop()
		end
		ViewmodelTracks.play(playing, "Swing", attack :: string, own.length, 1)
		hitDelay = (own.hit or 0) * own.length
	elseif right then
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
				ViewmodelTracks.play(playing, "Swing", attack :: string, length, 0)
			end
		else
			right.animator:play("Fire")
			if attack and VM.TRACKS[attack] then
				ViewmodelTracks.play(playing, "Swing", attack)
			end
		end
	end
	if right and right.fan then
		FanMotion.play(
			right.fan,
			if attack == "HeavyStab" then "Heavy" else "Slash",
			if length > 0 then length else nil,
			if own then own.hit else nil
		)
	end
	-- The free hand comes in for the thrust only (owner's knife clip, 2026-11-14).
	local window = VM.MELEE_HEAVY_HAND
	local started = os.clock()
	heavyFrom = started + window.from * length
	heavyUntil = if attack == "HeavyStab" and VM.MELEE_HEAVY_TWO_HAND
		then started + window.to * length
		else 0
	return hitDelay
end

-- Plays the inspect (Valorant / Phantom Forces style). Returns false when the
-- gun is busy (equipping, reloading, firing a clip, aiming).
function ViewmodelController.inspect(): boolean
	local c = config
	if not c or not guns.Right or hidden or adsAlpha > 0.05 then
		return false
	end
	if playing.Equip or playing.Reload or (playing.Swing and not playing.Swing.fading) then
		return false
	end
	-- Pressing inspect again restarts it from the top (owner 2026-11-12:
	-- "you can just spam it to restart the inspect, I want that"). Only an
	-- inspect restarts: a draw, reload or swing still blocks it.
	local bat = guns.Right.batMotion
	local reaver = guns.Right.reaver
	if reaver then
		if reaver.name ~= "Idle" and reaver.name ~= "Inspect" then
			return false
		end
		RuinedReaver.play(reaver, "Inspect")
		return true
	end
	if bat then
		if bat.name ~= "Idle" and bat.name ~= "Inspect" then
			return false
		end
		guns.Right.batMotion = PopCircuitBat.play("Inspect")
		return true
	end
	local again = playing.Inspect ~= nil
	for _, gun in guns do
		if gun.animator:isPlaying() and not gun.animator:isPlaying("Inspect") then
			return false
		end
		if gun.animator:isPlaying("Inspect") then
			again = true
		end
	end
	if again then
		ViewmodelController.cancelInspect()
	end
	local track = if guns.Right.shadowActions
		then guns.Right.shadowActions.profile.inspectTrack
		elseif
			guns.Right.tempest and TempestIdle.track(guns.Right.tempest, "inspect")
		then TempestIdle.track(guns.Right.tempest, "inspect") :: string
		elseif guns.Right.slipframe then "InspectSlipframe"
		elseif guns.Right.fan then "InspectFan"
		elseif c.fireMode == "Melee" then "InspectMelee"
		else VM.INSPECT_TRACK[c.id] or "Inspect"
	-- Akimbo: each gun gets a whole inspect, one after the other.
	local length = VM.TRACKS[track].length * (if guns.Left then 2 else 1)
	-- A track that owns the move turns the gun itself; otherwise a knife's own
	-- Inspect clip turns the blade and the track only lifts it into view.
	local ownTrack = VM.TRACKS[track].own == true
	local clipTurns = not ownTrack and c.fireMode == "Melee" and guns.Right.animator:has("Inspect")
	ViewmodelTracks.play(playing, "Inspect", track, length, if clipTurns then 0 else 1)
	if guns.Right.fan then
		FanMotion.play(guns.Right.fan, "Inspect", length)
	end
	-- The gun's own Inspect clip (a press check, the charm swinging) runs
	-- alongside, over the same time.
	if not ownTrack and guns.Right.animator:has("Inspect") then
		playTurns("Inspect", length)
	end
	-- A part rolled as the inspect starts, with its sound (VM.INSPECT_SPIN).
	local roll = VM.INSPECT_SPIN[c.id]
	if roll then
		for _, gun in guns do
			gun.animator:spin(roll.bone, roll.degrees, roll.seconds, roll.axis)
		end
	end
	return true
end

function ViewmodelController.cancelInspect()
	local right = guns.Right
	if right and right.shadowActions then
		ShadowMistActions.endInspect(right.shadowActions)
	end
	if right and right.batMotion and right.batMotion.name == "Inspect" then
		right.batMotion = PopCircuitBat.play("Idle")
	end
	if right and right.reaver and right.reaver.name == "Inspect" then
		RuinedReaver.play(right.reaver, "Idle")
	end
	if right and right.fan and right.fan.name == "Inspect" then
		FanMotion.play(right.fan, "Idle")
	end
	if playing.Inspect then
		turnToken += 1
	end
	ViewmodelTracks.fade(playing, "Inspect")
	for _, gun in guns do
		if gun.animator:isPlaying("Inspect") then
			gun.animator:stop()
		end
	end
end

-- A hit's drag (VM.HIT_DRAG; was a hit-stop that held one frame, which the
-- owner found choppy, 2026-11-15): the swing slows for a moment and eases
-- back to speed. `seconds`: the attack's `stop`. Runtime only, on a hit.
function ViewmodelController.hitStop(seconds: number)
	if seconds ~= seconds then
		return
	end
	local p = playing.Swing
	if p and not p.fading then
		p.freezeFor = ViewmodelMotion.dragTime(seconds)
		p.freeze = p.freezeFor
	end
	-- The bat moves on its own system: drag it too.
	local right = guns.Right
	if right and right.batMotion then
		PopCircuitBat.hitStop(right.batMotion, seconds)
	end
	if right and right.reaver then
		RuinedReaver.hitStop(right.reaver, seconds)
	end
end

function ViewmodelController.isInspecting(): boolean
	local p = playing.Inspect
	local reaver = guns.Right and guns.Right.reaver
	return (p ~= nil and not p.fading) or (reaver ~= nil and reaver.name == "Inspect")
end

function ViewmodelController.hasRuinedReaver(): boolean
	return guns.Right ~= nil and guns.Right.reaver ~= nil
end

-- Which knife-slot motion is in the hand ("RuinedReaver", "Bat", "Fan"), nil
-- for the stock knife tracks (Config/MeleeSkins FEEL keys on it).
function ViewmodelController.meleeMotion(): string?
	local right = guns.Right
	if not right then
		return nil
	end
	return if right.reaver
		then "RuinedReaver"
		elseif right.batMotion then "Bat"
		elseif right.fan then "Fan"
		else nil
end

function ViewmodelController.isFinishingShadowMistInspect(): boolean
	local right = guns.Right
	return (right and right.shadowActions ~= nil and playing.Inspect ~= nil) == true
end

function ViewmodelController.setAds(alpha: number)
	-- Which way the aim is going: the drawn blend (adsBlend) springs there.
	if alpha >= 1 or alpha > adsAlpha then
		adsGoal = 1
	elseif alpha <= 0 or alpha < adsAlpha then
		adsGoal = 0
	end
	adsAlpha = alpha
	-- Stepped here, once a frame, by whoever owns the aim (WeaponController,
	-- spectating, a replay), so the zoom they set from adsBlend() is this
	-- frame's and not the last one's.
	local now = os.clock()
	local dt = math.clamp(now - adsStepAt, 0, 0.1) * timeScale
	adsStepAt = now
	if studio then
		local scale = StateValues.get(Workspace, "VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	local feel = VM.ADS_FEEL
	local c = config
	local omega = feel.reach / math.max(if c then c.adsTime else 0.2, 0.05)
	local d, v = ViewmodelMotion.bounce(adsBlend - adsGoal, adsBlendVel, omega, feel.damping, dt)
	adsBlend, adsBlendVel = adsGoal + d, v
	adsZoom, adsZoomVel = ViewmodelMotion.spring(
		adsZoom,
		adsZoomVel,
		adsGoal,
		(if adsGoal > 0 then feel.zoomReach else feel.zoomOutReach)
			/ math.max(if c then c.adsTime else 0.2, 0.05),
		dt
	)
	if alpha > 0.05 and playing.Inspect then
		ViewmodelController.cancelInspect()
	end
end

-- The aim blend the gun is drawn at, 0..1.
function ViewmodelController.adsBlend(): number
	return math.clamp(adsBlend, 0, 1)
end

-- The aim blend for the camera's zoom, 0..1: it starts with the gun and
-- lands after it.
function ViewmodelController.adsZoom(): number
	return math.clamp(adsZoom, 0, 1)
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

-- Held Mods (Util/ViewmodelHeldMods, which documents each) -----------------------

-- Drops the gun (and the arms on it) out of view, or brings it back.
function ViewmodelController.setLowered(value: boolean)
	ViewmodelHeldMods.setLowered(heldMods, value)
end

-- Puts a Mod's item (a Model; cloned) in the right hand, raised as the gun
-- lowers. Its pivot is the grip. nil takes it away.
function ViewmodelController.holdItem(template: Model?)
	ViewmodelHeldMods.holdItem(heldMods, template)
end

-- After a use or a cancel: the item goes, the hand on it eases back onto the
-- gun as it comes up (ViewmodelHeldMods.letGoItem).
function ViewmodelController.letGoItem()
	ViewmodelHeldMods.letGoItem(heldMods)
end

-- Calls off the item's move (a throw cancelled in its wind-up): the hand
-- eases back from where it is, the item still in it.
function ViewmodelController.cancelItemAction()
	ViewmodelHeldMods.cancelAction(heldMods)
end

-- A Mod gesture: the free hand plays MOD_GESTURES[`gesture`] while the gun
-- moves by `dip` ("Dash", "Updraft", "Stim", "Recall"; nil: it stays).
-- `prop`: a model carried in the fist until the gesture's release.
-- `duration`: seconds it takes instead of its own length (its dip with it).
function ViewmodelController.gesture(gesture: string, dip: string?, prop: Model?, duration: number?)
	ViewmodelHeldMods.gesture(heldMods, gesture, dip, prop, duration)
end

-- Holds the free hand in a FREE_POSES pose until nil (the Firewall's
-- burning hand, with its flame).
function ViewmodelController.setFreeHand(pose: string?)
	ViewmodelHeldMods.setFreeHand(heldMods, pose)
end

-- Sets the transparency of the held item's part `name` (or its
-- `name`_<Material> pieces) until the item is next held.
function ViewmodelController.setItemPart(name: string, transparency: number)
	ViewmodelHeldMods.setItemPart(heldMods, name, transparency)
end

-- Hides the held item's part `name` after `delay` seconds (the Molly's pin).
function ViewmodelController.hideItemPart(name: string, delay: number)
	ViewmodelHeldMods.hideItemPart(heldMods, name, delay)
end

-- Moves one part of the held item: a turn about a pivot attachment or a
-- slide onto an attachment (VM.PartMove). Nothing happens when the item has
-- no such part or attachment; it's whole again the next time it's held.
function ViewmodelController.moveItemPart(move: VM.PartMove)
	ViewmodelHeldMods.moveItemPart(heldMods, move)
end

-- Plays the part moves VM.ITEM_PART_MOVES[`sequence`] on the held item (the
-- Molly's "MollyPad", "CanisterPin").
function ViewmodelController.itemParts(sequence: string)
	ViewmodelHeldMods.itemParts(heldMods, sequence)
end

-- A use, keyframed on the held item (ITEM_ACTIONS): "Throw", "Place" or "Heal".
function ViewmodelController.itemAction(kind: string)
	ViewmodelHeldMods.itemAction(heldMods, kind)
end

-- A held bow (VM.BOW, Recon): drawn to `charge` 0..1 while LMB is held, nil
-- lets it down to rest (a cancel); releaseItem lets it go.
function ViewmodelController.setItemCharge(charge: number?)
	ViewmodelHeldMods.setItemCharge(heldMods, charge)
end

function ViewmodelController.releaseItem()
	ViewmodelHeldMods.releaseItem(heldMods)
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
-- (Aiming isn't in here: updatePoseWeights takes every pose out by the aim
-- blend itself, so they leave exactly as the sights come up.)
local function poseTarget(name: string, state: string): number
	return if state == name then 1 else 0
end

-- Drops the old mag as it leaves the gun and hides it until the new one
-- comes up (MagDrop.timing). Runs after the clip has posed the joints.
local function showMag(mag: Mag, visible: boolean)
	mag.gone = not visible
	for _, p in mag.parts do
		LocalHide.set(p, if visible and not hidden then 0 else 1)
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
			if gun.shadowActions then
				ShadowMistActions.endReload(gun.shadowActions)
			end
			if gun.tempest then
				TempestIdle.endReload(gun.tempest)
			end
			continue
		end
		local t = gun.animator:progress()
		if gun.shadowActions and mag.seat and mag.bone == "Mag" then
			ShadowMistActions.reload(
				gun.shadowActions,
				mag.parts,
				t,
				timing,
				mag.seat,
				mag.empty == true
			)
			mag.gone = t >= timing.outAt
			continue
		end
		-- Tempest-Strike: the old mag bursts into water (no drop copy) and water
		-- gathers at the magwell before the new one seats (Util/TempestIdle).
		if gun.tempest and mag.bone == "Mag" and mag.clip then
			local _, magTo = gun.animator:activity(mag.clip, "Mag")
			local seat = math.max(timing.inAt, magTo or timing.inAt)
			if TempestIdle.reload(gun.tempest, mag.parts, t, timing.outAt, timing.inAt, seat) then
				showMag(mag, false)
			elseif mag.gone and t >= TempestIdle.solidAt(timing.inAt, seat) then
				showMag(mag, true) -- solid now (it was water from MagIn, Util/TempestCoat)
			end
			continue
		end
		if not mag.gone and t >= timing.outAt and t < timing.inAt then
			-- Kicked off and thrown forward (owner, 2026-11-08), in camera space.
			local cam = Workspace.CurrentCamera
			MagDrop.drop(
				gun.key,
				mag.parts,
				if cam then cam.CFrame:VectorToWorldSpace(VM.MAG_DROP.throw) else nil
			)
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
		-- Aimed, no movement pose is left at all, and it goes with the aim blend
		-- rather than on the pose's own slower spring (2026-11-12: aiming in a
		-- slide left the sights off the crosshair for about 0.7 s).
		weights[name] = s.x * (1 - math.clamp(adsBlend, 0, 1))
	end
end

-- Where the gun sits relative to the rig's root: hip or ADS, then the
-- movement poses, keyframed tracks and recoil, all around the grip.
-- Studio only: a Workspace Vector3 attribute overrides a hold value live
-- (VmOffset, VmRotation, VmRightHand, VmRightDir, VmLeftHand, VmLeftDir), for
-- tuning a gun's hold without restarting. Unset = the config value.
local function tuned(name: string, value: Vector3): Vector3
	if studio then
		local v = StateValues.get(Workspace, name)
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
	-- Every hold sits a little more right, higher and closer (owner, 2026-11-08:
	-- "more personal", Valorant-like); the sight picture (AimPoint) is unchanged.
	local hipPos = tuned("VmOffset", c.viewmodelOffset) + (c.hipShift or VM.HIP_SHIFT)
	local hipRot = tuned("VmRotation", c.viewmodelRotation or Vector3.zero)
	if mirror then
		hipPos, hipRot = mirrorPos(hipPos), mirrorRot(hipRot)
	end
	local hip = CFrame.new(hipPos) * angles(hipRot) * CFrame.new(-gun.hipRel)
	local base = hip
	if adsBlend ~= 0 or adsBlendVel ~= 0 then
		local ads = CFrame.new(c.adsOffset or Vector3.zero)
			* CFrame.new(0, 0, -adsDistanceOf(c, gun.model))
			* CFrame.new(-gun.aimRel)
		-- The raw spring blend: it runs a little past the pose and settles
		-- (VM.ADS_FEEL). On the way the gun cants into the move and swings
		-- under the straight line; both vanish at either end.
		local feel = VM.ADS_FEEL
		local arc = 4 * adsT * (1 - adsT)
		local cant = math.rad(feel.cant) * math.clamp(adsBlendVel * c.adsTime / 1.8, -1.5, 1.5)
		base = hip:Lerp(ads, adsBlend)
			* CFrame.new(0, -feel.dip * arc, feel.pull * arc)
			* CFrame.Angles(0, 0, if mirror then -cant else cant)
	end
	local r = gun.recoil:update(dt) * 0.1 * (1 - adsT)
	local a = gun.adsRecoil:update(dt) * adsT
	local kick = r + a
	-- Shot punch and spray climb (hip only: aimed, the sights stay put and the
	-- camera recoil carries it). The climb settles once the shooting stops.
	-- Once the shooting stops the climb lets go at once and the gun drops
	-- home on its spring (a small overshoot, settled in ~0.35 s; VM.CLIMB_*).
	-- (A slow semi-auto with a climb, the Judge, keeps it between its shots.)
	local settleAfter = math.max(CLIMB_SETTLE_AFTER, c.fireInterval * 1.25)
	if os.clock() - gun.lastShot > settleAfter then
		gun.climb.target = Vector3.zero
	end
	local hipK = 1 - adsT
	local slowK, fastK = math.exp(-dt / gun.snapDecay), math.exp(-dt / gun.snapAttack)
	if gun.snapHeld > 0 then
		-- Held at the peak: the kick doesn't start home yet (the revolver).
		gun.snapHeld -= dt
		slowK = 1
	end
	gun.snapSlow *= slowK
	gun.snapFast *= fastK
	gun.snapRollSlow *= slowK
	gun.snapRollFast *= fastK
	local p = (gun.snapSlow - gun.snapFast) * hipK
	local roll = (gun.snapRollSlow - gun.snapRollFast) * hipK
	local climb = gun.climb:update(dt) * hipK
	-- Handling bounce: the snap on a mag, a rack, a shell, the draw.
	local h = gun.bounce:update(dt) * (1 - (1 - VM.HANDLE_ADS) * adsT)
	local recoilCf = CFrame.new(0, -h.X, kick.X + p.X)
		* CFrame.Angles(kick.Y + p.Y + climb.X + h.Y, p.Z + climb.Y, kick.Z + roll + h.Z)
	local held = base * poseOffset(mirror) * trackOffset(gun, mirror, false) * recoilCf
	-- The knife is never quite still in the hand (VM.MELEE_IDLE): a slow
	-- roll and turn, through the inspect and the pull-out too (their holds
	-- sat dead still: "staged"). It eases out for a swing, which has to land
	-- where it is keyed, and back in after.
	if c.fireMode == "Melee" then
		local idle = VM.MELEE_IDLE
		meleeIdle += ((if playing.Swing then 0 else 1) - meleeIdle) * (1 - math.exp(-idle.fade * dt))
		local t = os.clock() * idle.rate * 2 * math.pi
		-- (The lean runs on the roll's cosine, so roll and lean trace an
		-- ellipse and the knife never stops turning: 2026-11-21, it sat under
		-- 4 degrees a second 48% of the time, as slow as 0.2.)
		held *= CFrame.new(0, math.sin(t * 0.5) * idle.lift * meleeIdle, 0) * CFrame.Angles(
			math.rad(idle.lean) * math.cos(t) * meleeIdle,
			math.rad(idle.yaw) * math.sin(t * 0.7 + 1) * meleeIdle,
			math.rad(idle.roll) * math.sin(t) * meleeIdle
		)
	end
	local screen = trackOffset(gun, mirror, true)
	if screen == CFrame.identity then
		return held
	end
	local pivot = CFrame.new(base.Position)
	return pivot * screen * pivot:Inverse() * held
end

local function mirrorHand(hand: VM.Hand, mirror: boolean): (Vector3, Vector3)
	if mirror then
		return mirrorPos(hand.offset), mirrorPos(hand.direction)
	end
	return hand.offset, hand.direction
end

-- The arm direction to draw this frame: `want` (world, unit) eased through the
-- side's follow spring in camera space. Snaps on the first frame after a gap
-- (a new gun, a hidden rig, another pose that placed the arm itself).
local function followArm(side: Side, camCf: CFrame, want: Vector3): Vector3
	local target = camCf:VectorToObjectSpace(want)
	local f = armFollow[side]
	if not f or f.frame < frameIndex - 1 or VM.ARM_FOLLOW <= 0 then
		armFollow[side] = { dir = target, vel = Vector3.zero, frame = frameIndex }
		return want
	end
	f.frame = frameIndex
	-- Aimed, the arms stiffen up (the sight picture stays quiet).
	local omega = VM.ARM_FOLLOW + (VM.ARM_FOLLOW_ADS - VM.ARM_FOLLOW) * math.clamp(adsBlend, 0, 1)
	f.dir, f.vel = ViewmodelMotion.spring3(f.dir, f.vel, target, omega, frameDt)
	if f.dir.Magnitude < 1e-3 then
		f.dir = target
		f.vel = Vector3.zero
	end
	return camCf:VectorToWorldSpace(f.dir.Unit)
end

-- A hand that has let go of the gun: where it is and where its arm runs
-- (world), and how far (0..1) it has left its hold for there.
type FreeHand = { point: Vector3, dir: Vector3, weight: number }
local runHand: FreeHand = { point = Vector3.zero, dir = Vector3.yAxis, weight = 0 }

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
	mirror: boolean,
	free: FreeHand?,
	shoulder: Vector3?
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
	-- Melee (2026-11-14, owner: "keep it on the edge of the hand", "the hands
	-- don't have fingers"): the knife is rigid in the block fist. The forearm
	-- runs at a fixed angle from the knife (VM.MELEE_HAND.direction, the hold
	-- he approved, measured in play), bent at most VM.MELEE_WRIST_BEND toward
	-- the shoulder. The keys (tools/studio/knife_fp_keys.py) pick the wrist
	-- roll that brings it from the shoulder side. Before: it aimed at the
	-- shoulder and was only kept VM.MELEE_ARM_ANGLE off the blade, so the
	-- knife slid round the fist as the blade turned.
	local twistRef = gunCf.RightVector
	if shoulder then
		local rigid = gunCf:VectorToWorldSpace(direction)
		local want = shoulder - point
		along = rigid
		if rigid.Magnitude > 1e-4 and want.Magnitude > 1e-3 then
			rigid, want = rigid.Unit, want.Unit
			local angle = math.acos(math.clamp(rigid:Dot(want), -1, 1))
			local bend = math.min(angle, math.rad(VM.MELEE_WRIST_BEND))
			local axis = rigid:Cross(want)
			if bend > 1e-4 and axis.Magnitude > 1e-6 then
				-- The wrist: the fist and forearm turn about the pivot inside the
				-- fist, so the handle stays seated as the knife bends.
				local turn = CFrame.fromAxisAngle(axis.Unit, bend)
				local pivot = gunCf:PointToWorldSpace(VM.MELEE_WRIST_PIVOT)
				point = pivot + turn:VectorToWorldSpace(point - pivot)
				twistRef = turn:VectorToWorldSpace(twistRef)
				along = turn:VectorToWorldSpace(rigid)
			end
		end
	end
	-- In the air the elbows flare out from the body (ViewmodelMotion airPos.Z).
	local flare = motion.airPos.Z * VM.AIR_ELBOW * (1 - math.clamp(adsBlend, 0, 1))
	if flare > 1e-3 and cam and along.Magnitude > 1e-4 then
		along = along.Unit + cam.CFrame.RightVector * (if side == "Right" then flare else -flare)
	end
	-- Off the gun (a pistol's support hand while running): blend to where
	-- that hand swings, unless it's working a part right now.
	if free and free.weight > 0 and along.Magnitude > 1e-4 then
		local w = free.weight * (1 - working)
		point = point:Lerp(free.point, w)
		along = along.Unit:Lerp(free.dir, w)
	end
	-- (A knife arm skips the follow spring: rigid with the fist, a trailing
	-- forearm would show as the knife moving in the hand.)
	if cam and along.Magnitude > 1e-4 and not shoulder then
		along = followArm(side, cam.CFrame, along.Unit)
	end
	-- Last eye guard, after the follow spring (which can carry an arm back
	-- over the bend above). 2026-11-13, owner: "the Outlaw reload... the left
	-- hand goes into the screen". Measured: loading each round the hand sat
	-- 0.49 studs in front of the eye and its arm ran 40% back toward the
	-- camera, so the eye was inside the block. When the block's line passes
	-- within ARM_EYE_CLEARANCE, it turns down and out with nothing back
	-- toward the camera, blended in by how close it gets (no pop).
	if cam and not shoulder and along.Magnitude > 1e-4 then
		local camCf = cam.CFrame
		local unit = along.Unit
		local toEye = camCf.Position - point
		local t = math.clamp(toEye:Dot(unit), 0, VM.ARM_REACH_LENGTH)
		local gap = (toEye - unit * t).Magnitude
		local k = math.clamp((VM.ARM_EYE_CLEARANCE - gap) / (VM.ARM_EYE_CLEARANCE * 0.5), 0, 1)
		if k > 0 then
			local c = camCf:VectorToObjectSpace(unit)
			local y = math.min(c.Y, -VM.ARM_MIN_DROP)
			local z = math.min(c.Z, 0)
			local sideSign = if math.abs(c.X) > 1e-3
				then math.sign(c.X)
				elseif side == "Right" then 1
				else -1
			local x = sideSign * math.sqrt(math.max(1 - y * y - z * z, 0))
			along = unit:Lerp(camCf:VectorToWorldSpace(Vector3.new(x, y, z)), k)
		end
	end
	ViewmodelArms.place(a, side, point, point + along, twistRef)
end

local handleCFrames: { [Side]: CFrame } = {}

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local right = guns.Right
	local c = config
	dt = math.min(dt, 0.1) * timeScale -- the final-kill replay's slow motion
	if studio then
		-- Studio only: Workspace attribute VfxTimeScale slows or freezes the
		-- viewmodel too (with the shot effects), for reviewing animations.
		local scale = StateValues.get(Workspace, "VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	frameIndex += 1
	frameDt = dt
	stepBumps(os.clock())
	MagDrop.step(dt) -- dropped mags keep falling after a swap
	if not cam or not right or not c then
		motion.lastCamera = cam and cam.CFrame
		ViewmodelHeldMods.dropGestureProp(heldMods) -- nothing to hold it
		return
	end
	local camCf = cam.CFrame
	local now = os.clock()

	-- Rebuild the arms if the avatar's look changed (appearance loads late).
	if now >= nextLookCheck then
		nextLookCheck = now + 1
		if ViewmodelArms.signature(subjectBody()) ~= armsLook then
			rebuildArms(cam)
		end
	end

	-- 1. Root: the camera plus the rig's motion (bob, breathing, sway, tilt).
	local moveAttr = subject and StateValues.get(subject, "MoveState")
	local state = if subject
		then (if typeof(moveAttr) == "string" then moveAttr else "Idle")
		else MovementController.getState()
	local character = subjectBody()
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local adsT = math.clamp(adsBlend, 0, 1)
	motionInput.camera = camCf
	local velocity = if rootPart and rootPart:IsA("BasePart")
		then rootPart.AssemblyLinearVelocity
		else Vector3.zero
	-- Mid-dash the body moves ~80 studs/s: feed the sway its exit speed, so a
	-- sideways dash doesn't tilt the gun over (the dip and gesture show it).
	local tune = character and StateValues.get(character, "DashTune")
	local exitSpeed = if typeof(tune) == "Vector3" then tune.X else nil
	if
		character
		and StateValues.get(character, "Dashing") == true
		and typeof(exitSpeed) == "number"
		and velocity.Magnitude > exitSpeed
	then
		velocity = velocity.Unit * exitSpeed
	end
	motionInput.velocity = velocity
	-- A live subject's feet: their Humanoid's floor (as Simulation/Poses reads
	-- it for the body), not MoveState, which arrives a send and two hops
	-- late and would shrink every landing to the minimum dip. A replay copy
	-- is anchored and has no floor: it keeps the state.
	local onFloor = state ~= "Air"
	if subject and rootPart and rootPart:IsA("BasePart") and not rootPart.Anchored then
		local subjectHumanoid = subject:FindFirstChildOfClass("Humanoid")
		if subjectHumanoid then
			onFloor = subjectHumanoid.FloorMaterial ~= Enum.Material.Air
		end
	end
	motionInput.grounded = onFloor and state ~= "Slide"
	motionInput.sprinting = state == "Sprint"
	motionInput.sliding = state == "Slide"
	motionInput.crouching = state == "Crouch"
	motionInput.ads = adsT
	-- The slide's lean (Util/SlideTilt, the crosshair's and camera's curve):
	-- the whole viewmodel turns about the line of sight, clockwise like the
	-- crosshair, so aimed sights stay on the centre and lean with it.
	local cantDegrees = VM.SLIDE_CANT.hip + (VM.SLIDE_CANT.ads - VM.SLIDE_CANT.hip) * adsT
	local cant = CFrame.Angles(0, 0, -math.rad(cantDegrees) * SlideTilt.amount())
	local root = camCf * cant * ViewmodelMotion.step(motion, motionInput, dt)

	-- Held Mod: the gun drops away (plus a Mod gesture's dip), the item comes up.
	local lowerCf, lowerT = ViewmodelHeldMods.lower(heldMods, now, dt)

	-- 2. Guns: root * hold pose, then every joint of the gun from its clip.
	updatePoseWeights(dt, state)
	ViewmodelTracks.step(playing, dt)
	local batPose: CFrame? = nil
	local batPalm: Vector3? = nil
	local batSupport: Vector3? = nil
	local batSupportHeld = false
	local reaverSupportRoll = 0
	if right.reaver then
		batPose, batPalm, batSupport, batSupportHeld, reaverSupportRoll =
			RuinedReaver.step(right.reaver, dt, not hidden and lowerT < 0.1, state == "Sprint")
	elseif right.batMotion then
		local pose, palm, support, _held, supportHeld, trail, done =
			PopCircuitBat.step(right.batMotion, dt)
		batPose = pose
		batPalm = palm
		batSupport = support
		batSupportHeld = supportHeld
		for _, ribbon in right.batTrails or {} do
			local on = trail and not hidden and lowerT < 0.1
			if on and not ribbon.Enabled then
				ribbon:Clear() -- a re-enabled trail joins its last point across the screen
			end
			ribbon.Enabled = on
		end
		if done then
			right.batMotion = PopCircuitBat.play("Idle")
		end
	end
	local fade = Ease.smooth((adsAlpha - 0.35) / 0.45)
	local lens = VM.SCOPE_LENS
	local lensFade = Ease.smooth((adsAlpha - lens.from) / (lens.to - lens.from))
	local rightToss: CFrame? = nil -- the knife in the air (VM Track `toss`)
	for _, side in SIDES do
		local gun = guns[side]
		local rig = gun and gun.rig
		if gun and rig then
			gun.animator:update(dt)
			if gun.fan then
				FanMotion.step(gun.fan, dt) -- after the clip, before the rig solve
			end
			if
				gun.lockPending
				and (not gun.animator:isPlaying("Fire") or gun.animator:progress() >= VM.LOCK_AT)
			then
				gun.lockPending = false
				gun.animator:holdStart("ReloadEmpty")
			end
			if gun.cosmeticInspect then
				local inspect = playing.Inspect
				local progress = if inspect and not inspect.fading
					then inspect.time / inspect.length
					else nil
				CosmeticInspect.step(gun.cosmeticInspect, progress)
			end
			local clipName = gun.animator.clipName
			local visible = not hidden and lowerT < 0.9
			if gun.slipframe then
				local inspect = playing.Inspect
				SlipframeEffects.step(
					gun.slipframe,
					dt,
					if inspect and not inspect.fading then inspect.time / inspect.length else nil,
					adsAlpha,
					visible
				)
			end
			local action: ShadowMistActions.Frame? = nil
			if gun.shadowActions then
				local draw = playing.Equip
				local inspect = playing.Inspect
				action = ShadowMistActions.step(
					gun.shadowActions,
					dt,
					visible,
					if draw and not draw.fading then draw.time / draw.length else nil,
					if inspect and not inspect.fading then inspect.time / inspect.length else nil,
					adsAlpha
				)
			end
			stepMags(gun)
			if gun.shadowActions then
				ShadowMistActions.stepDrop(gun.shadowActions, dt)
				ShadowMistActions.stepFx(gun.shadowActions, adsAlpha)
			end
			if gun.tempest then
				local draw = playing.Equip
				local inspect = playing.Inspect
				TempestIdle.step(
					gun.tempest,
					dt,
					visible,
					(clipName == nil or clipName == "Fire") and not playing.Inspect and lowerT < 0.1,
					adsAlpha,
					if draw and not draw.fading then draw.time / draw.length else nil,
					if inspect and not inspect.fading then inspect.time / inspect.length else nil
				)
			end
			if gun.kunai then
				local draw = playing.Equip
				local inspect = playing.Inspect
				local sw = playing.Swing
				local cut = sw ~= nil and not sw.fading
				TempestKunai.step(
					gun.kunai,
					dt,
					visible,
					if draw and not draw.fading then draw.time / draw.length else nil,
					if inspect and not inspect.fading then inspect.time / inspect.length else nil,
					if sw and cut then sw.time / sw.length else nil,
					cut and sw ~= nil and sw.track == VM.TRACKS.HeavyStab,
					if sw then sw.track.hit else nil
				)
			end
			if gun.shadowMist then
				ShadowMistIdle.step(
					gun.shadowMist,
					dt,
					visible,
					(clipName == nil or clipName == "Fire") and not playing.Inspect and lowerT < 0.1,
					adsAlpha,
					action
				)
			end
			local clipData = clipName
				and gun.animator.clips
				and (gun.animator.clips :: any)[clipName]
			for _, carry in gun.carries do
				local timing = clipData
					and (clipName == "Reload" or clipName == "ReloadEmpty")
					and carryTiming(clipData, carry.joint, if c then c.id else "")
				local off = if timing
					then not RoundCarry.visible(timing, carry.show, gun.animator:progress())
					else carry.hideAtRest
				if off ~= carry.hiddenNow then
					carry.hiddenNow = off
					for _, p in carry.parts do
						LocalHide.set(p, if off or hidden then 1 else 0)
					end
				end
			end
			for _, prop in gun.props do
				local away = prop.motor.Transform.Position.Magnitude > prop.limit
				if away ~= prop.hiddenNow then
					prop.hiddenNow = away
					for _, p in prop.parts do
						LocalHide.set(p, if away or hidden then 1 else 0)
					end
				end
			end
			local handleCf = if batPose and side == "Right"
				then root * lowerCf * batPose
				else root * lowerCf * holdPose(gun, c, side == "Left", adsT, dt)
			if gun.tempest then
				-- the skin's own motion layer: shot kick, draw roll-in, seat pop, inspect float
				handleCf *= TempestIdle.pose(gun.tempest)
			end
			-- A knife toss (VM Track `toss`): the knife leaves the fist, the arm
			-- stays on the fist (handleCf) until the catch.
			local toss = if side == "Right" then ViewmodelTracks.toss(playing) else nil
			if side == "Right" then
				rightToss = toss
			end
			local rootWeight = 1 - (1 - VM.ADS_CLIP_KICK) * adsT
			if gun.shadowActions and (playing.Equip or playing.Reload) then
				rootWeight *= 0.22
			end
			ViewmodelRig.solve(rig, if toss then handleCf * toss else handleCf, rootWeight)
			-- The hands hold the gun's body: the handle frame plus the clip's
			-- Root motion, so when a clip rolls the gun in the hands (a draw,
			-- an inspect) the arms turn with it instead of the gun turning
			-- into them.
			local rootMotor = rig.rootMotor
			local body = rootMotor and rootMotor.Part1 and rig.world[rootMotor.Part1]
			handleCFrames[side] = if toss
				then handleCf
				elseif body and rootMotor then body * rootMotor.C1 * rootMotor.C0:Inverse()
				else handleCf

			if gun.reticle then
				gun.reticle.Enabled = adsAlpha > 0.4 and not hidden
			end
			-- The gun's outline: gone while it's hidden, fading out as you aim.
			local h = gun.outline
			if h then
				local shown = if hidden
					then 1
					else 1 - (1 - VM.GUN_OUTLINE.transparency) * (1 - adsT)
				if math.abs(shown - gun.outlineShown) > 0.01 then
					gun.outlineShown = shown
					h.OutlineTransparency = shown
					h.Enabled = shown < 0.99
				end
			end
			-- Fade only the parts that block the sight line, while aiming.
			if not hidden and fade ~= gun.adsFade then
				gun.adsFade = fade
				for _, p in gun.adsHide do
					LocalHide.set(p, fade)
				end
			end
			if not hidden and lensFade ~= gun.lensFade then
				gun.lensFade = lensFade
				for _, p in gun.lensHide do
					LocalHide.set(p, lensFade)
				end
			end
		end
	end

	-- 3. Hands and arms on the grips: gun space, from the same pass.
	local a = arms
	local rightCf = handleCFrames.Right
	if a and rightCf and right.rig and batPalm and batSupport then
		-- The PopCircuit Bat (Util/PopCircuitBat): each fist is a block on
		-- its point, its arm straight back to its shoulder, nothing turning in
		-- the hand (owner 2026-11-12: "there isn't fingers... very simple").
		local frame = root * lowerCf
		local hand = frame:PointToWorldSpace(batPalm)
		local handRight = if right.reaver then rightCf.RightVector else frame.RightVector
		ViewmodelArms.place(
			a,
			"Right",
			hand,
			frame:PointToWorldSpace(
				if right.reaver then RuinedReaver.RIGHT_SHOULDER else PopCircuitBat.RIGHT_SHOULDER
			),
			handRight
		)
		ViewmodelArms.place(
			a,
			"Left",
			frame:PointToWorldSpace(batSupport),
			frame:PointToWorldSpace(PopCircuitBat.LEFT_SHOULDER),
			if right.reaver then frame.RightVector:Lerp(handRight, reaverSupportRoll) else handRight
		)
		if not batSupportHeld then
			ViewmodelHeldMods.stepFreeHand(heldMods, a, root, now, dt, hidden)
		end
	elseif a and rightCf and right.rig then
		local left = guns.Left
		local leftCf = handleCFrames.Left
		local pistol = right.pistol or left ~= nil -- akimbo: a pistol in each hand
		-- (Melee uses its own hand: the fist round the handle. The ChatGPT pass
		-- had dropped this, so the knife sat on top of the rifle hand offset,
		-- above the fist; owner 2026-11-12.)
		local rightHand = if c.fireMode == "Melee"
			then VM.MELEE_HAND
			elseif pistol then VM.PISTOL_RIGHT_HAND
			else VM.RIFLE_RIGHT_HAND
		local gripR = if right.rightGrip
			then anchorPosition(right, right.rightGrip)
			else rightCf.Position
		if rightToss then
			-- The fist stays where the grip was before the throw, not on the
			-- flying knife.
			gripR = rightCf:PointToWorldSpace(
				rightToss:PointToObjectSpace(rightCf:PointToObjectSpace(gripR))
			)
		end
		if c.fireMode == "Melee" then
			holdWith(
				a,
				"Right",
				right,
				rightCf,
				gripR,
				tunedHand(rightHand, "Right"),
				false,
				nil,
				root:PointToWorldSpace(VM.MELEE_SHOULDER)
			)
		else
			holdWith(a, "Right", right, rightCf, gripR, tunedHand(rightHand, "Right"), false)
		end

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
			-- Running: the support hand lets go and pumps (VM.PISTOL_RUN_HAND).
			local run = Ease.smooth(math.clamp(weights.Sprint or 0, 0, 1))
			if run > 0.001 then
				local swing = math.sin(motion.bobPhase + math.pi)
					* math.clamp(motion.bobAmount, 0, 1.4)
				local s = VM.PISTOL_RUN_SWING
				runHand.point = root:PointToWorldSpace(
					VM.PISTOL_RUN_HAND.offset + Vector3.new(s.X * swing, s.Y * swing, -s.Z * swing)
				)
				runHand.dir = root:VectorToWorldSpace(VM.PISTOL_RUN_HAND.direction)
			end
			runHand.weight = run
			holdWith(a, "Left", right, rightCf, gripR, VM.PISTOL_LEFT_HAND, false, runHand)
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
		else
			-- Melee: the free hand is a raised guard riding the root. It drops
			-- out of view for the inspect (one hand only) and moves onto the
			-- handle for the heavy stab, blended both ways so it never pops
			-- (owner, 2026-11-08).
			local clock = os.clock()
			local heavy = clock >= heavyFrom and clock < heavyUntil and right.rightGrip ~= nil
			-- Out of view through the inspect and the pull-out (VM.FREE_HAND_DRAW_AT).
			local drawing = playing.Equip
			local tucked = playing.Inspect ~= nil
				or (drawing ~= nil and drawing.time < drawing.length * VM.FREE_HAND_DRAW_AT)
			local blend = VM.FREE_HAND_BLEND
			freeHeavy = math.clamp(freeHeavy + (if heavy then dt else -dt) / blend, 0, 1)
			freeHidden = math.clamp(freeHidden + (if tucked then dt else -dt) / (blend * 2), 0, 1)
			local h = Ease.smooth(freeHidden)
			local offset = VM.FREE_HAND.offset:Lerp(VM.FREE_HAND_HIDDEN.offset, h)
			local direction = VM.FREE_HAND.direction:Lerp(VM.FREE_HAND_HIDDEN.direction, h)
			-- It goes with the body as the knife travels (VM.FREE_HAND_FOLLOW).
			local follow = VM.FREE_HAND_FOLLOW
			local travel = root:PointToObjectSpace(gripR)
				- (c.viewmodelOffset + (c.hipShift or VM.HIP_SHIFT))
			local far = Ease.smooth(math.clamp(travel.Magnitude / follow.reach, 0, 1)) * (1 - h)
			offset += Vector3.new(travel.X * follow.travel, -follow.drop * far, follow.back * far)
			local point = root:PointToWorldSpace(offset)
			local dir = root:VectorToWorldSpace(direction)
			if freeHeavy > 0 then
				local t = Ease.smooth(freeHeavy)
				local two = VM.MELEE_HEAVY_HAND
				point = point:Lerp(gripR + root:VectorToWorldSpace(two.offset), t)
				dir = dir:Lerp(root:VectorToWorldSpace(two.direction), t)
			end
			if dir.Magnitude > 1e-4 then
				dir = followArm("Left", camCf, dir.Unit)
			end
			ViewmodelArms.place(a, "Left", point, point + dir, root.RightVector)
		end
		-- A Mod gesture or a held free-hand pose takes the free hand off the gun.
		ViewmodelHeldMods.stepFreeHand(heldMods, a, root, now, dt, hidden)
	end

	-- 3b. A held Mod's item, in the right hand.
	ViewmodelHeldMods.stepItem(heldMods, a, root, now, dt, lowerT)

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

-- A fresh rig: no gun, no item, no arms, motion from rest (a life ends, or
-- the view moves to someone else).
local function resetView()
	ViewmodelController.unequip()
	ViewmodelController.holdItem(nil)
	ViewmodelHeldMods.reset(heldMods) -- the gun up, no gesture or prop, free hand back
	if arms then
		arms.model:Destroy()
		arms = nil
		armsLook = ""
	end
	-- Movement feel starts fresh next life (no landing dip from dying mid-air).
	ViewmodelMotion.reset(motion)
	table.clear(poseWeights)
	table.clear(weights)
end

-- Spectating: show `body`'s view (nil: back to yours). Starts empty; the
-- spectate controller equips their gun.
-- Skin preview: `owner` picked another line; rebuild the camera gun if it is
-- theirs and its geometry differs (surface-only lines re-skin in place).
local function onSkinPick(owner: Player)
	local weapon = config
	local right = guns.Right
	local viewer = if subject then subjectOwner else player
	if not weapon or not right or viewer ~= owner then
		return
	end
	local templateId = if weapon.models then weapon.models.right else weapon.id
	if SkinPreview.geometryChanged(right.model, templateId, owner) then
		local wasHidden = hidden
		-- Same gun, new look: no draw.
		ViewmodelController.equip(weapon, nil, { instant = true })
		ViewmodelController.setHidden(wasHidden)
	elseif subject then
		for _, gun in guns do
			SkinPreview.apply(gun.model)
		end
	end
end

local subjectSkinWatch: (() -> ())? = nil

-- `owner`: the player whose skins the gun wears, when `body` isn't their
-- character (a replay copy); else the body's player (none for a bot).
function ViewmodelController.setSubject(body: Model?, owner: Player?)
	local resolved: Player? = if body then owner or Players:GetPlayerFromCharacter(body) else nil
	if body == subject and resolved == subjectOwner then
		return
	end
	resetView()
	subject = body
	subjectOwner = resolved
	if subjectSkinWatch then
		subjectSkinWatch()
		subjectSkinWatch = nil
	end
	if resolved and SkinPreview.allowed() then
		local watched: Player = resolved
		subjectSkinWatch = SkinPreview.observe(watched, function()
			onSkinPick(watched)
		end)
	end
end

function ViewmodelController.start()
	RunService:BindToRenderStep("GGViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
	if SkinPreview.allowed() then
		SkinPreview.observe(player, function()
			onSkinPick(player)
		end)
	end
	player.CharacterRemoving:Connect(function()
		if not subject then
			resetView()
		end
	end)
end

return ViewmodelController
