--!strict
-- Tempest-Strike audio. Every take is its own upload (no atlases).
--   - Handling cues (Util/TempestIdle.cue, Util/TempestKatana) and the
--     Tempest-Strike Vandal's own set (`vandal`): sound set v2, 2026-11-22,
--     built by tools/audio/design_tempest_vandal.py from the ProPack rifle
--     set, the Pole Position AKM / HK416 mics (Sonniss GDC 2016) and CC0
--     water and electric recordings; owner approved the audition.
--   - magOut / magSeat (v1, tools/audio/design_tempest_sfx.py) stay for the
--     other Tempest guns' and the katana's cues.
-- Ledger and recipes: vault 02 Art/Skins/TempestStrike/Vandal Sound Set v2.md
-- and Tempest Audio.md.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	draw = {
		{ asset = "rbxassetid://99932376882362", length = 0.850, gain = 1 }, -- draw_01.wav
	},
	drawLock = {
		{ asset = "rbxassetid://92881246851525", length = 0.400, gain = 1 }, -- drawLock_01.wav
	},
	inspect = {
		{ asset = "rbxassetid://76322207431174", length = 1.000, gain = 1 }, -- inspect_01.wav
	},
	inspectRoll = {
		{ asset = "rbxassetid://75814397400601", length = 0.700, gain = 1 }, -- inspectRoll_01.wav
	},
	inspectCatch = {
		{ asset = "rbxassetid://87192897725862", length = 0.400, gain = 1 }, -- inspectCatch_01.wav
	},
	magForm = {
		{ asset = "rbxassetid://85958480571757", length = 0.550, gain = 1 }, -- magForm_01.wav
	},
	aimIn = {
		{ asset = "rbxassetid://97692084561090", length = 0.320, gain = 1 }, -- aimIn_01.wav
	},
	reloadSpin = {
		{ asset = "rbxassetid://139181635677629", length = 0.550, gain = 1 }, -- reloadSpin_01.wav
	},
	vFire = {
		{ asset = "rbxassetid://104412117751371", length = 0.500, gain = 1 }, -- fire_01.wav
		{ asset = "rbxassetid://110875818461341", length = 0.500, gain = 1 }, -- fire_02.wav
		{ asset = "rbxassetid://102606974070920", length = 0.500, gain = 1 }, -- fire_03.wav
		{ asset = "rbxassetid://127913519842688", length = 0.500, gain = 1 }, -- fire_04.wav
		{ asset = "rbxassetid://86178426241116", length = 0.500, gain = 1 }, -- fire_05.wav
		{ asset = "rbxassetid://122183537390675", length = 0.500, gain = 1 }, -- fire_06.wav
		{ asset = "rbxassetid://126505338566991", length = 0.500, gain = 1 }, -- fire_07.wav
		{ asset = "rbxassetid://109750630910733", length = 0.500, gain = 1 }, -- fire_08.wav
	},
	vFireFirst = {
		{ asset = "rbxassetid://98693356941532", length = 0.500, gain = 1 }, -- fireFirst_01.wav
	},
	vFireLast = {
		{ asset = "rbxassetid://138582710461704", length = 2.532, gain = 1 }, -- fireLast_01.wav
	},
	vTail = {
		{ asset = "rbxassetid://74682361856835", length = 1.600, gain = 1 }, -- tail_01.wav
	},
	vFireFar = {
		{ asset = "rbxassetid://125962863151162", length = 0.500, gain = 1 }, -- fireFar_01.wav
		{ asset = "rbxassetid://128460043469781", length = 0.500, gain = 1 }, -- fireFar_02.wav
		{ asset = "rbxassetid://103182678322163", length = 0.500, gain = 1 }, -- fireFar_03.wav
		{ asset = "rbxassetid://104029440745714", length = 0.500, gain = 1 }, -- fireFar_04.wav
	},
	vDryFire = {
		{ asset = "rbxassetid://101368209618074", length = 0.300, gain = 1 }, -- dryFire_01.wav
		{ asset = "rbxassetid://85342365188142", length = 0.300, gain = 1 }, -- dryFire_02.wav
		{ asset = "rbxassetid://87230236039825", length = 0.300, gain = 1 }, -- dryFire_03.wav
	},
	vMagOut = {
		{ asset = "rbxassetid://104682444876279", length = 0.600, gain = 1 }, -- magOut_01.wav
		{ asset = "rbxassetid://136104471834612", length = 0.600, gain = 1 }, -- magOut_02.wav
		{ asset = "rbxassetid://99869873979232", length = 0.600, gain = 1 }, -- magOut_03.wav
	},
	vMagIn = {
		{ asset = "rbxassetid://89031328585584", length = 0.500, gain = 1 }, -- magIn_01.wav
		{ asset = "rbxassetid://92658347004218", length = 0.500, gain = 1 }, -- magIn_02.wav
		{ asset = "rbxassetid://100352975766044", length = 0.500, gain = 1 }, -- magIn_03.wav
	},
	vRack = {
		{ asset = "rbxassetid://72652596755866", length = 0.800, gain = 1 }, -- rack_01.wav
		{ asset = "rbxassetid://120879430569319", length = 0.800, gain = 1 }, -- rack_02.wav
		{ asset = "rbxassetid://87604143969614", length = 0.800, gain = 1 }, -- rack_03.wav
	},
	vImpact = {
		{ asset = "rbxassetid://72005627368771", length = 0.300, gain = 1 }, -- impact_01.wav
		{ asset = "rbxassetid://124073180960973", length = 0.300, gain = 1 }, -- impact_02.wav
		{ asset = "rbxassetid://123399204518036", length = 0.300, gain = 1 }, -- impact_03.wav
		{ asset = "rbxassetid://128080953195438", length = 0.300, gain = 1 }, -- impact_04.wav
	},
	magOut = { { asset = "rbxassetid://139060144983977", length = 0.58, gain = 1 } }, -- v1
	magSeat = { { asset = "rbxassetid://89772200759443", length = 0.32, gain = 1 } }, -- v1
}

local function cue(name: string, volume: number, pitch: { number }?): GunSounds.GunSound
	return { id = "tempest:" .. name, volume = volume, pitch = pitch }
end

-- The stock Vandal's levels (Config/GunSounds: fire 1 x report trim 1.34, tail
-- 1.6 x 1.34, far 0.9 x 1.34, foley 0.8 x take gain 1.135); the v2 files are
-- levelled against those same stock slices (+0.8 dB shots, +1 dB foley).
local REPORT = 1.34
local FOLEY = 0.91

return table.freeze({
	takes = takes,
	-- TempestIdle / TempestKatana cue name -> sound
	cues = table.freeze({
		draw = cue("draw", 0.55, { 0.98, 1.02 }),
		drawLock = cue("drawLock", 0.45, { 0.97, 1.03 }),
		aimIn = cue("aimIn", 0.5, { 0.98, 1.03 }), -- a short high water swish into the sights
		inspect = cue("inspect", 0.5),
		idleSurge = cue("inspect", 0.22, { 1.05, 1.12 }), -- the idle flourish: the swirl, softer and higher
		inspectRoll = cue("inspectRoll", 0.6),
		reloadSpin = cue("reloadSpin", 0.55),
		inspectCatch = cue("inspectCatch", 0.55),
		magOut = cue("magOut", 0.6, { 0.95, 1.05 }),
		magForm = cue("magForm", 0.6),
		magSeat = cue("magSeat", 0.45, { 0.96, 1.04 }),
		katanaOut = cue("inspectRoll", 0.5, { 1.08, 1.14 }),
		katanaIn = cue("magOut", 0.5, { 1.1, 1.18 }),
		cleave = cue("drawLock", 0.6, { 0.84, 0.9 }), -- the katana heavy's crescent
		shellIn = cue("magSeat", 0.28, { 1.12, 1.22 }), -- each round or shell going in
	} :: { [string]: GunSounds.GunSound }),
	-- A Tempest-Strike gun's own shots and handling, by weapon (Util/GunAudio,
	-- WeaponController.playGun, EffectsController impacts).
	vandal = table.freeze({
		Vandal = table.freeze({
			fire = cue("vFire", REPORT, { 0.99, 1.01 }),
			fireFirst = cue("vFireFirst", REPORT, { 1, 1 }),
			fireLast = cue("vFireLast", REPORT, { 1, 1 }),
			tail = cue("vTail", 1.6 * REPORT, { 1, 1 }),
			fireFar = cue("vFireFar", 0.9 * REPORT, { 0.98, 1.02 }),
			dryFire = cue("vDryFire", FOLEY),
			magOut = cue("vMagOut", FOLEY),
			magIn = cue("vMagIn", FOLEY),
			rack = cue("vRack", FOLEY),
			impact = cue("vImpact", 0.55, { 0.95, 1.05 }),
		} :: { [string]: GunSounds.GunSound }),
	} :: { [string]: { [string]: GunSounds.GunSound } }),
})
