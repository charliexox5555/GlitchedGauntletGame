--!strict
-- UI sounds for menus (lobby now, match later; vault/02 Art/UI Polish Pass.md
-- → Sounds). Plays a Config/UiSounds cue 2D through one "UiSfx" SoundGroup,
-- from a small pool per cue (no Sound made per click), with the cue's gap
-- (hover / slider spam) and a little random pitch so repeats don't stamp.
--
--   UiSfx.play(name, pitchScale?)   play a cue
--   UiSfx.claim()                   a specific cue just played: the generic
--                                   button click (Controllers/UiSoundController)
--                                   skips this frame so they don't double
--   UiSfx.claimed(): boolean
--   UiSfx.setEnabled(on)            Settings → UI SOUNDS
--   UiSfx.preload()

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local UiSounds = require(script.Parent.Config.UiSounds)

local UiSfx = {}

local POOL = 3
local group: SoundGroup? = nil
local folder: Folder? = nil
local pools: { [string]: { sounds: { Sound }, next: number } } = {}
local lastPlayed: { [string]: number } = {}
local lastClaim = -math.huge
local enabled = true
local rng = Random.new()

local function ensure(): (SoundGroup, Folder)
	if group and folder and folder.Parent then
		return group :: SoundGroup, folder :: Folder
	end
	local g = SoundService:FindFirstChild("UiSfx")
	if not (g and g:IsA("SoundGroup")) then
		local made = Instance.new("SoundGroup")
		made.Name = "UiSfx"
		made.Volume = 1
		made.Parent = SoundService
		g = made
	end
	local f = Instance.new("Folder")
	f.Name = "UiSfxPool"
	f.Parent = SoundService
	group, folder = g :: SoundGroup, f
	return g :: SoundGroup, f
end

local function cueOf(name: string): UiSounds.Cue?
	local c = (UiSounds :: any)[name]
	if type(c) == "table" and type(c.id) == "string" and string.sub(c.id, 1, 6) ~= "atlas:" then
		return c :: UiSounds.Cue
	end
	return nil
end

local function poolFor(name: string, cue: UiSounds.Cue)
	local p = pools[name]
	if p then
		return p
	end
	local g, f = ensure()
	local list: { Sound } = {}
	for i = 1, POOL do
		local s = Instance.new("Sound")
		s.Name = name .. i
		s.SoundId = cue.id
		s.SoundGroup = g
		s.Parent = f
		table.insert(list, s)
	end
	p = { sounds = list, next = 1 }
	pools[name] = p
	return p
end

function UiSfx.play(name: string, pitchScale: number?)
	if not enabled then
		return
	end
	local cue = cueOf(name)
	if not cue then
		return
	end
	local now = os.clock()
	if cue.gap and now - (lastPlayed[name] or -math.huge) < cue.gap then
		return
	end
	lastPlayed[name] = now
	local spread = cue.spread or 0
	local speed = (pitchScale or 1) * (1 + rng:NextNumber(-spread, spread))
	local function fire(key: string, c: UiSounds.Cue)
		local p = poolFor(key, c)
		local s = p.sounds[p.next]
		p.next = p.next % #p.sounds + 1
		s.Volume = c.volume
		s.PlaybackSpeed = (c.pitch or 1) * speed
		s.TimePosition = 0
		s:Play()
	end
	fire(name, cue)
	-- layers: a designed cue is a few recordings played together (each its
	-- own pool, an optional delay)
	if cue.also then
		for i, layer in cue.also do
			local key = name .. "+" .. i
			if layer.delay and layer.delay > 0 then
				task.delay(layer.delay, fire, key, layer)
			else
				fire(key, layer)
			end
		end
	end
end

function UiSfx.claim()
	lastClaim = os.clock()
end

function UiSfx.claimed(): boolean
	return os.clock() - lastClaim < 0.05
end

-- play a specific cue in place of the generic click
function UiSfx.cue(name: string, pitchScale: number?)
	UiSfx.claim()
	UiSfx.play(name, pitchScale)
end

function UiSfx.setEnabled(on: boolean)
	enabled = on
end

function UiSfx.isEnabled(): boolean
	return enabled
end

local preloaded = false
function UiSfx.preload()
	if preloaded then
		return
	end
	preloaded = true
	task.spawn(function()
		local list: { Instance } = {}
		for name in UiSounds :: any do
			local cue = cueOf(name)
			if cue then
				table.insert(list, poolFor(name, cue).sounds[1])
				for i, layer in cue.also or {} do
					table.insert(list, poolFor(name .. "+" .. i, layer).sounds[1])
				end
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

return UiSfx
