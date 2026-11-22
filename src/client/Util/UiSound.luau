--!strict
-- Plays a Config/UiSounds cue in the match. A thin wrapper over Shared/UiSfx
-- (2026-11-20), so a cue sounds the same here as in the lobby: one "UiSfx"
-- sound group, pooled voices, the cue's gap and pitch spread.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiSfx = require(ReplicatedStorage.Shared.UiSfx)

local UiSound = {}

-- Returns the Sound it started (nil if the cue's gap or Settings held it).
function UiSound.play(name: string, pitchScale: number?, group: SoundGroup?): Sound?
	return UiSfx.play(name, pitchScale, group)
end

-- Loads every cue once, in the background, so the first hover isn't silent.
function UiSound.preload()
	UiSfx.preload()
end

return UiSound
