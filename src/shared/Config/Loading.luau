--!strict
-- The teleport / loading screen's words (lobby StarterGui.LobbyLoading,
-- tools/studio/BuildLoading.luau; vault/02 Art/UI Lobby Overhaul.md).
-- One tip is picked at random each teleport. Keep them true to the game
-- (vault/01 Design/Match Flow.md) and short (one line at 22 px).

return table.freeze({
	tips = table.freeze({
		"DRAFT A NEW MOD EVERY ROUND",
		"EVERY ROUND OPENS A NEW WEAPON TIER",
		"YOUR PARTY QUEUES TOGETHER, ON ONE TEAM",
		"THE SKINS YOU EQUIP IN THE LOCKER COME WITH YOU",
	}),
})
