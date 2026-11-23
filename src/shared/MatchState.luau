--!strict
-- Server-owned match state. Each replicated value carries one encoded field,
-- including whole lists. Timers are server timestamps, not per-second updates.
--
-- Several matches per server (place merge 2026-11-21, vault/04 Tech/Place
-- Merge Plan.md): each match has its own folder of fields.
--  * A server match (MatchHost) runs on its own copy of this module, bound to
--    its folder with bind(); in a whole-server match that folder is the
--    classic ReplicatedStorage.MatchState.
--  * Everyone else finds the folder per player: a player (or a bot body)
--    carrying the `MatchId` attribute reads ReplicatedStorage.Matches[MatchId];
--    the client uses the local player. Without one it's ReplicatedStorage.MatchState.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Absolute, so a copy of this module (outside Shared) still finds them.
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = SharedFolder:WaitForChild("Config")
local Config = require(ConfigFolder:WaitForChild("Match") :: ModuleScript)
local Weapons = require(ConfigFolder:WaitForChild("Weapons") :: ModuleScript)

export type Phase =
	"Waiting"
	| "Vote" -- the map vote before round 1 (MapVoteService)
	| "Draft"
	| "Countdown"
	| "Live"
	| "SuddenDeath"
	| "RoundEnd"
	| "Replay"
	| "MatchEnd"

-- One upgrade card: ability `id` in `slot` to `level` (path A, B or G).
export type UpgradeCard = {
	key: string, -- "id:level", what a pick sends
	id: string,
	slot: number,
	level: string,
}

-- A gun or ability card the server dealt to one player.
export type DraftOffer = {
	round: number,
	phase: string, -- the weapon phase's name
	endsAt: number,
	guns: { string },
	abilities: { string }, -- new abilities, one per empty slot
	upgrades: { UpgradeCard }, -- for the filled slots
	kit: { string }, -- your ability per slot (Q / E / T), "" = empty
	levels: { string }, -- their levels, "" = empty
	enemyKit: { string }, -- "id:level" for each enemy ability
	gun: string?, -- already selected (your gun while it's offered, else the first)
	ability: string?, -- already selected (an id or an upgrade card's key)
}

local MatchState = {}

local FOLDER = "MatchState"
MatchState.FOLDER = FOLDER
MatchState.MATCHES = "Matches" -- ReplicatedStorage folder of per-match folders
MatchState.MATCH_ID = "MatchId" -- attribute on a player or bot body

local FIELD_NAMES = {
	"Phase",
	"EndsAt",
	"Round",
	"RoundWinner",
	"Score1",
	"Score2",
	"MatchWinner",
	"RoundHistory",
	"Results",
	"WeaponPhase",
	"VoteOptions",
	"VoteChosen",
	"VoteTeamSize",
	"ReadyPlayers",
	"ExpectedPlayers",
	"RematchVotes",
	"RematchNeeded",
	"RematchOpen",
	"Zone",
	"Mode", -- the queued mode ("beginner", "2v2", ...): Controllers/BeginnerHighlightController
}

-- A folder of every field, named `name`, under `parent` (made once).
function MatchState.createFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, fieldName in FIELD_NAMES do
		local value = Instance.new("StringValue")
		value.Name = fieldName
		value.Parent = folder
	end
	folder.Parent = parent
	return folder
end

if RunService:IsServer() and not ReplicatedStorage:FindFirstChild(FOLDER) then
	MatchState.createFolder(ReplicatedStorage, FOLDER)
end

-- This copy's own folder (a server match's copy, bind()).
local bound: Folder? = nil
-- Field lookups for the folder last used (cleared when the folder changes).
local lastFolder: Instance? = nil
local fields: { [string]: StringValue } = {}
local cache: { [string]: { encoded: string, value: any } } = {}

function MatchState.bind(folder: Folder)
	bound = folder
end

local function matchIdOf(who: Instance?): string?
	local subject: Instance? = who
	if subject == nil and RunService:IsClient() then
		subject = Players.LocalPlayer
	end
	if typeof(subject) ~= "Instance" then
		return nil
	end
	local id = (subject :: Instance):GetAttribute(MatchState.MATCH_ID)
	return if typeof(id) == "string" and id ~= "" then id else nil
end

-- The folder holding `who`'s match (see the top of this file).
function MatchState.folderFor(who: Instance?, waitForReplication: boolean?): Instance?
	if bound and who == nil then
		return bound
	end
	local id = matchIdOf(who)
	if id then
		local matches = if waitForReplication
			then ReplicatedStorage:WaitForChild(MatchState.MATCHES)
			else ReplicatedStorage:FindFirstChild(MatchState.MATCHES)
		if not matches then
			return nil
		end
		return if waitForReplication then matches:WaitForChild(id) else matches:FindFirstChild(id)
	end
	if bound then
		return bound
	end
	return if waitForReplication
		then ReplicatedStorage:WaitForChild(FOLDER)
		else ReplicatedStorage:FindFirstChild(FOLDER)
end

local function field(name: string, waitForReplication: boolean, who: Instance?): StringValue?
	local folder = MatchState.folderFor(who, waitForReplication)
	if not folder then
		return nil
	end
	if who ~= nil then
		-- Someone else's match: no shared cache.
		local value = folder:FindFirstChild(name)
		return if value and value:IsA("StringValue") then value else nil
	end
	if folder ~= lastFolder then
		lastFolder = folder
		table.clear(fields)
		table.clear(cache)
	end
	if fields[name] then
		return fields[name]
	end
	local value = if waitForReplication and not RunService:IsServer()
		then folder:WaitForChild(name)
		else folder:FindFirstChild(name)
	if value and value:IsA("StringValue") then
		fields[name] = value
		return value
	end
	return nil
end

-- Player state field for the server-enforced combat lock.
MatchState.COMBAT_LOCKED = "CombatLocked"
MatchState.BOT_SEATS = "MatchBotSeats"

-- Where a match keeps its bot seats: inside its own folder for a scoped match,
-- ReplicatedStorage for a whole-server one.
function MatchState.seatsParent(who: Instance?): Instance
	local folder = MatchState.folderFor(who, false)
	if folder and folder.Name ~= FOLDER then
		return folder
	end
	return ReplicatedStorage
end

function MatchState.botSeats(): { Configuration }
	local folder = MatchState.seatsParent():FindFirstChild(MatchState.BOT_SEATS)
	local seats: { Configuration } = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Configuration") then
				table.insert(seats, child)
			end
		end
	end
	return seats
end

local warnedUnknown: { [string]: boolean } = {}

function MatchState.set(name: string, value: any)
	assert(RunService:IsServer(), "Only the server can publish match state")
	local target = field(name, false)
	if not target then
		-- a field missing from FIELD_NAMES is a bug, but it must never stop a live match
		-- (2026-11-23: "Mode" did, and every match fell back to the lobby)
		if not warnedUnknown[name] then
			warnedUnknown[name] = true
			warn(`[MatchState] unknown match field {name}: add it to FIELD_NAMES`)
		end
		return
	end
	target.Value = if value == nil then "" else HttpService:JSONEncode(value)
end

-- `who`: read that player's (or bot body's) match instead of this one's.
function MatchState.get(name: string, who: Instance?): any
	local source = field(name, false, who)
	local encoded = if source then source.Value else ""
	if encoded == "" then
		return nil
	end
	if who ~= nil then
		return HttpService:JSONDecode(encoded)
	end
	local saved = cache[name]
	if saved and saved.encoded == encoded then
		return saved.value
	end
	local value = HttpService:JSONDecode(encoded)
	cache[name] = { encoded = encoded, value = value }
	return value
end

function MatchState.setList(name: string, items: { string })
	MatchState.set(name, items)
end

function MatchState.getList(name: string): { string }
	local items = MatchState.get(name)
	return if typeof(items) == "table" then table.clone(items) else {}
end

function MatchState.changed(name: string): RBXScriptSignal
	return assert(field(name, true), "Unknown match field: " .. name):GetPropertyChangedSignal(
		"Value"
	)
end

function MatchState.phase(who: Instance?): Phase?
	return MatchState.get("Phase", who)
end

-- The shield a gun gives in a weapon phase (vault/01 Design/Gun Balance.md).
function MatchState.shieldFor(phaseName: string, gunId: string?): number
	for _, phase in Config.PHASES do
		if phase.name == phaseName then
			local shield = phase.flatShield
				or (gunId and phase.shieldByGun and phase.shieldByGun[gunId])
			if shield ~= nil then
				return shield
			end
			break
		end
	end
	local gun = gunId and Weapons.get(gunId)
	return gun and gun.shield or 0
end

-- How long the final-kill replay plays (Config/Match REPLAY), start delay
-- and end hold included: the server's Replay phase and every client's
-- playback use this one sum.
-- Playback seconds of the final-kill replay (ReplayController.recordedAt):
-- normal speed, an eased ramp of `slowRamp` playback seconds down to
-- `slowSpeed` that ends `slowFrom` before the kill, then slow to the end.
function MatchState.replayPlayback(): number
	local R = Config.REPLAY
	local rampRecorded = R.slowRamp * (1 + R.slowSpeed) / 2
	return (R.before - R.slowFrom - rampRecorded)
		+ R.slowRamp
		+ (R.slowFrom + R.after) / R.slowSpeed
end

function MatchState.replayLength(): number
	local R = Config.REPLAY
	return R.delay + MatchState.replayPlayback() + R.hold
end

-- The spawn hold (vault/01 Design/Spawn Hold.md): the select and its 3-2-1,
-- when every fighter waits at their marker. Read by the movement simulation
-- (no moving or jumping) and SpawnHoldController (ghost bodies).
function MatchState.isSpawnHold(who: Instance?): boolean
	local phase = MatchState.get("Phase", who)
	return phase == "Draft" or phase == "Countdown"
end

-- Seconds left on the current phase's clock.
function MatchState.timeLeft(): number
	local endsAt = MatchState.get("EndsAt")
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(endsAt - workspace:GetServerTimeNow(), 0)
end

return MatchState
