--!strict
-- What the Shop sells (vault/02 Art/UI Shop.md), one table the shop UI reads
-- and the economy will read too (prices, case contents and odds). PLACEHOLDER
-- content until the owner fills it: names, prices and weights are examples.
--
-- Cases are paid random items (owner 2026-11-16: "paid cases, done right"):
-- every case lists every outcome with a weight; the shown odds are weight /
-- total, from this same table the server will roll from. No duplicates of
-- owned cosmetics (the economy re-rolls those). Cases are hidden for players
-- where PolicyService says paid random items are restricted.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"
export type Kind = "Skin" | "Charm" | "Emote" | "Mod" | "Coins" | "Case"

export type Item = {
	kind: Kind,
	name: string, -- display name
	gun: string?, -- the gun a skin is for (Config/Weapons id)
	line: string?, -- the skin line (Shared/Locker lines), for its emblem and colour
	amount: number?, -- Coins, or a count
	rarity: Rarity?,
	weight: number?, -- cases only
}

export type Case = {
	id: string,
	name: string,
	coins: number,
	robux: number,
	robux3: number, -- three at once
	color: Color3,
	contents: { Item },
}

export type Bundle = {
	id: string,
	name: string,
	robux: number,
	color: Color3,
	items: { Item },
}

local ShopCatalog = {}

ShopCatalog.RARITY_COLOR = table.freeze({
	Common = Color3.fromHex("AEB8D6"),
	Rare = Color3.fromHex("3FA9FF"),
	Epic = Color3.fromHex("B58CFF"),
	Legendary = Color3.fromHex("FFC83D"),
}) :: { [string]: Color3 }

-- the odds disclaimer shown under every case's contents
ShopCatalog.ODDS_NOTE = "Odds are per opening and add up to 100%. You never get a cosmetic you already own: "
	.. "an owned one is re-rolled from the rest, so your odds for the others go up. "
	.. "Cases aren't sold where local rules restrict paid random items."

ShopCatalog.CASES = {
	{
		id = "Standard",
		name = "STANDARD CASE",
		coins = 400,
		robux = 99,
		robux3 = 249,
		color = Color3.fromHex("5D6B82"),
		contents = {
			{
				kind = "Skin",
				name = "REDLINE CLASSIC",
				gun = "Classic",
				line = "Redline",
				rarity = "Common",
				weight = 30,
			},
			{
				kind = "Skin",
				name = "REDLINE SPECTRE",
				gun = "Spectre",
				line = "Redline",
				rarity = "Common",
				weight = 30,
			},
			{
				kind = "Skin",
				name = "NITROUS SHORTY",
				gun = "Shorty",
				line = "Nitrous",
				rarity = "Rare",
				weight = 18,
			},
			{
				kind = "Skin",
				name = "SEALWORK GUARDIAN",
				gun = "Guardian",
				line = "Sealwork",
				rarity = "Rare",
				weight = 12,
			},
			{
				kind = "Skin",
				name = "PRISM VANDAL",
				gun = "Vandal",
				line = "Prism",
				rarity = "Epic",
				weight = 8,
			},
			{
				kind = "Skin",
				name = "GILTFOLD SHERIFF",
				gun = "Sheriff",
				line = "Giltfold",
				rarity = "Legendary",
				weight = 2,
			},
		},
	},
	{
		id = "Elite",
		name = "ELITE CASE",
		coins = 900,
		robux = 199,
		robux3 = 499,
		color = Color3.fromHex("6A3FC2"),
		contents = {
			{
				kind = "Skin",
				name = "NITROUS SPECTRE",
				gun = "Spectre",
				line = "Nitrous",
				rarity = "Rare",
				weight = 35,
			},
			{
				kind = "Skin",
				name = "POPCIRCUIT BUCKY",
				gun = "Bucky",
				line = "PopCircuit",
				rarity = "Rare",
				weight = 30,
			},
			{
				kind = "Skin",
				name = "MOLTFRAME VANDAL",
				gun = "Vandal",
				line = "Moltframe",
				rarity = "Epic",
				weight = 20,
			},
			{
				kind = "Skin",
				name = "PAYLOAD OPERATOR",
				gun = "Operator",
				line = "Payload",
				rarity = "Epic",
				weight = 12,
			},
			{
				kind = "Skin",
				name = "INKSHIFT VANDAL",
				gun = "Vandal",
				line = "Inkshift",
				rarity = "Legendary",
				weight = 3,
			},
		},
	},
	{
		id = "Apex",
		name = "APEX CASE",
		coins = 2000,
		robux = 399,
		robux3 = 999,
		color = Color3.fromHex("C2412F"),
		contents = {
			{
				kind = "Skin",
				name = "MOLTFRAME SPECTRE",
				gun = "Spectre",
				line = "Moltframe",
				rarity = "Epic",
				weight = 40,
			},
			{
				kind = "Skin",
				name = "SEALWORK OPERATOR",
				gun = "Operator",
				line = "Sealwork",
				rarity = "Epic",
				weight = 35,
			},
			{
				kind = "Skin",
				name = "GILTFOLD VANDAL",
				gun = "Vandal",
				line = "Giltfold",
				rarity = "Legendary",
				weight = 15,
			},
			{
				kind = "Skin",
				name = "POPCIRCUIT BAT",
				gun = "Knife",
				line = "PopCircuit",
				rarity = "Legendary",
				weight = 10,
			},
		},
	},
} :: { Case }

ShopCatalog.BUNDLES = {
	{
		id = "Neon",
		name = "NEON BUNDLE",
		robux = 975,
		color = Color3.fromHex("2B6FE0"),
		items = {
			{
				kind = "Skin",
				name = "NITROUS VANDAL",
				gun = "Vandal",
				line = "Nitrous",
				rarity = "Epic",
			},
			{
				kind = "Skin",
				name = "NITROUS SPECTRE",
				gun = "Spectre",
				line = "Nitrous",
				rarity = "Rare",
			},
			{ kind = "Mod", name = "OVERDRIVE", rarity = "Legendary" },
			{ kind = "Charm", name = "NEON FANG", rarity = "Rare" },
			{ kind = "Coins", name = "COINS", amount = 1500 },
		},
	},
	{
		id = "Ember",
		name = "EMBER BUNDLE",
		robux = 649,
		color = Color3.fromHex("C2412F"),
		items = {
			{
				kind = "Skin",
				name = "REDLINE VANDAL",
				gun = "Vandal",
				line = "Redline",
				rarity = "Rare",
			},
			{
				kind = "Skin",
				name = "REDLINE SHERIFF",
				gun = "Sheriff",
				line = "Redline",
				rarity = "Rare",
			},
			{ kind = "Emote", name = "WARM UP", rarity = "Rare" },
			{ kind = "Coins", name = "COINS", amount = 800 },
		},
	},
	{
		id = "Frost",
		name = "FROST BUNDLE",
		robux = 289,
		color = Color3.fromHex("2BB7D9"),
		items = {
			{
				kind = "Skin",
				name = "INKSHIFT CLASSIC",
				gun = "Classic",
				line = "Inkshift",
				rarity = "Rare",
			},
			{ kind = "Charm", name = "ICE SHARD", rarity = "Common" },
			{ kind = "Coins", name = "COINS", amount = 300 },
		},
	},
	{
		id = "Heavy",
		name = "HEAVY DUTY BUNDLE",
		robux = 1425,
		color = Color3.fromHex("C9822B"),
		items = {
			{
				kind = "Skin",
				name = "PAYLOAD ODIN",
				gun = "Odin",
				line = "Payload",
				rarity = "Epic",
			},
			{
				kind = "Skin",
				name = "PAYLOAD JUDGE",
				gun = "Judge",
				line = "Payload",
				rarity = "Epic",
			},
			{ kind = "Mod", name = "BULWARK", rarity = "Legendary" },
			{ kind = "Emote", name = "SALUTE", rarity = "Rare" },
			{ kind = "Coins", name = "COINS", amount = 2500 },
		},
	},
	{
		id = "Classic",
		name = "CLASSIC BUNDLE",
		robux = 865,
		color = Color3.fromHex("6A3FC2"),
		items = {
			{
				kind = "Skin",
				name = "GILTFOLD CLASSIC",
				gun = "Classic",
				line = "Giltfold",
				rarity = "Epic",
			},
			{
				kind = "Skin",
				name = "SEALWORK SHERIFF",
				gun = "Sheriff",
				line = "Sealwork",
				rarity = "Epic",
			},
			{ kind = "Charm", name = "OLD COIN", rarity = "Rare" },
			{ kind = "Coins", name = "COINS", amount = 1000 },
		},
	},
} :: { Bundle }

-- Odds for each item of a case, in %, from its weights (they add up to 100).
function ShopCatalog.odds(case: Case): { number }
	local total = 0
	for _, item in case.contents do
		total += item.weight or 0
	end
	local out: { number } = {}
	for i, item in case.contents do
		out[i] = if total > 0 then (item.weight or 0) / total * 100 else 0
	end
	return out
end

-- A percentage for the odds list: at least four digits after the first
-- non-zero one (Roblox's rule for paid random items), trailing zeros trimmed.
function ShopCatalog.formatOdds(pct: number): string
	if pct <= 0 then
		return "0%"
	end
	local digits = math.max(0, 3 - math.floor(math.log10(pct)))
	local s = string.format("%." .. digits .. "f", pct)
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s .. "%"
end

function ShopCatalog.case(id: string): Case?
	for _, c in ShopCatalog.CASES do
		if c.id == id then
			return c
		end
	end
	return nil
end

function ShopCatalog.bundle(id: string): Bundle?
	for _, b in ShopCatalog.BUNDLES do
		if b.id == id then
			return b
		end
	end
	return nil
end

return ShopCatalog
