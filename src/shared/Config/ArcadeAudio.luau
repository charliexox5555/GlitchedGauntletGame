--!strict
-- Arcade skin line handling cues (tools/audio/design_arcade.py): a real button click or coin
-- clunk from the licensed ProPack under a soft 8-bit blip. One private Roblox asset per take.
-- The stock gun report, reload and inspect foley still play; these sit on top, quietly.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	chase = { { asset = "rbxassetid://92623653287895", length = 0.12, gain = 1 } },
	win = { { asset = "rbxassetid://118852986845022", length = 0.27, gain = 1 } },
	coin = { { asset = "rbxassetid://83881971671794", length = 0.23, gain = 1 } },
}

local function cue(name: string, volume: number): GunSounds.GunSound
	return { id = "arcade:" .. name, volume = volume, pitch = { 1, 1 } }
end

return table.freeze({
	takes = takes,
	chase = cue("chase", 0.22), -- each inspect chase step
	win = cue("win", 0.3), -- all three buttons flash at the end of the chase
	coin = cue("coin", 0.3), -- the magazine seats
	-- Pitch per button, rear to front: the chase climbs like a little arpeggio.
	chasePitch = table.freeze({ 1, 1.122, 1.26 }),
})
