--!strict
-- Frostbite Legendary skin line audio cues (tools/audio/design_frostbite.py):
-- crisp cold-forged crystalline layers over stock gunfire, staggered inspect
-- ice-growth crackles + shimmer chime, and kill fracture shatter.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	vandal_fire = { { asset = "rbxassetid://132065486262242", length = 0.13, gain = 1 } },
	inspect_grow = { { asset = "rbxassetid://85469900133060", length = 0.185, gain = 1 } },
	inspect_settle = { { asset = "rbxassetid://125723564872150", length = 0.28, gain = 1 } },
	kill_shatter = { { asset = "rbxassetid://134870399149985", length = 0.37, gain = 1 } },
}

local function cue(name: string, volume: number, pitch: { number }?): GunSounds.GunSound
	return { id = "frostbite:" .. name, volume = volume, pitch = pitch or { 0.98, 1.02 } }
end

local shots: { [string]: GunSounds.GunSound } = {
	Vandal = cue("vandal_fire", 0.20, { 0.97, 1.03 }),
}

return table.freeze({
	takes = takes,
	shots = shots,
	grow = cue("inspect_grow", 0.26, { 1, 1 }),
	settle = cue("inspect_settle", 0.28, { 1, 1 }),
	kill = cue("kill_shatter", 0.34, { 0.97, 1.03 }),
	growPitch = table.freeze({ 0.94, 1.04, 1.16 }),
})
