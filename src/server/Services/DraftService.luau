--!strict
-- The between-round draft (vault/01 Design/Match Flow.md): deals each player 3
-- guns and 3 ability cards, takes their picks, then hands them to MatchService.
-- The server rolls and stores every offer, and a pick is only ever checked
-- against that stored list, so a client can't ask for anything it wasn't dealt.
--
-- Abilities live in fixed slots (Config/Mods `slot`): new abilities are only
-- offered for slots you haven't filled. With nothing new to offer, the cards
-- are upgrades (vault/01 Design/Abilities/Upgrade Paths.md): for each ability
-- at level 1, path A and path B (and sometimes the glitch path); at level 2,
-- the next level of its path. One card per draft.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Dev = require(ReplicatedStorage.Shared.Config.Dev)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Validate = require(ReplicatedStorage.Shared.Util.Validate)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local DraftService = {}

local ACTIONS = { Gun = true, Ability = true, Lock = true, Sync = true }

-- What one side of the draft holds for the whole match (players and the test
-- opponent alike; `key` is a Player or the opponent's marker table).
export type Seat = {
	key: any,
	kit: { string }, -- ability per slot, "" = empty
	levels: { string }, -- its level per slot, "" = empty
	sidearm: string?,
	primary: string?,
	shield: number, -- what the gun chosen this round gives
	-- This draft:
	guns: { string },
	abilities: { string },
	upgrades: { MatchState.UpgradeCard },
	gun: string?,
	ability: string?, -- a new ability's id, or an upgrade card's key
	glitchBonus: number, -- the glitch chance's rise since the last glitch card
	locked: boolean,
	offer: MatchState.DraftOffer?,
}

local limiter = RateLimit.new(Config.RATE)
local seats: { [any]: Seat } = {}
local open = false
local rng = Random.new()
local gunOffer: { string } = {}
local gunOfferPhase = ""
local abilityOrder: { string } = {}

local function shuffled(list: { string }): { string }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Guns of a tier that are really installed in this place.
local function gunsOfTier(tier: number): { string }
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	local list: { string } = {}
	for id, w in Weapons.list do
		if w.tier == tier and folder and folder:FindFirstChild(id) then
			table.insert(list, id)
		end
	end
	table.sort(list) -- a stable start, so the shuffle alone decides the order
	return list
end

-- 3 guns for the phase: its own tier first, then the tiers below when short.
local function rollGuns(phase: Config.Phase): { string }
	local offer = shuffled(gunsOfTier(phase.tier))
	local tier = phase.tier - 1
	while #offer < Config.GUN_OFFERS and tier >= 1 do
		for _, id in shuffled(gunsOfTier(tier)) do
			table.insert(offer, id)
		end
		tier -= 1
	end
	return { table.unpack(offer, 1, math.min(#offer, Config.GUN_OFFERS)) }
end

local function builtAbilities(): { string }
	local list: { string } = {}
	for id in ModsConfig.defs do
		if Mods.isBuilt(id) then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function DraftService.phaseFor(round: number): Config.Phase
	local found = Config.PHASES[1]
	for _, p in Config.PHASES do
		if round >= p.fromRound then
			found = p
		end
	end
	return found
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

-- The upgrade cards for a seat whose slots are settled: the next level of
-- each ability, and at level 1 its two paths plus, by chance, the glitch.
local function rollUpgrades(s: Seat): { MatchState.UpgradeCard }
	local cards: { MatchState.UpgradeCard } = {}
	local glitch = Config.GLITCH
	local eligible, glitched = false, false
	for slot = 1, ModsConfig.SLOTS do
		local id, level = s.kit[slot], s.levels[slot]
		if id == "" or not Mods.isBuilt(id) then
			continue
		end
		if level == "L1" then
			eligible = true
			table.insert(cards, card(id, slot, "A2"))
			table.insert(cards, card(id, slot, "B2"))
			local chance = math.min(glitch.chance + s.glitchBonus, glitch.cap)
			if Dev.ALWAYS_GLITCH_CARDS and RunService:IsStudio() then
				chance = 1
			end
			if rng:NextNumber() < chance then
				glitched = true
				table.insert(cards, card(id, slot, "G2"))
			end
		elseif NEXT[level] then
			table.insert(cards, card(id, slot, NEXT[level]))
		end
	end
	if glitched then
		s.glitchBonus = 0
	elseif eligible then
		s.glitchBonus += glitch.step
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
	local s = DraftService.seat(key)
	local out: { string } = {}
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
	gunOffer = {}
	gunOfferPhase = ""
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
			locked = false,
			glitchBonus = 0,
		}
		seats[key] = s
	end
	return s
end

function DraftService.forget(key: any)
	seats[key] = nil
end

-- Deals every seat its cards and tells the players. The gun offer lasts as long
-- as the phase; the ability order is shared, so 1v1 offers match until someone
-- already owns a card.
function DraftService.open(
	keys: { any },
	round: number,
	endsAt: number,
	enemyKitOf: (key: any) -> { string }
)
	local phase = DraftService.phaseFor(round)
	if phase.name ~= gunOfferPhase then
		gunOfferPhase = phase.name
		gunOffer = rollGuns(phase)
	end
	abilityOrder = shuffled(builtAbilities())
	for _, key in keys do
		local s = DraftService.seat(key)
		s.guns = gunOffer
		s.abilities = {}
		s.upgrades = {}
		s.gun = nil
		s.ability = nil
		s.locked = false
		-- Your gun from last round stays selected while it's still on offer.
		local current = if phase.tier == 1 then s.sidearm else s.primary
		if current and table.find(gunOffer, current) then
			s.gun = current
		end
		-- New abilities for the empty slots; with none to offer, upgrades.
		for _, id in abilityOrder do
			local def = Mods.def(id)
			if def and s.kit[def.slot] == "" then
				table.insert(s.abilities, id)
			end
			if #s.abilities == Config.ABILITY_OFFERS then
				break
			end
		end
		if #s.abilities == 0 then
			s.upgrades = rollUpgrades(s)
		end
		if typeof(key) == "Instance" and key:IsA("Player") then
			key:SetAttribute("DraftLocked", false)
			local offer: MatchState.DraftOffer = {
				round = round,
				phase = phase.name,
				endsAt = endsAt,
				guns = s.guns,
				abilities = s.abilities,
				upgrades = s.upgrades,
				kit = s.kit,
				levels = s.levels,
				enemyKit = enemyKitOf(key),
				gun = s.gun,
			}
			s.offer = offer
			Net.event("DraftOffer"):FireClient(key, offer)
		end
	end
	open = true
end

-- Picks for a seat with nobody clicking (the test opponent).
function DraftService.autoPick(key: any)
	local s = DraftService.seat(key)
	s.gun = s.gun or s.guns[rng:NextInteger(1, math.max(#s.guns, 1))]
	if #s.abilities > 0 then
		s.ability = s.abilities[rng:NextInteger(1, #s.abilities)]
	elseif #s.upgrades > 0 then
		s.ability = s.upgrades[rng:NextInteger(1, #s.upgrades)].key
	end
	s.locked = true
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
	local phaseName = gunOfferPhase
	for _, key in keys do
		local s = DraftService.seat(key)
		local gun = s.gun or s.guns[1]
		if gun then
			local config = Weapons.get(gun)
			if config and config.slot == "Secondary" then
				s.sidearm = gun
			else
				s.primary = gun
			end
		end
		s.shield = MatchState.shieldFor(phaseName, gun)
		-- Your pick, else the first card.
		local first = s.abilities[1] or (s.upgrades[1] and s.upgrades[1].key)
		local pick = s.ability or first
		local def = pick and Mods.def(pick)
		local upgrade = pick and upgradeByKey(s, pick)
		if def and table.find(s.abilities, def.id) and s.kit[def.slot] == "" then
			s.kit[def.slot] = def.id
			s.levels[def.slot] = Config.ABILITY_LEVEL
		elseif upgrade and s.kit[upgrade.slot] == upgrade.id then
			s.levels[upgrade.slot] = upgrade.level
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
		-- Nothing to confirm until both rows have a pick.
		local nothingToPick = #s.abilities == 0 and #s.upgrades == 0
		if s.gun ~= nil and (s.ability ~= nil or nothingToPick) then
			s.locked = true
			player:SetAttribute("DraftLocked", true)
		end
		return
	end
	if typeof(idArg) ~= "string" or #idArg > 32 then
		return
	end
	if action == "Gun" and table.find(s.guns, idArg) then
		s.gun = idArg
	elseif action == "Ability" and (table.find(s.abilities, idArg) or upgradeByKey(s, idArg)) then
		s.ability = idArg
	end
end

function DraftService.init()
	Net.event("DraftPick").OnServerEvent:Connect(onPick)
end

function DraftService.start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		DraftService.forget(player)
	end)
end

return DraftService
