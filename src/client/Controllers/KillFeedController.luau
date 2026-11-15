--!strict
-- The kill feed (top right) and the kill pop (your kills, under the crosshair)
-- in the match UI style (vault/02 Art/UI Feed and Spectate.md). The layout is
-- built in Studio (StarterGui.KillFeed, row template
-- ReplicatedStorage.UiTemplates.KillFeed.Row, backup
-- tools/studio/BuildFeedScreens.luau); this fills and animates it from the
-- server's "Killed" event (victim, attacker, sourceId, headshot).
--
-- Util/KillFeed still plays the kill sounds (its kill-tone ladder); its old
-- code-built rows and pop are taken off screen here on desktop. Phones keep
-- the old ones until the mobile pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Device = require(script.Parent.Parent.Util.Device)

local KillFeedController = {}

local player = Players.LocalPlayer

local DESIGN = Vector2.new(1920, 1080)
local ROWS = 4
local ROW_LIFE = 5 -- seconds a row stays
local SLIDE = 60 -- design px a row slides in from
local NAME_MAX = 14 -- characters before a name is cut with "…"
local POP_HOLD = 1.6 -- seconds the kill pop stays
local SEGMENTS = 5
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local NAVY, NAVY_HI = Color3.fromHex("1C2740"), Color3.fromHex("2B3A5A")
local GOLD, WHITE = Color3.fromHex("FFC83D"), Color3.new(1, 1, 1)

type Pop = {
	holder: Frame,
	scale: UIScale,
	group: CanvasGroup,
	segs: { ImageLabel },
	emblem: ImageLabel,
}

local feed: Frame? = nil
local template: Frame? = nil
local pop: Pop? = nil
local rowCount = 0
local roundKills = 0
local popToken = 0

local function tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- The Player behind a fighter (a Player, or a player's character), if any.
local function playerOf(x: Instance?): Player?
	if not x then
		return nil
	end
	if x:IsA("Player") then
		return x
	end
	return if x:IsA("Model") then Players:GetPlayerFromCharacter(x) else nil
end

local function nameOf(x: Instance): string
	local p = playerOf(x)
	local name = if p == player then "YOU" elseif p then p.DisplayName else x.Name
	name = string.upper(name)
	if utf8.len(name) or 0 > NAME_MAX then
		local cut = utf8.offset(name, NAME_MAX)
		if cut then
			name = string.sub(name, 1, cut - 1) .. "…"
		end
	end
	return name
end

local function colorOf(x: Instance): Color3
	if playerOf(x) == player then
		return ALLY
	end
	return if Teams.isAlly(x, player) then ALLY else ENEMY
end

local function row(killer: Instance?, victim: Instance, sourceId: string, head: boolean)
	local list, base = feed, template
	if not (list and base) then
		return
	end
	local holder = base:Clone()
	rowCount += 1
	holder.LayoutOrder = -rowCount -- newest on top
	local strip = holder:WaitForChild("Strip") :: CanvasGroup
	local team = strip:WaitForChild("Team") :: Frame
	local cap = strip:WaitForChild("Cap") :: ImageLabel
	local weapon = strip:WaitForChild("Weapon") :: ImageLabel
	local headIcon = strip:WaitForChild("Head") :: ImageLabel
	local gap3 = strip:WaitForChild("Gap3") :: Frame
	local victimLabel = strip:WaitForChild("Victim") :: TextLabel
	if killer and killer ~= victim then
		local color = colorOf(killer)
		team.BackgroundColor3 = color
		cap.ImageColor3 = color
		local label = team:WaitForChild("Label") :: TextLabel
		label.Text = nameOf(killer)
	else
		-- The zone, a fall or your own Molly: no killer block.
		team.Visible = false
		cap.Visible = false
	end
	local def = Mods.def(sourceId)
	if def then
		weapon.Image = def.icon
		weapon.Size = UDim2.fromOffset(24, 24)
	else
		weapon.Image = Theme.GUN[sourceId] or ""
	end
	weapon.Visible = weapon.Image ~= ""
	headIcon.Visible = head
	gap3.Visible = head
	victimLabel.Text = nameOf(victim)
	victimLabel.TextColor3 = colorOf(victim)
	local mine = (killer ~= nil and playerOf(killer) == player) or playerOf(victim) == player
	strip.BackgroundColor3 = if mine then NAVY_HI else NAVY
	-- In: slides from the right and fades up.
	strip.Position = UDim2.new(1, SLIDE, 0.5, 0)
	strip.GroupTransparency = 1
	holder.Parent = list
	tween(strip, 0.32, { Position = UDim2.fromScale(1, 0.5), GroupTransparency = 0 })
	-- Oldest rows go first once the list is full.
	local rows: { Frame } = {}
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = ROWS + 1, #rows do
		rows[i]:Destroy()
	end
	task.delay(ROW_LIFE, function()
		if holder.Parent then
			tween(
				strip,
				0.25,
				{ Position = UDim2.new(1, SLIDE, 0.5, 0), GroupTransparency = 1 },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
			task.delay(0.26, function()
				holder:Destroy()
			end)
		end
	end)
end

-- Your kill: the disc pops from its centre, a little bigger each kill this
-- round, with one more ring segment lit (gold on a headshot).
local function showPop(head: boolean)
	local p = pop
	if not p then
		return
	end
	roundKills += 1
	local count = math.min(roundKills, SEGMENTS)
	popToken += 1
	local token = popToken
	local lit = if head then GOLD else ENEMY
	for i, seg in p.segs do
		local on = i <= count
		seg.ImageColor3 = if on then lit else WHITE
		seg.ImageTransparency = if on then 0 else 0.7
	end
	p.emblem.ImageColor3 = if head then GOLD else WHITE
	p.holder.Visible = true
	p.group.GroupTransparency = 0
	p.scale.Scale = 1.3 + 0.08 * (count - 1)
	tween(p.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(POP_HOLD, function()
		if token ~= popToken then
			return
		end
		tween(
			p.group,
			0.3,
			{ GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		tween(p.scale, 0.3, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.31, function()
			if token == popToken then
				p.holder.Visible = false
			end
		end)
	end)
end

local function onKilled(victim: unknown, attacker: unknown, sourceId: unknown, headshot: unknown)
	if typeof(victim) ~= "Instance" then
		return
	end
	local killer = if typeof(attacker) == "Instance" then attacker else nil
	local head = headshot == true
	row(killer, victim, if typeof(sourceId) == "string" then sourceId else "", head)
	if killer and playerOf(killer) == player and playerOf(victim) ~= player then
		showPop(head)
	end
end

-- The old code-built feed and pop (Util/KillFeed, in CombatHud) leave the
-- screen; Util/KillFeed keeps playing the kill sounds.
local function hideOld()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("CombatHud", 30)
	if not hud then
		return
	end
	for _, name in { "KillFeed", "KillBanner" } do
		local old = hud:WaitForChild(name, 10)
		if old then
			old.Parent = nil
		end
	end
end

local function bind(gui: ScreenGui)
	local canvas = gui:WaitForChild("Canvas") :: Frame
	local fit = canvas:WaitForChild("Fit") :: UIScale
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.5, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	feed = canvas:WaitForChild("Feed") :: Frame
	local holder = canvas:WaitForChild("KillPop") :: Frame
	local group = holder:WaitForChild("Group") :: CanvasGroup
	local disc = group:WaitForChild("Disc") :: Frame
	local segs: { ImageLabel } = {}
	for i = 1, SEGMENTS do
		segs[i] = group:WaitForChild("Seg" .. i) :: ImageLabel
	end
	pop = {
		holder = holder,
		scale = holder:WaitForChild("Pop") :: UIScale,
		group = group,
		segs = segs,
		emblem = disc:WaitForChild("Emblem") :: ImageLabel,
	}
	local folder = ReplicatedStorage:WaitForChild("UiTemplates"):WaitForChild("KillFeed")
	template = folder:WaitForChild("Row") :: Frame
end

function KillFeedController.start()
	if Device.compact() then
		return -- phones keep the old feed for now
	end
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("KillFeed", 30)
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		bind(gui)
		Net.event("Killed").OnClientEvent:Connect(onKilled)
		MatchState.changed("Round"):Connect(function()
			roundKills = 0
		end)
		hideOld()
	end)
end

return KillFeedController
