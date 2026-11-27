--!strict
-- New-player onboarding numbers (vault/05 Production/Handoff - Onboarding and Bots.md,
-- owner's decisions 2026-11-22). Data only: Shared/Onboarding reads these, the lobby's
-- OnboardingService / QueueService and the OnboardingController act on them.
-- "Matches" = the saved matches played (PlayerData prog.matches, published "Matches").

export type Round = {
	select: string?, -- "none" hides the pick screen
	kit: { string }?, -- powers already on when the round starts
	offer: any?, -- { ids } or "glitch"
}
export type Script = { handGuns: boolean, rounds: { [number]: Round } }

return table.freeze({
	-- The mode new players go to (Lobby Config.MODES id).
	BEGINNER_MODE = "beginner",
	-- A solo new player's first this-many Beginner matches start at once in this lobby server against bots
	-- (QueueService → MatchHost), no queue and no teleport (owner 2026-11-25: match 2's queue lost 16%).
	INSTANT_MATCHES = 2,
	-- Server load (owner 2026-11-26: "25 duels happening at the same time ... too much for a server"): each instant
	-- match is the player + 3 bots + its own arena copy. At this many matches running in a lobby server (pad duels
	-- included), a new player goes through the normal queue to their own match server instead. Tune from the live
	-- "server slow" HealthLog lines (MatchHost).
	MAX_LOBBY_MATCHES = 8,
	-- With this many matches already running, a new player's instant match waits up to PAIR_WAIT seconds for
	-- another new player at the same onboarding match, and the two play one match on opposite teams (fewer bots,
	-- a real opponent). A quiet server starts at once.
	PAIR_WHEN_BUSY = 3,
	PAIR_WAIT = 2.5,
	-- Beginner 2v2 is offered (Play menu tile, the server accepts it) below this level.
	BEGINNER_MAX_LEVEL = 5,

	-- On arrival, after the loading screen: queued for Beginner 2v2 straight away
	-- while matches played is below this (the very first match).
	AUTO_QUEUE_BELOW = 1,
	-- PLAY goes straight into the Beginner queue (no menu) while matches played is below this (2 → 3,
	-- 2026-11-26: the menu arrives with the rest of the lobby, after match 2).
	PLAY_SHORTCUT_BELOW = 3,
	-- Seconds after the loading screen closes before the auto-queue fires (lets the
	-- lobby HUD and phone frame settle first).
	AUTO_QUEUE_DELAY = 1.2,

	-- HUD unlocks by matches played. Items not listed are always shown (Locker =
	-- "Weapons", Settings, PLAY). Each unlock gets one NEW pop (bit in `seen`).
	-- After match 2 (2026-11-26, vault/01 Design/First Ten Minutes.md: the lobby opens up once they've played
	-- two, so the Backpack isn't needed before).
	UNLOCKS = table.freeze({
		{ id = "Backpack", at = 2, bit = 4 },
		{ id = "Shop", at = 2, bit = 2 },
		{ id = "Party", at = 2, bit = 1 },
	}),
	SEEN_MAX = 7, -- all bits above set
	-- A NEW pop only shows within this many matches of its unlock (players who were
	-- past it before onboarding shipped never get a pile of old NEW pops).
	NEW_WINDOW = 3,
	NEW_TEXT = "NEW",

	-- The old free case for finishing Match 1 (the Starter Case, Config/Skins CASES.Starter). No longer granted
	-- (owner 2026-11-27: too strong, RIVALS doesn't); saves that still hold one keep it and open it from the
	-- Backpack like any case. Only the admin "start full onboarding" reset still clears it.
	FIRST_MATCH_CASE = "CaseStarter",

	-- The bouncing "Join the queue to start playing!" bubble over PLAY: shown while
	-- idle in the lobby with fewer matches played than this (RIVALS: ≤ 3 duels).
	BUBBLE_BELOW = 4,
	BUBBLE_TEXT = "Join the queue to start playing!",
	PLAY_SUB_NEW = "BEGINNER 2V2", -- PLAY's sub-line while it goes straight to Beginner

	-- Favorite prompts (AvatarEditorService:PromptSetFavorite): at most this many asks
	-- per player ever; the first back in the lobby after match 2, the second back in
	-- the lobby after match 3 if the first was declined (never mid-match).
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

	-- The first two matches, round by round (vault/01 Design/First Ten Minutes.md; owner 2026-11-26: learn by
	-- playing, one new thing per round, no menus they can't read yet). Index = the onboarding match (1 = the very
	-- first). DraftService deals from it, MatchService hides a `select = "none"` round's pick screen.
	--   handGuns: no gun row; each phase's HANDED_GUNS gun is handed out.
	--   select = "none": no pick screen; the round starts with `kit` already on (just the 3-2-1).
	--   offer = { ids }: only these new powers; "glitch": only the Glitched card (on the `kit` power if it can).
	--   Rounds not listed deal the normal power cards (still focused: no gun row, no empty columns).
	SCRIPT = table.freeze({
		table.freeze({
			handGuns = true,
			rounds = table.freeze({
				[1] = table.freeze({ select = "none", kit = table.freeze({ "Dash" }) }),
				[2] = table.freeze({ offer = table.freeze({ "Updraft", "Frost" }) }),
				[3] = table.freeze({ offer = "glitch" }),
			}),
		}),
		table.freeze({ handGuns = true, rounds = table.freeze({}) }),
	}) :: { Script },
	-- The gun handed out while `handGuns`, by the boosted round (MatchState.phaseRound; owner picks 2026-11-26:
	-- forgiving at Arena range). Kept from the old tiers until the onboarding update (build order step 5).
	HANDED_GUNS = table.freeze({
		table.freeze({ fromRound = 1, gun = "Sheriff" }),
		table.freeze({ fromRound = 2, gun = "Spectre" }), -- Prowler
		table.freeze({ fromRound = 4, gun = "Vandal" }), -- Havoc
		table.freeze({ fromRound = 7, gun = "Odin" }), -- Mauler
	}) :: { { fromRound: number, gun: string } },
	-- A `select = "none"` round: seconds before its 3-2-1 (time for everyone to spawn behind the barrier).
	HIDDEN_SELECT_TIME = 1.5,

	-- OnboardingRequest token bucket { perSecond, burst }.
	RATE = { 0.5, 4 },
})
