--!strict
-- New-player onboarding state and rules (vault/05 Production/Handoff - Onboarding and
-- Bots.md; numbers in Config/Onboarding). Pure: no services, both sides use it.
--
-- Saved in PlayerData as `onb` (2026-11-22, no version bump: older saves get new()):
--   fav      favorite prompts shown so far (0..FAV_MAX_ASKS)
--   favDone  the player favorited the game (or already had): never ask again
--   seen     bitset of the HUD unlock "NEW" pops already seen (Config UNLOCKS bits) and the first-unlock
--            callout (Config FIRST_UNLOCK bit)
-- Published on the player as StateValues "OnbFav", "OnbFavDone", "OnbSeen".
-- Matches played is the saved prog.matches (published "Matches").

local Config = require(script.Parent.Config.Onboarding)
local Loadout = require(script.Parent.Config.Loadout)

export type Onb = {
	fav: number,
	favDone: boolean,
	seen: number,
	analytics: boolean?,
	caseGift: boolean?,
	caseOpened: boolean?,
	skinEquipped: boolean?,
}

local Onboarding = {}

function Onboarding.new(): Onb
	return { fav = 0, favDone = false, seen = 0 }
end

local function whole(n: unknown, max: number): number?
	if typeof(n) == "number" and n == n and n == math.floor(n) and n >= 0 and n <= max then
		return n
	end
	return nil
end

-- Any stored value to a valid Onb (bad fields fall back to their defaults).
function Onboarding.clean(raw: unknown): Onb
	local o = Onboarding.new()
	if typeof(raw) ~= "table" then
		return o
	end
	local t = raw :: { [string]: unknown }
	o.fav = whole(t.fav, Config.FAV_MAX_ASKS) or 0
	o.favDone = t.favDone == true
	o.seen = whole(t.seen, Config.SEEN_MAX) or 0
	o.analytics = if t.analytics == true then true else nil
	o.caseGift = if t.caseGift == true then true else nil
	o.caseOpened = if t.caseOpened == true then true else nil
	o.skinEquipped = if t.skinEquipped == true then true else nil
	return o
end

function Onboarding.valid(o: Onb): boolean
	return whole(o.fav, Config.FAV_MAX_ASKS) ~= nil
		and typeof(o.favDone) == "boolean"
		and whole(o.seen, Config.SEEN_MAX) ~= nil
		and (o.analytics == nil or typeof(o.analytics) == "boolean")
		and (o.caseGift == nil or typeof(o.caseGift) == "boolean")
		and (o.caseOpened == nil or typeof(o.caseOpened) == "boolean")
		and (o.skinEquipped == nil or typeof(o.skinEquipped) == "boolean")
end

-- Rules ---------------------------------------------------------------------------

-- Beginner 2v2 is offered at this level.
function Onboarding.beginnerOpen(level: number): boolean
	return level < Config.BEGINNER_MAX_LEVEL
end

-- Queue for Beginner 2v2 on arrival.
function Onboarding.autoQueue(matches: number, level: number): boolean
	return matches < Config.AUTO_QUEUE_BELOW and Onboarding.beginnerOpen(level)
end

-- PLAY skips the menu and queues Beginner 2v2.
function Onboarding.playShortcut(matches: number, level: number): boolean
	return matches < Config.PLAY_SHORTCUT_BELOW and Onboarding.beginnerOpen(level)
end

-- A HUD item is shown (items not in UNLOCKS always are).
function Onboarding.unlocked(id: string, matches: number): boolean
	for _, u in Config.UNLOCKS do
		if u.id == id then
			return matches >= u.at
		end
	end
	return true
end

-- The unlock's bit, or nil for an item that is never locked.
function Onboarding.bitOf(id: string): number?
	for _, u in Config.UNLOCKS do
		if u.id == id then
			return u.bit
		end
	end
	return nil
end

-- A known unlock bit (the server accepts only these).
function Onboarding.isBit(bit: number): boolean
	if bit == Config.FIRST_UNLOCK.bit then
		return true
	end
	for _, u in Config.UNLOCKS do
		if u.bit == bit then
			return true
		end
	end
	return false
end

-- The bit may be marked seen at `matches` played (its menu or callout has appeared by then).
function Onboarding.bitAllowed(bit: number, matches: number): boolean
	if bit == Config.FIRST_UNLOCK.bit then
		return matches >= Config.FIRST_UNLOCK.fromMatches
	end
	for _, u in Config.UNLOCKS do
		if u.bit == bit then
			return Onboarding.unlocked(u.id, matches)
		end
	end
	return false
end

-- The first gun unlock (vault/01 Design/First Ten Minutes.md §13): the gun the Locker callout points at, or nil.
-- Due after FIRST_UNLOCK.fromMatches matches while the player owns only the starter guns, hasn't seen the
-- callout and has the coins for a locked gun: the cheapest one (Locker order on a tie).
function Onboarding.firstUnlock(
	matches: number,
	seen: number,
	owned: { [string]: boolean },
	coins: number
): string?
	local f = Config.FIRST_UNLOCK
	if matches < f.fromMatches or bit32.band(seen, f.bit) ~= 0 then
		return nil
	end
	local best: string? = nil
	for _, list in { Loadout.PRIMARIES, Loadout.SECONDARIES } do
		for _, id in list do
			local starter = id == Loadout.STARTER.Primary or id == Loadout.STARTER.Secondary
			if owned[id] and not starter then
				return nil -- they've bought a gun already
			end
			local price = Loadout.PRICES[id]
			if
				not owned[id]
				and price
				and price <= coins
				and (best == nil or price < (Loadout.PRICES[best] :: number))
			then
				best = id
			end
		end
	end
	return best
end

-- The NEW pop for this unlock is due (unlocked recently, not seen yet).
function Onboarding.newPop(id: string, matches: number, seen: number): boolean
	for _, u in Config.UNLOCKS do
		if u.id == id then
			return matches >= u.at
				and matches < u.at + Config.NEW_WINDOW
				and bit32.band(seen, u.bit) == 0
		end
	end
	return false
end

-- The bit is set in `seen`.
function Onboarding.hasBit(seen: number, bit: number): boolean
	return bit32.band(seen, bit) ~= 0
end

-- The bubble over PLAY (while idle in the lobby).
function Onboarding.bubble(matches: number): boolean
	return matches < Config.BUBBLE_BELOW
end

-- Ask to favorite now? `where`: "lobby" (back in the lobby) or "match" (disabled).
function Onboarding.favAsk(o: Onb, matches: number, where: string): boolean
	if o.favDone or o.fav >= Config.FAV_MAX_ASKS then
		return false
	end
	if where == "lobby" then
		return (o.fav == 0 and matches >= Config.FAV_LOBBY_AFTER)
			or (o.fav == 1 and matches >= Config.FAV_LOBBY_SECOND_AFTER)
	end
	return false
end

return Onboarding
