--!strict
-- The task Path panel (vault/01 Design/Tasks and Rewards.md): the showing part's tasks in the lobby's top-left
-- LobbyTasks panel (Studio-built; row template `Tasks.Row`, tools/studio/BuildTaskRow.luau). Read only: the server
-- owns the Path (LobbyServer Services/TaskService) and publishes it as the player's "Tasks" StringValue.
--   * Shows once the Path is open (Config/Tasks START_AFTER_MATCHES finished matches), in the lobby and the
--     Range, with no menu open; hidden when the Path is done. HIDE SIDE TASKS still hides the whole ScreenGui
--     (Shared/SettingsApply owns its Enabled).
--   * TaskEvent: a toast per finished task, then one for a finished part / set.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)
local Tasks = require(ReplicatedStorage.Shared.Config.Tasks)
local LobbyHudView = require(script.Parent.Parent.Util.LobbyHudView)
local Router = require(script.Parent.Parent.Util.Router)

local TaskPanel = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromHex("FFC83D")
local ALLY = Color3.fromHex("3FE0F2")
local TOAST_GAP = 1.6 -- s between toasts when several tasks finish at once

type View = {
	panel: Frame,
	setLabel: TextLabel,
	partLabel: TextLabel,
	template: Frame,
	bonus: TextLabel?,
	rows: { Frame },
}
local view: View? = nil

local function readState(): TaskPath.State
	local v = player:FindFirstChild(PlayerData.TASKS)
	if v and v:IsA("StringValue") and v.Value ~= "" then
		local ok, raw = pcall(HttpService.JSONDecode, HttpService, v.Value)
		if ok then
			return TaskPath.clean(raw)
		end
	end
	return TaskPath.new()
end

local function num(name: string, default: number): number
	local v = StateValues.get(player, name)
	return if typeof(v) == "number" then v else default
end

local function label(parent: Instance, name: string): TextLabel?
	local l = parent:FindFirstChild(name)
	return if l and l:IsA("TextLabel") then l else nil
end

local function rewardText(r: Tasks.SetReward): string
	local bits: { string } = {}
	if r.tickets and r.tickets > 0 then
		table.insert(bits, if r.tickets == 1 then "1 TICKET" else `{r.tickets} TICKETS`)
	end
	if r.coins and r.coins > 0 then
		table.insert(bits, `{r.coins} COINS`)
	end
	if r.title then
		table.insert(bits, `{string.upper(r.title)} TITLE`)
	end
	return table.concat(bits, " + ")
end

local function fillRow(row: Frame, task: Tasks.Task, have: number, coins: number)
	local done = have >= task.target
	local words = label(row, "Words")
	if words then
		words.Text = string.upper(TaskPath.text(task))
		words.TextTransparency = if done then 0.45 else 0
	end
	local count = label(row, "Count")
	if count then
		count.Text = if done then "DONE" else `{have} / {task.target}`
		count.TextColor3 = if done then GOLD else ALLY
	end
	local reward = label(row, "Reward")
	if reward then
		reward.Text = tostring(coins)
	end
	local bar = row:FindFirstChild("Bar")
	local fill = bar and bar:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.fromScale(math.clamp(have / task.target, 0, 1), 1)
		fill.BackgroundColor3 = if done then GOLD else ALLY
	end
end

local function render()
	local v = view
	if not v then
		return
	end
	local s = readState()
	local set, part = TaskPath.current(s)
	local show = StateValues.get(player, "DataReady") == true
		and TaskPath.open(num("Matches", 0))
		and set ~= nil
		and part ~= nil
		and PlayZone.get(player) ~= "Match"
		and Router.current() == nil
	v.panel.Visible = show
	if not show or not set or not part then
		return
	end
	local level = num("Level", 1)
	v.setLabel.Text = set.name
	v.partLabel.Text = `PART {s.part} / {#set.parts}`
	for i, task in part.tasks do
		local row = v.rows[i]
		if not row then
			row = v.template:Clone()
			row.Name = "Task" .. i
			row.LayoutOrder = 10 + i
			row.Parent = v.panel
			v.rows[i] = row
		end
		row.Visible = true
		fillRow(row, task, TaskPath.progress(s, task, level), set.coins)
	end
	for i = #part.tasks + 1, #v.rows do
		v.rows[i].Visible = false
	end
	local bonus = v.bonus
	if bonus then
		local text = `FINISH ALL {#part.tasks}  +{set.partBonus} COINS`
		if s.part == #set.parts then
			text ..= `  ·  SET: {rewardText(set.reward)}`
		end
		bonus.Text = text
		bonus.Visible = true
	end
end

local function toasts(p: LobbyNet.TaskEventPayload)
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
		local topLeft = gui and gui:FindFirstChild("TopLeft")
		local panel = topLeft and topLeft:FindFirstChild("Tasks")
		local head = panel and panel:FindFirstChild("Head")
		local block = head and head:FindFirstChild("Block")
		local template = panel and panel:FindFirstChild("Row")
		local setLabel = block and label(block, "Label")
		local partLabel = head and label(head, "Reset")
		if
			not panel
			or not panel:IsA("Frame")
			or not template
			or not template:IsA("Frame")
			or not setLabel
			or not partLabel
		then
			warn(
				"[TaskPanel] LobbyTasks panel or its Row template is missing (tools/studio/BuildTaskRow.luau)"
			)
			return
		end
		template.Visible = false
		view = {
			panel = panel,
			setLabel = setLabel,
			partLabel = partLabel,
			template = template,
			bonus = label(panel, "Bonus"),
			rows = {},
		}
		local function watchValue(v: Instance)
			if v.Name == PlayerData.TASKS and v:IsA("StringValue") then
				v.Changed:Connect(render)
				render()
			end
		end
		local existing = player:FindFirstChild(PlayerData.TASKS)
		if existing then
			watchValue(existing)
		end
		player.ChildAdded:Connect(watchValue)
		for _, name in { "Matches", "Level", "DataReady" } do
			StateValues.changed(player, name):Connect(render)
		end
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
