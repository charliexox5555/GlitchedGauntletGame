--!strict
-- Shared status effects on the server (Config/StatusEffects, Mods/Status):
-- the only writer of the expiry attributes (HinderedUntil, ...) on
-- characters and dummies. Mods apply them through apply(); re-applying
-- refreshes the timer (no stacking).
--
-- For the movement simulation it publishes the combined movement multipliers
-- as player attributes (written here, outside the simulation, read inside it
-- like MoveMult): StatusMoveMult, StatusJumpMult, StatusGravityMult (nil = 1),
-- and StatusStunned (true while a stun like Frozen is on: no casts).
-- Weapon checks read Mods/Status directly (WeaponService uses lenient() with
-- the start times kept here, so a slowdown that just started doesn't reject
-- shots the client fired before it saw it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.StatusEffects)
local Status = require(Shared.Mods.Status)
local Health = require(Shared.Health)

local StatusService = {}

-- Server time each effect last started on a model (weak: models go away).
local started: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local applyListeners: { (model: Model, name: string) -> () } = {}

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
	for _, fn in applyListeners do
		task.spawn(fn, model, name)
	end
end

-- `fn(model, name)` after every apply (a start or a refresh): WeaponService
-- drops a reload when a stun (Frozen) lands.
function StatusService.onApply(fn: (model: Model, name: string) -> ())
	table.insert(applyListeners, fn)
end

-- When each effect started on `model` (for Status.lenient).
function StatusService.startedAt(model: Instance?): { [string]: number }?
	return if model then started[model] else nil
end

-- HEALING: every live heal source on a model (Mod id → when it runs until and
-- when it last refreshed). The attribute shows the latest end; the source
-- attribute names the newest refresh. Written only here.
type HealSource = { untilAt: number, at: number }
local healing: { [Model]: { [string]: HealSource } } = setmetatable({}, { __mode = "k" }) :: any

local function publishHealing(model: Model, now: number)
	local list = healing[model]
	local latest, source, newest = 0, nil :: string?, -1
	if list then
		for id, src in list do
			if src.untilAt <= now then
				list[id] = nil
			else
				latest = math.max(latest, src.untilAt)
				if src.at > newest then
					newest, source = src.at, id
				end
			end
		end
	end
	local untilAt = if source then latest else nil
	if model:GetAttribute(Config.healing.attribute) ~= untilAt then
		model:SetAttribute(Config.healing.attribute, untilAt)
	end
	if model:GetAttribute(Config.healing.sourceAttribute) ~= source then
		model:SetAttribute(Config.healing.sourceAttribute, source)
	end
end

-- `modId`'s heal is running on `model` for `duration` more seconds (a heal
-- over time: its whole length; a zone tick: the tick interval plus slack).
-- A refresh extends it and makes this source the newest.
function StatusService.healing(model: Model, modId: string, duration: number)
	if duration ~= duration or duration <= 0 or not Health.isAlive(model) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local list = healing[model]
	if not list then
		list = {}
		healing[model] = list
	end
	list[modId] = { untilAt = now + duration, at = now }
	publishHealing(model, now)
end

-- `modId`'s heal on `model` ended early (cancelled, replaced, target downed).
function StatusService.healingEnded(model: Model, modId: string)
	local list = healing[model]
	if list and list[modId] then
		list[modId] = nil
		publishHealing(model, workspace:GetServerTimeNow())
	end
end

-- Expiry and death: attributes clear when the last source runs out, and a
-- downed or removed model loses them at once.
local function stepHealing()
	local now = workspace:GetServerTimeNow()
	for model, list in healing do
		if model.Parent == nil or not Health.isAlive(model) then
			table.clear(list)
		end
		publishHealing(model, now)
		if next(list) == nil then
			healing[model] = nil
		end
	end
end

local function set(player: Player, name: string, value: number)
	local v = if math.abs(value - 1) < 1e-4 then nil else value
	if player:GetAttribute(name) ~= v then
		player:SetAttribute(name, v)
	end
end

local function step()
	stepHealing()
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local m = Status.mults(player.Character, now)
		set(player, "StatusMoveMult", m.move)
		set(player, "StatusJumpMult", m.jump)
		set(player, "StatusGravityMult", m.gravity)
		local stunned = Status.stunned(player.Character, now) or nil
		if player:GetAttribute("StatusStunned") ~= stunned then
			player:SetAttribute("StatusStunned", stunned)
		end
	end
end

function StatusService.start()
	RunService.Heartbeat:Connect(step)
end

return StatusService
