--!strict
-- Frostbite Legendary skin line audio cues (tools/audio/design_frostbite.py):
-- crisp cold-forged crystalline layers over stock gunfire, staggered inspect
-- ice-growth crackles + shimmer chime, and kill fracture shatter.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	vandal_fire = { { asset = "rbxassetid://132065486262242", length = 0.13, gain = 1 } },
	phantom_fire = { { asset = "rbxassetid://129012931030871", length = 0.13, gain = 1 } },
	spectre_fire = { { asset = "rbxassetid://92162594659990", length = 0.13, gain = 1 } },
	guardian_fire = { { asset = "rbxassetid://112733224449782", length = 0.151, gain = 1 } },
	bulldog_fire = { { asset = "rbxassetid://99395370172603", length = 0.13, gain = 1 } },
	odin_fire = { { asset = "rbxassetid://139007484454034", length = 0.138, gain = 1 } },
	operator_fire = { { asset = "rbxassetid://79113774701130", length = 0.25, gain = 1 } },
	marshal_fire = { { asset = "rbxassetid://128380714358799", length = 0.173, gain = 1 } },
	bucky_fire = { { asset = "rbxassetid://108636919852465", length = 0.188, gain = 1 } },
	stinger_fire = { { asset = "rbxassetid://126131211057802", length = 0.13, gain = 1 } },
	classic_fire = { { asset = "rbxassetid://71753048785037", length = 0.13, gain = 1 } },
	sheriff_fire = { { asset = "rbxassetid://90169411370806", length = 0.188, gain = 1 } },
	shorty_fire = { { asset = "rbxassetid://112130139897964", length = 0.141, gain = 1 } },
	ghost_fire = { { asset = "rbxassetid://116831528681637", length = 0.13, gain = 1 } },
	inspect_grow = { { asset = "rbxassetid://85469900133060", length = 0.185, gain = 1 } },
	inspect_settle = { { asset = "rbxassetid://125723564872150", length = 0.28, gain = 1 } },
	kill_shatter = { { asset = "rbxassetid://134870399149985", length = 0.37, gain = 1 } },
	knife_draw = { { asset = "rbxassetid://114498235438507", length = 0.25, gain = 1 } },
	knife_slash = { { asset = "rbxassetid://86794888288327", length = 0.16, gain = 1 } },
	knife_heavy = { { asset = "rbxassetid://86270873692721", length = 0.242, gain = 1 } },
}

local function cue(name: string, volume: number, pitch: { number }?): GunSounds.GunSound
	return { id = "frostbite:" .. name, volume = volume, pitch = pitch or { 0.98, 1.02 } }
end

local shots: { [string]: GunSounds.GunSound } = {
	Vandal = cue("vandal_fire", 0.20, { 0.97, 1.03 }),
	Phantom = cue("phantom_fire", 0.19, { 0.97, 1.03 }),
	Spectre = cue("spectre_fire", 0.18, { 0.98, 1.04 }),
	Guardian = cue("guardian_fire", 0.22, { 0.97, 1.02 }),
	Bulldog = cue("bulldog_fire", 0.19, { 0.97, 1.03 }),
	Odin = cue("odin_fire", 0.19, { 0.96, 1.02 }),
	Operator = cue("operator_fire", 0.24, { 0.97, 1.02 }),
	Marshal = cue("marshal_fire", 0.22, { 0.97, 1.03 }),
	Bucky = cue("bucky_fire", 0.22, { 0.96, 1.02 }),
	Stinger = cue("stinger_fire", 0.17, { 0.98, 1.04 }),
	Classic = cue("classic_fire", 0.19, { 0.97, 1.03 }),
	Sheriff = cue("sheriff_fire", 0.23, { 0.97, 1.02 }),
	Shorty = cue("shorty_fire", 0.21, { 0.97, 1.03 }),
	Ghost = cue("ghost_fire", 0.18, { 0.98, 1.03 }),
}

local handling: { [string]: GunSounds.GunSound } = {
	FrostbiteDraw = cue("knife_draw", 0.28, { 0.98, 1.02 }),
	FrostbiteSlash = cue("knife_slash", 0.30, { 0.97, 1.03 }),
	FrostbiteHeavy = cue("knife_heavy", 0.35, { 0.97, 1.03 }),
}

return table.freeze({
	takes = takes,
	shots = shots,
	handling = handling,
	grow = cue("inspect_grow", 0.26, { 1, 1 }),
	settle = cue("inspect_settle", 0.28, { 1, 1 }),
	kill = cue("kill_shatter", 0.34, { 0.97, 1.03 }),
	growPitch = table.freeze({ 0.94, 1.04, 1.16 }),
	drawAt = 0.08,
})
