--!strict
-- The task Path panel in a match (owner 2026-11-26: "it will show up at the start of each round, and hide once
-- the play actually starts"; vault/01 Design/Tasks and Rewards.md). A copy of the lobby's Studio-built
-- LobbyTasks screen, named MatchTasks, drawn by Shared/TaskPanelView:
--   * shows in the round's "Draft" and "Countdown" phases, but not while the draft screen is open (it owns the
--     screen); hides when the round goes "Live" and stays hidden for the rest of the round;
--   * HIDE SIDE TASKS / HIDE HUD always hide it (Config/SettingsApply SIDE_TASK_GUIS lists "MatchTasks", and
--     Shared/SettingsApply owns its Enabled);
--   * only with the Path open and a part left (the lobby's own panel stays hidden while armed).
-- Progress from this match lands at the match end (ProgressionService), so mid-match it shows the Path as the
-- match started.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local TaskPanelView = require(ReplicatedStorage.Shared.TaskPanelView)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local DraftController = require(script.Parent.DraftController)

local MatchTasksController = {}

local player = Players.LocalPlayer
local GUI_NAME = "MatchTasks"
local SHOW_PHASES: { [string]: boolean } = { Draft = true, Countdown = true }
local CHECK_EVERY = 0.25 -- s: the draft screen opens and closes on its own, so the pre-round window is polled

local view: TaskPanelView.View? = nil

local function wanted(): boolean
	return PlayZone.get(player) == "Match"
		and SHOW_PHASES[MatchState.phase() or ""] == true
		and not DraftController.isOpen()
end

local function render()
	local v = view
	if v then
		TaskPanelView.render(v, player, wanted())
	end
end

function MatchTasksController.init() end

function MatchTasksController.start()
	task.spawn(function()
		local ok, source = pcall(UiRoot.source, "Lobby", "LobbyTasks")
		if not ok or not source then
			warn("[MatchTasks] the LobbyTasks template is missing")
			return
		end
		local playerGui = player:WaitForChild("PlayerGui")
		local old = playerGui:FindFirstChild(GUI_NAME)
		if old then
			old:Destroy()
		end
		local gui = source:Clone()
		gui.Name = GUI_NAME
		gui.ResetOnSpawn = false
		gui.Enabled = true -- the panel inside shows itself; SettingsApply turns the screen off for HIDE SIDE TASKS
		UiRoot.applyLayer(gui)
		local v = TaskPanelView.bind(gui)
		if not v then
			gui:Destroy()
			warn(
				"[MatchTasks] LobbyTasks panel or its Row template is missing (tools/studio/BuildTaskRow.luau)"
			)
			return
		end
		v.panel.Visible = false
		gui.Parent = playerGui
		UiLayout.watch(gui) -- the same per-device Fit scale as the lobby panel
		view = v
		TaskPanelView.watch(player, render)
		MatchState.changed("Phase"):Connect(render)
		StateValues.changed(player, "DraftLocked"):Connect(function()
			task.defer(render)
		end)
		PlayZone.onLocalChanged(function()
			render()
		end)
		render()
		local shown = false
		while gui.Parent do
			task.wait(CHECK_EVERY)
			local now = wanted()
			if now ~= shown then
				shown = now
				render()
			end
		end
	end)
end

return MatchTasksController
