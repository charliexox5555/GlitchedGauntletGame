--!strict
-- Hit feedback on the combat HUD (Gunplay.md §5): hit / headshot / kill X
-- markers and stacking damage numbers that fall off when the stack ends.
-- Everything is animated by hand from step(dt) (no tweens), so each element
-- always ends fully hidden, and rapid fire just restarts it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HitFeedback = {}

local WHITE = Color3.new(1, 1, 1)
local AMBER = Color3.fromHex("F2C94C") -- headshots
local RED = Color3.fromHex("EB5757") -- kills
local BLACK = Color3.new(0, 0, 0)
local NUMBER_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)

-- Damage numbers.
local POOL_SIZE = 10
local STACK_TIME = 0.9 -- a stack ends this long after its last hit
local KILL_HOLD = 0.45 -- a killing stack holds this long, then falls
local STACK_RANGE = 8 -- studs: hits further from the last one start a new stack
local POP_TIME = 0.12
local FALL_TIME = 0.6
local FALL_GRAVITY = 950 -- px/s²
local NUMBER_OFFSET = Vector2.new(34, -30) -- from the hit point on screen

type MarkerStyle = {
	color: Color3,
	life: number,
	peak: number, -- pop-in scale
	kick: number, -- degrees of rotation kick
}

local STYLES: { [string]: MarkerStyle } = {
	Body = { color = WHITE, life = 0.2, peak = 1.35, kick = 6 },
	Head = { color = AMBER, life = 0.28, peak = 1.55, kick = 10 },
	Kill = { color = RED, life = 0.45, peak = 1.7, kick = 16 },
}

type Marker = {
	root: CanvasGroup,
	scale: UIScale,
	bars: { Frame },
	reach: number, -- bar distance from the centre
	style: MarkerStyle,
	spin: number,
	t: number,
	active: boolean,
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
	t: number, -- time in the current state (pop timer while stacking)
	position: Vector2,
	velocity: Vector2,
	spin: number,
	size: number, -- base scale
	offscreen: boolean, -- its hit point is out of view: not drawn
	crosshair: boolean, -- no hit point: it sits by the crosshair
}

local container: Frame? = nil
local hitMarker: Marker? = nil
local killMarker: Marker? = nil
local numbers: { DamageNumber } = {}
local current: DamageNumber? = nil
-- Feedback time (advanced by step). Studio only: Workspace attribute
-- VfxTimeScale slows or freezes it too, for screenshots.
local clock = 0
local studio = RunService:IsStudio()

local function easeOut(k: number): number
	local inv = 1 - math.clamp(k, 0, 1)
	return 1 - inv * inv
end

-- Markers ------------------------------------------------------------------------

-- An X of four bars in a CanvasGroup, so the bars and their outlines fade together.
local function newMarker(parent: Instance, size: number, thickness: number): Marker
	local root = Instance.new("CanvasGroup")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(size * 4, size * 4)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Visible = false
	root.ZIndex = 5
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local bars = {}
	for i = 0, 3 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.fromOffset(size * 0.6, thickness)
		bar.Rotation = 45 + 90 * i
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = WHITE
		bar.Parent = root
		local outline = Instance.new("UIStroke")
		outline.Color = BLACK
		outline.Thickness = 1
		outline.Transparency = 0.35
		outline.Parent = bar
		bars[i + 1] = bar
	end
	return {
		root = root,
		scale = scale,
		bars = bars,
		reach = size * 0.62,
		style = STYLES.Body,
		spin = 0,
		t = 0,
		active = false,
	}
end

local function popMarker(m: Marker, style: MarkerStyle)
	m.style = style
	for _, bar in m.bars do
		bar.BackgroundColor3 = style.color
	end
	m.spin = (if math.random() < 0.5 then -1 else 1) * style.kick * (0.6 + math.random() * 0.4)
	m.t = 0
	m.active = true
	m.root.Visible = true
end

local function stepMarker(m: Marker, dt: number)
	if not m.active then
		return
	end
	m.t += dt
	local style = m.style
	if m.t >= style.life then
		m.active = false
		m.root.Visible = false
		m.root.GroupTransparency = 1
		return
	end
	local life = m.t / style.life
	-- Pop in big, snap back; rotation kick settles the same way.
	local settle = 1 - easeOut(m.t / 0.08)
	m.scale.Scale = 1 + (style.peak - 1) * settle
	m.root.Rotation = m.spin * settle
	-- Hold, then fade; the arms drift outward as it goes.
	local hold = 0.4
	m.root.GroupTransparency = if life < hold then 0 else ((life - hold) / (1 - hold)) ^ 1.4
	local reach = m.reach * (1 + 0.35 * life)
	for i, bar in m.bars do
		local rad = math.rad(45 + 90 * (i - 1))
		bar.Position = UDim2.new(0.5, math.cos(rad) * reach, 0.5, math.sin(rad) * reach)
	end
end

function HitFeedback.hit(headshot: boolean)
	if hitMarker then
		popMarker(hitMarker, if headshot then STYLES.Head else STYLES.Body)
	end
end

function HitFeedback.kill()
	if killMarker then
		popMarker(killMarker, STYLES.Kill)
	end
end

-- Damage numbers -------------------------------------------------------------------

local function newNumber(parent: Instance): DamageNumber
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(140, 44)
	label.BackgroundTransparency = 1
	label.FontFace = NUMBER_FONT
	label.TextSize = 28
	label.TextColor3 = WHITE
	label.TextTransparency = 1
	label.Text = ""
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
	return {
		label = label,
		stroke = outline,
		scale = scale,
		state = "Idle",
		total = 0,
		world = Vector3.zero,
		lastHit = 0,
		killed = false,
		t = 0,
		position = Vector2.zero,
		velocity = Vector2.zero,
		spin = 0,
		size = 1,
		offscreen = false,
		crosshair = false,
	}
end

local function setAlpha(n: DamageNumber, transparency: number)
	n.label.TextTransparency = transparency
	n.stroke.Transparency = 0.2 + 0.8 * transparency
end

local function hide(n: DamageNumber)
	n.state = "Idle"
	n.label.Visible = false
	setAlpha(n, 1)
	n.label.Rotation = 0
end

-- Where a stack's number sits: just off its hit point (it stays on the
-- target, e.g. someone burning in a Molly). nil while the point is out of
-- view: the number isn't drawn then (never parked on the crosshair).
local function screenPoint(world: Vector3): Vector2?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local p, onScreen = cam:WorldToViewportPoint(world)
	if not onScreen or p.Z < 0 then
		return nil
	end
	local size = cam.ViewportSize
	local x = math.clamp(p.X + NUMBER_OFFSET.X, 40, size.X - 40)
	local y = math.clamp(p.Y + NUMBER_OFFSET.Y, 30, size.Y - 30)
	return Vector2.new(x, y)
end

-- Follows the hit point on screen; hidden while it's out of view. A hit
-- with no point sits by the crosshair.
local function place(n: DamageNumber)
	local cam = Workspace.CurrentCamera
	local p = if n.crosshair and cam
		then cam.ViewportSize / 2 + NUMBER_OFFSET
		else screenPoint(n.world)
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
	local side = if math.random() < 0.5 then -1 else 1
	n.velocity = Vector2.new(side * (50 + math.random() * 70), -(170 + math.random() * 60))
	n.spin = side * (70 + math.random() * 60)
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

-- A confirmed hit: stacks onto the current number while you keep hitting the
-- same target, else starts a new one. Amber for headshots, bigger on the kill.
function HitFeedback.damage(amount: number, headshot: boolean, position: Vector3?, killed: boolean?)
	if amount ~= amount or amount <= 0 then
		return
	end
	local now = clock
	local world = position or Vector3.zero
	local n = current
	local continues = n ~= nil
		and n.state == "Stack"
		and not n.killed
		and now - n.lastHit < STACK_TIME
		and (position == nil or (n.world - world).Magnitude < STACK_RANGE)
	if n and not continues then
		if n.state == "Stack" then
			startFall(n)
		end
		n = nil
	end
	if not n then
		n = takeNumber()
		if not n then
			return
		end
		n.total = 0
		n.killed = false
		n.state = "Stack"
		n.label.Rotation = 0
		n.label.Visible = true
		setAlpha(n, 0)
		current = n
	end
	local stack = n :: DamageNumber
	stack.total += amount
	stack.world = if position then world else stack.world
	stack.lastHit = now
	stack.t = 0 -- pop again
	stack.killed = killed == true
	stack.size = if stack.killed then 1.3 elseif headshot then 1.12 else 1
	stack.label.TextColor3 = if headshot then AMBER else WHITE
	stack.label.Text = tostring(math.round(stack.total))
	stack.crosshair = position == nil -- no hit point: by the crosshair
	place(stack)
end

local function stepNumber(n: DamageNumber, dt: number, now: number)
	if n.state == "Stack" then
		n.t += dt
		place(n)
		local pop = 1 - easeOut(n.t / POP_TIME)
		n.scale.Scale = n.size * (1 + 0.5 * pop)
		n.label.Position = UDim2.fromOffset(n.position.X, n.position.Y)
		if now - n.lastHit > (if n.killed then KILL_HOLD else STACK_TIME) then
			startFall(n)
			if current == n then
				current = nil
			end
		end
	elseif n.state == "Fall" then
		n.t += dt
		local k = n.t / FALL_TIME
		if k >= 1 then
			hide(n)
			return
		end
		n.velocity += Vector2.new(0, FALL_GRAVITY * dt)
		n.position += n.velocity * dt
		n.label.Position = UDim2.fromOffset(n.position.X, n.position.Y)
		n.label.Rotation += n.spin * dt
		-- A quick swell as it lets go, then it shrinks and fades as it drops.
		local swell = if n.t < 0.06 then n.t / 0.06 else math.max(0, 1 - (n.t - 0.06) / 0.1)
		n.scale.Scale = n.size * (1 + 0.2 * swell - 0.35 * k)
		setAlpha(n, k ^ 1.6)
	end
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
	hitMarker = newMarker(root, 16, 2)
	killMarker = newMarker(root, 22, 3)
	for i = 1, POOL_SIZE do
		numbers[i] = newNumber(root)
	end
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
end

return HitFeedback
