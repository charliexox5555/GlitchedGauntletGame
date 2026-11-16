--!strict
-- Spawn hold, the look (vault/01 Design/Spawn Hold.md, 2026-11-16): through
-- the select and its 3-2-1 every other fighter (players and bots) shows as a
-- ghost on this client, then turns solid on GO. Standing still is the
-- movement simulation's job (MatchState.isSpawnHold), and no shots or Mods
-- is CombatLocked's; this only fades bodies.
--
-- Uses LocalTransparencyModifier, which the replay, spectate, death and
-- match-end scenes also write. None of them run during the hold, and on
-- release only parts still at the ghost value are reset, so their writes win.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local MatchState = require(ReplicatedStorage.Shared.MatchState)

local SpawnHoldController = {}

local HOLD = Config.SPAWN_HOLD
local player = Players.LocalPlayer

local faded: { [Instance]: boolean } = {}
local holding = false
local running = false

local function fadeable(d: Instance): boolean
	return d:IsA("BasePart") or d:IsA("Decal")
end

local function fadeBody(body: Model)
	for _, d in body:GetDescendants() do
		if fadeable(d) and not faded[d] then
			local current = (d :: any).LocalTransparencyModifier :: number
			if current < HOLD.ghost then
				(d :: any).LocalTransparencyModifier = HOLD.ghost
				faded[d] = true
			end
		end
	end
end

local function release()
	for d in faded do
		if
			d.Parent
			and math.abs(((d :: any).LocalTransparencyModifier :: number) - HOLD.ghost) < 1e-3
		then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(faded)
end

-- One pass over every other fighter; repeats while held so late spawns,
-- respawns and newly equipped guns fade too.
local function loop()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while holding do
			local own = player.Character
			for _, body in Fighters.bodies() do
				if body ~= own then
					fadeBody(body)
				end
			end
			task.wait(HOLD.refresh)
		end
		release() -- anything faded by a pass that was mid-way at GO
		running = false
	end)
end

local function onPhase()
	local now = MatchState.isSpawnHold()
	if now == holding then
		return
	end
	holding = now
	if holding then
		loop()
	else
		release()
	end
end

function SpawnHoldController.isHolding(): boolean
	return holding
end

function SpawnHoldController.start()
	MatchState.changed("Phase"):Connect(onPhase)
	onPhase()
end

return SpawnHoldController
