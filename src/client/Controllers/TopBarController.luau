--!strict
-- The match top bar, v2.2 (vault/02 Art/UI Top Bar Draft.md). The layout is
-- built in Studio: StarterGui.TopBar.Root → Shadow + Bar → AllyTeam / Centre /
-- EnemyTeam. A team = Body (Players, Score) + a Slant cap; Centre holds the
-- Timer (Clock → Icon, Time; Info). The player cell template is
-- ReplicatedStorage.UiTemplates.TopBar.Player (a CanvasGroup with a Headshot).
-- Colours live on the instances (Body colour + Shade gradient, Body's
-- "CellColor" attribute), so they can be tuned in Studio.
-- This script only fills it in: one cell per fighter (greyed out when dead),
-- the round score, the clock and the info line, from MatchState; the server
-- decides all of it.
-- Motion: the bar drops in, cells pop in, a death dips and greys, a point
-- bumps the team block, flashes it bright and pops the number, the last
-- seconds pulse the timer.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local RunService = game:GetService("RunService")

local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)
local UiSound = require(script.Parent.Parent.Util.UiSound)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module (lobby + match)
local WaitGui = require(script.Parent.Parent.Util.WaitGui)

local TopBarController = {}

local player = Players.LocalPlayer

local TICK = 0.1 -- seconds between refreshes
local DESIGN = Vector2.new(1920, 1080) -- the Studio layout is authored at this size
local URGENT_LIVE = 10 -- the clock turns red this many seconds from the end
local TICK_FROM: { [string]: number } = { Draft = 5, Countdown = 3, Live = 5 } -- the clock ticks (sound) from here
local BOT_HEADSHOT = "rbxassetid://119185654291939" -- helmet stand-in for bots and test players
local SHADOW_PAD = Vector2.new(56, 48) -- the soft shadow reaches this far past the bar
local SCALE_STEP = 0.01 -- the fit scale only moves by more than this share (pixel rounding can't loop it)
local VOTE_ORDER = 41 -- over the map vote screen (StarterGui.MapVote is 40)
local BAR_HEIGHT = 80 -- design px of the bar
local ROW_GAP = 8 -- px kept clear between the bar and anything beside it
local ROW_KEEP = 0.8 -- the bar stays in the top row while it keeps this share of its size there,
local ROW_MIN_PX = 30 -- and at least this many px tall; otherwise it drops under Roblox's buttons
local DROP_GAP = 4 -- px between Roblox's top-bar row and a dropped bar
local REFIT_EVERY = 0.5 -- s: the neighbours (Roblox's menu bar opening, touch buttons) are re-measured this often
local LEVEL_TEXT = 14 -- design px of the LV chip under a headshot
local MIN_TEXT = 12 -- drawn px: a smaller LV chip hides (phones: it drew at 5-6 px)

local WHITE = Color3.new(1, 1, 1)
local DANGER = Color3.fromHex("FF4D5E")
local DEAD_TINT = Color3.fromRGB(120, 124, 132) -- greyed-out headshot
local DEAD_FADE = 0.35 -- headshot fade inside a dead cell
local CELL_DEAD = Color3.fromHex("3F3F42")
local CELL_FADE = 0.1

type Fighter = { key: Instance, userId: number?, humanoid: Humanoid? }
-- holder: a fixed-size item in the row; cell: centred inside it, so its pop
-- scales from the middle without moving the neighbours.
type Slot = {
	holder: Frame,
	cell: CanvasGroup,
	head: ImageLabel,
	skull: ImageLabel,
	pop: UIScale,
	downed: boolean?,
}
type Side = {
	block: Frame,
	blockPop: UIScale,
	body: Frame,
	slant: ImageLabel,
	players: Frame,
	value: TextLabel,
	valueShadow: TextLabel,
	pop: UIScale,
	color: Color3,
	cellColor: Color3,
	shown: number,
}

local tween = UiMotion.tween

local function clockText(seconds: number): string
	if MatchState.phase() == "Vote" and seconds < 10 then
		return string.format("%.1f", math.max(seconds, 0)) -- the vote: tenths, like RIVALS
	end
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

-- An onboarding match deals later phases early (MatchState.phaseFor).
local function tierName(round: number): string
	return string.upper(MatchState.phaseFor(round).name)
end

-- The round's guns in words ("SIDEARMS ONLY", "FULL LOADOUT"; Config/Match PHASES label).
local function gunsLabel(round: number): string
	return string.upper(MatchState.phaseFor(round).label)
end

local function myTeam(): number
	return Teams.of(player) or 1
end

-- Matches a bot seat to its Workspace.Dummies model within the local player's match.
local function findBotModel(dummies: Instance?, seat: Instance): Model?
	if not dummies then
		return nil
	end
	local botId = StateValues.get(seat, "BotId")
	for _, child in dummies:GetChildren() do
		if child:IsA("Model") and PlayZone.inSameScope(player, child) then
			if botId ~= nil and StateValues.get(child, "BotId") == botId then
				return child
			elseif botId == nil and child.Name == seat.Name then
				return child
			end
		end
	end
	return nil
end

-- Everyone on a team, in a stable order: you first, then players by UserId,
-- then bot seats by name. Seats exist before their bodies spawn.
local function roster(team: number): { Fighter }
	local list: { Fighter } = {}
	local people: { Player } = {}
	for _, p in Players:GetPlayers() do
		if PlayZone.inSameScope(player, p) and Teams.of(p) == team then
			table.insert(people, p)
		end
	end
	table.sort(people, function(a, b)
		if a == player then
			return true
		elseif b == player then
			return false
		end
		return a.UserId < b.UserId
	end)
	for _, p in people do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		table.insert(list, { key = p, userId = p.UserId, humanoid = humanoid })
	end
	local dummies = workspace:FindFirstChild("Dummies")
	local seats = MatchState.botSeats()
	table.sort(seats, function(a, b)
		return a.Name < b.Name
	end)
	for _, seat in seats do
		if StateValues.get(seat, Teams.ATTRIBUTE) == team then
			local model = findBotModel(dummies, seat)
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			table.insert(list, { key = seat, humanoid = humanoid })
		end
	end
	return list
end

-- Screen-pixel boxes { left, top, right, bottom } of what sits in the top rows beside the bar
-- (owner 2026-11-27, phone: "the settings button and also the top bar button overlapped with ...
-- the scoreboard"): Roblox's own buttons (left and right of GuiService.TopbarInset, live, so the
-- old and the new top bar and an opened menu bar all count), our Settings / Leave bar, and on
-- touch the weapon slots and the scoreboard / inspect buttons.
type Box = { number }
local function neighbours(playerGui: Instance, screenWidth: number): { Box }
	local boxes: { Box } = {}
	local inset = GuiService.TopbarInset
	if inset.Height > 0 then
		if inset.Min.X > 0 then
			table.insert(boxes, { 0, inset.Min.Y, inset.Min.X, inset.Max.Y })
		end
		if inset.Max.X < screenWidth - 1 then
			table.insert(boxes, { inset.Max.X, inset.Min.Y, screenWidth, inset.Max.Y })
		end
	end
	-- AbsolutePosition is measured from below Roblox's bar (GetGuiInset); boxes are screen pixels.
	local offset = GuiService:GetGuiInset()
	local function add(o: Instance?)
		if not o or not o:IsA("GuiObject") or not o.Visible then
			return
		end
		local screen = o:FindFirstAncestorWhichIsA("ScreenGui")
		if not screen or not screen.Enabled then
			return
		end
		local p, s = o.AbsolutePosition + offset, o.AbsoluteSize
		if s.X > 0 and s.Y > 0 then
			table.insert(boxes, { p.X, p.Y, p.X + s.X, p.Y + s.Y })
		end
	end
	local settings = playerGui:FindFirstChild("MatchSettingsTopbar")
	local settingsBar = settings and settings:FindFirstChild("Bar")
	if settingsBar then
		for _, b in settingsBar:GetChildren() do
			add(b)
		end
	end
	local touch = playerGui:FindFirstChild("Touch")
	local touchRoot = touch and touch:FindFirstChild("Root")
	if touchRoot and touchRoot:IsA("GuiObject") and touchRoot.Visible then
		local weapons = touchRoot:FindFirstChild("Weapons")
		if weapons and weapons:IsA("GuiObject") and weapons.Visible then
			for _, slot in weapons:GetChildren() do
				add(slot)
			end
		end
		local topLeft = touchRoot:FindFirstChild("TopLeft")
		if topLeft and topLeft:IsA("GuiObject") and topLeft.Visible then
			for _, b in topLeft:GetChildren() do
				add(b)
			end
		end
	end
	return boxes
end

-- How far the bar may reach left and right of `cx` (screen px) in the band `top`..`bottom`.
local function freeHalfWidth(
	boxes: { Box },
	cx: number,
	top: number,
	bottom: number,
	screenWidth: number
): number
	local left, right = 0, screenWidth
	for _, b in boxes do
		if b[2] < bottom and b[4] > top then
			if (b[1] + b[3]) / 2 < cx then
				left = math.max(left, b[3] + ROW_GAP)
			else
				right = math.min(right, b[1] - ROW_GAP)
			end
		end
	end
	return math.max(math.min(cx - left, right - cx), 0)
end

-- The bar's screen. The map vote shows the bar before anyone spawns (and
-- StarterGui only copies on a spawn), so take our own copy now and drop the
-- one Roblox adds at the first spawn (like MapVoteController).
local function ownCopy(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local mine0 = playerGui:FindFirstChild("TopBar")
	local source = if mine0 then nil else UiRoot.source("Match", "TopBar")
	if not mine0 and not (source and source:IsA("ScreenGui")) then
		return WaitGui("TopBar") :: ScreenGui
	end
	local mine = playerGui:FindFirstChild("TopBar") :: ScreenGui?
	if not mine then
		local copy = (source :: ScreenGui):Clone()
		copy.ResetOnSpawn = false
		copy.Parent = playerGui
		mine = copy
	end
	local kept = mine :: ScreenGui
	playerGui.ChildAdded:Connect(function(c)
		if c ~= kept and c.Name == "TopBar" and c:IsA("ScreenGui") then
			task.defer(c.Destroy, c)
		end
	end)
	return kept
end

function TopBarController.start()
	local gui = ownCopy()
	local baseOrder = gui.DisplayOrder
	local root = gui:WaitForChild("Root") :: Frame
	local fit = root:WaitForChild("Fit") :: UIScale
	-- This controller sets the bar's scale (phone-aware, below): Shared/UiLayout must not write it too. Both
	-- writing it was an endless resize fight on phones (the live "exponential deferred event growth" error).
	fit:SetAttribute("CustomFit", true)
	local shadow = root:WaitForChild("Shadow") :: ImageLabel
	local bar = root:WaitForChild("Bar") :: Frame
	local timer = (bar:WaitForChild("Centre") :: Frame):WaitForChild("Timer") :: Frame
	local clock = timer:WaitForChild("Clock") :: Frame
	local timeLabel = clock:WaitForChild("Time") :: TextLabel
	local icon = clock:WaitForChild("Icon") :: ImageLabel
	local infoLabel = timer:WaitForChild("Info") :: TextLabel
	local timerEdge = timer:WaitForChild("Edge") :: UIStroke
	local timerPop = timer:WaitForChild("Pop") :: UIScale
	local template = UiRoot.templates():WaitForChild("TopBar"):WaitForChild("Player") :: Frame

	local function side(name: string): Side
		local block = bar:WaitForChild(name) :: Frame
		local body = block:WaitForChild("Body") :: Frame
		-- The number and its shadow sit in a centred Inner frame (its pop scales
		-- from the middle; the Score item keeps its size in the row).
		local score = (body:WaitForChild("Score") :: Frame):WaitForChild("Inner") :: Frame
		local players = body:WaitForChild("Players") :: Frame
		-- The Studio preview cells only show the layout in Edit mode.
		for _, child in players:GetChildren() do
			if StateValues.get(child, "Preview") then
				child:Destroy()
			end
		end
		local cellColor = StateValues.get(body, "CellColor")
		return {
			block = block,
			blockPop = block:WaitForChild("Pop") :: UIScale,
			body = body,
			slant = block:WaitForChild("Slant") :: ImageLabel,
			players = players,
			value = score:WaitForChild("Value") :: TextLabel,
			valueShadow = score:WaitForChild("Shadow") :: TextLabel,
			pop = score:WaitForChild("Pop") :: UIScale,
			color = body.BackgroundColor3,
			cellColor = if typeof(cellColor) == "Color3" then cellColor else Color3.new(0, 0, 0),
			shown = -1,
		}
	end
	local sides: { [string]: Side } = { ally = side("AllyTeam"), enemy = side("EnemyTeam") }

	-- The bar sizes to the team sizes, so it keeps its 1080p pixel design and
	-- one UIScale fits it to the screen (vault/04 Tech/UI Architecture.md §5):
	--   * desktop / console: the screen height / 1080 (and never wider than
	--     the screen), with no floor: a floor is what pushed UI off phones;
	--   * phones (touch): 11.5% of the height, and the ROUND / tier line under
	--     the clock hides (it drew at 5-7 px);
	--   * every device: the bar shrinks to clear what is measured beside it in
	--     its row (neighbours: Roblox's buttons, Settings, the touch weapon
	--     slots), centred on the screen. If that would shrink it below
	--     ROW_KEEP of its size or ROW_MIN_PX, it drops under Roblox's buttons.
	local infoLine = root:FindFirstChild("Info", true)
	local clockPosition = if clock and clock:IsA("GuiObject") then clock.Position else nil
	local clockAnchor = if clock and clock:IsA("GuiObject") then clock.AnchorPoint else nil
	local rowHome = root.Position -- the Studio spot: the top row
	local home = rowHome -- where the bar sits now (the drop-in tween ends here)
	local dropping = false
	local function refit()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local phone = UiLayout.family() == "Phone"
		local width = math.max(bar.AbsoluteSize.X / math.max(fit.Scale, 0.01), 1)
		local natural = if phone then 0.115 * size.Y / BAR_HEIGHT else size.Y / DESIGN.Y
		natural = math.min(natural, size.X * 0.96 / width)

		-- Screen pixels: the gui's top-left and the bar's centre line.
		local origin = gui.AbsolutePosition + GuiService:GetGuiInset()
		local screenWidth = GuiService:GetInsetArea(Enum.ScreenInsets.None).Width
		local cx = origin.X + size.X / 2
		local boxes = neighbours(gui.Parent or gui, screenWidth)
		local function fitAt(top: number): number
			local half = freeHalfWidth(boxes, cx, top, top + BAR_HEIGHT * natural, screenWidth)
			return math.min(natural, 2 * half / width)
		end
		local rowTop = origin.Y + rowHome.Y.Scale * size.Y + rowHome.Y.Offset
		local scale = fitAt(rowTop)
		local newHome = rowHome
		local inset = GuiService.TopbarInset
		if
			(scale < natural * ROW_KEEP or BAR_HEIGHT * scale < ROW_MIN_PX)
			and inset.Height > 0
			and inset.Max.Y + DROP_GAP > rowTop
		then
			local dropTop = inset.Max.Y + DROP_GAP
			local dropped = fitAt(dropTop)
			if dropped > scale then
				scale = dropped
				newHome = UDim2.new(rowHome.X.Scale, rowHome.X.Offset, 0, dropTop - origin.Y)
			end
		end
		if newHome ~= home then
			home = newHome
			if not dropping then
				root.Position = home
			end
		end
		-- The bar's width is read back through this same scale, rounded to whole pixels, so every write
		-- nudged the next read: on phones (where the scale depends on the width) it never settled, an
		-- endless AbsoluteSize loop (live error log 2026-11-24/25: "exponential deferred event growth",
		-- ~4,300 reports; lag and jumping UI on phones). A change under SCALE_STEP is that rounding: kept.
		local target = math.max(scale, 0.05)
		if math.abs(target - fit.Scale) > SCALE_STEP * fit.Scale then
			fit.Scale = target
		end
		if infoLine and infoLine:IsA("GuiObject") then
			-- (tablets: 15 px design drew at 10.5 px on an iPad)
			infoLine.Visible = not phone and infoLabel.TextSize * fit.Scale >= MIN_TEXT
		end
		local showLevel = LEVEL_TEXT * fit.Scale >= MIN_TEXT
		for _, s in sides do
			for _, holder in s.players:GetChildren() do
				local tag = holder:FindFirstChild("LevelTag")
				if tag and tag:IsA("GuiObject") then
					tag.Visible = showLevel
				end
			end
		end
		if clock and clock:IsA("GuiObject") and clockPosition and clockAnchor then
			clock.AnchorPoint = if phone then Vector2.new(clockAnchor.X, 0.5) else clockAnchor
			clock.Position = if phone
				then UDim2.new(clockPosition.X.Scale, clockPosition.X.Offset, 0.5, 0)
				else clockPosition
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	-- The soft shadow follows the bar's width (the bar grows with the team sizes).
	local function fitShadow()
		local width = math.round(bar.AbsoluteSize.X / math.max(fit.Scale, 0.01))
		local size = UDim2.fromOffset(width + SHADOW_PAD.X, bar.Size.Y.Offset + SHADOW_PAD.Y)
		-- Only a real change (a fighter joined or left): pixel rounding through the scale isn't one.
		if math.abs(shadow.Size.X.Offset - size.X.Offset) > 2 or shadow.Size.Y ~= size.Y then
			shadow.Size = size
		end
	end
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitShadow)
	fitShadow()

	local slots: { [string]: { [Instance]: Slot } } = { ally = {}, enemy = {} }

	local function newSlot(key: string, f: Fighter): Slot
		local holder = template:Clone()
		local cell = holder:WaitForChild("Cell") :: CanvasGroup
		cell.BackgroundColor3 = sides[key].cellColor
		local head = cell:WaitForChild("Headshot") :: ImageLabel
		local pop = cell:WaitForChild("Pop") :: UIScale
		pop.Scale = 0.5
		local skull = Instance.new("ImageLabel")
		skull.Name = "DeathSkull"
		skull.AnchorPoint = Vector2.new(0.5, 0.5)
		skull.Position = UDim2.fromScale(0.5, 0.47)
		skull.Size = UDim2.fromScale(0.55, 0.55)
		skull.BackgroundTransparency = 1
		skull.Image = Theme.ICON.Skull
		skull.ImageTransparency = 1
		skull.ScaleType = Enum.ScaleType.Fit
		skull.ZIndex = head.ZIndex + 2
		skull.Parent = cell
		-- Level on the tile's foot, device in its corner.
		local z = cell.ZIndex + 5
		local lv = PlayerTags.level(holder, f.key, LEVEL_TEXT, z)
		lv.Visible = LEVEL_TEXT * fit.Scale >= MIN_TEXT
		lv.AnchorPoint = Vector2.new(0.5, 0.5)
		lv.Position = UDim2.new(0.5, 0, 1, -1)
		local dev = PlayerTags.device(holder, f.key, 14, z)
		dev.AnchorPoint = Vector2.new(1, 0)
		dev.Position = UDim2.new(1, -4, 0, 4)
		holder.Parent = sides[key].players
		tween(pop, 0.36, { Scale = 1 })
		return {
			holder = holder,
			cell = cell,
			head = head,
			skull = skull,
			pop = pop,
			downed = nil,
		}
	end

	local function setDowned(key: string, slot: Slot, downed: boolean)
		if slot.downed == downed then
			return
		end
		local first = slot.downed == nil
		slot.downed = downed
		local time = if first then 0 else 0.3
		tween(slot.cell, time, {
			BackgroundColor3 = if downed then CELL_DEAD else sides[key].cellColor,
			BackgroundTransparency = if downed then 0 else CELL_FADE,
		})
		tween(slot.head, time, {
			ImageColor3 = if downed then DEAD_TINT else WHITE,
			ImageTransparency = if downed then DEAD_FADE else 0,
		})
		tween(slot.skull, time, { ImageTransparency = if downed then 0 else 1 })

		if not first then
			-- A dip on a death, a lift on a respawn.
			slot.pop.Scale = if downed then 0.85 else 1.15
			tween(slot.pop, 0.32, { Scale = 1 })
		end
	end

	local function syncSide(key: string, team: number)
		local seen: { [Instance]: boolean } = {}
		for i, f in roster(team) do
			seen[f.key] = true
			local slot = slots[key][f.key]
			if not slot then
				slot = newSlot(key, f)
				slots[key][f.key] = slot
			end
			PlayerTags.loadHeadshot(
				slot.head,
				f.userId or StateValues.get(f.key, "PortraitUserId"),
				BOT_HEADSHOT
			)
			-- Player 1 sits next to the score, closest to the timer.
			slot.holder.LayoutOrder = if key == "ally" then -i else i
			-- Keep the last known state if the body is temporarily out of view.
			if MatchState.phase() == "Vote" then
				setDowned(key, slot, false)
			elseif f.humanoid or slot.downed == nil then
				setDowned(key, slot, Health.isDowned(f.humanoid))
			end
			local placeholder = slot.head:FindFirstChild("LoadingPortrait")
			if placeholder and placeholder:IsA("ImageLabel") then
				placeholder.ImageColor3 = slot.head.ImageColor3
				placeholder.ImageTransparency = slot.head.ImageTransparency
			end
		end
		for k, slot in slots[key] do
			if not seen[k] then
				slot.holder:Destroy()
				slots[key][k] = nil
			end
		end
	end

	local function setScore(s: Side, value: number)
		local text = tostring(value)
		s.value.Text = text
		s.valueShadow.Text = text
		if s.shown >= 0 and value > s.shown then
			-- A point: the block bumps and flashes bright, the number pops.
			if s == sides.ally then -- only your own team's point pings (2026-11-20)
				UiSound.play("Score")
			end
			s.pop.Scale = 1.35
			tween(s.pop, 0.42, { Scale = 1 })
			local flash = s.color:Lerp(WHITE, 0.55)
			s.body.BackgroundColor3 = flash
			s.slant.ImageColor3 = flash
			tween(s.body, 0.5, { BackgroundColor3 = s.color })
			tween(s.slant, 0.5, { ImageColor3 = s.color })
		end
		s.shown = value
	end

	local lastSecond = -1
	local lastTick = -1
	local function refresh()
		local phase = MatchState.phase()
		root.Visible = phase ~= nil and phase ~= "Waiting" and not TestMode.isOn()
		-- Over the map vote's screen (it covers every other HUD).
		gui.DisplayOrder = if phase == "Vote" then VOTE_ORDER else baseOrder
		if not root.Visible then
			return
		end
		local mine = myTeam()
		local theirs = if mine == 1 then 2 else 1
		syncSide("ally", mine)
		syncSide("enemy", theirs)

		local scoreOne = MatchState.get("Score1") or 0
		local scoreTwo = MatchState.get("Score2") or 0
		local myScore = if mine == 1 then scoreOne else scoreTwo
		local theirScore = if mine == 1 then scoreTwo else scoreOne
		setScore(sides.ally, myScore)
		setScore(sides.enemy, theirScore)

		local left = MatchState.timeLeft()
		local second = math.ceil(left)
		timeLabel.Text = clockText(left)
		local urgent = phase == "SuddenDeath"
			or phase == "Countdown"
			or (phase == "Live" and second <= URGENT_LIVE)
			or (phase == "Draft" and second <= 5)
			or (phase == "Vote" and second <= 3)
		timeLabel.TextColor3 = if urgent then DANGER else WHITE
		icon.ImageColor3 = if urgent then DANGER else WHITE
		timerEdge.Transparency = if urgent then 0.2 else 1
		if urgent and second ~= lastSecond and second >= 1 and second <= URGENT_LIVE then
			timerPop.Scale = 1.08
			tween(timerPop, 0.3, { Scale = 1 })
		end
		lastSecond = second
		-- The last seconds tick (moved here from MatchHudController's old bar).
		local from = TICK_FROM[phase or ""]
		if from and second >= 1 and second <= from and second ~= lastTick then
			lastTick = second
			UiSound.play(if second == 1 then "TickFinal" else "Tick")
		elseif not from or second > from then
			lastTick = -1
		end

		local round = MatchState.get("Round") or 0
		local matchPoint = math.max(myScore, theirScore) == MatchState.roundsToWin() - 1
		local info
		if phase == "Vote" then
			info = "VOTE FOR A MAP"
		elseif phase == "SuddenDeath" then
			info = string.format(
				'ROUND %d · <font color="#%s">SUDDEN DEATH</font>',
				round,
				DANGER:ToHex()
			)
		elseif round <= 0 then
			info = string.format("FIRST TO %d", MatchState.roundsToWin())
		elseif phase == "Draft" then
			info = string.format("DRAFT · %s", gunsLabel(round))
		elseif matchPoint then
			info = string.format('ROUND %d · <font color="#FFC83D">MATCH POINT</font>', round)
		else
			info = string.format("ROUND %d · %s", round, tierName(round))
		end
		infoLabel.Text = info
	end

	-- Drop into place when a match starts showing the bar.
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			refit()
			local target = home
			dropping = true
			root.Position = target - UDim2.fromOffset(0, 40)
			tween(root, 0.42, { Position = target }).Completed:Once(function()
				dropping = false
				if home ~= target then -- the spot moved during the drop
					root.Position = home
				end
			end)
		end
	end)

	local acc, sinceFit = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		sinceFit += acc
		acc = 0
		if sinceFit >= REFIT_EVERY then
			sinceFit = 0
			refit()
		end
		refresh()
	end)
	refresh()
end

return TopBarController
