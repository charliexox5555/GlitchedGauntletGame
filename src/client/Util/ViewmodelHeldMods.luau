--!strict
-- Held Mods on the first-person rig (Config/Viewmodel LOWER, ITEM_*,
-- ITEM_ACTIONS, MOD_GESTURES, *_DIP, FREE_POSES):
--   * the gun lowered out of view (spring 0..1) and a gesture's dip on top;
--   * the Mod's item in the right hand (its own WorldModel under the camera,
--     like the guns): raise, breathing idle, keyed use, parts hidden or lit;
--   * Mod gestures of the free hand (Dash, Updraft, Stim), with a prop
--     carried in the fist until the release;
--   * a held free-hand pose (the Firewall's burning hand) and its flame,
--     reached by a keyed move (FREE_POSE_MOVES) and trailing the view's turn
--     (FREE_POSE_STEER);
--   * moving parts of the held item (ITEM_PART_MOVES: the Molly's pad, pin
--     and latch), turned about or slid to attachments of the model.
-- Keyed moves run on the rig's own clock (clockNow): real time, except in
-- Studio, where Workspace VfxTimeScale slows or freezes it for captures.
-- ViewmodelController keeps one state table (new()), wraps the setters here
-- in its public API and calls the per-frame steps from its render step, in
-- rig order (lower before the guns, free hand after the grips, item last).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

local LocalHide = require(script.Parent.LocalHide)
local ViewmodelArms = require(script.Parent.ViewmodelArms)
local ViewmodelMotion = require(script.Parent.ViewmodelMotion)
local ViewmodelTracks = require(script.Parent.ViewmodelTracks)

local angles = ViewmodelTracks.angles

local STUDIO = RunService:IsStudio()

-- A part of the held item on the move (VM.PartMove): where its pieces sat
-- as built (in the model's pivot space), and the turn's pivot or the slide
-- there.
type PartState = {
	move: VM.PartMove,
	startAt: number, -- on the rig's clock
	parts: { BasePart },
	rest: { CFrame },
	pivot: CFrame?,
	slide: Vector3?,
}

export type HeldMods = {
	-- The rig's clock for keyed moves (clockNow) and the os.clock() it was
	-- last advanced at.
	clock: number,
	clockAt: number,
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
	-- Its moving parts (moveItemPart), and where each part sat as built.
	partMoves: { PartState },
	partRest: { [BasePart]: CFrame },
	-- A Mod gesture (Dash, Updraft): the gun's dip and the free hand's gesture
	-- (MOD_GESTURES, DASH_DIP / UPDRAFT_DIP).
	gestureKind: string?,
	dipKind: string?,
	gestureAt: number,
	gestureScale: number, -- the gesture (and its dip) stretched by this
	-- A prop in the gesturing fist (the Stim beacon) until the gesture's release.
	gestureProp: WorldModel?,
	-- A held free-hand pose (FREE_POSES), eased toward; and the flame that
	-- burns in it (a part under the camera, moved with the fist).
	freePose: string?,
	freePos: Vector3,
	freeDir: Vector3,
	-- The keyed move into that pose (FREE_POSE_MOVES): when it began and
	-- where the hand was then.
	freeMoveAt: number,
	freeMoveFrom: Vector3,
	freeMoveDir: Vector3,
	-- The pose trailing the view's turn (FREE_POSE_STEER): the last yaw seen
	-- and the fist's sideways trail (studs).
	steerYaw: number?,
	steerX: number,
	handFlame: Part?,
	handFlameEmitter: ParticleEmitter?,
	-- A held bow (VM.BOW; nil when the item isn't one): its rig, found once
	-- per item; the charge while drawing (nil otherwise); when the draw, the
	-- release and a let-down began and the draw then; the draw last shown
	-- and the drawing fist (root space) last frame.
	bow: BowRig?,
	bowChecked: boolean,
	bowCharge: number?,
	bowDrawAt: number,
	bowReleaseAt: number,
	bowReleaseDraw: number,
	bowLetAt: number,
	bowLetDraw: number,
	bowFullAt: number,
	bowShown: number,
	bowHand: Vector3,
}

-- A bow's rig (model pivot space): each limb's pieces as built, its pivot
-- and string tip, which way it turns to flex; the strings and the line
-- across each (kept when re-aimed); the nock, the draw, the nocked bolt.
type BowLimb = { parts: { BasePart }, rest: { CFrame }, pivot: Vector3, tip: Vector3, sign: number }
type BowRig = {
	limbs: { BowLimb },
	axis: Vector3,
	strings: { BasePart },
	across: { Vector3 },
	nock: Vector3,
	draw: Vector3,
	bolt: { BasePart },
	boltRest: { CFrame },
	charge: BasePart?,
	chargeColour: Color3,
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
		clock = 0,
		clockAt = os.clock(),
		lowered = false,
		lowerX = 0,
		lowerV = 0,
		item = nil,
		raiseX = 0,
		raiseV = 0,
		actionKind = nil,
		actionAt = -math.huge,
		itemHidden = false,
		partMoves = {},
		partRest = {},
		gestureKind = nil,
		dipKind = nil,
		gestureAt = -math.huge,
		gestureScale = 1,
		gestureProp = nil,
		freePose = nil,
		freePos = VM.FREE_POSE_FROM,
		freeDir = Vector3.new(-0.3, -0.8, 0.5),
		freeMoveAt = -math.huge,
		freeMoveFrom = VM.FREE_POSE_FROM,
		freeMoveDir = Vector3.new(-0.3, -0.8, 0.5),
		steerYaw = nil,
		steerX = 0,
		handFlame = nil,
		handFlameEmitter = nil,
		bow = nil,
		bowChecked = false,
		bowCharge = nil,
		bowDrawAt = -math.huge,
		bowReleaseAt = -math.huge,
		bowReleaseDraw = 0,
		bowLetAt = -math.huge,
		bowLetDraw = 0,
		bowFullAt = -math.huge,
		bowShown = math.huge,
		bowHand = VM.FREE_POSE_FROM,
	}
end

local function resetBow(h: HeldMods)
	h.bow = nil
	h.bowChecked = false
	h.bowCharge = nil
	h.bowDrawAt = -math.huge
	h.bowReleaseAt = -math.huge
	h.bowReleaseDraw = 0
	h.bowLetAt = -math.huge
	h.bowLetDraw = 0
	h.bowFullAt = -math.huge
	h.bowShown = math.huge
end

-- The rig's clock, advanced to now: seconds of real time, scaled by the
-- Studio-only Workspace attribute VfxTimeScale (0 freezes a move mid-way).
local function clockNow(h: HeldMods): number
	local now = os.clock()
	local scale = 1
	if STUDIO then
		local value = Workspace:GetAttribute("VfxTimeScale")
		if typeof(value) == "number" then
			scale = math.clamp(value, 0, 1)
		end
	end
	h.clock += (now - h.clockAt) * scale
	h.clockAt = now
	return h.clock
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
	table.clear(h.partMoves)
	table.clear(h.partRest)
	resetBow(h)
	if not template or not cam then
		return
	end
	local hold = VM.ITEM_HOLDS[template.Name]
	h.item = visualCopy(template, "ViewmodelItem", cam, hold and hold.scale)
end

-- A Mod gesture: the free hand plays MOD_GESTURES[`gesture`] ("DashForward",
-- "DashBack", "DashLeft", "DashRight" camera-relative, "UpdraftDown",
-- "MollyPinPull", "StimToss") while the gun moves by `dip` ("Dash": out of
-- view; "Updraft": down while rising; "Stim": a short dip; nil: the gun stays as
-- it is). `prop`: a model carried in the fist until the gesture's release
-- (the Stim beacon), at its propScale. `duration`: the gesture takes this
-- long instead of its `length`, its dip stretched by the same factor (the
-- Recall's wind-up, already running when the client hears of it).
function ViewmodelHeldMods.gesture(
	h: HeldMods,
	gesture: string,
	dip: string?,
	prop: Model?,
	duration: number?
)
	local g = VM.MOD_GESTURES[gesture]
	if not g or (dip ~= nil and not DIPS[dip]) then
		return
	end
	h.gestureKind = gesture
	h.dipKind = dip
	h.gestureAt = clockNow(h)
	h.gestureScale = if duration and duration > 0 then duration / g.length else 1
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
	if pose and pose ~= h.freePose and VM.FREE_POSE_MOVES[pose] then
		-- A keyed move into the pose, from wherever the hand is.
		h.freeMoveAt = clockNow(h)
		h.freeMoveFrom = h.freePos
		h.freeMoveDir = h.freeDir
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

-- Moves one part of the held item (VM.PartMove): a turn about a pivot
-- attachment, or a slide onto an attachment. Nothing happens when the item
-- has no such part or attachment. Every move runs from where the part was
-- built; a new move of the same part replaces the one before.
function ViewmodelHeldMods.moveItemPart(h: HeldMods, move: VM.PartMove)
	local held = h.item
	local model = held and held:FindFirstChildOfClass("Model")
	if not model then
		return
	end
	local parts: { BasePart } = {}
	local found: { [string]: Attachment } = {}
	local prefix = move.part .. "_"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == move.part or string.sub(d.Name, 1, #prefix) == prefix then
				table.insert(parts, d)
			end
		elseif d:IsA("Attachment") then
			found[d.Name] = d
		end
	end
	if #parts == 0 then
		return
	end
	local base = model:GetPivot()
	local rest: { CFrame } = {}
	for i, p in parts do
		local built = h.partRest[p]
		if not built then
			built = base:ToObjectSpace(p.CFrame)
			h.partRest[p] = built
		end
		rest[i] = built
	end
	local pivot: CFrame? = nil
	local slide: Vector3? = nil
	local pivotAt = if move.pivot then found[move.pivot] else nil
	local toAt = if move.to then found[move.to] else nil
	if pivotAt and move.angle then
		pivot = base:ToObjectSpace(pivotAt.WorldCFrame)
	elseif toAt then
		local fromAt = if move.from then found[move.from] else nil
		local start = if fromAt
			then base:PointToObjectSpace(fromAt.WorldPosition)
			else rest[1] * (parts[1].Size * (move.anchor or Vector3.zero) * 0.5)
		slide = base:PointToObjectSpace(toAt.WorldPosition) - start
	else
		return
	end
	for i = #h.partMoves, 1, -1 do
		if h.partMoves[i].move.part == move.part then
			table.remove(h.partMoves, i)
		end
	end
	table.insert(h.partMoves, {
		move = move,
		startAt = clockNow(h) + move.at,
		parts = parts,
		rest = rest,
		pivot = pivot,
		slide = slide,
	})
end

-- Plays VM.ITEM_PART_MOVES[`sequence`] on the held item (each move at its
-- own `at`).
function ViewmodelHeldMods.itemParts(h: HeldMods, sequence: string)
	local moves = VM.ITEM_PART_MOVES[sequence]
	if moves then
		for _, move in moves do
			ViewmodelHeldMods.moveItemPart(h, move)
		end
	end
end

-- A use, keyframed on the held item (Config/Viewmodel ITEM_ACTIONS): "Throw"
-- (the item leaves the hand at the release), "Place" or "Heal".
function ViewmodelHeldMods.itemAction(h: HeldMods, kind: string)
	if VM.ITEM_ACTIONS[kind] then
		h.actionKind = kind
		h.actionAt = clockNow(h)
	end
end

-- The draw shown at `clock` (the string's place, 0 rest .. 1 full draw;
-- below 0 while it rings past rest after a release), and how much of the
-- full-draw tremble is on.
local function bowDrawAt(h: HeldMods, clock: number): (number, number)
	local B = VM.BOW
	local charge = h.bowCharge
	if charge then
		local u = math.clamp((clock - h.bowDrawAt) / B.nockTime, 0, 1)
		local hand = 1 - (1 - u) ^ 4 -- the hand on the string first
		local draw = (1 - (1 - charge) ^ B.drawEase) * hand
		local tremble =
			Ease.smooth(math.clamp((charge - B.tremble.from) / (1 - B.tremble.from), 0, 1))
		return draw, tremble
	end
	local r = B.release
	local t = clock - h.bowReleaseAt
	if t < r.snap then
		-- Let go: the string accelerates to rest.
		local u = t / r.snap
		return h.bowReleaseDraw * (1 - u * u), 0
	end
	local ring = t - r.snap
	if ring < r.decay * 6 then
		return -h.bowReleaseDraw * r.overshoot * math.exp(-ring / r.decay) * math.sin(
			ring * r.ring * 2 * math.pi
		),
			0
	end
	local l = clock - h.bowLetAt
	if l < B.letDown then
		return h.bowLetDraw * (1 - Ease.smooth(l / B.letDown)), 0
	end
	return 0, 0
end

-- A held bow's draw: the charge 0..1 while LMB is held (the free hand comes
-- to the string and draws it), nil to let it down to rest (a cancel). No
-- bow in the hand: nothing happens.
function ViewmodelHeldMods.setItemCharge(h: HeldMods, charge: number?)
	local clock = clockNow(h)
	if charge then
		if not h.bowCharge then
			h.bowDrawAt = clock
			h.bowFullAt = -math.huge
		end
		h.bowCharge = math.clamp(charge, 0, 1)
	elseif h.bowCharge then
		h.bowLetDraw = bowDrawAt(h, clock)
		h.bowLetAt = clock
		h.bowCharge = nil
	end
end

-- Lets the drawn bow go: the string snaps forward and rings, the bow hand
-- kicks and settles, the drawing hand follows through and drops away.
function ViewmodelHeldMods.releaseItem(h: HeldMods)
	local clock = clockNow(h)
	h.bowReleaseDraw = if h.bowCharge then bowDrawAt(h, clock) else 0
	h.bowReleaseAt = clock
	h.bowCharge = nil
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
	h.gestureScale = 1
	h.steerYaw = nil
	h.steerX = 0
	ViewmodelHeldMods.dropGestureProp(h)
	ViewmodelHeldMods.setFreeHand(h, nil)
end

-- Keyed motion ---------------------------------------------------------------------

-- The speed through a key on one axis (Fritsch-Butland, the monotone
-- "PCHIP" cubic Util/ViewmodelTracks uses for its smooth tracks): a weighted
-- harmonic mean of the two segments' speeds, zero where they turn back. A
-- move out of a held pose starts from rest, a fast move brakes into the next
-- hold, and nothing drifts past a key (overshoot is keyed).
local function pchip(a: number, b: number, c: number, da: number, db: number): number
	local sa, sb = (b - a) / da, (c - b) / db
	if sa * sb <= 0 then
		return 0
	end
	return 3 * (da + db) / ((2 * db + da) / sa + (db + 2 * da) / sb)
end

-- `field` of key `i` (zero when the key leaves it out: an ItemKey's `arm`).
local function valueOf(keys: { any }, i: number, field: string): Vector3
	local v = keys[i][field]
	return if typeof(v) == "Vector3" then v else Vector3.zero
end

-- The velocity `field` passes key `i` with (zero at both ends).
local function through(keys: { any }, i: number, field: string): Vector3
	if i <= 1 or i >= #keys then
		return Vector3.zero
	end
	local da, db = keys[i].t - keys[i - 1].t, keys[i + 1].t - keys[i].t
	if da <= 1e-6 or db <= 1e-6 then
		return Vector3.zero
	end
	local a = valueOf(keys, i - 1, field)
	local b = valueOf(keys, i, field)
	local c = valueOf(keys, i + 1, field)
	return Vector3.new(
		pchip(a.X, b.X, c.X, da, db),
		pchip(a.Y, b.Y, c.Y, da, db),
		pchip(a.Z, b.Z, c.Z, da, db)
	)
end

-- The segment of `keys` (each with a `t`) that holds `t`: its first key's
-- index and how far through it (0..1).
local function segment(keys: { any }, t: number): (number, number)
	local n = #keys
	if t <= keys[1].t then
		return 1, 0
	end
	for i = 2, n do
		if t <= keys[i].t then
			return i - 1, (t - keys[i - 1].t) / math.max(keys[i].t - keys[i - 1].t, 1e-3)
		end
	end
	return n - 1, 1
end

-- `field` at `u` through the segment from key `i`: smoothstep between the
-- two keys, or (`smooth`) the spline through all of them.
local function keyed(keys: { any }, i: number, u: number, field: string, smooth: boolean?): Vector3
	local a, b = valueOf(keys, i, field), valueOf(keys, i + 1, field)
	if not smooth then
		return a:Lerp(b, Ease.smooth(u))
	end
	local span = keys[i + 1].t - keys[i].t
	local u2, u3 = u * u, u * u * u
	local h10, h01, h11 = u3 - 2 * u2 + u, -2 * u3 + 3 * u2, u3 - u2
	return a * (1 - h01)
		+ through(keys, i, field) * (span * h10)
		+ b * h01
		+ through(keys, i + 1, field) * (span * h11)
end

-- Keyed offsets (ITEM_ACTIONS, the dips) at `t` 0..1, and the keys' `arm`
-- there (added to the arm direction).
local function keyedOffset(action: VM.ItemAction, t: number): (CFrame, Vector3)
	if t < 0 or t >= 1 then
		return CFrame.identity, Vector3.zero
	end
	local keys = action.keys
	local i, u = segment(keys, t)
	local smooth = action.smooth
	local offset = CFrame.new(keyed(keys, i, u, "pos", smooth))
		* angles(keyed(keys, i, u, "rot", smooth))
	return offset, keyed(keys, i, u, "arm", smooth)
end

-- The action's offset at `clock` (identity when none is playing), whether
-- the item has left the hand, and what the move adds to the arm direction.
local function actionOffset(h: HeldMods, clock: number): (CFrame, boolean, Vector3)
	local action = if h.actionKind then VM.ITEM_ACTIONS[h.actionKind] else nil
	if not action then
		return CFrame.identity, false, Vector3.zero
	end
	local t = (clock - h.actionAt) / action.length
	local gone = action.hideAt ~= nil and t >= action.hideAt
	local offset, arm = keyedOffset(action, t)
	return offset, gone, arm
end

-- A free hand at `t` 0..1 through `keys`: fist position and arm direction
-- (root space).
local function handAt(keys: { VM.HandKey }, t: number, smooth: boolean?): (Vector3, Vector3)
	if t >= 1 then
		local last = keys[#keys]
		return last.pos, last.dir
	end
	local i, u = segment(keys, t)
	return keyed(keys, i, u, "pos", smooth), keyed(keys, i, u, "dir", smooth)
end

-- Where gesture `name`'s prop is at its release, in root space (the Stim
-- beacon's world twin starts there: Util/StimFx).
function ViewmodelHeldMods.releasePoint(name: string): Vector3?
	local g = VM.MOD_GESTURES[name]
	local release = g and g.release
	if not g or not release then
		return nil
	end
	local pos = handAt(g.keys, release, g.smooth)
	return pos + Vector3.new(0, VM.GESTURE_PROP_LIFT, 0)
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
function ViewmodelHeldMods.lower(h: HeldMods, _now: number, dt: number): (CFrame, number)
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
		local dipT = (clockNow(h) - h.gestureAt) / (dip.length * h.gestureScale)
		if dipT < 1 then
			lowerCf *= (keyedOffset(dip, dipT))
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
	_now: number,
	dt: number,
	hidden: boolean
)
	local clock = clockNow(h)
	-- A Mod gesture: the free hand leaves the gun and gestures.
	local gesture = if h.gestureKind then VM.MOD_GESTURES[h.gestureKind] else nil
	local gestureT = if gesture
		then (clock - h.gestureAt) / (gesture.length * h.gestureScale)
		else 1
	if gesture and gestureT < 1 and not hidden then
		local pos, dir = handAt(gesture.keys, gestureT, gesture.smooth)
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
				CFrame.new(point + root.UpVector * VM.GESTURE_PROP_LIFT)
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
	local name = h.freePose
	local pose = if name then VM.FREE_POSES[name] else nil
	local flamePart: Part?, flame: ParticleEmitter? = nil, nil
	if pose or h.handFlameEmitter then
		flamePart, flame = flameEmitter(h)
	end
	if pose and name and not hidden then
		local move = VM.FREE_POSE_MOVES[name]
		local moveT = if move then (clock - h.freeMoveAt) / move.length else 1
		if move and moveT < 1 then
			-- The keyed move into the pose, bent toward where the hand really
			-- was when it began (a cast before the hand was up).
			local pos, dir = handAt(move.keys, moveT, move.smooth)
			local first = move.keys[1]
			local off = 1 - Ease.smooth(moveT / VM.FREE_POSE_MOVE_BLEND)
			h.freePos = pos + (h.freeMoveFrom - first.pos) * off
			h.freeDir = dir + (h.freeMoveDir - first.dir) * off
		else
			local k = 1 - math.exp(-VM.FREE_POSE_RATE * dt)
			h.freePos = h.freePos:Lerp(pose.offset, k)
			h.freeDir = h.freeDir:Lerp(pose.direction, k)
		end
		-- Guiding: the fist trails the view's turn and catches up.
		local steer = VM.FREE_POSE_STEER[name]
		local look = root.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local goal = 0
		local last = h.steerYaw
		if steer and last and dt > 1e-4 then
			local turned = (yaw - last + math.pi) % (2 * math.pi) - math.pi
			goal = math.clamp(turned / dt * steer.lag, -steer.max, steer.max)
		end
		h.steerYaw = yaw
		h.steerX = Ease.approach(h.steerX, goal, if steer then steer.rate else 12, dt)
		local swing = if steer then steer.swing else 0
		local point = root:PointToWorldSpace(h.freePos + Vector3.new(h.steerX, 0, 0))
		ViewmodelArms.place(
			a,
			"Left",
			point,
			point + root:VectorToWorldSpace(h.freeDir - Vector3.new(h.steerX * swing, 0, 0)),
			root.RightVector
		)
		if flamePart then
			flamePart.CFrame = CFrame.new(point + root.UpVector * 0.12)
		end
	else
		h.steerYaw = nil
		h.steerX = 0
	end
	if flame then
		flame.Rate = if pose and not hidden then 40 else 0
	end
end

-- The held item's moving parts, after the item itself has been placed:
-- each one from where it was built to its turn or slide at `clock`.
local function stepParts(h: HeldMods, model: Model, clock: number)
	local base = model:GetPivot()
	for i = #h.partMoves, 1, -1 do
		local s = h.partMoves[i]
		local move = s.move
		local t = clock - s.startAt
		if t <= 0 then
			continue
		end
		local k = TweenService:GetValue(
			math.clamp(t / math.max(move.time, 1e-3), 0, 1),
			move.style or Enum.EasingStyle.Quad,
			move.dir or Enum.EasingDirection.Out
		)
		local back = move.back
		local held = move.time + (move.hold or 0)
		if back and t > held then
			k = 1 - Ease.smooth((t - held) / math.max(back, 1e-3))
			if k <= 0 then
				table.remove(h.partMoves, i) -- back where it was built
			end
		end
		local pivot, slide = s.pivot, s.slide
		local moved = if pivot and move.angle
			then pivot * angles(move.angle * k) * pivot:Inverse()
			elseif slide then CFrame.new(slide * k)
			else CFrame.identity
		for j, part in s.parts do
			part.CFrame = base * moved * s.rest[j]
		end
	end
end

-- The held item's bow rig (VM.BOW), or nil when it isn't a bow: every
-- attachment and string it needs, else nothing moves. Attachments give
-- positions only (the builder drops their rotation), so the limbs turn
-- about the bow's sideways axis, each the way that brings its tip back.
local function findBow(h: HeldMods, model: Model): BowRig?
	h.bowChecked = true
	local B = VM.BOW
	local found: { [string]: Attachment } = {}
	local named: { [string]: BasePart } = {}
	local bolt: { BasePart } = {}
	local boltPrefix = B.bolt .. "_"
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") then
			found[d.Name] = d
		elseif d:IsA("BasePart") then
			named[d.Name] = d
			if d.Name == B.bolt or string.sub(d.Name, 1, #boltPrefix) == boltPrefix then
				table.insert(bolt, d)
			end
		end
	end
	for _, name in { "LimbTopPivot", "LimbBottomPivot", "TipTop", "TipBottom", "Nock", "NockDrawn" } do
		if not found[name] then
			return nil
		end
	end
	local stringTop, stringBottom = named.StringTop, named.StringBottom
	if not stringTop or not stringBottom then
		return nil
	end
	local base = model:GetPivot()
	local function at(name: string): Vector3
		return base:PointToObjectSpace(found[name].WorldPosition)
	end
	local nock = at("Nock")
	local draw = at("NockDrawn") - nock
	local axis = (at("TipTop") - at("TipBottom")):Cross(draw)
	if axis.Magnitude < 1e-4 then
		return nil
	end
	axis = axis.Unit
	local limbs: { BowLimb } = {}
	for _, side in { "Top", "Bottom" } do
		local pivot, tip = at("Limb" .. side .. "Pivot"), at("Tip" .. side)
		local turned = CFrame.fromAxisAngle(axis, 0.1) * (tip - pivot) + pivot
		local limb: BowLimb = {
			parts = {},
			rest = {},
			pivot = pivot,
			tip = tip,
			sign = if (turned - nock - draw).Magnitude < (tip - nock - draw).Magnitude
				then 1
				else -1,
		}
		for _, name in if side == "Top" then B.limbs.Top else B.limbs.Bottom do
			local p = named[name]
			if p then
				table.insert(limb.parts, p)
				table.insert(limb.rest, base:ToObjectSpace(p.CFrame))
			end
		end
		table.insert(limbs, limb)
	end
	local boltRest: { CFrame } = {}
	for i, p in bolt do
		boltRest[i] = base:ToObjectSpace(p.CFrame)
	end
	local charge = named[B.chargePart]
	return {
		limbs = limbs,
		axis = axis,
		strings = { stringTop, stringBottom },
		across = {
			base:VectorToObjectSpace(stringTop.CFrame.RightVector),
			base:VectorToObjectSpace(stringBottom.CFrame.RightVector),
		},
		nock = nock,
		draw = draw,
		bolt = bolt,
		boltRest = boltRest,
		charge = charge,
		chargeColour = if charge then charge.Color else Color3.new(1, 1, 1),
	}
end

-- Poses the bow at draw `shown` (limbs flexed about their pivots, the nock
-- and bolt drawn back, each string re-aimed and stretched from its tip to
-- the nock) and lights its charge strip. Returns the nock (model space).
local function stepBow(
	h: HeldMods,
	rig: BowRig,
	model: Model,
	clock: number,
	shown: number
): Vector3
	local B = VM.BOW
	local nock = rig.nock + rig.draw * shown
	if shown ~= h.bowShown then
		h.bowShown = shown
		local base = model:GetPivot()
		local flex = math.rad(B.flex) * shown
		for i, limb in rig.limbs do
			local pivot = limb.pivot
			local turn = CFrame.new(pivot)
				* CFrame.fromAxisAngle(rig.axis, flex * limb.sign)
				* CFrame.new(-pivot)
			for j, part in limb.parts do
				part.CFrame = base * turn * limb.rest[j]
			end
			local s = rig.strings[i]
			local span = turn * limb.tip - nock
			local length = span.Magnitude
			if length > 1e-3 then
				local up = span / length
				local across = rig.across[i]
				local right = across - up * across:Dot(up)
				if right.Magnitude > 1e-4 then
					s.CFrame = base * CFrame.fromMatrix(nock + span * 0.5, right.Unit, up)
					s.Size = Vector3.new(s.Size.X, length, s.Size.Z)
				end
			end
		end
		local slide = CFrame.new(rig.draw * math.max(shown, 0))
		for i, part in rig.bolt do
			part.CFrame = base * slide * rig.boltRest[i]
		end
	end
	-- The charge strip fills with the charge and flashes once at full.
	local strip = rig.charge
	if strip then
		local c = h.bowCharge or 0
		local lit = 1 - (1 - c) * (1 - c)
		local look = B.charge
		local colour = rig.chargeColour:Lerp(Color3.new(0, 0, 0), look.dimColour * (1 - lit))
		if c >= 1 then
			if h.bowFullAt == -math.huge then
				h.bowFullAt = clock
			end
			colour = colour:Lerp(
				Color3.new(1, 1, 1),
				0.85 * math.exp(-(clock - h.bowFullAt) / look.flash)
			)
		end
		strip.Transparency = look.dim * (1 - lit)
		strip.Color = colour
	end
	return nock
end

-- The bow hand's move on top of the hold: pushed out as it's drawn, a
-- tremble at full draw, the kick at the release settling with a small
-- overshoot.
local function bowOffset(h: HeldMods, clock: number, shown: number, tremble: number): CFrame
	local B = VM.BOW
	local d = math.max(shown, 0)
	local cf = CFrame.new(B.drawPush.pos * d) * angles(B.drawPush.rot * d)
	if tremble > 0 then
		local w = clock * B.tremble.rate * 2 * math.pi
		cf *= angles(Vector3.new(math.sin(w), math.cos(w * 0.7), 0) * B.tremble.rot * tremble)
	end
	local k = B.kick
	local t = clock - h.bowReleaseAt
	if t >= 0 and t < k.out + k.decay * 6 then
		local strength = k.tap + (1 - k.tap) * h.bowReleaseDraw
		local after = t - k.out
		local amount = if t < k.out
			then Ease.out(t / k.out)
			else math.exp(-after / k.decay) * math.cos(after * k.ring * 2 * math.pi)
		amount *= strength
		cf *= CFrame.new(k.pos * amount) * angles(k.rot * amount)
	end
	return cf
end

-- The drawing hand on a bow (the hand the bow isn't in): out of view at
-- rest (a block forearm reaching the far string covers the screen), up to
-- the string as the draw starts, pulling straight back to the cheek with
-- the nock, riding it forward and dropping on a let-down; after the release
-- it follows through back toward the ear, holds, and drops away.
local function stepBowHand(
	h: HeldMods,
	a: ViewmodelArms.Arms,
	root: CFrame,
	clock: number,
	nockWorld: Vector3,
	bowCf: CFrame,
	side: ViewmodelArms.Side
)
	local B = VM.BOW
	local from = root:PointToWorldSpace(B.handFrom)
	local point: Vector3
	local w: number
	local f = B.follow
	local t = clock - h.bowReleaseAt
	if not h.bowCharge and t >= 0 and t < f.out + f.hold + f.back then
		local strength = B.kick.tap + (1 - B.kick.tap) * h.bowReleaseDraw
		local k = Ease.out(math.clamp(t / f.out, 0, 1))
		w = 1 - Ease.smooth(math.clamp((t - f.out - f.hold) / f.back, 0, 1))
		point = from:Lerp(root:PointToWorldSpace(h.bowHand + f.offset * (k * strength)), w)
	elseif h.bowCharge then
		local u = math.clamp((clock - h.bowDrawAt) / B.nockTime, 0, 1)
		w = 1 - (1 - u) ^ 3
		point = from:Lerp(nockWorld + bowCf:VectorToWorldSpace(B.hand), w)
		h.bowHand = root:PointToObjectSpace(point)
	else
		local l = clock - h.bowLetAt
		if l < 0 or l >= B.letDown * 1.6 then
			return
		end
		w = 1 - Ease.smooth(math.clamp((l - B.letDown * 0.5) / B.letDown, 0, 1))
		point = from:Lerp(nockWorld + bowCf:VectorToWorldSpace(B.hand), w)
	end
	if w <= 1e-3 then
		return
	end
	-- The drawing elbow comes up level as the draw goes back.
	local toward = point + root:VectorToWorldSpace(B.handDir)
	ViewmodelArms.place(a, side, point, toward, root.RightVector)
end

-- A held Mod's item, in the right hand: raise (overshoots a little),
-- breathing idle, then the use. The right arm moves onto it once the gun is
-- lowered past `lowerT` 0.05 (from lower()).
function ViewmodelHeldMods.stepItem(
	h: HeldMods,
	a: ViewmodelArms.Arms?,
	root: CFrame,
	_now: number,
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
	local clock = clockNow(h)
	-- A Mod's own hold, where it has one (Config/Viewmodel ITEM_HOLDS).
	local hold = VM.ITEM_HOLDS[model.Name]
	local idle = VM.ITEM_IDLE
	local phase = clock * idle.rate * math.pi * 2
	local idleCf = CFrame.new(idle.pos * Vector3.new(math.sin(phase * 0.5), math.sin(phase), 0))
		* angles(
			idle.rot * Vector3.new(math.sin(phase), math.sin(phase * 0.5), math.cos(phase * 0.5))
		)
	local useCf, gone, useArm = actionOffset(h, clock)
	if gone ~= h.itemHidden then
		h.itemHidden = gone
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				LocalHide.set(d, if gone then 1 else 0)
			end
		end
	end
	-- A bow: its draw this frame and the bow hand's move with it.
	if not h.bowChecked then
		h.bow = findBow(h, model)
	end
	local rig = h.bow
	local shown, tremble = 0, 0
	if rig then
		shown, tremble = bowDrawAt(h, clock)
		if tremble > 0 then
			local w = clock * VM.BOW.tremble.rate * 2 * math.pi
			local wobble = math.sin(w) + 0.5 * math.sin(w * 1.7)
			shown += tremble * VM.BOW.tremble.nock / rig.draw.Magnitude * wobble
		end
		useCf *= bowOffset(h, clock, shown, tremble)
	end
	local pos = ((hold and hold.offset) or VM.ITEM_OFFSET)
		+ ((hold and hold.from) or VM.ITEM_FROM) * (1 - h.raiseX)
	local grip = root * CFrame.new(pos) * useCf * idleCf
	local itemCf = grip * angles((hold and hold.rotation) or VM.ITEM_ROTATION)
	-- Where the item sits from the grip: the builder's HoldOffset, plus the
	-- hold's own `lift` (clear of the fist).
	local offset = model:GetAttribute("HoldOffset")
	local lift = (hold and hold.lift) or Vector3.zero
	model:PivotTo(
		itemCf * CFrame.new((if typeof(offset) == "Vector3" then offset else Vector3.zero) + lift)
	)
	if #h.partMoves > 0 then
		stepParts(h, model, clock)
	end
	local nock = if rig then stepBow(h, rig, model, clock, shown) else nil
	if a and lowerT > 0.05 then
		local hand = grip.Position
		local arm = ((hold and hold.arm) or VM.ITEM_ARM) + useArm
		local side: ViewmodelArms.Side = (hold and hold.side) or "Right"
		ViewmodelArms.place(a, side, hand, hand + root:VectorToWorldSpace(arm), root.RightVector)
		if nock then
			local base = model:GetPivot()
			local other: ViewmodelArms.Side = if side == "Left" then "Right" else "Left"
			stepBowHand(h, a, root, clock, base:PointToWorldSpace(nock), base, other)
		end
	end
end

return ViewmodelHeldMods
