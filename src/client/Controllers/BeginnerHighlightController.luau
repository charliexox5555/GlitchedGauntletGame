--!strict
-- Beginner 2v2 red enemies (owner 2026-11-22/23; vault/05 Production/Handoff - Onboarding and Bots.md → phase
-- 3; RIVALS' Beginner queue draws enemies as solid red figures). In a Beginner match every enemy, player or
-- bot, glows neon red and pulses, seen through walls, until the fighter whose view this is lands a first hit
-- on that enemy; from then on that enemy looks normal for the rest of the match, respawns included.
-- Whose view: your own, or, while you spectate a teammate (player or bot), theirs: the server publishes who
-- each fighter has hit as "RedHits" on the Player or the bot's seat (MatchService). Your own hits also clear
-- at once from your HitConfirm, without waiting for that.
-- The limbs live outside the character (Shared/MatchBody), so the body is held as one Instance while it is
-- red (Util/LimbHold) and one Highlight covers it all. Numbers: Config/Onboarding.RED_ENEMY.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local LimbHold = require(script.Parent.Parent.Util.LimbHold)
local Watched = require(script.Parent.Parent.Util.Watched)

local BeginnerHighlightController = {}

local RED = OnbConfig.RED_ENEMY
local player = Players.LocalPlayer

local ownHits: { [string]: boolean } = {} -- this player's hits, straight from HitConfirm
local lit: { [Model]: Highlight } = {}
local matchSeen: string? = nil

-- Who a body is, across respawns: a player's UserId, a bot's BotId (same keys as MatchService).
local function keyOf(body: Model): string?
	local owner = Players:GetPlayerFromCharacter(body)
	if owner then
		return "p" .. owner.UserId
	end
	local botId = StateValues.get(body, "BotId")
	if botId ~= nil then
		return "b" .. tostring(botId)
	end
	return nil
end

-- The server's list of who `holder` has hit (a Player, or a bot's seat).
local function published(holder: Instance?): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local raw = if holder then StateValues.get(holder, "RedHits") else nil
	if typeof(raw) == "string" then
		for _, k in string.split(raw, ",") do
			if k ~= "" then
				set[k] = true
			end
		end
	end
	return set
end

-- A bot's seat from its body (its RedHits live there).
local function seatOf(body: Model): Instance?
	local botId = StateValues.get(body, "BotId")
	if botId == nil then
		return nil
	end
	for _, seat in MatchState.botSeats() do
		if StateValues.get(seat, "BotId") == botId then
			return seat
		end
	end
	return nil
end

-- Whose eyes: (team, hits) of the spectated teammate, else this player.
local function viewer(): (number?, { [string]: boolean })
	local mine = Teams.of(player)
	local holder, body = Watched.get()
	if holder and body and holder ~= player and Teams.of(body) == mine then
		local who = if holder:IsA("Player") then holder else seatOf(body)
		return mine, published(who)
	end
	local hits = published(player)
	for k in ownHits do
		hits[k] = true
	end
	return mine, hits
end

local function unlight(body: Model)
	local h = lit[body]
	if not h then
		return
	end
	lit[body] = nil
	h:Destroy()
	if body.Parent then
		LimbHold.release(body)
	end
end

local function light(body: Model)
	if lit[body] then
		return
	end
	LimbHold.take(body)
	local h = Instance.new("Highlight")
	h.Name = "BeginnerRed"
	h.Adornee = body
	h.FillColor = RED.fill
	h.FillTransparency = RED.fillLow
	h.OutlineColor = RED.outline
	h.OutlineTransparency = RED.outlineTransparency
	h.DepthMode = if RED.throughWalls
		then Enum.HighlightDepthMode.AlwaysOnTop
		else Enum.HighlightDepthMode.Occluded
	h.Parent = body
	lit[body] = h
end

local function pass()
	local on = MatchState.get("Mode") == OnbConfig.BEGINNER_MODE
	-- a new match (a rematch in this server) starts clean
	local round = MatchState.get("Round")
	if round == 1 and matchSeen ~= "fresh" then
		matchSeen = "fresh"
		table.clear(ownHits)
	elseif round ~= 1 and matchSeen == "fresh" then
		matchSeen = "on"
	end
	local want: { [Model]: boolean } = {}
	local team, hits = viewer()
	if on and team ~= nil then
		for _, body in Fighters.bodies() do
			local key = keyOf(body)
			local theirs = Teams.of(body)
			if
				key
				and theirs ~= nil
				and theirs ~= team
				and not hits[key]
				and Health.isAlive(body)
			then
				want[body] = true
			end
		end
	end
	for body in lit do
		if not want[body] or not body.Parent then
			unlight(body)
		end
	end
	for body in want do
		light(body)
	end
end

-- The neon pulse: every lit body breathes together.
local function pulse()
	if next(lit) == nil then
		return
	end
	local k = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 / RED.pulseTime)
	local t = RED.fillLow + (RED.fillHigh - RED.fillLow) * k
	for _, h in lit do
		h.FillTransparency = t
	end
end

local function onHitConfirm(confirm: any)
	if typeof(confirm) ~= "table" or confirm.blocked == true then
		return
	end
	local victim = confirm.victim
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local key = keyOf(victim)
	if key and not ownHits[key] then
		ownHits[key] = true
		pass()
	end
end

function BeginnerHighlightController.start()
	if not ServerRole.isMatch() then
		return -- Beginner 2v2 is only ever a queued match
	end
	Net.event("HitConfirm").OnClientEvent:Connect(onHitConfirm)
	RunService.RenderStepped:Connect(pulse)
	task.spawn(function()
		while true do
			pass()
			task.wait(RED.scan)
		end
	end)
end

return BeginnerHighlightController
