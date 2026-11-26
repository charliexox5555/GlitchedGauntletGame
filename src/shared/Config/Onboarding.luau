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
	-- two; match 1's free case opens by itself, so the Backpack isn't needed before).
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
	-- The gun each weapon phase hands out while `handGuns` (owner picks 2026-11-26: forgiving at Arena range).
	HANDED_GUNS = table.freeze({
		Sidearm = "Sheriff",
		Light = "Spectre", -- Prowler
		Heavy = "Vandal", -- Havoc
		Elite = "Odin", -- Mauler
	}) :: { [string]: string },
	-- A `select = "none"` round: seconds before its 3-2-1 (time for everyone to spawn behind the barrier).
	HIDDEN_SELECT_TIME = 1.5,

	-- OnboardingRequest token bucket { perSecond, burst }.
	RATE = { 0.5, 4 },
})
