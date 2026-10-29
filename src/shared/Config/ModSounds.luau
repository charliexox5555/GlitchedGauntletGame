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
	LagField = table.freeze({
		throw = cue(9120712091, 0.55), -- 3D
		open = cue(9120059083, 0.7), -- 3D
		hum = cue(9125636597, 0.25, 0.9, true), -- 3D, stand-in for ModLagLoop
		slowed = cue(9120059060, 0.55), -- enemy 2D, stand-in for ModLagSlowed
		expire = cue(9125640290, 0.5), -- 3D
	}),
	Ping = table.freeze({
		cast = cue(9125981410, 0.6), -- you, stand-in for ModPingCast
		pulse = cue(9125984762, 0.6), -- 3D, stand-in for ModPingPulse
		revealed = cue(9118777239, 0.6), -- enemy 2D, stand-in for ModPingRevealed
	}),
	PatchUp = table.freeze({
		raise = cue(127533251122014, 0.5), -- you
		start = cue(9126073001, 0.6), -- 3D
		hum = cue(9125986205, 0.25, 1, true), -- 3D while healing, stand-in for ModHealLoop
		done = cue(9119834423, 0.5), -- healer + target, stand-in for ModHealDone
	}),
	Overclock = table.freeze({
		on = cue(9119816546, 0.6), -- 3D, stand-in for ModOverclockOn
		hum = cue(9114344375, 0.22, 1, true), -- 3D on the gun, stand-in for ModOverclockLoop
		off = cue(9117869243, 0.45, 1.2), -- 3D, stand-in for ModOverclockOff
	}),
	Rollback = table.freeze({
		rewind = cue(9117880715, 0.6), -- you, stand-in for ModRollbackRewind
		snap = cue(9120425687, 0.55), -- 3D at both ends, stand-in for ModRollbackSnap
	}),
})
