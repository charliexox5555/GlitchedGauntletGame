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
}

return table.freeze({
	TIERS = TIERS,
	-- the template's place in ReplicatedStorage (Studio-owned, saved with the Lobby place)
	FOLDER = "Crates",
	TEMPLATE = "Crate",
})
