--!strict
-- Animated floor paths in the Duels hall (owner 2026-11-16: "the paths and arrows more like RIVALS, animated and
-- fun"). Two kinds of anchors from the lobby builder (tools/blender/lobby_v4/v4_duels.path_run / line_run):
--   LobbyPathRun: a run of chevrons laid on the floor along DX / DY (Blender axes) for Length studs, Width wide,
--     every Spacing studs; a wave of light travels along it at Speed studs a second (the aisle toward the trophy,
--     a short run from the aisle to every pad).
--   LobbyLineRun: a light pulse that runs along a lit floor line (the aisle's two edge lines).
-- Tone "lilac" / "violet" (the studio palette). Built locally from the anchors; nothing is sent to the server.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LobbyPathFx = {}

local TONES = {
	lilac = Color3.fromHex("C5B7D9"),
	violet = Color3.fromHex("7A4CF0"),
}
local BASE_T = 0.82 -- a chevron at rest: faint
local TAIL = 16 -- studs of glow behind a wave's head
local GAP = 18 -- studs of dark after a run before the next wave
local PULSE = 0.06 -- a line pulse's length, as a share of the line
local LINE_SPEED = 0.35 -- line pulses: lengths a second
local RANGE = 260 -- studs: further from the camera than this a run holds still

type Run = {
	anchor: BasePart,
	folder: Folder,
	parts: { { BasePart } },
	dist: { number },
	length: number,
	speed: number,
	origin: Vector3,
}
type Line = { anchor: BasePart, folder: Folder, beam: Beam, origin: Vector3, phase: number }

local runs: { [BasePart]: Run } = {}
local lines: { [BasePart]: Line } = {}
local folder: Folder? = nil

local function root(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "LobbyPathFx"
	f.Parent = workspace
	folder = f
	return f
end

local function num(p: Instance, key: string, default: number): number
	local v = p:GetAttribute(key)
	return if typeof(v) == "number" and v == v and math.abs(v) < 1e5 then v else default
end

local function dirOf(p: Instance): Vector3
	local d = Vector3.new(num(p, "DX", 0), 0, -num(p, "DY", 0)) -- Blender (x, y) on the floor is Roblox (x, -z)
	return if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
end

local function toneOf(p: Instance): Color3
	local t = p:GetAttribute("Tone")
	return if typeof(t) == "string" and TONES[t] then TONES[t] else TONES.lilac
end

local function bar(parent: Instance, cf: CFrame, size: Vector3, colour: Color3): BasePart
	local b = Instance.new("Part")
	b.Name = "Bar"
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	b.Material = Enum.Material.Neon
	b.Color = colour
	b.Transparency = BASE_T
	b.Size = size
	b.CFrame = cf
	b.Parent = parent
	return b
end

local function trackRun(a: BasePart)
	local dir = dirOf(a)
	local length = num(a, "Length", 20)
	local width = num(a, "Width", 6)
	local spacing = math.max(num(a, "Spacing", 4), 1)
	local colour = toneOf(a)
	local f = Instance.new("Folder")
	f.Name = a.Name
	f.Parent = root()
	local origin = a.Position
	local side = dir:Cross(Vector3.yAxis)
	local run: Run = {
		anchor = a,
		folder = f,
		parts = {},
		dist = {},
		length = length,
		speed = num(a, "Speed", 30),
		origin = origin,
	}
	-- a chevron: two angled bars meeting at the tip, pointing along the run
	local depth = width * 0.4
	local d = spacing * 0.5
	while d < length do
		local tip = origin + dir * d
		local pair = {}
		for _, s in { -1, 1 } do
			local tail = tip - dir * depth + side * s * width * 0.5
			local mid = (tip + tail) / 2
			table.insert(
				pair,
				bar(
					f,
					CFrame.lookAt(mid, tip),
					Vector3.new(0.55, 0.05, (tip - tail).Magnitude + 0.3),
					colour
				)
			)
		end
		table.insert(run.parts, pair)
		table.insert(run.dist, d)
		d += spacing
	end
	runs[a] = run
end

local function trackLine(a: BasePart)
	local dir = dirOf(a)
	local length = num(a, "Length", 50)
	local width = num(a, "Width", 0.5)
	local f = Instance.new("Folder")
	f.Name = a.Name
	f.Parent = root()
	local base = Instance.new("Part")
	base.Name = "LineBase"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(0.2, 0.2, 0.2)
	base.CFrame = CFrame.new(a.Position)
	base.Parent = f
	local side = dir:Cross(Vector3.yAxis)
	-- the beam lies flat on the line: its width runs along the attachments' Y (here: across the line)
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.fromMatrix(Vector3.zero, dir, side)
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.fromMatrix(dir * length, dir, side)
	a1.Parent = base
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = width * 1.6, width * 1.6
	b.FaceCamera = false
	b.Segments = 1
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(toneOf(a), 0.35))
	b.Transparency = NumberSequence.new(1)
	b.Parent = base
	lines[a] = { anchor = a, folder = f, beam = b, origin = a.Position, phase = math.random() }
end

local function track(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if CollectionService:HasTag(inst, "LobbyPathRun") and not runs[inst] then
		trackRun(inst)
	elseif CollectionService:HasTag(inst, "LobbyLineRun") and not lines[inst] then
		trackLine(inst)
	end
end

local function untrack(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local r = runs[inst]
	if r then
		r.folder:Destroy()
		runs[inst] = nil
	end
	local l = lines[inst]
	if l then
		l.folder:Destroy()
		lines[inst] = nil
	end
end

-- A pulse window [p - w, p] (0..1) as a Beam transparency sequence: bright at the head, fading behind it.
local function pulse(p: number): NumberSequence
	local a = math.clamp(p - PULSE, 0, 1)
	local b = math.clamp(p, 0, 1)
	local kps = { NumberSequenceKeypoint.new(0, 1) }
	if a > 0.001 then
		table.insert(kps, NumberSequenceKeypoint.new(a, 1))
	end
	if b > a + 0.001 and b < 0.999 then
		table.insert(kps, NumberSequenceKeypoint.new(b, 0.05))
		table.insert(kps, NumberSequenceKeypoint.new(math.min(b + 0.004, 0.999), 1))
	end
	table.insert(kps, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(kps)
end

local function step()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local t = os.clock()
	for _, r in runs do
		if (camPos - r.origin).Magnitude > RANGE + r.length then
			continue
		end
		local cycle = r.length + TAIL + GAP
		local head = (t * r.speed) % cycle
		for i, pair in r.parts do
			local behind = head - r.dist[i]
			local k = if behind >= 0 and behind <= TAIL then 1 - behind / TAIL else 0
			local tr = BASE_T - (BASE_T - 0.05) * k
			for _, b in pair do
				b.Transparency = tr
			end
		end
	end
	for _, l in lines do
		if (camPos - l.origin).Magnitude > RANGE * 1.5 then
			continue
		end
		local p = (t * LINE_SPEED + l.phase) % 1.3 -- a pause between pulses
		l.beam.Transparency = pulse(p)
	end
end

function LobbyPathFx.start()
	for _, tag in { "LobbyPathRun", "LobbyLineRun" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
		for _, a in CollectionService:GetTagged(tag) do
			track(a)
		end
	end
	RunService.RenderStepped:Connect(step)
end

return LobbyPathFx
