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
}

local function cue(
	n: number,
	volume: number,
	pitch: number?,
	loop: boolean?,
	range: number?,
	cut: number?,
	start: number?
): Cue
	return table.freeze({
		id = "rbxassetid://" .. tostring(n),
		volume = volume,
		pitch = pitch,
		loop = loop,
		range = range,
		cut = cut,
		start = start,
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
	Packet = table.freeze({
		pin = cue(9114659833, 0.6), -- you, on raise
		throw = cue(9126229700, 0.55), -- 3D
		bounce = cue(9116617140, 0.5), -- 3D, first contact only
		fuse = cue(9118777437, 0.45), -- 3D, stand-in for ModPacketFuse
		danger = cue(9118777437, 0.6, 1.35), -- enemy 2D, stand-in for ModPacketDanger
		explode = cue(9119236749, 0.9), -- 3D
		explodeCrackle = cue(9125625388, 0.5), -- 3D layer
	}),
	Firewall = table.freeze({
		deploy = cue(9125981170, 0.6), -- 3D
		deploySlam = cue(9125819216, 0.5), -- 3D layer
		hum = cue(9114524164, 0.2, 1, true), -- 3D
		hit = cue(9119073329, 0.35), -- 3D, stand-in for ModWallHit
		broken = cue(9114589190, 0.8), -- 3D
		expire = cue(9117872887, 0.5), -- 3D
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
