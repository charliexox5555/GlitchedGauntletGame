--!strict
-- What this build ships (owner 2026-11-22, vault/05 Production/Release Plan 2026-11-22.md).
-- A feature set to false is hidden from players but its code and builds stay in place,
-- so it can come back in a later update by flipping the flag.
local Release = {}

-- The shooting range (lobby bar button, the hologram entrance, the entrance prompt). Closed for this update.
Release.RANGE_OPEN = false

-- The Battle Pass (Shop's Season Pass card, the world sign, the Router menu). Not in the first update:
-- the Backpack replaced it (vault/01 Design/Inventory and Crates.md).
Release.BATTLE_PASS_OPEN = false

return table.freeze(Release)
