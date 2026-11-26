--!strict
-- What the Shop sells (vault/02 Art/UI Shop.md), one table the shop UI reads
-- and the economy will read too (prices, case contents and odds). PLACEHOLDER
-- content until the owner fills it: names, prices and weights are examples.
--
-- Cases cost Tickets only (Config/Economy.CASE_TICKETS; owner 2026-11-22). Tickets are
-- earned and never sold, so a case is not a paid random item. NEVER put a case or
-- Tickets inside anything bought with Robux or coins without the PolicyService gate.
-- Odds still show for every case (Shared/SkinCases, the same table the server rolls).

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
	productId: number?, -- dedicated product when sold alone
}

export type Case = {
	id: string,
	name: string,
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
	hero: string?, -- the card's big picture (a Studio hero render, tools/studio/RenderHeroShots.luau)
	banner: string?, -- the card's background art (Gemini / ChatGPT, vault Shop Economy → Art prompts); flat colour until set
	crate: number?, -- Config/Crates look of its opening (one crate per item); none = the YOU GOT popup only
}

local Products = require(game:GetService("ReplicatedStorage").Shared.Config.Products)

local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)

local ShopCatalog = {}

-- Shared art ids (art-source/ui/shop/, uploaded 2026-11-16) for screens that
-- show shop things outside the Shop (the Season Pass). The Shop's builder has
-- its own copy in tools/studio/BuildShop.luau.
-- Coin pack pictures, Pack1..Pack6 (art-source/ui/shop/new/pack_1..6.png, ChatGPT 2026-11-22,
-- vault Prompts/2026-11-22 Shop Art Master Prompt). Empty = the Studio picture stays.
ShopCatalog.PACK_ART = table.freeze({
	"rbxassetid://133249202687167", -- pack_1 small pile
	"rbxassetid://92145452769066", -- pack_2 short stack
	"rbxassetid://90207390989766", -- pack_3 two tall stacks
	"rbxassetid://80029818066118", -- pack_4 pouch
	"rbxassetid://100700481422006", -- pack_5 chest
	"rbxassetid://132442670633809", -- pack_6 vault crate
}) :: { string }
-- The coin pack cards' backdrop (one image for all six; new/pack_backdrop.png); "" = flat colour.
ShopCatalog.PACK_BACKDROP = "rbxassetid://111801042683623"

ShopCatalog.ART = table.freeze({
	coin = "rbxassetid://126250416946442",
	coinStack = "rbxassetid://77893326046955",
	starterContents = "rbxassetid://97381557374007",
	ticket = "rbxassetid://118693853905400", -- the Ticket currency icon (new/ticket.png)
	starterBanner = "rbxassetid://96454339687407", -- also on HOME's special offer card
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
ShopCatalog.ODDS_NOTE = "These are your odds for the next case. Owned skins have a 0% chance. "
	.. "Each crate in OPEN 3 uses updated odds. "
	.. "Cases aren't sold where local rules restrict paid random items."

ShopCatalog.CASES = {
	{
		id = "Standard",
		name = "STANDARD CASE",
		art = "rbxassetid://122735078835784", -- the 3D crate render (art-source/ui/shop/crates/crate_standard_wide.png; the Home card uses crate_standard_card.png)
		color = Color3.fromHex("69696C"),
	},
	-- gift only (Config/Skins CASES.Starter): listed so the Backpack can show and open it; the Shop has no card for it
	{
		id = "Starter",
		name = "STARTER CASE",
		art = "rbxassetid://120685505151159", -- the Elite crate render until it has its own
		color = Color3.fromHex("6A3FC2"),
	},
	{
		id = "Elite",
		name = "ELITE CASE",
		art = "rbxassetid://120685505151159", -- crate_elite_wide.png
		color = Color3.fromHex("6A3FC2"),
	},
	{
		id = "Apex",
		name = "APEX CASE",
		art = "rbxassetid://87218064940726", -- crate_apex_wide.png
		color = Color3.fromHex("C2412F"),
	},
	{
		id = "Knife", -- knives only (owner 2026-11-20)
		name = "KNIFE CASE",
		art = "rbxassetid://75937518028942", -- crate_knife_wide.png
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
		name = lineName .. " " .. string.upper(shown or Weapons.nameOf(gun)), -- `shown`: a knife-slot item's own name
		gun = gun,
		line = line,
		rarity = rarity,
	}
end

ShopCatalog.BUNDLES = {
	{
		id = "RuinBlighted",
		name = "RUIN-BLIGHTED",
		robux = 999,
		hero = "rbxassetid://122434274434504", -- art-source/ui/shop/heroes/hero_ruinblighted.png
		banner = "rbxassetid://114348398658883", -- art-source/ui/shop/new/banner_ruinblighted.png
		color = Color3.fromHex("2A6F6A"),
		crate = 5,
		slot = "Featured",
		tag = "EXCLUSIVE",
		sub = "5 GUNS + THE RUINED REAVER",
		items = {
			skin("RuinBlighted", "RUIN-BLIGHTED", "Vandal", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Spectre", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Ghost", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Guardian", "Exclusive"),
			skin("RuinBlighted", "RUIN-BLIGHTED", "Operator", "Exclusive"),
			{
				kind = "Skin",
				name = "RUINED REAVER",
				productId = Products.RUINED_REAVER.id,
				gun = "Knife",
				line = "RuinBlighted",
				rarity = "Exclusive",
			},
		},
	},
	{
		id = "TempestStrike",
		name = "TEMPEST-STRIKE",
		robux = 1099,
		hero = "rbxassetid://78378943251206", -- art-source/ui/shop/heroes/hero_tempeststrike.png
		banner = "rbxassetid://131808642557103", -- art-source/ui/shop/new/banner_tempeststrike.png
		color = Color3.fromHex("2F5DB8"),
		crate = 6,
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
		-- Price 67 R$ (owner 2026-11-22); contents come with the economy build (vault/01 Design/Shop Economy and Art v1.md).
		id = "Starter",
		name = "STARTER BUNDLE",
		robux = 67,
		color = Color3.fromHex("2E7D5B"),
		slot = "Starter",
		tag = "NEW PLAYERS",
		sub = "2 CASES + 1,500 COINS + 3 TICKETS", -- Config/Products.STARTER grants it
		banner = "rbxassetid://96454339687407", -- art-source/ui/shop/new/banner_starter.png (ART.starterBanner)
		items = {},
	},
} :: { Bundle }

-- The daily shop is per player now (Shared/DailyShop, Shared/DailyRoll, prices in
-- Config/Economy.DAILY_COINS / SKIN_ROBUX; owner 2026-11-22).

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
	if item.productId then
		local product = Products.BY_ID[item.productId]
		return if product then product.robux else nil
	end
	if item.robux then
		return item.robux
	end
	-- a bundle skin bought alone (Config/Products.BUNDLE_ITEM_ROBUX: guns 349, knife 449)
	if item.kind == "Skin" and item.rarity == "Exclusive" then
		local each = Products.BUNDLE_ITEM_ROBUX
		return if item.gun == "Knife" then each.knife else each.gun
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

function ShopCatalog.featuredBundles(includeStarter: boolean, fullLayout: boolean): { Bundle }
	local featured: { Bundle } = {}
	local starter = ShopCatalog.bundle("Starter")
	if includeStarter and starter and not starter.soon then
		table.insert(featured, starter)
	end
	for _, bundle in ShopCatalog.BUNDLES do
		if
			not bundle.soon
			and #bundle.items > 0
			and (bundle.slot == "Featured" or (fullLayout and bundle.slot == "Limited"))
		then
			table.insert(featured, bundle)
		end
	end
	return featured
end

return ShopCatalog
