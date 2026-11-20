--!strict
-- Plays a Config/UiSounds cue in the match. A thin wrapper over Shared/UiSfx
-- (2026-11-20), so a cue sounds the same here as in the lobby: one "UiSfx"
-- sound group, pooled voices, the cue's gap and pitch spread.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiSfx = require(ReplicatedStorage.Shared.UiSfx)

local UiSound = {}

function UiSound.play(name: string, pitchScale: number?)
	UiSfx.play(name, pitchScale)
end

-- Loads every cue once, in the background, so the first hover isn't silent.
function UiSound.preload()
	UiSfx.preload()
end

return UiSound
