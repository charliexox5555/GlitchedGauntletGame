--!strict
-- All Mod (ability) data (vault/01 Design/Mods.md, numbers are starting points
-- for playtesting). Code reads stats only through Mods.stats(id, level), which
-- resolves L1 → A2 → A3 (or B2 → B3, G2 → G3): each level lists only what
-- changes. Behaviour switches (e.g. `onDash = "Reload"`) are how later levels
-- change what a Mod does; each Mod module dispatches on them. Levels above L1
-- are shaped here but not built yet (Phase 2): their notes say what they do.
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
			A2 = { note = "Burst: 2 charges", charges = 2 },
			A3 = { note = "Burst: each dash reloads 50% of the magazine", onDash = "Reload" },
			B2 = { note = "Ghost: bullets pass through you while dashing", dashImmune = true },
			B3 = { note = "Ghost: near-invisible for 1 s after a dash", cloakAfter = 1 },
			G2 = { note = "Desync: decoy afterimage; no shooting 0.3 s", behaviour = "Desync" },
			G3 = { note = "Desync: the decoy fires blanks; you're invisible", decoyFires = true },
		},
	},
	Updraft = {
		id = "Updraft",
		name = "Updraft",
		role = "Mobility",
		block = "Launch",
		activation = "Instant",
		authority = "Simulation",
		icon = "rbxassetid://99871732908404", -- the Launch Pad icon until Updraft has its own
		glyph = "^",
		hint = {},
		levels = {
			L1 = {
				note = "Launch straight up ~14 studs (works mid-air)",
				cooldown = 0, -- 2 per round, no recharge
				charges = 2,
				peak = 14, -- studs above where you used it (speed from Workspace.Gravity)
				maxCarry = 24, -- most running speed carried into the air (a slide-jump's)
				gunDown = 0.35, -- seconds the gun is down after the launch (most of the rise)
			},
			-- The paths below are the Launch Pad's, not redesigned yet.
			A2 = { note = "Jump Grid: 2 pads at once", charges = 2 },
			A3 = { note = "Jump Grid: +30% move speed for 2 s on landing", landingBoost = 0.3 },
			B2 = { note = "Air Strike: no airborne spread for 2 s after launch", airAccurate = 2 },
			B3 = { note = "Air Strike: landing slam, 40 damage in 8 studs", slamDamage = 40 },
			G2 = { note = "Zero-G: 14-stud low-gravity zone for 5 s", behaviour = "ZeroG" },
			G3 = { note = "Zero-G: immune to own zone spread, reveals enemies", zoneReveal = true },
		},
	},
	Molly = {
		id = "Molly",
		name = "Molly",
		role = "Damage",
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
			-- The paths below are the Packet's, not redesigned yet.
			A2 = { note = "Payload: 2 charges", charges = 2 },
			A3 = { note = "Payload: 11-stud blast and a 3 s burn zone", radius = 11, burnDps = 10 },
			B2 = { note = "Sticky: sticks to the first hit, 0.8 s fuse", behaviour = "Sticky" },
			B3 = { note = "Sticky: hit enemies get Packet Loss for 2.5 s", packetLoss = 2.5 },
			G2 = { note = "Fork Bomb: 3 random mini-bombs that can hurt you", behaviour = "Fork" },
			G3 = { note = "Fork Bomb: 5 mini-bombs that bounce twice", forks = 5 },
		},
	},
	Firewall = {
		id = "Firewall",
		name = "Firewall",
		role = "Control",
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
			-- The paths below are the old cover wall's, not redesigned yet.
			A2 = { note = "Rampart: 250 HP, lasts 10 s", hp = 250, life = 10 },
			A3 = { note = "Rampart: your team shoots out through it", oneWay = true },
			B2 = { note = "Burn Wall: fire curtain you can walk through", behaviour = "Burn" },
			B3 = { note = "Burn Wall: moves forward 10 studs over 4 s", advance = 10 },
			G2 = { note = "Mirror Wall: reflects 25% of bullet damage", behaviour = "Mirror" },
			G3 = { note = "Mirror Wall: 50% reflection, 2 charges", reflect = 0.5, charges = 2 },
		},
	},
	Frost = {
		id = "Frost",
		name = "Frost",
		role = "Control",
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
			-- The paths below are the Lag Field's, not redesigned yet.
			A2 = { note = "Latency: enemies inside fire and reload 30% slower", latency = 0.3 },
			A3 = { note = "Latency: enemies inside take +15% damage", vulnerable = 0.15 },
			B2 = { note = "Buffer: 14 studs, lasts 7 s", radius = 14, duration = 7 },
			B3 = { note = "Buffer: first exit pulls them back to the centre", pullBack = true },
			G2 = { note = "Freeze Frame: everything inside freezes 1.5 s", behaviour = "Freeze" },
			G3 = { note = "Freeze Frame: 2.5 s, +20% damage after", freeze = 2.5 },
		},
	},
	Recon = {
		id = "Recon",
		name = "Recon",
		role = "Info",
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
			-- The paths below are the Ping's, not redesigned yet.
			A2 = { note = "Traceroute: marked 4 s for the whole team", duration = 4 },
			A3 = { note = "Traceroute: marked enemies take +10% damage", vulnerable = 0.1 },
			B2 = { note = "Sonar: 50 studs and a sensor pulsing for 9 s", radius = 50 },
			B3 = { note = "Sonar: the sensor shows enemy Mod cooldowns", showCooldowns = true },
			G2 = { note = "Ping Spike: everyone in 60 studs for 4 s, you too", behaviour = "Spike" },
			G3 = { note = "Ping Spike: +20% damage to revealed enemies", bonusDamage = 0.2 },
		},
	},
	HealOrb = {
		id = "HealOrb",
		name = "Heal Orb",
		role = "Sustain",
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
			A2 = { note = "Hotfix: the heal is instant", duration = 0 },
			A3 = { note = "Hotfix: also cleanses and gives +25 overshield", shield = 25 },
			B2 = { note = "Support Patch: heal pad, 15 HP/s for 4 s", behaviour = "Pad" },
			B3 = { note = "Support Patch: the pad gives 20% damage reduction", reduction = 0.2 },
			G2 = {
				note = "Corrupted Patch: instant full heal, then -4 HP/s",
				behaviour = "Corrupt",
			},
			G3 = { note = "Corrupted Patch: overheal to +50 shield", shield = 50 },
		},
	},
	Stim = {
		id = "Stim",
		name = "Stim",
		role = "Team buff",
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
			},
			-- The paths below are the Overclock's, not redesigned yet.
			A2 = { note = "Turbo: also +40% reload speed", reloadSpeed = 1.4 },
			A3 = { note = "Turbo: kills extend it by 3 s", killExtend = 3 },
			B2 = { note = "Precision: no spread or bloom instead", behaviour = "Precision" },
			B3 = { note = "Precision: headshots x2", headMultiplier = 2 },
			G2 = { note = "Overheat: +60%, no ammo use, -8 HP/s for 4 s", behaviour = "Overheat" },
			G3 = { note = "Overheat: bullets pierce walls and players", pierce = true },
		},
	},
	Recall = {
		id = "Recall",
		name = "Recall",
		role = "Escape",
		block = "Placeable",
		activation = "HeldPlace",
		authority = "Server",
		icon = "rbxassetid://139660148791653", -- the Rollback icon until Recall has its own
		glyph = "↺",
		hint = { primary = "Plant" },
		levels = {
			L1 = {
				note = "Plant an anchor; press within 40 studs to teleport to it (0.6 s wind-up, 15 s cooldown)",
				cooldown = 15, -- seconds between teleports; the anchor stays (planting is free)
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
			-- The paths below are the Rollback's, not redesigned yet.
			A2 = { note = "Undo: also restores HP from 3 s ago", restoreHealth = true },
			A3 = { note = "Undo: 15 s cooldown, 30% damage reduction 2 s", cooldown = 15 },
			B2 = {
				note = "Save State: press to drop a checkpoint, again to return",
				behaviour = "Save",
			},
			B3 = { note = "Save State: returning leaves a 30-damage shockwave", shockwave = 30 },
			G2 = {
				note = "Crash Recovery: passive auto-rewind once, max HP 60",
				behaviour = "Crash",
			},
			G3 = { note = "Crash Recovery: reveals who damaged you", revealAttackers = 4 },
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
	BUILT = { L1 = true } :: { [string]: boolean },

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

	-- Studio and test-mode servers start everyone with these (no draft yet).
	TEST_LOADOUT = {
		{ id = "Dash", level = "L1" },
		{ id = "Molly", level = "L1" },
		{ id = "HealOrb", level = "L1" },
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
