--!strict
-- AmbienceClient: decorative lobby ambience (phase 1, step 6). Visual only: no gameplay,
-- no remotes, no UI, no player data, no camera or movement. Lives in
-- Workspace.Lobby.Ambience as a Script with RunContext = Client.
-- Source of truth: art-source/lobby/scripts/AmbienceClient.luau. AmbienceSetup.luau installs
-- it and tags the targets in Studio.
--
-- Targets are found by CollectionService tag, which works with StreamingEnabled: an instance
-- is picked up when it streams in and dropped (connections cut) when it streams out. Nothing
-- is cached across a stream-out; a part list per target is kept current with DescendantAdded /
-- DescendantRemoving while the target is in.
--
--   Lobby_Turntable  BasePart or Model. Turns about the vertical axis through attribute
--                    SpinCenter (Vector3). SpinPeriod = seconds per cycle, SpinPhase = seconds.
--                    SpinSwing (degrees, optional): swivel back and forth by this much instead
--                    of turning all the way round (for guns longer than their bay allows).
--   Lobby_PadRing    Neon BasePart: slow breathing glow (Transparency).
--   Lobby_Pulse      Neon BasePart (Transparency) or Light (Brightness): same breathing.
--                    Both take AmbPeriod (s), AmbDepth (0..1) and AmbPhase (s).
--   Lobby_Flicker    Neon BasePart: an occasional short fluorescent stutter.
--   Lobby_LedScreen  BasePart carrying a sign SurfaceGui: adds a faint client-side overlay.
--                    AmbFace (NormalId name), AmbStyle ("Scan" | "Shimmer"), AmbColor (Color3),
--                    AmbPeriod (s).
--
-- One Heartbeat connection drives everything. Turntables move every frame with one
-- Workspace:BulkMoveTo; pulses, flickers and screens update at 30 Hz. Anything farther than
-- CULL_DISTANCE from the camera is skipped.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CULL_DISTANCE = 150
local SLOW_STEP = 1 / 30
local TAU = 2 * math.pi

local NORMAL_IDS: { [string]: Enum.NormalId } = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
	Top = Enum.NormalId.Top,
	Bottom = Enum.NormalId.Bottom,
}

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

local function numberAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	if typeof(v) == "number" and finite(v) then
		return v
	end
	return default
end

-- Smooth 0..1..0 wave over `period` seconds.
local function wave(t: number, period: number, phase: number): number
	return 0.5 - 0.5 * math.cos(((t + phase) % period) / period * TAU)
end

local function disconnectAll(conns: { RBXScriptConnection })
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
end

-- ------------------------------------------------------------------ turntables

type Spinner = {
	axis: CFrame,
	period: number,
	phase: number,
	swing: number, -- radians; 0 = full turns
	-- part -> its CFrame relative to the axis at angle 0 (its replicated, unturned pose)
	parts: { [BasePart]: CFrame },
	conns: { RBXScriptConnection },
}

local spinners: { [Instance]: Spinner } = {}

local function trackSpinPart(s: Spinner, d: Instance)
	if d:IsA("BasePart") then
		local p = d :: BasePart
		if p.Anchored and s.parts[p] == nil then
			s.parts[p] = s.axis:ToObjectSpace(p.CFrame)
		end
	end
end

local function addSpinner(inst: Instance)
	if spinners[inst] then
		return
	end
	local center = inst:GetAttribute("SpinCenter")
	if typeof(center) ~= "Vector3" then
		return
	end
	local period = math.max(numberAttr(inst, "SpinPeriod", 36), 4)
	local s: Spinner = {
		axis = CFrame.new(center),
		period = period,
		phase = numberAttr(inst, "SpinPhase", 0),
		swing = math.rad(math.clamp(numberAttr(inst, "SpinSwing", 0), 0, 180)),
		parts = {},
		conns = {},
	}
	trackSpinPart(s, inst)
	for _, d in inst:GetDescendants() do
		trackSpinPart(s, d)
	end
	table.insert(
		s.conns,
		inst.DescendantAdded:Connect(function(d: Instance)
			trackSpinPart(s, d)
		end)
	)
	table.insert(
		s.conns,
		inst.DescendantRemoving:Connect(function(d: Instance)
			if d:IsA("BasePart") then
				s.parts[d :: BasePart] = nil
			end
		end)
	)
	spinners[inst] = s
end

local function removeSpinner(inst: Instance)
	local s = spinners[inst]
	if not s then
		return
	end
	spinners[inst] = nil
	disconnectAll(s.conns)
	-- Put the parts back where the server has them if they are still here (tag removed).
	if inst.Parent then
		for part, rel in s.parts do
			if part.Parent then
				part.CFrame = s.axis * rel
			end
		end
	end
	table.clear(s.parts)
end

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local function updateSpinners(cam: Vector3, t: number)
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, s in spinners do
		if (s.axis.Position - cam).Magnitude <= CULL_DISTANCE then
			local u = ((t + s.phase) % s.period) / s.period
			local angle = if s.swing > 0 then s.swing * math.sin(u * TAU) else u * TAU
			local turned = s.axis * CFrame.Angles(0, -angle, 0)
			for part, rel in s.parts do
				table.insert(moveParts, part)
				table.insert(moveCFrames, turned * rel)
			end
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
end

-- ------------------------------------------------------------------ pulses (pads, gate, hero)

type Pulse = {
	part: BasePart?,
	light: Light?,
	base: number,
	position: Vector3,
	period: number,
	depth: number,
	phase: number,
}

local pulses: { [Instance]: Pulse } = {}

local function addPulse(inst: Instance, defaultPeriod: number, defaultDepth: number)
	if pulses[inst] then
		return
	end
	local period = math.max(numberAttr(inst, "AmbPeriod", defaultPeriod), 0.5)
	local depth = math.clamp(numberAttr(inst, "AmbDepth", defaultDepth), 0, 1)
	local phase = numberAttr(inst, "AmbPhase", 0)
	if inst:IsA("BasePart") then
		local p = inst :: BasePart
		pulses[inst] = {
			part = p,
			light = nil,
			base = p.Transparency,
			position = p.Position,
			period = period,
			depth = depth,
			phase = phase,
		}
	elseif inst:IsA("Light") then
		local l = inst :: Light
		local holder = l.Parent
		local pos: Vector3
		if holder and holder:IsA("BasePart") then
			pos = (holder :: BasePart).Position
		elseif holder and holder:IsA("Attachment") then
			pos = (holder :: Attachment).WorldPosition
		else
			return
		end
		pulses[inst] = {
			part = nil,
			light = l,
			base = l.Brightness,
			position = pos,
			period = period,
			depth = depth,
			phase = phase,
		}
	end
end

local function removePulse(inst: Instance)
	local p = pulses[inst]
	if not p then
		return
	end
	pulses[inst] = nil
	if inst.Parent then
		local part, light = p.part, p.light
		if part then
			part.Transparency = p.base
		elseif light then
			light.Brightness = p.base
		end
	end
end

local function updatePulses(cam: Vector3, t: number)
	for _, p in pulses do
		if (p.position - cam).Magnitude <= CULL_DISTANCE then
			local w = wave(t, p.period, p.phase)
			local part, light = p.part, p.light
			if part then
				part.Transparency = p.base + (1 - p.base) * p.depth * w
			elseif light then
				light.Brightness = p.base * (1 - p.depth * w)
			end
		end
	end
end

-- ------------------------------------------------------------------ flickers

type Flicker = {
	part: BasePart,
	base: number,
	level: number,
	rng: Random,
	nextBurst: number,
	burstEnd: number,
	nextFlip: number,
}

local flickers: { [Instance]: Flicker } = {}

local function addFlicker(inst: Instance)
	if flickers[inst] or not inst:IsA("BasePart") then
		return
	end
	local p = inst :: BasePart
	local rng = Random.new()
	flickers[inst] = {
		part = p,
		base = p.Transparency,
		level = p.Transparency,
		rng = rng,
		nextBurst = os.clock() + rng:NextNumber(2, 9),
		burstEnd = 0,
		nextFlip = 0,
	}
end

local function removeFlicker(inst: Instance)
	local f = flickers[inst]
	if not f then
		return
	end
	flickers[inst] = nil
	if inst.Parent then
		f.part.Transparency = f.base
	end
end

local function setLevel(f: Flicker, level: number)
	if f.level ~= level then
		f.level = level
		f.part.Transparency = level
	end
end

local function updateFlickers(cam: Vector3, c: number)
	for _, f in flickers do
		if (f.part.Position - cam).Magnitude > CULL_DISTANCE then
			continue
		end
		if c >= f.burstEnd then
			if c < f.nextBurst then
				setLevel(f, f.base)
				continue
			end
			-- Start a stutter: 0.25-0.9 s of rapid dips, then steady for 6-15 s.
			f.burstEnd = c + f.rng:NextNumber(0.25, 0.9)
			f.nextBurst = f.burstEnd + f.rng:NextNumber(6, 15)
			f.nextFlip = c
		end
		if c >= f.nextFlip then
			f.nextFlip = c + f.rng:NextNumber(0.03, 0.11)
			if f.rng:NextNumber() < 0.55 then
				setLevel(f, f.base + (1 - f.base) * f.rng:NextNumber(0.5, 0.85))
			else
				setLevel(f, f.base)
			end
		end
	end
end

-- ------------------------------------------------------------------ LED screens

type Screen = {
	part: BasePart,
	gui: SurfaceGui,
	style: string,
	mover: Frame,
	gradient: UIGradient,
	period: number,
	phase: number,
}

local screens: { [Instance]: Screen } = {}

local function addScreen(inst: Instance)
	if screens[inst] or not inst:IsA("BasePart") then
		return
	end
	local part = inst :: BasePart
	local faceName = part:GetAttribute("AmbFace")
	local face = if typeof(faceName) == "string" then NORMAL_IDS[faceName] else nil
	local styleAttr = part:GetAttribute("AmbStyle")
	local style = if styleAttr == "Shimmer" then "Shimmer" else "Scan"
	local colorAttr = part:GetAttribute("AmbColor")
	local color = if typeof(colorAttr) == "Color3" then colorAttr else Color3.new(1, 1, 1)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "AmbienceOverlay"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0
	gui.ZOffset = 2
	gui.ClipsDescendants = true
	gui.Active = false

	local mover = Instance.new("Frame")
	mover.Name = style
	mover.BorderSizePixel = 0
	mover.BackgroundColor3 = color
	mover.BackgroundTransparency = 0
	local gradient = Instance.new("UIGradient")
	if style == "Scan" then
		-- A soft band with a brighter leading (lower) edge, sliding down the screen.
		mover.Size = UDim2.fromScale(1, 0.22)
		mover.Position = UDim2.fromScale(0, -0.22)
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.75, 0.92),
			NumberSequenceKeypoint.new(0.94, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		-- A narrow diagonal sheen that sweeps across, then rests off-screen.
		mover.Size = UDim2.fromScale(1, 1)
		gradient.Rotation = 20
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.47, 0.9),
			NumberSequenceKeypoint.new(0.5, 0.84),
			NumberSequenceKeypoint.new(0.53, 0.9),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	gradient.Parent = mover
	mover.Parent = gui
	gui.Parent = part

	screens[inst] = {
		part = part,
		gui = gui,
		style = style,
		mover = mover,
		gradient = gradient,
		period = math.max(numberAttr(part, "AmbPeriod", 6), 1),
		phase = numberAttr(part, "AmbPhase", 0),
	}
end

local function removeScreen(inst: Instance)
	local s = screens[inst]
	if not s then
		return
	end
	screens[inst] = nil
	s.gui:Destroy()
end

local function updateScreens(cam: Vector3, t: number)
	for _, s in screens do
		if (s.part.Position - cam).Magnitude > CULL_DISTANCE then
			continue
		end
		local u = ((t + s.phase) % s.period) / s.period
		if s.style == "Scan" then
			s.mover.Position = UDim2.fromScale(0, -0.22 + u * 1.22)
		else
			-- Sweep during the first 30% of the period, rest for the remainder.
			local k = math.clamp(u / 0.3, 0, 1)
			s.gradient.Offset = Vector2.new(-1 + 2 * k, 0)
		end
	end
end

-- ------------------------------------------------------------------ wiring

local connections: { RBXScriptConnection } = {}

local function watch(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(add))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(remove))
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
end

watch("Lobby_Turntable", addSpinner, removeSpinner)
watch("Lobby_PadRing", function(inst: Instance)
	addPulse(inst, 3.2, 0.35)
end, removePulse)
watch("Lobby_Pulse", function(inst: Instance)
	addPulse(inst, 4, 0.3)
end, removePulse)
watch("Lobby_Flicker", addFlicker, removeFlicker)
watch("Lobby_LedScreen", addScreen, removeScreen)

local slowClock = 0
table.insert(
	connections,
	RunService.Heartbeat:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local cam = camera.CFrame.Position
		local t = Workspace:GetServerTimeNow()
		updateSpinners(cam, t)
		slowClock += dt
		if slowClock >= SLOW_STEP then
			slowClock = 0
			updatePulses(cam, t)
			updateFlickers(cam, os.clock())
			updateScreens(cam, t)
		end
	end)
)

-- Clean up if the script is ever removed (e.g. AmbienceSetup reinstalls it).
local destroying: RBXScriptConnection
destroying = script.Destroying:Connect(function()
	destroying:Disconnect()
	disconnectAll(connections)
	for inst in spinners do
		removeSpinner(inst)
	end
	for inst in pulses do
		removePulse(inst)
	end
	for inst in flickers do
		removeFlicker(inst)
	end
	for inst in screens do
		removeScreen(inst)
	end
end)
