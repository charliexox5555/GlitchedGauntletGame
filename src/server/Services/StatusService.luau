--!strict
-- Shared status effects on the server (Config/StatusEffects, Mods/Status):
-- the only writer of the expiry attributes (HinderedUntil, ...) on
-- characters and dummies. Mods apply them through apply(); re-applying
-- refreshes the timer (no stacking).
--
-- For the movement simulation it publishes the combined movement multipliers
-- as player attributes (written here, outside the simulation, read inside it
-- like MoveMult): StatusMoveMult, StatusJumpMult, StatusGravityMult (nil = 1).
-- Weapon checks read Mods/Status directly (WeaponService uses lenient() with
-- the start times kept here, so a slowdown that just started doesn't reject
-- shots the client fired before it saw it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.StatusEffects)
local Status = require(Shared.Mods.Status)

local StatusService = {}

-- Server time each effect last started on a model (weak: models go away).
local started: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

-- Puts `name` on `model` for `duration` seconds from now (a refresh, never
-- longer: a new hit restarts the timer).
function StatusService.apply(model: Model, name: string, duration: number)
	local effect = Config.effects[name]
	if not effect or duration ~= duration or duration <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	local list = started[model]
	if not list then
		list = {}
		started[model] = list
	end
	-- A refresh of a running effect keeps its start (it's already enforced).
	if not Status.active(model, name, now) then
		list[name] = now
	end
	model:SetAttribute(effect.attribute, now + duration)
end

-- When each effect started on `model` (for Status.lenient).
function StatusService.startedAt(model: Instance?): { [string]: number }?
	return if model then started[model] else nil
end

local function set(player: Player, name: string, value: number)
	local v = if math.abs(value - 1) < 1e-4 then nil else value
	if player:GetAttribute(name) ~= v then
		player:SetAttribute(name, v)
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local m = Status.mults(player.Character, now)
		set(player, "StatusMoveMult", m.move)
		set(player, "StatusJumpMult", m.jump)
		set(player, "StatusGravityMult", m.gravity)
	end
end

function StatusService.start()
	RunService.Heartbeat:Connect(step)
end

return StatusService
