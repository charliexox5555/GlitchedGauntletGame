--!strict
-- Subtle first-person Sundial accents built from the licensed ProPack
-- (tools/audio/design_sundial.py). One private Roblox asset per take.
-- Layered lightly under the stock weapon report and tail (first person only).
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	ghost_shot = { { asset = "rbxassetid://101181060920385", length = 0.12, gain = 1 } },
	guardian_shot = { { asset = "rbxassetid://127290693663624", length = 0.12, gain = 1 } },
	marshal_shot = { { asset = "rbxassetid://134084678910311", length = 0.12, gain = 1 } },
	operator_shot = { { asset = "rbxassetid://99295002142975", length = 0.12, gain = 1 } },
	outlaw_shot = { { asset = "rbxassetid://74605816344216", length = 0.12, gain = 1 } },
	sheriff_shot = { { asset = "rbxassetid://107370098211418", length = 0.12, gain = 1 } },
	draw = { { asset = "rbxassetid://133767261961992", length = 0.12102, gain = 1 } },
	mag_out = { { asset = "rbxassetid://93867650286768", length = 0.12, gain = 1 } },
	mag_seat = { { asset = "rbxassetid://79914324725725", length = 0.12, gain = 1 } },
	inspect = { { asset = "rbxassetid://75879048571431", length = 0.153, gain = 1 } },
	knife_slash = { { asset = "rbxassetid://113699013982182", length = 0.12, gain = 1 } },
}

local function cue(name: string, volume: number): GunSounds.GunSound
	return { id = "sundial:" .. name, volume = volume, pitch = { 0.97, 1.03 } }
end

local shots: { [string]: GunSounds.GunSound } = {
	Ghost = cue("ghost_shot", 0.20),
	Guardian = cue("guardian_shot", 0.18),
	Marshal = cue("marshal_shot", 0.19),
	Operator = cue("operator_shot", 0.18),
	Outlaw = cue("outlaw_shot", 0.19),
	Sheriff = cue("sheriff_shot", 0.20),
}

local handling: { [string]: GunSounds.GunSound } = {
	SundialDraw = cue("draw", 0.28),
	MagOut = cue("mag_out", 0.24),
	MagIn = cue("mag_seat", 0.28),
	Close = cue("mag_seat", 0.26),
	SundialInspect = cue("inspect", 0.30),
	SundialSlash = cue("knife_slash", 0.32),
	SundialHeavy = cue("knife_slash", 0.38),
}

local handlingPitch: { [string]: number } = {
	Ghost = 1.10,
	Guardian = 1.02,
	Marshal = 0.96,
	Operator = 0.88,
	Outlaw = 0.92,
	Sheriff = 1.04,
	Knife = 1.08,
}

return table.freeze({
	takes = takes,
	shots = shots,
	handling = handling,
	handlingPitch = handlingPitch,
	heavyPitch = 0.86,
	drawAt = 0.40,
	inspectAt = 0.18,
})
