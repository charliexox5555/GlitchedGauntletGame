--!strict
-- Plays complete weapon and shared recordings ("gun:<Name>" and "sfx:<Name>")
-- and plain asset IDs. 2D voices play your own sounds; 3D voices (one Attachment
-- in Terrain each) play other players' shots where they happen.
--
-- Mix (Config/Audio): SoundService.Combat (master, limiter) holds the Gun,
-- Enemy, Feedback and Foley groups. Feedback has its own level.
-- Fire and tail voices can overlap to the end of each shot or tail fade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local GunSoundAssets = require(ReplicatedStorage.Shared.Config.GunSoundAssets)
local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local RuinedReaverAudio = require(ReplicatedStorage.Shared.Config.RuinedReaverAudio)
local SharedSoundAssets = require(ReplicatedStorage.Shared.Config.SharedSoundAssets)
local ShadowMistAudio = require(ReplicatedStorage.Shared.Config.ShadowMistAudio)
local SkinPreviewConfig = require(ReplicatedStorage.Shared.Config.SkinPreview)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

export type Group = Audio.Group

export type PlayOptions = {
	group: Group?, -- default "Foley"
	volume: number?, -- default 0.6
	pitch: number?, -- default 1 (jitter is added on top)
	at: Vector3?, -- play in 3D here (otherwise 2D)
	far: boolean?, -- use the "<Name>_Far" recording if there is one
	jitter: boolean?, -- add the group's small random pitch (default true)
	range: number?, -- 3D: audible up to this many studs (default Config/Audio ROLLOFF_MAX)
	cut: number?, -- fade out and stop this many wall-clock seconds after playback starts
	start: number?, -- seconds into the file to start from
	protect: boolean?, -- let a gunshot or its tail play without voice stealing
}

type Voice = {
	sound: Sound,
	holder: Attachment?,
	asset: string,
	key: string,
	startedAt: number,
	endsAt: number,
	protected: boolean, -- gunfire and its tails may not be stolen mid-play
	fade: Tween?, -- a running fadeOut, cancelled when the voice is reused
}

local AudioController = {}

type Take = GunSoundAssets.Take

-- A started sound, so it can be faded out early (AudioController.fadeOut).
export type Handle = { voice: Voice, startedAt: number }

-- Separate voice budgets for weapons and for shared map/UI cues.
type SoundBank = {
	takes: { [string]: { [number]: Take } },
	voices2d: { Voice },
	voices3d: { Voice },
}
local BANKS: { [string]: SoundBank } = {
	gun = { takes = GunSoundAssets, voices2d = {}, voices3d = {} },
	sfx = { takes = SharedSoundAssets, voices2d = {}, voices3d = {} },
	shadow = { takes = {}, voices2d = {}, voices3d = {} },
	reaver = { takes = {}, voices2d = {}, voices3d = {} },
}

local groups: { [string]: SoundGroup } = {}
type VariantBag = { remaining: { number }, last: number? }
local variantBags: { [string]: VariantBag } = {}
local mergedTakes: { [string]: { Take } } = {}
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
	for _, name in { "Gun", "Enemy", "Feedback", "Foley", "Ui", "Ambience", "Room" } do
		local g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = Audio.GROUP_VOLUME[name] or 1
		g.Parent = master
		groups[name] = g
	end
	compressor(groups.Ambience, Audio.AMBIENCE_DUCK, 2).SideChain = groups.Gun

	local folder = Instance.new("Folder")
	folder.Name = "CombatVoices"
	folder.Parent = SoundService
	voiceFolder = folder
end

local function newVoice(is3d: boolean, asset: string): Voice
	local s = Instance.new("Sound")
	s.Name = "Voice"
	s.SoundId = asset
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
	return {
		sound = s,
		holder = holder,
		asset = asset,
		key = "",
		startedAt = 0,
		endsAt = 0,
		protected = false,
		fade = nil,
	}
end

-- Ordinary cues may reuse a non-protected voice when their budget is full.
-- Gunfire uses an idle voice or grows the pool to cover the current overlap.
local function acquire(
	pool: { Voice },
	size: number,
	is3d: boolean,
	asset: string,
	key: string,
	now: number,
	protect: boolean
): Voice?
	local sameCount, sameOldest = 0, nil :: Voice?
	local activeCount = 0
	local matchingFree: Voice? = nil
	local oldest: Voice? = nil
	for _, v in pool do
		local busy = v.endsAt > now or (v.protected and v.sound.IsPlaying)
		if busy then
			activeCount += 1
			if v.protected then
				continue
			end
			if v.key == key then
				sameCount += 1
				if not sameOldest or v.startedAt < sameOldest.startedAt then
					sameOldest = v
				end
			end
			if not oldest or v.startedAt < oldest.startedAt then
				oldest = v
			end
		elseif v.asset == asset then
			if not matchingFree or v.sound.IsLoaded then
				matchingFree = v
			end
		end
	end
	if not protect and sameOldest and sameCount >= Audio.VOICES_PER_SOUND then
		return sameOldest
	end
	if protect or activeCount < size then
		if matchingFree then
			return matchingFree
		end
		local v = newVoice(is3d, asset)
		table.insert(pool, v)
		return v
	end
	return oldest
end

-- Symbolic cues use a whole recording selected from a shuffled take bag.
local function resolve(id: string, far: boolean?): (SoundBank?, string, Take?)
	local prefix, name = string.match(id, "^(%a+):(.+)$")
	if not prefix or not name then
		return nil, id, nil
	end
	local bank = BANKS[prefix]
	if not bank then
		return nil, id, nil
	end
	if far and bank.takes[name .. "_Far"] then
		name ..= "_Far"
	end
	local key = prefix .. ":" .. name
	local variants = bank.takes[name] or mergedTakes[key]
	if not variants and string.find(name, "|", 1, true) then
		local merged: { Take } = {}
		for part in string.gmatch(name, "[^|]+") do
			for _, take in bank.takes[part] or {} do
				table.insert(merged, take)
			end
		end
		mergedTakes[key] = merged
		variants = merged
	end
	if not variants or #variants == 0 then
		return bank, name, nil
	end
	if #variants == 1 then
		return bank, name, variants[1]
	end
	local bag = variantBags[key]
	if not bag then
		bag = { remaining = {}, last = nil }
		variantBags[key] = bag
	end
	local remaining = bag.remaining
	if #remaining == 0 then
		for i = 1, #variants do
			remaining[i] = i
		end
	end
	local pick = math.random(#remaining)
	if remaining[pick] == bag.last then
		-- Only possible at the start of a fresh bag. Choose another uniformly.
		pick = (pick + math.random(#remaining - 1) - 1) % #remaining + 1
	end
	local i = table.remove(remaining, pick)
	bag.last = i
	return bank, name, variants[i]
end

-- Standalone legacy IDs outside the banks can use a short fade and cleanup.
local CUT_FADE = TweenInfo.new(0.1)

-- Plain asset ids played 2D from the start (the hit marker): a small pool of
-- preloaded Sounds per id, so a play never waits on a new instance loading
-- (owner 2026-11-14: the hit marker "fires way too late").
local LOOSE_POOL = 6
local loosePools: { [string]: { Sound } } = {}

local function loosePool(id: string): { Sound }
	local pool = loosePools[id]
	if not pool then
		pool = {}
		loosePools[id] = pool
	end
	return pool
end

local function playPooled(id: string, group: Group, volume: number, pitch: number)
	local pool = loosePool(id)
	local s: Sound? = nil
	for _, p in pool do
		if not p.IsPlaying then
			s = p
			break
		end
	end
	if not s then
		if #pool < LOOSE_POOL then
			local n = Instance.new("Sound")
			n.Name = "Loose"
			n.SoundId = id
			n.Parent = voiceFolder or SoundService
			table.insert(pool, n)
			s = n
		else
			s = pool[1]
			table.remove(pool, 1)
			table.insert(pool, s :: Sound)
		end
	end
	local snd = s :: Sound
	snd.Volume = volume
	snd.PlaybackSpeed = pitch
	snd.SoundGroup = groups[group]
	snd.TimePosition = 0
	snd:Play()
end

-- Load plain asset ids ahead of their first play (2D pooled ones).
function AudioController.preload(ids: { string })
	local list: { Instance } = {}
	for _, id in ids do
		if string.sub(id, 1, 13) == "rbxassetid://" then
			local pool = loosePool(id)
			if #pool == 0 then
				local n = Instance.new("Sound")
				n.Name = "Loose"
				n.SoundId = id
				n.Parent = voiceFolder or SoundService
				table.insert(pool, n)
			end
			table.insert(list, pool[1])
		end
	end
	if #list > 0 then
		task.spawn(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end
end

function AudioController.isPreloaded(id: string): boolean
	local pool = loosePools[id]
	local sound = if pool then pool[1] else nil
	return sound ~= nil and sound.IsLoaded
end

local function playLoose(
	id: string,
	group: Group,
	volume: number,
	pitch: number,
	at: Vector3?,
	range: number?,
	cut: number?,
	start: number?
)
	if not at and not cut and not start then
		playPooled(id, group, volume, pitch)
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.SoundGroup = groups[group]
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	local far = range or Audio.ROLLOFF_MAX
	s.RollOffMinDistance = math.min(Audio.ROLLOFF_MIN, far * 0.25)
	s.RollOffMaxDistance = far
	local holder: Instance = voiceFolder or SoundService
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		holder = a
	end
	s.Parent = holder
	if start then
		s.TimePosition = start
	end
	s.Ended:Once(function()
		if holder:IsA("Attachment") then
			holder:Destroy()
		else
			s:Destroy()
		end
	end)
	s:Play()
	if cut then
		task.delay(math.max(cut - 0.1, 0), function()
			if s.Parent then
				local fade = TweenService:Create(s, CUT_FADE, { Volume = 0 })
				fade.Completed:Once(function()
					s:Stop() -- Stop doesn't fire Ended: clean up here
					if holder:IsA("Attachment") then
						holder:Destroy()
					else
						s:Destroy()
					end
				end)
				fade:Play()
			end
		end)
	end
end

function AudioController.play(id: string?, options: PlayOptions?): Handle?
	if not id or id == "" then
		return nil
	end
	local o: PlayOptions = options or {}
	local group: Group = o.group or "Foley"
	local volume = o.volume or 0.6
	local jitter = if o.jitter == false then 0 else Audio.PITCH_JITTER[group] or 0
	local pitch = math.max(0.05, (o.pitch or 1) * (1 + (math.random() * 2 - 1) * jitter))
	local bank, key, take = resolve(id, o.far)
	if not bank then
		playLoose(id, group, volume, pitch, o.at, o.range, o.cut, o.start)
		return nil
	end
	if not take then
		return nil
	end

	local now = os.clock()
	local at = o.at
	local protect = (bank == BANKS.gun or bank == BANKS.shadow) and o.protect == true
	local asset = take.asset
	local v = if at
		then acquire(bank.voices3d, Audio.VOICES_3D, true, asset, key, now, protect)
		else acquire(bank.voices2d, Audio.VOICES_2D, false, asset, key, now, protect)
	if not v then
		return nil
	end
	local s = v.sound
	if v.fade then
		v.fade:Cancel()
		v.fade = nil
	end
	s:Stop()
	if v.asset ~= asset then
		s.SoundId = asset
		v.asset = asset
	end
	s.Volume = volume * take.gain
	s.PlaybackSpeed = pitch
	s.SoundGroup = groups[group]
	local holder = v.holder
	if holder and at then
		holder.WorldPosition = at
		-- Voices are reused: set the range every play.
		local far = o.range or Audio.ROLLOFF_MAX
		s.RollOffMinDistance = math.min(Audio.ROLLOFF_MIN, far * 0.25)
		s.RollOffMaxDistance = far
	end
	local start = o.start or 0
	s.TimePosition = start
	s:Play()
	v.key = key
	v.protected = protect
	v.startedAt = now
	v.endsAt = now + math.max(take.length - start, 0) / pitch + 0.05
	local handle = { voice = v, startedAt = now }
	if o.cut then
		local fadeTime = math.min(o.cut, 0.10)
		task.delay(o.cut - fadeTime, function()
			if not v.fade then
				AudioController.fadeOut(handle, fadeTime)
			end
		end)
	end
	return handle
end

-- Fades a started sound out over `time` s and stops it, unless its voice has
-- moved on to another sound since (automatic guns' tails: each shot fades the
-- last shot's tail, as the pro pack's guide says).
function AudioController.fadeOut(handle: Handle?, time: number)
	if not handle then
		return
	end
	local v = handle.voice
	if v.startedAt ~= handle.startedAt or v.endsAt <= os.clock() then
		return
	end
	local s = v.sound
	local startedAt = handle.startedAt
	v.endsAt = math.min(v.endsAt, os.clock() + time)
	local tween =
		TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Linear), { Volume = 0 })
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and v.startedAt == startedAt then
			s:Stop()
			v.fade = nil
		end
	end)
	v.fade = tween
	tween:Play()
end

-- Plays one entry of Config/GunSounds: its own volume (times `volumeScale`)
-- and a random pitch inside its range. `at`: 3D at that point, else 2D.
function AudioController.playSound(
	sound: GunSounds.GunSound?,
	group: Group,
	at: Vector3?,
	volumeScale: number?,
	pitchScale: number?,
	studs: number? -- 3D: audible up to this many studs (default Config/Audio ROLLOFF_MAX)
): Handle?
	if not sound then
		return nil
	end
	local pitchRange = sound.pitch
	local pitch = (
		if pitchRange and #pitchRange >= 2
			then pitchRange[1] + math.random() * (pitchRange[2] - pitchRange[1])
			else 1
	) * (pitchScale or 1)
	-- a small random level per play (Config/Audio VOLUME_JITTER_DB)
	local jitterDb = Audio.VOLUME_JITTER_DB[group] or 0
	local level = 10 ^ ((math.random() * 2 - 1) * jitterDb / 20)
	return AudioController.play(sound.id, {
		group = group,
		volume = sound.volume * (volumeScale or 1) * level,
		pitch = pitch,
		at = at,
		range = studs,
		jitter = false,
		protect = group == "Gun" or group == "Enemy",
	})
end

-- The SoundGroup for `group` (Controllers/AmbienceController adds its own
-- effects to the ambience buses).
function AudioController.group(group: Group): SoundGroup?
	return groups[group]
end

local function preloadBank(
	bank: SoundBank,
	equipPriority: { string }?,
	stagedTakes: { [string]: { Take } }?
)
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(takes: { [number]: Take })
		for _, take in takes do
			if not seen[take.asset] then
				seen[take.asset] = true
				table.insert(ids, take.asset)
			end
		end
	end
	-- Kits available at spawn should load while the remaining weapons buffer.
	for _, weapon in equipPriority or {} do
		for _, sound in GunSounds.get(weapon) :: { [string]: GunSounds.GunSound } do
			for name in string.gmatch(string.sub(sound.id, 5), "[^|]+") do
				add(bank.takes[name] or {})
			end
		end
	end
	for _, takes in stagedTakes or bank.takes do
		add(takes)
	end
	task.spawn(function()
		local contentProvider = game:GetService("ContentProvider")
		local loaded: { [string]: boolean } = {}
		for first = 1, #ids, Audio.PRELOAD_BATCH_SIZE do
			local batch = {}
			for index = first, math.min(first + Audio.PRELOAD_BATCH_SIZE - 1, #ids) do
				local voice = newVoice(false, ids[index])
				table.insert(bank.voices2d, voice)
				table.insert(batch, voice.sound)
			end
			contentProvider:PreloadAsync(batch)
			if stagedTakes then
				for _, sound in batch do
					loaded[sound.SoundId] = sound.IsLoaded
				end
			end
		end
		-- Make the private skin cues available after loading. Missing files
		-- stay out of the variation bag so the caller can use its fallback.
		for name, takes in stagedTakes or {} do
			local ready: { Take } = {}
			for _, take in takes do
				if loaded[take.asset] then
					table.insert(ready, take)
				end
			end
			bank.takes[name] = ready
		end
	end)
end

function AudioController.init()
	buildGroups()
	if RunService:IsStudio() and game.PlaceId == SkinPreviewConfig.PLACE_ID then
		preloadBank(BANKS.shadow, nil, ShadowMistAudio.takes)
	end
	if game.PlaceId == SkinPreviewConfig.PLACE_ID then
		preloadBank(BANKS.reaver, nil, RuinedReaverAudio.takes)
	end
	preloadBank(BANKS.gun, { "Vandal", "Classic", "Knife" })
	preloadBank(BANKS.sfx)
	-- the hit / kill sounds that are plain asset ids, loaded before the first hit
	AudioController.preload({ Sounds.HitBody, Sounds.HitHead, Sounds.Kill, Sounds.KillHead })
end

return AudioController
