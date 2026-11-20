--!strict
-- Sudden death (vault/05 Production/Match Structure Revamp.md): when the round
-- clock runs out, MatchService starts a circle that closes on the map's
-- middle. This service owns it: it publishes the circle (shared/Zone) and,
-- on its own timer, takes health from every fighter outside it, straight off
-- their HP (the shield doesn't absorb it). Numbers: Config/Match SUDDEN_DEATH.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Health = require(ReplicatedStorage.Shared.Health)
local Zone = require(ReplicatedStorage.Shared.Zone)

local BotService = require(script.Parent.BotService)
local HealthService = require(script.Parent.HealthService)
local MapService = require(script.Parent.MapService)

local ZoneService = {}

local SD = Config.SUDDEN_DEATH
local CENTRE_TAG = "ZoneCentre"
local FOOTPRINT_HEIGHT = 5
local SEARCH_RINGS = 8
local SEARCH_DIRECTIONS = 8

local nextId = 0
local running: Zone.State? = nil
local sinceTick = 0

-- The map's `ZoneCentre` part (a tagged BasePart inside the active map), if any.
local function centrePart(): BasePart?
	local map = MapService.map()
	if not map then
		return nil
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag(CENTRE_TAG) then
			return d
		end
	end
	return nil
end

-- Check the end circle, including room for a standing fighter and floor
-- near its edges. Only the active map's colliders affect the design check.
local function playableCentre(map: Model, preferred: Vector3): Vector3?
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { map }
	rays.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { map }
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	local radius = SD.endRadius
	local up = Vector3.yAxis
	local footprint = Vector3.new(radius * 2, FOOTPRINT_HEIGHT, radius * 2)
	local function floorAt(point: Vector3): RaycastResult?
		return workspace:Raycast(point + up * 2.5, -up * 10, rays)
	end
	local function fits(point: Vector3): Vector3?
		local hit = floorAt(point)
		if not hit or hit.Normal.Y < 0.75 then
			return nil
		end
		local floor = hit.Position
		local volume = CFrame.new(floor + up * (FOOTPRINT_HEIGHT / 2 + 0.3))
		if #workspace:GetPartBoundsInBox(volume, footprint, overlap) > 0 then
			return nil
		end
		for _, axis in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			local edge = floorAt(floor + axis * radius)
			if not edge or math.abs(edge.Position.Y - floor.Y) > 1.5 then
				return nil
			end
		end
		return floor
	end
	local exact = fits(preferred)
	if exact then
		return exact
	end
	for ring = 1, SEARCH_RINGS do
		for i = 0, SEARCH_DIRECTIONS - 1 do
			local angle = i * math.pi * 2 / SEARCH_DIRECTIONS
			local point = preferred
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * (ring * radius)
			local floor = fits(point)
			if floor then
				return floor
			end
		end
	end
	local closest: Vector3? = nil
	local distance = math.huge
	for team = 1, 2 do
		for _, spawn in MapService.spawns(team) do
			local floor = fits(spawn.Position)
			if floor and (floor - preferred).Magnitude < distance then
				closest, distance = floor, (floor - preferred).Magnitude
			end
		end
	end
	return closest
end

-- Where the circle closes, and how big it starts.
local function shape(): (Vector3?, number)
	local part = centrePart()
	local one, two = MapService.spawnCentre(1), MapService.spawnCentre(2)
	local centre: Vector3? = if part
		then part.Position
		elseif one and two then (one + two) / 2
		else one or two
	if not centre then
		return nil, 0
	end
	local map = MapService.map()
	if map then
		local playable = playableCentre(map, centre)
		if playable then
			centre = playable
		elseif RunService:IsStudio() then
			warn(`[ZoneService] no clear end circle near {centre}; check the ZoneCentre marker`)
		end
	end
	local override = part and StateValues.get(part, "ZoneRadius")
	if typeof(override) == "number" and override > SD.endRadius then
		return centre, override
	end
	-- Past the furthest spawn, so nobody starts the shrink outside it.
	local furthest = 0
	for team = 1, 2 do
		for _, s in MapService.spawns(team) do
			local flat = Vector3.new(s.Position.X - centre.X, 0, s.Position.Z - centre.Z)
			furthest = math.max(furthest, flat.Magnitude)
		end
	end
	return centre, math.max(furthest * SD.startScale, SD.endRadius + 20)
end

-- Takes `amount` from a fighter's body standing outside the circle.
local function hurt(body: Model?, state: Zone.State, now: number, amount: number)
	if not body then
		return
	end
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	local root = body:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or not Health.isAlive(humanoid) then
		return
	end
	if Zone.outside(state, root.Position, now) > 0 then
		HealthService.damage(humanoid, amount)
	end
end

local function step(dt: number)
	local state = running
	if not state then
		return
	end
	sinceTick += dt
	if sinceTick < SD.tick then
		return
	end
	local span = sinceTick
	sinceTick = 0
	local now = workspace:GetServerTimeNow()
	local elapsed = math.max(now - state.startAt, 0)
	local perSecond = SD.damage + SD.damageStep * math.floor(elapsed / SD.stepEvery)
	local amount = perSecond * span
	for _, player in Players:GetPlayers() do
		hurt(player.Character, state, now, amount)
	end
	for _, key in BotService.keys() do
		hurt(BotService.modelOf(key), state, now, amount)
	end
end

-- Starts closing the circle now. Returns false when the map gives no centre.
function ZoneService.begin(): boolean
	local centre, fromRadius = shape()
	if not centre then
		warn("[ZoneService] no spawns or ZoneCentre: no sudden-death zone")
		return false
	end
	nextId += 1
	local now = workspace:GetServerTimeNow()
	local state: Zone.State = {
		id = nextId,
		centre = centre,
		fromRadius = fromRadius,
		toRadius = SD.endRadius,
		startAt = now,
		endAt = now + SD.shrinkTime,
	}
	running = state
	sinceTick = 0
	Zone.publish(state)
	return true
end

function ZoneService.stop()
	running = nil
	Zone.publish(nil)
end

-- The circle now (bots read it to stay inside).
function ZoneService.current(): Zone.State?
	return running
end

function ZoneService.start()
	Zone.publish(nil)
	RunService.Heartbeat:Connect(step) -- lives as long as the server
end

return ZoneService
