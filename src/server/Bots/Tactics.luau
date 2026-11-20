--!strict
-- Choose positions against a perceived threat. Navigation owns how to get there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Bots)
local Zone = require(ReplicatedStorage.Shared.Zone)

local Nav = require(script.Parent.Nav)
local Types = require(script.Parent.Types)

type Bot = Types.Bot

local Tactics = {}
local rng = Random.new()
local FLAT = Vector3.new(1, 0, 1)
local EYE = Vector3.yAxis * 3.5

function Tactics.assignOpening(bot: Bot, taken: { [number]: boolean })
	local roll = rng:NextNumber()
	local flankWeight = bot.profile.tactics.flankChance * 0.65
	bot.openingStyle = if roll < flankWeight
		then "Flanker"
		elseif roll < flankWeight + 0.32 then "Controller"
		else "Holder"
	local weights: { [number]: number } = {}
	local total = 0
	for lane = -1, 1 do
		if taken[lane] then
			continue
		end
		local flank = bot.openingStyle == "Flanker"
		local weight = if (lane == 0) == flank then 1 else 3.5
		if lane == bot.openingLane then
			weight *= Config.OPENING_REPEAT_WEIGHT
		end
		weights[lane] = weight
		total += weight
	end
	local pick = rng:NextNumber() * total
	for lane = -1, 1 do
		local weight = weights[lane]
		if weight then
			pick -= weight
			if pick <= 0 then
				bot.openingLane = lane
				taken[lane] = true
				break
			end
		end
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	bot.openingOffset = Vector3.new(math.cos(angle), 0, math.sin(angle))
		* rng:NextNumber(1, Config.OPENING_JITTER)
end

function Tactics.patrol(bot: Bot, opening: Vector3?, points: { Vector3 }, now: number): Vector3?
	local root = bot.root
	if not root then
		return nil
	end
	local pos = root.Position
	local previous = bot.roamGoal
	if previous then
		local failed = bot.nav.failedFor
		if failed and ((failed - previous) * FLAT).Magnitude < 3 then
			bot.roamBlocked[previous] = now + Config.ROAM_RETRY
		elseif not bot.roamBlocked[previous] and ((previous - pos) * FLAT).Magnitude > 6 then
			return previous
		end
	end
	for point, untilAt in bot.roamBlocked do
		if now >= untilAt then
			bot.roamBlocked[point] = nil
		end
	end
	-- Ground the round's chosen opening once and follow it until contact.
	if not bot.lastRoam and not previous then
		local side = bot.openingLane or 0
		local first = if #points >= 5
			then points[if side == 0 then 3 elseif side < 0 then 4 else 5]
			else opening
		if first then
			local point = first + bot.openingOffset
			if bot.openingStyle == "Holder" then
				point = point:Lerp(pos, 0.2)
			elseif bot.openingStyle == "Flanker" and opening then
				point = point:Lerp(opening, 0.12)
			end
			-- Controllers can take an elevated route if the map offers one nearby.
			local lift = if bot.openingStyle == "Controller"
				then Vector3.yAxis * 5
				else Vector3.zero
			local floor = Nav.ground(bot, point + lift, 21) or Nav.ground(bot, first)
			if floor and not bot.roamBlocked[floor] and ((floor - pos) * FLAT).Magnitude > 6 then
				return floor
			end
		end
	end
	local best: Vector3? = nil
	local bestScore = -math.huge
	local onward = if previous and bot.lastRoam
		then (previous - bot.lastRoam) * FLAT
		elseif opening then (opening - pos) * FLAT
		else Vector3.zero
	for _, point in points do
		local offset = (point - pos) * FLAT
		local distance = offset.Magnitude
		if distance < 8 or (previous and ((point - previous) * FLAT).Magnitude < 5) then
			continue
		end
		local floor = Nav.ground(bot, point)
		if floor and not bot.roamBlocked[floor] then
			local score = rng:NextNumber() - distance / 180
			if onward.Magnitude > 1 then
				score += 0.65 * onward.Unit:Dot(offset.Unit)
			end
			if bot.lastRoam and ((floor - bot.lastRoam) * FLAT).Magnitude < 8 then
				score -= 1
			end
			if score > bestScore then
				best, bestScore = floor, score
			end
		end
	end
	bot.lastRoam = previous or bot.lastRoam
	return best
end

function Tactics.needsZone(bot: Bot, zone: Zone.State): boolean
	local root = bot.root
	if not root then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local distance = ((root.Position - zone.centre) * FLAT).Magnitude
	local margin = math.min(Config.ZONE_MARGIN, zone.toRadius * 0.65)
	local lead = bot.profile.movement.zoneLead + math.min(distance / Config.ZONE_RUN_SPEED, 8)
	local safeRadius = Zone.radiusAt(zone, now + lead) - margin
	if bot.goal == "Rotate" then
		safeRadius *= 0.75
	end
	return distance > safeRadius
end

function Tactics.zoneGoal(bot: Bot, zone: Zone.State): Vector3
	local failed = bot.nav.failedFor
	local radius = Zone.radiusAt(zone, workspace:GetServerTimeNow())
	if not failed then
		local current = bot.nav.goal
		if
			bot.goal == "Rotate"
			and current
			and ((current - zone.centre) * FLAT).Magnitude < radius
		then
			return current
		end
		return zone.centre
	end
	local best, closest = zone.centre, math.huge
	local pos = if bot.root then bot.root.Position else zone.centre
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local point = zone.centre + dir * math.min(radius * 0.65, 10)
		if (failed - point).Magnitude < Config.REPATH_MOVE then
			continue
		end
		local floor = Nav.ground(bot, point)
		local distance = (point - pos).Magnitude
		if floor and distance < closest then
			best, closest = floor, distance
		end
	end
	return best
end

-- Small local search for standing cover with a compatible side to re-peek.
-- Use the last perceived position, even while the opponent is out of sight.
function Tactics.findCover(bot: Bot, threat: Vector3, allies: { Model }): (Vector3?, Vector3?)
	local root = bot.root
	if not root then
		return nil, nil
	end
	local pos = root.Position
	local offset = (pos - threat) * FLAT
	if offset.Magnitude < 0.1 then
		return nil, nil
	end
	local away = offset.Unit
	local side = Vector3.new(-away.Z, 0, away.X)
	if rng:NextNumber() < 0.5 then
		side = -side
	end
	local best: Vector3? = nil
	local peek: Vector3? = nil
	local bestScore = -math.huge
	for _, dir in { side, -side, away, (away + side).Unit, (away - side).Unit } do
		local floor = Nav.ground(bot, pos + dir * Config.COVER_RADIUS)
		if not floor or not Nav.zoneAllows(bot, floor, 0.6) then
			continue
		end
		local eye = floor + EYE
		if Nav.clearLine(bot, eye, threat) then
			continue
		end
		local occupied = false
		for _, ally in allies do
			local other = ally.PrimaryPart
			if other and (other.Position - floor).Magnitude < Config.TEAM_SPACING then
				occupied = true
				break
			end
		end
		if occupied then
			continue
		end
		for _, step in { -dir, side, -side } do
			local out = Nav.ground(bot, floor + step * 5)
			if
				out
				and Nav.zoneAllows(bot, out, 0.6)
				and Nav.clearLine(bot, eye, out + EYE)
				and Nav.clearLine(bot, out + EYE, threat)
			then
				local score = dir:Dot(away) + rng:NextNumber() * 0.5
				if score > bestScore then
					best, peek, bestScore = floor, out, score
				end
				break
			end
		end
	end
	return best, peek
end

return Tactics
