--!strict
-- The match state both sides read: attributes on ReplicatedStorage, written
-- only by MatchService. Late joiners get them for free, and timers are one end
-- time (Workspace:GetServerTimeNow) rather than a remote every second.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Phase = "Waiting" | "Ready" | "Draft" | "Countdown" | "Live" | "RoundEnd" | "MatchEnd"

-- A gun or ability card the server dealt to one player.
export type DraftOffer = {
	round: number,
	phase: string, -- the weapon phase's name
	endsAt: number,
	guns: { string },
	abilities: { string }, -- empty once every slot is full
	kit: { string }, -- your abilities, Q / E / T order
	enemyKit: { string },
	gun: string?, -- already selected (your gun, while the phase's offer lasts)
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

-- Seconds left on the current phase's clock.
function MatchState.timeLeft(): number
	local endsAt = MatchState.get("EndsAt")
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(endsAt - workspace:GetServerTimeNow(), 0)
end

return MatchState
