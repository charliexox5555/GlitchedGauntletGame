--!strict
-- Draws the task Path panel (vault/01 Design/Tasks and Rewards.md) into a copy of the Studio-built
-- `LobbyTasks.TopLeft.Tasks` frame (row template `Row`, part line `Bonus`; tools/studio/BuildTaskRow.luau).
-- Client only, read only: the Path is the player's "Tasks" StringValue (Shared/PlayerData). Used by the lobby
-- (LobbyClient Controllers/TaskPanel) and the match (Controllers/MatchTasksController).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)
local Tasks = require(ReplicatedStorage.Shared.Config.Tasks)

local TaskPanelView = {}

local GOLD = Color3.fromHex("FFC83D")
local ALLY = Color3.fromHex("3FE0F2")

export type View = {
	panel: Frame,
	setLabel: TextLabel,
	partLabel: TextLabel,
	template: Frame,
	bonus: TextLabel?,
	rows: { Frame },
}

local function label(parent: Instance, name: string): TextLabel?
	local l = parent:FindFirstChild(name)
	return if l and l:IsA("TextLabel") then l else nil
end

-- The panel inside a LobbyTasks ScreenGui copy, or nil when its pieces are missing.
function TaskPanelView.bind(gui: Instance): View?
	local topLeft = gui:FindFirstChild("TopLeft")
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
		return nil
	end
	template.Visible = false
	return {
		panel = panel,
		setLabel = setLabel,
		partLabel = partLabel,
		template = template,
		bonus = label(panel, "Bonus"),
		rows = {},
	}
end

-- The player's Path as published (a fresh one until the save loads).
function TaskPanelView.state(player: Player): TaskPath.State
	local v = player:FindFirstChild(PlayerData.TASKS)
	if v and v:IsA("StringValue") and v.Value ~= "" then
		local ok, raw = pcall(HttpService.JSONDecode, HttpService, v.Value)
		if ok then
			return TaskPath.clean(raw)
		end
	end
	return TaskPath.new()
end

local function num(player: Player, name: string, default: number): number
	local v = StateValues.get(player, name)
	return if typeof(v) == "number" then v else default
end

-- Is there a part to show? (the save loaded, the Path open, not done)
function TaskPanelView.hasPart(player: Player): boolean
	if
		StateValues.get(player, "DataReady") ~= true or not TaskPath.open(num(player, "Matches", 0))
	then
		return false
	end
	local _, part = TaskPath.current(TaskPanelView.state(player))
	return part ~= nil
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

-- Fills the panel and shows it when `show` and there is a part to show. Returns whether it is shown.
function TaskPanelView.render(v: View, player: Player, show: boolean): boolean
	local s = TaskPanelView.state(player)
	local set, part = TaskPath.current(s)
	local visible = show and TaskPanelView.hasPart(player) and set ~= nil and part ~= nil
	v.panel.Visible = visible
	if not visible or not set or not part then
		return false
	end
	local level = num(player, "Level", 1)
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
	return true
end

-- Calls `fn` whenever the Path, matches played, level or the save's readiness change. Returns the connections.
function TaskPanelView.watch(player: Player, fn: () -> ()): { RBXScriptConnection }
	local conns: { RBXScriptConnection } = {}
	local function watchValue(v: Instance)
		if v.Name == PlayerData.TASKS and v:IsA("StringValue") then
			table.insert(conns, v.Changed:Connect(fn))
			fn()
		end
	end
	local existing = player:FindFirstChild(PlayerData.TASKS)
	if existing then
		watchValue(existing)
	end
	table.insert(conns, player.ChildAdded:Connect(watchValue))
	for _, name in { "Matches", "Level", "DataReady" } do
		table.insert(conns, StateValues.changed(player, name):Connect(fn))
	end
	return conns
end

return TaskPanelView
