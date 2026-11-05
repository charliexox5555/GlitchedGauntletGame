--!strict
-- Plays a Shared/Config/UiSounds cue, 2D, through a "Ui" SoundGroup, with the
-- cue's minimum gap so hovering across tiles never machine-guns. (The match
-- client's Util/UiSound depends on its AudioController; the lobby has its own.)

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local UiSounds = require(ReplicatedStorage.Shared.Config.UiSounds)

local Sound = {}

local lastPlayed: { [string]: number } = {}

local function group(): SoundGroup
	local g = SoundService:FindFirstChild("Ui")
	if g and g:IsA("SoundGroup") then
		return g
	end
	local made = Instance.new("SoundGroup")
	made.Name = "Ui"
	made.Volume = 1
	made.Parent = SoundService
	return made
end

function Sound.play(name: string, pitchScale: number?)
	local cue = (UiSounds :: any)[name] :: UiSounds.Cue?
	if not cue then
		return
	end
	local now = os.clock()
	if cue.gap and now - (lastPlayed[name] or -math.huge) < cue.gap then
		return
	end
	lastPlayed[name] = now
	local s = Instance.new("Sound")
	s.SoundId = cue.id
	s.Volume = cue.volume
	s.PlaybackSpeed = (cue.pitch or 1) * (pitchScale or 1)
	s.SoundGroup = group()
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Loads every cue once in the background so the first hover isn't silent.
function Sound.preload()
	task.spawn(function()
		local list: { Instance } = {}
		for _, cue in UiSounds :: any do
			local s = Instance.new("Sound")
			s.SoundId = cue.id
			table.insert(list, s)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, s in list do
			s:Destroy()
		end
	end)
end

return Sound
