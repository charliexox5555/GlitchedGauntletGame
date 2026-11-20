--!strict
-- Server-owned match state. Each replicated value carries one encoded field,
-- including whole lists. Timers are server timestamps, not per-second updates.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config.Match)
local Weapons = require(script.Parent.Config.Weapons)

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
local fields: { [string]: StringValue } = {}
local cache: { [string]: { encoded: string, value: any } } = {}

if RunService:IsServer() and not ReplicatedStorage:FindFirstChild(FOLDER) then
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, name in
		{
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
		}
	do
		local field = Instance.new("StringValue")
		field.Name = name
		field.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function field(name: string, waitForReplication: boolean): StringValue?
	if fields[name] then
		return fields[name]
	end
	local folder = if waitForReplication
		then ReplicatedStorage:WaitForChild(FOLDER)
		else ReplicatedStorage:FindFirstChild(FOLDER)
	if not folder then
		return nil
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

function MatchState.botSeats(): { Configuration }
	local folder = ReplicatedStorage:FindFirstChild(MatchState.BOT_SEATS)
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

function MatchState.set(name: string, value: any)
	assert(RunService:IsServer(), "Only the server can publish match state")
	local target = assert(field(name, false), "Unknown match field: " .. name)
	target.Value = if value == nil then "" else HttpService:JSONEncode(value)
end

function MatchState.get(name: string): any
	local source = field(name, false)
	local encoded = if source then source.Value else ""
	if encoded == "" then
		return nil
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

function MatchState.phase(): Phase?
	return MatchState.get("Phase")
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
function MatchState.isSpawnHold(): boolean
	local phase = MatchState.get("Phase")
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
