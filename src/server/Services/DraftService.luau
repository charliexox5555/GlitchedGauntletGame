--!strict
-- The between-round draft (vault/01 Design/Match Flow.md): deals each player their
-- ability cards, takes their picks, then hands them to MatchService.
--
-- Guns (vault/01 Design/Loadout and Power Deck.md, step 2): no gun row any more. Each seat takes its gun
-- loadout (Shared/GunLoadout: a player's saved primary + secondary, a bot's random pair) when the draft
-- closes; Config/Loadout SECONDARY_ROUNDS rounds hand out only the secondary. Onboarding matches still hand
-- out Config/Onboarding HANDED_GUNS until the onboarding update.
-- The server rolls and stores every offer, and a pick is only ever checked
-- against that stored list, so a client can't ask for anything it wasn't dealt.
--
-- The power deck (vault/01 Design/Loadout and Power Deck.md, 2026-11-26): a player is dealt only the powers in
-- their own deck (Shared/ModLoadout: owned and equipped; bots draw from every built power). Slots fill in
-- draft order: the match's 1st power goes on slot 1 (Q), the 2nd on slot 2 (E), the 3rd on slot 3 (T). The
-- ability row keeps one column per slot: a filled slot offers its upgrades
-- (vault/01 Design/Abilities/Upgrade Paths.md: at level 1 path A and path B, sometimes the glitch path; at
-- level 2 the next level of its path); each empty slot shows one new power from the deck, and whichever new
-- power is picked lands on the first empty slot. One card per draft, from any column.

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Players = Context.players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local MatchState = require(script.Parent.Parent.MatchState)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Mods = require(ReplicatedStorage.Shared.Mods)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local Net = Context.net
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local DraftService = {}

local ACTIONS = { Ability = true, Lock = true, Sync = true }

-- What one side of the draft holds for the whole match (players and the test
-- opponent alike; `key` is a Player or the opponent's marker table).
export type Seat = {
	key: any,
	kit: { string }, -- ability per slot, "" = empty
	levels: { string }, -- its level per slot, "" = empty
	sidearm: string?,
	primary: string?,
	shield: number, -- what this round's gun gives
	botGuns: GunLoadout.Loadout?, -- a bot's pair for the whole match (players read their save)
	-- This draft:
	guns: { string }, -- always empty since the gun loadout (kept for the offer's shape and old clients)
	abilities: { string },
	upgrades: { MatchState.UpgradeCard },
	lastNewMods: { string }, -- the new powers this seat was offered last draft (not dealt again while others can be)
	gun: string?, -- onboarding only: the handed gun
	ability: string?, -- a new ability's id, or an upgrade card's key
	glitchBonus: number, -- the glitch chance's rise since the last glitch card
	glitchDealt: boolean, -- this seat has been dealt a glitch card this match (the onboarding guarantee)
	locked: boolean,
	dealtRound: number, -- the round this seat was last dealt cards for (0: never)
	offer: MatchState.DraftOffer?,
	focus: boolean, -- this draft follows the onboarding script (Config/Onboarding SCRIPT)
	hidden: boolean, -- ...and has no pick screen
}

local limiter = RateLimit.new(Config.RATE)
local seats: { [any]: Seat } = {}
local open = false
local rng = Random.new()
local abilityOfferCounts: { [string]: number } = {}
-- Told about every pick that lands (MatchService hands these to StatsService for the task Path).
local pickListeners: { (key: any, powerId: string, level: string) -> () } = {}

local function tellPick(key: any, powerId: string, level: string)
	for _, fn in pickListeners do
		local ok, err = pcall(fn, key, powerId, level)
		if not ok then
			warn("[DraftService] pick listener failed:", err)
		end
	end
end

function DraftService.onPicked(fn: (key: any, powerId: string, level: string) -> ())
	table.insert(pickListeners, fn)
end

-- Onboarding: the gun HANDED_GUNS gives for `round` (by the boosted round), if it is installed.
local function handedGun(round: number): string?
	local at = MatchState.phaseRound(round)
	local gun: string? = nil
	for _, h in OnbConfig.HANDED_GUNS do
		if at >= h.fromRound then
			gun = h.gun
		end
	end
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	return if gun and Weapons.get(gun) and folder and folder:FindFirstChild(gun) then gun else nil
end

-- The powers a seat may be dealt: a player's deck, or (a bot: `human` false) every built power.
local function deckOf(loadout: ModLoadout.Loadout?, human: boolean): { string }
	local deck: { string } = {}
	for _, id in ModsConfig.ORDER do
		if Mods.isBuilt(id) and (not human or ModLoadout.eligible(id, loadout)) then
			table.insert(deck, id)
		end
	end
	return deck
end

-- The first empty slot (the next power's key), nil when all are filled.
local function firstFree(kit: { string }): number?
	for slot = 1, ModsConfig.SLOTS do
		if kit[slot] == "" then
			return slot
		end
	end
	return nil
end

-- One new power from `pool` the seat doesn't hold and hasn't been dealt this draft. Cards offered to fewer seats
-- first; last draft's cards only when nothing else is left.
local function rollNewMod(s: Seat, pool: { string }): string?
	local fresh: { string } = {}
	local stale: { string } = {}
	for _, id in pool do
		if table.find(s.kit, id) or table.find(s.abilities, id) then
			continue
		end
		table.insert(if table.find(s.lastNewMods, id) then stale else fresh, id)
	end
	local candidates = if #fresh > 0 then fresh else stale
	local choices: { string } = {}
	local bestCount = math.huge
	for _, id in candidates do
		local count = abilityOfferCounts[id] or 0
		if count < bestCount then
			table.clear(choices)
			bestCount = count
		end
		if count == bestCount then
			table.insert(choices, id)
		end
	end
	if #choices == 0 then
		return nil
	end
	local picked = choices[rng:NextInteger(1, #choices)]
	abilityOfferCounts[picked] = bestCount + 1
	return picked
end

-- An onboarding match (MatchState "PhaseBoost") deals later phases early (MatchState.phaseFor).
function DraftService.phaseFor(round: number): Config.Phase
	return MatchState.phaseFor(round)
end

local function emptyKit(): { string }
	local list: { string } = {}
	for slot = 1, ModsConfig.SLOTS do
		list[slot] = ""
	end
	return list
end

-- The next level on each path (vault/01 Design/Abilities/Upgrade Paths.md).
local NEXT: { [string]: string } = { A2 = "A3", B2 = "B3", G2 = "G3" }

local function card(id: string, slot: number, level: string): MatchState.UpgradeCard
	return { key = id .. ":" .. level, id = id, slot = slot, level = level }
end

-- The upgrade cards for a seat's filled slots: the next level of each ability,
-- and at level 1 its two paths plus, by chance, the glitch. `guarantee`: deal a
-- glitch card if any slot can take one (the onboarding match's Glitched card).
local function rollUpgrades(s: Seat, guarantee: boolean): { MatchState.UpgradeCard }
	local cards: { MatchState.UpgradeCard } = {}
	local glitch = Config.GLITCH
	local eligible: { number } = {}
	local force = Dev.ALWAYS_GLITCH_CARDS and RunService:IsStudio()
	for slot = 1, ModsConfig.SLOTS do
		local id, level = s.kit[slot], s.levels[slot]
		if id == "" or not Mods.isBuilt(id) then
			continue
		end
		if level == "L1" then
			table.insert(cards, card(id, slot, "A2"))
			table.insert(cards, card(id, slot, "B2"))
			if force then
				table.insert(cards, card(id, slot, "G2"))
			else
				table.insert(eligible, slot)
			end
		elseif NEXT[level] then
			table.insert(cards, card(id, slot, NEXT[level]))
		end
	end
	local chance = math.min(glitch.chance + s.glitchBonus, glitch.cap)
	if force then
		s.glitchBonus = 0
	elseif #eligible > 0 then
		if guarantee or rng:NextNumber() < chance then
			local slot = eligible[rng:NextInteger(1, #eligible)]
			table.insert(cards, card(s.kit[slot], slot, "G2"))
			s.glitchBonus = 0
		else
			s.glitchBonus += glitch.step
		end
	end
	return cards
end

local function upgradeByKey(s: Seat, key: string): MatchState.UpgradeCard?
	for _, c in s.upgrades do
		if c.key == key then
			return c
		end
	end
	return nil
end

-- "id:level" for each ability a seat has (the enemy's kit on the draft screen).
function DraftService.kitOf(key: any): { string }
	local out: { string } = {}
	local s = seats[key] -- a read never makes a seat (join deals by dealtRound)
	if not s then
		return out
	end
	for slot = 1, ModsConfig.SLOTS do
		if s.kit[slot] ~= "" then
			table.insert(out, s.kit[slot] .. ":" .. s.levels[slot])
		end
	end
	return out
end

-- A new match: everyone's kit is gone.
function DraftService.reset()
	table.clear(seats)
	open = false
end

function DraftService.seat(key: any): Seat
	local s = seats[key]
	if not s then
		s = {
			key = key,
			kit = emptyKit(),
			levels = emptyKit(),
			shield = 0,
			guns = {},
			abilities = {},
			upgrades = {},
			lastNewMods = {},
			locked = false,
			glitchBonus = 0,
			glitchDealt = false,
			dealtRound = 0,
			focus = false,
			hidden = false,
		}
		seats[key] = s
	end
	return s
end

function DraftService.forget(key: any)
	seats[key] = nil
end

-- The draft that's open now (for seats dealt in late).
local dealt = {
	round = 0,
	endsAt = 0,
	enemyKitOf = function(_key: any): { string }
		return {}
	end,
}

local function isPlayer(key: any): boolean
	return typeof(key) == "Instance" and key:IsA("Player")
end

local function pruneKit(s: Seat, loadout: ModLoadout.Loadout?): boolean
	local changed = false
	for slot, id in s.kit do
		if id ~= "" and not ModLoadout.eligible(id, loadout) then
			s.kit[slot], s.levels[slot] = "", ""
			changed = true
		end
	end
	return changed
end

-- Sends a player their seat's cards (and what's already selected for them).
local function sendOffer(player: Player, s: Seat)
	StateValues.set(player, "DraftLocked", s.locked)
	local offer: MatchState.DraftOffer = {
		round = dealt.round,
		phase = DraftService.phaseFor(dealt.round).name,
		endsAt = dealt.endsAt,
		guns = s.guns,
		abilities = s.abilities,
		upgrades = s.upgrades,
		kit = s.kit,
		levels = s.levels,
		enemyKit = dealt.enemyKitOf(player),
		gun = s.gun,
		ability = s.ability,
		focus = s.focus or nil,
		hidden = s.hidden or nil,
	}
	s.offer = offer
	Net.event("DraftOffer"):FireClient(player, offer)
end

-- This match's onboarding script (Config/Onboarding SCRIPT; MatchService sets "OnboardingMatch"), nil in
-- any other match.
function DraftService.script(): OnbConfig.Script?
	local index = MatchState.get("OnboardingMatch")
	return if typeof(index) == "number" then OnbConfig.SCRIPT[index] else nil
end

-- The script's step for `round`, nil when that round deals the normal cards.
function DraftService.scriptStep(round: number): OnbConfig.Round?
	local plan = DraftService.script()
	return if plan then plan.rounds[round] else nil
end

-- A scripted round (vault/01 Design/First Ten Minutes.md): its start kit, then only the cards it names. False when
-- nothing it names can be dealt, so the normal deal runs instead.
local function dealScripted(s: Seat, step: OnbConfig.Round, deck: { string }): boolean
	for _, id in step.kit or {} do
		local def = Mods.def(id)
		local slot = firstFree(s.kit)
		if
			def
			and slot
			and Mods.isBuilt(id)
			and not table.find(s.kit, def.id)
			and table.find(deck, def.id)
		then
			s.kit[slot] = def.id
			s.levels[slot] = Config.ABILITY_LEVEL
		end
	end
	if step.select == "none" then
		s.ability = nil
		s.locked = true
		s.hidden = true
		return true
	end
	local offer = step.offer
	if offer == "glitch" then
		-- The Glitched card, on the script's starter power when it's still level 1, else any level-1 power.
		local want: { [string]: boolean } = {}
		for _, r in (DraftService.script() :: OnbConfig.Script).rounds do
			for _, id in r.kit or {} do
				want[id] = true
			end
		end
		local best: number? = nil
		for slot = 1, ModsConfig.SLOTS do
			if s.kit[slot] ~= "" and s.levels[slot] == "L1" and Mods.isBuilt(s.kit[slot]) then
				if best == nil or (want[s.kit[slot]] and not want[s.kit[best]]) then
					best = slot
				end
			end
		end
		if not best then
			return false
		end
		local c = card(s.kit[best], best, "G2")
		s.upgrades = { c }
		s.ability = c.key
		s.glitchDealt = true
		return true
	elseif typeof(offer) == "table" then
		for _, id in offer do
			local def = Mods.def(id)
			if
				def
				and firstFree(s.kit)
				and not table.find(s.kit, def.id)
				and not table.find(s.abilities, def.id)
				and table.find(deck, def.id)
			then
				table.insert(s.abilities, def.id)
			end
		end
		s.ability = s.abilities[1]
		return #s.abilities > 0
	end
	return false
end

-- Deals one seat this draft's cards. Something is selected from the start
-- (vault/05 Production/Match Structure Revamp.md): the first ability card. Bots pick over it.
local function deal(key: any)
	local s = DraftService.seat(key)
	local human = isPlayer(key)
	local loadout = if human then PlayerData.mods(key) else nil
	local deck = deckOf(loadout, human)
	if human then
		pruneKit(s, loadout)
	end
	s.guns = {}
	s.abilities = {}
	s.upgrades = {}
	s.locked = false
	s.gun = nil
	s.focus, s.hidden = false, false
	-- Onboarding: a new player's first matches follow Config/Onboarding SCRIPT (no gun row: the phase's gun is
	-- handed out; scripted rounds deal only what they name).
	local plan = if human then DraftService.script() else nil
	if plan then
		s.focus = true
		if plan.handGuns then
			s.gun = handedGun(dealt.round)
		end
		local step = plan.rounds[dealt.round]
		if step and dealScripted(s, step, deck) then
			s.dealtRound = dealt.round
			sendOffer(key, s)
			return
		end
		s.abilities, s.upgrades, s.ability, s.locked, s.hidden = {}, {}, nil, false, false
	end
	-- One new power from the deck per empty slot (all of them land on the first empty slot when picked).
	-- Prefer cards that have been offered to fewer seats and skip the seat's last offer.
	for slot = 1, ModsConfig.SLOTS do
		if s.kit[slot] ~= "" then
			continue
		end
		local id = rollNewMod(s, deck)
		if id then
			table.insert(s.abilities, id)
		end
	end
	s.lastNewMods = table.clone(s.abilities)
	-- Onboarding (owner 2026-11-25): a new player is dealt a Glitched card by round GLITCH.onboardingRound, and it
	-- comes preselected so the moment happens even if they don't look.
	local guarantee = human
		and not s.glitchDealt
		and dealt.round >= Config.GLITCH.onboardingRound
		and MatchState.get("PhaseBoost") == true
	s.upgrades = rollUpgrades(s, guarantee)
	local glitchCard: string? = nil
	for _, c in s.upgrades do
		if string.sub(c.level, 1, 1) == "G" then
			s.glitchDealt = true
			glitchCard = c.key
		end
	end
	s.ability = if guarantee and glitchCard
		then glitchCard
		else s.abilities[1] or (s.upgrades[1] and s.upgrades[1].key)
	s.dealtRound = dealt.round
	if human then
		sendOffer(key, s)
	end
end

-- Shuffle seat order so the same side doesn't consistently get first pick of the Mod pools.
function DraftService.open(
	keys: { any },
	round: number,
	endsAt: number,
	enemyKitOf: (key: any) -> { string }
)
	table.clear(abilityOfferCounts)
	dealt.round, dealt.endsAt, dealt.enemyKitOf = round, endsAt, enemyKitOf
	local order = table.clone(keys)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for _, key in order do
		deal(key)
	end
	open = true
end

function DraftService.isOpen(): boolean
	return open
end

-- Someone joined while the draft is open: deal them in (unless this draft
-- already dealt their seat).
function DraftService.join(key: any)
	local s = seats[key]
	if open and (not s or s.dealtRound ~= dealt.round) then
		deal(key)
	end
end

-- A seat changes hands (a player takes their bot stand-in's place, or a bot
-- takes a leaver's): kit, levels, guns and this draft's cards go with it. A
-- player who takes a seat mid-draft gets the bot's picks unlocked, provided
-- the seat only holds eligible Mods.
function DraftService.transfer(from: any, to: any)
	local s = seats[from]
	if not s then
		return
	end
	seats[from] = nil
	s.key = to
	seats[to] = s
	if isPlayer(to) then
		local loadout = PlayerData.mods(to)
		local needsDeal = pruneKit(s, loadout)
		if open then
			for _, id in s.abilities do
				needsDeal = needsDeal or not ModLoadout.eligible(id, loadout)
			end
			if needsDeal then
				deal(to)
			else
				s.locked = false
				sendOffer(to, s)
			end
		end
	end
end

function DraftService.allLocked(keys: { any }): boolean
	for _, key in keys do
		local s = seats[key]
		if s and not s.locked then
			return false
		end
	end
	return true
end

-- Ends the draft: unlocked seats get their last click or the first card. Kits
-- and guns are updated, and MatchService gives them out.
function DraftService.close(keys: { any })
	open = false
	local phaseName = DraftService.phaseFor(dealt.round).name
	for _, key in keys do
		local s = DraftService.seat(key)
		local handed = s.gun
		if handed then
			-- onboarding: the handed gun (a secondary replaces both guns, a primary comes with the Classic)
			local config = Weapons.get(handed)
			if config and config.slot == "Secondary" then
				s.sidearm, s.primary = handed, nil
			else
				s.primary, s.sidearm = handed, Weapons.DEFAULT_LOADOUT.Secondary
			end
		else
			-- the saved loadout, read now so a Locker change made before the match is in
			local guns: GunLoadout.Loadout
			if isPlayer(key) then
				guns = PlayerData.guns(key)
			else
				guns = s.botGuns or GunLoadout.random(rng)
				s.botGuns = guns
			end
			s.primary, s.sidearm = GunLoadout.forRound(guns, dealt.round)
		end
		s.shield = MatchState.shieldFor(phaseName, s.primary or s.sidearm)
		-- Your pick, else the first card.
		local first = s.abilities[1] or (s.upgrades[1] and s.upgrades[1].key)
		local pick = s.ability or first
		local def = pick and Mods.def(pick)
		local upgrade = pick and upgradeByKey(s, pick)
		local free = firstFree(s.kit)
		if def and free and table.find(s.abilities, def.id) and not table.find(s.kit, def.id) then
			s.kit[free] = def.id
			s.levels[free] = Config.ABILITY_LEVEL
			tellPick(key, def.id, Config.ABILITY_LEVEL)
		elseif upgrade and s.kit[upgrade.slot] == upgrade.id then
			s.levels[upgrade.slot] = upgrade.level
			tellPick(key, upgrade.id, upgrade.level)
		end
		s.locked = true
	end
end

local function onPick(player: Player, actionArg: unknown, idArg: unknown)
	if not limiter:allow(player, "DraftPick") then
		return
	end
	local action = Validate.enum(actionArg, ACTIONS)
	if not action then
		return
	end
	local s = seats[player]
	if not open or not s then
		return
	end
	if action ~= "Sync" and workspace:GetServerTimeNow() > dealt.endsAt then
		return -- past the deadline (the loop closes the draft on its next poll)
	end
	if action == "Sync" then
		-- A client that started up after the deal asks for its cards.
		if s.offer then
			Net.event("DraftOffer"):FireClient(player, s.offer)
		end
		return
	end
	if s.locked then
		return
	end
	if action == "Lock" then
		-- Nothing to confirm until a card is picked (no gun row since the gun loadout).
		local nothingToPick = #s.abilities == 0 and #s.upgrades == 0
		if s.ability ~= nil or nothingToPick then
			s.locked = true
			StateValues.set(player, "DraftLocked", true)
		end
		return
	end
	if typeof(idArg) ~= "string" or #idArg > ModLoadout.MAX_ID_LENGTH + #":A2" then
		return
	end
	if action == "Ability" and (table.find(s.abilities, idArg) or upgradeByKey(s, idArg)) then
		s.ability = idArg
	end
end

function DraftService.init()
	Net.event("DraftPick").OnServerEvent:Connect(onPick)
end

function DraftService.start()
	-- The seat itself stays: MatchService hands it to a bot or forgets it.
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return DraftService
