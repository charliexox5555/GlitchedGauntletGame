--!strict
-- The match state both sides read: attributes on ReplicatedStorage, written
-- only by MatchService. Late joiners get them for free, and timers are one end
-- time (Workspace:GetServerTimeNow) rather than a remote every second.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config.Match)
local Weapons = require(script.Parent.Config.Weapons)

export type Phase =
	"Waiting"
	| "Draft"
	| "Countdown"
	| "Live"
	| "SuddenDeath"
	| "RoundEnd"
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

-- Player attribute: no shots and no abilities (the server enforces it too).
MatchState.COMBAT_LOCKED = "CombatLocked"

function MatchState.set(name: string, value: any)
	ReplicatedStorage:SetAttribute("Match" .. name, value)
end

function MatchState.get(name: string): any
	return ReplicatedStorage:GetAttribute("Match" .. name)
end

function MatchState.changed(name: string): RBXScriptSignal
	return ReplicatedStorage:GetAttributeChangedSignal("Match" .. name)
end

function MatchState.phase(): Phase?
	return MatchState.get("Phase")
end

-- The shield a gun gives in a weapon phase (vault/01 Design/Gun Balance.md).
function MatchState.shieldFor(phaseName: string, gunId: string?): number
	for _, phase in Config.PHASES do
		if phase.name == phaseName and phase.flatShield then
			return phase.flatShield
		end
	end
	local gun = gunId and Weapons.get(gunId)
	return gun and gun.shield or 0
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
