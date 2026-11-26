--!strict
-- What this build ships (owner 2026-11-22, vault/05 Production/Release Plan 2026-11-22.md).
-- A feature set to false is hidden from players but its code and builds stay in place,
-- so it can come back in a later update by flipping the flag.
local Release = {}

-- The shooting range (the lobby bar's RANGE button, the hub's hologram gate). Opened 2026-11-26 (owner: "now it's
-- time to open up the range in the lobby").
Release.RANGE_OPEN = true

-- The Battle Pass (Shop's Season Pass card, the world sign, the Router menu). Not in the first update:
-- the Backpack replaced it (vault/01 Design/Inventory and Crates.md).
Release.BATTLE_PASS_OPEN = false

-- The Shop's full layout (Home charms + emotes, the Thanksgiving "LIMITED TIME" bundle). false = the
-- launch layout: Home = CASES + SPECIAL OFFERS only, Bundles = Ruin-Blighted, Tempest-Strike + the
-- Starter Bundle. The Studio screen marks its parts with attributes (ShopController applies them):
-- FullOnly / LaunchOnly (bool), LaunchSize / LaunchCellPadding (UDim2), LaunchMaxCells. The full layout is
-- recorded in vault/02 Art/UI Shop.md → Release layout.
Release.SHOP_FULL_LAYOUT = false

return table.freeze(Release)
