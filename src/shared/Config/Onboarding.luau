--!strict
-- New-player onboarding numbers (vault/05 Production/Handoff - Onboarding and Bots.md,
-- owner's decisions 2026-11-22). Data only: Shared/Onboarding reads these, the lobby's
-- OnboardingService / QueueService and the OnboardingController act on them.
-- "Matches" = the saved matches played (PlayerData prog.matches, published "Matches").

return table.freeze({
	-- The mode new players go to (Lobby Config.MODES id).
	BEGINNER_MODE = "beginner",
	-- A solo new player's first this-many Beginner matches start at once in this lobby server against bots
	-- (QueueService → MatchHost), no queue and no teleport (owner 2026-11-25: match 2's queue lost 16%).
	INSTANT_MATCHES = 2,
	-- Beginner 2v2 is offered (Play menu tile, the server accepts it) below this level.
	BEGINNER_MAX_LEVEL = 5,

	-- On arrival, after the loading screen: queued for Beginner 2v2 straight away
	-- while matches played is below this (the very first match).
	AUTO_QUEUE_BELOW = 1,
	-- PLAY goes straight into the Beginner queue (no menu) while matches played is below this.
	PLAY_SHORTCUT_BELOW = 2,
	-- Seconds after the loading screen closes before the auto-queue fires (lets the
	-- lobby HUD and phone frame settle first).
	AUTO_QUEUE_DELAY = 1.2,

	-- HUD unlocks by matches played. Items not listed are always shown (Locker =
	-- "Weapons", Settings, PLAY). Each unlock gets one NEW pop (bit in `seen`).
	UNLOCKS = table.freeze({
		{ id = "Backpack", at = 1, bit = 4 },
		{ id = "Shop", at = 1, bit = 2 },
		{ id = "Party", at = 1, bit = 1 },
	}),
	SEEN_MAX = 7, -- all bits above set
	-- A NEW pop only shows within this many matches of its unlock (players who were
	-- past it before onboarding shipped never get a pile of old NEW pops).
	NEW_WINDOW = 3,
	NEW_TEXT = "NEW",

	-- Free case granted on finishing Match 1 (guided open + equip before Match 2). The Starter Case (owner
	-- 2026-11-25): gift only, always an Epic gun skin (Config/Skins CASES.Starter), so a new player's first
	-- unbox is a big one. Was the Standard Case.
	FIRST_MATCH_CASE = "CaseStarter",
	CASE_CALLOUT_TEXT = "OPEN FREE CASE!",
	EQUIP_CALLOUT_TEXT = "EQUIP SKIN!",
	CASE_TOAST_TEXT = "YOU EARNED A FREE EPIC CASE! OPEN YOUR BACKPACK",
	-- Back in the lobby with the free case unopened: the Backpack opens on it by itself after this many seconds,
	-- once per session (owner 2026-11-25: 12.5% left between the hub and opening the Backpack).
	CASE_AUTO_OPEN_DELAY = 1.5,

	-- The bouncing "Join the queue to start playing!" bubble over PLAY: shown while
	-- idle in the lobby with fewer matches played than this (RIVALS: ≤ 3 duels).
	BUBBLE_BELOW = 4,
	BUBBLE_TEXT = "Join the queue to start playing!",
	PLAY_SUB_NEW = "BEGINNER 2V2", -- PLAY's sub-line while it goes straight to Beginner

	-- Favorite prompts (AvatarEditorService:PromptSetFavorite): at most this many asks
	-- per player ever; the first back in the lobby after match 2, the second back in
	-- the lobby after match 3 if the first was declined (never mid-match, never during
	-- the post-Match-1 free case onboarding).
	FAV_MAX_ASKS = 2,
	FAV_LOBBY_AFTER = 2, -- matches played before the first lobby ask
	FAV_LOBBY_SECOND_AFTER = 3, -- matches played before the second lobby ask
	FAV_LOBBY_DELAY = 2.5, -- seconds after the lobby is ready (after the HUD entrance)

	-- Beginner 2v2: every enemy drawn solid red on your screen until YOU first hit them (owner 2026-11-22;
	-- RIVALS' red figures). Per viewer, for the whole match (a hit enemy stays plain after respawning).
	RED_ENEMY = table.freeze({
		-- neon (owner 2026-11-23: "more neon and pulsing a bit ... seen through walls")
		fill = Color3.fromRGB(255, 28, 52),
		outline = Color3.fromRGB(255, 120, 135),
		outlineTransparency = 0,
		fillLow = 0.05, -- fill transparency at the pulse's strongest
		fillHigh = 0.4, -- ...and at its softest
		pulseTime = 1.1, -- seconds per pulse
		throughWalls = true, -- AlwaysOnTop: shown behind cover too
		scan = 0.25, -- seconds between passes that pick up spawns, respawns and the watched view
	}),

	-- OnboardingRequest token bucket { perSecond, burst }.
	RATE = { 0.5, 4 },
})
