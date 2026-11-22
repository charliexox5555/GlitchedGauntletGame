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

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Exclusive"
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
	slot: "Featured" | "Limited" | "Starter", -- where it sits on the BUNDLES tab
	tag: string?, -- the small tag under the name
	sub: string?, -- one line under the name (what's in it)
	soon: boolean?, -- contents not decided yet: the card says so and doesn't open
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
	Exclusive = Color3.fromHex("FF4D8D"),
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

-- The launch bundles (owner 2026-11-20): two featured skin-line bundles and a
-- Thanksgiving bundle. PLACEHOLDER prices; the Thanksgiving contents are still
-- to be decided. Tempest-Strike is final (owner 2026-11-22): five guns and the
-- Katana in the knife slot, bundle-only (Config/Skins: Exclusive).
local function skin(
	line: string,
	lineName: string,
	gun: string,
	rarity: Rarity,
	shown: string?
): Item
	return {
		kind = "Skin",
		name = lineName .. " " .. string.upper(shown or gun), -- `shown`: a knife-slot item's own name
		gun = gun,
		line = line,
		rarity = rarity,
	}
end

ShopCatalog.BUNDLES = {
	{
		id = "RuinBlighted",
		name = "RUIN-BLIGHTED",
		robux = 1999,
		color = Color3.fromHex("2A6F6A"),
		slot = "Featured",
		tag = "EXCLUSIVE",
		sub = "5 EXCLUSIVE SKINS",
		items = {
			skin("RuinBlighted", "RUIN-BLIGHTED", "Vandal", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Spectre", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Ghost", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Guardian", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Operator", "Exclusive"),
		},
	},
	{
		id = "TempestStrike",
		name = "TEMPEST-STRIKE",
		robux = 1499,
		color = Color3.fromHex("2F5DB8"),
		slot = "Featured",
		tag = "NEW",
		sub = "5 GUNS + THE KATANA",
		items = {
			skin("TempestStrike", "TEMPEST-STRIKE", "Vandal", "Exclusive"),
			skin("TempestStrike", "TEMPEST-STRIKE", "Stinger", "Exclusive"),
			skin("TempestStrike", "TEMPEST-STRIKE", "Marshal", "Exclusive"),
			skin("TempestStrike", "TEMPEST-STRIKE", "Bucky", "Exclusive"),
			skin("TempestStrike", "TEMPEST-STRIKE", "Sheriff", "Exclusive"),
			skin("TempestStrike", "TEMPEST-STRIKE", "Knife", "Exclusive", "Katana"),
		},
	},
	{
		id = "Thanksgiving",
		name = "THANKSGIVING BUNDLE",
		robux = 799,
		color = Color3.fromHex("C9822B"),
		slot = "Limited",
		tag = "LIMITED TIME",
		sub = "CONTENTS COMING SOON",
		soon = true,
		items = {},
	},
	{
		-- launch layout only (Config/Release.SHOP_FULL_LAYOUT; Studio `Bundles.Row3`, LaunchOnly).
		-- PLACEHOLDER price and contents: the owner sets them in the pricing pass.
		id = "Starter",
		name = "STARTER BUNDLE",
		robux = 99,
		color = Color3.fromHex("2E7D5B"),
		slot = "Starter",
		tag = "NEW PLAYERS",
		sub = "CONTENTS COMING SOON",
		soon = true,
		items = {},
	},
} :: { Bundle }

-- Today's items (the DAILY tab's eight cards). PLACEHOLDER stock with real skins so
-- the tab shows real pictures; the daily rotation (same for everyone, 00:00 UTC) and
-- buying come with the economy. Price in coins by the skin's tier (Config/Skins).
ShopCatalog.DAILY = {
	{ gun = "Phantom", line = "Playback" },
	{ gun = "Sheriff", line = "Sealwork" },
	{ gun = "Knife", line = "Giltfold" },
	{ gun = "Vandal", line = "Redline" },
	{ gun = "Vandal", line = "Prism" },
	{ gun = "Spectre", line = "Rootglass" },
	{ gun = "Odin", line = "Payload" },
	{ gun = "Ghost", line = "Misprint" },
} :: { { gun: string, line: string } }
ShopCatalog.DAILY_COINS =
	table.freeze({ Common = 600, Rare = 900, Epic = 1400, Legendary = 2000 }) :: { [string]: number }

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
