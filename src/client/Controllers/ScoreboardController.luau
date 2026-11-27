--!strict
-- The hold-Tab scoreboard (vault/02 Art/UI Match Extras.md): live
-- eliminations / deaths / assists / damage and every fighter's drafted build,
-- both teams, the round and the score. The layout is built in Studio
-- (StarterGui.Scoreboard, templates UiTemplates.Scoreboard, backup
-- tools/studio/BuildMatchExtras.luau). While it's open the client asks the
-- server for the lines once a second (the `Scoreboard` remote, rate-limited
-- there; StatsService answers this client only). Desktop only for now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)
local WaitGui = require(script.Parent.Parent.Util.WaitGui)

local ScoreboardController = {}

type Line = {
	id: string,
	name: string,
	userId: number?,
	botLevel: number?,
	portraitUserId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	mvp: boolean?,
	kit: { string }?,
}

local player = Players.LocalPlayer

local NAVY, NAVY_HI = Color3.fromHex("262629"), Color3.fromHex("39393C")
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local ALLY_CELL, ENEMY_CELL = Color3.fromHex("0D5C7A"), Color3.fromHex("8A1C24")
local BOT_HEAD = "rbxassetid://119185654291939"
local ASK_EVERY = 1 -- seconds between refreshes while open
-- Settings OPEN SCOREBOARD (default Tab / Select)
local function isKey(key: Enum.KeyCode): boolean
	return key.Value ~= 0 and SettingsApply.keyIs("kScoreboard", key)
end

type State = {
	gui: ScreenGui,
	canvas: Frame,
	fit: UIScale,
	panel: Frame,
	pop: UIScale,
	round: TextLabel,
	us: TextLabel,
	them: TextLabel,
	templates: Folder,
}

local state: State? = nil
local open = false
local openGen = 0 -- each open's ask loop ends when a newer open (or a close) starts
local lines: { Line } = {}

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

-- Alive right now: a player's character, or a bot's body (by its BotId).
local function alive(line: Line, bot: Model?): boolean
	if line.userId then
		local p = Players:GetPlayerByUserId(line.userId)
		return p ~= nil and Health.isAlive(p.Character)
	end
	return Health.isAlive(bot)
end

local function header(s: State, order: number, label: string, color: Color3)
	local h = (child(s.templates, "Header") :: Frame):Clone()
	h.LayoutOrder = order
	local team = child(h, "Team") :: Frame
	team.BackgroundColor3 = color
	local text = child(team, "Label") :: TextLabel
	text.Text = label
	local cap = child(h, "Cap") :: ImageLabel
	cap.ImageColor3 = color
	h.Parent = s.panel
end

local function row(s: State, order: number, line: Line, ally: boolean)
	local holder = (child(s.templates, "Row") :: Frame):Clone()
	holder.LayoutOrder = order
	local mine = line.id == "p" .. player.UserId
	local bot = if line.userId then nil else Fighters.botBody(line.id)
	local up = alive(line, bot)
	local body = child(holder, "Body") :: CanvasGroup
	body.BackgroundColor3 = if mine then NAVY_HI else NAVY
	body.GroupTransparency = if up then 0 else 0.45 -- the dead read dimmer
	local cell = child(body, "Cell") :: Frame
	cell.BackgroundColor3 = if ally then ALLY_CELL else ENEMY_CELL
	local headshot = child(cell, "Headshot") :: ImageLabel
	headshot.Image = PlayerTags.headshot(
		line.userId or line.portraitUserId or (bot and StateValues.get(bot, "PortraitUserId")),
		BOT_HEAD
	)
	local nameLine = child(body, "NameLine") :: Frame
	local name = child(nameLine, "PlayerName") :: TextLabel
	name.Text = string.upper(line.name)
	name.TextColor3 = if ally then ALLY else ENEMY
	local shard = child(nameLine, "Shard") :: ImageLabel
	shard.Visible = line.mvp == true
	local dead = child(nameLine, "Dead") :: ImageLabel
	dead.Visible = not up
	-- level and device after the name (vault/02 Art/UI Match Overhaul.md); a
	-- player who left gets neither
	local who = if line.userId then Players:GetPlayerByUserId(line.userId) else nil
	if who or not line.userId then
		name.LayoutOrder = 1
		local lv = PlayerTags.level(nameLine, who or bot, 12, name.ZIndex, line.botLevel)
		lv.LayoutOrder = 2
		local dev = PlayerTags.device(nameLine, who or bot, 16, name.ZIndex)
		dev.LayoutOrder = 3
		dev.ImageColor3 = Color3.fromHex("AAAAAD")
		shard.LayoutOrder = 4
		dead.LayoutOrder = 5
	end
	for i, v in { line.eliminations, line.deaths, line.assists, line.dealt } do
		local stat = body:FindFirstChild("Stat" .. i)
		if stat and stat:IsA("TextLabel") then
			stat.Text = tostring(math.floor(v + 0.5))
		end
	end
	local build = child(body, "Build") :: Frame
	local chipT = child(s.templates, "Chip") :: Frame
	for i, entry in line.kit or {} do
		local id, level = string.match(entry, "^(%w+):(%w+)$")
		local def = id and Mods.def(id)
		if def and level then
			local chip = chipT:Clone()
			chip.LayoutOrder = i
			chip.BackgroundColor3 = Theme.ROLE[def.role] or ALLY
			local icon = child(chip, "Icon") :: ImageLabel
			icon.Image = def.icon
			local lv = child(chip, "Level") :: TextLabel
			lv.Text = tostring(tonumber(string.sub(level, 2, 2)) or 1)
			chip.Parent = build
		end
	end
	holder.Parent = s.panel
end

local function panelTargetScale(s: State): number
	local fitScale = math.max(s.fit.Scale, 1e-3)
	local availW = s.canvas.AbsoluteSize.X / fitScale - 24
	local availH = s.canvas.AbsoluteSize.Y / fitScale - 24
	if availW <= 0 or availH <= 0 then
		return 1
	end
	local layout = s.panel:FindFirstChildOfClass("UIListLayout")
	local gap = if layout then layout.Padding.Offset else 4
	local baseW = math.max(s.panel.Size.X.Offset, 1040)
	local baseH, count = 0, 0
	for _, c in s.panel:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			baseH += c.Size.Y.Offset
			count += 1
		end
	end
	if count > 1 then
		baseH += gap * (count - 1)
	end
	return math.clamp(math.min(1, availW / baseW, availH / math.max(baseH, 1)), 0.5, 1)
end

local function render()
	local s = state
	if not s then
		return
	end
	for _, c in s.panel:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "Top" and c.Name ~= "TopGap" then
			c:Destroy()
		end
	end
	local mine = Teams.of(player) or 1
	local one, two = MatchState.get("Score1") or 0, MatchState.get("Score2") or 0
	s.us.Text = tostring(if mine == 1 then one else two)
	s.them.Text = tostring(if mine == 1 then two else one)
	local phaseName = MatchState.get("WeaponPhase")
	s.round.Text = string.format(
		"ROUND %d  ·  %s",
		MatchState.get("Round") or 0,
		string.upper(if typeof(phaseName) == "string" then phaseName else "")
	)
	local order = 1
	for t = 1, 2 do
		local ally = t == 1
		local team = if ally then mine else 3 - mine
		order += 1
		header(s, order, if ally then "YOUR TEAM" else "ENEMY", if ally then ALLY else ENEMY)
		for _, line in lines do
			if line.team == team then
				order += 1
				row(s, order, line, ally)
			end
		end
		if ally then
			order += 1
			local spacer = Instance.new("Frame")
			spacer.Name = "Spacer"
			spacer.LayoutOrder = order
			spacer.Size = UDim2.fromOffset(10, 12)
			spacer.BackgroundTransparency = 1
			spacer.Parent = s.panel
		end
	end
	s.pop.Scale = panelTargetScale(s)
end

local function setOpen(on: boolean)
	local s = state
	if not s or open == on then
		return
	end
	open = on
	openGen += 1
	s.gui.Enabled = on
	if on then
		render() -- the last lines at once, fresh ones a moment later
		local target = panelTargetScale(s)
		s.pop.Scale = target * 0.96
		TweenService:Create(s.pop, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { Scale = target })
			:Play()
		local gen = openGen
		task.spawn(function()
			-- a quick close and reopen used to leave the old loop running beside the new one
			while open and openGen == gen do
				Net.event("Scoreboard"):FireServer()
				task.wait(ASK_EVERY)
			end
		end)
	end
end

local function bind(gui: ScreenGui)
	local canvas = child(gui, "Canvas") :: Frame
	local panel = child(canvas, "Panel") :: Frame
	local top = child(panel, "Top") :: Frame
	local score = child(top, "Score") :: Frame
	-- Always render above the Touch controls ScreenGui (DisplayOrder 15) on phones.
	if gui.DisplayOrder < 22 then
		gui.DisplayOrder = 22
	end
	local s: State = {
		gui = gui,
		canvas = canvas,
		fit = child(canvas, "Fit"),
		panel = panel,
		pop = child(panel, "Pop"),
		round = child(top, "Round"),
		us = child(score, "Us"),
		them = child(score, "Them"),
		templates = UiRoot.templates():WaitForChild("Scoreboard") :: Folder,
	}
	-- A fit canvas: Shared/UiLayout sizes it per device.
	gui.Enabled = false
	state = s
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if open and state then
			state.pop.Scale = panelTargetScale(state)
		end
	end)
end

function ScoreboardController.start()
	task.spawn(function()
		local gui = WaitGui("Scoreboard")
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		bind(gui)
		Net.event("Scoreboard").OnClientEvent:Connect(function(data: unknown)
			if typeof(data) == "table" then
				lines = data :: any
				if open then
					render()
				end
			end
		end)
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if isKey(input.KeyCode) and not UserInputService:GetFocusedTextBox() then
				local phase = MatchState.phase()
				if phase ~= "MatchEnd" and phase ~= "Waiting" and phase ~= "Vote" then
					setOpen(true)
				end
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if isKey(input.KeyCode) then
				setOpen(false)
			end
		end)
	end)
end

-- Touch: the touch screen's scoreboard button, held like Tab.
function ScoreboardController.setHeld(on: boolean)
	if on then
		local phase = MatchState.phase()
		if phase ~= "MatchEnd" and phase ~= "Waiting" and phase ~= "Vote" then
			setOpen(true)
		end
	else
		setOpen(false)
	end
end

return ScoreboardController
