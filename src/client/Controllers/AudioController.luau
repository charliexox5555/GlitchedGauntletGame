--!strict
-- Plays every game sound. Sounds are slices of one atlas asset
-- (Config/SoundAtlas), so a fixed pool of Sound voices, all on the atlas,
-- plays anything by moving its PlaybackRegion: no instances per shot and no
-- SoundId reloads. 2D voices play your own sounds; 3D voices (one Attachment
-- in Terrain each) play other players' shots where they happen.
--
-- Mix (Config/Audio): SoundService.Combat (master, limiter) holds the Gun,
-- Enemy, Feedback and Foley groups. Your gun is glued by a compressor and
-- ducks slightly under hit feedback; enemy shots use their "_Far" slices
-- (duller, more room) plus a little EQ, so your gun and theirs never blur.
-- Every play gets a different variant than last time and a small random
-- pitch, and each name is capped at a few voices so fast guns never cut out
-- or stack into a wall of noise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local SoundAtlas = require(ReplicatedStorage.Shared.Config.SoundAtlas)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

export type Group = Audio.Group

export type PlayOptions = {
	group: Group?, -- default "Foley"
	volume: number?, -- default 0.6
	pitch: number?, -- default 1 (jitter is added on top)
	at: Vector3?, -- play in 3D here (otherwise 2D)
	far: boolean?, -- use the "<Name>_Far" slice if there is one
}

type Voice = {
	sound: Sound,
	holder: Attachment?,
	key: string,
	startedAt: number,
	endsAt: number,
}

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local voices2d: { Voice } = {}
local voices3d: { Voice } = {}
local lastVariant: { [string]: number } = {}
local voiceFolder: Folder? = nil

type CompressorSettings = { threshold: number, ratio: number, attack: number, release: number }

local function compressor(
	parent: Instance,
	settings: CompressorSettings,
	priority: number
): CompressorSoundEffect
	local c = Instance.new("CompressorSoundEffect")
	c.Threshold = settings.threshold
	c.Ratio = settings.ratio
	c.Attack = settings.attack
	c.Release = settings.release
	c.Priority = priority
	c.Parent = parent
	return c
end

local function buildGroups()
	local master = Instance.new("SoundGroup")
	master.Name = "Combat"
	master.Volume = Audio.GROUP_VOLUME.Master or 1
	compressor(master, Audio.MASTER_LIMIT, 0)
	master.Parent = SoundService
	for _, name in { "Gun", "Enemy", "Feedback", "Foley" } do
		local g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = Audio.GROUP_VOLUME[name] or 1
		g.Parent = master
		groups[name] = g
	end
	compressor(groups.Gun, Audio.GUN_GLUE, 2)
	compressor(groups.Gun, Audio.GUN_DUCK, 1).SideChain = groups.Feedback
	compressor(groups.Enemy, Audio.GUN_GLUE, 2)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = Audio.ENEMY_EQ.low
	eq.MidGain = Audio.ENEMY_EQ.mid
	eq.HighGain = Audio.ENEMY_EQ.high
	eq.Priority = 1
	eq.Parent = groups.Enemy

	local folder = Instance.new("Folder")
	folder.Name = "CombatVoices"
	folder.Parent = SoundService
	voiceFolder = folder
end

local function newVoice(is3d: boolean): Voice
	local s = Instance.new("Sound")
	s.Name = "Voice"
	s.SoundId = Sounds.ATLAS
	s.PlaybackRegionsEnabled = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = Audio.ROLLOFF_MIN
	s.RollOffMaxDistance = Audio.ROLLOFF_MAX
	local holder: Attachment? = nil
	if is3d then
		local a = Instance.new("Attachment")
		a.Name = "CombatVoice"
		a.Parent = Workspace.Terrain
		s.Parent = a
		holder = a
	else
		s.Parent = voiceFolder
	end
	return { sound = s, holder = holder, key = "", startedAt = 0, endsAt = 0 }
end

-- A voice for `key`: its own oldest one if the name is at its cap, else a
-- free one, else a new one while the pool has room, else the oldest overall.
local function acquire(
	pool: { Voice },
	size: number,
	is3d: boolean,
	key: string,
	now: number
): Voice
	local sameCount, sameOldest = 0, nil :: Voice?
	local free: Voice? = nil
	local oldest: Voice? = nil
	for _, v in pool do
		if v.endsAt > now then
			if v.key == key then
				sameCount += 1
				if not sameOldest or v.startedAt < sameOldest.startedAt then
					sameOldest = v
				end
			end
			if not oldest or v.startedAt < oldest.startedAt then
				oldest = v
			end
		elseif not free then
			free = v
		end
	end
	if sameOldest and sameCount >= Audio.VOICES_PER_SOUND then
		return sameOldest
	end
	if free then
		return free
	end
	if #pool < size or not oldest then
		local v = newVoice(is3d)
		table.insert(pool, v)
		return v
	end
	return oldest
end

-- "atlas:<Name>" -> the slice name and a variant (never the same twice in a
-- row). Returns nil for a plain asset id or an unknown name.
local function resolve(id: string, far: boolean?): (string, SoundAtlas.Region?)
	if string.sub(id, 1, 6) ~= "atlas:" then
		return id, nil
	end
	local name = string.sub(id, 7)
	if far and SoundAtlas[name .. "_Far"] then
		name ..= "_Far"
	end
	local variants = SoundAtlas[name]
	if not variants or #variants == 0 then
		return name, nil
	end
	local n = #variants
	local last = lastVariant[name]
	local i = math.random(n)
	if n > 1 and last and i == last then
		i = i % n + 1
	end
	lastVariant[name] = i
	return name, variants[i]
end

-- A plain asset id (not in the atlas): a one-off Sound, cleaned up after.
local function playLoose(id: string, group: Group, volume: number, pitch: number, at: Vector3?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.SoundGroup = groups[group]
	s.RollOffMinDistance = Audio.ROLLOFF_MIN
	s.RollOffMaxDistance = Audio.ROLLOFF_MAX
	local holder: Instance = voiceFolder or SoundService
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		holder = a
	end
	s.Parent = holder
	s.Ended:Once(function()
		if holder:IsA("Attachment") then
			holder:Destroy()
		else
			s:Destroy()
		end
	end)
	s:Play()
end

function AudioController.play(id: string?, options: PlayOptions?)
	if not id or id == "" then
		return
	end
	local o: PlayOptions = options or {}
	local group: Group = o.group or "Foley"
	local volume = o.volume or 0.6
	local jitter = Audio.PITCH_JITTER[group] or 0
	local pitch = math.max(0.05, (o.pitch or 1) * (1 + (math.random() * 2 - 1) * jitter))
	local key, region = resolve(id, o.far)
	if not region then
		if string.sub(id, 1, 6) ~= "atlas:" then
			playLoose(id, group, volume, pitch, o.at)
		end
		return
	end

	local now = os.clock()
	local at = o.at
	local v = if at
		then acquire(voices3d, Audio.VOICES_3D, true, key, now)
		else acquire(voices2d, Audio.VOICES_2D, false, key, now)
	local s = v.sound
	s:Stop()
	local range = NumberRange.new(region.start, region.start + region.length)
	s.PlaybackRegion = range
	s.LoopRegion = range
	s.Looped = false
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.SoundGroup = groups[group]
	local holder = v.holder
	if holder and at then
		holder.WorldPosition = at
	end
	s.TimePosition = region.start
	s:Play()
	v.key = key
	v.startedAt = now
	v.endsAt = now + region.length / pitch + 0.05
end

function AudioController.init()
	buildGroups()
end

return AudioController
