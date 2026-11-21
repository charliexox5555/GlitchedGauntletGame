--!strict
-- Tempest-Strike Vandal foley (first person; tools/audio/design_tempest_sfx.py):
-- real CC0 water and electric recordings, cut and layered (ledger: vault
-- 02 Art/Skins/TempestStrike/Tempest Audio.md). Layered over the stock Vandal
-- handling; the gunshot stays the stock one until the skin's own shots are made.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	draw = { { asset = "rbxassetid://139394779927632", length = 0.68, gain = 1 } },
	drawLock = { { asset = "rbxassetid://137513670055806", length = 0.35, gain = 1 } },
	inspect = { { asset = "rbxassetid://75211447319830", length = 0.9, gain = 1 } },
	inspectRoll = { { asset = "rbxassetid://79439644788203", length = 0.88, gain = 1 } },
	inspectCatch = { { asset = "rbxassetid://72972938811283", length = 0.4, gain = 1 } },
	magOut = { { asset = "rbxassetid://139060144983977", length = 0.58, gain = 1 } },
	magForm = { { asset = "rbxassetid://124844050444554", length = 0.36, gain = 1 } },
	magSeat = { { asset = "rbxassetid://89772200759443", length = 0.32, gain = 1 } },
}

local function cue(name: string, volume: number, pitch: { number }?): GunSounds.GunSound
	return { id = "tempest:" .. name, volume = volume, pitch = pitch }
end

return table.freeze({
	takes = takes,
	-- TempestIdle cue name -> sound (levels set against the stock foley)
	cues = table.freeze({
		draw = cue("draw", 0.55, { 0.97, 1.03 }),
		drawLock = cue("drawLock", 0.42, { 0.96, 1.04 }),
		inspect = cue("inspect", 0.5),
		idleSurge = cue("inspect", 0.22, { 1.05, 1.12 }), -- the idle flourish: the swirl, softer and higher
		inspectRoll = cue("inspectRoll", 0.6),
		inspectCatch = cue("inspectCatch", 0.55),
		magOut = cue("magOut", 0.6, { 0.95, 1.05 }),
		magForm = cue("magForm", 0.55),
		magSeat = cue("magSeat", 0.45, { 0.96, 1.04 }),
	} :: { [string]: GunSounds.GunSound }),
})
