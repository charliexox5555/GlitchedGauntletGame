--!strict
-- All Mod (ability) data (vault/01 Design/Mods.md, numbers are starting points
-- for playtesting). Code reads stats only through Mods.stats(id, level), which
-- resolves L1 → A2 → A3 (or B2 → B3, G2 → G3): each level lists only what
-- changes. Behaviour switches (e.g. `behaviour = "Slam"`) are how later
-- levels change what a Mod does; each Mod module dispatches on them. The
-- upgrade paths: vault/01 Design/Abilities/Upgrade Paths.md (2026-11-03).
--
-- `slot`: every ability lives in one fixed slot (1 = Q, 2 = E, 3 = T for now;
-- keys become rebindable later). The draft only fills a slot with its own
-- abilities. `paths`: the names of path A, path B and the glitch path.
--
-- Charges (vault/01 Design/Abilities/00 Abilities.md → Charges): every L1 has
-- `charges`, how many uses a round starts with (RoundService refills them:
-- ModService.refillCharges), and `cooldown`, the seconds one spent charge
-- takes to come back; 0 = no recharge, it's gone until the next round. The
-- dev panel's "Test mode: unlimited charges" makes casting free.
--
-- Shared by the server (authoritative) and the client (HUD, previews):
-- nothing secret here, and the server never trusts a client-sent number.

local Types = require(script.Parent.Parent.Mods.Types)

type ModDef = Types.ModDef

local defs: { [string]: ModDef } = {
	Dash = {
		id = "Dash",
		name = "Dash",
		role = "Mobility",
		slot = 2, -- E (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Long Dash", B = "Ghost", G = "Desync" },
		block = "Dash",
		activation = "Instant",
		authority = "Simulation",
		icon = "rbxassetid://140468016168978", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "»",
		hint = {},
		levels = {
			L1 = {
				note = "Dash 16 studs in your move direction",
				cooldown = 0, -- Dash: 1 per round, no recharge
				charges = 1,
				-- 16 (was 12; owner 2026-11-15: a quick dodge that earns its slot
				-- beside sliding). Trial 12 / 16 / 18 at the same 0.15 s: the gun
				-- is back at the same moment for all three (+0.23 s), 18 mostly
				-- bought more wall stops in a lane (vault/05 Production/Ability
				-- Rework 2026-11-15.md → Dash trial). Open to the owner's feel check.
				distance = 16,
				duration = 0.15, -- seconds the dash lasts
				exitSpeed = 22, -- horizontal speed kept when the dash ends
				radius = 1.4, -- spherecast radius: stops short of walls
				fireDelay = 0.1, -- the gun is down while dashing and this long after
				focusWindow = 0.6, -- Dash Focus: the first shot this soon after has no move/air spread
			},
			-- Long Dash keeps its +6 steps over the new L1.
			A2 = { note = "Dash 22 studs instead of 16, just as fast", distance = 22 },
			A3 = { note = "Dash 28 studs, just as fast, and 2 charges", distance = 28, charges = 2 },
			B2 = {
				note = "Bullets pass through you for 0.35 s from the press",
				card = "BULLETPROOF FOR 0.35 S",
				dodgeWindow = 0.35, -- seconds from the press: every hit on you is blocked
				ghostAlpha = 0.55, -- how see-through everyone sees you meanwhile (0..1)
			},
			B3 = {
				note = "Vanish for 1 s after a dash (a shimmer up close), 2 charges",
				cloakAfter = 1, -- seconds after the dash ends
				cloakShimmer = 10, -- enemies this close still see a shimmer
				cloakAlpha = 0.95, -- how see-through enemies further away see you
				cloakShimmerAlpha = 0.75, -- ... and close enemies (it flickers around this)
				cloakAllyAlpha = 0.5, -- ... and your team
				charges = 2,
			},
			G2 = {
				note = "Leave a decoy that keeps running for 1.5 s; no shots for 0.3 s",
				card = "A DECOY RUNS ON FOR 1.5 S",
				behaviour = "Desync",
				decoyTime = 1.5, -- seconds the decoy runs before it glitches out
				decoyMinSpeed = 16, -- its run speed: yours before the dash, kept in this range
				decoyMaxSpeed = 22,
				fireDelay = 0.3,
			},
			G3 = {
				note = "The decoy fires fake shots, and you vanish while it runs",
				card = "DECOY SHOOTS  ·  YOU VANISH",
				decoyFires = true,
				decoyShotRange = 150, -- it shoots at the nearest enemy this close, in sight
				decoyShotDelay = 0.2, -- seconds after the dash before the first fake shot
				decoyShotMinGap = 0.12, -- never faster than this, whatever the gun
				decoyShotSpread = 2.5, -- degrees: the fake shots miss a little
				decoyCloak = true, -- you're invisible for decoyTime from the press
				cloakShimmer = 10,
				cloakAlpha = 0.95,
				cloakShimmerAlpha = 0.75,
				cloakAllyAlpha = 0.5,
			},
		},
	},
	Updraft = {
		id = "Updraft",
		name = "Updraft",
		role = "Mobility",
		slot = 1, -- Q (vault/01 Design/Abilities/Upgrade Paths.md)
		-- Upgrade Paths.md calls them Height / Charges / Slam.
		paths = { A = "High Rise", B = "Second Wind", G = "Crash Down" },
		block = "Launch",
		activation = "Instant",
		authority = "Simulation",
		icon = "rbxassetid://109401404845816", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "^",
		hint = {},
		levels = {
			L1 = {
				note = "Launch straight up ~14 studs (works mid-air)",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				peak = 14, -- studs above where you used it (speed from Workspace.Gravity)
				maxCarry = 24, -- most running speed carried into the air (a slide-jump's)
				gunDown = 0.35, -- seconds the gun is down after the launch (the cost, not height-scaled)
			},
			A2 = { note = "High Rise: launch 50% higher, about 21 studs", peak = 21 },
			A3 = { note = "High Rise: launch twice as high, about 28 studs", peak = 28 },
			B2 = { note = "Second Wind: 2 Updrafts every round", charges = 2 },
			B3 = { note = "Second Wind: 3 Updrafts every round", charges = 3 },
			G2 = {
				-- Owner 2026-11-15: a second press of the Updraft key, not Crouch.
				note = "Crash Down: press Updraft again mid-air to slam, 30 damage within 8 studs",
				card = "PRESS AGAIN TO SLAM  ·  30 DAMAGE IN 8 STUDS",
				behaviour = "Slam",
				slamDamage = 30, -- enemies in sight of the landing (no self or team damage)
				slamRadius = 8, -- studs from your root where you land (10 is the trial value)
				slamSpeed = 90, -- studs/s down
				slamCarry = 16, -- most horizontal studs/s the dive keeps (walk speed: a nudge, not a glide)
				slamArm = 0.15, -- seconds after the launch before a slam starts (a press waits)
			},
			G3 = {
				note = "Crash Down: 45 damage, Hinders for 1 s, 2 Updrafts a round",
				slamDamage = 45,
				slamHinder = 1, -- seconds of Hinder on everyone it hits
				charges = 2,
			},
		},
	},
	Molly = {
		id = "Molly",
		name = "Molly",
		role = "Damage",
		slot = 2, -- E (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Recharge", B = "Bigger Fire", G = "Fork Fire" },
		block = "Projectile",
		activation = "HeldThrow",
		authority = "Server",
		icon = "rbxassetid://115604306101761", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "●",
		hint = { primary = "Throw", alt = "Lob" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Incendiary: a 9-stud fire patch for 4 s, 45 damage/s",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				throwSpeed = 88, -- LMB, overhand: ~82 studs at most on flat ground (was 72: ~54)
				lobSpeed = 24, -- RMB, underhand: a few studs in front of you
				throwLift = 0.12, -- added to the aim's up component before scaling
				lobLift = 0.3,
				gravity = 100, -- studs/s², lighter than the world's for readable arcs
				bounces = 4, -- wall bounces (it bursts on the first floor it touches)
				restitution = 0.45, -- speed kept on a wall bounce
				friction = 0.7, -- along-surface speed kept on a wall bounce
				size = 0.3, -- projectile radius
				dropTime = 1.3, -- seconds in the air before it drops straight down (was 0.9)
				maxFlight = 4, -- seconds simulated; still flying then = no fire
				radius = 9, -- fire patch (studs)
				height = 5, -- studs above the floor the fire reaches
				duration = 4,
				dps = 45, -- to enemies; FRIENDLY_FIRE of it to you and your team
				tick = 0.25,
			},
			-- Recharge / Bigger Fire are numbers only (Mods/Charges, Util/MollyFx
			-- scales the fire's look and sound to `radius` and `duration`).
			A2 = { note = "Recharge: a used Molly comes back after 15 s", cooldown = 15 },
			A3 = { note = "Recharge: your Molly comes back after only 10 s", cooldown = 10 },
			B2 = { note = "Bigger Fire: the fire patch grows to 12 studs", radius = 12 },
			B3 = {
				note = "Bigger Fire: a 14-stud patch that burns for 6 s",
				radius = 14,
				duration = 6,
			},
			-- Fork Fire (Mods/Molly → Fork): no big fire; where the canister comes
			-- to rest it splits into `forks` bomblets (server RNG) that scatter,
			-- hop off the floor and burst into small fires (same dps / duration).
			G2 = {
				note = "Fork Fire: splits into 3 bouncing firebombs; their fire burns you too",
				card = "SPLITS INTO 3 FIREBOMBS",
				behaviour = "Fork",
				forks = 3,
				forkRadius = 5,
				forkSpeed = 30, -- studs/s the bomblets scatter at
				forkSpeedJitter = 0.25, -- each one's speed is ± this share of forkSpeed
				forkLift = 0.8, -- up component of the scatter (before scaling), ± forkLiftJitter
				forkLiftJitter = 0.3,
				forkHops = 1, -- floor bounces before a bomblet bursts
				forkBounces = 2, -- wall bounces
				forkSize = 0.25, -- bomblet radius
				forkFlight = 2.5, -- seconds simulated; still flying then = no fire
				selfFire = 1, -- share of the damage to you and your team
			},
			-- `hops`: the canister skips off the floor this many times before it
			-- splits (the "bounces once more"); `bounces` 5 is one more wall bounce.
			G3 = {
				note = "Fork Fire: 5 firebombs, and it bounces once more before splitting",
				card = "FIREBOMBS  3 → 5",
				forks = 5,
				bounces = 5,
				hops = 1,
			},
		},
	},
	Firewall = {
		id = "Firewall",
		name = "Firewall",
		role = "Control",
		slot = 3, -- T (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Short Wall", B = "Long Wall", G = "Frost Wall" },
		block = "Wall",
		activation = "HeldSteer",
		authority = "Server",
		icon = "rbxassetid://75501045250826", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "▮",
		hint = { primary = "Hold: steer", alt = "Straight" },
		quickCast = "Alt",
		levels = {
			L1 = {
				note = "Steerable fire wall, 40 x 10: blocks vision, 30 damage/s",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				speed = 40, -- studs/s it builds forward
				maxLength = 40,
				turnRate = 110, -- degrees/s it may curve while you steer
				height = 10, -- fully blocks sight
				thickness = 1.5,
				segment = 4, -- studs per wall piece (the server's parts)
				duration = 6, -- seconds after it finishes building
				dps = 30, -- to enemies; FRIENDLY_FIRE of it to your team; none to you
				tick = 0.25,
			},
			A2 = {
				note = "Short Wall: a 20-stud wall that recharges after 15 s",
				cooldown = 15,
				maxLength = 20,
			},
			A3 = { note = "Short Wall: recharges after just 6 s", cooldown = 6 },
			B2 = { note = "Long Wall: a 60-stud wall (50% longer)", maxLength = 60 },
			B3 = { note = "Long Wall: 2 walls per round", charges = 2 },
			-- Ice instead of fire (Services/ModWalls, Util/FrostWallFx).
			G2 = {
				note = "Frost Wall: a 60-stud ice wall; no damage, Hinders enemies 1.5 s",
				behaviour = "Frost",
				hinder = 1.5, -- seconds of Hinder (Config/StatusEffects), refreshed while they touch it
				maxLength = 60,
			},
			G3 = { note = "Frost Wall: 2 ice walls per round", charges = 2 },
		},
	},
	Frost = {
		id = "Frost",
		name = "Frost",
		role = "Control",
		slot = 3, -- T (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Stockpile", B = "Big Burst", G = "Freeze Frame" },
		block = "Projectile",
		activation = "HeldThrow",
		authority = "Server",
		icon = "rbxassetid://104088410327059", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "❄",
		hint = { primary = "Throw", alt = "Lob" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Frost burst: everyone within 10 studs is Hindered for 3 s",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				throwSpeed = 108, -- LMB, javelin: flatter and faster than the Molly, ~115 studs at most (was 92: ~74)
				lobSpeed = 24, -- RMB, underhand
				throwLift = 0.06,
				lobLift = 0.3,
				gravity = 100,
				bounces = 4, -- wall bounces (it bursts on the first floor it touches)
				restitution = 0.45,
				friction = 0.7,
				size = 0.3,
				dropTime = 1.3, -- seconds in the air before it drops straight down (was 0.9)
				maxFlight = 4, -- still flying then: no burst
				radius = 10,
				hinder = 3, -- seconds of Hinder (Config/StatusEffects)
			},
			A2 = { note = "Stockpile: 2 canisters a round", charges = 2 },
			A3 = { note = "Stockpile: 3 canisters a round", charges = 3 },
			B2 = { note = "Big Burst: 14-stud burst, double the area", radius = 14 },
			B3 = { note = "Big Burst: 17-stud burst, triple the area", radius = 17 },
			G2 = {
				note = "Freeze Frame: frozen solid 1.5 s, can't move or shoot. Hits you too",
				card = "FROZEN SOLID 1.5 S  ·  HITS YOU TOO",
				behaviour = "Freeze", -- Frozen (Config/StatusEffects) instead of Hinder
				freeze = 1.5, -- seconds frozen
			},
			G3 = { note = "Freeze Frame: frozen solid for 2.5 s", freeze = 2.5 },
		},
	},
	Recon = {
		id = "Recon",
		name = "Recon",
		role = "Info",
		slot = 2, -- E (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Recharge", B = "More Pulses", G = "Ping Spike" },
		block = "Reveal",
		activation = "HeldCharge",
		authority = "Server",
		icon = "rbxassetid://72076959811852", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "◉",
		hint = { primary = "Hold: charge", alt = "Bounces" },
		levels = {
			L1 = {
				note = "Recon dart: sticks, pulses twice, reveals enemies it sees (40 studs)",
				cooldown = 30, -- 1 charge, back 30 s after use
				charges = 1,
				chargeTime = 1, -- seconds of LMB to full power
				minSpeed = 45, -- a tap
				maxSpeed = 130, -- full charge
				lift = 0.04, -- added to the aim's up component (a slight arc)
				gravity = 45,
				size = 0.15,
				restitution = 0.85, -- a dart keeps most of its speed off a wall
				friction = 0.9,
				maxBounces = 2,
				maxFlight = 3,
				pulseDelay = 0.5, -- first pulse after sticking
				pulseGap = 1.5,
				pulses = 2,
				radius = 40, -- reveal range (enemies the dart can see)
				reveal = 2, -- seconds the outline lasts
				hp = 1, -- any bullet destroys it
			},
			-- Upgrades (Upgrade Paths.md → 6. Recon; built in Mods/Recon and
			-- client Util/UpgradeFx/Recon). The dart lives pulseDelay +
			-- pulseGap * (pulses - 1) + 0.6 s, so More Pulses keeps it up longer.
			A2 = { note = "Recharge: the dart comes back 20 s after use", cooldown = 20 },
			A3 = { note = "Recharge: the dart comes back 12 s after use", cooldown = 12 },
			B2 = { note = "More Pulses: the dart pulses 3 times, 1.5 s apart", pulses = 3 },
			B3 = { note = "More Pulses: the dart pulses 5 times, 1.5 s apart", pulses = 5 },
			-- Spike: one pulse `pulseDelay` after sticking, every enemy within
			-- `radius`, no line-of-sight check (it can still be shot down first).
			G2 = {
				note = "Ping Spike: one pulse finds every enemy in 60 studs through walls, 4 s",
				behaviour = "Spike",
				radius = 60,
				reveal = 4,
				pulses = 1,
			},
			-- The caster's damage (guns and Mods) to enemies it revealed, while
			-- the reveal lasts.
			G3 = {
				note = "Ping Spike: you deal +20% damage to enemies it revealed (4 s)",
				card = "+20% DAMAGE TO REVEALED ENEMIES",
				bonusDamage = 0.2,
			},
		},
	},
	HealOrb = {
		id = "HealOrb",
		name = "Heal Orb",
		role = "Sustain",
		slot = 2, -- E (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Charges", B = "Long Heal", G = "Barrier" },
		block = "Target",
		activation = "HeldTarget",
		authority = "Server",
		icon = "rbxassetid://133509365622988", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "+",
		hint = { primary = "Heal ally", alt = "Heal self" },
		quickCast = "Alt",
		levels = {
			L1 = {
				note = "Heal orb: an ally 60 HP over 3 s, or yourself 30",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				heal = 60, -- to an ally
				selfHeal = 30, -- to yourself (half)
				duration = 3, -- seconds the heal runs (it keeps going under fire)
				range = 30,
				aimAngle = 12, -- degrees from the crosshair an ally may be
			},
			A2 = { note = "Charges: 2 orbs a round", charges = 2 },
			A3 = { note = "Charges: 3 orbs a round", charges = 3 },
			B2 = {
				note = "Long Heal: twice as long (6 s): an ally 120, yourself 60",
				duration = 6,
				heal = 120,
				selfHeal = 60,
			},
			B3 = {
				note = "Long Heal: three times as long (9 s): an ally 180, yourself 90",
				duration = 9,
				heal = 180,
				selfHeal = 90,
			},
			G2 = {
				-- No heal: a hex bubble on the target that takes whole enemy hits
				-- (Mods/HealOrb). Lasts until used up, death or the next round.
				note = "Barrier: no heal; a hex bubble blocks the target's next enemy hit",
				card = "BLOCKS THE NEXT HIT  ·  NO HEAL",
				behaviour = "Barrier",
				barrierHits = 1,
			},
			G3 = {
				note = "Barrier: the bubble blocks the next 2 enemy hits",
				card = "HITS BLOCKED  1 → 2",
				barrierHits = 2,
			},
		},
	},
	Stim = {
		id = "Stim",
		name = "Stim",
		role = "Team buff",
		slot = 1, -- Q (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Quick Stims", B = "Strong Stim", G = "Heal Zone" },
		block = "Zone",
		activation = "Instant",
		authority = "Server",
		icon = "rbxassetid://138755716535424", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "⚡",
		hint = {},
		useKind = "Lob", -- third person: the underhand toss
		levels = {
			L1 = {
				note = "Toss a stim beacon just ahead: you and your team in it fire and move 15% faster, swap and reload faster",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				radius = 10, -- studs (the zone, around the beacon)
				height = 8, -- studs up from the floor that still count
				duration = 8, -- seconds the zone lasts
				linger = 4, -- seconds you stay Stimmed after leaving it
				tossDistance = 8, -- studs ahead it lands (short of a wall); 5 until 2026-11-16
				tossRelease = 0.3, -- seconds from the press to leaving the hand (StimToss)
				tossTime = 0.4, -- seconds in the air
				deployTime = 0.25, -- seconds from landing to the zone switching on
				tick = 0.1, -- seconds between zone checks
				-- The status the zone gives (Config/StatusEffects); path B
				-- swaps it for "StimStrong" (one or the other, never both).
				status = "Stimmed",
			},
			A2 = {
				note = "Quick Stims: 2 charges; each zone lasts 4 s, 2 s after you leave",
				charges = 2,
				duration = 4,
				linger = 2,
			},
			A3 = { note = "Quick Stims: 4 charges of the 4 s zone", charges = 4 },
			B2 = {
				note = "Strong Stim: +25% speed and fire rate, much faster reloads and swaps",
				card = "BOOST  15 → 25%",
				status = "StimStrong",
			},
			B3 = {
				note = "Strong Stim: the zone lasts 16 s (you stay stimmed 4 s after)",
				duration = 16,
			},
			G2 = {
				note = "Heal Zone: no stim; you and your team inside heal 60 HP over 8 s",
				card = "TEAM HEALS 60 HP  ·  NO STIM",
				behaviour = "Heal", -- Mods/Stim: heals friendlies inside instead of a stim
				healPerSecond = 7.5, -- via ctx.restore each tick (a Heal Orb's heal keeps running)
			},
			G3 = { note = "Heal Zone: 2 charges", charges = 2 },
		},
	},
	Recall = {
		id = "Recall",
		name = "Recall",
		role = "Escape",
		slot = 2, -- E (vault/01 Design/Abilities/Upgrade Paths.md)
		paths = { A = "Recharge", B = "Long Range", G = "Crash Recovery" },
		block = "Placeable",
		activation = "HeldPlace",
		authority = "Server",
		icon = "rbxassetid://92035047423292", -- ChatGPT icon (art-source/ui/chatgpt, vault/02 Art/UI Art Brief (ChatGPT).md)
		glyph = "↺",
		hint = { primary = "Plant" },
		levels = {
			L1 = {
				note = "Plant an anchor; teleport back to it from 40 studs (20 s cooldown)",
				cooldown = 20, -- seconds between teleports; the anchor stays (planting is free)
				charges = 1,
				placeRange = 10, -- studs from the head to where it's planted
				size = 1.2, -- the anchor's box across (studs)
				height = 1.6, -- and up
				range = 40, -- studs from the anchor you can teleport from
				windup = 0.6, -- seconds from the press to arriving (no shooting)
				pickupRange = 6, -- studs from the anchor you can pick it up
				pickupHold = 0.5, -- seconds the key is held to pick it up
				roomWidth = 2.5, -- studs: the space a spot needs for you to arrive
				roomHeight = 5,
				hp = 2, -- bullet hits that destroy it
				life = 600, -- seconds (all round, until rounds exist)
			},
			-- Card text (`note`) stays under ~70 characters (the draft cards).
			A2 = { note = "Recharge: teleport again after 10 s (was 20 s)", cooldown = 10 },
			A3 = { note = "Recharge: teleport again after just 5 s", cooldown = 5 },
			B2 = { note = "Long Range: teleport back from 60 studs away (was 40)", range = 60 },
			B3 = { note = "Long Range: teleport back from 80 studs away", range = 80 },
			-- Crash Recovery: a passive on top of the normal Recall (Services/
			-- ModRecall.rescue): once a round, the hit that would kill you within
			-- `range` of your standing anchor pulls you onto it instead, at
			-- `rescueHealth`; the anchor breaks (no charge lost, plant again).
			G2 = {
				note = "Crash Recovery: once a round, die near your anchor: back on it at 1 HP",
				card = "CHEAT DEATH ONCE  ·  BACK AT 1 HP",
				behaviour = "Crash",
				rescueHealth = 1,
				rescueGrace = 0.25, -- seconds nothing lands after a rescue (the trip; shots already fired)
			},
			G3 = {
				note = "Crash Recovery: you come back with 40 HP instead of 1",
				card = "COMEBACK HP  1 → 40",
				rescueHealth = 40,
			},
		},
	},
	-- The free pack (vault/04 Tech/Prompts/2026-11-17 New Abilities (Free Pack).md,
	-- spec locked 2026-11-17; spec notes in vault/01 Design/Abilities/).
	-- Shock Dart: Recon's bow and flight, but the bolt explodes where it lands
	-- (Mods/ShockDart). Damage falls from `damage` at the centre to
	-- `edgeDamage` at `radius`; line of sight from the impact; none to you,
	-- FRIENDLY_FIRE of it to your team.
	ShockDart = {
		id = "ShockDart",
		name = "Shock Dart",
		role = "Damage",
		slot = 2, -- E, like Recon (same bow: you never hold both)
		paths = { A = "Recharge", B = "More Darts", G = "Static" },
		block = "Projectile",
		activation = "HeldCharge",
		authority = "Server",
		icon = "rbxassetid://72311263273723", -- stand-in (tools/icons/make_free_pack_icons.py) until the ChatGPT icon
		glyph = "SD",
		hint = { primary = "Hold: charge", alt = "Bounces" },
		levels = {
			L1 = {
				note = "Shock dart: Recon's bow; the bolt explodes where it lands, 50 → 25 over 5 studs",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				chargeTime = 1, -- Recon's flight from here to maxFlight
				minSpeed = 45,
				maxSpeed = 130,
				lift = 0.04,
				gravity = 45,
				size = 0.15,
				restitution = 0.85,
				friction = 0.9,
				maxBounces = 2,
				maxFlight = 3,
				radius = 5,
				damage = 50, -- at the centre
				edgeDamage = 25, -- at `radius`
			},
			A2 = { note = "Recharge: the dart comes back 15 s after use", cooldown = 15 },
			A3 = { note = "Recharge: the dart comes back 6 s after use", cooldown = 6 },
			B2 = {
				note = "More Darts: 2 darts a round, 42 → 21 damage",
				charges = 2,
				damage = 42,
				edgeDamage = 21,
			},
			B3 = {
				note = "More Darts: 4 darts a round, 36 → 18 damage",
				charges = 4,
				damage = 36,
				edgeDamage = 18,
			},
			-- No damage: Hinder (Config/StatusEffects) on everyone in the radius
			-- the impact can see, but you.
			G2 = {
				note = "Static: no damage; Hinders everyone in 5 studs for 2 s; recharges in 15 s",
				card = "HINDERS INSTEAD OF DAMAGE",
				behaviour = "Static",
				hinder = 2,
				cooldown = 15,
			},
			G3 = {
				note = "Static: Hinder 3 s in a 7-stud radius",
				card = "HINDER 3 S  ·  RADIUS 5 → 7",
				hinder = 3,
				radius = 7,
			},
		},
	},
	-- Flash: a held throw (Mods/Flash). LMB throws it (it pops `fuse` s after
	-- leaving the hand, wherever it is), RMB pops it from the hand after
	-- `quickFuse` s (a short toss). Everyone facing the pop with a clear line,
	-- within `range`, is Blinded (StatusService.blind): `blindMax` s looking
	-- straight at it, down to `blindSide` at `sideAngle`, none past `maxAngle`.
	-- Enemies, teammates and you alike.
	Flash = {
		id = "Flash",
		name = "Flash",
		role = "Control",
		slot = 1, -- Q
		paths = { A = "More Flashes", B = "Recharge", G = "Exposure" },
		block = "Projectile",
		activation = "HeldThrow",
		authority = "Server",
		icon = "rbxassetid://86922815169421", -- stand-in (tools/icons/make_free_pack_icons.py)
		glyph = "FL",
		hint = { primary = "Throw", alt = "Quick pop" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Flash: pops 0.9 s after the throw; blinds everyone facing it in 30 studs, up to 1.75 s",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				throwSpeed = 75, -- LMB
				throwLift = 0.08,
				lobSpeed = 14, -- RMB: a short toss that pops just ahead
				lobLift = 0.2,
				gravity = 55,
				bounces = 3, -- off walls (it pops in the air or on the floor)
				restitution = 0.45,
				friction = 0.7,
				size = 0.25,
				fuse = 0.9, -- seconds after the throw it pops
				quickFuse = 0.3, -- RMB
				range = 30,
				-- On your screen when it pops (owner 2026-11-17: "if you can see
				-- the flash on the screen when it pops, you will get flashed"):
				-- the default 80° camera's view, ±screenX across and ±screenY up
				-- and down from where you look. blindMax in the middle, blindEdge
				-- at the screen's edge.
				screenX = 56,
				screenY = 40,
				blindMax = 1.75,
				blindEdge = 1.25,
				-- Off screen but within glanceAngle of your look: a short glance
				-- (Valorant: a flash at the edge of your view still stings).
				glance = 0.35,
				glanceAngle = 100,
				walls = 0, -- walls the flash reaches through
			},
			A2 = { note = "More Flashes: 2 a round", charges = 2 },
			A3 = { note = "More Flashes: 3 a round", charges = 3 },
			B2 = { note = "Recharge: comes back 15 s after use", cooldown = 15 },
			B3 = { note = "Recharge: comes back 6 s after use", cooldown = 6 },
			-- No blind: every enemy who would have been blinded is revealed
			-- (Recon's outline for your team, DETECTED for them).
			G2 = {
				note = "Exposure: no blind; enemies who see it are revealed for 3 s; recharges in 15 s",
				card = "REVEALS INSTEAD OF BLINDING",
				behaviour = "Exposure",
				reveal = 3,
				cooldown = 15,
			},
			G3 = {
				note = "Exposure: revealed for 5 s, and it reaches through one wall",
				card = "REVEAL 3 → 5 S  ·  THROUGH 1 WALL",
				reveal = 5,
				walls = 1,
			},
		},
	},
	-- Roller: a held placement (Mods/Roller). LMB sets the bot down just ahead;
	-- it rolls at `speed` for `life` s, turns at walls and ledges, and locks on
	-- to the first enemy in sight within `lockRange` inside a `lockAngle` cone
	-- ahead. Locked, it chases at `lockSpeed`; within `trigger` studs (or
	-- `chase` s after the lock) it chirps for `warn` s and explodes: `damage`
	-- at the centre to `edgeDamage` at `radius`, line of sight, none to you,
	-- FRIENDLY_FIRE to your team. `hp`: it can be shot. Nobody locked by the
	-- end: it fizzles.
	Roller = {
		id = "Roller",
		name = "Roller",
		role = "Damage",
		slot = 3, -- T
		paths = { A = "More Bots", B = "Faster", G = "Remote" },
		block = "Placeable",
		activation = "HeldPlace",
		authority = "Server",
		icon = "rbxassetid://93611125603416", -- stand-in (tools/icons/make_free_pack_icons.py)
		glyph = "RB",
		hint = { primary = "Set down" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Roller: a bot that rolls 5 s, locks on to an enemy ahead and explodes, 60 → 30",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				placeRange = 9, -- studs ahead it can be set down
				width = 1.7, -- its box (studs)
				height = 1.2,
				length = 2,
				speed = 14, -- studs/s
				lockSpeed = 22, -- once locked on
				life = 5, -- seconds rolling
				lockRange = 25,
				lockAngle = 60, -- the cone ahead (full angle)
				trigger = 4, -- studs from the target: the warning starts
				chase = 2.5, -- seconds locked before it warns anyway
				warn = 0.4, -- the chirp before it explodes
				radius = 6,
				damage = 60,
				edgeDamage = 30,
				hp = 25,
				maxActive = 1,
				stepUp = 1.6, -- highest step it climbs
				dropDown = 6, -- deepest drop it rolls off (deeper: it turns)
			},
			A2 = { note = "More Bots: 2 a round", charges = 2, maxActive = 2 },
			A3 = { note = "More Bots: 4 a round", charges = 4, maxActive = 2 },
			B2 = {
				note = "Faster: 125% speed for 7 s",
				speed = 17.5,
				lockSpeed = 27.5,
				life = 7,
			},
			B3 = {
				note = "Faster: 150% speed for 10 s",
				speed = 21,
				lockSpeed = 33,
				life = 10,
			},
			-- Remote: press the key again while it rolls to blow it up there
			-- (no charge spent: ModTrigger). It still seeks on its own.
			G2 = {
				note = "Remote: press the key again to blow it up any time",
				card = "PRESS AGAIN: DETONATE",
				behaviour = "Remote",
			},
			G3 = {
				note = "Remote: + recharges in 7 s, 125% speed, 7 s",
				card = "RECHARGE 7 S  ·  125% SPEED",
				cooldown = 7,
				speed = 17.5,
				lockSpeed = 27.5,
				life = 7,
			},
		},
	},
}

-- The order Mods are listed in (dev panel, draft later).
local ORDER = {
	"Dash",
	"Updraft",
	"Molly",
	"Firewall",
	"Frost",
	"Recon",
	"HealOrb",
	"Stim",
	"Recall",
	"ShockDart",
	"Flash",
	"Roller",
}

-- One wind stroke on the screen (WIND_FEEL).
type WindStroke = {
	x: number, -- where the head starts: share of the screen width
	y: number, -- ... and of its height (0 = top)
	size: number, -- index into WIND_FEEL.sizes
	at: number?, -- Updraft: share of the rise when it starts
	ahead: boolean?, -- Dash: only when dashing forward or back
	slide: boolean?, -- Dash: also drawn for a slide
}

return table.freeze({
	defs = defs,
	ORDER = ORDER,
	SLOTS = 3,
	-- Every level, and the levels each one builds on (in order).
	LEVELS = { "L1", "A2", "A3", "B2", "B3", "G2", "G3" },
	CHAIN = {
		L1 = { "L1" },
		A2 = { "L1", "A2" },
		A3 = { "L1", "A2", "A3" },
		B2 = { "L1", "B2" },
		B3 = { "L1", "B2", "B3" },
		G2 = { "L1", "G2" },
		G3 = { "L1", "G2", "G3" },
	} :: { [string]: { string } },
	-- Levels whose behaviour is built (the rest resolve, but only their
	-- numbers apply). The dev panel marks the others.
	BUILT = {
		L1 = true,
		A2 = true,
		A3 = true,
		B2 = true,
		B3 = true,
		G2 = true,
		G3 = true,
	} :: { [string]: boolean },

	-- Held Mods (Mods.md → Rules for held Mods).
	EQUIP_TIME = 0.25, -- raise before a held Mod can be used
	USE_TIME = 0.35, -- throw / heal animation before the gun comes back

	-- Molly in first person: the pin pull starts this long after the raise,
	-- and the pin leaves the canister this far into it (seconds).
	MOLLY_PIN_AT = 0.12,
	MOLLY_PIN_GONE = 0.3, -- 0.2 until 2026-11-16: hid it before the yank (Viewmodel ITEM_PART_MOVES)

	-- Damage from your own Mods to you and your team, as a share of the
	-- enemy damage (00 Abilities.md → Friendly fire). Exceptions per Mod.
	FRIENDLY_FIRE = 0.5,

	-- Dash feel (vault/01 Design/Abilities/Dash.md → First person, What
	-- others see, Sound). Client-only look; the rules are in the Dash stats.
	DASH_FEEL = {
		fov = 11, -- FOV punch (degrees), eased back over fovTime
		fovTime = 0.25,
		roll = 4, -- camera roll toward a sideways dash (degrees)
		rollTime = 0.3,
		lunge = 0.35, -- studs the camera leads the dash, then settles back
		lungeTime = 0.3,
		shake = 0.12,
		trailTime = 0.35, -- the wind trail others see lingers this long
		crackle = true, -- play the Dash_Crackle layer (on/off to try the classic feel)
	},

	-- Updraft feel (vault/01 Design/Abilities/Updraft.md → First person, What
	-- others see). Client-only look.
	UPDRAFT_FEEL = {
		fov = 6, -- FOV punch (degrees) over fovTime
		fovTime = 0.3,
		lurch = 0.4, -- studs the camera leads upward, then settles
		lurchTime = 0.3,
		shake = 0.1,
		trailTime = 0.3, -- the wind trail under you while rising
	},

	-- Wind strokes: what Dash and Updraft put on your own screen (vault/02 Art/
	-- Ability VFX Direction.md → Wind; drawn by client/Util/WindStrokes). One
	-- tapered stroke (VfxTextures.WIND_STROKE) in a few sizes, on the screen
	-- edges only: it snaps in, moves along the move on held frames and goes by
	-- closing from the tail. No blur, no fade. Places are shares of the screen
	-- (x across, y down); lengths are shares of the screen height.
	WIND_FEEL = {
		color = Color3.fromHex("EAF4FF"), -- off-white, a faint cool tint
		alpha = 0.08, -- ImageTransparency of a stroke (flat: it never fades)
		-- The dark edge: a bigger copy of the shape under each stroke, so the
		-- white reads on a bright sky or a pale floor.
		ink = Color3.fromHex("1B2838"),
		inkAlpha = 0.5, -- its ImageTransparency
		inkThick = 1.6, -- its thickness (x the stroke's)
		inkLength = 1.035, -- ... and its length
		fps = 14, -- held frames a second (the stepped motion)
		onset = 0.05, -- seconds a stroke takes to shoot out to its full length
		onsetLength = 0.45, -- its length on the first frame (share of the full one)
		hold = 0.3, -- share of a stroke's life at full length before the tail closes
		thin = 0.55, -- thickness left once the tail has closed (share)
		clear = 0.4, -- the aim area: the middle share of the screen no stroke enters
		clearPad = 0.015, -- extra gap kept round it (share of the screen height)
		sizes = { -- { length, thickness }
			{ 0.46, 0.028 },
			{ 0.34, 0.021 },
			{ 0.24, 0.015 },
			{ 0.15, 0.01 },
		},
		-- Dash: every stroke at once, pointing the way you dash. Forward they
		-- converge on the centre, back they leave it, sideways they lie flat on
		-- the leading and trailing edges. x, y: where the head starts.
		dash = {
			time = 0.25, -- seconds from the dash to the last stroke gone
			travel = 0.09, -- how far a head moves (share of the screen height)
			-- A slide draws only the `slide` strokes, lighter: at strength 0 they
			-- keep this share of the length, travel and opacity (1 = a dash's).
			light = 0.5,
			strokes = {
				{ x = 0.13, y = 0.25, size = 1 },
				{ x = 0.88, y = 0.29, size = 1 },
				{ x = 0.09, y = 0.58, size = 2, slide = true },
				{ x = 0.91, y = 0.54, size = 2, slide = true },
				{ x = 0.17, y = 0.85, size = 2, slide = true },
				{ x = 0.84, y = 0.82, size = 3, slide = true },
				{ x = 0.37, y = 0.1, size = 3, ahead = true }, -- top and bottom:
				{ x = 0.65, y = 0.93, size = 4, ahead = true }, -- not for a side dash
			} :: { WindStroke },
		},
		-- Updraft: the same strokes straight up, in waves over the rise: the
		-- bottom corners on the launch, then up the sides. `at`: share of the
		-- rise when a stroke starts (0.25 is about the hand's downward flick).
		-- Three waves and a short life, so at most five are up at once (the
		-- rise is only about 0.4 s: nine strokes in four waves all overlapped).
		updraft = {
			life = 0.18, -- seconds one stroke lasts
			endBy = 0.88, -- every stroke is gone by this share of the rise
			travel = 0.2, -- how far a head runs up (share of the screen height)
			strokes = {
				{ x = 0.07, y = 0.84, size = 1, at = 0 },
				{ x = 0.93, y = 0.8, size = 1, at = 0 },
				{ x = 0.18, y = 0.97, size = 2, at = 0 },
				{ x = 0.84, y = 0.62, size = 2, at = 0.25 },
				{ x = 0.14, y = 0.56, size = 2, at = 0.25 },
				{ x = 0.06, y = 0.3, size = 3, at = 0.5 },
				{ x = 0.94, y = 0.26, size = 3, at = 0.5 },
			} :: { WindStroke },
		},
		-- Ghost (Dash B2/B3): while the dodge window is open, short thin strokes
		-- jump along both side edges on held frames; gone the frame it closes.
		-- The cloak (B3, G3) is one long thin line down each side, and the world
		-- a little greyer; both come off over the cloak's fade-out.
		ghost = {
			color = Color3.fromHex("D8F0FF"),
			alpha = 0.15,
			fps = 12, -- the shimmer's held frames a second
			inset = 0.02, -- from the side edge (share of the screen width)
			strokes = { -- per side (the right side is the left one upside down)
				{ y = 0.34, length = 0.26, thick = 0.014 },
				{ y = 0.56, length = 0.14, thick = 0.012 },
				{ y = 0.72, length = 0.2, thick = 0.012 },
			},
			jump = { 0, 0.05, -0.03, 0.07, -0.05 }, -- y steps a stroke cycles through
			blink = 3, -- each stroke is dark one held frame in this many
			cloak = {
				alpha = 0.45,
				length = 0.5,
				thick = 0.006,
				fps = 5,
				jump = 0.012, -- the line steps up and down by this (share of the height)
				fadeIn = 0.15, -- seconds
				saturation = -0.2, -- ColorCorrection while cloaked (no tint, no flash)
			},
		},
	},

	-- Colours by viewer: you and your team / enemies / glitch static.
	COLORS = {
		ally = Color3.fromHex("00E5FF"),
		enemy = Color3.fromHex("FF5A36"),
		glitch = Color3.fromHex("FF3DCB"),
	},

	-- Requests are checked against the server's own head and camera.
	ORIGIN_TOLERANCE = 5, -- studs from the claimed camera origin to the server head
	AIM_TOLERANCE = 30, -- degrees between the aim and the server's copy of the camera
	AIM_YAW_TOLERANCE = 50, -- fallback: degrees between the aim and the character's facing

	-- Test-mode servers start everyone with these (a match drafts them).
	TEST_LOADOUT = {
		{ id = "Updraft", level = "L1" }, -- slot 1 (Q)
		{ id = "Dash", level = "L1" }, -- slot 2 (E)
		{ id = "Firewall", level = "L1" }, -- slot 3 (T)
	} :: { Types.SlotLoadout },

	-- The Flash's white-out on the blinded player's screen (Util/FlashFx,
	-- vault/01 Design/Abilities/Flash.md). Valorant's recipe, our colours: a
	-- fast ramp in, a near-white peak (a hair under full), held, then the
	-- fill clears from the edges inward while a glow on the flash's spot
	-- shrinks into it, tinted in the Flash's colour as it fades.
	FLASH_FEEL = {
		peak = Color3.fromHex("FFF8EA"), -- the held white (warm, never pure)
		tint = Color3.fromHex("FFC24D"), -- the Flash's colour, shown in the fade
		rampIn = 0.05, -- seconds to full
		peakAlpha = 0.03, -- the fill's transparency at full strength
		fadeShare = 0.4, -- the last share of the blind spent clearing
		minFade = 0.35, -- ... but never faster than this
		coreSize = 2.4, -- the glow on the flash's spot, in screen heights, at the peak
		coreEnd = 0.25, -- ... and as it closes
		muffle = 0.6, -- 0..1 of the full sound muffle
	},

	-- Remote budgets (per player): rate per second, burst.
	RATE = {
		ModHold = { 8, 10 },
		ModUse = { 6, 8 },
		ModSteer = { 30, 40 }, -- the Firewall's steering stream (~20 a second)
		ModRecall = { 4, 6 }, -- Recall's teleport / pick-up
		ModTrigger = { 4, 6 }, -- a second press on a Mod already out (Roller's Remote)
		ModSim = { 10, 14 }, -- predicted Mods' reports with Server Authority off (dash, launch, slam, landing)
		DevMod = { 6, 10 },
		DevDummy = { 0.5, 3 }, -- SpawnDummy on top of DevMod: one every 2 s, burst 3
	},

	-- Server Authority off (Services/ModSim): each client simulates its own
	-- Dash and Updraft and reports them; the server checks the reports against
	-- its own charge count and its own view of the character.
	SIM_REPORT = {
		grace = 0.25, -- seconds of slack on a recharge (two clocks, latency)
		flightLife = 8, -- seconds an Updraft can stay in the air before its reports are dropped
		-- Crash Down, from the server's view of the root:
		armSlack = 0.05, -- seconds of jitter allowed under slamArm (must stay below it)
		slamMinRise = 1, -- studs the root must have risen above the launch before a dive counts
		slamMinDive = 0.03, -- seconds a dive must last (two steps: no launch-and-land in one burst)
		slamFloorReach = 8, -- studs above the floor the server may still see a landed root (it sees it late)
		slamTravelSlack = 8, -- studs on top of maxCarry x the flight's time a slam may land from its launch
		slamMaxTravel = 70, -- ... and never further than this
		slamMaxDrop = 60, -- studs below the launch a slam may land
	},

	-- Dev test panel (DevModService): who may use it outside Studio and test
	-- mode (Config/TestRange TESTER_DEV_PANEL opens it to every tester).
	DEV_GROUP = 11116787,
	DEV_RANK = 255,
	DEV_DUMMY_DISTANCE = 12, -- studs in front of you a dummy spawns
	DEV_MAX_DUMMIES = 6, -- per player
	DEV_MAX_DUMMIES_TOTAL = 18, -- per server (several testers)
	DEV_HURT = 50, -- "Hurt me": a hit from nobody through the damage guards (can kill)
})
