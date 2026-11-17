--!strict
-- Hit feedback on the combat HUD (Gunplay.md §5, numbers in Config/HitFx):
-- hit / headshot / kill X markers and stacking damage numbers that fall off
-- when the stack ends. A hit a damage guard took (a Heal Orb Barrier, a Ghost
-- dash) shows a cool grey X and a BLOCKED tag at the hit point instead of a
-- number.
-- 2026-11-13, after the owner played (RIVALS references in vault/02 Art/
-- References/hitfx/): four small wedges slide in to the crosshair and hit,
-- white on the body and plain red on a headshot; their length follows the
-- damage; a kill shows the normal marker (HitFx.KILL_MARKER). Damage numbers use
-- Sarpanch (UI theme v4.1) and go red on headshots.
-- Everything is animated by hand from step(dt) (no tweens), so each element
-- always ends fully hidden, and rapid fire just restarts it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CrosshairConfig = require(ReplicatedStorage.Shared.Config.Crosshair)
local HitFx = require(ReplicatedStorage.Shared.Config.HitFx)

local Crosshair = require(script.Parent.Crosshair)

local HitFeedback = {}

type MarkerSpec = HitFx.MarkerSpec

local BLOCKED = HitFx.COLOR.blocked
local BLACK = HitFx.COLOR.outline
local NUMBER = HitFx.NUMBER
local NUMBER_FONT =
	Font.new("rbxasset://fonts/families/" .. NUMBER.family .. ".json", NUMBER.weight)

-- Damage numbers.
local POOL_SIZE = 10
local FALL = NUMBER.fall
local NUMBER_OFFSET = NUMBER.offset -- from the hit point on screen

local MARKER_BOX = 200 -- px: the marker's canvas (holds the kill wedges and ring at 1.5x)

-- The BLOCKED tag: pops in at the hit point, holds, rises and fades.
local TAG_POP = 0.1
local TAG_HOLD = 0.45
local TAG_FADE = 0.3
local TAG_RISE = 26 -- px over the fade

type Marker = {
	root: CanvasGroup,
	scale: UIScale,
	wedges: { ImageLabel },
	backs: { ImageLabel }, -- a dark wedge behind each (reads on a white-flashed body)
	ring: Frame,
	ringStroke: UIStroke,
	spec: MarkerSpec,
	t: number,
	active: boolean,
	size: number, -- wedge length from the damage (HitFx.DAMAGE_SCALE), easing to targetSize
	targetSize: number,
	matched: boolean, -- the server's confirm already merged into this pop
	k0: number, -- where this pop's shrink starts (0: from the very start; a quick re-pop starts part way)
	ringOn: boolean,
}

type DamageNumber = {
	label: TextLabel,
	stroke: UIStroke,
	scale: UIScale,
	state: "Idle" | "Stack" | "Fall",
	total: number,
	world: Vector3,
	lastHit: number,
	killed: boolean,
	head: boolean,
	t: number, -- time in the current state (pop timer while stacking)
	position: Vector2,
	fallFrom: Vector2, -- where it stood when it tipped over
	size: number, -- base scale
	offscreen: boolean, -- its hit point is out of view: not drawn
	crosshair: boolean, -- no hit point: it sits by the crosshair
	target: Instance?, -- whose number this is (one per target)
	reach: number, -- the distance scale this frame (NUMBER.distance)
}

local container: Frame? = nil
local hitMarker: Marker? = nil
local killMarker: Marker? = nil
local numbers: { DamageNumber } = {}
-- The last number with no target known (a victim that isn't streamed in).
local current: DamageNumber? = nil
-- Each target's running total and when it was last hit: a hit within
-- NUMBER.stackTime adds to it, even after its number has fallen away.
local tallies: { [Instance]: { total: number, at: number } } = {}
type Tag = {
	label: TextLabel,
	stroke: UIStroke,
	scale: UIScale,
	t: number,
	active: boolean,
	world: Vector3?, -- nil: by the crosshair
}
local tag: Tag? = nil
-- Feedback time (advanced by step). Studio only: Workspace attribute
-- VfxTimeScale slows or freezes it too, for screenshots.
local clock = 0
local studio = RunService:IsStudio()

local function easeOut(k: number): number
	local inv = 1 - math.clamp(k, 0, 1)
	return 1 - inv * inv
end

-- Marker px are designed at 1080p and scale exactly like the crosshair
-- (Config/Crosshair limits), so the X and the crosshair keep their proportions
-- on a phone.
local function screenScale(): number
	local cam = Workspace.CurrentCamera
	local c = CrosshairConfig.DEFAULT
	local h = if cam then cam.ViewportSize.Y else c.designHeight
	return math.clamp(h / c.designHeight, c.minScale, c.maxScale)
end

-- Markers ------------------------------------------------------------------------

-- Four wedges (HitFx.TEXTURES.wedge: tip at the image's bottom, dark edge baked
-- in, tinted by the spec's colour) on the diagonals, tips toward the centre,
-- and a ring, in a CanvasGroup so they fade together.
local function newMarker(parent: Instance): Marker
	local root = Instance.new("CanvasGroup")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(MARKER_BOX, MARKER_BOX)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Visible = false
	root.ZIndex = 5
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local wedges = {}
	local backs = {}
	for i = 0, 3 do
		local back = Instance.new("ImageLabel")
		back.AnchorPoint = Vector2.new(0.5, 0.5)
		back.BackgroundTransparency = 1
		back.Image = HitFx.TEXTURES.marker
		back.Visible = HitFx.MARKER_BACK.enabled
		back.ImageColor3 = HitFx.MARKER_BACK.color
		back.ImageTransparency = HitFx.MARKER_BACK.transparency
		back.Rotation = 45 + 90 * i + 90
		back.ZIndex = 1
		back.Parent = root
		backs[i + 1] = back
		local w = Instance.new("ImageLabel")
		w.AnchorPoint = Vector2.new(0.5, 0.5)
		w.BackgroundTransparency = 1
		w.Image = HitFx.TEXTURES.marker
		-- The image's tip points down; turn it to point at the centre from its
		-- diagonal (45 + 90 i degrees, screen y down): rotation = angle + 90.
		w.Rotation = 45 + 90 * i + 90
		w.ZIndex = 2
		w.Parent = root
		wedges[i + 1] = w
	end
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = HitFx.MARKER_RING.color
	ringStroke.Parent = ring
	return {
		root = root,
		scale = scale,
		wedges = wedges,
		backs = backs,
		ring = ring,
		ringStroke = ringStroke,
		spec = HitFx.MARKER.Body,
		t = 0,
		active = false,
		size = 1,
		targetSize = 1,
		matched = false,
		k0 = 0,
		ringOn = false,
	}
end

-- Colour and parts for `spec`, without restarting the animation.
local function paint(m: Marker, spec: MarkerSpec)
	m.spec = spec
	for _, w in m.wedges do
		w.ImageColor3 = spec.color
	end
	m.ringOn = spec.ring
	m.ring.Visible = spec.ring
end

-- Wedge length of the last confirmed hit: a predicted pop starts at it (the
-- same gun usually does the same damage), the confirm corrects it.
local lastSize = 1

-- Critically damped spring from 0 to 1 at angular speed `w`, `t` seconds
-- after it was let go (RIVALS' marker spring: damper 1).
local function shrinkAt(t: number, w: number): number
	local x = w * math.max(t, 0)
	return 1 - (1 + x) * math.exp(-x)
end

local function progressOf(m: Marker): number
	return m.k0 + (1 - m.k0) * shrinkAt(m.t, m.spec.speed)
end

local function popMarker(m: Marker, spec: MarkerSpec)
	-- A hit while the last marker still shows restarts most of the travel
	-- (MARKER_REPOP), so a spray pulses instead of jumping.
	m.k0 = if m.active then progressOf(m) * (1 - HitFx.MARKER_REPOP) else 0
	paint(m, spec)
	m.t = 0
	m.size = lastSize
	m.targetSize = lastSize
	m.matched = false
	m.active = true
	m.root.Visible = true
end

local function stepRing(m: Marker, px: number)
	local r = HitFx.MARKER_RING
	local k = m.t / r.life
	if k >= 1 then
		m.ring.Visible = false
		return
	end
	local radius = (r.from + (r.to - r.from) * easeOut(k)) * px
	m.ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
	m.ringStroke.Thickness = r.thickness * px * (1 - 0.5 * k)
	m.ringStroke.Transparency = k ^ 1.5
end

local function stepMarker(m: Marker, dt: number)
	if not m.active then
		return
	end
	m.t += dt
	local spec = m.spec
	if m.t >= spec.life then
		m.active = false
		m.root.Visible = false
		m.root.GroupTransparency = 1
		return
	end
	local px = screenScale()
	-- The same whole-pixel centre as Util/Crosshair, so the marker and the
	-- crosshair share one centre (the canvas is an even size).
	local cam = Workspace.CurrentCamera
	if cam then
		m.root.Position =
			UDim2.fromOffset(math.floor(cam.ViewportSize.X / 2), math.floor(cam.ViewportSize.Y / 2))
	end
	m.size += (m.targetSize - m.size) * (1 - math.exp(-HitFx.SIZE_RATE * dt))
	-- Big and wide at the hit, shrinking in tight (time-based: the same at any
	-- frame rate); solid for most of its life, then a quick fade.
	local k = progressOf(m)
	m.scale.Scale = 1
	m.root.GroupTransparency = math.clamp(m.t / spec.life, 0, 1) ^ spec.fadePow
	-- It tilts with the crosshair (the slide tilt), as RIVALS' does.
	m.root.Rotation = Crosshair.tilt()
	local tipGap = spec.fromGap + (spec.gap - spec.fromGap) * k
	local len = (spec.fromLength + (spec.length - spec.fromLength) * k) * m.size
	local centreDist = (tipGap + len / 2) * px
	for i, w in m.wedges do
		local rad = math.rad(45 + 90 * (i - 1))
		w.Position = UDim2.new(0.5, math.cos(rad) * centreDist, 0.5, math.sin(rad) * centreDist)
		w.Size = UDim2.fromOffset(len * px * HitFx.MARKER_ASPECT, len * px)
		local back = m.backs[i]
		local grow = HitFx.MARKER_BACK.grow * px
		back.Position = w.Position
		back.Size = UDim2.fromOffset(len * px * HitFx.MARKER_ASPECT + grow, len * px + grow * 1.6)
	end
	if m.ringOn then
		stepRing(m, px)
	end
end

-- Wedge length for a hit of `amount` damage.
local function damageSize(amount: number): number
	local d = HitFx.DAMAGE_SCALE
	local k = math.clamp((amount - d.low) / (d.high - d.low), 0, 1)
	return d.min + (d.max - d.min) * k
end

-- A hit: pops the X. The client pops it on its predicted hit and the server's
-- confirm calls this again about a ping later; that confirm merges into the
-- pop still playing (no second pop), upgrading it to a headshot if the server
-- says so (a re-pop: the bigger event) or quietly downgrading it.
function HitFeedback.hit(headshot: boolean)
	local m = hitMarker
	if not m then
		return
	end
	local head = HitFx.MARKER.Head
	if
		m.active
		and not m.matched
		and m.t < HitFx.CONFIRM_WINDOW
		and m.spec ~= HitFx.MARKER.Blocked
	then
		if headshot and m.spec ~= head then
			popMarker(m, head)
		elseif not headshot and m.spec == head then
			paint(m, HitFx.MARKER.Body)
		end
		m.matched = true
		return
	end
	popMarker(m, if headshot then head else HitFx.MARKER.Body)
end

-- A kill: nothing extra by default (HitFx.KILL_MARKER); when on, bigger red
-- wedges and a ring over the hit marker.
function HitFeedback.kill()
	if killMarker and HitFx.KILL_MARKER then
		popMarker(killMarker, HitFx.MARKER.Kill)
		killMarker.size = HitFx.DAMAGE_SCALE.max
		killMarker.targetSize = HitFx.DAMAGE_SCALE.max
	end
end

-- A hit that a guard took whole: the grey X and the BLOCKED tag, no number.
-- `position`: the world hit point (nil: by the crosshair).
function HitFeedback.blocked(position: Vector3?)
	if hitMarker then
		popMarker(hitMarker, HitFx.MARKER.Blocked)
	end
	local tg = tag
	if tg then
		tg.t = 0
		tg.active = true
		tg.world = position
		tg.label.Visible = true
	end
end

-- Damage numbers -------------------------------------------------------------------

local function newNumber(parent: Instance): DamageNumber
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(140, 44)
	label.BackgroundTransparency = 1
	label.FontFace = NUMBER_FONT
	label.TextSize = NUMBER.textSize
	label.TextColor3 = NUMBER.color
	label.TextTransparency = 1
	label.Text = ""
	label.Visible = false
	label.ZIndex = 4
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = BLACK
	outline.Thickness = NUMBER.stroke
	outline.Transparency = 1
	outline.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return {
		label = label,
		stroke = outline,
		scale = scale,
		state = "Idle",
		total = 0,
		world = Vector3.zero,
		lastHit = 0,
		killed = false,
		head = false,
		t = 0,
		position = Vector2.zero,
		fallFrom = Vector2.zero,
		size = 1,
		offscreen = false,
		crosshair = false,
		target = nil,
		reach = 1,
	}
end

local function setAlpha(n: DamageNumber, transparency: number)
	n.label.TextTransparency = transparency
	n.stroke.Transparency = 0.2 + 0.8 * transparency
end

local function hide(n: DamageNumber)
	if current == n then
		current = nil
	end
	n.state = "Idle"
	n.target = nil
	n.label.Visible = false
	setAlpha(n, 1)
	n.label.Rotation = 0
end

-- Where a stack's number sits: just off its hit point (it stays on the
-- target, e.g. someone burning in a Molly). nil while the point is out of
-- view: the number isn't drawn then (never parked on the crosshair).
local function screenPoint(world: Vector3, offsetScale: number?): Vector2?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local p, onScreen = cam:WorldToViewportPoint(world)
	if not onScreen or p.Z < 0 then
		return nil
	end
	local size = cam.ViewportSize
	local offset = NUMBER_OFFSET * (offsetScale or 1)
	local x = math.clamp(p.X + offset.X, 40, size.X - 40)
	local y = math.clamp(p.Y + offset.Y, 30, size.Y - 30)
	return Vector2.new(x, y)
end

-- The number's size for how far away its target is, like a BillboardGui
-- sized `studs` in the world plus `px` on screen (RIVALS' DamageGui is 15
-- studs + 250 px): it shrinks with distance, but less than the world does.
-- 1 at `ref` studs, kept between `min` and `max`.
local function reachScale(world: Vector3): number
	local cam = Workspace.CurrentCamera
	if not cam then
		return 1
	end
	local d = NUMBER.distance
	local half = math.tan(math.rad(cam.FieldOfView) / 2)
	local height = cam.ViewportSize.Y
	local function pxAt(dist: number): number
		return d.px + d.studs * height / (2 * math.max(dist, 1) * half)
	end
	local dist = (world - cam.CFrame.Position).Magnitude
	return math.clamp(pxAt(dist) / pxAt(d.ref), d.min, d.max)
end

-- Where a target's number sits: over its head (it follows them), else the
-- last hit point.
local function anchorOf(n: DamageNumber): Vector3
	local target = n.target
	local head = if target and target.Parent then target:FindFirstChild("Head") else nil
	if head and head:IsA("BasePart") then
		return head.Position + Vector3.yAxis * (head.Size.Y / 2 + NUMBER.headLift)
	end
	return n.world
end

-- Follows the hit point on screen; hidden while it's out of view. A hit
-- with no point sits by the crosshair.
local function place(n: DamageNumber)
	local cam = Workspace.CurrentCamera
	local world = anchorOf(n)
	n.reach = if n.crosshair then 1 else reachScale(world)
	local p = if n.crosshair and cam
		then cam.ViewportSize / 2 + NUMBER_OFFSET
		else screenPoint(world, n.reach)
	n.offscreen = p == nil
	n.label.Visible = p ~= nil
	if p then
		n.position = p
	end
end

local function startFall(n: DamageNumber)
	if n.offscreen then
		hide(n) -- nothing to see fall
		return
	end
	n.state = "Fall"
	n.t = 0
	n.fallFrom = n.position
end

-- Picks a free label, or the oldest falling one when all are busy.
local function takeNumber(): DamageNumber?
	local oldest: DamageNumber? = nil
	for _, n in numbers do
		if n.state == "Idle" then
			return n
		elseif n.state == "Fall" and (not oldest or n.t > oldest.t) then
			oldest = n
		end
	end
	return oldest
end

-- A confirmed hit: one number per target, which keeps counting while you
-- keep hitting them (within NUMBER.stackTime of the last hit, even if it had
-- already fallen: it comes back with the running total), and re-pops in
-- place instead of making a new one. Red for headshots, bigger on the kill.
-- Also sizes the hit marker just popped for this hit by its damage.
-- `target`: who was hit (HitConfirm.victim; nil falls back to the last
-- number with no target).
function HitFeedback.damage(
	amount: number,
	headshot: boolean,
	position: Vector3?,
	killed: boolean?,
	target: Instance?
)
	if amount ~= amount or amount <= 0 then
		return
	end
	local m = hitMarker
	if m and m.active then
		lastSize = damageSize(amount)
		m.targetSize = lastSize
	end
	local now = clock
	local world = position or Vector3.zero
	-- This target's number, if one is up.
	local n: DamageNumber? = nil
	if target then
		for _, other in numbers do
			if other.state ~= "Idle" and other.target == target then
				n = other
				break
			end
		end
	else
		local last = current
		if last and last.state ~= "Idle" and last.target == nil then
			n = last
		end
	end
	local continues = n ~= nil and not n.killed and now - n.lastHit < NUMBER.stackTime
	if n and continues and n.state == "Fall" then
		-- Tipped over already: it snaps back upright and keeps counting.
		n.state = "Stack"
		n.label.Rotation = 0
		setAlpha(n, 0)
	end
	if n and not continues then
		if n.state == "Stack" then
			startFall(n)
		end
		n = nil
	end
	-- The running total carries over a number that already fell away.
	local carried = 0
	local tally = if target then tallies[target] else nil
	if tally and not n and now - tally.at < NUMBER.stackTime then
		carried = tally.total
	end
	if not n then
		n = takeNumber()
		if not n then
			return
		end
		n.total = carried
		n.killed = false
		n.state = "Stack"
		n.label.Rotation = 0
		n.label.Visible = true
		setAlpha(n, 0)
		n.target = target
		if not target then
			current = n
		end
	end
	local stack = n :: DamageNumber
	stack.total += amount
	stack.world = if position then world else stack.world
	stack.lastHit = now
	stack.t = 0 -- pop again
	stack.killed = killed == true
	stack.head = headshot
	stack.size = if stack.killed then NUMBER.killSize elseif headshot then NUMBER.headSize else 1
	stack.label.TextColor3 = if headshot then NUMBER.headColor else NUMBER.color
	stack.stroke.Color = if headshot then NUMBER.headOutline else BLACK
	stack.label.Text = tostring(math.round(stack.total))
	stack.crosshair = position == nil and target == nil -- nowhere to sit: by the crosshair
	if target then
		tallies[target] = if stack.killed then nil else { total = stack.total, at = now }
	end
	place(stack)
end

local function stepNumber(n: DamageNumber, dt: number, now: number)
	if n.state == "Stack" then
		n.t += dt
		place(n)
		local pop = 1 - easeOut(n.t / NUMBER.popTime)
		n.scale.Scale = n.size
			* n.reach
			* (1 + (if n.head then NUMBER.headPopScale else NUMBER.popScale) * pop)
		n.label.Position = UDim2.fromOffset(n.position.X, n.position.Y)
		if now - n.lastHit > (if n.killed then NUMBER.killHold else NUMBER.hold) then
			startFall(n)
		end
	elseif n.state == "Fall" then
		n.t += dt
		local k = n.t / FALL.time
		if k >= 1 then
			hide(n)
			return
		end
		-- It tips over clockwise and drops, slowly at first (like something
		-- toppling), shrinking as it goes, and fades over the second half.
		local g = k * k
		n.position = n.fallFrom + Vector2.new(FALL.drift * k, FALL.drop * g) * n.reach
		n.label.Position = UDim2.fromOffset(n.position.X, n.position.Y)
		n.label.Rotation = FALL.tip * g
		n.scale.Scale = n.size * n.reach * (1 - (1 - FALL.shrink) * k)
		setAlpha(n, math.clamp((k - 0.45) / 0.55, 0, 1) ^ 1.5)
	end
end

-- The BLOCKED tag -------------------------------------------------------------------

local function newTag(parent: Instance): Tag
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(160, 36)
	label.BackgroundTransparency = 1
	label.FontFace = NUMBER_FONT
	label.TextSize = 22
	label.TextColor3 = BLOCKED
	label.TextTransparency = 1
	label.Text = "BLOCKED"
	label.Visible = false
	label.ZIndex = 4
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = BLACK
	outline.Thickness = 2
	outline.Transparency = 1
	outline.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return { label = label, stroke = outline, scale = scale, t = 0, active = false, world = nil }
end

local function stepTag(tg: Tag, dt: number)
	tg.t += dt
	local t = tg.t
	local fadeK = math.clamp((t - TAG_HOLD) / TAG_FADE, 0, 1)
	if fadeK >= 1 then
		tg.active = false
		tg.label.Visible = false
		tg.label.TextTransparency = 1
		tg.stroke.Transparency = 1
		return
	end
	local cam = Workspace.CurrentCamera
	local world = tg.world
	local p: Vector2? = if world
		then screenPoint(world)
		elseif cam then cam.ViewportSize / 2 + NUMBER_OFFSET
		else nil
	tg.label.Visible = p ~= nil
	if not p then
		return
	end
	local pop = 1 - easeOut(t / TAG_POP)
	tg.scale.Scale = 1 + 0.45 * pop
	tg.label.Position = UDim2.fromOffset(p.X, p.Y - TAG_RISE * easeOut(fadeK))
	local alpha = fadeK ^ 1.4
	tg.label.TextTransparency = alpha
	tg.stroke.Transparency = 0.2 + 0.8 * alpha
end

-- Setup -------------------------------------------------------------------------------

function HitFeedback.build(gui: ScreenGui)
	local root = Instance.new("Frame")
	root.Name = "HitFeedback"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 4
	root.Parent = gui
	container = root
	hitMarker = newMarker(root)
	killMarker = newMarker(root)
	for i = 1, POOL_SIZE do
		numbers[i] = newNumber(root)
	end
	tag = newTag(root)
end

function HitFeedback.step(frameDt: number)
	if not container then
		return
	end
	local dt = frameDt
	if studio then
		local scale = Workspace:GetAttribute("VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	clock += dt
	local now = clock
	if hitMarker then
		stepMarker(hitMarker, dt)
	end
	if killMarker then
		stepMarker(killMarker, dt)
	end
	for _, n in numbers do
		if n.state ~= "Idle" then
			stepNumber(n, dt, now)
		end
	end
	for target, tally in tallies do
		if now - tally.at >= NUMBER.stackTime then
			tallies[target] = nil
		end
	end
	local tg = tag
	if tg and tg.active then
		stepTag(tg, dt)
	end
end

return HitFeedback
