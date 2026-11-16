--!strict
-- The predicted Mods (Dash, Updraft) with Server Authority OFF (shared/
-- Authority; server half: Services/ModSim). Each client simulates its own
-- character there, so what Simulation/Abilities writes on it stays on this
-- client. Two jobs:
--
--   Report our own: a dash, a launch, a Crash Down dive and the landing each
--   go to the server once, on the ModSim remote (slot, kind, data). The
--   server pays the cast from its own charge count and does its part (the
--   Ghost dodge window, the slam's damage); `data` only shapes what other
--   players see.
--
--   Mirror the others': the server relays a report to every other client
--   (ModSimFx) with times as seconds from now. We write the same attributes
--   the simulation would have written onto that player's character, locally
--   and in our own clock, so everything that already reads them (WindFx,
--   UpgradeFx/Dash, DashGhost, DashDecoy, UpgradeFx/Updraft, spectating)
--   works unchanged. A local write on someone else's character goes nowhere.
--
-- With Server Authority on, the server simulates and replicates all of this
-- itself and this controller does nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Authority = require(Shared.Authority)
local Config = require(Shared.Config.Mods)
local Net = require(Shared.Net)

local ModSimController = {}

local player = Players.LocalPlayer

-- A re-simulated start a few ms off isn't a new cast (as UpgradeFx/Dash).
local NEW_CAST = 0.05

local function number(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

-- The slot `id` is in (nil: not slotted).
local function slotOf(id: string): number?
	for slot = 1, Config.SLOTS do
		if player:GetAttribute("Mod" .. slot .. "Id") == id then
			return slot
		end
	end
	return nil
end

-- Our own character ------------------------------------------------------------

local watched: Model? = nil
local lastDash = 0
local lastUpdraft = 0
local lastSlamAt = 0
local flying = false -- an Updraft we reported is still in the air
local diving = false -- ... and its dive was reported

local function send(id: string, kind: string, data: { [string]: any }?)
	local slot = slotOf(id)
	if slot then
		Net.event("ModSim"):FireServer(slot, kind, data)
	end
end

local function stepOwn()
	local character = player.Character
	if not character then
		watched = nil
		return
	end
	if character ~= watched then
		-- A new life: what it already carries is old, not news.
		watched = character
		lastDash = number(character, "DashStart")
		lastUpdraft = number(character, "UpdraftAt")
		lastSlamAt = number(character, "UpdraftSlamAt")
		flying = false
		diving = false
		return
	end

	local dash = number(character, "DashStart")
	if dash > lastDash + NEW_CAST then
		lastDash = dash
		local velocity = character:GetAttribute("DashVelocity")
		local run = character:GetAttribute("DashDecoyRun")
		send("Dash", "Cast", {
			dur = number(character, "DashUntil") - dash,
			vel = if typeof(velocity) == "Vector3" then velocity else nil,
			run = if typeof(run) == "Vector3" then run else nil,
		})
	elseif dash < lastDash then
		lastDash = dash
	end

	local updraft = number(character, "UpdraftAt")
	if updraft > lastUpdraft + NEW_CAST then
		lastUpdraft = updraft
		lastSlamAt = number(character, "UpdraftSlamAt")
		flying = true
		diving = false
		send("Updraft", "Cast", nil)
	elseif updraft < lastUpdraft then
		lastUpdraft = updraft
	end

	if not flying then
		return
	end
	-- The dive: seen as it runs, or (a short one between two frames) by the
	-- landing it left.
	local slamAt = number(character, "UpdraftSlamAt")
	local landedSlam = slamAt > lastSlamAt
	lastSlamAt = slamAt
	if not diving and (character:GetAttribute("UpdraftSlam") == "Down" or landedSlam) then
		diving = true
		send("Updraft", "Slam", nil)
	end
	if character:GetAttribute("Updrafting") ~= true then
		flying = false
		diving = false
		send("Updraft", "Land", nil)
	end
end

-- Everyone else's ---------------------------------------------------------------

local function vector(v: unknown): Vector3?
	return if typeof(v) == "Vector3" then v else nil
end

-- A window `seconds` from now as a time() (0 = none).
local function untilT(now: number, seconds: number): number
	return if seconds > 0 then now + seconds else 0
end

local function mirrorDash(character: Model, data: { [string]: unknown }, now: number)
	local duration = if typeof(data.dur) == "number" then data.dur else 0
	local windows = vector(data.windows)
	local any = windows ~= nil and (windows.X > 0 or windows.Y > 0 or windows.Z > 0)
	-- The upgrade levels' attributes go first: clients key on DashStart.
	character:SetAttribute(
		"DashWindows",
		if windows and any
			then Vector3.new(untilT(now, windows.X), untilT(now, windows.Y), untilT(now, windows.Z))
			else nil
	)
	character:SetAttribute("DashDecoy", if typeof(data.decoy) == "CFrame" then data.decoy else nil)
	character:SetAttribute("DashDecoyRun", vector(data.run))
	character:SetAttribute("DashTune", vector(data.tune))
	character:SetAttribute("DashVelocity", vector(data.vel))
	character:SetAttribute("DashUntil", now + duration)
	character:SetAttribute("Dashing", true)
	character:SetAttribute("DashStart", now)
	task.delay(duration, function()
		-- Unless a newer dash took over.
		if character:GetAttribute("DashStart") == now then
			character:SetAttribute("Dashing", nil)
		end
	end)
end

local function mirrorUpdraft(
	character: Model,
	kind: string,
	data: { [string]: unknown },
	now: number
)
	if kind == "Cast" then
		character:SetAttribute("UpdraftSlam", nil)
		character:SetAttribute("UpdraftLaunch", vector(data.launch))
		character:SetAttribute("Updrafting", true)
		character:SetAttribute("UpdraftAt", now)
		-- A landing that never reaches us (a dropped report) can't leave the
		-- flight, or its dive, on this character for good.
		task.delay(Config.SIM_REPORT.flightLife + 1, function()
			if character:GetAttribute("UpdraftAt") == now then
				character:SetAttribute("UpdraftSlam", nil)
				character:SetAttribute("Updrafting", nil)
			end
		end)
	elseif kind == "Slam" then
		character:SetAttribute("UpdraftSlamStart", now)
		character:SetAttribute("UpdraftSlam", "Down")
	elseif kind == "Land" then
		-- The impact itself is the server's UpdraftSlam ModFx (UpgradeFx/Updraft).
		character:SetAttribute("UpdraftSlam", nil)
		character:SetAttribute("Updrafting", nil)
	end
end

local function onMirror(owner: unknown, id: unknown, kind: unknown, data: unknown)
	if
		typeof(owner) ~= "Instance"
		or not owner:IsA("Player")
		or owner == player
		or typeof(kind) ~= "string"
		or typeof(data) ~= "table"
	then
		return
	end
	local character = owner.Character
	if not character then
		return
	end
	local now = time()
	if id == "Dash" then
		if kind == "Cast" then
			mirrorDash(character, data :: any, now)
		end
	elseif id == "Updraft" then
		mirrorUpdraft(character, kind, data :: any, now)
	end
end

function ModSimController.start()
	if Authority.server() then
		return
	end
	Net.event("ModSimFx").OnClientEvent:Connect(onMirror)
	RunService.Heartbeat:Connect(stepOwn)
end

return ModSimController
