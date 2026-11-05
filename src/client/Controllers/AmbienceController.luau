--!strict
-- Map ambience, client only (2026-11-05). Data: Config/Ambience. Beds loop
-- 2D for the map the camera is in, emitters tagged in the map play
-- positional loops (the nearest few) and random one-shots, and inside a
-- tagged room the outdoor bus is muffled while the room tone comes up.
-- Every sound is a slice of the shared sound atlas (Config/Sounds ATLAS).
-- LihFolk: lihfolk-sfx (beds on their own bus, positional sounds mono,
-- InverseTapered roll-off, cull by distance, cap live voices), Spatial Audio
-- and Mixing (duck ambience under combat: the Ambience bus is sidechained to
-- your gun in AudioController).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Config.Ambience)
local SoundAtlas = require(ReplicatedStorage.Shared.Config.SoundAtlas)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local AudioController = require(script.Parent.AudioController)

local AmbienceController = {}

type Loop = { sound: Sound, holder: Instance?, base: number, current: number, target: number }

local folder: Folder? = nil
local beds: { [string]: { Loop } } = {} -- map id -> its bed loops
local rooms: { [string]: Loop } = {} -- map id -> its room tone
local spotLoops: { [Instance]: Loop } = {} -- emitter -> its playing loop
local nextShot: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local emitters: { [Instance]: boolean } = {}
local indoorParts: { [BasePart]: boolean } = {}
local indoor = 0 -- 0 outdoors .. 1 indoors, smoothed
local indoorTarget = 0
local activeMap: string? = nil
local eq: EqualizerSoundEffect? = nil

local function region(id: string): NumberRange?
	if string.sub(id, 1, 6) ~= "atlas:" then
		return nil
	end
	local variants = SoundAtlas[string.sub(id, 7)]
	local r = variants and variants[1]
	return if r then NumberRange.new(r.start, r.start + r.length) else nil
end

-- A looping slice of the atlas. `at`: a positional holder (Attachment), else 2D.
local function newLoop(
	id: string,
	group: AudioController.Group,
	base: number,
	pitch: number?,
	at: Instance?,
	range: number?
): Loop?
	local r = region(id)
	if not r then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = id
	s.SoundId = Sounds.ATLAS
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = r
	s.LoopRegion = r
	s.Looped = true
	s.Volume = 0
	s.PlaybackSpeed = pitch or 1
	s.SoundGroup = AudioController.group(group)
	if range then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = range * 0.15
		s.RollOffMaxDistance = range
	end
	s.Parent = at or folder
	-- Start somewhere inside the loop so emitters of one kind never phase.
	s.TimePosition = r.Min + math.random() * (r.Max - r.Min) * 0.9
	s:Play()
	return { sound = s, holder = at, base = base, current = 0, target = 0 }
end

local function dropLoop(l: Loop)
	l.sound:Destroy()
	if l.holder and l.holder ~= folder then
		l.holder:Destroy()
	end
end

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

local function insideBox(cf: CFrame, size: Vector3, p: Vector3): boolean
	local q = cf:PointToObjectSpace(p)
	return math.abs(q.X) <= size.X / 2
		and math.abs(q.Y) <= size.Y / 2
		and math.abs(q.Z) <= size.Z / 2
end

local function mapAt(p: Vector3): string?
	for id, m in Ambience.MAPS do
		if insideBox(CFrame.new(m.center), m.size, p) then
			return id
		end
	end
	return nil
end

-- The map's beds and room tone, made the first time it's visited.
local function ensureMap(id: string)
	if beds[id] then
		return
	end
	local m = Ambience.MAPS[id]
	local list = {}
	for _, b in m.beds do
		local l = newLoop(b.id, "Ambience", b.volume)
		if l then
			table.insert(list, l)
		end
	end
	beds[id] = list
	if m.room then
		local l = newLoop(m.room.id, "Room", m.room.volume)
		if l then
			rooms[id] = l
		end
	end
end

-- The checks that don't need every frame: which map, indoors or not, which
-- emitters are near, the one-shots that are due.
local function tick(cam: Camera)
	local eye = cam.CFrame.Position
	local map = mapAt(eye)
	if map then
		ensureMap(map)
	end
	activeMap = map
	for id, list in beds do
		for _, l in list do
			l.target = if id == map then l.base else 0
		end
	end

	local inside = false
	for part in indoorParts do
		if part.Parent and insideBox(part.CFrame, part.Size, eye) then
			inside = true
			break
		end
	end
	indoorTarget = if inside and map then 1 else 0
	for id, l in rooms do
		l.target = if id == map then l.base else 0
	end

	-- Positional loops: the nearest MAX_LOOPS within range play.
	local near: { { inst: Instance, d: number, pos: Vector3 } } = {}
	local now = os.clock()
	for inst in emitters do
		local pos = positionOf(inst)
		local kind = inst:GetAttribute("Sound")
		local spot = if typeof(kind) == "string" then Ambience.SPOTS[kind] else nil
		if pos and spot then
			local d = (pos - eye).Magnitude
			if spot.loop then
				if d <= spot.range then
					table.insert(near, { inst = inst, d = d, pos = pos })
				end
			elseif d <= spot.range then
				local due = nextShot[inst]
				local gap = spot.interval or { 10, 20 }
				if not due then
					nextShot[inst] = now + gap[1] * math.random()
				elseif now >= due then
					nextShot[inst] = now + gap[1] + math.random() * (gap[2] - gap[1])
					local p = spot.pitch
					local pitch = if p and #p >= 2 then p[1] + math.random() * (p[2] - p[1]) else 1
					local scale = 1 + (Ambience.INDOOR.outdoorVolume - 1) * indoor
					AudioController.play(spot.id, {
						group = "Ambience",
						volume = spot.volume * scale,
						pitch = pitch,
						at = pos,
						range = spot.range,
					})
				end
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local keep: { [Instance]: boolean } = {}
	for i = 1, math.min(#near, Ambience.MAX_LOOPS) do
		local n = near[i]
		keep[n.inst] = true
		local l = spotLoops[n.inst]
		if not l then
			local spot = Ambience.SPOTS[n.inst:GetAttribute("Sound") :: string]
			local holder = Instance.new("Attachment")
			holder.Name = "AmbienceSpot"
			holder.WorldPosition = n.pos
			holder.Parent = Workspace.Terrain
			l = newLoop(
				spot.id,
				"Ambience",
				spot.volume,
				spot.pitch and spot.pitch[1],
				holder,
				spot.range
			)
			if l then
				spotLoops[n.inst] = l
			else
				holder:Destroy()
			end
		end
		if l then
			l.target = l.base
		end
	end
	for inst, l in spotLoops do
		if not keep[inst] then
			l.target = 0
		end
	end
end

local function step(dt: number)
	local fade = math.min(dt / Ambience.FADE, 1)
	indoor += math.clamp(
		indoorTarget - indoor,
		-dt / Ambience.INDOOR.blend,
		dt / Ambience.INDOOR.blend
	)
	local outdoorScale = 1 + (Ambience.INDOOR.outdoorVolume - 1) * indoor
	if eq then
		eq.HighGain = Ambience.INDOOR.highCut * indoor
		eq.MidGain = Ambience.INDOOR.midCut * indoor
	end
	for _, list in beds do
		for _, l in list do
			l.current += (l.target - l.current) * fade
			l.sound.Volume = l.current * outdoorScale
		end
	end
	for _, l in rooms do
		l.current += (l.target - l.current) * fade
		l.sound.Volume = l.current * indoor
	end
	for inst, l in spotLoops do
		l.current += (l.target - l.current) * math.min(dt / 0.6, 1)
		l.sound.Volume = l.current * outdoorScale
		if l.target == 0 and l.current < 0.005 then
			dropLoop(l)
			spotLoops[inst] = nil
		end
	end
end

local function watchTag(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

function AmbienceController.start()
	local f = Instance.new("Folder")
	f.Name = "Ambience"
	f.Parent = SoundService
	folder = f
	local bus = AudioController.group("Ambience")
	if bus then
		local e = Instance.new("EqualizerSoundEffect")
		e.Name = "IndoorMuffle"
		e.LowGain = 0
		e.MidGain = 0
		e.HighGain = 0
		e.Priority = 3
		e.Parent = bus
		eq = e
	end
	watchTag(Ambience.TAG_EMITTER, function(inst)
		emitters[inst] = true
	end, function(inst)
		emitters[inst] = nil
		local l = spotLoops[inst]
		if l then
			dropLoop(l)
			spotLoops[inst] = nil
		end
	end)
	watchTag(Ambience.TAG_INDOOR, function(inst)
		if inst:IsA("BasePart") then
			indoorParts[inst] = true
		end
	end, function(inst)
		if inst:IsA("BasePart") then
			indoorParts[inst] = nil
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		acc += dt
		if acc >= Ambience.TICK then
			acc = 0
			tick(cam)
		end
		step(dt)
	end)
end

-- For tests and the HUD: which map's ambience is playing (nil: none).
function AmbienceController.activeMap(): string?
	return activeMap
end

return AmbienceController
