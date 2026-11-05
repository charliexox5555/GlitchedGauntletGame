--!strict
-- AmbienceClient_V2: decorative motion for the "Sunwell Bunker, redone" Lobby (rebuild 2026-11-04).
-- Installed as a Script (RunContext Client) at Workspace.Lobby.Ambience.AmbienceClient by Build_Bunker2. Client-only,
-- purely cosmetic (no gameplay, no remotes). Tag-driven and streaming-safe: instances are picked up when they stream
-- in and dropped when they leave; anything farther than WAKE studs from the camera sleeps.
--   LobbySpin   Model/BasePart: SpinSpeed (deg/s about world Y), optional BobAmp / BobSpeed (studs, Hz)
--   LobbyBob    Model/BasePart: BobAmp / BobSpeed only
--   LobbyPulse  Neon BasePart: soft breathing (Transparency 0..0.35)
--   LobbyGlitch BasePart: rare flicker. Magenta sign ghosts flash in with a small jitter; holo lines blink out.
--   LobbyScroll UIGradient: slow sweep across a screen
--   LobbyLight  Light: switched off beyond LIGHT_RANGE studs (LihFolk "Light Sources and Shadows": about 8-12 visible
--               local lights on mid phones; tag and disable, never delete)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WAKE = 160
local LIGHT_RANGE = 120

type Mover = { inst: Instance, base: CFrame, spin: number, amp: number, freq: number, phase: number }
local movers: { [Instance]: Mover } = {}
local pulses: { [BasePart]: number } = {}
local glitches: { [BasePart]: { base: CFrame, base_t: number, next: number, until_: number, ghost: boolean } } = {}
local scrolls: { [UIGradient]: number } = {}
local lights: { [Light]: boolean } = {}

local function pivotOf(i: Instance): CFrame?
	if i:IsA("Model") then
		return i:GetPivot()
	elseif i:IsA("BasePart") then
		return i.CFrame
	end
	return nil
end

local function addMover(i: Instance, spinning: boolean)
	local cf = pivotOf(i)
	if not cf then
		return
	end
	local speed = if spinning then i:GetAttribute("SpinSpeed") else 0
	local amp = i:GetAttribute("BobAmp")
	local freq = i:GetAttribute("BobSpeed")
	movers[i] = {
		inst = i,
		base = cf,
		spin = math.rad(if typeof(speed) == "number" then speed else 0),
		amp = if typeof(amp) == "number" then amp else 0,
		freq = if typeof(freq) == "number" then freq else 1,
		phase = math.random() * math.pi * 2,
	}
end

local function watch(tagName: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, i in CollectionService:GetTagged(tagName) do
		add(i)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(remove)
end

local function dropMover(i: Instance)
	movers[i] = nil
end
watch("LobbySpin", function(i)
	addMover(i, true)
end, dropMover)
watch("LobbyBob", function(i)
	addMover(i, false)
end, dropMover)
watch("LobbyPulse", function(i)
	if i:IsA("BasePart") then
		pulses[i] = math.random() * math.pi * 2
	end
end, function(i)
	if i:IsA("BasePart") then
		pulses[i] = nil
	end
end)
watch("LobbyGlitch", function(i)
	if i:IsA("BasePart") then
		glitches[i] = { base = i.CFrame, base_t = i.Transparency, next = os.clock() + 2 + math.random() * 8, until_ = 0, ghost = i.Name == "GlitchGhost" }
	end
end, function(i)
	if i:IsA("BasePart") then
		glitches[i] = nil
	end
end)
watch("LobbyScroll", function(i)
	if i:IsA("UIGradient") then
		scrolls[i] = math.random()
	end
end, function(i)
	if i:IsA("UIGradient") then
		scrolls[i] = nil
	end
end)

watch("LobbyLight", function(i)
	if i:IsA("Light") then
		lights[i] = i.Enabled
	end
end, function(i)
	if i:IsA("Light") then
		lights[i] = nil
	end
end)
task.spawn(function()
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			local cam = camera.CFrame.Position
			for l, wanted in lights do
				local holder = l.Parent
				if holder and holder:IsA("BasePart") then
					l.Enabled = wanted and (holder.Position - cam).Magnitude < LIGHT_RANGE
				end
			end
		end
		task.wait(0.5)
	end
end)

local function near(p: Vector3, cam: Vector3): boolean
	return (p - cam).Magnitude < WAKE
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cam = camera.CFrame.Position
	local t = os.clock()
	for i, m in movers do
		if not i.Parent then
			movers[i] = nil
		elseif near(m.base.Position, cam) then
			local cf = CFrame.new(0, math.sin(t * m.freq * math.pi * 2 + m.phase) * m.amp, 0) + m.base.Position
			cf = cf * CFrame.Angles(0, t * m.spin, 0) * m.base.Rotation
			if i:IsA("Model") then
				i:PivotTo(cf)
			elseif i:IsA("BasePart") then
				i.CFrame = cf
			end
		end
	end
	for p, phase in pulses do
		if near(p.Position, cam) then
			p.Transparency = 0.175 + 0.175 * math.sin(t * 1.6 + phase)
		end
	end
	for p, g in glitches do
		if near(g.base.Position, cam) then
			if t >= g.next then
				g.until_ = t + 0.06 + math.random() * 0.12
				g.next = t + 3 + math.random() * 9
			end
			local on = t < g.until_
			if g.ghost then
				p.Transparency = if on then 0.25 else 1
				p.CFrame = if on then g.base * CFrame.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.2, 0) else g.base
			else
				p.Transparency = if on then 0.85 else g.base_t
			end
		end
	end
	for g, phase in scrolls do
		g.Offset = Vector2.new(((t * 0.08 + phase) % 2) - 1, 0)
	end
end)
