--!strict
-- The loading screen v2 (ReplicatedFirst.DuelsLoading, tools/studio/BuildDuelsLoading.luau; driven by
-- src/first/LoadingScreen.client.luau and the lobby's DuelLoadingController; vault/05 Production/Handoff -
-- Stability, Loading and Preload.md → Phase 2). Owner 2026-11-22: short hold, no skip; a sting plus a quiet music
-- bed; on the first join and every teleport, a short version on pad duels.
-- One tip is picked at random each time. Keep them true to the game (vault/01 Design/Match Flow.md) and short.

return table.freeze({
	tips = table.freeze({
		"DRAFT A NEW MOD EVERY ROUND",
		"EVERY ROUND OPENS A NEW WEAPON TIER",
		"YOUR PARTY QUEUES TOGETHER, ON ONE TEAM",
		"THE SKINS YOU EQUIP IN THE LOCKER COME WITH YOU",
	}),

	-- The words under the progress line, one per real stage.
	stages = table.freeze({
		connecting = "CONNECTING",
		data = "LOADING YOUR DATA",
		body = "GETTING YOUR FIGHTER READY",
		lobby = "OPENING THE LOBBY",
		match = "SETTING UP THE MATCH",
		players = "WAITING FOR PLAYERS",
		duel = "LOADING DUEL",
		ready = "READY",
	}),
	modeLine = "%s  /  LOADING MATCH", -- a teleport into a match (the mode, upper case)
	homeLine = "BACK TO THE LOBBY", -- a teleport from a match to the lobby

	-- Timing (seconds).
	minHold = 2.2, -- the logo reveal (0.5 s) and a beat of the full title, at least (no skip button)
	assetWait = 3, -- longest wait for the logo images and this config before the reveal plays anyway
	watchdogLobby = 30, -- closes whatever happens (LihFolk: Streaming Joins - Frozen Players ... Teardown, 25 s)
	watchdogMatch = 120, -- a match server can wait for teleporting players (Config/Bots JOIN_GRACE + READY_TIMEOUT)
	duelMin = 0.6, -- the pad-duel short version
	duelMax = 4,
	fadeOut = 0.45,
	fill = 0.35, -- one progress step
	blur = 24, -- the world behind blurs, then clears as the screen fades

	-- Phones in landscape (screen height under phoneHeight px) get the canvas this much bigger.
	phoneHeight = 600,
	phoneBoost = 1.3,
	-- ...and the rows pulled closer (design-canvas y, px) so the tip stays on a 667 × 375 screen (src/first/LoadingLayout).
	phoneY = table.freeze({
		Mode = 230,
		Logo = 430,
		Progress = 650,
		Spinner = 650,
		Stage = 692,
		Count = 728,
		Tip = 905,
	}),

	-- Sound, on SoundService.SettingsMusic (Settings MUSIC × MASTER). Licensed Creator Store audio (APMOfficial);
	-- shortlist in the handoff note: the owner picks after the audition. These are the current picks.
	sting = table.freeze({ id = "rbxassetid://9047207931", volume = 0.6, at = 0.21 }), -- "Outrunning - Hit"
	bed = table.freeze({
		id = "rbxassetid://9042293789",
		volume = 0.18,
		fadeIn = 1.2,
		fadeOut = 0.6,
	}), -- "Beginnings"
})
