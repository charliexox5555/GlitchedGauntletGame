--!strict
-- Riftforge Legendary FULL REPLACEMENT sound set (design_riftforge_v2.py).
-- 100% real licensed/CC0 recordings (ProPack + Sonniss GDC 2016 Pole Position guns +
-- steel bulkhead sub-thump + CC0 Freesound electric/lightning/metal latch/blade):
--   - Replaces stock Phantom shots completely in GunAudio.shot (6 takes cut cleanly
--     to Phantom's fire rate, fireFirst, fireLast, 1.55s dark-matter tail, 3D fireFar).
--   - Replaces stock Phantom handling foley in WeaponController + ViewmodelController:
--     draw, drawLock (armor cowl SLAM), magOut (plasma cell discharge), magForm
--     (magnetic plasma gather swell), magIn (heavy bulkhead SLAM), rack (armor cowl
--     SLAM + barrel surge, replacing stock bolt rack!), inspectStart, inspectRoll,
--     inspectLock, and 3 plasma wall impact takes!

local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	["pFire"] = {
		{ asset = "rbxassetid://129165960174206", length = 0.165, gain = 1 }, -- RF_fire_01.wav
		{ asset = "rbxassetid://80890137787522", length = 0.165, gain = 1 }, -- RF_fire_02.wav
		{ asset = "rbxassetid://115295130878645", length = 0.165, gain = 1 }, -- RF_fire_03.wav
		{ asset = "rbxassetid://116112996361254", length = 0.165, gain = 1 }, -- RF_fire_04.wav
		{ asset = "rbxassetid://91811681053091", length = 0.165, gain = 1 }, -- RF_fire_05.wav
		{ asset = "rbxassetid://87450273780725", length = 0.165, gain = 1 }, -- RF_fire_06.wav
	},
	["pFireFirst"] = {
		{ asset = "rbxassetid://136979799378959", length = 0.165, gain = 1 }, -- RF_fireFirst_01.wav
	},
	["pFireLast"] = {
		{ asset = "rbxassetid://80825865404058", length = 1.650, gain = 1 }, -- RF_fireLast_01.wav
	},
	["pTail"] = {
		{ asset = "rbxassetid://115442257066878", length = 1.550, gain = 1 }, -- RF_tail_01.wav
	},
	["pFireFar"] = {
		{ asset = "rbxassetid://130798610537176", length = 0.165, gain = 1 }, -- RF_fireFar_01.wav
		{ asset = "rbxassetid://76778933191665", length = 0.165, gain = 1 }, -- RF_fireFar_02.wav
		{ asset = "rbxassetid://75422662976125", length = 0.165, gain = 1 }, -- RF_fireFar_03.wav
	},
	["draw"] = {
		{ asset = "rbxassetid://82206056213974", length = 0.750, gain = 1 }, -- RF_draw_01.wav
	},
	["drawLock"] = {
		{ asset = "rbxassetid://114925086316207", length = 0.580, gain = 1 }, -- RF_drawLock_01.wav
	},
	["pMagOut"] = {
		{ asset = "rbxassetid://89369131562308", length = 0.520, gain = 1 }, -- RF_magOut_01.wav
		{ asset = "rbxassetid://131052749842557", length = 0.520, gain = 1 }, -- RF_magOut_02.wav
	},
	["magForm"] = {
		{ asset = "rbxassetid://82236586005952", length = 0.550, gain = 1 }, -- RF_magForm_01.wav
	},
	["pMagIn"] = {
		{ asset = "rbxassetid://75807972791538", length = 0.480, gain = 1 }, -- RF_magIn_01.wav
		{ asset = "rbxassetid://76435674790005", length = 0.480, gain = 1 }, -- RF_magIn_02.wav
	},
	["pRack"] = {
		{ asset = "rbxassetid://75198476638641", length = 0.580, gain = 1 }, -- RF_rack_01.wav
	},
	["inspectStart"] = {
		{ asset = "rbxassetid://109417029131921", length = 0.900, gain = 1 }, -- RF_inspectStart_01.wav
	},
	["inspectRoll"] = {
		{ asset = "rbxassetid://124749042603855", length = 0.950, gain = 1 }, -- RF_inspectRoll_01.wav
	},
	["inspectLock"] = {
		{ asset = "rbxassetid://111991941104648", length = 0.580, gain = 1 }, -- RF_inspectLock_01.wav
	},
	["pImpact"] = {
		{ asset = "rbxassetid://84142045211562", length = 0.280, gain = 1 }, -- RF_impact_01.wav
		{ asset = "rbxassetid://85147127057284", length = 0.280, gain = 1 }, -- RF_impact_02.wav
		{ asset = "rbxassetid://129858742383468", length = 0.280, gain = 1 }, -- RF_impact_03.wav
	},
}

local function sound(key: string, volume: number, pitchSpread: number?): GunSounds.SoundDef
	return {
		keys = { key },
		volume = volume,
		pitchSpread = pitchSpread or 0.03,
	}
end

local FIRE = 0.72
local TAIL = 0.36
local FAR = 0.56
local FOLEY = 0.62

local guns: { [string]: { [string]: GunSounds.SoundDef } } = {
	Phantom = {
		fire = sound("pFire", FIRE, 0.035),
		fireFirst = sound("pFireFirst", FIRE * 1.05, 0.02),
		fireLast = sound("pFireLast", FIRE * 0.92, 0.015),
		tail = sound("pTail", TAIL, 0.02),
		fireFar = sound("pFireFar", FAR, 0.04),
		draw = sound("draw", FOLEY * 0.85, 0.025),
		magOut = sound("pMagOut", FOLEY, 0.03),
		magIn = sound("pMagIn", FOLEY * 1.08, 0.03),
		rack = sound("pRack", FOLEY * 1.08, 0.025),
		impact = sound("pImpact", 0.52, 0.06),
	},
}

-- Handling cues played via ViewmodelController bumps (timed to custom Riftforge tracks!)
local handling: { [string]: GunSounds.SoundDef } = {
	RiftforgeDraw = sound("draw", FOLEY * 0.9, 0.025),
	RiftforgeDrawLock = sound("drawLock", FOLEY * 1.05, 0.02),
	RiftforgeMagForm = sound("magForm", FOLEY * 0.88, 0.02),
	RiftforgeInspectStart = sound("inspectStart", FOLEY * 0.92, 0.02),
	RiftforgeInspectRoll = sound("inspectRoll", FOLEY * 0.98, 0.02),
	RiftforgeInspectLock = sound("inspectLock", FOLEY * 1.05, 0.02),
}

local RiftforgeAudio = {
	takes = takes,
	guns = guns,
	-- Legacy fallback table (empty because Phantom uses full replacement `guns.Phantom`)
	shots = {} :: { [string]: GunSounds.SoundDef },
	handling = handling,
	handlingPitch = {
		Phantom = 1.0,
	},
	-- Track timings (0..1 of track length)
	drawAt = 0.04,
	drawLockAt = 0.42,
	inspectStartAt = 0.08,
	inspectRollAt = 0.45,
	inspectLockAt = 0.80,
}

return RiftforgeAudio
