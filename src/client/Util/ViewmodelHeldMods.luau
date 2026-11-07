--!strict
-- Held Mods on the first-person rig (Config/Viewmodel LOWER, ITEM_*,
-- ITEM_ACTIONS, MOD_GESTURES, *_DIP, FREE_POSES):
--   * the gun lowered out of view (spring 0..1) and a gesture's dip on top;
--   * the Mod's item in the right hand (its own WorldModel under the camera,
--     like the guns): raise, breathing idle, keyed use, parts hidden or lit;
--   * Mod gestures of the free hand (Dash, Updraft, Stim), with a prop
--     carried in the fist until the release;
--   * a held free-hand pose (the Firewall's burning hand) and its flame.
-- ViewmodelController keeps one state table (new()), wraps the setters here
-- in its public API and calls the per-frame steps from its render step, in
-- rig order (lower before the guns, free hand after the grips, item last).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

local ViewmodelArms = require(script.Parent.ViewmodelArms)
local ViewmodelMotion = require(script.Parent.ViewmodelMotion)
local ViewmodelTracks = require(script.Parent.ViewmodelTracks)

local angles = ViewmodelTracks.angles

export type HeldMods = {
	-- The gun lowered (spring 0..1).
	lowered: boolean,
	lowerX: number,
	lowerV: number,
	-- The Mod's item in the right hand.
	item: WorldModel?,
	raiseX: number, -- the item's own (underdamped) raise
	raiseV: number,
	actionKind: string?,
	actionAt: number,
	itemHidden: boolean,
	-- A Mod gesture (Dash, Updraft): the gun's dip and the free hand's gesture
	-- (MOD_GESTURES, DASH_DIP / UPDRAFT_DIP).
	gestureKind: string?,
	dipKind: string?,
	gestureAt: number,
	-- A prop in the gesturing fist (the Stim beacon) until the gesture's release.
	gestureProp: WorldModel?,
	-- A held free-hand pose (FREE_POSES), eased toward; and the flame that
	-- burns in it (a part under the camera, moved with the fist).
	freePose: string?,
	freePos: Vector3,
	freeDir: Vector3,
	handFlame: Part?,
	handFlameEmitter: ParticleEmitter?,
}

local ViewmodelHeldMods = {}

local DIPS: { [string]: VM.ItemAction } = {
	Dash = VM.DASH_DIP,
	Updraft = VM.UPDRAFT_DIP,
	Stim = VM.STIM_DIP,
	Recall = VM.RECALL_DIP,
}

function ViewmodelHeldMods.new(): HeldMods
	return {
		lowered = false,
		lowerX = 0,
		lowerV = 0,
		item = nil,
		raiseX = 0,
		raiseV = 0,
		actionKind = nil,
		actionAt = -math.huge,
		itemHidden = false,
		gestureKind = nil,
		dipKind = nil,
		gestureAt = -math.huge,
		gestureProp = nil,
		freePose = nil,
		freePos = VM.FREE_POSE_FROM,
		freeDir = Vector3.new(-0.3, -0.8, 0.5),
		handFlame = nil,
		handFlameEmitter = nil,
	}
end

function ViewmodelHeldMods.dropGestureProp(h: HeldMods)
	local prop = h.gestureProp
	if prop then
		prop:Destroy()
		h.gestureProp = nil
	end
end

-- A clone of `template` in its own WorldModel under `cam`, its parts made
-- into pure visuals.
local function visualCopy(template: Model, name: string, cam: Camera, scale: number?): WorldModel
	local world = Instance.new("WorldModel")
	world.Name = name
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
	if scale then
		copy:ScaleTo(copy:GetScale() * scale)
	end
	copy.Parent = world
	world.Parent = cam
	return world
end

-- Setters (ViewmodelController's public API) -----------------------------------

-- Drops the gun (and the arms on it) out of view, or brings it back.
function ViewmodelHeldMods.setLowered(h: HeldMods, value: boolean)
	h.lowered = value
end

-- Puts a Mod's item (a Model; cloned) in the right hand, raised as the gun
-- lowers. Its pivot is the grip. nil takes it away.
function ViewmodelHeldMods.holdItem(h: HeldMods, template: Model?)
	local old = h.item
	if old then
		old:Destroy()
		h.item = nil
	end
	local cam = Workspace.CurrentCamera
	h.actionKind = nil
	h.itemHidden = false
	h.raiseX, h.raiseV = 0, 0
	if not template or not cam then
		return
	end
	h.item = visualCopy(template, "ViewmodelItem", cam, nil)
end

-- A Mod gesture: the free hand plays MOD_GESTURES[`gesture`] ("DashForward",
-- "DashBack", "DashLeft", "DashRight" camera-relative, "UpdraftDown",
-- "MollyPinPull", "StimToss") while the gun moves by `dip` ("Dash": out of
-- view; "Updraft": down while rising; "Stim": a short dip; nil: the gun stays as
-- it is). `prop`: a model carried in the fist until the gesture's release
-- (the Stim beacon), at its propScale.
function ViewmodelHeldMods.gesture(h: HeldMods, gesture: string, dip: string?, prop: Model?)
	local g = VM.MOD_GESTURES[gesture]
	if not g or (dip ~= nil and not DIPS[dip]) then
		return
	end
	h.gestureKind = gesture
	h.dipKind = dip
	h.gestureAt = os.clock()
	ViewmodelHeldMods.dropGestureProp(h)
	local cam = Workspace.CurrentCamera
	if prop and cam and g.release then
		h.gestureProp = visualCopy(prop, "ViewmodelGestureProp", cam, g.propScale)
	end
end

-- Holds the free hand in a FREE_POSES pose until nil (the Firewall's
-- burning hand: "FirewallReady", "FirewallGuide"). A Firewall pose lights
-- the flame in it.
function ViewmodelHeldMods.setFreeHand(h: HeldMods, pose: string?)
	if pose and not VM.FREE_POSES[pose] then
		return
	end
	if pose and not h.freePose then
		h.freePos = VM.FREE_POSE_FROM
	end
	h.freePose = pose
	-- Put the flame out at once (update may not run: no gun, dead).
	local flame = h.handFlameEmitter
	if not pose and flame then
		flame.Rate = 0
	end
end

-- Sets the transparency of the held item's part named `name`, or its
-- pieces `name`_<Material> (the export splits multi-material parts): Recon's
-- launcher lights, its loaded dart. The item comes back as built the next
-- time it's held.
function ViewmodelHeldMods.setItemPart(h: HeldMods, name: string, transparency: number)
	local held = h.item
	if not held then
		return
	end
	local prefix = name .. "_"
	for _, d in held:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == name or string.sub(d.Name, 1, #prefix) == prefix) then
			d.Transparency = transparency
		end
	end
end

-- Hides the held item's part named `name` after `delay` seconds (the
-- Molly's pin, pulled). The item comes back whole the next time it's held.
function ViewmodelHeldMods.hideItemPart(h: HeldMods, name: string, delay: number)
	local held = h.item
	task.delay(delay, function()
		if h.item ~= held or not held then
			return
		end
		for _, d in held:GetDescendants() do
			if d.Name == name and d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
	end)
end

-- A use, keyframed on the held item (Config/Viewmodel ITEM_ACTIONS): "Throw"
-- (the item leaves the hand at the release), "Place" or "Heal".
function ViewmodelHeldMods.itemAction(h: HeldMods, kind: string)
	if VM.ITEM_ACTIONS[kind] then
		h.actionKind = kind
		h.actionAt = os.clock()
	end
end

-- A fresh rig (a life ends, or the view moves to someone else): the gun up,
-- no gesture, no prop, the free hand back on the gun. The item goes with
-- holdItem(nil).
function ViewmodelHeldMods.reset(h: HeldMods)
	h.lowered = false
	h.lowerX, h.lowerV = 0, 0
	h.gestureKind = nil
	h.dipKind = nil
	h.gestureAt = -math.huge
	ViewmodelHeldMods.dropGestureProp(h)
	ViewmodelHeldMods.setFreeHand(h, nil)
end

-- Keyed motion ---------------------------------------------------------------------

-- Keyed offsets (ITEM_ACTIONS, the dips) at `t` 0..1, smoothstep between keys.
local function keyedOffset(keys: { VM.ItemKey }, t: number): CFrame
	if t < 0 or t >= 1 then
		return CFrame.identity
	end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			local k = Ease.smooth((t - a.t) / math.max(b.t - a.t, 1e-3))
			return CFrame.new(a.pos:Lerp(b.pos, k)) * angles(a.rot:Lerp(b.rot, k))
		end
	end
	return CFrame.identity
end

-- The action's offset at `now` (identity when none is playing), and whether
-- the item has left the hand.
local function actionOffset(h: HeldMods, now: number): (CFrame, boolean)
	local action = if h.actionKind then VM.ITEM_ACTIONS[h.actionKind] else nil
	if not action then
		return CFrame.identity, false
	end
	local t = (now - h.actionAt) / action.length
	local gone = action.hideAt ~= nil and t >= action.hideAt
	return keyedOffset(action.keys, t), gone
end

-- A gesture's free hand at `t` 0..1: fist position and arm direction (root
-- space).
local function gestureHand(keys: { VM.HandKey }, t: number): (Vector3, Vector3)
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			local k = Ease.smooth((t - a.t) / math.max(b.t - a.t, 1e-3))
			return a.pos:Lerp(b.pos, k), a.dir:Lerp(b.dir, k)
		end
	end
	local last = keys[#keys]
	return last.pos, last.dir
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
	local step = dt / steps
	for _ = 1, steps do
		local a = w * w * (goal - x) - 2 * zeta * w * v
		v += a * step
		x += v * step
	end
	return x, v
end

local function flameEmitter(h: HeldMods): (Part, ParticleEmitter)
	local p = h.handFlame
	local e = h.handFlameEmitter
	if p and e and p.Parent then
		return p, e
	end
	local part = Instance.new("Part")
	part.Name = "HandFlame"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.25, 0.25, 0.25)
	local size = VM.HAND_FLAME_SIZE
	local made = Instance.new("ParticleEmitter")
	made.Texture = VFX.MOLLY_FLAME_4x4
	made.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	made.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	made.FlipbookFramerate = NumberRange.new(20, 24)
	made.FlipbookStartRandom = true
	made.LockedToPart = true
	made.Lifetime = NumberRange.new(0.35, 0.55)
	made.Speed = NumberRange.new(0.3, 0.8)
	made.EmissionDirection = Enum.NormalId.Top
	made.SpreadAngle = Vector2.new(15, 15)
	made.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.7),
		NumberSequenceKeypoint.new(0.4, size),
		NumberSequenceKeypoint.new(1, size * 0.5),
	})
	made.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.2, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	made.LightEmission = 0.7
	made.LightInfluence = 0
	made.Rate = 0
	made.Parent = part
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = part
	part.Parent = Workspace.CurrentCamera
	h.handFlame = part
	h.handFlameEmitter = made
	return part, made
end

-- Per frame ------------------------------------------------------------------------

-- Held Mod: the gun drops away (its offset from the rig's root), with a Mod
-- gesture's dip riding on top of the lower. Also returns how far it's
-- lowered (0..1).
function ViewmodelHeldMods.lower(h: HeldMods, now: number, dt: number): (CFrame, number)
	h.lowerX, h.lowerV = ViewmodelMotion.spring(
		h.lowerX,
		h.lowerV,
		if h.lowered then 1 else 0,
		VM.LOWER_FREQUENCY,
		dt
	)
	local lowerT = math.clamp(h.lowerX, 0, 1)
	local lowerCf = if lowerT > 1e-3
		then CFrame.new(VM.LOWER.pos * lowerT) * angles(VM.LOWER.rot * lowerT)
		else CFrame.identity
	local dip = if h.dipKind then DIPS[h.dipKind] else nil
	if dip then
		local dipT = (now - h.gestureAt) / dip.length
		if dipT < 1 then
			lowerCf *= keyedOffset(dip.keys, dipT)
		end
	end
	return lowerCf, lowerT
end

-- The free (left) hand, after it has been placed on the gun: a Mod gesture
-- takes it off and gestures (carrying its prop), and a held free-hand pose
-- (the Firewall's burning hand) holds it, with its flame. `root`: the rig's
-- root this frame.
function ViewmodelHeldMods.stepFreeHand(
	h: HeldMods,
	a: ViewmodelArms.Arms,
	root: CFrame,
	now: number,
	dt: number,
	hidden: boolean
)
	-- A Mod gesture: the free hand leaves the gun and gestures.
	local gesture = if h.gestureKind then VM.MOD_GESTURES[h.gestureKind] else nil
	local gestureT = if gesture then (now - h.gestureAt) / gesture.length else 1
	if gesture and gestureT < 1 and not hidden then
		local pos, dir = gestureHand(gesture.keys, gestureT)
		local point = root:PointToWorldSpace(pos)
		ViewmodelArms.place(
			a,
			"Left",
			point,
			point + root:VectorToWorldSpace(dir),
			root.RightVector
		)
		-- The prop sits upright on the fist, tipping forward into the toss.
		local propWorld = h.gestureProp
		local prop = propWorld and propWorld:FindFirstChildOfClass("Model")
		if prop and gesture.release and gestureT < gesture.release then
			local tilt = (gesture.propTilt or 0) * Ease.smooth(gestureT / gesture.release)
			prop:PivotTo(
				CFrame.new(point + root.UpVector * 0.08)
					* root.Rotation
					* CFrame.Angles(math.rad(tilt), 0, 0)
			)
		elseif propWorld then
			ViewmodelHeldMods.dropGestureProp(h)
		end
	elseif h.gestureProp then
		ViewmodelHeldMods.dropGestureProp(h)
	end
	-- A held free-hand pose (the Firewall's burning hand), and its flame.
	local pose = if h.freePose then VM.FREE_POSES[h.freePose] else nil
	local flamePart: Part?, flame: ParticleEmitter? = nil, nil
	if pose or h.handFlameEmitter then
		flamePart, flame = flameEmitter(h)
	end
	if pose and not hidden then
		local k = 1 - math.exp(-VM.FREE_POSE_RATE * dt)
		h.freePos = h.freePos:Lerp(pose.offset, k)
		h.freeDir = h.freeDir:Lerp(pose.direction, k)
		local point = root:PointToWorldSpace(h.freePos)
		ViewmodelArms.place(
			a,
			"Left",
			point,
			point + root:VectorToWorldSpace(h.freeDir),
			root.RightVector
		)
		if flamePart then
			flamePart.CFrame = CFrame.new(point + root.UpVector * 0.12)
		end
	end
	if flame then
		flame.Rate = if pose and not hidden then 40 else 0
	end
end

-- A held Mod's item, in the right hand: raise (overshoots a little),
-- breathing idle, then the use. The right arm moves onto it once the gun is
-- lowered past `lowerT` 0.05 (from lower()).
function ViewmodelHeldMods.stepItem(
	h: HeldMods,
	a: ViewmodelArms.Arms?,
	root: CFrame,
	now: number,
	dt: number,
	lowerT: number
)
	local held = h.item
	local model = held and held:FindFirstChildOfClass("Model")
	if not model then
		return
	end
	h.raiseX, h.raiseV = springStep(
		h.raiseX,
		h.raiseV,
		if h.lowered then 1 else 0,
		VM.ITEM_RAISE_FREQUENCY,
		VM.ITEM_RAISE_DAMPING,
		dt
	)
	local idle = VM.ITEM_IDLE
	local phase = now * idle.rate * math.pi * 2
	local idleCf = CFrame.new(idle.pos * Vector3.new(math.sin(phase * 0.5), math.sin(phase), 0))
		* angles(
			idle.rot * Vector3.new(math.sin(phase), math.sin(phase * 0.5), math.cos(phase * 0.5))
		)
	local useCf, gone = actionOffset(h, now)
	if gone ~= h.itemHidden then
		h.itemHidden = gone
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if gone then 1 else 0
			end
		end
	end
	local pos = VM.ITEM_OFFSET + VM.ITEM_FROM * (1 - h.raiseX)
	local itemCf = root * CFrame.new(pos) * useCf * idleCf * angles(VM.ITEM_ROTATION)
	local offset = model:GetAttribute("HoldOffset")
	model:PivotTo(if typeof(offset) == "Vector3" then itemCf * CFrame.new(offset) else itemCf)
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

return ViewmodelHeldMods
