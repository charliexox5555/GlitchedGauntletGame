--!strict
-- The Play menu and the searching bar (vault/02 Art/UI Play and Party
-- Menus.md). Both are Studio-built (StarterGui.PlayMenu, StarterGui.LobbySearch;
-- backup tools/studio/BuildLobbyMenus.luau); this only fills and animates them.
--
-- PLAY opens the menu as the Router's "Queue" menu (the world blurs behind).
-- Clicking a live tile (1V1 / 2V2 / 3V3, or keys 1-3; BEGINNER 2V2 below level 10,
-- highlighted, onboarding 2026-11-22) asks the server to queue and closes the menu;
-- SOON tiles (4V4, 5V5) only nudge. A tile is live when Lobby Config.MODE_BY_TILE
-- names it (else its Studio "Live" attribute). While
-- you're searching, the bar at the top shows the mode, the bot-fill countdown,
-- the timer and a cancel button (anyone in a party can cancel; only the leader
-- starts). The server decides everything (Services/QueueService).
-- Every device; Shared/UiLayout sizes both (their Fit scales).

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)
local Config = require(game:GetService("ReplicatedStorage").Lobby.Config)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local Plates = require(script.Parent.Parent.Util.Plates)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M
local UiSfx = require(game:GetService("ReplicatedStorage").Shared.UiSfx)

local PlayMenuController = {}

local player = Players.LocalPlayer
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
	hit: GuiButton?,
	levelCap: number?, -- shown only below this level (Beginner 2v2)
	featured: boolean, -- sits brighter than the others (Beginner 2v2)
}

local gui: ScreenGui
local canvas: Frame
local scrim: Frame
local tiles: { Tile } = {}
local isOpen = false
local openToken = 0
local resetClose: () -> () = function() end
local pendingUntil = 0 -- a join is in flight: ignore more clicks briefly

-- the searching bar
local searchGui: ScreenGui
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

local function levelNow(): number
	local v = StateValues.get(player, "Level")
	return if typeof(v) == "number" then v else 1
end

local function refreshTiles()
	local searching = QueueState.status() ~= "idle"
	local queued = QueueState.mode()
	local level = levelNow()
	for _, t in tiles do
		if t.levelCap then
			local shown = level < t.levelCap
			t.button.Visible = shown
			if t.hit then
				t.hit.Visible = shown
			end
		end
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
		UiSfx.cue("Denied")
		LobbyHud.toast("Coming soon", "info")
		return
	end
	press(t.pop)
	UiSfx.cue("Confirm")
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

-- Focus (owner 2026-11-20: "focus in on a duel, not shake it"; round 2: "the
-- text still shakes a little, and it's really dark"; vault/02 Art/UI Polish
-- Pass.md): NOTHING scales any more (a scaling tile re-draws its words every
-- frame, which reads as a shimmer). The hovered tile's art goes full bright
-- and its dark shade lifts; the other tiles ease back a little. At rest the
-- live tiles sit brighter than before. Hover is read from a fixed, invisible
-- Hit button over each tile's home.
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(150, 150, 158)
local REST_LIFT = 0.35 -- live tiles at rest: their tone this far toward white
local FEATURED_LIFT = 0.75 -- the Beginner tile while it's offered: the brightest at rest
local FEATURED_SUB = Color3.fromHex("FFC83D") -- its sub-line in the PLAY gold
local focused: Tile? = nil
local shadeHome: { [Tile]: number } = {}

local function artColour(t: Tile): Color3
	local base = if t.live
		then t.tone:Lerp(WHITE, if t.featured then FEATURED_LIFT else REST_LIFT)
		else t.tone
	if focused == t then
		return if t.live then WHITE else t.tone:Lerp(WHITE, 0.25)
	elseif focused then
		return base:Lerp(DIM, 0.3) -- another tile has the focus
	end
	return base
end

local function shadeOf(t: Tile): Frame?
	local sh = t.button:FindFirstChild("Shade")
	return if sh and sh:IsA("Frame") then sh else nil
end

-- Size on hover (owner round 3: "the hover should also have some size
-- animation") without scaling any words: the picture zooms inside its own
-- frame (its crop rectangle shrinks around the centre, so the tile, its
-- rounded corners and the text stay exactly as they are) and the tile lifts
-- a few pixels. The art is drawn from an explicit crop rect (Stretch over a
-- rect of the tile's own aspect = the same look as Crop).
local ZOOM = 1.08
local LIFT_PX = 5
local cropOf: { [Tile]: { size: Vector2, centre: Vector2 } } = {}

local ART_PX = Vector2.new(840, 940) -- the old mode pictures' size (refined below when readable)
-- The queue tile pictures' real sizes (art-source/ui/queue/upload, 2026-11-22): EditableImage
-- can't read them in a live game, so the crop needs them written down.
local ART_SIZE: { [string]: Vector2 } = {
	["1v1"] = Vector2.new(1024, 1024),
	["2v2"] = Vector2.new(1024, 1024),
	["3v3"] = Vector2.new(1024, 1024),
	["4v4"] = Vector2.new(1024, 612),
	["5v5"] = Vector2.new(1024, 612),
	Beginner2v2 = Vector2.new(572, 1024),
}

local function applyCrop(t: Tile, dims: Vector2)
	local art = t.art
	if not art then
		return
	end
	local tile = t.button.Size
	local aspect = tile.X.Offset / math.max(tile.Y.Offset, 1)
	local size = if aspect > dims.X / dims.Y
		then Vector2.new(dims.X, dims.X / aspect)
		else Vector2.new(dims.Y * aspect, dims.Y)
	cropOf[t] = { size = size, centre = dims / 2 }
	art.ScaleType = Enum.ScaleType.Stretch
	art.ImageRectSize = size
	art.ImageRectOffset = dims / 2 - size / 2
end

local function setupCrop(t: Tile)
	local art = t.art
	if not art then
		return
	end
	local known = ART_SIZE[t.button.Name]
	applyCrop(t, known or ART_PX)
	if known then
		return
	end
	-- new mode art may have another size: read it in the background, and keep
	-- the default if the client can't (EditableImage may be unavailable)
	task.spawn(function()
		local ok, img = pcall(function()
			return game:GetService("AssetService")
				:CreateEditableImageAsync(Content.fromUri(art.Image))
		end)
		if ok and img then
			local dims = img.Size
			img:Destroy()
			if dims ~= ART_PX and dims.X > 0 and dims.Y > 0 then
				applyCrop(t, dims)
			end
		end
	end)
end

local function zoomArt(t: Tile, z: number, time: number)
	local c = cropOf[t]
	local art = t.art
	if not (c and art) then
		return
	end
	local size = c.size / z
	tween(art, time, { ImageRectSize = size, ImageRectOffset = c.centre - size / 2 })
end

local function paintTile(o: Tile, time: number)
	if o.art then
		tween(o.art, time, { ImageColor3 = artColour(o) })
	end
	local sh = shadeOf(o)
	if sh then
		local home = shadeHome[o]
		if home == nil then
			home = sh.BackgroundTransparency
			shadeHome[o] = home
		end
		tween(sh, time, {
			-- the dark shade is lighter at rest too (owner: "really dark"); the
			-- focused tile lifts it further
			BackgroundTransparency = math.min(home + (if focused == o then 0.4 else 0.15), 1),
		})
	end
end

local function setFocus(t: Tile?)
	if focused == t then
		return
	end
	focused = t
	for _, o in tiles do
		paintTile(o, 0.3)
		local on = o == t and o.live
		zoomArt(o, if on then ZOOM else 1, if on then 0.4 else 0.3)
		if isOpen then
			tween(
				o.button,
				0.3,
				{ Position = o.home - UDim2.fromOffset(0, if on then LIFT_PX else 0) }
			)
		end
	end
end

local function hookTile(t: Tile, hit: GuiButton)
	hit.MouseEnter:Connect(function()
		setFocus(t)
	end)
	hit.SelectionGained:Connect(function()
		setFocus(t)
	end)
	hit.MouseLeave:Connect(function()
		if focused == t then
			setFocus(nil)
		end
	end)
	hit.SelectionLost:Connect(function()
		if focused == t then
			setFocus(nil)
		end
	end)
	hit.Activated:Connect(function()
		choose(t)
	end)
end

-- The fixed hover / click area for a tile (made once, at the tile's home).
local function hitFor(b: TextButton): TextButton
	local hit = Instance.new("TextButton")
	hit.Name = b.Name .. "Hit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = b.AnchorPoint
	hit.Position = b.Position
	hit.Size = b.Size
	hit.ZIndex = b.ZIndex + 50
	hit.Parent = b.Parent
	-- the tile itself no longer takes the mouse or gamepad focus
	b.Interactable = false
	b.Selectable = false
	return hit
end

--------------------------------------------------------------------------------
-- Open / close

local function open()
	openToken += 1
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	refreshTiles()
	resetClose()
	scrim.BackgroundTransparency = 1
	tween(scrim, 0.25, { BackgroundTransparency = 0.62 }) -- lighter (owner: "really dark")
	-- the header slides in from the left, the tiles rise in one after another
	for _, name in { "Title", "Hint" } do
		local o = canvas:FindFirstChild(name)
		if o and o:IsA("GuiObject") then
			local h = StateValues.get(o, "Home")
			local home = if typeof(h) == "UDim2" then h else o.Position
			StateValues.set(o, "Home", home)
			o.Position = home - UDim2.fromOffset(40, 0)
			tween(o, 0.4, { Position = home })
		end
	end
	focused = nil
	for i, t in tiles do
		t.button.Position = t.home + UDim2.fromOffset(0, 36)
		StateValues.set(t.pop, "Rest", 1)
		t.pop.Scale = 1 -- they rise in without scaling (scaling makes the words shimmer)
		paintTile(t, 0)
		zoomArt(t, 1, 0)
		task.delay((i - 1) * 0.03, function()
			if isOpen then
				tween(t.button, 0.42, { Position = t.home })
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

local function updateBar()
	local elapsed = QueueState.elapsed()
	barTimer.Text = clock(elapsed)
	local mode = QueueState.label(QueueState.mode())
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
			barMode.Text = QueueState.label(QueueState.mode(), true)
		end
		return
	end
	barShown = want
	if want then
		barMode.Text = QueueState.label(QueueState.mode(), true)
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
	scrim = child(gui, "Scrim")

	local modes = child(canvas, "Modes") :: Frame
	for _, b in modes:GetChildren() do
		if b:IsA("TextButton") then
			local art = b:FindFirstChild("Art")
			local count = b:FindFirstChild("Count")
			local info = Config.MODE_BY_TILE[b.Name]
			local live = if info then info.enabled else StateValues.get(b, "Live") == true
			local t: Tile = {
				id = if info then info.id else b.Name,
				button = b,
				pop = child(b, "Pop"),
				art = if art and art:IsA("ImageLabel") and art.Visible then art else nil,
				tone = if art and art:IsA("ImageLabel")
					then art.ImageColor3
					else Color3.new(1, 1, 1),
				live = live,
				count = maybe(count, "Label") :: TextLabel?,
				dot = maybe(count, "Dot") :: Frame?,
				inQueue = maybe(b, "InQueue") :: GuiObject?,
				home = b.Position,
				levelCap = if info then info.maxLevel else nil,
				featured = info ~= nil and info.maxLevel ~= nil,
			}
			if info and live then
				-- a Studio SOON tile the config made live (Beginner 2V2)
				local soon = b:FindFirstChild("Soon")
				if soon and soon:IsA("GuiObject") then
					soon.Visible = false
				end
			end
			if t.featured then
				local sub = b:FindFirstChild("Sub")
				if sub and sub:IsA("TextLabel") then
					sub.TextColor3 = FEATURED_SUB
				end
			end
			table.insert(tiles, t)
		end
	end
	for _, t in tiles do
		local hit = hitFor(t.button)
		t.hit = hit
		hookTile(t, hit)
		setupCrop(t)
	end
	table.sort(tiles, function(a, b)
		return a.button.LayoutOrder < b.button.LayoutOrder
	end)
	resetClose = CloseButton.hook(child(canvas, "Close") :: GuiButton, function()
		Router.close()
	end)
	Plates.deepen(gui)
	Router.register("Queue", { open = open, close = close, screen = "PlayMenu" })

	searchGui = sg
	local top = child(searchGui, "Top") :: Frame
	bar = child(top, "Bar")
	barPop = child(bar, "Pop")
	local modeCircle = child(bar, "Mode") :: Frame
	barMode = child(modeCircle, "Label")
	barSpin = child(child(child(modeCircle, "Ring"), "Stroke"), "Spin")
	barSub = child(bar, "Sub")
	barTimer = child(bar, "Timer")
	bar.Visible = false
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
	StateValues.changed(player, "Level"):Connect(refreshTiles)
	refreshTiles()
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
