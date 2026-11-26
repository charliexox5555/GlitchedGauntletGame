--!strict
-- The range's moving dummy carriage (vault/01 Design/Range v5.md): where it is is a pure function of the server
-- clock, so the server (hit checks) and every client (drawing it) agree without sending positions. It waits `pause`
-- seconds at each end and eases in and out of every run.
--
-- Who moves what (2026-11-26, the network check): the server moves only the rider (a `RangeBot` inside the carriage,
-- which hits are checked against), a few times a second; each client moves the whole carriage, rider included,
-- every frame. The carriage's own parts never move on the server, so nothing about them is sent.

local CollectionService = game:GetService("CollectionService")

local RangeDummies = require(script.Parent.Config.RangeDummies)

local RangeCarriage = {}

RangeCarriage.TAG = "RangeMovingDummy"
RangeCarriage.RIDER_TAG = "RangeBot"
RangeCarriage.OFFSET_ATTRIBUTE = "CarriageOffset" -- on a rider: its pivot relative to the carriage's home
RangeCarriage.HOME_ATTRIBUTE = "Home" -- on the carriage: its pivot where it was built (stamped by the server)

-- World X of a carriage running between `from` and `to` at an average `speed` studs/s, at server time `t`.
function RangeCarriage.x(from: number, to: number, speed: number, t: number): number
	local distance = math.abs(to - from)
	if distance < 1e-3 or speed <= 0 or speed ~= speed then
		return from
	end
	local pause = RangeDummies.CARRIAGE.pause
	local run = distance / speed
	local half = run + pause
	local u = t % (2 * half)
	local outbound = u < half
	local s = if outbound then u else u - half
	local k = math.clamp((s - pause) / run, 0, 1)
	local eased = (1 - math.cos(math.pi * k)) / 2
	return if outbound then from + (to - from) * eased else to + (from - to) * eased
end

-- The carriage's pivot at server time `t`, from its home pivot and its From / To / Speed attributes (nil: none).
function RangeCarriage.pose(model: Model, home: CFrame, t: number): CFrame?
	local from, to, speed =
		model:GetAttribute("From"), model:GetAttribute("To"), model:GetAttribute("Speed")
	if typeof(from) ~= "number" or typeof(to) ~= "number" or typeof(speed) ~= "number" then
		return nil
	end
	return CFrame.new(RangeCarriage.x(from, to, speed, t), home.Y, home.Z) * home.Rotation
end

-- The riders on a carriage (its RangeBot models).
function RangeCarriage.riders(model: Model): { Model }
	local out: { Model } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and CollectionService:HasTag(d, RangeCarriage.RIDER_TAG) then
			table.insert(out, d)
		end
	end
	return out
end

-- A rider's place on the carriage. The server stamps it the first time it sees the rider (still where it was built);
-- clients read the stamp.
function RangeCarriage.riderOffset(rider: Model, home: CFrame, stamp: boolean): CFrame?
	local v = rider:GetAttribute(RangeCarriage.OFFSET_ATTRIBUTE)
	if typeof(v) == "CFrame" then
		return v
	end
	if not stamp then
		return nil
	end
	local offset = home:ToObjectSpace(rider:GetPivot())
	rider:SetAttribute(RangeCarriage.OFFSET_ATTRIBUTE, offset)
	return offset
end

return RangeCarriage
