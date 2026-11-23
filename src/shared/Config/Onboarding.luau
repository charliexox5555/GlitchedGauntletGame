--!strict
-- New-player onboarding numbers (vault/05 Production/Handoff - Onboarding and Bots.md,
-- owner's decisions 2026-11-22). Data only: Shared/Onboarding reads these, the lobby's
-- OnboardingService / QueueService and the OnboardingController act on them.
-- "Matches" = the saved matches played (PlayerData prog.matches, published "Matches").

return table.freeze({
	-- The mode new players go to (Lobby Config.MODES id).
	BEGINNER_MODE = "beginner",
	-- Beginner 2v2 is offered (Play menu tile, the server accepts it) below this level.
	BEGINNER_MAX_LEVEL = 10,

	-- On arrival, after the loading screen: queued for Beginner 2v2 straight away
	-- while matches played is below this (the very first match).
	AUTO_QUEUE_BELOW = 1,
	-- PLAY goes straight into the Beginner queue (no menu) while matches played is below this.
	PLAY_SHORTCUT_BELOW = 2,
	-- Seconds after the loading screen closes before the auto-queue fires (lets the
	-- lobby HUD finish its entrance first).
	AUTO_QUEUE_DELAY = 1.5,

	-- HUD unlocks by matches played. Items not listed are always shown (Locker =
	-- "Weapons", Settings, PLAY). Each unlock gets one NEW pop (bit in `seen`).
	UNLOCKS = table.freeze({
		{ id = "Party", at = 1, bit = 1 },
		{ id = "Shop", at = 3, bit = 2 },
		{ id = "Backpack", at = 3, bit = 4 },
	}),
	SEEN_MAX = 7, -- all bits above set
	-- A NEW pop only shows within this many matches of its unlock (players who were
	-- past it before onboarding shipped never get a pile of old NEW pops).
	NEW_WINDOW = 3,
	NEW_TEXT = "NEW",

	-- The bouncing "Join the queue to start playing!" bubble over PLAY: shown while
	-- idle in the lobby with fewer matches played than this (RIVALS: ≤ 3 duels).
	BUBBLE_BELOW = 4,
	BUBBLE_TEXT = "Join the queue to start playing!",
	PLAY_SUB_NEW = "BEGINNER 2V2", -- PLAY's sub-line while it goes straight to Beginner

	-- Favorite prompts (AvatarEditorService:PromptSetFavorite): at most this many asks
	-- per player ever; the first back in the lobby after match 1, the second during
	-- match 2 if the first was declined.
	FAV_MAX_ASKS = 2,
	FAV_LOBBY_AFTER = 1, -- matches played before the lobby ask
	FAV_LOBBY_DELAY = 2.5, -- seconds after the lobby is ready (after the HUD entrance)
	FAV_MATCH_ON = 2, -- the in-match ask happens during this match (matches played + 1)

	-- Beginner 2v2: every enemy drawn solid red on your screen until YOU first hit them (owner 2026-11-22;
	-- RIVALS' red figures). Per viewer, for the whole match (a hit enemy stays plain after respawning).
	RED_ENEMY = table.freeze({
		fill = Color3.fromRGB(229, 38, 46),
		fillTransparency = 0, -- solid, very visible
		outline = Color3.fromRGB(120, 12, 18),
		outlineTransparency = 0,
		scan = 0.25, -- seconds between passes that pick up spawns and respawns
	}),

	-- OnboardingRequest token bucket { perSecond, burst }.
	RATE = { 0.5, 4 },
})
