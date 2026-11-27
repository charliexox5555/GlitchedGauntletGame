--!strict
-- Power case odds (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26: "rank powers in
-- tiers so there are better powers that will be lower chances"). Like the skin cases, a TIER is rolled first
-- (by WEIGHTS, among the tiers that still hold a power the player doesn't own), then every unowned power in it has
-- the same chance. Never a duplicate. Tier ids, names and colours are the skin tiers' (Config/Skins TIERS), so
-- the opening's effects grow with the tier (Config/CaseOpening TIER_FX).
-- PROPOSED ranking (Claude, 2026-11-26), the owner tunes it: the stronger the swing in a duel, the rarer.

return table.freeze({
	TIER_OF = table.freeze({
		Recon = "Common",
		HealOrb = "Common",
		Stim = "Common",
		Firewall = "Rare",
		Recall = "Rare",
		Flash = "Epic",
		ShockDart = "Epic",
		Roller = "Legendary",
	} :: { [string]: string }),
	-- a power not listed above (a new one) is this tier until it's ranked
	DEFAULT_TIER = "Rare",
	-- tier chances before renormalising over the tiers that still have something for the player
	WEIGHTS = table.freeze({
		Common = 55,
		Rare = 28,
		Epic = 13,
		Legendary = 4,
	} :: { [string]: number }),
})
