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
	Moltframe = { tier = "Rare", kind = "shape" }, -- Legendary once the chamber flow ships
	Breakwater = { tier = "Rare", kind = "shape" }, -- rescue hardware, pump inspect
	-- animated
	Playback = { tier = "Epic", kind = "animated" }, -- reel window, animated inspect
	Sundial = { tier = "Epic", kind = "animated" }, -- turning dial
	-- bundles only
	RuinBlighted = { tier = "Exclusive", kind = "animated" },
}

-- Chance of each tier per case (relative weights; a tier with nothing left to
-- give drops out and the rest scale up). Owner's brief: the lowest case gives
-- reskins only; the middle one reskins and shape changes with a very low chance
-- of animated; the top case can give everything except Exclusive.
local CASE_ODDS: { [string]: { [TierId]: number } } = {
	Standard = { Common = 100 },
	Elite = { Common = 80, Rare = 19, Epic = 1 },
	Apex = { Common = 50, Rare = 33, Epic = 13, Legendary = 4 },
}

return table.freeze({
	TIERS = TIERS,
	LINES = LINES,
	CASE_ODDS = CASE_ODDS,
	ORDER = { "Common", "Rare", "Epic", "Legendary", "Exclusive" } :: { TierId },
})
