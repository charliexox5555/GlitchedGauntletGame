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
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local TweenService = game:GetService("TweenService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local KillFeed = require(script.Parent.Parent.Util.KillFeed)
local Ui = require(script.Parent.Parent.Util.Ui)
local WaitGui = require(script.Parent.Parent.Util.WaitGui)
local Watched = require(script.Parent.Parent.Util.Watched)

local KillFeedController = {}

local player = Players.LocalPlayer

local ROWS = 4
local ROW_LIFE = 5 -- seconds a row stays
local SLIDE = 60 -- design px a row slides in from
local NAME_MAX = 14 -- characters before a name is cut with "…"
local POP_HOLD = 1.6 -- seconds the kill pop stays
local SEGMENTS = 5
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local NAVY, NAVY_HI = Color3.fromHex("262629"), Color3.fromHex("39393C")
local GOLD, WHITE = Color3.fromHex("FFC83D"), Color3.new(1, 1, 1)

type Pop = {
	holder: Frame,
	scale: UIScale,
	group: CanvasGroup,
	segs: { ImageLabel },
	emblem: ImageLabel,
	splits: { ImageLabel }, -- cyan (left) and pink (right) copies of the emblem
	flash: Frame,
	wave: ImageLabel,
}

-- The kill pop's beats (seconds). It slams in big, snaps down past its size,
-- overshoots and settles (vault: Animation oomph: snap, brake, overshoot,
-- settle); the impact flashes the disc, bursts a ring outward, lights the
-- new segment white-hot and snaps the glitch split tight.
local SLAM = 0.07 -- big to under-size: the hit
local SLAM_FROM = 1.6 -- start scale (a little bigger each kill)
local SLAM_STEP = 0.1
local SLAM_UNDER = 0.88
local REBOUND, REBOUND_TO = 0.09, 1.06
local SETTLE = 0.18
local SPIN_FROM, SPIN_TIME = -70, 0.5 -- the ring spins into place
local FLASH_TIME = 0.32
local WAVE_TIME, WAVE_TO = 0.45, 2.1
local SPLIT_FROM, SPLIT_TO, SPLIT_TIME = 16, 4, 0.22
local JITTER = { 7, -5, 3, 0 } -- emblem x kicks, one per 0.03 s
local OUT_TIME = 0.25

local feed: Frame? = nil
local template: Frame? = nil
local pop: Pop? = nil
local rowCount = 0
local roundKills = 0
-- The kills this round of each fighter you watched (Util/Watched), so their
-- pop climbs its own ladder and doesn't add to yours.
local watchedKills: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
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
	local palette = SettingsApply.palette() -- Settings COLORBLIND FILTER
	local ally, enemy = palette.ally or ALLY, palette.enemy or ENEMY
	if playerOf(x) == player then
		return ally
	end
	return if Teams.isAlly(x, player) then ally else enemy
end

local function row(
	killer: Instance?,
	victim: Instance,
	sourceId: string,
	head: boolean,
	assists: number,
	myAssist: boolean
)
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
	if assists > 0 then
		Ui.text(
			strip,
			"+" .. assists .. (if assists == 1 then " ASSIST" else " ASSISTS"),
			"label",
			{
				Name = "AssistTag",
				Size = UDim2.fromOffset(90, 24),
				LayoutOrder = 10,
				TextColor3 = if myAssist then ALLY else Theme.COLORS.textSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
		)
	end
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

-- Your kill (or the watched fighter's): the disc slams in from big, one
-- more ring segment lights (gold on a headshot), and it holds, then shrinks
-- away. `kills`: the killer's kills this round.
local function showPop(head: boolean, kills: number)
	local p = pop
	if not p then
		return
	end
	local count = math.min(kills, SEGMENTS)
	popToken += 1
	local token = popToken
	local lit = if head then GOLD else ENEMY
	local function live(): boolean
		return token == popToken
	end
	-- Start: big, faint, the ring turned back, the split wide.
	for i, seg in p.segs do
		local on = i < count
		seg.ImageColor3 = if on then lit else WHITE
		seg.ImageTransparency = if on then 0 else 0.7
		seg.Size = UDim2.fromScale(1, 1)
		-- The ring spins into place (each segment turns about the centre).
		local home = (i - 1) * 72
		seg.Rotation = home + SPIN_FROM
		tween(seg, SPIN_TIME, { Rotation = home }, Enum.EasingStyle.Back)
	end
	p.emblem.ImageColor3 = if head then GOLD else WHITE
	p.emblem.Position = UDim2.fromScale(0.5, 0.5)
	p.holder.Visible = true
	p.group.GroupTransparency = 0.6
	p.scale.Scale = SLAM_FROM + SLAM_STEP * (count - 1)
	p.flash.BackgroundTransparency = 1
	p.wave.ImageTransparency = 1
	for i, split in p.splits do
		local side = if i == 1 then -1 else 1
		split.Position = UDim2.new(0.5, side * SPLIT_FROM, 0.5, 0)
		split.ImageTransparency = 0
	end
	tween(p.group, SLAM, { GroupTransparency = 0 }, Enum.EasingStyle.Linear)
	-- The slam: accelerates into the hit.
	tween(p.scale, SLAM, { Scale = SLAM_UNDER }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(SLAM, function()
		if not live() then
			return
		end
		-- Rebound past full size, then settle.
		tween(p.scale, REBOUND, { Scale = REBOUND_TO }, Enum.EasingStyle.Quad).Completed:Once(
			function()
				if live() then
					tween(
						p.scale,
						SETTLE,
						{ Scale = 1 },
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					)
				end
			end
		)
		-- Flash and shockwave.
		p.flash.BackgroundColor3 = if head then GOLD else WHITE
		p.flash.BackgroundTransparency = 0.05
		tween(p.flash, FLASH_TIME, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		p.wave.ImageColor3 = lit
		p.wave.ImageTransparency = 0.1
		p.wave.Size = UDim2.fromScale(1, 1)
		tween(
			p.wave,
			WAVE_TIME,
			{ ImageTransparency = 1, Size = UDim2.fromScale(WAVE_TO, WAVE_TO) }
		)
		-- The new segment: white-hot and a little out, then its colour, home.
		local seg = p.segs[count]
		seg.ImageColor3 = WHITE
		seg.ImageTransparency = 0
		seg.Size = UDim2.fromScale(1.16, 1.16)
		tween(seg, 0.3, { ImageColor3 = lit, Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
		-- The glitch split snaps tight, the emblem kicks side to side.
		for i, split in p.splits do
			local side = if i == 1 then -1 else 1
			tween(split, SPLIT_TIME, { Position = UDim2.new(0.5, side * SPLIT_TO, 0.5, 0) })
		end
		for i, dx in JITTER do
			task.delay((i - 1) * 0.03, function()
				if live() then
					p.emblem.Position = UDim2.new(0.5, dx, 0.5, 0)
				end
			end)
		end
	end)
	-- Out: the split closes, it shrinks and fades.
	task.delay(POP_HOLD, function()
		if not live() then
			return
		end
		for _, split in p.splits do
			tween(split, OUT_TIME, { Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 1 })
		end
		tween(
			p.group,
			OUT_TIME,
			{ GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		tween(p.scale, OUT_TIME, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(OUT_TIME + 0.01, function()
			if live() then
				p.holder.Visible = false
			end
		end)
	end)
end

local function onKilled(
	victim: unknown,
	attacker: unknown,
	sourceId: unknown,
	headshot: unknown,
	assistIds: unknown
)
	if typeof(victim) ~= "Instance" or not PlayZone.inSameScope(player, victim) then
		return
	end
	local killer = if typeof(attacker) == "Instance" then attacker else nil
	local head = headshot == true
	local assists, myAssist = KillFeed.assistInfo(assistIds)
	row(
		killer,
		victim,
		if typeof(sourceId) == "string" then sourceId else "",
		head,
		assists,
		myAssist
	)
	if killer and playerOf(killer) == player and playerOf(victim) ~= player then
		roundKills += 1
		showPop(head, roundKills)
	elseif killer and Watched.is(killer) and not Watched.is(victim) then
		-- Spectating: the one you watch got the kill (the pop, as if yours).
		local holder = Watched.get()
		if holder then
			local kills = (watchedKills[holder] or 0) + 1
			watchedKills[holder] = kills
			showPop(head, kills)
		end
	end
end

local function bind(gui: ScreenGui)
	-- The screen is Scale (tools/studio/modules/UiToScale); each device's size
	-- and place come from Shared/UiLayout (phones: the right side, 2x).
	local canvas = gui:WaitForChild("Canvas") :: Frame
	feed = canvas:WaitForChild("Feed") :: Frame
	local holder = canvas:WaitForChild("KillPop") :: Frame
	local group = holder:WaitForChild("Group") :: CanvasGroup
	local disc = group:WaitForChild("Disc") :: Frame
	local ring = group:WaitForChild("Ring") :: Frame
	local segs: { ImageLabel } = {}
	for i = 1, SEGMENTS do
		segs[i] = ring:WaitForChild("Seg" .. i) :: ImageLabel
	end
	pop = {
		holder = holder,
		scale = holder:WaitForChild("Pop") :: UIScale,
		group = group,
		segs = segs,
		emblem = disc:WaitForChild("Emblem") :: ImageLabel,
		splits = {
			disc:WaitForChild("SplitA") :: ImageLabel,
			disc:WaitForChild("SplitB") :: ImageLabel,
		},
		flash = disc:WaitForChild("Flash") :: Frame,
		wave = holder:WaitForChild("Wave") :: ImageLabel,
	}
	local folder = UiRoot.templates():WaitForChild("KillFeed")
	template = folder:WaitForChild("Row") :: Frame
end

function KillFeedController.start()
	task.spawn(function()
		local gui = WaitGui("KillFeed")
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		bind(gui)
		-- Settings SHOW KILL FEED: the rows of recent kills (your own kill pop stays).
		SettingsApply.onChanged(function()
			if feed then
				feed.Visible = SettingsApply.get("showKillFeed") ~= false
			end
		end)
		Net.event("Killed").OnClientEvent:Connect(onKilled)
		MatchState.changed("Round"):Connect(function()
			roundKills = 0
			table.clear(watchedKills)
		end)
	end)
end

return KillFeedController
