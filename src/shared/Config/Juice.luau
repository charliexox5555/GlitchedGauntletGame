--!strict
-- Feel ("juice") numbers that aren't one gun's own (vault/01 Design/Gunplay.md
-- §5 Feedback, the 2026-11-04 polish pass). Competitive rule (LihFolk "Motion
-- Sensitivity and Camera Comfort"): feedback moves and rolls the camera a
-- little but never turns where you look, so it never moves your aim.

return table.freeze({
	-- What others see when someone fires (EffectsController): the gun kicks in
	-- the hand, back along the barrel and muzzle up. It is a spring that each
	-- shot gives a push (2026-11-12): one shot swells to `back` / `rise` and
	-- settles; held fire rides at about that with a small ripple, capped at
	-- `hold` times it. Never a restart per shot: the old kick snapped to full
	-- in one frame on every shot, and a second kick on the right arm (an IK
	-- that switched on and off) threw the gun 0.69 studs in a frame, which is
	-- what read as jitter. The left hand follows the gun (GripController).
	-- 2026-11-15: about 55% of what it was (0.16 + 0.2 / up studs, 6 + 8 / up
	-- degrees). The rest of the kick now goes through the body (BODY_KICK
	-- below), so the gun and the hands move together.
	WORLD_KICK = table.freeze({
		back = 0.09, -- studs, plus `backPerUp` x the gun's recoil.up
		backPerUp = 0.11,
		rise = 3.5, -- degrees muzzle up, plus `risePerUp` x recoil.up
		risePerUp = 4.5,
		frequency = 16, -- 1/s: how fast it swells and settles (peak about 1 / frequency s after the shot; 26 still stepped 0.17 studs in a frame)
		damping = 0.9, -- spring damping ratio (1 = no overshoot on the way home)
		hold = 1.5, -- cap, in single-shot kicks
	}),

	-- What others see when someone fires, part two (Util/BodyRecoil,
	-- 2026-11-15): the recoil goes through the arms and the chest. Seen from
	-- outside, only the gun moved in two still fists and the body did not
	-- react at all. Each hold has a recoil pose (Config/Animations RECOIL: at
	-- full weight the hands 0.3-0.5 studs back, the muzzle 12-17 degrees up,
	-- the chest 6-12 degrees back, the head still); a shot pushes a spring
	-- and the pose is blended over the hold by it. `weight` / `gun`: the
	-- share of the pose one shot swells to (0.28 on a rifle: hands 0.13 studs,
	-- chest about 3 degrees). Held fire rides at up to `hold` times that.
	-- Never restarted per shot (the jitter rule above).
	BODY_KICK = table.freeze({
		frequency = 20, -- 1/s: it peaks about 1 / frequency s after the shot
		hold = 1.5, -- cap, in single-shot kicks
		max = 0.95, -- ...and never more than this share of the pose
		default = 0.25,
		weight = table.freeze({
			Sidearm = 0.4,
			SMG = 0.16,
			Rifle = 0.28,
			MachineGun = 0.26,
			Shotgun = 0.8,
			Sniper = 0.9,
		} :: { [string]: number }),
		gun = table.freeze({
			Sheriff = 0.75, -- the revolver hits like a rifle round
			Shorty = 0.7,
			Ghost = 0.3,
			Spectre = 0.14,
			Guardian = 0.5,
			Marshal = 0.75,
		} :: { [string]: number }),
	}),

	-- Your own shot (owner 2026-11-08: "more umph, smooth, not glitchy"): a
	-- small FOV punch and roll per shot, scaled by the gun's recoil.up, plus the
	-- view shake (degrees = shakeBase + shakePerUp x up). Aimed: x `adsScale`.
	SHOT_FEEL = table.freeze({
		-- 2026-11-11 (owner: more aggressive): each about a third up.
		-- 2026-11-14 (owner's clips: the camera stays still on every shot; all
		-- the kick is in the gun, which now kicks harder, Config/Viewmodel
		-- SHOT_PUNCH / SHOT_SNAP; research: big kick on the viewmodel, small
		-- on the camera): FOV, roll and shake halved (were 0.6 / 2.8, 0.3 /
		-- 1.4, 0.08 / 0.18). The aim recoil itself is untouched.
		fovPerUp = 0.3, -- degrees wider per recoil.up
		fovMax = 1.4,
		fovTime = 0.11,
		rollPerUp = 0.15, -- degrees, random side
		rollMax = 0.7,
		rollTime = 0.14,
		shakeBase = 0.04,
		shakePerUp = 0.09,
		adsScale = 0.55,
		-- 2026-11-09: the automatics (recoil.up 0.22-0.42) count as at least
		-- this much here, so a spray has weight (the camera recoil itself is unchanged).
		upFloor = 0.65,
		-- 2026-11-13 (lane B, measured): the camera kick peaked 100-120 ms
		-- after the shot on every gun (eased in at 45/s) while the gun's
		-- punch peaked at 34 ms; Valorant's view jumps on the shot frame.
		-- Now 95% of each kick is in within about 25 ms.
		kickApplyRate = 120, -- 1/s (was 45)
		-- A look-only jolt per shot (CameraController.viewPunch): up this many
		-- degrees within `viewPunchRise` s, back over `time` s with a small dip
		-- past level. It never moves the aim (the recoil does that). Sized
		-- per class: a heavy gun's tap thumps the screen, an SMG just ticks
		-- it. Times `adsScale` while aimed.
		viewPunchRise = 0.018,
		viewPunch = table.freeze({
			-- 2026-11-14: trimmed to ~60% (the clips' cameras don't move; the
			-- heavy guns keep ~75% so a shot still thumps). Were 0.55, 0.22,
			-- 0.4, 0.35, 1.3, 1.6.
			Sidearm = { degrees = 0.33, time = 0.12 },
			SMG = { degrees = 0.13, time = 0.08 },
			Rifle = { degrees = 0.24, time = 0.1 },
			MachineGun = { degrees = 0.22, time = 0.1 },
			Shotgun = { degrees = 1.0, time = 0.17 },
			Sniper = { degrees = 1.2, time = 0.2 },
		} :: { [string]: { degrees: number, time: number } }),
		-- Guns that differ from their class.
		viewPunchGun = table.freeze({
			Sheriff = { degrees = 1.1, time = 0.16 }, -- the revolver hits like a rifle round
			Shorty = { degrees = 1, time = 0.15 },
			Guardian = { degrees = 0.8, time = 0.13 },
			Ghost = { degrees = 0.4, time = 0.1 }, -- suppressed
			Spectre = { degrees = 0.18, time = 0.08 }, -- suppressed
		} :: { [string]: { degrees: number, time: number } }),
	}),

	-- Tracers (Util/TracerFx).
	-- 2026-11-10 (owner: "much better tracers"): a white-hot core inside a
	-- wider glow, plus a faint trail from the muzzle that hangs and fades.
	-- 2026-11-15 (owner: "add tracers for some guns, like actual ones, to make
	-- it all more satisfying"). Measured in play: your own tracer never showed
	-- at all (a 0.085-stud streak is 1.4 px wide at 40 studs, it runs straight
	-- away from the eye, and it started inside the muzzle flash). Measured in
	-- the owner's clips (60 fps): a tracer is a short bright DART near the aim
	-- point, never a line from the muzzle: its head is on the hit point from
	-- the first frame and its tail shrinks into it over 2-4 frames; 5 px wide
	-- on a rifle or pistol, 8-10 on the SMGs, 10-13 on the revolver, a long
	-- tapered lance on the sniper; a near-white core in a pale yellow glow.
	-- So there are two looks now:
	--   your own shot   the dart (`dart*`): drawn a fixed size on SCREEN
	--                   whatever the range.
	--   everyone else's a streak that flies from their muzzle (`speed`,
	--                   `length`, `core`, `glow`: studs, about twice as wide
	--                   as before), with the trail it leaves (`trail*`).
	-- Each class has its own round (`class`, then `gun`).
	-- Transparencies 0 (solid) .. 1 (gone).
	TRACER = table.freeze({
		pool = 56,
		minTime = 0.05, -- close shots still show for a few frames
		maxTime = 0.2,
		minDistance = 4, -- shorter shots draw none
		-- Kept at 1: the place's Bloom starts at 2, and a spray overlaps several
		-- additive streaks on one line (2.5 whited out the whole screen).
		coreBrightness = 1,
		tailTaper = 0.2, -- a flying streak's tail width as a share of its head's
		wakeWhiten = 0.55, -- the trail's colour: the tracer colour this far toward white
		dartGlow = 3, -- the dart's glow width, times its core (2.4 until the colours)
		dartGlowFade = 0.1, -- the dart glow's transparency
		-- Colour (2026-11-15, owner: "nice tracers, with colour, for the ones
		-- with a muzzle flash and snipers"). Every gun that flashes has its
		-- class's colour: the warm family from yellow (light, fast guns) to
		-- orange-red (heavy ones), and the snipers their own violet, clear of
		-- both team colours (cyan allies, orange-red enemies). Suppressed guns
		-- have no flash and keep the pale round (Config/Weapons tracerColor).
		-- The glow and the trail are the colour; the core is white tinted
		-- `core` of the way to it, so the round still reads hot.
		color = table.freeze({
			core = 0.4,
			trail = 0.25, -- the trail: the colour this far toward white (wakeWhiten for pale rounds)
			class = table.freeze({
				Sidearm = Color3.fromHex("FFC94D"), -- gold
				SMG = Color3.fromHex("FFDC2E"), -- yellow
				Rifle = Color3.fromHex("FFAA2B"), -- amber
				MachineGun = Color3.fromHex("FF8A1F"), -- orange
				Shotgun = Color3.fromHex("FF6A2A"), -- orange-red
				Sniper = Color3.fromHex("B57BFF"), -- violet
			} :: { [string]: Color3 }),
			gun = table.freeze({
				Sheriff = Color3.fromHex("FF7A3D"), -- the revolver: hotter than a pistol
				Guardian = Color3.fromHex("FF962E"),
			} :: { [string]: Color3 }),
		}),
		dartBrightness = 1.6, -- the dart core's Brightness (under the Bloom threshold of 2)
		-- 2026-11-16 (owner: "their same tracers and bullet like shooting
		-- look"). RIVALS' own-shot tracer (Modules.TracerEffect, vault/03
		-- Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md): one
		-- tapered beam whose tail starts AT the muzzle and runs to the hit at a
		-- steady ~800 studs/s, its head at most 75 studs ahead of the tail
		-- (so a long shot visibly flies, a short one is a streak that
		-- collapses into the hit). `speed` > 0 uses that for every gun (the
		-- per-class dartStart / dartTime below are the old eased dart, used
		-- when speed is 0).
		dart = table.freeze({ speed = 800, reach = 75, start = 1.2 }),
		suppressedFade = 0.55, -- your own suppressed dart (enemies see no tracer at all)
		-- The round every gun starts from (a rifle's).
		style = table.freeze({
			-- Your own shot: the dart.
			-- px at 1080p, at its head. The beam's texture is brightest down its
			-- middle, so these are about twice the width that reads on screen
			-- (the clips: 5 px rifle and pistol, 8-10 SMG, 10-13 revolver).
			dartWidth = 10,
			dartTaper = 0.45, -- its tail's width as a share of that
			dartStart = 8, -- studs ahead of the muzzle its tail starts (nearer = longer on screen)
			dartTime = 0.044, -- s: its tail gets e times further away every this long (bigger = it lasts longer)
			-- Everyone else's: the flying streak and its trail.
			-- RIVALS (2026-11-16): others' rounds are a 15-stud dart at 800 studs/s.
			speed = 800, -- studs/s (1300 until 2026-11-15, 950 until 2026-11-16)
			length = 15, -- studs of streak (at most 60% of the shot)
			core = 0.16, -- the streak's white core, width (0.085 until 2026-11-15)
			glow = 0.5, -- the coloured glow around it, width
			glowFade = 0.35, -- the glow's transparency
			trailWidth = 0.12,
			trail = 0.55, -- the trail's transparency while the round flies (1 = none)
			trailFade = 0.22, -- seconds it takes to dissolve once the round arrives
			trailGrow = 0.8, -- how much wider it gets as it goes (0.8 = 1.8x)
		}),
		class = table.freeze({
			Sidearm = {
				dartStart = 11,
				dartTime = 0.032,
				length = 12,
				core = 0.13,
				glow = 0.42,
				trailWidth = 0.1,
				trailFade = 0.18,
			},
			SMG = {
				dartWidth = 15,
				dartStart = 6.5,
				dartTime = 0.04,
				speed = 1050,
				length = 11,
				core = 0.12,
				glow = 0.36,
				trailWidth = 0.09,
				trail = 0.68,
				trailFade = 0.14,
			},
			MachineGun = {
				dartWidth = 14,
				dartStart = 7,
				length = 21,
				core = 0.2,
				glow = 0.6,
				trailWidth = 0.14,
				trailFade = 0.2,
			},
			-- Pellets: a spray of short darts, hardly any trail.
			Shotgun = {
				dartWidth = 7,
				dartStart = 9,
				dartTime = 0.036,
				speed = 820,
				length = 7,
				core = 0.1,
				glow = 0.3,
				trailWidth = 0.07,
				trail = 0.8,
				trailFade = 0.12,
			},
			-- A lance with a thin tail, and a vapour trail that hangs and spreads.
			Sniper = {
				dartWidth = 20,
				dartTaper = 0.22,
				dartStart = 2.8,
				dartTime = 0.058,
				speed = 1500,
				length = 32,
				core = 0.3,
				glow = 0.95,
				glowFade = 0.2,
				trailWidth = 0.15,
				trail = 0.45,
				trailFade = 0.6,
				trailGrow = 1.5,
			},
		} :: { [string]: { [string]: number } }),
		gun = table.freeze({
			-- The revolver and the semi-auto rifle hit like a rifle round.
			Sheriff = {
				dartWidth = 24,
				dartStart = 5,
				dartTime = 0.036,
				length = 19,
				core = 0.24,
				glow = 0.7,
				trailWidth = 0.15,
				trail = 0.45,
				trailFade = 0.3,
				trailGrow = 1.2,
			},
			Guardian = {
				dartWidth = 14,
				dartStart = 6,
				length = 22,
				core = 0.22,
				glow = 0.66,
				trailWidth = 0.14,
				trailFade = 0.28,
				trailGrow = 1.1,
			},
			Spectre = { dartWidth = 19, dartStart = 9 }, -- the large SMG: a fatter, shorter dart
		} :: { [string]: { [string]: number } }),
	}),

	-- Getting hit: a flinch (camera offset + roll away from the shot, scaled by
	-- damage) and a red pulse at the screen edges. Never touches the look.
	FLINCH = table.freeze({
		offset = 0.08, -- studs at `fullDamage`
		roll = 1.2, -- degrees at `fullDamage`
		fullDamage = 40,
		-- 2026-11-15 (RIVALS pass: its hurt vignette starts at 0.5 + 0.5 x the
		-- share of your health the hit took and fades in ~0.4 s): the edge
		-- pulse peaks at pulse + pulsePerShare x (damage / health before the
		-- hit), at most pulseMax.
		pulse = 0.16,
		pulsePerShare = 0.6,
		pulseMax = 0.55,
		pulseTime = 0.4, -- seconds it fades over
		-- The low-HP vignette fades in below `lowFrom` of max health and is
		-- full at `lowFull` (RIVALS: from 50 %).
		lowFrom = 0.5,
		lowFull = 0.1,
	}),

	-- Slide: a quick FOV punch on top of the slide's FOV (the roll is
	-- Config/Movement SLIDE_CAMERA_TILT), dust at the feet that everyone sees,
	-- and a scrape. Sounds: PROVISIONAL ProSoundEffects picks (licensed), audition.
	SLIDE = table.freeze({
		fovPunch = 6, -- degrees, eases out over `punchTime`
		punchTime = 0.35,
		-- 2026-11-15 (RIVALS pass): the slide roll rides an underdamped spring
		-- (RIVALS: damper 0.5, speed 15): it swings past the tilt by ~16 %
		-- and settles, instead of an even ease. Applies to CameraController.setRoll.
		rollSpeed = 15,
		rollDamping = 0.5,
		lunge = 0.3, -- studs the view leads into the slide, then settles (2026-11-10)
		lungeTime = 0.45,
		streaks = 0.45, -- the Dash's wind strokes at this strength (fewer, shorter, fainter)
		dustRate = 60, -- particles/s while sliding fast
		dustMinSpeed = 13, -- studs/s below which the dust stops
		-- "Baseball Runner Slide On Dirt Into Home Plate 4": its first 0.8 s.
		-- A real shoe skid (CC0, atlas; 2026-11-05). Was ProSoundEffects 9125380604 (cut 0.8).
		-- 2026-11-14 (owner: the skid was "a squeech sound ... a little whoosh on
		-- the slide"): soft cloth swishes (gun atlas). The CC0 skid is
		-- "gun:slide_skid", the old one "atlas:SlideStart".
		sound = { id = "gun:knife_whoosh_cloth_heavy", volume = 0.5, cut = 0.8, range = 70 },
	}),

	-- Jumping: a soft cloth sound as you leave the ground.
	JUMP = table.freeze({
		minRise = 8, -- studs/s up that counts as a jump (not a step or a bump)
		-- "Cloth Flap 2" (ProSoundEffects), higher and quieter. PROVISIONAL, audition.
		-- 2026-11-14: none of our own: Roblox's default jump plays (Config/Audio
		-- ROBLOX_CHARACTER_SOUNDS). Ours was "gun:jump" (the pack's cloth flicks).
		sound = { id = "", volume = 0.35, pitch = 1 },
	}),

	-- Landing: the camera dips by how fast you fell (k = fall speed / `fullFall`,
	-- dip scales with k^2), and a thud for falls past `soundFrom`.
	LAND = table.freeze({
		dip = 0.55, -- studs at k = 1
		fullFall = 70, -- studs/s
		minFall = 18, -- studs/s below which nothing happens
		soundFrom = 24, -- studs/s
		-- "Cloth Flap 2" (ProSoundEffects, a muffled whump). PROVISIONAL, audition.
		-- 2026-11-14: none of our own: Roblox's default landing plays (Config/Audio
		-- ROBLOX_CHARACTER_SOUNDS). Ours were "rbxland:Land" and "gun:land".
		sound = { id = "", volume = 0.5 },
	}),

	-- The death look (DeathFxController): the body is hidden and a still copy
	-- of it falls over, rests, then fades with a dust puff. The downed player's
	-- own screen drains of colour.
	-- The sudden-death wall (Controllers/ZoneController, vault/05 Production/
	-- Match Structure Revamp.md): a ring of Beams with the glitch-storm
	-- texture, one texture repeat per segment (`tile` studs wide each), and a
	-- faster glitch layer on top. Outside the circle the screen tints and a
	-- warning ticks.
	ZONE = table.freeze({
		color = Color3.fromHex("CD3CFF"),
		edgeColor = Color3.fromHex("FF72CD"),
		glitchColor = Color3.fromHex("C57AFF"),
		below = 30, -- studs the wall reaches under the circle's centre
		height = 320, -- extends 290 studs above the zone centre
		fallbackSegments = 40,
		sparkEmitters = 5,
		sparkDistance = 38,
		tint = Color3.fromHex("F2DDFF"), -- the screen while you're outside
		tintTime = 0.25,
		warnEvery = 0.55, -- seconds between warning ticks outside
	}),

	-- Death camera and first-person spectating (Controllers/SpectateController,
	-- vault/05 Production/Match Structure Revamp.md phase B).
	SPECTATE = table.freeze({
		pullTime = 1.2, -- seconds the camera takes to leave your head
		holdTime = 0.7, -- then it watches the body before switching to a teammate
		pullBack = 7, -- studs behind where you fell
		pullUp = 5, -- studs above
		-- Their eye, built like your own camera (Roblox's first-person camera
		-- measured in Studio 2026-11-16: 1.5 studs over the HumanoidRootPart,
		-- 0.5 behind along the look), minus the crouch / slide drop
		-- (shared/CameraDrop on their MoveState). Not the animated Head part:
		-- that bobbed with the walk cycle and lagged a stud at a run.
		eyeHeight = 1.5,
		eyeBack = 0.5,
		aimRate = 18, -- 1/s: one ease for their yaw and pitch (smooths the steps between updates)
		-- Their aim, sent by their client (WeaponController, the Aim remote) and
		-- published for bots (Bots/Brain). Combat.RATE.Aim must allow aimSendHz.
		aimSendHz = 30, -- at most this often...
		aimDeadband = 0.004, -- ...when the pitch moved more than this (radians)
		aimSettle = 0.1, -- seconds after the aim stops: one more send so the last value lands
		aimKeepalive = 0.5, -- seconds: a resend even with nothing new (a dropped packet heals)
		-- A bot's gun look (`AimGunYaw` / `AimGunPitch`: its aim plus aim error
		-- and recoil), published only while someone spectates it (Bots/Spectated).
		botAimSendHz = 30,
		botAimDeadband = 0.002, -- radians, on yaw or pitch
		-- A bot's intended pitch (`AimPitch`): gameplay input too (Target.lookOf:
		-- bot Mods' aim, Flash), always published, at the old pre-spectate rate.
		botPitchSendHz = 10,
		botPitchDeadband = 0.03, -- radians
		-- The look stream (Services/LookStream, plan B): every fighter's aim on
		-- one server-time line, drawn a little in the past and interpolated, so
		-- the watched view turns as smoothly as theirs did.
		lookHz = 30, -- samples a second (players: WeaponController; bots: Brain)
		lookRingSeconds = 6, -- how much the server keeps per fighter (the replay reads it)
		lookMaxAge = 1, -- seconds: an older sample is dropped by the server
		lookMaxAhead = 0.25, -- seconds: a sample stamped further ahead is dropped
		lookJitter = 0.07, -- seconds of buffer on top of the measured latency (about two samples)
		lookDelayMin = 0.05, -- seconds: never draw closer to "now" than this
		lookDelayMax = 0.35, -- seconds: never further behind than this
		lookExtrapolate = 0.05, -- seconds the view may run past the newest sample, then it holds
		lookStale = 0.4, -- seconds without a sample: back to the replicated look (Fighters.lookOf)
		relayHitVolume = 0.7, -- the watched fighter's hit sounds, against your own (SpectateFeed)
		switchDelay = 1, -- seconds on a fighter who went down before moving on (only with nobody to cut to)
		-- The fighter you watch goes down: you cut to the next one at once.
		-- With nobody left to cut to, their eye sinks `downDrop` studs, tips to
		-- `downPitch` and rolls `downRoll` over `downTime` seconds (a fall).
		downTime = 0.45,
		downDrop = 2.2,
		downPitch = -0.5,
		downRoll = 0.4,
		fadeTime = 0.12, -- black blink when the view jumps to someone else
	}),

	DEATH = table.freeze({
		buckle = 0.28, -- seconds the knees buckle (the Death clip) before it tips
		fall = 0.45, -- seconds to hit the floor
		tilt = 82, -- degrees it tips over
		rest = 1.4, -- seconds it lies there
		fade = 0.5, -- seconds to fade out
		dust = 18, -- particles in the puff
		saturation = -0.85, -- your screen while downed
		brightness = -0.08,
		tint = Color3.fromRGB(255, 220, 220),
		screenFade = 0.4, -- seconds
	}),
})
