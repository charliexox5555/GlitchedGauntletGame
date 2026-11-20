--!strict
-- The sudden-death circle (vault/05 Production/Match Structure Revamp.md),
-- read the same way by the server (damage, bots) and clients (the wall, the
-- tint). ZoneService writes one snapshot to MatchState. Clients work out the radius
-- from Workspace:GetServerTimeNow(), so late joiners land mid-shrink.

local MatchState = require(script.Parent.MatchState)

local Zone = {}

export type State = {
	id: number,
	centre: Vector3,
	fromRadius: number,
	toRadius: number,
	startAt: number,
	endAt: number,
}

function Zone.publish(state: State?)
	MatchState.set(
		"Zone",
		if state
			then {
				state.id,
				state.centre.X,
				state.centre.Y,
				state.centre.Z,
				state.fromRadius,
				state.toRadius,
				state.startAt,
				state.endAt,
			}
			else nil
	)
end

-- The zone now, or nil when there's none.
function Zone.read(): State?
	local state = MatchState.get("Zone")
	if state == nil then
		return nil
	end
	return {
		id = state[1],
		centre = Vector3.new(state[2], state[3], state[4]),
		fromRadius = state[5],
		toRadius = state[6],
		startAt = state[7],
		endAt = state[8],
	}
end

-- The circle's radius at server time `now` (smoothstep, so it eases in and out).
function Zone.radiusAt(state: State, now: number): number
	local span = state.endAt - state.startAt
	local t = if span > 0 then math.clamp((now - state.startAt) / span, 0, 1) else 1
	t = t * t * (3 - 2 * t)
	return state.fromRadius + (state.toRadius - state.fromRadius) * t
end

-- How far outside the circle a position is (studs, flat; ≤ 0 inside).
function Zone.outside(state: State, position: Vector3, now: number): number
	local flat = Vector3.new(position.X - state.centre.X, 0, position.Z - state.centre.Z)
	return flat.Magnitude - Zone.radiusAt(state, now)
end

function Zone.changed(): RBXScriptSignal
	return MatchState.changed("Zone")
end

return Zone
