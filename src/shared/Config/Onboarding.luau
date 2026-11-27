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
export type Script = { roundsToWin: number, rounds: { [number]: Round } }

return table.freeze({
	-- The mode new players go to (Lobby Config.MODES id).
	BEGINNER_MODE = "beginner",
	-- A solo new player's first this-many Beginner matches skip the queue wait: a reserved match server with bots
	-- at once, like every match (QueueService). Owner 2026-11-27: onboarding matches no longer run inside the
	-- lobby (hub) server ("it's just going to cause lag ... overusage of matches in the server"). Studio has no
	-- teleports, so there the match runs in the Studio server as a stand-in.
	LAUNCH_AT_ONCE = 2,
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
	-- The Range goes first (2026-11-27, First Ten Minutes §13): the Task Path's first part is there, and its coins
	-- pay for the first gun unlock (Config/Economy, economy pass 2026-11-27).
	UNLOCKS = table.freeze({
		{ id = "Range", at = 2, bit = 16 },
		{ id = "Backpack", at = 2, bit = 4 },
		{ id = "Shop", at = 2, bit = 2 },
		{ id = "Party", at = 2, bit = 1 },
	}),
	SEEN_MAX = 31, -- all bits above and FIRST_UNLOCK's set
	-- A NEW pop only shows within this many matches of its unlock (players who were
	-- past it before onboarding shipped never get a pile of old NEW pops).
	NEW_WINDOW = 3,
	NEW_TEXT = "NEW",

	-- The first gun unlock (First Ten Minutes §13, replaces the old free case and its OPEN / EQUIP steps): back in
	-- the lobby after `fromMatches` matches, owning only the starter guns and with coins for the cheapest locked one,
	-- the Locker icon pulses with `text`; it opens on that gun. Once (its `bit` in `seen`), never once a gun is bought.
	FIRST_UNLOCK = table.freeze({ fromMatches = 1, bit = 8, text = "UNLOCK A GUN" }),

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

	-- The first two matches, round by round (vault/01 Design/First Ten Minutes.md §13, the loadout update
	-- 2026-11-27): the real loadout and rules (Classic in round 1, Havoc from round 2), one new thing per round, only
	-- the draft scripted. Index = the onboarding match (1 = the very first). DraftService deals from it,
	-- MatchService hides a `select = "none"` round's pick screen and reads `roundsToWin`.
	--   roundsToWin: first to this (owner 2026-11-27: "could be 4 ... maybe even the full 5"; Claude's pick 4, the
	--     fewest rounds match 1 can have, so its four steps always fit).
	--   select = "none": no pick screen; the round starts with `kit` already on (just the 3-2-1).
	--   offer = { ids }: only these new powers; "glitch": only the Glitched card (on the first level-1 power).
	--   Rounds not listed deal the normal power cards (still focused: no empty columns).
	SCRIPT = table.freeze({
		table.freeze({
			roundsToWin = 4,
			rounds = table.freeze({
				[1] = table.freeze({ select = "none" }), -- sidearm round: move, shoot, no power yet
				[2] = table.freeze({ offer = table.freeze({ "Dash", "Updraft" }) }), -- a power (single taps)
				[3] = table.freeze({ offer = table.freeze({ "Frost", "Molly" }) }), -- powers stack (held throws)
				[4] = table.freeze({ offer = "glitch" }), -- upgrades: the Glitched card
			}),
		}),
		-- match 2: the real draft from round 1 (three cards), A/B upgrades from round 2
		table.freeze({ roundsToWin = 4, rounds = table.freeze({}) }),
	}) :: { Script },
	-- A `select = "none"` round: seconds before its 3-2-1 (time for everyone to spawn behind the barrier).
	HIDDEN_SELECT_TIME = 1.5,

	-- OnboardingRequest token bucket { perSecond, burst }.
	RATE = { 0.5, 4 },
})
