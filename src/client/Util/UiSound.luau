--!strict
-- Plays a Config/UiSounds cue, 2D, in the "Ui" sound group, with a per-cue
-- minimum gap so hovering across cards never machine-guns.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiSounds = require(ReplicatedStorage.Shared.Config.UiSounds)

local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local UiSound = {}

local lastPlayed: { [string]: number } = {}
local preloaded = false

function UiSound.play(name: string, pitchScale: number?)
	local cue = (UiSounds :: any)[name] :: UiSounds.Cue?
	if not cue then
		return
	end
	local now = os.clock()
	if cue.gap and now - (lastPlayed[name] or -math.huge) < cue.gap then
		return
	end
	lastPlayed[name] = now
	AudioController.play(cue.id, {
		group = "Ui",
		volume = cue.volume,
		pitch = (cue.pitch or 1) * (pitchScale or 1),
	})
end

-- Loads every cue once, in the background, so the first hover isn't silent.
function UiSound.preload()
	if preloaded then
		return
	end
	preloaded = true
	task.spawn(function()
		local list: { Sound } = {}
		for _, cue in UiSounds :: any do
			if string.sub(cue.id, 1, 6) ~= "atlas:" then -- atlas slices load with the atlas
				local s = Instance.new("Sound")
				s.SoundId = cue.id
				table.insert(list, s)
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, s in list do
			s:Destroy()
		end
	end)
end

return UiSound
