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
		paths = { A = "Distance", B = "Ghost", G = "Desync" },
		block = "Dash",
		activation = "Instant",
		authority = "Simulation",
		icon = "rbxassetid://129496243981575",
		glyph = "»",
		hint = {},
		levels = {
			L1 = {
				note = "Dash 12 studs in your move direction",
				cooldown = 0, -- Dash: 1 per round, no recharge
				charges = 1,
				distance = 12,
				duration = 0.15, -- seconds the dash lasts
				exitSpeed = 22, -- horizontal speed kept when the dash ends
				radius = 1.4, -- spherecast radius: stops short of walls
				fireDelay = 0.1, -- the gun is down while dashing and this long after
				focusWindow = 0.6, -- Dash Focus: the first shot this soon after has no move/air spread
			},
			A2 = { note = "Distance: dash 18 studs (150%) in the same time", distance = 18 },
			A3 = { note = "Distance: dash 24 studs (200%), 2 charges", distance = 24, charges = 2 },
			B2 = {
				note = "Ghost: bullets pass through you for 0.35 s from the press",
				dodgeWindow = 0.35,
			},
			B3 = {
				note = "Ghost: nearly invisible for 1 s after a dash, 2 charges",
				cloakAfter = 1, -- seconds after the dash ends
				cloakShimmer = 10, -- enemies this close still see a shimmer
				charges = 2,
			},
			G2 = {
				note = "Desync: a decoy keeps running for 1.5 s; you can't shoot for 0.3 s",
				behaviour = "Desync",
				decoyTime = 1.5,
				fireDelay = 0.3,
			},
			G3 = {
				note = "Desync: the decoy fires fake shots and you're invisible while it runs",
				decoyFires = true,
				decoyCloak = true,
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
		icon = "rbxassetid://99871732908404", -- the Launch Pad icon until Updraft has its own
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
				note = "Crash Down: crouch mid-air to slam, 30 damage within 8 studs",
				behaviour = "Slam",
				slamDamage = 30, -- enemies in sight of the landing (no self or team damage)
				slamRadius = 8, -- studs from your root where you land
				slamSpeed = 90, -- studs/s straight down
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
		icon = "rbxassetid://116682455753318", -- the Packet icon until Molly has its own
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
			A2 = { note = "Recharge: a used Molly comes back after 15 s", cooldown = 15 },
			A3 = { note = "Recharge: comes back after 10 s", cooldown = 10 },
			B2 = { note = "Bigger Fire: a 12-stud fire patch", radius = 12 },
			B3 = { note = "Bigger Fire: 14 studs, burns for 6 s", radius = 14, duration = 6 },
			G2 = {
				note = "Fork Fire: splits into 3 small fires that scatter; they burn you too",
				behaviour = "Fork",
				forks = 3,
				forkRadius = 5,
				forkSpeed = 30, -- studs/s the bomblets scatter at
				selfFire = 1, -- share of the damage to you and your team
			},
			G3 = { note = "Fork Fire: 5 fires, one more bounce first", forks = 5, bounces = 5 },
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
		icon = "rbxassetid://124672546555888", -- the old wall's icon until Firewall has its own
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
				note = "Short Wall: recharges after 15 s, but half as long (20 studs)",
				cooldown = 15,
				maxLength = 20,
			},
			A3 = { note = "Short Wall: recharges after 6 s", cooldown = 6 },
			B2 = { note = "Long Wall: 60 studs long", maxLength = 60 },
			B3 = { note = "Long Wall: 2 charges", charges = 2 },
			G2 = {
				note = "Frost Wall: a wall of ice, 60 studs; no damage, touching it Hinders 1.5 s",
				behaviour = "Frost",
				hinder = 1.5,
				maxLength = 60,
			},
			G3 = { note = "Frost Wall: 2 charges", charges = 2 },
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
		icon = "rbxassetid://98630150227573", -- the Lag Field icon until Frost has its own
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
			A2 = { note = "Stockpile: 2 charges", charges = 2 },
			A3 = { note = "Stockpile: 3 charges", charges = 3 },
			B2 = { note = "Big Burst: double the area (14 studs)", radius = 14 },
			B3 = { note = "Big Burst: triple the area (17 studs)", radius = 17 },
			G2 = {
				note = "Freeze Frame: everyone in the burst is frozen solid 1.5 s, you too",
				behaviour = "Freeze",
				freeze = 1.5,
			},
			G3 = { note = "Freeze Frame: frozen for 2.5 s", freeze = 2.5 },
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
		icon = "rbxassetid://94197716144737", -- the Ping icon until Recon has its own
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
			A2 = { note = "Recharge: the dart comes back after 20 s", cooldown = 20 },
			A3 = { note = "Recharge: comes back after 12 s", cooldown = 12 },
			B2 = { note = "More Pulses: 3 pulses", pulses = 3 },
			B3 = { note = "More Pulses: 5 pulses", pulses = 5 },
			G2 = {
				note = "Ping Spike: one big pulse reveals every enemy in 60 studs through walls for 4 s",
				behaviour = "Spike",
				radius = 60,
				reveal = 4,
				pulses = 1,
			},
			G3 = { note = "Ping Spike: +20% damage to enemies it revealed", bonusDamage = 0.2 },
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
		icon = "rbxassetid://108865641226831",
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
				behaviour = "Barrier",
				barrierHits = 1,
			},
			G3 = { note = "Barrier: the bubble blocks the next 2 enemy hits", barrierHits = 2 },
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
		icon = "rbxassetid://78196418309045", -- the Overclock icon until Stim has its own
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
				tossDistance = 5, -- studs ahead it lands (short of a wall)
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
				status = "StimStrong",
			},
			B3 = {
				note = "Strong Stim: the zone lasts 16 s (you stay stimmed 4 s after)",
				duration = 16,
			},
			G2 = {
				note = "Heal Zone: no stim; you and your team inside heal 60 HP over 8 s",
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
		icon = "rbxassetid://139660148791653", -- the Rollback icon until Recall has its own
		glyph = "↺",
		hint = { primary = "Plant" },
		levels = {
			L1 = {
				note = "Plant an anchor; press within 40 studs to teleport to it (0.6 s wind-up, 20 s cooldown)",
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
			A2 = { note = "Recharge: 10 s cooldown", cooldown = 10 },
			A3 = { note = "Recharge: 5 s cooldown", cooldown = 5 },
			B2 = { note = "Long Range: teleport from 60 studs away", range = 60 },
			B3 = { note = "Long Range: from 80 studs away", range = 80 },
			G2 = {
				note = "Crash Recovery: once a round, a death within range pulls you back to the anchor at 1 HP",
				behaviour = "Crash",
				rescueHealth = 1,
			},
			G3 = { note = "Crash Recovery: you arrive with 40 HP", rescueHealth = 40 },
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
	MOLLY_PIN_GONE = 0.2,

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
		blur = 4, -- BlurEffect size at the start, gone after blurTime
		blurTime = 0.18,
		streakTime = 0.3, -- screen-edge wind streaks
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

	-- Remote budgets (per player): rate per second, burst.
	RATE = {
		ModHold = { 8, 10 },
		ModUse = { 6, 8 },
		ModSteer = { 30, 40 }, -- the Firewall's steering stream (~20 a second)
		ModRecall = { 4, 6 }, -- Recall's teleport / pick-up
		DevMod = { 6, 10 },
		DevDummy = { 0.5, 3 }, -- SpawnDummy on top of DevMod: one every 2 s, burst 3
	},

	-- Dev test panel (DevModService): who may use it outside Studio and test
	-- mode (Config/TestRange TESTER_DEV_PANEL opens it to every tester).
	DEV_GROUP = 11116787,
	DEV_RANK = 255,
	DEV_DUMMY_DISTANCE = 12, -- studs in front of you a dummy spawns
	DEV_MAX_DUMMIES = 6, -- per player
	DEV_MAX_DUMMIES_TOTAL = 18, -- per server (several testers)
	DEV_HURT = 50, -- "Hurt me" (never kills)
})
