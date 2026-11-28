--!strict
-- Crate looks per tier (vault/01 Design/Inventory and Crates.md), from the owner's tier sheet
-- art-source/ui/shop/crates/crate_tiers.png. One crate mesh (ReplicatedStorage.Crates.Crate,
-- built by tools/studio/BuildCrate.luau); a tier only changes these colour roles.
-- Roles = the mesh part suffixes: Base_Body -> "Body", Gem_Gem -> "Gem", LatchL_Hardware -> "Hardware".

export type Role = "Body" | "Frame" | "Hardware" | "Light" | "Gem" | "Interior"
export type Look = { color: Color3, material: Enum.Material }
export type Tier = {
	name: string,
	accent: Color3, -- UI and effects colour for this tier
	roles: { [Role]: Look },
	template: string?, -- the model in ReplicatedStorage.Crates (default TEMPLATE, the big crate)
	scale: number?, -- the in-world opening's scale (default Config/CaseOpening.SCALE)
	bag: boolean?, -- a goodie bag (Util/BagOpening: it drops, wobbles, the tie pops and one prize rises out)
	pack: boolean?, -- a card pack (Util/PackOpening: it floats in front of your camera and rips open), not a crate
	blindBox: boolean?, -- a collector charm blind box (Util/BlindBoxOpening: hops, flips lid open, swings 3D charm)
}

local function look(hex: string, material: Enum.Material?): Look
	return { color = Color3.fromHex(hex), material = material or Enum.Material.SmoothPlastic }
end

local TIERS: { [number]: Tier } = {
	[1] = {
		name = "Standard",
		accent = Color3.fromHex("2FD3E6"),
		roles = {
			Body = look("5E636C"),
			Frame = look("37353D"),
			Hardware = look("A7ABB1", Enum.Material.Metal),
			Light = look("2FD3E6", Enum.Material.Neon),
			Gem = look("3FC8DD", Enum.Material.Neon),
			Interior = look("1A1C21"),
		},
	},
	[2] = {
		name = "Elite",
		accent = Color3.fromHex("FFC83D"),
		roles = {
			Body = look("5A3A8E"),
			Frame = look("3A2452"),
			Hardware = look("C9A04A", Enum.Material.Metal),
			Light = look("F5B82E", Enum.Material.Neon),
			Gem = look("E8AE34", Enum.Material.Neon),
			Interior = look("1B1424"),
		},
	},
	[3] = {
		name = "Apex",
		accent = Color3.fromHex("FF4A2A"),
		roles = {
			Body = look("2A2B2F"),
			Frame = look("46474C"),
			Hardware = look("8C9096", Enum.Material.Metal),
			Light = look("E8401F", Enum.Material.Neon),
			Gem = look("D8341E", Enum.Material.Neon),
			Interior = look("140E0E"),
		},
	},
	-- knives only (2026-11-20): dark green and bright steel with a green glow (no
	-- skin tier uses green, so it reads apart from the gun cases)
	[4] = {
		name = "Knife",
		-- its own, smaller model (owner 2026-11-20: "shorter, smaller, more like for knives"):
		-- tools/blender/crates/build_knife_case.py, 1.64 studs long, opened at 2x (3.3 studs;
		-- the big crate opens at 5)
		template = "KnifeCase",
		scale = 2.0,
		accent = Color3.fromHex("5BE35A"),
		roles = {
			Body = look("26402A"),
			Frame = look("172A1B"),
			Hardware = look("C5CAD0", Enum.Material.Metal),
			Light = look("5BE35A", Enum.Material.Neon),
			Gem = look("4FD24E", Enum.Material.Neon),
			Interior = look("0F1A11"),
		},
	},
	-- Bundle crates (owner 2026-11-25: a bought bundle throws out one crate per item "in a different
	-- colored case" and opens them all at once). Each bundle's colours (ShopCatalog BUNDLES `crate`),
	-- with gold hardware so a bundle reads apart from every case.
	[5] = {
		name = "Ruin-Blighted",
		accent = Color3.fromHex("3FE0B8"),
		roles = {
			Body = look("1F3B39"),
			Frame = look("10201F"),
			Hardware = look("D9B25A", Enum.Material.Metal),
			Light = look("3FE0B8", Enum.Material.Neon),
			Gem = look("5CF2C9", Enum.Material.Neon),
			Interior = look("0B1514"),
		},
	},
	[6] = {
		name = "Tempest-Strike",
		accent = Color3.fromHex("49B6FF"),
		roles = {
			Body = look("1E3566"),
			Frame = look("111E3B"),
			Hardware = look("D9B25A", Enum.Material.Metal),
			Light = look("49B6FF", Enum.Material.Neon),
			Gem = look("7FD0FF", Enum.Material.Neon),
			Interior = look("0B1226"),
		},
	},
	-- the SURGE power case (vault/01 Design/Loadout and Power Deck.md -> Power cases): its own compact chest
	-- (tools/blender/crates/build_power_case.py, 2.0 studs long, opened at 2x), charcoal and gold
	[7] = {
		name = "Surge",
		-- a card pack, not a case (owner 2026-11-26: "it rips open the card pack and looks cool"):
		-- tools/blender/crates/build_power_pack.py + tools/studio/BuildPack.luau; Util/PackOpening plays it
		template = "PowerPack",
		pack = true,
		scale = 2.0,
		accent = Color3.fromHex("FFC83D"),
		roles = {
			Body = look("41444C"),
			Frame = look("18191D"),
			Hardware = look("9DA2A9", Enum.Material.Metal),
			Light = look("E8AE34", Enum.Material.Neon),
			Gem = look("E8AE34", Enum.Material.Neon),
			Interior = look("141518"),
		},
	},
	[8] = {
		name = "Strike Box",
		template = "CharmBox",
		blindBox = true,
		scale = 1.25,
		accent = Color3.fromHex("F5C238"),
		roles = {
			Body = look("25282E"),
			Frame = look("111216", Enum.Material.Metal),
			Hardware = look("111216", Enum.Material.Metal),
			Light = look("F5C238", Enum.Material.Neon),
			Gem = look("F5C238", Enum.Material.Neon),
			Interior = look("08090C"),
		},
	},
	[9] = {
		name = "Overdrive Box",
		template = "CharmBox",
		blindBox = true,
		scale = 1.25,
		accent = Color3.fromHex("3FE0F2"),
		roles = {
			Body = look("181C25"),
			Frame = look("0C0E14", Enum.Material.Metal),
			Hardware = look("0C0E14", Enum.Material.Metal),
			Light = look("3FE0F2", Enum.Material.Neon),
			Gem = look("3FE0F2", Enum.Material.Neon),
			Interior = look("06070A"),
		},
	},
	-- the Season 1 goodie bag (owner 2026-11-27; tools/blender/crates/build_goodie_bag.py): Arcade purple with a gold tie
	[10] = {
		name = "Goodie Bag",
		template = "GoodieBag",
		bag = true,
		scale = 2.0,
		accent = Color3.fromHex("D6339C"),
		roles = {
			Body = look("2C1650"),
			Frame = look("47297C"),
			Hardware = look("FFC83D"),
			Light = look("3FE0F2", Enum.Material.Neon),
			Gem = look("F03CA8", Enum.Material.Neon),
			Interior = look("140A24"),
		},
	},
}

return table.freeze({
	TIERS = TIERS,
	-- the template's place in ReplicatedStorage (Studio-owned, saved with the Lobby place)
	FOLDER = "Crates",
	TEMPLATE = "Crate",
})
