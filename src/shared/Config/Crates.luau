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
}

return table.freeze({
	TIERS = TIERS,
	-- the template's place in ReplicatedStorage (Studio-owned, saved with the Lobby place)
	FOLDER = "Crates",
	TEMPLATE = "Crate",
})
