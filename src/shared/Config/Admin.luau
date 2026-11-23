--!strict
-- Owner-only Admin Panel configuration. Strictly restricted to AUTHORIZED_USER_IDS
-- on both server (Services/AdminService) and client (Controllers/AdminPanelController).

local AUTHORIZED_USER_IDS: { [number]: boolean } = table.freeze({
	[284035946] = true,
})

local Admin = {}

Admin.AUTHORIZED_USER_IDS = AUTHORIZED_USER_IDS
Admin.HOTKEY = Enum.KeyCode.F8
Admin.RATE = table.freeze({ 8, 16 }) -- requests/sec, burst (Util/RateLimit)
Admin.MAX_AMOUNT = 10_000_000

Admin.COIN_PRESETS = table.freeze({ 500, 2500, 10000, 50000, 250000, -1000 })
Admin.TICKET_PRESETS = table.freeze({ 5, 25, 100, 500, -5 })
Admin.LEVEL_PRESETS = table.freeze({ 1, 5, 10, 25, -1 })
Admin.XP_PRESETS = table.freeze({ 250, 1000, 5000 })
Admin.CASE_PRESETS = table.freeze({ 1, 5, 10, -1, -5 })
-- Bots tab (match servers and pad duels): the level badge a bot shows, and quick picks.
Admin.BOT_LEVEL_MAX = 9999
Admin.BOT_LEVEL_PRESETS = table.freeze({ 1, 10, 25, 50, 100, 500 })

function Admin.isAllowed(userId: number): boolean
	return AUTHORIZED_USER_IDS[userId] == true
end

return table.freeze(Admin)
