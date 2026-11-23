--!strict
-- Avatar source IDs stay on the Match server. Add approved Roblox user IDs here.

return table.freeze({
	BACKUP_USER_IDS = {} :: { number },
	FRIENDS_PER_PLAYER = 64,
	FRIEND_PAGES = 2,
	-- Bot outfits built ahead (each a full avatar: many asset downloads). 2026-11-23: 10 / 3 at a cold server's
	-- start flooded its downloads (animations and body meshes failed, a save read took ~58 s); a 2v2 needs <= 3.
	AVATAR_TEMPLATES = 4,
	AVATAR_WORKERS = 1,
	PREFETCH_DELAY = 6, -- seconds after the server starts before outfits are built (players' own assets first)
	FRIEND_ATTEMPTS = 20,
	BACKUP_ATTEMPTS = 8,
	FIRST_SPAWN_LOOK_WAIT = 5.5,
	STARTER_SKIN_CHANCE = 0.6,
	DEVICES = { "PC", "PC", "PC", "Mobile", "Mobile", "Console" },

	NAMES = {
		"mossbyte",
		"hushorbit",
		"JuniperRush",
		"cobalt_owl",
		"riverarc",
		"slowcomet",
		"mikaAfterDark",
		"TessOnRails",
		"SpruceShift",
		"BenchCloud",
		"nicozip",
		"lumenloop",
		"CrateSparrow",
		"JunoDrift",
		"aero_peach",
		"northgrove",
		"cinderkite",
		"SidewalkFern",
		"littleHalftone",
		"mellowpixel",
	},

	-- Weight, level range, number of weapons equipped with a skin.
	PROFILES = {
		{ weight = 30, level = { 2, 17 }, skins = { 0, 1 } },
		{ weight = 55, level = { 14, 39 }, skins = { 1, 4 } },
		{ weight = 15, level = { 34, 72 }, skins = { 3, 6 } },
	},

	FALLBACK_SKIN = { 0xF1C49A, 0xD59B72, 0xAF7858, 0x784A38, 0xC88564 },
	FALLBACK_TOP = { 0x344E6C, 0x755764, 0x536653, 0xBCAE95, 0x626188, 0x854836 },
	FALLBACK_PANTS = { 0x353742, 0x3A4C5C, 0x514A3B, 0x4C4157, 0x383D3A },
})
