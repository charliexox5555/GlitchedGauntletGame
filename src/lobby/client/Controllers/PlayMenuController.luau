--!strict
-- The desktop Play menu and the searching bar (vault/02 Art/UI Play and Party
-- Menus.md). Both are Studio-built (StarterGui.PlayMenu, StarterGui.LobbySearch;
-- backup tools/studio/BuildLobbyMenus.luau); this only fills and animates them.
--
-- PLAY opens the menu as the Router's "Queue" menu (the world blurs behind).
-- Clicking a live tile (1V1 / 2V2 / 3V3, or keys 1-3) asks the server to queue
-- and closes the menu; SOON tiles (BEGINNER 2V2, 4V4, 5V5) only nudge. While
-- you're searching, the bar at the top shows the mode, the bot-fill countdown,
-- the timer and a cancel button (anyone in a party can cancel; only the leader
-- starts). The server decides everything (Services/QueueService).
-- Phones keep the old code-built menu (Controllers/QueueMenu) for now.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local Layout = require(script.Parent.Parent.Util.Layout)
local Plates = require(script.Parent.Parent.Util.Plates)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M

local PlayMenuController = {}

local player = Players.LocalPlayer
local DESIGN = Vector2.new(1920, 1080)
local QUINT = Enum.EasingStyle.Quint
local IN = Enum.EasingDirection.In
local GREEN, MUTED = Color3.fromHex("3FD68A"), Color3.fromHex("B8B8BB")
local LIVE = { "1v1", "2v2", "3v3" }

type Tile = {
	id: string,
	button: TextButton,
	pop: UIScale,
	art: ImageLabel?,
	tone: Color3,
	live: boolean,
	count: TextLabel?,
	dot: Frame?,
	inQueue: GuiObject?,
	home: UDim2,
}

local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local scrim: Frame
local tiles: { Tile } = {}
local isOpen = false
local openToken = 0
local resetClose: () -> () = function() end
local pendingUntil = 0 -- a join is in flight: ignore more clicks briefly

-- the searching bar
local searchGui: ScreenGui
local barFit: UIScale
local bar: Frame
local barPop: UIScale
local barMode: TextLabel
local barSub: TextLabel
local barTimer: TextLabel
local barSpin: UIGradient
local barShown = false
local barConn: RBXScriptConnection? = nil

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

-- A child that may not be there (SOON tiles have no count or queue tag).
local function maybe(parent: Instance?, name: string): Instance?
	return if parent then parent:FindFirstChild(name) else nil
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- A quick dip from the pop's rest scale and an ease back (no overshoot).
local function press(p: UIScale?, _low: number?)
	if p then
		UiMotion.press(p)
	end
end

local function rest(p: UIScale?, scale: number)
	if p then
		UiMotion.rest(p, scale)
	end
end

-- A small left-right nudge for things that aren't ready (SOON tiles).
local nudge = UiMotion.nudge

--------------------------------------------------------------------------------
-- Tiles

local function refreshTiles()
	local searching = QueueState.status() ~= "idle"
	local queued = QueueState.mode()
	for _, t in tiles do
		if t.live then
			local n = QueueState.count(t.id)
			if t.count then
				t.count.Text = string.format("%d SEARCHING", n)
			end
			if t.dot then
				t.dot.BackgroundColor3 = if n > 0 then GREEN else MUTED
			end
			if t.inQueue then
				t.inQueue.Visible = searching and queued == t.id
			end
		end
	end
end

local function choose(t: Tile)
	if not t.live then
		nudge(t.button, t.home)
		LobbyHud.toast("Coming soon", "info")
		return
	end
	press(t.pop)
	if os.clock() < pendingUntil then
		return
	end
	if not QueueState.isLeader() then
		LobbyHud.toast("Your party leader starts the search", "info")
		return
	end
	local status = QueueState.status()
	if status == "idle" or (status == "searching" and QueueState.mode() ~= t.id) then
		pendingUntil = os.clock() + 1.5
		QueueState.join(t.id)
	end
	Router.close()
end

local function hookTile(t: Tile)
	t.button.MouseEnter:Connect(function()
		rest(t.pop, if t.live then KM.hoverCard else 1.012)
		if t.art then
			tween(t.art, 0.2, {
				ImageColor3 = if t.live
					then Color3.new(1, 1, 1)
					else t.tone:Lerp(Color3.new(1, 1, 1), 0.2),
			})
		end
	end)
	t.button.MouseLeave:Connect(function()
		rest(t.pop, 1)
		if t.art then
			tween(t.art, 0.2, { ImageColor3 = t.tone })
		end
	end)
	t.button.Activated:Connect(function()
		choose(t)
	end)
end

--------------------------------------------------------------------------------
-- Open / close

local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(size.X / DESIGN.X, size.Y / DESIGN.Y)
	end
end

local function open()
	openToken += 1
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	refit()
	refreshTiles()
	resetClose()
	scrim.BackgroundTransparency = 1
	tween(scrim, 0.25, { BackgroundTransparency = 0.45 })
	-- the header slides in from the left, the tiles rise in one after another
	for _, name in { "Title", "Hint" } do
		local o = canvas:FindFirstChild(name)
		if o and o:IsA("GuiObject") then
			local h = o:GetAttribute("Home")
			local home = if typeof(h) == "UDim2" then h else o.Position
			o:SetAttribute("Home", home)
			o.Position = home - UDim2.fromOffset(40, 0)
			tween(o, 0.4, { Position = home })
		end
	end
	for i, t in tiles do
		t.button.Position = t.home + UDim2.fromOffset(0, 36)
		t.pop:SetAttribute("Rest", 1)
		t.pop.Scale = 0.96
		if t.art then
			t.art.ImageColor3 = t.tone
		end
		task.delay((i - 1) * 0.03, function()
			if isOpen then
				tween(t.button, 0.42, { Position = t.home })
				tween(t.pop, 0.42, { Scale = 1 })
			end
		end)
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	openToken += 1
	local token = openToken
	tween(scrim, 0.16, { BackgroundTransparency = 1 }, QUINT, IN)
	for _, t in tiles do
		tween(t.button, 0.16, { Position = t.home + UDim2.fromOffset(0, 18) }, QUINT, IN)
	end
	task.delay(0.17, function()
		if openToken == token and not isOpen then
			gui.Enabled = false
			for _, t in tiles do
				t.button.Position = t.home
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- The searching bar

local function refitBar()
	local size = searchGui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		barFit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.6, 1.5)
	end
end

local function updateBar()
	local elapsed = QueueState.elapsed()
	barTimer.Text = clock(elapsed)
	local mode = string.upper(QueueState.mode() or "")
	local left = QueueState.botFillAfter() - elapsed
	barSub.Text = if left > 0
		then string.format("%s  ·  BOTS FILL IN %s", mode, clock(left))
		else string.format("%s  ·  FILLING WITH BOTS", mode)
	barSpin.Rotation = (os.clock() * 220) % 360
end

-- Shown while searching and no menu or MATCH FOUND covers the screen.
local function placeBar()
	local want = QueueState.status() == "searching" and Router.current() == nil
	if want == barShown then
		if want then
			barMode.Text = string.upper(QueueState.mode() or "")
		end
		return
	end
	barShown = want
	if want then
		barMode.Text = string.upper(QueueState.mode() or "")
		updateBar()
		bar.Visible = true
		bar.Position = UDim2.new(0.5, 0, 0.5, -24)
		barPop.Scale = 0.92
		tween(bar, 0.4, { Position = UDim2.fromScale(0.5, 0.5) })
		tween(barPop, 0.4, { Scale = 1 })
		if not barConn then
			barConn = RunService.Heartbeat:Connect(updateBar)
		end
	else
		tween(bar, 0.18, { Position = UDim2.new(0.5, 0, 0.5, -24) }, QUINT, IN)
		local t = tween(barPop, 0.18, { Scale = 0.92 }, QUINT, IN)
		t.Completed:Once(function()
			if not barShown then
				bar.Visible = false
				if barConn then
					barConn:Disconnect()
					barConn = nil
				end
			end
		end)
	end
end

--------------------------------------------------------------------------------

function PlayMenuController.init()
	if Layout.isPhone() then
		return -- phones keep Controllers/QueueMenu's menu for now
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("PlayMenu", 15)
	local sg = playerGui:WaitForChild("LobbySearch", 15)
	if not g or not g:IsA("ScreenGui") or not sg or not sg:IsA("ScreenGui") then
		warn(
			"[PlayMenu] StarterGui.PlayMenu / LobbySearch missing (tools/studio/BuildLobbyMenus.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	canvas = child(gui, "Canvas")
	fit = child(canvas, "Fit")
	scrim = child(gui, "Scrim")
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	local modes = child(canvas, "Modes") :: Frame
	for _, b in modes:GetChildren() do
		if b:IsA("TextButton") then
			local art = b:FindFirstChild("Art")
			local count = b:FindFirstChild("Count")
			local t: Tile = {
				id = b.Name,
				button = b,
				pop = child(b, "Pop"),
				art = if art and art:IsA("ImageLabel") and art.Visible then art else nil,
				tone = if art and art:IsA("ImageLabel")
					then art.ImageColor3
					else Color3.new(1, 1, 1),
				live = b:GetAttribute("Live") == true,
				count = maybe(count, "Label") :: TextLabel?,
				dot = maybe(count, "Dot") :: Frame?,
				inQueue = maybe(b, "InQueue") :: GuiObject?,
				home = b.Position,
			}
			table.insert(tiles, t)
			hookTile(t)
		end
	end
	table.sort(tiles, function(a, b)
		return a.button.LayoutOrder < b.button.LayoutOrder
	end)
	resetClose = CloseButton.hook(child(canvas, "Close") :: GuiButton, function()
		Router.close()
	end)
	Plates.deepen(gui)
	Router.register("Queue", { open = open, close = close })

	searchGui = sg
	local top = child(searchGui, "Top") :: Frame
	barFit = child(top, "Fit")
	bar = child(top, "Bar")
	barPop = child(bar, "Pop")
	local modeCircle = child(bar, "Mode") :: Frame
	barMode = child(modeCircle, "Label")
	barSpin = child(child(child(modeCircle, "Ring"), "Stroke"), "Spin")
	barSub = child(bar, "Sub")
	barTimer = child(bar, "Timer")
	bar.Visible = false
	searchGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refitBar)
	refitBar()
	local cancel = child(bar, "Cancel") :: TextButton
	local cancelPop = child(cancel, "Pop") :: UIScale
	cancel.MouseEnter:Connect(function()
		rest(cancelPop, KM.hover)
	end)
	cancel.MouseLeave:Connect(function()
		rest(cancelPop, 1)
	end)
	cancel.Activated:Connect(function()
		press(cancelPop)
		QueueState.leave()
	end)
end

function PlayMenuController.start()
	if not gui then
		return
	end
	QueueState.onChanged(function()
		pendingUntil = 0
		refreshTiles()
		placeBar()
	end)
	Router.onChanged(function()
		placeBar()
	end)
	placeBar()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not isOpen then
			return
		end
		local index = if input.KeyCode == Enum.KeyCode.One
			then 1
			elseif input.KeyCode == Enum.KeyCode.Two then 2
			elseif input.KeyCode == Enum.KeyCode.Three then 3
			else nil
		if index then
			for _, t in tiles do
				if t.id == LIVE[index] then
					choose(t)
				end
			end
		end
	end)
end

return PlayMenuController
