--!strict
-- Audition the UI sounds (Config/UiSounds): paste into Studio's command bar in
-- Edit mode. Plays every cue in order with its name in the Output, 1.2 s apart.

local SoundService = game:GetService("SoundService")
local UiSounds = require(game.ReplicatedStorage.Shared.Config.UiSounds)

local names = {}
for name in UiSounds :: any do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local cue = (UiSounds :: any)[name]
	local s = Instance.new("Sound")
	s.SoundId = cue.id
	s.Volume = cue.volume
	s.PlaybackSpeed = cue.pitch or 1
	s.Parent = SoundService
	print("UI sound:", name, cue.id)
	SoundService:PlayLocalSound(s)
	task.wait(1.2)
	s:Destroy()
end
