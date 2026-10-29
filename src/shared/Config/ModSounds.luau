--!strict
-- Mod sounds. PROVISIONAL: every id here is an UNAUDITIONED pick from
-- vault/02 Art/Mod Audio.md (Roblox-licensed Creator Store audio: ProSound-
-- Effects, Audioscape or Roblox's own, so no upload is needed). The user
-- auditions them, then this file gets the approved ids.
--
-- Where Mod Audio.md's top pick is a synth cue (tools/audio/mod_sfx.py, not
-- uploaded: the user auditions the local reel art-source/audio/ModSfx/
-- _Reel.wav first), the listed library alternative stands in, marked
-- "stand-in for <slice>". Swap them for atlas slices once the synth set is
-- approved and uploaded.
--
-- Who hears what (Mod Audio.md): "you" = 2D for the caster, "3D" = at the
-- source for everyone in range, "enemy 2D" = a warning only the target hears.

export type Cue = {
	id: string,
	volume: number,
	pitch: number?, -- default 1
	loop: boolean?, -- a hum: played Looped and faded out
	range: number?, -- 3D: audible up to this many studs (louder up close)
	cut: number?, -- fade out and stop this many seconds after `start` (a long recording)
	start: number?, -- seconds into the file to start from (skip silence; a loop's steady part)
	loopEnd: number?, -- loops: loop only start..loopEnd (the file's steady part)
}

local function cue(
	n: number,
	volume: number,
	pitch: number?,
	loop: boolean?,
	range: number?,
	cut: number?,
	start: number?,
	loopEnd: number?
): Cue
	return table.freeze({
		id = "rbxassetid://" .. tostring(n),
		volume = volume,
		pitch = pitch,
		loop = loop,
		range = range,
		cut = cut,
		start = start,
		loopEnd = loopEnd,
	})
end

return table.freeze({
	-- Shared (you)
	Ready = cue(9126076030, 0.35, 1.1), -- stand-in for ModReady
	Denied = cue(17208353912, 0.4), -- stand-in for ModDenied
	Cancel = cue(15675032796, 0.35), -- stand-in for ModCancel
	-- ModRaise has no library stand-in: silent until the synth set lands.

	-- Dash hooks (vault/01 Design/Abilities/Dash.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned), listed in the Dash note; one id each.
	Dash = table.freeze({
		-- Dash_Whoosh: you. "Whoosh By Fast Airy Swooshing Whipping Thuds 1", 0.6 s
		whoosh = cue(9126229267, 0.6, 1.05),
		-- Dash_Crackle: you, a layer (Config/Mods DASH_FEEL.crackle).
		-- "Doppler Whooshes Crackly Airy Bursts 2", cut at 0.6 s
		crackle = cue(9114157098, 0.25, 1.15, nil, nil, 0.6),
		-- Dash_Land: you. "Cloth Movement 24", cut at 0.35 s
		land = cue(9113824230, 0.35, 1.1, nil, nil, 0.35),
		-- Dash_World: 3D for everyone else, ~40 studs. "Fast Pass By Airy Whooshes Windy 4"
		world = cue(9114373678, 0.8, 1, nil, 40),
	}),
	-- Updraft hooks (vault/01 Design/Abilities/Updraft.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned), listed in the Updraft note; one id each.
	Updraft = table.freeze({
		-- Updraft_Launch: you. "Giant Air Blast Low Bursts Pound Many Versions 5", 0.2–0.85 s
		launch = cue(9125577266, 0.7, 1.05, nil, nil, 0.65, 0.2),
		-- Updraft_Wind: you, a loop while rising. "Plasma Trails Constant Airy Whooshing Windy 1"
		wind = cue(9125742111, 0.35, 1, true, nil, nil, 2.8),
		-- Updraft_Land: you. "Body Fall Master 10", cut at 0.35 s
		land = cue(9113472118, 0.5, 1.1, nil, nil, 0.35),
		-- Updraft_World: 3D for everyone else, ~40 studs. "Giant Air Blast ... Many Versions 7"
		world = cue(9125577419, 1, 0.95, nil, 40, 1.1, 0.2),
	}),
	-- Molly hooks (vault/01 Design/Abilities/Molly.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned), listed in the Molly note; one id each.
	Molly = table.freeze({
		equip = cue(9114701864, 0.5, 1.1, nil, nil, 0.75), -- Molly_Equip: you. "Gun From Holster 1"
		pinPull = cue(9114659833, 0.65), -- Molly_PinPull: you. "Grenade Pull Pin 2"
		-- Molly_Throw: 3D at the hand. Overhand "Swish Med High End Sharp ...",
		-- underhand "Wood Swish Ruler Whoosh ..."
		throw = cue(9126013811, 0.5, 0.9, nil, 40, 0.4, 0.1),
		throwLob = cue(9126283272, 0.35, 0.85, nil, 40, nil, 0.18),
		-- Molly_Flight: 3D hiss on the canister. "Fireworks Sparks 2"
		flight = cue(9114447275, 0.4, 1, true, 35, nil, 1),
		-- Molly_Bounce: 3D clink off a wall. "Canister Drop Canister Impact 1"
		bounce = cue(9113704665, 0.6, 1, nil, 40, 0.45),
		-- Molly_Burst: 3D pop + whoomp, ~50 studs. "Fire Whoosh 2"
		burst = cue(9114442751, 0.9, 0.85, nil, 50),
		-- Molly_FireLoop: 3D, ~40 studs. "Fire Whoosh 1" (a kerosene fire loop)
		fireLoop = cue(9112780561, 0.5, 1, true, 40),
		-- Molly_SizzleOut: 3D. "Fireball Sizzle 2", its tail from 3.3 s
		sizzleOut = cue(9114428855, 0.6, 1, nil, 40, 1, 3.3),
		-- Molly_Burning: you, while burning. "Sizzle Short And Explosive Sear 13"
		burning = cue(9119166425, 0.35, 1, nil, nil, 0.35),
	}),
	-- Firewall hooks (vault/01 Design/Abilities/Firewall.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned), listed in the Firewall note; one id each.
	-- A deep roar, unlike the Molly's crackle, so the two fires sound apart.
	Firewall = table.freeze({
		-- Firewall_Ignite: you. "Fire Whoosh 15"
		ignite = cue(9114446852, 0.5, 1.1, nil, nil, nil, 0.05),
		-- Firewall_Cast: you / 3D at the caster. "Fire Whoosh 8", 0.38 s on
		cast = cue(9114441555, 0.7, 1, nil, 40, 1.1, 0.38),
		-- Firewall_Build: 3D, the wall racing on. "Fire Burst 2", 0.45 s on
		build = cue(9114430091, 0.6, 1.1, nil, 60, 1.2, 0.45),
		-- Firewall_Loop: 3D, ~50 studs. "Fire Burst 8", looping its steady 2.8–6.2 s
		loop = cue(9114429835, 0.2, 1, true, 50, nil, 2.8, 6.2),
		-- Firewall_PassThrough: you. "Kerosene Explosion Whooshing Poofs Crackling 6"
		passThrough = cue(9125616715, 0.6, 1.05),
		-- Firewall_End: 3D. "Fire Burst 8", its natural tail from 7 s
		ending = cue(9114429835, 0.3, 1, nil, 40, nil, 7),
	}),
	-- Frost hooks (vault/01 Design/Abilities/Frost.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned), listed in the Frost note; one id each.
	Frost = table.freeze({
		-- Frost_Equip: you. "Air Release Valve Scuba Tank 1", 0.15 s on
		equip = cue(9113074345, 0.35, 1.05, nil, nil, 0.9, 0.15),
		-- Frost_Throw: 3D at the hand. Javelin "Whoosh Heavy Punches 2",
		-- underhand "Dowel Swish Bamboo Thick 5"
		throw = cue(9120728883, 0.5, 0.95, nil, 40, 0.45, 0.08),
		throwLob = cue(9125495498, 0.35, 0.9, nil, 40, 0.3),
		-- Frost_Flight: 3D hiss on the canister. "Spray Paint Aerosol Air Hiss Constant 2"
		flight = cue(9119525650, 1.5, 1.1, true, 35, nil, 8.4, 13.2),
		-- Frost_Bounce: 3D. "Canister Drop Canister Impact 3"
		bounce = cue(9113704875, 0.6, 1.1, nil, 40, 0.5, 0.08),
		-- Frost_Burst: 3D, ~50 studs. "Fire Extinguisher 2" + an ice crackle
		-- layer "Ice Freeze Large Piece Crackles Liquid Nitrogen 3"
		burst = cue(9114437277, 0.9, 0.9, nil, 50),
		burstCrackle = cue(9125611419, 0.6, 1, nil, 50, nil, 0.2),
		-- Frost_HinderedLoop: you while hindered. "Barstow Wind Light Blustery Low Howl 1"
		hinderedLoop = cue(9113286782, 1, 0.95, true, nil, nil, 1.8, 6.6),
		-- Frost_Recover: you. "Ice Crackle Large Block Cracks 1", 0.1 s on
		recover = cue(9114858583, 0.5, 1.05, nil, nil, 0.65, 0.1),
	}),
	-- Recon hooks (vault/01 Design/Abilities/Recon.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned), listed in the Recon note; one id each.
	Recon = table.freeze({
		-- Recon_Equip: you. "Crossbow Movement Latches 13", 0.18 s on
		equip = cue(9114004483, 0.5, 1.1, nil, nil, 1.6, 0.18),
		-- Recon_Charge: you, a motor spinning up (looped at its peak, pitched by code).
		-- "Power Up Accelerating Motors 1"
		charge = cue(9117882920, 0.5, 1, true, nil, nil, 0.25, 2),
		-- Recon_BounceSelect: you. "Rotary Selector Switch Twisting 9"
		bounceSelect = cue(9118727210, 0.6, 1.1, nil, nil, 0.15, 0.2),
		-- Recon_Fire: you. "Grenade Launcher 2", one thoonk
		fire = cue(9114659666, 0.7, 1.1, nil, nil, 0.22),
		-- (the dart leaving the launcher, 3D for others: the same thoonk)
		throw = cue(9114659666, 0.6, 1.1, nil, 40, 0.22),
		throwLob = cue(9114659666, 0.6, 1.1, nil, 40, 0.22),
		-- Recon_Flight: 3D. "Arrow Pass Bys Zooming Past Distant Landing 7"
		flight = cue(9125363711, 0.6, 1.15, true, 40, nil, 0.8, 1.5),
		-- Recon_Bounce: 3D. "Ricochet Metal 5", a short tick
		bounce = cue(9118168962, 0.5, 1.3, nil, 40, 0.3, 0.14),
		-- Recon_Stick: 3D. "Arrow In And Hit 6"
		stick = cue(9113162981, 0.6, 0.95, nil, 40, nil, 0.5),
		-- Recon_Pulse: 3D, ~60 studs. "Spaceship Sonar Low And High Pitch Tonal Throbs 1"
		pulse = cue(9125981390, 0.9, 1, nil, 60, 1.5, 0.05),
		-- Recon_Revealed: the revealed player. "Car Alarm Chirp 1"
		revealed = cue(9113719080, 0.5, 1.05, nil, nil, 0.35, 0.14),
		-- Recon_Destroyed: 3D. "Static Zap Body Two Buzzy Impacts 2" + "Light Bulb 1"
		destroyed = cue(9119594871, 0.6, 1, nil, 40),
		destroyedBreak = cue(9116264240, 0.4, 1.2, nil, 40, 0.6, 0.08),
	}),
	-- Heal Orb hooks (vault/01 Design/Abilities/Heal Orb.md → Sound). Placeholders
	-- (ProSoundEffects, unauditioned; acoustic recordings picked over the
	-- library's designed tones), listed in the Heal Orb note; one id each.
	HealOrb = table.freeze({
		-- HealOrb_Form: you. "Sparkle Bell Tree Wind Chimes 1", 0.3 s on
		form = cue(9119447936, 0.4, 1.1, nil, nil, 2.5, 0.3),
		-- HealOrb_HeldLoop: you, quiet. "Wind Chimes 1" ("Delicate Tuned Ringing")
		heldLoop = cue(9120750051, 1.2, 1.15, true, nil, nil, 1.5, 22),
		-- HealOrb_Send: 2D for you. "Whoosh By Airy Whomping Humming Rumbling 6"
		send = cue(9120696273, 0.35, 1.15, nil, nil, nil, 0.15),
		-- HealOrb_Absorb: you. "Cloth Impact 1", the thump
		absorb = cue(9113821561, 0.35, 0.9, nil, nil, 0.85, 0.75),
		-- HealOrb_HealLoop: 3D on the healed player, ~30 studs. "Wind Chimes 2"
		healLoop = cue(9120750072, 2, 1, true, 30, nil, 1, 30.5),
		-- HealOrb_Complete: the healed player. "Door Chime Single Dings 5"
		complete = cue(9114133866, 0.35, 1.2, nil, nil, 2.3, 0.2),
		-- HealOrb_Refused: you. "Metal Thunk 3"
		refused = cue(9116895615, 0.35, 0.75),
	}),
	-- Stim hooks (vault/01 Design/Abilities/Stim.md → Sound). Placeholders
	-- (ProSoundEffects recordings, unauditioned), listed in the Stim note.
	Stim = table.freeze({
		-- Stim_Grab: you. "Cloth Rip Violent 14" (nylon rip, the velcro)
		grab = cue(9113835765, 0.45, 1.1, nil, nil, 0.4, 0.03),
		-- Stim_Drop: 3D. "Metal Case Impact 1", the slam
		drop = cue(9116539107, 0.7, 0.95, nil, 40, 0.3),
		-- Stim_Deploy: 3D, two layers. "Circuit Breaker 1" (the snap) ...
		deploy = cue(9113808115, 0.7, 1.1, nil, 50, 0.3, 0.14),
		-- ... and "Tesla Coil 3" (the crackle)
		deployCrackle = cue(9119992532, 0.4, 1, nil, 50, 1.1),
		-- Stim_ZoneLoop: 3D on the beacon, ~40 studs. "Tesla Coil 2"
		zoneLoop = cue(9119993024, 0.8, 1, true, 40, nil, 1, 19.5),
		-- (the zone dying out: the loop's tail, "Static Zap Mix Reverberant Bursts 3")
		zoneEnd = cue(9119595114, 0.3, 1.1, nil, 40, 0.8, 0.4),
		-- Stim_Gained: 2D for you. "Static Zap Blast 2" (the build into a zap)
		gained = cue(9119594571, 0.35, 1.1, nil, nil, 0.65, 0.7),
		-- Stim_Ending: 2D for you. "Static Zap Mix Reverberant Bursts 3", the fizzle
		ending = cue(9119595114, 0.35, 0.9, nil, nil, nil, 0.4),
	}),
	-- Recall hooks (vault/01 Design/Abilities/Recall.md → Sound). Placeholders
	-- (ProSoundEffects recordings, unauditioned), listed in the Recall note.
	Recall = table.freeze({
		-- Recall_Equip: you. "Metal Latches 3"
		equip = cue(9116722779, 0.45, 1.1, nil, nil, 0.5),
		-- Recall_Place: 3D. "Metal Box Set Down Metal Drawer 1"
		place = cue(9116527569, 0.75, 0.95, nil, 40, 0.35),
		-- Recall_Idle: 3D on the anchor, ~20 studs. "Transformer Hum 1 (Steady, Loop)"
		idle = cue(9112889082, 0.25, 1, true, 20, nil, 1, 35),
		-- Recall_PickUp: 3D. "Locking Wrench 1"
		pickUp = cue(9116320625, 0.45, 1.05, nil, 30, 0.3),
		-- Recall_OutOfRange: you. "Static Many Various Length Bursts 24"
		outOfRange = cue(9119583983, 0.35, 1, nil, nil, 0.45),
		-- Recall_WindUp: 3D, ~40 studs. "Power Up Accelerating Motors 3"
		windUp = cue(9117882661, 0.6, 1.25, nil, 40, 0.6, 0.8),
		-- Recall_Depart: 3D. "Spaceship Doors Air Release Some With Suck Hiss 2"
		depart = cue(9125975673, 0.6, 1.1, nil, 40, 0.8, 0.45),
		-- Recall_Arrive: 3D, ~50 studs. "Whoosh By Fast Airy Swooshing Whipping Thuds 2"
		arrive = cue(9126229255, 0.8, 0.95, nil, 50, 0.5, 0.05),
		-- Recall_Destroyed: 3D, two layers. "Lightning Flashes Quick Electrical Bursts 56" ...
		destroyed = cue(9116279560, 0.55, 1.1, nil, 40, 0.6),
		-- ... and "Glass Breaks 17"
		destroyedBreak = cue(9114593205, 0.4, 1.2, nil, 40, 0.4),
	}),
})
