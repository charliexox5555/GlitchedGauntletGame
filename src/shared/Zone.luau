--!strict
-- The sudden-death circle (vault/05 Production/Match Structure Revamp.md),
-- read the same way by the server (damage, bots) and clients (the wall, the
-- tint). ZoneService writes it as ReplicatedStorage attributes: the centre,
-- the radius it shrinks from/to and the server times it does so, then
-- `MatchZoneId` last (the commit; 0 = no zone). Clients work out the radius
-- from Workspace:GetServerTimeNow(), so late joiners land mid-shrink.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zone = {}

export type State = {
	id: number,
	centre: Vector3,
	fromRadius: number,
	toRadius: number,
	startAt: number,
	endAt: number,
}

Zone.ID = "MatchZoneId"
Zone.CENTRE = "MatchZoneCentre"
Zone.RADIUS = "MatchZoneRadius" -- Vector2(from, to)
-- Server times are plain number attributes: Vector2/Vector3 attributes are
-- 32-bit floats, which round a server time (~1.8e9) to about two minutes.
Zone.START = "MatchZoneStart"
Zone.END = "MatchZoneEnd"

-- The zone now, or nil when there's none.
function Zone.read(): State?
	local id = ReplicatedStorage:GetAttribute(Zone.ID)
	local centre = ReplicatedStorage:GetAttribute(Zone.CENTRE)
	local radius = ReplicatedStorage:GetAttribute(Zone.RADIUS)
	local startAt = ReplicatedStorage:GetAttribute(Zone.START)
	local endAt = ReplicatedStorage:GetAttribute(Zone.END)
	if
		typeof(id) ~= "number"
		or id == 0
		or typeof(centre) ~= "Vector3"
		or typeof(radius) ~= "Vector2"
		or typeof(startAt) ~= "number"
		or typeof(endAt) ~= "number"
	then
		return nil
	end
	return {
		id = id,
		centre = centre,
		fromRadius = radius.X,
		toRadius = radius.Y,
		startAt = startAt,
		endAt = endAt,
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
	return ReplicatedStorage:GetAttributeChangedSignal(Zone.ID)
end

return Zone
