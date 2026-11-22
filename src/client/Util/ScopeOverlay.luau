--!strict
-- The sniper scope picture (numbers and the why in Config/Scope). Built into
-- the HUD by Controllers/HudController, which shows and hides it for
-- WeaponController (scoped in), SpectateController and ReplayController and
-- steps it every frame.
--   window   a clear circle in a black mask texture (Config/Scope.MASK), with
--            thinning black inside it (the feathered edge). It opens from
--            where the eyepiece was, lags the turn of the view, and jolts on
--            a shot.
--   reticle  a thin cross and a red dot. It rides the window while that
--            opens, then stays on the screen centre (where the shot goes).
--   blur     a BlurEffect on the camera for the way in, the way out and a shot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Scope = require(ReplicatedStorage.Shared.Config.Scope)

local Crosshair = require(script.Parent.Crosshair)
local ViewmodelMotion = require(script.Parent.ViewmodelMotion)

local ScopeOverlay = {}

local TAU = 2 * math.pi

local root: Frame? = nil
local window: Frame? = nil
local reticle: Frame? = nil
local pixelParts: { { object: GuiObject, width: number, height: number } } = {}
local blur: BlurEffect? = nil

local shown = false
local age = 0 -- seconds since it came up
local offset = Vector2.zero -- px at 1080p: the surround, off the screen centre
local offsetVel = Vector2.zero
local jolt = 0 -- a shot's ring: 1 at the shot, rings to 0
local joltVel = 0
local blurSize = 0
local blurRate = 0 -- BlurEffect.Size lost per second
local lastLook: CFrame? = nil
local builtFor = 0 -- the screen height the px sizes were set for
local studio = RunService:IsStudio()

local function frame(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
end

-- A solid bar in the reticle: `scale` of the reticle's box, or `width` /
-- `height` px at 1080p where that is 0.
local function bar(
	parent: Instance,
	scale: Vector2,
	width: number,
	height: number,
	color: Color3,
	transparency: number
): Frame
	local f = frame(parent, "Line")
	f.Size = UDim2.fromScale(scale.X, scale.Y)
	f.BackgroundTransparency = transparency
	f.BackgroundColor3 = color
	table.insert(pixelParts, { object = f, width = width, height = height })
	return f
end

-- Sets every px size for this screen height (the window can be resized).
local function fit(height: number)
	builtFor = height
	local px = height / 1080
	for _, part in pixelParts do
		local size = part.object.Size
		part.object.Size = UDim2.new(
			size.X.Scale,
			if part.width > 0 then math.max(1, math.round(part.width * px)) else 0,
			size.Y.Scale,
			if part.height > 0 then math.max(1, math.round(part.height * px)) else 0
		)
	end
end

function ScopeOverlay.build(gui: ScreenGui): Frame
	local r = Instance.new("Frame")
	r.Name = "Scope"
	r.Size = UDim2.fromScale(1, 1)
	r.BackgroundTransparency = 1
	r.Visible = false
	r.Parent = gui
	root = r

	local W = Scope.WINDOW
	local w = frame(r, "Window")
	w.Size = UDim2.fromScale(W.outer, W.outer)
	w.SizeConstraint = Enum.SizeConstraint.RelativeYY
	w.BackgroundTransparency = 1
	window = w
	-- The surround: a mask texture (a round hole with the feather baked in)
	-- over the window's square, and four big black frames outside it. A
	-- texture keeps the hole exactly round on every device.
	local mask = Instance.new("ImageLabel")
	mask.Name = "Mask"
	mask.Size = UDim2.fromScale(1, 1)
	mask.BackgroundTransparency = 1
	mask.Image = Scope.MASK
	mask.ImageColor3 = Scope.COLOR
	mask.Parent = w
	local FAR = 10000 -- px: past any screen
	for _, side in
		{
			{ "Top", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 0, 1), UDim2.fromOffset(FAR, FAR) },
			{ "Bottom", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, -1), UDim2.fromOffset(FAR, FAR) },
			{ "Left", Vector2.new(1, 0.5), UDim2.new(0, 1, 0.5, 0), UDim2.new(0, FAR, 1, 0) },
			{ "Right", Vector2.new(0, 0.5), UDim2.new(1, -1, 0.5, 0), UDim2.new(0, FAR, 1, 0) },
		}
	do
		local f = Instance.new("Frame")
		f.Name = side[1] :: string
		f.AnchorPoint = side[2] :: Vector2
		f.Position = side[3] :: UDim2
		f.Size = side[4] :: UDim2
		f.BackgroundColor3 = Scope.COLOR
		f.BorderSizePixel = 0
		f.Parent = w
	end

	-- The reticle's box is the window's at rest.
	local ret = frame(r, "Reticle")
	ret.Size = UDim2.fromScale(W.outer, W.outer)
	ret.SizeConstraint = Enum.SizeConstraint.RelativeYY
	reticle = ret
	local R = Scope.RETICLE
	-- A little past the window's edge (black on black there), so the lines
	-- still reach it while the surround lags to one side.
	bar(ret, Vector2.new(1.1, 0), 0, R.line, Scope.COLOR, R.lineFade)
	bar(ret, Vector2.new(0, 1.1), R.line, 0, Scope.COLOR, R.lineFade)
	round(bar(ret, Vector2.zero, R.dot, R.dot, Scope.DOT, 0))

	local cam = Workspace.CurrentCamera
	fit(if cam then cam.ViewportSize.Y else 1080)
	return r
end

local function setBlur(size: number, time: number)
	if size >= blurSize then
		blurSize = size
		blurRate = size / math.max(time, 0.01)
	end
end

function ScopeOverlay.set(visible: boolean)
	local r = root
	if not r or shown == visible then
		return
	end
	shown = visible
	r.Visible = visible
	if visible and reticle then
		reticle.Rotation = Crosshair.tilt() -- this frame's lean, not the last one shown
	end
	if visible then
		age = 0
		offset = Vector2.zero
		offsetVel = Vector2.zero
		jolt = 0
		joltVel = 0
		lastLook = nil
		setBlur(Scope.IN.blur, Scope.IN.blurTime)
	else
		setBlur(Scope.OUT.blur, Scope.OUT.blurTime)
	end
end

-- A shot fired while scoped in.
function ScopeOverlay.shot()
	if not shown then
		return
	end
	jolt = 1
	joltVel = 0
	setBlur(Scope.SHOT.blur, Scope.SHOT.blurTime)
end

local function stepBlur(dt: number)
	if blurSize <= 0 then
		return
	end
	blurSize = math.max(blurSize - blurRate * dt, 0)
	local cam = Workspace.CurrentCamera
	local b = blur
	if not b or b.Parent ~= cam then
		if b then
			b:Destroy()
		end
		if not cam then
			return
		end
		b = Instance.new("BlurEffect")
		b.Name = "ScopeBlur"
		b.Parent = cam
		blur = b
	end
	b.Size = blurSize
	b.Enabled = blurSize > 0.5
end

function ScopeOverlay.step(dt: number)
	if studio then
		-- Studio only: Workspace VfxTimeScale slows or freezes it (captures).
		local scale = StateValues.get(Workspace, "VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	stepBlur(dt)
	local w, ret, cam = window, reticle, Workspace.CurrentCamera
	if not shown or not w or not ret or not cam then
		return
	end
	local height = cam.ViewportSize.Y
	if height ~= builtFor then
		fit(height)
	end
	age += dt

	-- The feather's strokes, in px for the window's size this frame.
	local W = Scope.WINDOW

	-- The surround lags the turn of the view, then springs back.
	local look = cam.CFrame
	local last = lastLook
	lastLook = look
	local lag = Scope.LAG
	if last and dt > 0 then
		local pitch, yaw = last:ToObjectSpace(look):ToEulerAnglesYXZ()
		-- px (at 1080p) the picture slid by this frame.
		local perRadian = 540 / math.tan(math.rad(cam.FieldOfView) / 2)
		offset += Vector2.new(yaw, pitch) * perRadian * lag.lag
		if offset.Magnitude > lag.max then
			offset = offset.Unit * lag.max
		end
	end
	local x, vx = ViewmodelMotion.spring(offset.X, offsetVel.X, 0, lag.frequency, dt)
	local y, vy = ViewmodelMotion.spring(offset.Y, offsetVel.Y, 0, lag.frequency, dt)
	offset, offsetVel = Vector2.new(x, y), Vector2.new(vx, vy)

	local shot = Scope.SHOT
	jolt, joltVel = ViewmodelMotion.bounce(jolt, joltVel, shot.frequency * TAU, shot.damping, dt)

	-- Opening: from the eyepiece (smaller, down and right) to the centre.
	local enter = Scope.IN
	local u = 1 - math.clamp(age / enter.time, 0, 1)
	local closed = u * u * u -- 1 at the cut, 0 once open (ease-out)
	local open = 1 - (1 - enter.scale) * closed
	local from = enter.from * height * closed

	local px = height / 1080
	local scale = open + shot.scale * jolt
	local at = from + (offset + Vector2.new(0, -shot.rise * jolt)) * px
	w.Position = UDim2.new(0.5, math.round(at.X), 0.5, math.round(at.Y))
	w.Size = UDim2.fromScale(W.outer * scale, W.outer * scale)
	-- The reticle opens with the window, then keeps the screen centre.
	ret.Position = UDim2.new(0.5, math.round(from.X), 0.5, math.round(from.Y))
	ret.Size = UDim2.fromScale(W.outer * open, W.outer * open)
	-- A slide leans the reticle with the crosshair and the camera.
	ret.Rotation = Crosshair.tilt()
end

return ScopeOverlay
