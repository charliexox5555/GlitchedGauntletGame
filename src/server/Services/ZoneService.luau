--!strict
-- Sudden death (vault/05 Production/Match Structure Revamp.md): when the round
-- clock runs out, MatchService starts a circle that closes on the map's
-- middle. This service owns it: it publishes the circle (shared/Zone) and,
-- on its own timer, takes health from every fighter outside it, straight off
-- their HP (the shield doesn't absorb it). Numbers: Config/Match SUDDEN_DEATH.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local nextId = 0
local running: Zone.State? = nil
local sinceTick = 0

local function spawnCentre(team: number): Vector3?
	local spawns = MapService.spawns(team)
	if #spawns == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, s in spawns do
		sum += s.Position
	end
	return sum / #spawns
end

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

-- Where the circle closes, and how big it starts.
local function shape(): (Vector3?, number)
	local part = centrePart()
	local one, two = spawnCentre(1), spawnCentre(2)
	local centre: Vector3? = if part
		then part.Position
		elseif one and two then (one + two) / 2
		else one or two
	if not centre then
		return nil, 0
	end
	local override = part and part:GetAttribute("ZoneRadius")
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

local function publish(state: Zone.State?)
	if state then
		ReplicatedStorage:SetAttribute(Zone.CENTRE, state.centre)
		ReplicatedStorage:SetAttribute(Zone.RADIUS, Vector2.new(state.fromRadius, state.toRadius))
		ReplicatedStorage:SetAttribute(Zone.START, state.startAt)
		ReplicatedStorage:SetAttribute(Zone.END, state.endAt)
		ReplicatedStorage:SetAttribute(Zone.ID, state.id) -- the commit, last
	else
		ReplicatedStorage:SetAttribute(Zone.ID, 0)
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
	publish(state)
	return true
end

function ZoneService.stop()
	running = nil
	publish(nil)
end

-- The circle now (bots read it to stay inside).
function ZoneService.current(): Zone.State?
	return running
end

function ZoneService.start()
	publish(nil)
	RunService.Heartbeat:Connect(step) -- lives as long as the server
end

return ZoneService
