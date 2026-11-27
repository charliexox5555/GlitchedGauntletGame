--!strict
-- The gun loadout (vault/01 Design/Loadout and Power Deck.md → "Step 2 plan"): guns are owned (coins unlock
-- them) and a primary + secondary is picked in the Locker before the match; round 1 is secondary only.
-- Only these guns are offered, sold and listed; the rest of Config/Weapons is parked (data kept).

return table.freeze({
	-- Locker order (Config/Weapons ids; display names in brackets)
	PRIMARIES = table.freeze({
		"Vandal", -- Havoc, rifle (starter)
		"Spectre", -- Prowler, SMG
		"Stinger", -- Hornet, SMG (back 2026-11-27)
		"Bucky", -- Pump, shotgun
		"Bulldog", -- Lancer, burst rifle
		"Guardian", -- Marksman, DMR
		"Marshal", -- Scout, light sniper (back 2026-11-27)
		"Phantom", -- Spirit, silenced rifle
		"Odin", -- Mauler, LMG
		"Operator", -- Deadeye, sniper
	}),
	SECONDARIES = table.freeze({
		"Classic", -- (starter)
		"Sheriff",
		"Shorty",
		"Ghost", -- Hush
	}),

	-- Every save owns and equips these.
	STARTER = table.freeze({ Primary = "Vandal", Secondary = "Classic" }),

	-- Coins to unlock (placeholders until the economy pass, build order step 4).
	PRICES = table.freeze({
		Sheriff = 400,
		Shorty = 400,
		Ghost = 500,
		Spectre = 500,
		Stinger = 600,
		Bucky = 600,
		Bulldog = 750,
		Guardian = 900,
		Marshal = 1000,
		Phantom = 1000,
		Odin = 1200,
		Operator = 1500,
	} :: { [string]: number }),

	-- Rounds 1..N give only the secondary; later rounds give primary + secondary.
	SECONDARY_ROUNDS = 1,

	-- One-line role under the gun's name in the Locker (Locker v3 mockup wording; the 2026-11-27 balance pass,
	-- vault/01 Design/Gun Balance.md, says what each gun is for).
	ROLES = table.freeze({
		Vandal = {
			"RIFLE · ALL-ROUNDER",
			"Steady at every range. The honest pick that always works.",
		},
		Spectre = {
			"SMG · STEADY",
			"Quiet and easy to control. The SMG that still hits at mid range.",
		},
		Stinger = {
			"SMG · BULLET HOSE",
			"The fastest trigger in the game. Hold on through the kick.",
		},
		Bucky = { "SHOTGUN · CLOSE BURST", "One big burst up close. Pick your corners." },
		Bulldog = { "BURST RIFLE · PRECISE", "Three-round bursts that stay on target." },
		Guardian = {
			"DMR · MARKSMAN",
			"Semi-auto and dead on when aimed. Three to the head ends it.",
		},
		Marshal = {
			"SNIPER · QUICK",
			"Light and fast, accurate from the hip. Head, then body, and they drop.",
		},
		Phantom = { "SILENCED RIFLE · QUIET", "No tracers. They never see where it came from." },
		Odin = { "LMG · SUPPRESS", "A huge magazine that takes a moment to spin up." },
		Operator = { "SNIPER · ONE-SHOT", "One headshot ends it. Miss and you're exposed." },
		Classic = { "PISTOL · RELIABLE", "Quick to draw, easy to land. Never a bad call." },
		Sheriff = { "REVOLVER · HEAVY", "Slow, loud, and one tap to the head up close." },
		Shorty = { "POCKET SHOTGUN", "Two shells for when they get too close." },
		Ghost = { "SILENCED PISTOL", "Quiet and accurate. Finish what your primary started." },
	} :: { [string]: { string } }),
})
