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
		home = "BACK TO THE LOBBY", -- from a match back to this server's lobby (Controllers/DuelLoadingController)
		ready = "READY",
	}),
	modeLine = "%s  /  LOADING MATCH", -- a teleport into a match (the mode, upper case)
	homeLine = "BACK TO THE LOBBY", -- a teleport from a match to the lobby

	-- Timing (seconds).
	minHold = 2.2, -- from the reveal, at least (no skip button; tightened for ad retention)
	stepMin = 0.3, -- each stage shows at least this long, so the four segments fill one by one
	assetWait = 3, -- longest wait for the logo images and this config before the reveal plays anyway
	watchdogLobby = 30, -- closes whatever happens (LihFolk: Streaming Joins - Frozen Players ... Teardown, 25 s)
	watchdogMatch = 120, -- a match server can wait for teleporting players (Config/Bots JOIN_GRACE + READY_TIMEOUT)
	-- Lobby join: after the fighter exists, ask Roblox to stream the area around it and wait for floor under its
	-- feet (owner 2026-11-22: "stuck in a void"), at most this long; then look this far down for the floor.
	streamWait = 8,
	-- Longest the "LOADING YOUR DATA" stage waits for the save; then the screen opens and the save keeps loading
	-- (the Shop and onboarding wait for it themselves).
	dataWait = 8,
	-- Then the longest wait for your equipped gun skins to arrive (Shared/SkinStore), so none shows stock first.
	skinWait = 4,
	groundProbe = 40,
	duelMin = 0.6, -- the pad-duel short version
	duelMax = 8,
	homeMin = 1, -- back from a match to this server's lobby: at least this long...
	homeMax = 10, -- ...and at most this (it waits for the body animations and floor under the lobby character)
	fadeOut = 0.8, -- the close: words drop out, the title zooms through, the backdrop fades as the blur clears
	fill = 0.4, -- one segment filling
	blur = 24, -- the world behind blurs, then clears as the screen fades

	-- Phones in landscape (screen height under phoneHeight px) get the canvas this much bigger.
	phoneHeight = 600,
	phoneBoost = 1.3,
	-- ...and the rows pulled closer (design-canvas y, px) so the tip stays on a 667 × 375 screen (src/first/LoadingLayout).
	phoneY = table.freeze({
		Mode = 230,
		Logo = 430,
		Pips = 650,
		Spinner = 650,
		StageClip = 692,
		Count = 728,
		Tip = 905,
	}),

	-- Motion (v2.1): slash drift (screen widths a second), title float (fraction of its height), its speed, the
	-- ticket's sway (degrees), one shine sweep (s), the working segment's breath (s a cycle).
	motion = table.freeze({
		stripeSpeed = 0.012,
		floatAmp = 0.012,
		floatSpeed = 1.5,
		swayDeg = 1.2,
		shine = 0.75,
		pulse = 1.1,
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
