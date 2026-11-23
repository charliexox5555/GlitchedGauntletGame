--!strict
-- Subtle first-person Playback accents built from the licensed ProPack
-- (tools/audio/design_playback.py). One private Roblox asset per take.
-- Layered lightly under the stock weapon report and tail (first person only).
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	ares_shot = { { asset = "rbxassetid://126645591058170", length = 0.12, gain = 1 } },
	bulldog_shot = { { asset = "rbxassetid://97157756026786", length = 0.12, gain = 1 } },
	classic_shot = { { asset = "rbxassetid://93916695663551", length = 0.12, gain = 1 } },
	ghost_shot = { { asset = "rbxassetid://107253028441062", length = 0.12, gain = 1 } },
	phantom_shot = { { asset = "rbxassetid://84265127923761", length = 0.12, gain = 1 } },
	stinger_shot = { { asset = "rbxassetid://112198109954071", length = 0.12, gain = 1 } },
	draw = { { asset = "rbxassetid://81783912789320", length = 0.12, gain = 1 } },
	mag_out = { { asset = "rbxassetid://72651332218345", length = 0.122, gain = 1 } },
	mag_seat = { { asset = "rbxassetid://132121884725269", length = 0.12, gain = 1 } },
	inspect = { { asset = "rbxassetid://127716998604974", length = 0.15302, gain = 1 } },
	knife_slash = { { asset = "rbxassetid://137655040492742", length = 0.12, gain = 1 } },
}

local function cue(name: string, volume: number): GunSounds.GunSound
	return { id = "playback:" .. name, volume = volume, pitch = { 0.97, 1.03 } }
end

local shots: { [string]: GunSounds.GunSound } = {
	Ares = cue("ares_shot", 0.17),
	Bulldog = cue("bulldog_shot", 0.18),
	Classic = cue("classic_shot", 0.19),
	Ghost = cue("ghost_shot", 0.21),
	Phantom = cue("phantom_shot", 0.20),
	Stinger = cue("stinger_shot", 0.18),
}

local handling: { [string]: GunSounds.GunSound } = {
	PlaybackDraw = cue("draw", 0.28),
	MagOut = cue("mag_out", 0.26),
	MagIn = cue("mag_seat", 0.28),
	Close = cue("mag_seat", 0.26),
	PlaybackInspect = cue("inspect", 0.30),
	PlaybackSlash = cue("knife_slash", 0.30),
	PlaybackHeavy = cue("knife_slash", 0.36),
}

local handlingPitch: { [string]: number } = {
	Ares = 0.92,
	Bulldog = 0.98,
	Classic = 1.06,
	Ghost = 1.08,
	Phantom = 1.02,
	Stinger = 1.12,
	Knife = 1.06,
}

return table.freeze({
	takes = takes,
	shots = shots,
	handling = handling,
	handlingPitch = handlingPitch,
	heavyPitch = 0.88,
	drawAt = 0.40,
	inspectAt = 0.18,
})
