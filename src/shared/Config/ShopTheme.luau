--!strict
-- The Shop's colours (owner 2026-11-22: scheme A "Night market", vault/01 Design/Shop
-- Economy and Art v1.md → Look pass). Same plates, buttons and layout as before; only the
-- colours change. Studio's screen is recoloured from these by tools/studio/ShopTheme.luau;
-- ShopController uses them for what it colours at run time.
local ShopTheme = {}

ShopTheme.PAGE = Color3.fromHex("17132A") -- the wash over the blurred lobby
ShopTheme.WASH_T = 0.12 -- how see-through that wash is (the lobby barely shows, like RIVALS)
ShopTheme.DIM = Color3.fromHex("0E0B1A") -- behind popups
ShopTheme.PANEL = Color3.fromHex("241D40") -- cards, popups, tabs that are off
ShopTheme.INNER = Color3.fromHex("2F2752") -- a card's art area (until banner art)
ShopTheme.DEEP = Color3.fromHex("1A1530") -- item tiles, wells
ShopTheme.GOLD = Color3.fromHex("FFC83D") -- the active tab, today's login reward, coins
ShopTheme.ON_GOLD = Color3.fromHex("3A2A00") -- words on gold
ShopTheme.MUTED = Color3.fromHex("CFC8F0") -- words on panels that are off
ShopTheme.ROBUX = Color3.fromHex("3FD45C") -- anything priced in Robux

-- The DAILY cards (owner 2026-11-28, "make it look better"; Util/DailyCard). `wash` = how far
-- a card's back leans toward its tier colour (top of the card; the bottom keeps a third of
-- it), so Epic and Legendary read from across the page without an outline or a glow.
ShopTheme.DAILY = table.freeze({
	wash = table.freeze({ Common = 0, Rare = 0.1, Epic = 0.26, Legendary = 0.34 }) :: { [string]: number },
	washBottom = 0.35,
	ownedPic = Color3.fromHex("B8B4CC"), -- an owned skin's picture, a little dimmed
	lockedPic = Color3.fromHex("5A566E"), -- a locked gun's skin: the shape still shows (a tease)
	badge = Color3.fromHex("1A1530"), -- the GUN LOCKED plate (DEEP)
	badgeText = Color3.fromHex("CFC8F0"), -- MUTED
	quietPlate = Color3.fromHex("1A1530"), -- the price plate when it isn't a price (OWNED, UNLOCK)
})

return table.freeze(ShopTheme)
