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
	LaunchPad = {
		id = "LaunchPad",
		name = "Launch Pad",
		role = "Mobility",
		block = "Placeable",
		activation = "HeldPlace",
		authority = "Server",
		icon = "rbxassetid://99871732908404",
		glyph = "^",
		hint = { primary = "Place" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Pad that launches you ~25 studs up and forward",
				cooldown = 0, -- Updraft: 2 per round, no recharge
				charges = 2,
				placeRange = 12,
				size = 6,
				life = 15,
				hp = 50,
				launchUp = 99, -- studs/s up
				launchForward = 30, -- studs/s along the pad's facing
			},
			A2 = { note = "Jump Grid: 2 pads at once", charges = 2 },
			A3 = { note = "Jump Grid: +30% move speed for 2 s on landing", landingBoost = 0.3 },
			B2 = { note = "Air Strike: no airborne spread for 2 s after launch", airAccurate = 2 },
			B3 = { note = "Air Strike: landing slam, 40 damage in 8 studs", slamDamage = 40 },
			G2 = { note = "Zero-G: 14-stud low-gravity zone for 5 s", behaviour = "ZeroG" },
			G3 = { note = "Zero-G: immune to own zone spread, reveals enemies", zoneReveal = true },
		},
	},
	Packet = {
		id = "Packet",
		name = "Packet",
		role = "Damage",
		block = "Projectile",
		activation = "HeldThrow",
		authority = "Server",
		icon = "rbxassetid://116682455753318",
		glyph = "●",
		hint = { primary = "Throw", alt = "Lob" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Grenade: bounces once, explodes after 1.2 s",
				cooldown = 0, -- Molly: 1 per round, no recharge
				charges = 1,
				fuse = 1.2,
				bounces = 1,
				damageCenter = 50,
				damageEdge = 20,
				radius = 8,
				throwSpeed = 80,
				lobSpeed = 40,
				throwLift = 0.12, -- added to the aim's up component before scaling
				lobLift = 0.35,
				gravity = 100, -- studs/s², lighter than the world's for readable arcs
				restitution = 0.45, -- speed kept on a bounce
				friction = 0.7, -- along-surface speed kept on a bounce
				size = 0.45, -- projectile radius
				selfDamage = false,
				friendlyFire = false,
			},
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
		role = "Defense",
		block = "Placeable",
		activation = "HeldPlace",
		authority = "Server",
		icon = "rbxassetid://124672546555888",
		glyph = "▮",
		hint = { primary = "Deploy" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "8x6 wall that blocks bullets both ways",
				cooldown = 0, -- 1 per round, no recharge
				charges = 1,
				placeRange = 8,
				width = 8,
				height = 6,
				thickness = 0.6,
				hp = 150,
				life = 6,
			},
			A2 = { note = "Rampart: 250 HP, lasts 10 s", hp = 250, life = 10 },
			A3 = { note = "Rampart: your team shoots out through it", oneWay = true },
			B2 = { note = "Burn Wall: fire curtain you can walk through", behaviour = "Burn" },
			B3 = { note = "Burn Wall: moves forward 10 studs over 4 s", advance = 10 },
			G2 = { note = "Mirror Wall: reflects 25% of bullet damage", behaviour = "Mirror" },
			G3 = { note = "Mirror Wall: 50% reflection, 2 charges", reflect = 0.5, charges = 2 },
		},
	},
	LagField = {
		id = "LagField",
		name = "Lag Field",
		role = "Control",
		block = "Zone",
		activation = "HeldThrow",
		authority = "Server",
		icon = "rbxassetid://98630150227573",
		glyph = "◎",
		hint = { primary = "Throw", alt = "Lob" },
		quickCast = "Primary",
		levels = {
			L1 = {
				note = "Orb makes a 10-stud zone for 4 s; enemies slowed 40%",
				cooldown = 0, -- Frost: 1 per round, no recharge
				charges = 1,
				radius = 10,
				duration = 4,
				slow = 0.4,
				throwSpeed = 70,
				lobSpeed = 35,
				throwLift = 0.12,
				lobLift = 0.35,
				gravity = 100,
				size = 0.5,
				maxFlight = 3, -- seconds before it opens mid-air
			},
			A2 = { note = "Latency: enemies inside fire and reload 30% slower", latency = 0.3 },
			A3 = { note = "Latency: enemies inside take +15% damage", vulnerable = 0.15 },
			B2 = { note = "Buffer: 14 studs, lasts 7 s", radius = 14, duration = 7 },
			B3 = { note = "Buffer: first exit pulls them back to the centre", pullBack = true },
			G2 = { note = "Freeze Frame: everything inside freezes 1.5 s", behaviour = "Freeze" },
			G3 = { note = "Freeze Frame: 2.5 s, +20% damage after", freeze = 2.5 },
		},
	},
	Ping = {
		id = "Ping",
		name = "Ping",
		role = "Info",
		block = "Reveal",
		activation = "Instant",
		authority = "Server",
		icon = "rbxassetid://94197716144737",
		glyph = "◉",
		hint = {},
		levels = {
			L1 = {
				note = "Reveal enemies within 30 studs for 2 s",
				cooldown = 30, -- Recon: 1 charge, back 30 s after use
				charges = 1,
				radius = 30,
				duration = 2,
			},
			A2 = { note = "Traceroute: marked 4 s for the whole team", duration = 4 },
			A3 = { note = "Traceroute: marked enemies take +10% damage", vulnerable = 0.1 },
			B2 = { note = "Sonar: 50 studs and a sensor pulsing for 9 s", radius = 50 },
			B3 = { note = "Sonar: the sensor shows enemy Mod cooldowns", showCooldowns = true },
			G2 = { note = "Ping Spike: everyone in 60 studs for 4 s, you too", behaviour = "Spike" },
			G3 = { note = "Ping Spike: +20% damage to revealed enemies", bonusDamage = 0.2 },
		},
	},
	PatchUp = {
		id = "PatchUp",
		name = "Patch Up",
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
				note = "Heal 40 HP over 2 s (ally in your crosshair or yourself)",
				cooldown = 0, -- Heal Orb: 1 per round, no recharge
				charges = 1,
				heal = 40,
				duration = 2,
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
	Overclock = {
		id = "Overclock",
		name = "Overclock",
		role = "Weapon buff",
		block = "SelfBuff",
		activation = "Instant",
		authority = "Server",
		icon = "rbxassetid://78196418309045",
		glyph = "⚡",
		hint = {},
		levels = {
			L1 = {
				note = "+25% fire rate for 5 s",
				cooldown = 0, -- Stim: 1 per round, no recharge
				charges = 1,
				duration = 5,
				fireRate = 1.25,
			},
			A2 = { note = "Turbo: also +40% reload speed", reloadSpeed = 1.4 },
			A3 = { note = "Turbo: kills extend it by 3 s", killExtend = 3 },
			B2 = { note = "Precision: no spread or bloom instead", behaviour = "Precision" },
			B3 = { note = "Precision: headshots x2", headMultiplier = 2 },
			G2 = { note = "Overheat: +60%, no ammo use, -8 HP/s for 4 s", behaviour = "Overheat" },
			G3 = { note = "Overheat: bullets pierce walls and players", pierce = true },
		},
	},
	Rollback = {
		id = "Rollback",
		name = "Rollback",
		role = "Escape",
		block = "Rewind",
		activation = "Instant",
		authority = "Simulation",
		icon = "rbxassetid://139660148791653",
		glyph = "↺",
		hint = {},
		levels = {
			L1 = {
				note = "Snap back to where you were 3 s ago, with that ammo",
				cooldown = 0, -- Recall: 1 per round, no recharge
				charges = 1,
				rewind = 3,
			},
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
	"LaunchPad",
	"Packet",
	"Firewall",
	"LagField",
	"Ping",
	"PatchUp",
	"Overclock",
	"Rollback",
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
		{ id = "Packet", level = "L1" },
		{ id = "PatchUp", level = "L1" },
	} :: { Types.SlotLoadout },

	-- Remote budgets (per player): rate per second, burst.
	RATE = {
		ModHold = { 8, 10 },
		ModUse = { 6, 8 },
		DevMod = { 6, 10 },
	},

	-- Dev test panel (DevModService): who may use it outside Studio.
	DEV_GROUP = 11116787,
	DEV_RANK = 255,
	DEV_DUMMY_DISTANCE = 12, -- studs in front of you a dummy spawns
	DEV_MAX_DUMMIES = 6,
	DEV_HURT = 50, -- "Hurt me" (never kills)
})
