--!strict
-- Gun skin tiers and what each case can give (vault/01 Design/Skin Tiers and Cases.md).
-- PROVISIONAL (owner 2026-11-20: "categorize them how you want right now, but we'll go
-- over them later"). Data only; Shared/SkinCases builds the pools and rolls from it.
--
-- Tiers, lowest to highest (owner's brief):
--   Common     reskins: new colours / textures on the stock shape
--   Rare       a change in shape that looks good (Rootglass, Sealwork), no custom animation
--   Epic       custom animation (inspects, moving parts), the tier above shape changes
--   Legendary  near-exclusive quality (animations, custom sound) that cases CAN give
--   Exclusive  only in Robux bundles, never in cases (Ruin-Blighted)
-- A skin is one gun in one line (a "pair"); a line has a tier, and single guns can be
-- lifted (the animated melee of a line).

export type TierId = "Common" | "Rare" | "Epic" | "Legendary" | "Exclusive"
export type Tier = { id: TierId, name: string, order: number, color: Color3, inCases: boolean }
export type Line = {
	tier: TierId,
	kind: "reskin" | "shape" | "animated",
	guns: { [string]: TierId }?, -- per-gun tier overrides (the line's animated melee)
}

local TIERS: { [TierId]: Tier } = {
	Common = {
		id = "Common",
		name = "COMMON",
		order = 1,
		color = Color3.fromHex("B8B8BB"),
		inCases = true,
	},
	Rare = {
		id = "Rare",
		name = "RARE",
		order = 2,
		color = Color3.fromHex("3FA9FF"),
		inCases = true,
	},
	Epic = {
		id = "Epic",
		name = "EPIC",
		order = 3,
		color = Color3.fromHex("B58CFF"),
		inCases = true,
	},
	Legendary = {
		id = "Legendary",
		name = "LEGENDARY",
		order = 4,
		color = Color3.fromHex("FFC83D"),
		inCases = true,
	},
	Exclusive = {
		id = "Exclusive",
		name = "EXCLUSIVE",
		order = 5,
		color = Color3.fromHex("FF4D8D"),
		inCases = false, -- bundles only
	},
}

-- Every line (Config/SkinPreview.LINES) and its tier. Kinds from the skin build
-- ledgers (vault/02 Art/Skins/), checked 2026-11-20.
local LINES: { [string]: Line } = {
	-- reskins
	Prism = { tier = "Common", kind = "reskin" },
	Redline = { tier = "Common", kind = "reskin" },
	Nitrous = { tier = "Common", kind = "reskin" },
	Oilwake = { tier = "Common", kind = "reskin" },
	Misprint = { tier = "Common", kind = "reskin" },
	Faultline = { tier = "Common", kind = "reskin" },
	Poolside = { tier = "Common", kind = "reskin" },
	PopCircuit = { tier = "Common", kind = "reskin", guns = { Knife = "Epic" } }, -- the Bat has its own rig and moves
	-- shape changes
	Rootglass = { tier = "Rare", kind = "shape", guns = { Knife = "Epic" } }, -- Leafblade inspect
	Sealwork = { tier = "Rare", kind = "shape" },
	Inkshift = { tier = "Rare", kind = "shape" },
	Payload = { tier = "Rare", kind = "shape" },
	Giltfold = { tier = "Rare", kind = "shape", guns = { Knife = "Epic" } }, -- the Fan opens and shuts
	Breakwater = { tier = "Rare", kind = "shape" }, -- rescue hardware, pump inspect
	-- animated
	Moltframe = { tier = "Epic", kind = "animated" }, -- flowing violet chambers, surge VFX, violet muzzle & close accents
	Playback = { tier = "Epic", kind = "animated" }, -- reactive reels & VU meter, deck VFX, retro muzzle, tape audio & custom tanto
	Sundial = { tier = "Epic", kind = "animated" }, -- escapement dial, solar VFX, golden muzzle, horological audio & astrolabe dagger
	Slipframe = { tier = "Epic", kind = "animated", guns = { Knife = "Legendary" } },
	-- legendary (cases + featured)
	Riftforge = { tier = "Legendary", kind = "animated" }, -- floating reactor core, flaring prongs & suppressor vents, plasma VFX & heavy audio
	-- bundles only
	RuinBlighted = { tier = "Exclusive", kind = "animated" },
	TempestStrike = { tier = "Exclusive", kind = "animated" }, -- Vandal, Stinger, Marshal, Bucky, Sheriff, Katana (owner 2026-11-22: final)
}

-- Knives use their line's tier like any gun (owner 2026-11-20, round 6: knives have their
-- own case now, so the old "a knife is at least Rare / Epic" floor is gone).

-- What each case holds and how it rolls (owner 2026-11-20, round 5: "tier first"; vault
-- Skin Tiers and Cases → Proposal). The roll: a SECTION by its chance (gun skins, knife
-- skins), then a TIER by its chance, then every line in that tier the SAME chance
-- (Playback = Giltfold), split across the line's guns. Tiers make a skin rarer; each
-- case is one step up (a pricier case never pays out worse: Apex has no Commons).
-- Whatever has nothing left for the player (a tier, a section) drops out and the
-- rest scale up. Knives have their own case; Apex keeps a small knife slot.
export type SectionId = "Guns" | "Knives"
export type Case = { tiers: { [TierId]: number }, sections: { [SectionId]: number } }

local SECTIONS: { [SectionId]: { name: string, order: number } } = {
	Guns = { name = "GUN SKINS", order = 1 },
	Knives = { name = "KNIFE SKINS", order = 2 },
}

local CASES: { [string]: Case } = {
	Standard = { tiers = { Common = 85, Rare = 15 }, sections = { Guns = 100 } },
	-- Gift only, never sold (owner 2026-11-25): the free case for finishing match 1 always holds an Epic gun skin.
	-- Its own case so the odds it shows are the odds it rolls (Config/Onboarding FIRST_MATCH_CASE).
	Starter = { tiers = { Epic = 100 }, sections = { Guns = 100 } },
	Elite = { tiers = { Common = 50, Rare = 40, Epic = 10 }, sections = { Guns = 100 } },
	-- Legendary drops out (and Rare / Epic scale up) until a Legendary line exists
	Apex = { tiers = { Rare = 65, Epic = 30, Legendary = 5 }, sections = { Guns = 97, Knives = 3 } },
	-- 2% total for Legendary when all tiers are eligible, split among unowned Legendary knives.
	Knife = {
		tiers = { Common = 48, Rare = 35, Epic = 15, Legendary = 2 },
		sections = { Knives = 100 },
	},
}

return table.freeze({
	TIERS = TIERS,
	LINES = LINES,
	CASES = CASES,
	SECTIONS = SECTIONS,
	ORDER = { "Common", "Rare", "Epic", "Legendary", "Exclusive" } :: { TierId },
})
