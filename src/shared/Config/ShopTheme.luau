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

return table.freeze(ShopTheme)
