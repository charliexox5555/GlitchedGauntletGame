--!strict
-- Beginner 2v2 red enemies (owner 2026-11-22; vault/05 Production/Handoff - Onboarding and Bots.md → phase 3;
-- RIVALS' Beginner queue draws enemies as solid red figures). In a Beginner match every enemy, player or bot,
-- shows as a solid red body on THIS screen until this player lands their first hit on that enemy; from then
-- on that enemy looks normal for the rest of the match, respawns included. Each player sees their own.
-- A hit is the server's HitConfirm naming the victim (guns, the knife and Mods alike).
-- The limbs live outside the character (Shared/MatchBody), so the body is held as one Instance while it is
-- red (Util/LimbHold) and one Highlight covers it all. Numbers: Config/Onboarding.RED_ENEMY.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local LimbHold = require(script.Parent.Parent.Util.LimbHold)

local BeginnerHighlightController = {}

local RED = OnbConfig.RED_ENEMY
local player = Players.LocalPlayer

local hit: { [string]: boolean } = {} -- enemies this player has hit this match
local lit: { [Model]: Highlight } = {}
local matchSeen: string? = nil

-- Who a body is, across respawns: a player's UserId, a bot's BotId.
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
	h.FillTransparency = RED.fillTransparency
	h.OutlineColor = RED.outline
	h.OutlineTransparency = RED.outlineTransparency
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = body
	lit[body] = h
end

local function active(): boolean
	return MatchState.get("Mode") == OnbConfig.BEGINNER_MODE
end

local function pass()
	local mine = Teams.of(player)
	local on = active() and mine ~= nil
	-- a new match (a rematch in this server) starts with a clean slate
	local round = MatchState.get("Round")
	local tag = tostring(MatchState.get("Mode"))
	if round == 1 and matchSeen ~= tag .. ":fresh" then
		matchSeen = tag .. ":fresh"
		table.clear(hit)
	elseif round ~= 1 and matchSeen == tag .. ":fresh" then
		matchSeen = tag
	end
	local want: { [Model]: boolean } = {}
	if on then
		for _, body in Fighters.bodies() do
			local key = keyOf(body)
			local team = Teams.of(body)
			if
				key
				and body ~= player.Character
				and team ~= nil
				and team ~= mine
				and not hit[key]
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

local function onHitConfirm(confirm: any)
	if typeof(confirm) ~= "table" or confirm.blocked == true then
		return
	end
	local victim = confirm.victim
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local key = keyOf(victim)
	if key and not hit[key] then
		hit[key] = true
		unlight(victim)
	end
end

function BeginnerHighlightController.start()
	if not ServerRole.isMatch() then
		return -- Beginner 2v2 is only ever a queued match
	end
	Net.event("HitConfirm").OnClientEvent:Connect(onHitConfirm)
	task.spawn(function()
		while true do
			pass()
			task.wait(RED.scan)
		end
	end)
end

return BeginnerHighlightController
