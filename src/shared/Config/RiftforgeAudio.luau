--!strict
-- Riftforge Legendary FULL REPLACEMENT sound set (design_riftforge_v2.py).
-- 100% real licensed/CC0 recordings (ProPack + Sonniss GDC 2016 Pole Position guns +
-- steel bulkhead sub-thump + CC0 Freesound electric/lightning/metal latch/blade):
--   - Uses exact `riftforge:<take>` bank keys (AudioController BANKS.riftforge) and
--     matches TempestAudio's reference gain levels (REPORT = 1.34, FOLEY = 0.91) so
--     every shot, draw, reload, inspect, and wall impact plays loud, crisp, and
--     unmistakably custom (replacing stock Phantom completely!).

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
	-- Riftfang Legendary Knife (design_riftforge_knife.py)
	["kDraw"] = {
		{ asset = "rbxassetid://91226163896573", length = 0.720, gain = 1 }, -- RFK_draw_01.wav
	},
	["kFire"] = {
		{ asset = "rbxassetid://112272737195710", length = 0.500, gain = 1 }, -- RFK_fire_v2_01.wav
		{ asset = "rbxassetid://101854944223968", length = 0.500, gain = 1 }, -- RFK_fire_v2_02.wav
		{ asset = "rbxassetid://119488762657946", length = 0.500, gain = 1 }, -- RFK_fire_v2_03.wav
	},
	["kHeavy"] = {
		{ asset = "rbxassetid://86530047848301", length = 1.050, gain = 1 }, -- RFK_heavy_v2_01.wav
		{ asset = "rbxassetid://104522922218474", length = 1.050, gain = 1 }, -- RFK_heavy_v2_02.wav
	},
	["kHitBody"] = {
		{ asset = "rbxassetid://103506424041835", length = 0.420, gain = 1 }, -- RFK_hitBody_01.wav
		{ asset = "rbxassetid://113464592264369", length = 0.420, gain = 1 }, -- RFK_hitBody_02.wav
		{ asset = "rbxassetid://77550242975025", length = 0.420, gain = 1 }, -- RFK_hitBody_03.wav
	},
	["kHitWall"] = {
		{ asset = "rbxassetid://95566695459194", length = 0.380, gain = 1 }, -- RFK_hitWall_01.wav
		{ asset = "rbxassetid://83183424408170", length = 0.380, gain = 1 }, -- RFK_hitWall_02.wav
		{ asset = "rbxassetid://80405049793005", length = 0.380, gain = 1 }, -- RFK_hitWall_03.wav
	},
	["kInspectStart"] = {
		{ asset = "rbxassetid://125781035730958", length = 0.780, gain = 1 }, -- RFK_inspectStart_01.wav
	},
	["kInspectSpin"] = {
		{ asset = "rbxassetid://127484923836746", length = 0.720, gain = 1 }, -- RFK_inspectTurn_v2_01.wav
	},
	["kInspectLock"] = {
		{ asset = "rbxassetid://110938431483904", length = 0.480, gain = 1 }, -- RFK_inspectLock_01.wav
	},
	-- Riftforge Operator v2 (Clean Supersonic Dual-Rail Plasma Sniper Cannon — zero mid-bark!)
	["opFire"] = {
		{ asset = "rbxassetid://106750152238849", length = 1.550, gain = 1 }, -- RFO_fire_v2_01.wav
		{ asset = "rbxassetid://92863609384743", length = 1.550, gain = 1 }, -- RFO_fire_v2_02.wav
		{ asset = "rbxassetid://128195765633410", length = 1.550, gain = 1 }, -- RFO_fire_v2_03.wav
	},
	["opFireFar"] = {
		{ asset = "rbxassetid://72372525749855", length = 1.550, gain = 1 }, -- RFO_fireFar_v2_01.wav
		{ asset = "rbxassetid://124871472598899", length = 1.550, gain = 1 }, -- RFO_fireFar_v2_02.wav
	},
	["opCycle"] = {
		{ asset = "rbxassetid://108236908299258", length = 0.680, gain = 1 }, -- RFO_cycle_01.wav
	},
	-- Riftforge Sheriff (Heavy Reactor Revolver)
	["shFire"] = {
		{ asset = "rbxassetid://107805861739571", length = 0.950, gain = 1 }, -- RFS_fire_01.wav
		{ asset = "rbxassetid://111624459866618", length = 0.950, gain = 1 }, -- RFS_fire_02.wav
		{ asset = "rbxassetid://72603322369711", length = 0.950, gain = 1 }, -- RFS_fire_03.wav
	},
	["shFireFar"] = {
		{ asset = "rbxassetid://92361008551560", length = 0.950, gain = 1 }, -- RFS_fireFar_01.wav
		{ asset = "rbxassetid://80820011268912", length = 0.950, gain = 1 }, -- RFS_fireFar_02.wav
	},
	["shOpen"] = {
		{ asset = "rbxassetid://131794987546006", length = 0.460, gain = 1 }, -- RFS_open_01.wav
	},
	["shClose"] = {
		{ asset = "rbxassetid://96289120295281", length = 0.440, gain = 1 }, -- RFS_close_01.wav
	},
	-- Riftforge Spectre (High-ROF Suppressed Plasma SMG)
	["spFire"] = {
		{ asset = "rbxassetid://133132975923406", length = 0.140, gain = 1 }, -- RFSP_fire_01.wav
		{ asset = "rbxassetid://101361773446875", length = 0.140, gain = 1 }, -- RFSP_fire_02.wav
		{ asset = "rbxassetid://106905992440750", length = 0.140, gain = 1 }, -- RFSP_fire_03.wav
		{ asset = "rbxassetid://130245102264788", length = 0.140, gain = 1 }, -- RFSP_fire_04.wav
	},
	["spFireFirst"] = {
		{ asset = "rbxassetid://117587664589131", length = 0.140, gain = 1 }, -- RFSP_fireFirst_01.wav
	},
	["spFireLast"] = {
		{ asset = "rbxassetid://76158530726142", length = 1.450, gain = 1 }, -- RFSP_fireLast_01.wav
	},
	["spTail"] = {
		{ asset = "rbxassetid://78841569688920", length = 1.400, gain = 1 }, -- RFSP_tail_01.wav
	},
	["spFireFar"] = {
		{ asset = "rbxassetid://124171999940163", length = 0.140, gain = 1 }, -- RFSP_fireFar_01.wav
		{ asset = "rbxassetid://113288280915890", length = 0.140, gain = 1 }, -- RFSP_fireFar_02.wav
	},
	-- Riftforge Shorty (Break-Action Twin-Core Plasma Pocket Shotgun)
	["soFire"] = {
		{ asset = "rbxassetid://140005707592671", length = 1.250, gain = 1 }, -- RFSH_fire_01.wav
		{ asset = "rbxassetid://90720186995399", length = 1.250, gain = 1 }, -- RFSH_fire_02.wav
		{ asset = "rbxassetid://134653890511064", length = 1.250, gain = 1 }, -- RFSH_fire_03.wav
	},
	["soFireFar"] = {
		{ asset = "rbxassetid://137391894628511", length = 1.250, gain = 1 }, -- RFSH_fireFar_01.wav
		{ asset = "rbxassetid://112337804199359", length = 1.250, gain = 1 }, -- RFSH_fireFar_02.wav
	},
	["soOpen"] = {
		{ asset = "rbxassetid://133654666518579", length = 0.480, gain = 1 }, -- RFSH_open_01.wav
	},
	["soClose"] = {
		{ asset = "rbxassetid://80737955432934", length = 0.460, gain = 1 }, -- RFSH_close_01.wav
	},
}

local function cue(name: string, volume: number, pitch: { number }?): GunSounds.GunSound
	return { id = "riftforge:" .. name, volume = volume, pitch = pitch }
end

-- Reference levels matched to stock Phantom / TempestAudio so every shot and
-- handling beat lands with unmistakable Legendary punch.
local REPORT = 1.34
local FOLEY = 0.92

local guns: { [string]: { [string]: GunSounds.GunSound } } = table.freeze({
	Phantom = table.freeze({
		fire = cue("pFire", REPORT, { 0.985, 1.015 }),
		fireFirst = cue("pFireFirst", REPORT * 1.04, { 1, 1 }),
		fireLast = cue("pFireLast", REPORT * 0.95, { 1, 1 }),
		tail = cue("pTail", 1.15 * REPORT, { 0.99, 1.01 }),
		fireFar = cue("pFireFar", 0.85 * REPORT, { 0.97, 1.03 }),
		draw = cue("draw", FOLEY * 0.88, { 0.98, 1.02 }),
		magOut = cue("pMagOut", FOLEY, { 0.97, 1.03 }),
		magIn = cue("pMagIn", FOLEY * 1.08, { 0.97, 1.03 }),
		rack = cue("pRack", FOLEY * 1.10, { 0.98, 1.02 }),
		impact = cue("pImpact", 0.72, { 0.95, 1.06 }),
	}),
	Operator = table.freeze({
		fire = cue("opFire", REPORT * 1.12, { 0.98, 1.02 }),
		fireFar = cue("opFireFar", 0.95 * REPORT, { 0.97, 1.03 }),
		draw = cue("draw", FOLEY * 0.94, { 0.84, 0.88 }),
		magOut = cue("pMagOut", FOLEY * 1.05, { 0.84, 0.88 }),
		magIn = cue("pMagIn", FOLEY * 1.12, { 0.84, 0.88 }),
		rack = cue("opCycle", FOLEY * 1.15, { 0.97, 1.03 }),
		bolt = cue("opCycle", FOLEY * 1.12, { 0.97, 1.03 }),
		impact = cue("pImpact", 0.85, { 0.82, 0.90 }),
	}),
	Sheriff = table.freeze({
		fire = cue("shFire", REPORT * 1.06, { 0.98, 1.02 }),
		fireFar = cue("shFireFar", 0.90 * REPORT, { 0.97, 1.03 }),
		draw = cue("draw", FOLEY * 0.92, { 1.04, 1.08 }),
		open = cue("shOpen", FOLEY * 1.05, { 0.97, 1.03 }),
		eject = cue("pMagOut", FOLEY * 0.96, { 1.08, 1.14 }),
		shellIn = cue("pMagIn", FOLEY * 1.06, { 1.04, 1.08 }),
		close = cue("shClose", FOLEY * 1.12, { 0.97, 1.03 }),
		magOut = cue("shOpen", FOLEY * 1.05, { 0.97, 1.03 }),
		magIn = cue("pMagIn", FOLEY * 1.05, { 1.04, 1.08 }),
		rack = cue("shClose", FOLEY * 1.12, { 0.97, 1.03 }),
		impact = cue("pImpact", 0.78, { 0.94, 1.04 }),
	}),
	Spectre = table.freeze({
		fire = cue("spFire", REPORT * 0.98, { 0.985, 1.015 }),
		fireFirst = cue("spFireFirst", REPORT * 1.02, { 1, 1 }),
		fireLast = cue("spFireLast", REPORT * 0.94, { 1, 1 }),
		tail = cue("spTail", 1.10 * REPORT, { 0.99, 1.01 }),
		fireFar = cue("spFireFar", 0.82 * REPORT, { 0.97, 1.03 }),
		draw = cue("draw", FOLEY * 0.88, { 1.06, 1.10 }),
		magOut = cue("pMagOut", FOLEY * 0.96, { 1.06, 1.10 }),
		magIn = cue("pMagIn", FOLEY * 1.04, { 1.06, 1.10 }),
		rack = cue("pRack", FOLEY * 1.05, { 1.06, 1.10 }),
		impact = cue("pImpact", 0.68, { 1.02, 1.10 }),
	}),
	Shorty = table.freeze({
		fire = cue("soFire", REPORT * 1.10, { 0.98, 1.02 }),
		fireFar = cue("soFireFar", 0.92 * REPORT, { 0.97, 1.03 }),
		draw = cue("draw", FOLEY * 0.92, { 0.90, 0.95 }),
		open = cue("soOpen", FOLEY * 1.08, { 0.97, 1.03 }),
		eject = cue("pMagOut", FOLEY * 0.98, { 0.90, 0.96 }),
		shellIn = cue("pMagIn", FOLEY * 1.06, { 0.92, 0.98 }),
		close = cue("soClose", FOLEY * 1.14, { 0.97, 1.03 }),
		magOut = cue("soOpen", FOLEY * 1.08, { 0.97, 1.03 }),
		magIn = cue("pMagIn", FOLEY * 1.06, { 0.92, 0.98 }),
		rack = cue("soClose", FOLEY * 1.14, { 0.97, 1.03 }),
		impact = cue("pImpact", 0.80, { 0.88, 0.96 }),
	}),
	Knife = table.freeze({
		draw = cue("kDraw", FOLEY * 1.05, { 0.98, 1.02 }),
		fire = cue("kFire", 1.24, { 0.97, 1.04 }),
		heavy = cue("kHeavy", 1.30, { 0.98, 1.02 }),
		hitBody = cue("kHitBody", 1.16, { 0.96, 1.04 }),
		hitWall = cue("kHitWall", 1.08, { 0.96, 1.04 }),
		hitMetal = cue("kHitWall", 1.12, { 1.04, 1.12 }),
		hitWood = cue("kHitWall", 1.04, { 0.90, 0.96 }),
		hitSoft = cue("kHitWall", 1.00, { 0.84, 0.90 }),
	}),
})

-- Handling cues played via ViewmodelController bumps (timed to custom Riftforge tracks!)
local handling: { [string]: GunSounds.GunSound } = table.freeze({
	RiftforgeDraw = cue("draw", FOLEY * 0.90, { 0.98, 1.02 }),
	RiftforgeDrawLock = cue("drawLock", FOLEY * 1.08, { 0.98, 1.02 }),
	RiftforgeMagForm = cue("magForm", FOLEY * 0.92, { 0.98, 1.02 }),
	RiftforgeReloadRoll = cue("inspectRoll", FOLEY * 0.95, { 1.04, 1.08 }),
	RiftforgeInspectStart = cue("inspectStart", FOLEY * 0.94, { 0.98, 1.02 }),
	RiftforgeInspectRoll = cue("inspectRoll", FOLEY * 1.00, { 0.98, 1.02 }),
	RiftforgeInspectLock = cue("inspectLock", FOLEY * 1.08, { 0.98, 1.02 }),
	-- Riftfang Knife inspect timeline cues
	RiftfangInspectStart = cue("kInspectStart", FOLEY * 0.98, { 0.98, 1.02 }),
	RiftfangInspectSpin = cue("kInspectSpin", FOLEY * 1.02, { 0.98, 1.02 }),
	RiftfangInspectLock = cue("kInspectLock", FOLEY * 1.08, { 0.98, 1.02 }),
})

return table.freeze({
	takes = takes,
	guns = guns,
	-- Legacy fallback table (empty: Phantom/Knife use full replacement `guns.*`)
	shots = table.freeze({}) :: { [string]: GunSounds.GunSound },
	handling = handling,
	handlingPitch = table.freeze({
		Phantom = 1.0,
		Operator = 0.86,
		Sheriff = 1.04,
		Spectre = 1.08,
		Shorty = 0.92,
		Knife = 1.0,
	}),
	-- Track timings (0..1 of track length)
	drawAt = 0.03,
	drawLockAt = 0.42,
	reloadRollAt = 0.53,
	inspectStartAt = 0.08,
	inspectRollAt = 0.45,
	inspectLockAt = 0.80,
	-- Riftfang Knife inspect cue timings (3.4s natural wrist-roll track)
	knifeInspectStartAt = 0.08,
	knifeInspectSpinAt = 0.41,
	knifeInspectLockAt = 0.77,
})
