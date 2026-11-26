--!strict
-- The task Path panel in the lobby (vault/01 Design/Tasks and Rewards.md): the showing part's tasks in the
-- top-left LobbyTasks panel, drawn by Shared/TaskPanelView. Read only: the server owns the Path (LobbyServer
-- Services/TaskService).
--   * Shows once the Path is open, in the lobby and the Range, with no menu open; hidden when the Path is done.
--     HIDE SIDE TASKS / HIDE HUD always hide it (Shared/SettingsApply owns the ScreenGui's Enabled). In a match
--     Controllers/MatchTasksController shows its own copy before each round.
--   * TaskEvent: a toast per finished task, then one for a finished set / Ticket / title.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local TaskPanelView = require(ReplicatedStorage.Shared.TaskPanelView)
local LobbyHudView = require(script.Parent.Parent.Util.LobbyHudView)
local Router = require(script.Parent.Parent.Util.Router)

local TaskPanel = {}

local player = Players.LocalPlayer
local TOAST_GAP = 1.6 -- s between toasts when several tasks finish at once

local view: TaskPanelView.View? = nil

local function render()
	local v = view
	if v then
		TaskPanelView.render(v, player, PlayZone.get(player) ~= "Match" and Router.current() == nil)
	end
end

local function toasts(p: LobbyNet.TaskEventPayload)
	if PlayZone.get(player) == "Match" then
		return -- the match HUD has the screen; the panel shows the new progress before the next round
	end
	local lines: { string } = {}
	for _, d in p.done do
		table.insert(lines, `TASK DONE: {d.text}  +{d.coins}`)
	end
	for _, id in p.sets do
		table.insert(lines, `{id} SET COMPLETE!`)
	end
	if p.tickets > 0 then
		table.insert(lines, if p.tickets == 1 then "+1 TICKET" else `+{p.tickets} TICKETS`)
	end
	if p.title then
		table.insert(lines, `TITLE UNLOCKED: {p.title}`)
	end
	task.spawn(function()
		for i, line in lines do
			if i > 1 then
				task.wait(TOAST_GAP)
			end
			LobbyHudView.toast(line, "info")
		end
	end)
end

function TaskPanel.init() end

function TaskPanel.start()
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("LobbyTasks", 30)
		view = gui and TaskPanelView.bind(gui)
		if not view then
			warn(
				"[TaskPanel] LobbyTasks panel or its Row template is missing (tools/studio/BuildTaskRow.luau)"
			)
			return
		end
		TaskPanelView.watch(player, render)
		PlayZone.onLocalChanged(function()
			render()
		end)
		Router.onChanged(function()
			render()
		end)
		render()
	end)
	LobbyNet.event("TaskEvent").OnClientEvent:Connect(toasts)
end

return TaskPanel
