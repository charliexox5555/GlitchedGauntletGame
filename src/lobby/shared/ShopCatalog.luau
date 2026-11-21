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
	robux: number?, -- its own price when sold alone (else ITEM_ROBUX by kind and rarity)
}

export type Case = {
	id: string,
	name: string,
	coins: number,
	robux: number,
	robux3: number, -- three at once
	color: Color3,
	art: string?, -- the case picture: a render of the 3D crate (tools/blender/crates/render_icons.py, cropped)
	-- what it gives comes from the skin tiers: Shared/SkinCases.contents(id) (Config/Skins)
}

export type Bundle = {
	id: string,
	name: string,
	robux: number,
	color: Color3,
	items: { Item },
}

local ShopCatalog = {}

-- Shared art ids (art-source/ui/shop/, uploaded 2026-11-16) for screens that
-- show shop things outside the Shop (the Season Pass). The Shop's builder has
-- its own copy in tools/studio/BuildShop.luau.
ShopCatalog.ART = table.freeze({
	coin = "rbxassetid://126250416946442",
	coinStack = "rbxassetid://77893326046955",
	seasonPass = "rbxassetid://129516715347397",
})

ShopCatalog.RARITY_COLOR = table.freeze({
	Common = Color3.fromHex("B8B8BB"),
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
		art = "rbxassetid://122735078835784", -- the 3D crate render (art-source/ui/shop/crates/crate_standard_wide.png; the Home card uses crate_standard_card.png)
		coins = 400,
		robux = 99,
		robux3 = 249,
		color = Color3.fromHex("69696C"),
	},
	{
		id = "Elite",
		name = "ELITE CASE",
		art = "rbxassetid://120685505151159", -- crate_elite_wide.png
		coins = 900,
		robux = 199,
		robux3 = 499,
		color = Color3.fromHex("6A3FC2"),
	},
	{
		id = "Apex",
		name = "APEX CASE",
		art = "rbxassetid://87218064940726", -- crate_apex_wide.png
		coins = 2000,
		robux = 399,
		robux3 = 999,
		color = Color3.fromHex("C2412F"),
	},
	{
		id = "Knife", -- knives only (owner 2026-11-20)
		name = "KNIFE CASE",
		art = "rbxassetid://75937518028942", -- crate_knife_wide.png
		coins = 2500,
		robux = 499,
		robux3 = 1249,
		color = Color3.fromHex("1E8A5C"),
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

-- What an item costs on its own, in Robux, when it has no price of its own
-- (PLACEHOLDER prices). A bundle's "separately" total is the sum of these:
-- a real price you'd pay item by item, never an invented "value".
ShopCatalog.ITEM_ROBUX = table.freeze({
	Skin = { Common = 249, Rare = 349, Epic = 479, Legendary = 599 },
	Charm = { Common = 99, Rare = 149, Epic = 199, Legendary = 249 },
	Emote = { Common = 149, Rare = 199, Epic = 249, Legendary = 299 },
	Mod = { Common = 299, Rare = 349, Epic = 399, Legendary = 449 },
}) :: { [string]: { [string]: number } }

function ShopCatalog.itemRobux(item: Item): number?
	if item.robux then
		return item.robux
	end
	local byRarity = ShopCatalog.ITEM_ROBUX[item.kind]
	return if byRarity then byRarity[item.rarity or "Common"] else nil
end

-- The bundle's items bought one by one (coins aren't sold alone here, so
-- they don't count).
function ShopCatalog.separately(bundle: Bundle): number
	local total = 0
	for _, item in bundle.items do
		total += ShopCatalog.itemRobux(item) or 0
	end
	return total
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
