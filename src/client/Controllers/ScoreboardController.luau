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
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Device = require(script.Parent.Parent.Util.Device)
local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)

local ScoreboardController = {}

type Line = {
	id: string,
	name: string,
	userId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	mvp: boolean?,
	kit: { string }?,
}

local player = Players.LocalPlayer

local DESIGN = Vector2.new(1920, 1080)
local NAVY, NAVY_HI = Color3.fromHex("1C2740"), Color3.fromHex("2B3A5A")
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local ALLY_CELL, ENEMY_CELL = Color3.fromHex("0D5C7A"), Color3.fromHex("8A1C24")
local BOT_HEAD = "rbxassetid://119185654291939"
local ASK_EVERY = 1 -- seconds between refreshes while open
local KEYS = { [Enum.KeyCode.Tab] = true, [Enum.KeyCode.ButtonSelect] = true }

type State = {
	gui: ScreenGui,
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
local lines: { Line } = {}

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

-- Alive right now: a player's character, or a bot's body (by its BotId).
local function alive(line: Line): boolean
	if line.userId then
		local p = Players:GetPlayerByUserId(line.userId)
		return p ~= nil and Health.isAlive(p.Character)
	end
	for _, body in Fighters.bodies() do
		if "b" .. tostring(body:GetAttribute("BotId")) == line.id then
			return Health.isAlive(body)
		end
	end
	return false
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
	local up = alive(line)
	local body = child(holder, "Body") :: CanvasGroup
	body.BackgroundColor3 = if mine then NAVY_HI else NAVY
	body.GroupTransparency = if up then 0 else 0.45 -- the dead read dimmer
	local cell = child(body, "Cell") :: Frame
	cell.BackgroundColor3 = if ally then ALLY_CELL else ENEMY_CELL
	local headshot = child(cell, "Headshot") :: ImageLabel
	headshot.Image = if line.userId
		then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", line.userId)
		else BOT_HEAD
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
		local lv = PlayerTags.level(nameLine, who, 12, name.ZIndex)
		lv.LayoutOrder = 2
		local dev = PlayerTags.device(nameLine, who, 16, name.ZIndex)
		dev.LayoutOrder = 3
		dev.ImageColor3 = Color3.fromHex("A9A9B0")
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
end

local function setOpen(on: boolean)
	local s = state
	if not s or open == on then
		return
	end
	open = on
	s.gui.Enabled = on
	if on then
		render() -- the last lines at once, fresh ones a moment later
		s.pop.Scale = 0.96
		TweenService:Create(s.pop, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { Scale = 1 })
			:Play()
		task.spawn(function()
			while open do
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
	local s: State = {
		gui = gui,
		fit = child(canvas, "Fit"),
		panel = panel,
		pop = child(panel, "Pop"),
		round = child(top, "Round"),
		us = child(score, "Us"),
		them = child(score, "Them"),
		templates = ReplicatedStorage:WaitForChild("UiTemplates"):WaitForChild("Scoreboard") :: Folder,
	}
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			s.fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.5, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	gui.Enabled = false
	state = s
end

function ScoreboardController.start()
	if Device.compact() then
		return -- phones later
	end
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("Scoreboard", 30)
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
			if KEYS[input.KeyCode] and not UserInputService:GetFocusedTextBox() then
				local phase = MatchState.phase()
				if phase ~= "MatchEnd" and phase ~= "Waiting" and phase ~= "Vote" then
					setOpen(true)
				end
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if KEYS[input.KeyCode] then
				setOpen(false)
			end
		end)
	end)
end

return ScoreboardController
