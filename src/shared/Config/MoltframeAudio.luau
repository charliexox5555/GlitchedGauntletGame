--!strict
-- Subtle first-person Moltframe accents built from the licensed ProPack
-- (tools/audio/design_moltframe.py). One private Roblox asset per take.
-- Layered lightly under the stock weapon report and tail (first person only).
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	vandal_shot = { { asset = "rbxassetid://118525825306022", length = 0.12, gain = 1 } },
	phantom_shot = { { asset = "rbxassetid://82522501187559", length = 0.12, gain = 1 } },
	spectre_shot = { { asset = "rbxassetid://131621774079024", length = 0.12, gain = 1 } },
	judge_shot = { { asset = "rbxassetid://111046426890025", length = 0.12, gain = 1 } },
	ares_shot = { { asset = "rbxassetid://128834383592794", length = 0.12, gain = 1 } },
	sheriff_shot = { { asset = "rbxassetid://128715547809541", length = 0.12, gain = 1 } },
	draw = { { asset = "rbxassetid://121446243682176", length = 0.13, gain = 1 } },
	mag_seat = { { asset = "rbxassetid://125641787211175", length = 0.12, gain = 1 } },
	inspect = { { asset = "rbxassetid://75771204781966", length = 0.14002, gain = 1 } },
}

local function cue(name: string, volume: number): GunSounds.GunSound
	return { id = "moltframe:" .. name, volume = volume, pitch = { 0.97, 1.03 } }
end

local shots: { [string]: GunSounds.GunSound } = {
	Vandal = cue("vandal_shot", 0.18),
	Phantom = cue("phantom_shot", 0.21),
	Spectre = cue("spectre_shot", 0.22),
	Judge = cue("judge_shot", 0.19),
	Ares = cue("ares_shot", 0.18),
	Sheriff = cue("sheriff_shot", 0.20),
}

local handling: { [string]: GunSounds.GunSound } = {
	MoltframeDraw = cue("draw", 0.28),
	MagIn = cue("mag_seat", 0.26),
	Close = cue("mag_seat", 0.26),
	MoltframeInspect = cue("inspect", 0.30),
}

local handlingPitch: { [string]: number } = {
	Vandal = 1.0,
	Phantom = 1.04,
	Spectre = 1.09,
	Judge = 0.88,
	Ares = 0.92,
	Sheriff = 1.02,
	Knife = 1.12,
}

return table.freeze({
	takes = takes,
	shots = shots,
	handling = handling,
	handlingPitch = handlingPitch,
	drawAt = 0.42,
	inspectAt = 0.20,
})
