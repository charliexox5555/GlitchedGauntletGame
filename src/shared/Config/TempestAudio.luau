--!strict
-- Tempest-Strike audio. Every take is its own upload (no atlases).
--   - The Vandal's handling cues: sound set v2 (owner approved in game
--     2026-11-22), tools/audio/design_tempest_vandal.py. Every gun's shots
--     (v3, 2026-11-22: more oomph, auto shots cut to the fire interval):
--     tools/audio/design_tempest_line.py.
--   - The electric inspect cues and the Stinger, Marshal, Bucky, Sheriff and
--     Katana sets: tools/audio/design_tempest_line.py (2026-11-22).
--   Real recordings only: the ProPack, Pole Position mics (Sonniss GDC 2016),
--   CC0 water and electric recordings.
--   - magOut / magSeat (v1, tools/audio/design_tempest_sfx.py) stay for guns
--     whose handling isn't designed yet.
-- Ledger and recipes: vault 02 Art/Skins/TempestStrike/Vandal Sound Set v2.md,
-- Line Sound Sets.md and Tempest Audio.md.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	["draw"] = {
		{ asset = "rbxassetid://99932376882362", length = 0.850, gain = 1 }, -- draw_01.wav
	},
	["drawLock"] = {
		{ asset = "rbxassetid://92881246851525", length = 0.400, gain = 1 }, -- drawLock_01.wav
	},
	["magForm"] = {
		{ asset = "rbxassetid://85958480571757", length = 0.550, gain = 1 }, -- magForm_01.wav
	},
	["aimIn"] = {
		{ asset = "rbxassetid://97692084561090", length = 0.320, gain = 1 }, -- aimIn_01.wav
	},
	["reloadSpin"] = {
		{ asset = "rbxassetid://139181635677629", length = 0.550, gain = 1 }, -- reloadSpin_01.wav
	},
	["inspect"] = {
		{ asset = "rbxassetid://95142096469647", length = 0.950, gain = 1 }, -- Insp_start_01.wav
	},
	["inspectSnap"] = {
		{ asset = "rbxassetid://135708330847365", length = 0.450, gain = 1 }, -- Insp_snap_01.wav
		{ asset = "rbxassetid://117906028482736", length = 0.450, gain = 1 }, -- Insp_snap_02.wav
	},
	["inspectRoll"] = {
		{ asset = "rbxassetid://125604723117769", length = 1.000, gain = 1 }, -- Insp_roll_01.wav
	},
	["inspectCatch"] = {
		{ asset = "rbxassetid://99954447956219", length = 0.400, gain = 1 }, -- Insp_catch_01.wav
	},
	["inspectSettle"] = {
		{ asset = "rbxassetid://115093422071197", length = 0.300, gain = 1 }, -- Insp_settle_01.wav
	},
	["katanaWave"] = {
		{ asset = "rbxassetid://106959783651439", length = 0.600, gain = 1 }, -- Katana_wave_01.wav
	},
	["vFire"] = {
		{ asset = "rbxassetid://97699524801506", length = 0.185, gain = 1 }, -- Vandal_fire_01.wav
		{ asset = "rbxassetid://132535589394765", length = 0.185, gain = 1 }, -- Vandal_fire_02.wav
		{ asset = "rbxassetid://127444344713463", length = 0.185, gain = 1 }, -- Vandal_fire_03.wav
		{ asset = "rbxassetid://101746663758834", length = 0.185, gain = 1 }, -- Vandal_fire_04.wav
		{ asset = "rbxassetid://114534631040730", length = 0.185, gain = 1 }, -- Vandal_fire_05.wav
		{ asset = "rbxassetid://111014669471431", length = 0.185, gain = 1 }, -- Vandal_fire_06.wav
		{ asset = "rbxassetid://112962618181474", length = 0.185, gain = 1 }, -- Vandal_fire_07.wav
		{ asset = "rbxassetid://82282052117883", length = 0.185, gain = 1 }, -- Vandal_fire_08.wav
	},
	["vFireFirst"] = {
		{ asset = "rbxassetid://89659957829936", length = 0.185, gain = 1 }, -- Vandal_fireFirst_01.wav
	},
	["vFireLast"] = {
		{ asset = "rbxassetid://101148310011010", length = 2.532, gain = 1 }, -- Vandal_fireLast_01.wav
	},
	["vTail"] = {
		{ asset = "rbxassetid://133323658314916", length = 1.600, gain = 1 }, -- Vandal_tail_01.wav
	},
	["vFireFar"] = {
		{ asset = "rbxassetid://127696296110395", length = 0.185, gain = 1 }, -- Vandal_fireFar_01.wav
		{ asset = "rbxassetid://115268290647424", length = 0.185, gain = 1 }, -- Vandal_fireFar_02.wav
		{ asset = "rbxassetid://131756451611781", length = 0.185, gain = 1 }, -- Vandal_fireFar_03.wav
		{ asset = "rbxassetid://70391014671414", length = 0.185, gain = 1 }, -- Vandal_fireFar_04.wav
	},
	["vDryFire"] = {
		{ asset = "rbxassetid://101368209618074", length = 0.300, gain = 1 }, -- dryFire_01.wav
		{ asset = "rbxassetid://85342365188142", length = 0.300, gain = 1 }, -- dryFire_02.wav
		{ asset = "rbxassetid://87230236039825", length = 0.300, gain = 1 }, -- dryFire_03.wav
	},
	["vMagOut"] = {
		{ asset = "rbxassetid://104682444876279", length = 0.600, gain = 1 }, -- magOut_01.wav
		{ asset = "rbxassetid://136104471834612", length = 0.600, gain = 1 }, -- magOut_02.wav
		{ asset = "rbxassetid://99869873979232", length = 0.600, gain = 1 }, -- magOut_03.wav
	},
	["vMagIn"] = {
		{ asset = "rbxassetid://89031328585584", length = 0.500, gain = 1 }, -- magIn_01.wav
		{ asset = "rbxassetid://92658347004218", length = 0.500, gain = 1 }, -- magIn_02.wav
		{ asset = "rbxassetid://100352975766044", length = 0.500, gain = 1 }, -- magIn_03.wav
	},
	["vRack"] = {
		{ asset = "rbxassetid://72652596755866", length = 0.800, gain = 1 }, -- rack_01.wav
		{ asset = "rbxassetid://120879430569319", length = 0.800, gain = 1 }, -- rack_02.wav
		{ asset = "rbxassetid://87604143969614", length = 0.800, gain = 1 }, -- rack_03.wav
	},
	["vImpact"] = {
		{ asset = "rbxassetid://72005627368771", length = 0.300, gain = 1 }, -- impact_01.wav
		{ asset = "rbxassetid://124073180960973", length = 0.300, gain = 1 }, -- impact_02.wav
		{ asset = "rbxassetid://123399204518036", length = 0.300, gain = 1 }, -- impact_03.wav
		{ asset = "rbxassetid://128080953195438", length = 0.300, gain = 1 }, -- impact_04.wav
	},
	["Stinger_fire"] = {
		{ asset = "rbxassetid://114401814954046", length = 0.143, gain = 1 }, -- Stinger_fire_01.wav
		{ asset = "rbxassetid://73414438765302", length = 0.143, gain = 1 }, -- Stinger_fire_02.wav
		{ asset = "rbxassetid://118073331947429", length = 0.143, gain = 1 }, -- Stinger_fire_03.wav
		{ asset = "rbxassetid://112744796336449", length = 0.143, gain = 1 }, -- Stinger_fire_04.wav
		{ asset = "rbxassetid://103668446087244", length = 0.143, gain = 1 }, -- Stinger_fire_05.wav
		{ asset = "rbxassetid://137898557949988", length = 0.143, gain = 1 }, -- Stinger_fire_06.wav
	},
	["Stinger_fireFirst"] = {
		{ asset = "rbxassetid://117413027122141", length = 0.143, gain = 1 }, -- Stinger_fireFirst_01.wav
	},
	["Stinger_fireLast"] = {
		{ asset = "rbxassetid://77599541715867", length = 1.859, gain = 1 }, -- Stinger_fireLast_01.wav
	},
	["Stinger_tail"] = {
		{ asset = "rbxassetid://89688543267520", length = 1.859, gain = 1 }, -- Stinger_tail_01.wav
	},
	["Stinger_fireFar"] = {
		{ asset = "rbxassetid://83246244868148", length = 0.143, gain = 1 }, -- Stinger_fireFar_01.wav
		{ asset = "rbxassetid://137168523043287", length = 0.143, gain = 1 }, -- Stinger_fireFar_02.wav
		{ asset = "rbxassetid://118112408940507", length = 0.143, gain = 1 }, -- Stinger_fireFar_03.wav
	},
	["Stinger_magOut"] = {
		{ asset = "rbxassetid://134247403214219", length = 0.600, gain = 1 }, -- Stinger_magOut_01.wav
		{ asset = "rbxassetid://129541779508812", length = 0.600, gain = 1 }, -- Stinger_magOut_02.wav
		{ asset = "rbxassetid://128019335045668", length = 0.600, gain = 1 }, -- Stinger_magOut_03.wav
	},
	["Stinger_magIn"] = {
		{ asset = "rbxassetid://131828795026714", length = 0.500, gain = 1 }, -- Stinger_magIn_01.wav
		{ asset = "rbxassetid://98151371878907", length = 0.500, gain = 1 }, -- Stinger_magIn_02.wav
		{ asset = "rbxassetid://84103379449009", length = 0.500, gain = 1 }, -- Stinger_magIn_03.wav
	},
	["Stinger_rack"] = {
		{ asset = "rbxassetid://82234905225488", length = 0.800, gain = 1 }, -- Stinger_rack_01.wav
		{ asset = "rbxassetid://110495125646888", length = 0.800, gain = 1 }, -- Stinger_rack_02.wav
		{ asset = "rbxassetid://76933379749276", length = 0.800, gain = 1 }, -- Stinger_rack_03.wav
	},
	["Stinger_dryFire"] = {
		{ asset = "rbxassetid://130247224726454", length = 0.300, gain = 1 }, -- Stinger_dryFire_01.wav
		{ asset = "rbxassetid://70482501742491", length = 0.300, gain = 1 }, -- Stinger_dryFire_02.wav
		{ asset = "rbxassetid://128311268369388", length = 0.300, gain = 1 }, -- Stinger_dryFire_03.wav
	},
	["Marshal_fire"] = {
		{ asset = "rbxassetid://113457737324541", length = 1.400, gain = 1 }, -- Marshal_fire_01.wav
		{ asset = "rbxassetid://84097844558381", length = 1.400, gain = 1 }, -- Marshal_fire_02.wav
		{ asset = "rbxassetid://136726751510249", length = 1.400, gain = 1 }, -- Marshal_fire_03.wav
		{ asset = "rbxassetid://84147696758215", length = 1.400, gain = 1 }, -- Marshal_fire_04.wav
	},
	["Marshal_fireFar"] = {
		{ asset = "rbxassetid://123303950645515", length = 1.400, gain = 1 }, -- Marshal_fireFar_01.wav
		{ asset = "rbxassetid://74365371014187", length = 1.400, gain = 1 }, -- Marshal_fireFar_02.wav
		{ asset = "rbxassetid://132564533791527", length = 1.400, gain = 1 }, -- Marshal_fireFar_03.wav
	},
	["Marshal_rack"] = {
		{ asset = "rbxassetid://93816946502063", length = 0.800, gain = 1 }, -- Marshal_rack_01.wav
		{ asset = "rbxassetid://121697431161372", length = 0.800, gain = 1 }, -- Marshal_rack_02.wav
		{ asset = "rbxassetid://92624129258258", length = 0.800, gain = 1 }, -- Marshal_rack_03.wav
		{ asset = "rbxassetid://124253428291991", length = 0.800, gain = 1 }, -- Marshal_rack_04.wav
	},
	["Marshal_shellIn"] = {
		{ asset = "rbxassetid://84704227209351", length = 0.400, gain = 1 }, -- Marshal_shellIn_01.wav
		{ asset = "rbxassetid://86672739267561", length = 0.400, gain = 1 }, -- Marshal_shellIn_02.wav
		{ asset = "rbxassetid://110945778081442", length = 0.400, gain = 1 }, -- Marshal_shellIn_03.wav
		{ asset = "rbxassetid://121943516589161", length = 0.400, gain = 1 }, -- Marshal_shellIn_04.wav
	},
	["Marshal_dryFire"] = {
		{ asset = "rbxassetid://136261408984222", length = 0.300, gain = 1 }, -- Marshal_dryFire_01.wav
		{ asset = "rbxassetid://73338883040555", length = 0.300, gain = 1 }, -- Marshal_dryFire_02.wav
		{ asset = "rbxassetid://129745569858006", length = 0.300, gain = 1 }, -- Marshal_dryFire_03.wav
	},
	["Bucky_fire"] = {
		{ asset = "rbxassetid://113942866402607", length = 1.400, gain = 1 }, -- Bucky_fire_01.wav
		{ asset = "rbxassetid://86335360382293", length = 1.400, gain = 1 }, -- Bucky_fire_02.wav
		{ asset = "rbxassetid://77521566119527", length = 1.400, gain = 1 }, -- Bucky_fire_03.wav
		{ asset = "rbxassetid://122314227585710", length = 1.400, gain = 1 }, -- Bucky_fire_04.wav
	},
	["Bucky_fireFar"] = {
		{ asset = "rbxassetid://111112244818575", length = 1.400, gain = 1 }, -- Bucky_fireFar_01.wav
		{ asset = "rbxassetid://101561915303398", length = 1.400, gain = 1 }, -- Bucky_fireFar_02.wav
		{ asset = "rbxassetid://134035516022008", length = 1.400, gain = 1 }, -- Bucky_fireFar_03.wav
	},
	["Bucky_rack"] = {
		{ asset = "rbxassetid://106052840513188", length = 0.800, gain = 1 }, -- Bucky_rack_01.wav
		{ asset = "rbxassetid://109476041705695", length = 0.800, gain = 1 }, -- Bucky_rack_02.wav
		{ asset = "rbxassetid://139166231111237", length = 0.800, gain = 1 }, -- Bucky_rack_03.wav
		{ asset = "rbxassetid://90622089719082", length = 0.800, gain = 1 }, -- Bucky_rack_04.wav
	},
	["Bucky_shellIn"] = {
		{ asset = "rbxassetid://99343031043022", length = 0.400, gain = 1 }, -- Bucky_shellIn_01.wav
		{ asset = "rbxassetid://82541650935895", length = 0.400, gain = 1 }, -- Bucky_shellIn_02.wav
		{ asset = "rbxassetid://135837670052211", length = 0.400, gain = 1 }, -- Bucky_shellIn_03.wav
		{ asset = "rbxassetid://129858486356368", length = 0.400, gain = 1 }, -- Bucky_shellIn_04.wav
	},
	["Bucky_dryFire"] = {
		{ asset = "rbxassetid://81367337597839", length = 0.300, gain = 1 }, -- Bucky_dryFire_01.wav
		{ asset = "rbxassetid://114852274533234", length = 0.300, gain = 1 }, -- Bucky_dryFire_02.wav
	},
	["Sheriff_fire"] = {
		{ asset = "rbxassetid://129959190896865", length = 1.000, gain = 1 }, -- Sheriff_fire_01.wav
		{ asset = "rbxassetid://85105117269523", length = 1.000, gain = 1 }, -- Sheriff_fire_02.wav
		{ asset = "rbxassetid://81922819565408", length = 1.000, gain = 1 }, -- Sheriff_fire_03.wav
		{ asset = "rbxassetid://96673516835351", length = 1.000, gain = 1 }, -- Sheriff_fire_04.wav
	},
	["Sheriff_fireFar"] = {
		{ asset = "rbxassetid://71816178389592", length = 1.000, gain = 1 }, -- Sheriff_fireFar_01.wav
		{ asset = "rbxassetid://113135642633662", length = 1.000, gain = 1 }, -- Sheriff_fireFar_02.wav
		{ asset = "rbxassetid://107936265590152", length = 1.000, gain = 1 }, -- Sheriff_fireFar_03.wav
	},
	["Sheriff_rack"] = {
		{ asset = "rbxassetid://86314200380422", length = 0.500, gain = 1 }, -- Sheriff_rack_01.wav
		{ asset = "rbxassetid://96761715563015", length = 0.500, gain = 1 }, -- Sheriff_rack_02.wav
		{ asset = "rbxassetid://79965159691199", length = 0.500, gain = 1 }, -- Sheriff_rack_03.wav
	},
	["Sheriff_open"] = {
		{ asset = "rbxassetid://124379713208657", length = 0.450, gain = 1 }, -- Sheriff_open_01.wav
		{ asset = "rbxassetid://99866196295290", length = 0.450, gain = 1 }, -- Sheriff_open_02.wav
		{ asset = "rbxassetid://81062220187648", length = 0.450, gain = 1 }, -- Sheriff_open_03.wav
	},
	["Sheriff_close"] = {
		{ asset = "rbxassetid://72973694349126", length = 0.450, gain = 1 }, -- Sheriff_close_01.wav
		{ asset = "rbxassetid://95662450836687", length = 0.450, gain = 1 }, -- Sheriff_close_02.wav
		{ asset = "rbxassetid://93849961990634", length = 0.450, gain = 1 }, -- Sheriff_close_03.wav
	},
	["Sheriff_eject"] = {
		{ asset = "rbxassetid://93511407685681", length = 0.500, gain = 1 }, -- Sheriff_eject_01.wav
		{ asset = "rbxassetid://105352479896125", length = 0.500, gain = 1 }, -- Sheriff_eject_02.wav
		{ asset = "rbxassetid://128515633440232", length = 0.500, gain = 1 }, -- Sheriff_eject_03.wav
	},
	["Sheriff_shellIn"] = {
		{ asset = "rbxassetid://131453923624920", length = 0.400, gain = 1 }, -- Sheriff_shellIn_01.wav
		{ asset = "rbxassetid://83051035848926", length = 0.400, gain = 1 }, -- Sheriff_shellIn_02.wav
		{ asset = "rbxassetid://83206543305071", length = 0.400, gain = 1 }, -- Sheriff_shellIn_03.wav
		{ asset = "rbxassetid://82161820581894", length = 0.400, gain = 1 }, -- Sheriff_shellIn_04.wav
	},
	["Sheriff_dryFire"] = {
		{ asset = "rbxassetid://114548236989709", length = 0.300, gain = 1 }, -- Sheriff_dryFire_01.wav
		{ asset = "rbxassetid://121318676225469", length = 0.300, gain = 1 }, -- Sheriff_dryFire_02.wav
		{ asset = "rbxassetid://132419510958360", length = 0.300, gain = 1 }, -- Sheriff_dryFire_03.wav
	},
	["Katana_fire"] = {
		{ asset = "rbxassetid://111507628939709", length = 0.500, gain = 1 }, -- Katana_fire_01.wav
		{ asset = "rbxassetid://72236334273756", length = 0.500, gain = 1 }, -- Katana_fire_02.wav
		{ asset = "rbxassetid://101693822980283", length = 0.500, gain = 1 }, -- Katana_fire_03.wav
		{ asset = "rbxassetid://92502868492690", length = 0.500, gain = 1 }, -- Katana_fire_04.wav
	},
	["Katana_heavy"] = {
		{ asset = "rbxassetid://83740489783133", length = 1.300, gain = 1 }, -- Katana_heavy_01.wav
		{ asset = "rbxassetid://103412092538772", length = 1.300, gain = 1 }, -- Katana_heavy_02.wav
	},
	["Katana_hitBody"] = {
		{ asset = "rbxassetid://134936969510008", length = 0.450, gain = 1 }, -- Katana_hitBody_01.wav
		{ asset = "rbxassetid://117444355954392", length = 0.450, gain = 1 }, -- Katana_hitBody_02.wav
		{ asset = "rbxassetid://137846154960934", length = 0.450, gain = 1 }, -- Katana_hitBody_03.wav
	},
	["Katana_hitWall"] = {
		{ asset = "rbxassetid://117941687270056", length = 0.400, gain = 1 }, -- Katana_hitWall_01.wav
		{ asset = "rbxassetid://86599130885822", length = 0.400, gain = 1 }, -- Katana_hitWall_02.wav
		{ asset = "rbxassetid://82986310052726", length = 0.400, gain = 1 }, -- Katana_hitWall_03.wav
	},
	["Katana_draw"] = {
		{ asset = "rbxassetid://140358030738456", length = 0.700, gain = 1 }, -- Katana_draw_01.wav
	},
	["Katana_drawWhoosh"] = {
		{ asset = "rbxassetid://104173951560451", length = 0.300, gain = 1 }, -- Katana_drawWhoosh_01.wav
		{ asset = "rbxassetid://94392236798851", length = 0.300, gain = 1 }, -- Katana_drawWhoosh_02.wav
		{ asset = "rbxassetid://121654578458268", length = 0.300, gain = 1 }, -- Katana_drawWhoosh_03.wav
	},
	magOut = { { asset = "rbxassetid://139060144983977", length = 0.58, gain = 1 } }, -- v1
	magSeat = { { asset = "rbxassetid://89772200759443", length = 0.32, gain = 1 } }, -- v1
}

local function cue(name: string, volume: number, pitch: { number }?): GunSounds.GunSound
	return { id = "tempest:" .. name, volume = volume, pitch = pitch }
end

-- The stock Vandal's levels (Config/GunSounds: fire 1 x report trim 1.34, tail
-- 1.6 x 1.34, far 0.9 x 1.34, foley 0.8 x take gain 1.135); every set is
-- levelled against its own gun's stock slices (+0.8 dB shots, +1 dB foley), so
-- each gun's set uses that gun's stock volumes.
local REPORT = 1.34
local FOLEY = 0.91

local function set(t: { [string]: GunSounds.GunSound }): { [string]: GunSounds.GunSound }
	return table.freeze(t)
end

return table.freeze({
	takes = takes,
	-- TempestIdle / TempestKatana cue name -> sound
	cues = table.freeze({
		draw = cue("draw", 0.55, { 0.98, 1.02 }),
		drawLock = cue("drawLock", 0.45, { 0.97, 1.03 }),
		aimIn = cue("aimIn", 0.5, { 0.98, 1.03 }), -- a short high water swish into the sights
		-- the inspect, all electric (owner 2026-11-22), on the timeline in
		-- TempestProfiles inspectSfx / SkinPreview KATANA.INSPECT_SFX
		inspect = cue("inspect", 0.5), -- the charge swell as it starts
		inspectSnap = cue("inspectSnap", 0.5, { 0.96, 1.05 }), -- a crackling whoosh per snap of the move
		inspectRoll = cue("inspectRoll", 0.55), -- the arc whirl through the roll
		inspectCatch = cue("inspectCatch", 0.55, { 0.97, 1.03 }), -- zap and click on the catch
		inspectSettle = cue("inspectSettle", 0.45), -- settling into the hold
		katanaWave = cue("katanaWave", 0.5, { 0.97, 1.03 }), -- the crackle run down the blade
		idleSurge = cue("inspect", 0.2, { 1.05, 1.12 }), -- the idle flourish: the swell, softer and higher
		reloadSpin = cue("reloadSpin", 0.55),
		magOut = cue("magOut", 0.6, { 0.95, 1.05 }),
		magForm = cue("magForm", 0.6),
		magSeat = cue("magSeat", 0.45, { 0.96, 1.04 }),
		shellIn = cue("magSeat", 0.28, { 1.12, 1.22 }), -- (guns without their own shell sound)
	} :: { [string]: GunSounds.GunSound }),
	-- A Tempest-Strike gun's own shots and handling, by weapon (Util/GunAudio,
	-- WeaponController.playGun, EffectsController impacts).
	guns = table.freeze({
		Vandal = set({
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
		}),
		Stinger = set({
			fire = cue("Stinger_fire", 1.28, { 0.98, 1.02 }),
			fireFirst = cue("Stinger_fireFirst", 1.28),
			fireLast = cue("Stinger_fireLast", 1.28),
			tail = cue("Stinger_tail", 1.28),
			fireFar = cue("Stinger_fireFar", 0.9 * 1.28, { 0.98, 1.02 }),
			magOut = cue("Stinger_magOut", FOLEY),
			magIn = cue("Stinger_magIn", FOLEY),
			rack = cue("Stinger_rack", FOLEY),
			dryFire = cue("Stinger_dryFire", FOLEY),
			impact = cue("vImpact", 0.45, { 1.0, 1.1 }),
		}),
		Marshal = set({
			fire = cue("Marshal_fire", 0.54, { 0.98, 1.02 }),
			fireFar = cue("Marshal_fireFar", 0.9 * 0.54, { 0.98, 1.02 }),
			rack = cue("Marshal_rack", FOLEY),
			shellIn = cue("Marshal_shellIn", FOLEY),
			dryFire = cue("Marshal_dryFire", FOLEY),
			impact = cue("vImpact", 0.6, { 0.9, 0.98 }),
		}),
		Bucky = set({
			fire = cue("Bucky_fire", 0.59, { 0.98, 1.02 }),
			fireFar = cue("Bucky_fireFar", 0.9 * 0.59, { 0.98, 1.02 }),
			rack = cue("Bucky_rack", FOLEY),
			shellIn = cue("Bucky_shellIn", FOLEY),
			dryFire = cue("Bucky_dryFire", FOLEY),
			impact = cue("vImpact", 0.5, { 0.92, 1.0 }),
		}),
		Sheriff = set({
			fire = cue("Sheriff_fire", 0.6, { 0.98, 1.02 }),
			fireFar = cue("Sheriff_fireFar", 0.9 * 0.6, { 0.98, 1.02 }),
			rack = cue("Sheriff_rack", FOLEY),
			open = cue("Sheriff_open", FOLEY),
			close = cue("Sheriff_close", FOLEY),
			eject = cue("Sheriff_eject", FOLEY),
			shellIn = cue("Sheriff_shellIn", FOLEY),
			dryFire = cue("Sheriff_dryFire", FOLEY),
			impact = cue("vImpact", 0.55),
		}),
		-- the knife slot's Katana: swings peak 0.06 / 0.09 s in (Animations.KNIFE_FEEL whooshPeak)
		Knife = set({
			fire = cue("Katana_fire", 0.75, { 0.97, 1.05 }),
			heavy = cue("Katana_heavy", 0.85, { 0.96, 1.0 }),
			hitBody = cue("Katana_hitBody", 0.85),
			hitWall = cue("Katana_hitWall", 0.85),
			draw = cue("Katana_draw", 0.7),
			drawWhoosh = cue("Katana_drawWhoosh", 0.45),
		}),
	} :: { [string]: { [string]: GunSounds.GunSound } }),
})
