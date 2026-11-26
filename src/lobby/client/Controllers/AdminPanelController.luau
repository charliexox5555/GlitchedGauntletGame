--!strict
-- Owner-only interactive Admin Panel (Config/Admin.AUTHORIZED_USER_IDS).
-- Zero footprint for unauthorized players. Uses Theme tokens, ItemPortraits,
-- ItemIcons, Inventory crate art and LobbyNet.AdminRequest/AdminEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.Admin)
local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local InputMode = require(ReplicatedStorage.Shared.InputMode)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local ItemPortraits = require(ReplicatedStorage.Shared.ItemPortraits)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local SkinsConfig = require(ReplicatedStorage.Shared.Config.Skins)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local AdminPanelController = {}

local C = {
	bg = Color3.fromHex("111318"),
	surface = Color3.fromHex("181B23"),
	card = Color3.fromHex("20242F"),
	cardHover = Color3.fromHex("292E3C"),
	input = Color3.fromHex("13161D"),
	stroke = Color3.fromHex("303647"),
	strokeBright = Color3.fromHex("4B546B"),
	text = Theme.COLORS.text,
	sub = Theme.COLORS.textSecondary,
	dim = Theme.COLORS.textDim,
	gold = Theme.COLORS.gold,
	mint = Theme.COLORS.ready,
	coral = Color3.fromHex("FF5A5F"),
	sky = Color3.fromHex("3FA9FF"),
	epic = Color3.fromHex("B58CFF"),
	darkText = Theme.COLORS.onAccent,
}

local FONT_HEAVY = Theme.TEXT.key.font
local FONT_BOLD = Theme.TEXT.label.font
local FONT_MED = Theme.TEXT.bodyS.font

type SkinEntry = {
	gun: string,
	line: string,
	tier: SkinsConfig.TierId,
	tierOrder: number,
	color: Color3,
	image: string,
}

type LineSummary = {
	line: string,
	tier: SkinsConfig.TierId,
	tierOrder: number,
	color: Color3,
	count: number,
}

local function fmt(n: number): string
	local sign = if n < 0 then "-" else ""
	local s = tostring(math.abs(math.floor(n)))
	while true do
		local nextStr, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = nextStr
		if k == 0 then
			break
		end
	end
	return sign .. s
end

local function shortNum(n: number): string
	local a = math.abs(n)
	local prefix = if n > 0 then "+" elseif n < 0 then "-" else ""
	if a >= 1_000_000 then
		return prefix .. string.format("%.1fM", a / 1_000_000):gsub("%.0M$", "M")
	elseif a >= 1000 then
		return prefix .. string.format("%.1fK", a / 1000):gsub("%.0K$", "K")
	end
	return prefix .. tostring(a)
end

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function stroke(
	parent: Instance,
	color: Color3,
	thickness: number?,
	transparency: number?
): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function pad(parent: Instance, t: number, r: number, b: number, l: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t)
	p.PaddingRight = UDim.new(0, r)
	p.PaddingBottom = UDim.new(0, b)
	p.PaddingLeft = UDim.new(0, l)
	p.Parent = parent
end

local function label(props: {
	parent: Instance,
	text: string,
	size: number,
	font: Font?,
	color: Color3?,
	xAlign: Enum.TextXAlignment?,
	frameSize: UDim2?,
	pos: UDim2?,
	anchor: Vector2?,
	truncate: boolean?,
}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = props.text
	l.TextSize = props.size
	l.FontFace = props.font or FONT_MED
	l.TextColor3 = props.color or C.text
	l.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	l.Size = props.frameSize or UDim2.new(1, 0, 0, props.size + 4)
	if props.pos then
		l.Position = props.pos
	end
	if props.anchor then
		l.AnchorPoint = props.anchor
	end
	if props.truncate then
		l.TextTruncate = Enum.TextTruncate.AtEnd
	end
	l.Parent = props.parent
	return l
end

local function button(props: {
	parent: Instance,
	text: string,
	bg: Color3?,
	fg: Color3?,
	border: Color3?,
	size: UDim2?,
	textSize: number?,
	font: Font?,
	layoutOrder: number?,
	onClick: () -> (),
}): TextButton
	local bg = props.bg or C.card
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = bg
	b.Text = props.text
	b.TextColor3 = props.fg or C.text
	b.FontFace = props.font or FONT_BOLD
	b.TextSize = props.textSize or 12
	b.Size = props.size or UDim2.fromOffset(72, 30)
	b.AutoButtonColor = false
	if props.layoutOrder then
		b.LayoutOrder = props.layoutOrder
	end
	corner(b, 4)
	if props.border then
		stroke(b, props.border, 1, 0.25)
	end
	b.MouseEnter:Connect(function()
		TweenService
			:Create(
				b,
				TweenInfo.new(0.1),
				{ BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12) }
			)
			:Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = bg }):Play()
	end)
	b.Activated:Connect(props.onClick)
	b.Parent = props.parent
	return b
end

local function buildSkinCatalog(): ({ SkinEntry }, { LineSummary })
	local entries: { SkinEntry } = {}
	local byLine: { [string]: LineSummary } = {}
	local guns: { string } = {}
	for id in Weapons.list do
		table.insert(guns, id)
	end
	table.sort(guns)

	for _, gun in guns do
		for _, line in Locker.linesFor(gun) do
			if line == "Stock" then
				continue
			end
			local tier = SkinCases.tierOf(gun, line) or "Common"
			local tierDef = SkinsConfig.TIERS[tier]
			local order = if tierDef then tierDef.order else 1
			local color = if tierDef then tierDef.color else C.sub
			local img = ItemPortraits.get(gun, line) or ItemIcons.get(gun, line) or ""
			table.insert(entries, {
				gun = gun,
				line = line,
				tier = tier,
				tierOrder = order,
				color = color,
				image = img,
			})
			local ls = byLine[line]
			if not ls then
				local lineDef = SkinsConfig.LINES[line]
				local lineTier = if lineDef then lineDef.tier else tier
				local lineTierDef = SkinsConfig.TIERS[lineTier]
				ls = {
					line = line,
					tier = lineTier,
					tierOrder = if lineTierDef then lineTierDef.order else order,
					color = Locker.COLORS[line]
						or (if lineTierDef then lineTierDef.color else C.sub),
					count = 0,
				}
				byLine[line] = ls
			end
			ls.count += 1
		end
	end

	table.sort(entries, function(a, b)
		if a.tierOrder ~= b.tierOrder then
			return a.tierOrder > b.tierOrder
		end
		if a.line ~= b.line then
			return a.line < b.line
		end
		return a.gun < b.gun
	end)

	local lines: { LineSummary } = {}
	for _, ls in byLine do
		table.insert(lines, ls)
	end
	table.sort(lines, function(a, b)
		if a.tierOrder ~= b.tierOrder then
			return a.tierOrder > b.tierOrder
		end
		return a.line < b.line
	end)

	return entries, lines
end

function AdminPanelController.start()
	local localPlayer = Players.LocalPlayer
	if not AdminConfig.isAllowed(localPlayer.UserId) then
		return
	end

	local adminRequest = LobbyNet.event("AdminRequest")
	local adminEvent = LobbyNet.event("AdminEvent")
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local allSkins, allLines = buildSkinCatalog()
	local selectedPlayer: Player = localPlayer
	local activeTab = "Economy"
	local selectedLine: string? = nil
	local skinSearch = ""
	local ownedOnly = false
	local isOpen = false
	local resetArmedAt = 0
	local thumbCache: { [number]: string } = {}
	local targetConns: { RBXScriptConnection } = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanelGui"
	-- KeepGui: the match client never clears it and ArmedHideController never hides it (usable mid-match)
	gui:SetAttribute("KeepGui", true)
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Sleek corner toggle button (bottom-right in Lobby; compact top-left in Match so it avoids ammo HUD)
	-- in a match: the old Match role, or a hosted match / pad duel (PlayZone), re-placed when the zone changes
	local function inMatchNow(): boolean
		return ServerRole.isMatch() or localPlayer:GetAttribute("PlayZone") == "Match"
	end
	local inMatch = inMatchNow()
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "AdminToggle"
	local function placeToggle()
		inMatch = inMatchNow()
		local touchMatch = inMatch and (InputMode.touchCapable() or InputMode.touch())
		toggleBtn.AnchorPoint = if inMatch then Vector2.new(0, 0) else Vector2.new(1, 1)
		toggleBtn.Position = if touchMatch
			then UDim2.fromOffset(10, 82)
			elseif inMatch then UDim2.fromOffset(14, 14)
			else UDim2.new(1, -18, 1, -18)
		toggleBtn.Size = if touchMatch then UDim2.fromOffset(96, 26) else UDim2.fromOffset(126, 36)
		toggleBtn.TextSize = if touchMatch then 10 else 13
		toggleBtn.BackgroundTransparency = if inMatch then 0.25 else 0
	end
	toggleBtn.BackgroundColor3 = C.surface
	placeToggle()
	localPlayer:GetAttributeChangedSignal("PlayZone"):Connect(placeToggle)
	InputMode.changed:Connect(placeToggle)
	toggleBtn.Text = "ADMIN [F8]"
	toggleBtn.TextColor3 = C.gold
	toggleBtn.FontFace = FONT_HEAVY
	toggleBtn.AutoButtonColor = false
	corner(toggleBtn, 5)
	stroke(toggleBtn, C.gold, 1.5, 0.15)
	toggleBtn.Parent = gui

	-- Backdrop scrim (blocks clicks behind panel and unlocks first-person mouse via Modal while open)
	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0.55
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Modal = true
	scrim.Visible = false
	scrim.Parent = gui

	-- Main Window
	local win = Instance.new("Frame")
	win.Name = "Window"
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromOffset(920, 620)
	win.BackgroundColor3 = C.bg
	win.Visible = false
	win.Parent = gui
	corner(win, 6)
	stroke(win, C.strokeBright, 1.5, 0.1)

	local winScale = Instance.new("UIScale")
	winScale.Scale = 1
	winScale.Parent = win

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(640, 440)
	sizeConstraint.MaxSize = Vector2.new(960, 660)
	sizeConstraint.Parent = win

	-- Header Bar (draggable)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 46)
	header.BackgroundColor3 = C.surface
	header.BorderSizePixel = 0
	header.Parent = win
	corner(header, 6)

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(0, 4, 1, -14)
	headerBar.Position = UDim2.fromOffset(12, 7)
	headerBar.BackgroundColor3 = C.gold
	headerBar.BorderSizePixel = 0
	headerBar.Parent = header

	label({
		parent = header,
		text = "ADMIN CONSOLE",
		size = 17,
		font = FONT_HEAVY,
		color = C.text,
		frameSize = UDim2.fromOffset(190, 22),
		pos = UDim2.fromOffset(26, 6),
	})
	label({
		parent = header,
		text = "OWNER · ID 284035946",
		size = 11,
		font = FONT_BOLD,
		color = C.gold,
		frameSize = UDim2.fromOffset(190, 14),
		pos = UDim2.fromOffset(26, 26),
	})

	local headerTargetBadge = label({
		parent = header,
		text = "TARGET: " .. localPlayer.DisplayName,
		size = 12,
		font = FONT_BOLD,
		color = C.mint,
		xAlign = Enum.TextXAlignment.Right,
		frameSize = UDim2.new(0, 280, 0, 20),
		pos = UDim2.new(1, -56, 0.5, -10),
		anchor = Vector2.new(1, 0),
		truncate = true,
	})

	-- Drag support on header
	do
		local dragging = false
		local dragStart = Vector2.zero
		local startPos = win.Position
		header.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
				startPos = win.Position
			end
		end)
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
				win.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	end

	-- Player Roster Bar
	local rosterWrap = Instance.new("Frame")
	rosterWrap.Name = "Roster"
	rosterWrap.Position = UDim2.fromOffset(12, 54)
	rosterWrap.Size = UDim2.new(1, -24, 0, 56)
	rosterWrap.BackgroundColor3 = C.surface
	rosterWrap.Parent = win
	corner(rosterWrap, 5)
	stroke(rosterWrap, C.stroke, 1, 0.2)

	local rosterScroll = Instance.new("ScrollingFrame")
	rosterScroll.Size = UDim2.fromScale(1, 1)
	rosterScroll.BackgroundTransparency = 1
	rosterScroll.BorderSizePixel = 0
	rosterScroll.ScrollBarThickness = 3
	rosterScroll.ScrollingDirection = Enum.ScrollingDirection.X
	rosterScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	rosterScroll.CanvasSize = UDim2.fromOffset(0, 0)
	rosterScroll.Parent = rosterWrap
	pad(rosterScroll, 6, 8, 6, 8)
	local rosterLayout = Instance.new("UIListLayout")
	rosterLayout.FillDirection = Enum.FillDirection.Horizontal
	rosterLayout.Padding = UDim.new(0, 8)
	rosterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rosterLayout.Parent = rosterScroll

	-- Live Target Summary Ribbon
	local statsRibbon = Instance.new("Frame")
	statsRibbon.Name = "StatsRibbon"
	statsRibbon.Position = UDim2.fromOffset(12, 118)
	statsRibbon.Size = UDim2.new(1, -24, 0, 44)
	statsRibbon.BackgroundColor3 = C.surface
	statsRibbon.Parent = win
	corner(statsRibbon, 5)
	stroke(statsRibbon, C.stroke, 1, 0.2)
	pad(statsRibbon, 6, 10, 6, 10)

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.Padding = UDim.new(0, 10)
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statsLayout.Parent = statsRibbon

	local function makeStatBox(
		titleText: string,
		accent: Color3,
		widthScale: number
	): (TextLabel, Frame?)
		local box = Instance.new("Frame")
		box.Size = UDim2.new(widthScale, -8, 1, 0)
		box.BackgroundColor3 = C.card
		box.Parent = statsRibbon
		corner(box, 4)
		pad(box, 3, 8, 3, 8)
		label({
			parent = box,
			text = titleText,
			size = 10,
			font = FONT_BOLD,
			color = C.dim,
			frameSize = UDim2.new(1, 0, 0, 12),
		})
		local val = label({
			parent = box,
			text = "—",
			size = 14,
			font = FONT_HEAVY,
			color = accent,
			frameSize = UDim2.new(1, 0, 0, 16),
			pos = UDim2.fromOffset(0, 12),
			truncate = true,
		})
		return val, box
	end

	local statCoins = makeStatBox("COINS", C.gold, 0.20)
	local statTickets = makeStatBox("TICKETS", C.sky, 0.16)
	local statLevel = makeStatBox("LEVEL / XP", C.mint, 0.24)
	local statStreak = makeStatBox("STREAK · W / K", C.coral, 0.20)
	local statOwned = makeStatBox("SKINS · CASES", C.epic, 0.20)

	-- Tab Bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Position = UDim2.fromOffset(12, 170)
	tabBar.Size = UDim2.new(1, -24, 0, 34)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = win

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	-- Tab Content Container
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(12, 212)
	body.Size = UDim2.new(1, -24, 1, -256)
	body.BackgroundColor3 = C.surface
	body.ClipsDescendants = true
	body.Parent = win
	corner(body, 5)
	stroke(body, C.stroke, 1, 0.2)

	-- Toast Status Footer
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Position = UDim2.new(0, 12, 1, -38)
	footer.Size = UDim2.new(1, -24, 0, 28)
	footer.BackgroundColor3 = C.surface
	footer.Parent = win
	corner(footer, 4)
	stroke(footer, C.stroke, 1, 0.25)

	local toastLabel = label({
		parent = footer,
		text = "Ready · Select a player above to edit coins, skins, cases or progression.",
		size = 12,
		font = FONT_MED,
		color = C.sub,
		frameSize = UDim2.new(1, -20, 1, 0),
		pos = UDim2.fromOffset(10, 0),
		truncate = true,
	})

	local function showToast(ok: boolean, text: string)
		toastLabel.Text = (if ok then "[OK]  " else "[ERR]  ") .. text
		toastLabel.TextColor3 = if ok then C.mint else C.coral
		footer.BackgroundColor3 = (if ok then C.mint else C.coral):Lerp(C.surface, 0.85)
		TweenService:Create(footer, TweenInfo.new(0.45), { BackgroundColor3 = C.surface }):Play()
	end

	local function send(action: string, payload: { [string]: any }?)
		if not selectedPlayer or not selectedPlayer.Parent then
			showToast(false, "Selected player is no longer in this server")
			return
		end
		adminRequest:FireServer(action, selectedPlayer.UserId, payload or {})
	end

	-- Forward declarations for live refresh callbacks
	local refreshAll: () -> ()
	local refreshSkinsView: () -> ()
	local refreshCasesView: () -> ()
	local refreshRoster: () -> ()
	local refreshBotsView: () -> () = function() end
	local setOpen: (boolean) -> ()

	adminEvent.OnClientEvent:Connect(function(data: LobbyNet.AdminEventPayload)
		if typeof(data) == "table" then
			showToast(data.ok == true, tostring(data.text or ""))
			if
				data.ok == true
				and data.targetUserId == localPlayer.UserId
				and (data.action == "startOnboarding" or data.action == "testFreeCase")
			then
				setOpen(false)
			end
		end
	end)

	setOpen = function(open: boolean)
		isOpen = open
		scrim.Visible = open
		if open then
			win.Visible = true
			winScale.Scale = 0.94
			TweenService:Create(
				winScale,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
			refreshRoster()
			refreshAll()
		else
			win.Visible = false
		end
	end

	button({
		parent = header,
		text = "X",
		bg = C.card,
		fg = C.sub,
		border = C.stroke,
		size = UDim2.fromOffset(30, 30),
		textSize = 14,
		font = FONT_HEAVY,
		onClick = function()
			setOpen(false)
		end,
	}).Position =
		UDim2.new(1, -38, 0.5, -15)

	scrim.Activated:Connect(function()
		setOpen(false)
	end)

	-- =========================================================================
	-- TAB PAGES
	-- =========================================================================
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: { btn: TextButton, bar: Frame } } = {}

	local function makePage(name: string): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		f.Visible = false
		f.Parent = body
		pages[name] = f
		return f
	end

	local function switchTab(name: string)
		activeTab = name
		for k, page in pages do
			page.Visible = k == name
		end
		for k, tb in tabButtons do
			local on = k == name
			tb.btn.BackgroundColor3 = if on then C.card else C.surface
			tb.btn.TextColor3 = if on then C.text else C.sub
			tb.bar.Visible = on
		end
		if name == "Skins" then
			refreshSkinsView()
		elseif name == "Cases" then
			refreshCasesView()
		elseif name == "Bots" then
			refreshBotsView()
		end
	end

	for idx, spec in
		{
			{ id = "Economy", title = "ECONOMY & XP", accent = C.gold },
			{ id = "Skins", title = "GUN & KNIFE SKINS", accent = C.epic },
			{ id = "Cases", title = "CASES & CRATES", accent = C.sky },
			{ id = "Utilities", title = "UTILITIES & RESET", accent = C.coral },
			{ id = "Bots", title = "MATCH BOTS", accent = C.mint },
		}
	do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. spec.id
		b.LayoutOrder = idx
		b.Size = UDim2.fromOffset(172, 34)
		b.BackgroundColor3 = C.surface
		b.Text = spec.title
		b.TextColor3 = C.sub
		b.FontFace = FONT_HEAVY
		b.TextSize = 12
		b.AutoButtonColor = false
		corner(b, 4)
		stroke(b, C.stroke, 1, 0.25)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, -12, 0, 3)
		bar.Position = UDim2.new(0, 6, 1, -3)
		bar.BackgroundColor3 = spec.accent
		bar.BorderSizePixel = 0
		bar.Visible = false
		bar.Parent = b
		b.Activated:Connect(function()
			switchTab(spec.id)
		end)
		b.Parent = tabBar
		tabButtons[spec.id] = { btn = b, bar = bar }
	end

	-- =========================================================================
	-- TAB 1: ECONOMY & PROGRESSION
	-- =========================================================================
	local econPage = makePage("Economy")
	pad(econPage, 12, 12, 12, 12)
	local econGrid = Instance.new("UIGridLayout")
	econGrid.CellSize = UDim2.new(0.5, -6, 0.5, -6)
	econGrid.CellPadding = UDim2.fromOffset(12, 12)
	econGrid.SortOrder = Enum.SortOrder.LayoutOrder
	econGrid.Parent = econPage

	local function makeSectionCard(
		parent: Instance,
		titleText: string,
		accent: Color3,
		order: number
	): Frame
		local card = Instance.new("Frame")
		card.LayoutOrder = order
		card.BackgroundColor3 = C.card
		card.Parent = parent
		corner(card, 5)
		stroke(card, C.stroke, 1, 0.15)
		pad(card, 10, 12, 10, 12)

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 3, 0, 16)
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel = 0
		bar.Parent = card

		label({
			parent = card,
			text = titleText,
			size = 13,
			font = FONT_HEAVY,
			color = C.text,
			frameSize = UDim2.new(1, -14, 0, 18),
			pos = UDim2.fromOffset(10, -1),
		})
		return card
	end

	local function makePresetRow(
		parent: Instance,
		y: number,
		presets: { number },
		accent: Color3,
		suffix: string,
		onPick: (n: number) -> ()
	)
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundTransparency = 1
		row.Parent = parent
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, 6)
		l.Parent = row
		for i, n in presets do
			local neg = n < 0
			button({
				parent = row,
				text = shortNum(n) .. suffix,
				bg = if neg then Color3.fromHex("2E1C20") else C.surface,
				fg = if neg then C.coral else accent,
				border = if neg then C.coral else C.strokeBright,
				size = UDim2.new(1 / #presets, -5, 1, 0),
				textSize = 11,
				font = FONT_HEAVY,
				layoutOrder = i,
				onClick = function()
					onPick(n)
				end,
			})
		end
	end

	local function makeInputRow(
		parent: Instance,
		y: number,
		placeholder: string,
		actions: { { label: string, color: Color3, fn: (num: number?) -> () } }
	)
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.Parent = parent

		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -(#actions * 66 + 4), 1, 0)
		box.BackgroundColor3 = C.input
		box.Text = ""
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = C.dim
		box.TextColor3 = C.text
		box.FontFace = FONT_BOLD
		box.TextSize = 13
		box.ClearTextOnFocus = false
		box.TextXAlignment = Enum.TextXAlignment.Left
		corner(box, 4)
		stroke(box, C.stroke, 1, 0.1)
		pad(box, 0, 8, 0, 8)
		box.Parent = row

		for i, act in actions do
			local b = button({
				parent = row,
				text = act.label,
				bg = act.color,
				fg = C.darkText,
				size = UDim2.fromOffset(60, 34),
				textSize = 11,
				font = FONT_HEAVY,
				onClick = function()
					local v = tonumber(box.Text)
					act.fn(v)
				end,
			})
			b.Position = UDim2.new(1, -((#actions - i + 1) * 66 - 6), 0, 0)
		end
	end

	-- Card 1: Coins
	local coinsCard = makeSectionCard(econPage, "COINS WALLET", C.gold, 1)
	label({
		parent = coinsCard,
		text = "Quick grant/deduct or set exact balance (0 .. 10,000,000)",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 22),
	})
	makePresetRow(coinsCard, 46, AdminConfig.COIN_PRESETS, C.gold, "", function(n)
		send("addCoins", { amount = n })
	end)
	makeInputRow(coinsCard, 92, "Custom coins...", {
		{
			label = "ADD",
			color = C.gold,
			fn = function(v)
				if v then
					send("addCoins", { amount = v })
				else
					showToast(false, "Enter a number for coins")
				end
			end,
		},
		{
			label = "SET",
			color = C.mint,
			fn = function(v)
				if v then
					send("setCoins", { amount = v })
				else
					showToast(false, "Enter a number for coins")
				end
			end,
		},
		{
			label = "ZERO",
			color = C.coral,
			fn = function()
				send("setCoins", { amount = 0 })
			end,
		},
	})

	-- Card 2: Tickets
	local ticketsCard = makeSectionCard(econPage, "CASE TICKETS", C.sky, 2)
	label({
		parent = ticketsCard,
		text = "Earn-only currency used to buy Standard / Elite / Apex / Knife cases",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 22),
	})
	makePresetRow(ticketsCard, 46, AdminConfig.TICKET_PRESETS, C.sky, "", function(n)
		send("addTickets", { amount = n })
	end)
	makeInputRow(ticketsCard, 92, "Custom tickets...", {
		{
			label = "ADD",
			color = C.sky,
			fn = function(v)
				if v then
					send("addTickets", { amount = v })
				else
					showToast(false, "Enter a number for tickets")
				end
			end,
		},
		{
			label = "SET",
			color = C.mint,
			fn = function(v)
				if v then
					send("setTickets", { amount = v })
				else
					showToast(false, "Enter a number for tickets")
				end
			end,
		},
		{
			label = "ZERO",
			color = C.coral,
			fn = function()
				send("setTickets", { amount = 0 })
			end,
		},
	})

	-- Card 3: Level & XP
	local levelCard = makeSectionCard(econPage, "LEVEL & XP", C.mint, 3)
	makePresetRow(levelCard, 26, AdminConfig.LEVEL_PRESETS, C.mint, " LVL", function(n)
		send("addLevel", { amount = n })
	end)
	makePresetRow(levelCard, 66, AdminConfig.XP_PRESETS, C.sky, " XP", function(n)
		send("addXp", { amount = n })
	end)
	makeInputRow(levelCard, 108, "Level or XP amount...", {
		{
			label = "SET LVL",
			color = C.mint,
			fn = function(v)
				if v then
					send("setLevel", { amount = v })
				else
					showToast(false, "Enter a level (1+)")
				end
			end,
		},
		{
			label = "+XP",
			color = C.sky,
			fn = function(v)
				if v then
					send("addXp", { amount = v })
				else
					showToast(false, "Enter an XP amount")
				end
			end,
		},
	})

	-- Card 4: Streak & Profile Stats
	local statsCard = makeSectionCard(econPage, "WIN STREAK & PROFILE STATS", C.coral, 4)
	label({
		parent = statsCard,
		text = "Adjust win streak, wins and career kills on target player's profile",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 22),
	})
	makePresetRow(statsCard, 46, { 1, 5, 10, 25, -1 }, C.coral, " STR", function(n)
		send("addStreak", { amount = n })
	end)
	local statActionRow = Instance.new("Frame")
	statActionRow.Position = UDim2.fromOffset(0, 92)
	statActionRow.Size = UDim2.new(1, 0, 0, 34)
	statActionRow.BackgroundTransparency = 1
	statActionRow.Parent = statsCard
	local statRowLayout = Instance.new("UIListLayout")
	statRowLayout.FillDirection = Enum.FillDirection.Horizontal
	statRowLayout.Padding = UDim.new(0, 8)
	statRowLayout.Parent = statActionRow
	button({
		parent = statActionRow,
		text = "RESET STREAK",
		bg = Color3.fromHex("2E1C20"),
		fg = C.coral,
		border = C.coral,
		size = UDim2.new(0.34, -5, 1, 0),
		textSize = 11,
		onClick = function()
			send("setStreak", { amount = 0 })
		end,
	})
	button({
		parent = statActionRow,
		text = "+10 WINS",
		bg = C.surface,
		fg = C.mint,
		border = C.strokeBright,
		size = UDim2.new(0.33, -5, 1, 0),
		textSize = 11,
		onClick = function()
			send("addStats", { wins = 10, kills = 0 })
		end,
	})
	button({
		parent = statActionRow,
		text = "+50 KILLS",
		bg = C.surface,
		fg = C.gold,
		border = C.strokeBright,
		size = UDim2.new(0.33, -5, 1, 0),
		textSize = 11,
		onClick = function()
			send("addStats", { wins = 0, kills = 50 })
		end,
	})

	-- =========================================================================
	-- TAB 2: GUN & KNIFE SKINS BROWSER
	-- =========================================================================
	local skinsPage = makePage("Skins")
	pad(skinsPage, 10, 10, 10, 10)

	-- Left Line Filter Sidebar
	local lineList = Instance.new("ScrollingFrame")
	lineList.Name = "LineList"
	lineList.Size = UDim2.new(0, 194, 1, 0)
	lineList.BackgroundColor3 = C.bg
	lineList.BorderSizePixel = 0
	lineList.ScrollBarThickness = 4
	lineList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lineList.CanvasSize = UDim2.fromOffset(0, 0)
	lineList.Parent = skinsPage
	corner(lineList, 4)
	stroke(lineList, C.stroke, 1, 0.2)
	pad(lineList, 6, 6, 6, 6)
	local lineLayout = Instance.new("UIListLayout")
	lineLayout.Padding = UDim.new(0, 4)
	lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lineLayout.Parent = lineList

	-- Right Skin Grid Area
	local skinRight = Instance.new("Frame")
	skinRight.Position = UDim2.fromOffset(204, 0)
	skinRight.Size = UDim2.new(1, -204, 1, 0)
	skinRight.BackgroundTransparency = 1
	skinRight.Parent = skinsPage

	-- Top Toolbar
	local skinBar = Instance.new("Frame")
	skinBar.Size = UDim2.new(1, 0, 0, 34)
	skinBar.BackgroundTransparency = 1
	skinBar.Parent = skinRight

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -330, 1, 0)
	searchBox.BackgroundColor3 = C.input
	searchBox.Text = ""
	searchBox.PlaceholderText = "Search weapon or line..."
	searchBox.PlaceholderColor3 = C.dim
	searchBox.TextColor3 = C.text
	searchBox.FontFace = FONT_MED
	searchBox.TextSize = 12
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	corner(searchBox, 4)
	stroke(searchBox, C.stroke, 1, 0.1)
	pad(searchBox, 0, 8, 0, 8)
	searchBox.Parent = skinBar

	local ownedFilterBtn = button({
		parent = skinBar,
		text = "OWNED ONLY",
		bg = C.card,
		fg = C.sub,
		border = C.stroke,
		size = UDim2.fromOffset(92, 34),
		textSize = 11,
		onClick = function()
			ownedOnly = not ownedOnly
			refreshSkinsView()
		end,
	})
	ownedFilterBtn.Position = UDim2.new(1, -322, 0, 0)

	local grantScopeBtn = button({
		parent = skinBar,
		text = "+ GRANT ALL",
		bg = C.mint,
		fg = C.darkText,
		size = UDim2.fromOffset(108, 34),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			if selectedLine then
				send("grantLine", { line = selectedLine })
			else
				send("grantAllSkins")
			end
		end,
	})
	grantScopeBtn.Position = UDim2.new(1, -222, 0, 0)

	local removeScopeBtn = button({
		parent = skinBar,
		text = "- CLEAR ALL",
		bg = Color3.fromHex("2E1C20"),
		fg = C.coral,
		border = C.coral,
		size = UDim2.fromOffset(106, 34),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			if selectedLine then
				send("removeLine", { line = selectedLine })
			else
				send("clearAllSkins")
			end
		end,
	})
	removeScopeBtn.Position = UDim2.new(1, -106, 0, 0)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		skinSearch = string.lower(searchBox.Text)
		refreshSkinsView()
	end)

	local skinScroll = Instance.new("ScrollingFrame")
	skinScroll.Position = UDim2.fromOffset(0, 42)
	skinScroll.Size = UDim2.new(1, 0, 1, -42)
	skinScroll.BackgroundColor3 = C.bg
	skinScroll.BorderSizePixel = 0
	skinScroll.ScrollBarThickness = 5
	skinScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	skinScroll.CanvasSize = UDim2.fromOffset(0, 0)
	skinScroll.Parent = skinRight
	corner(skinScroll, 4)
	stroke(skinScroll, C.stroke, 1, 0.2)
	pad(skinScroll, 8, 8, 8, 8)

	local skinGrid = Instance.new("UIGridLayout")
	skinGrid.CellSize = UDim2.new(0.333, -6, 0, 114)
	skinGrid.CellPadding = UDim2.fromOffset(8, 8)
	skinGrid.SortOrder = Enum.SortOrder.LayoutOrder
	skinGrid.Parent = skinScroll

	-- Build reusable line sidebar buttons
	type LineRowRef = { btn: TextButton, countLbl: TextLabel, line: string? }
	local lineRows: { LineRowRef } = {}

	local function createLineRow(
		order: number,
		lineName: string?,
		titleText: string,
		swatch: Color3
	)
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, 30)
		b.BackgroundColor3 = C.card
		b.Text = ""
		b.AutoButtonColor = false
		corner(b, 4)
		b.Parent = lineList

		local sw = Instance.new("Frame")
		sw.Size = UDim2.new(0, 4, 1, -8)
		sw.Position = UDim2.fromOffset(4, 4)
		sw.BackgroundColor3 = swatch
		sw.BorderSizePixel = 0
		sw.Parent = b

		label({
			parent = b,
			text = titleText,
			size = 11,
			font = FONT_BOLD,
			color = C.text,
			frameSize = UDim2.new(1, -56, 1, 0),
			pos = UDim2.fromOffset(14, 0),
			truncate = true,
		})
		local cnt = label({
			parent = b,
			text = "0/0",
			size = 11,
			font = FONT_BOLD,
			color = C.sub,
			xAlign = Enum.TextXAlignment.Right,
			frameSize = UDim2.new(0, 40, 1, 0),
			pos = UDim2.new(1, -46, 0, 0),
		})
		b.Activated:Connect(function()
			selectedLine = lineName
			refreshSkinsView()
		end)
		table.insert(lineRows, { btn = b, countLbl = cnt, line = lineName })
	end

	createLineRow(0, nil, "ALL SKIN LINES", C.gold)
	for i, ls in allLines do
		createLineRow(i, ls.line, string.upper(ls.line), ls.color)
	end

	-- Pre-build skin cards once and simply filter/update their owned state!
	type SkinCardRef = {
		entry: SkinEntry,
		btn: TextButton,
		border: UIStroke,
		badge: TextLabel,
	}
	local skinCards: { SkinCardRef } = {}
	for i, entry in allSkins do
		local card = Instance.new("TextButton")
		card.Name = entry.gun .. "_" .. entry.line
		card.LayoutOrder = i
		card.BackgroundColor3 = C.card
		card.Text = ""
		card.AutoButtonColor = false
		corner(card, 5)
		local brd = stroke(card, C.stroke, 1, 0.2)
		card.Parent = skinScroll

		local tierBar = Instance.new("Frame")
		tierBar.Size = UDim2.new(1, 0, 0, 3)
		tierBar.BackgroundColor3 = entry.color
		tierBar.BorderSizePixel = 0
		tierBar.Parent = card

		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Position = UDim2.fromOffset(8, 10)
		img.Size = UDim2.new(1, -16, 0, 62)
		img.Image = entry.image
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = card

		label({
			parent = card,
			text = string.upper(Weapons.nameOf(entry.gun)),
			size = 12,
			font = FONT_HEAVY,
			color = C.text,
			frameSize = UDim2.new(1, -14, 0, 14),
			pos = UDim2.fromOffset(8, 76),
			truncate = true,
		})
		label({
			parent = card,
			text = entry.line,
			size = 11,
			font = FONT_MED,
			color = entry.color,
			frameSize = UDim2.new(1, -70, 0, 14),
			pos = UDim2.fromOffset(8, 92),
			truncate = true,
		})

		local badge = Instance.new("TextLabel")
		badge.AnchorPoint = Vector2.new(1, 1)
		badge.Position = UDim2.new(1, -6, 1, -6)
		badge.Size = UDim2.fromOffset(58, 18)
		badge.BackgroundColor3 = C.surface
		badge.Text = "LOCKED"
		badge.TextColor3 = C.dim
		badge.FontFace = FONT_HEAVY
		badge.TextSize = 10
		corner(badge, 3)
		badge.Parent = card

		card.Activated:Connect(function()
			local owned = PlayerData.owns(PlayerData.skins(selectedPlayer), entry.gun, entry.line)
			if owned then
				send("removeSkin", { gun = entry.gun, line = entry.line })
			else
				send("grantSkin", { gun = entry.gun, line = entry.line })
			end
		end)

		table.insert(skinCards, {
			entry = entry,
			btn = card,
			border = brd,
			badge = badge,
		})
	end

	-- =========================================================================
	-- TAB 3: CASES & CRATES
	-- =========================================================================
	local casesPage = makePage("Cases")
	pad(casesPage, 12, 12, 12, 12)

	local caseTop = Instance.new("Frame")
	caseTop.Size = UDim2.new(1, 0, 0, 34)
	caseTop.BackgroundTransparency = 1
	caseTop.Parent = casesPage
	local caseTopLayout = Instance.new("UIListLayout")
	caseTopLayout.FillDirection = Enum.FillDirection.Horizontal
	caseTopLayout.Padding = UDim.new(0, 8)
	caseTopLayout.Parent = caseTop

	for i, spec in
		{
			{
				text = "+1 ALL CASES",
				bg = C.mint,
				fg = C.darkText,
				fn = function()
					send("addAllCases", { amount = 1 })
				end,
			},
			{
				text = "+5 ALL CASES",
				bg = C.sky,
				fg = C.darkText,
				fn = function()
					send("addAllCases", { amount = 5 })
				end,
			},
			{
				text = "+10 ALL CASES",
				bg = C.gold,
				fg = C.darkText,
				fn = function()
					send("addAllCases", { amount = 10 })
				end,
			},
			{
				text = "CLEAR ALL CASES",
				bg = Color3.fromHex("2E1C20"),
				fg = C.coral,
				border = C.coral,
				fn = function()
					send("clearItems")
				end,
			},
		}
	do
		button({
			parent = caseTop,
			text = spec.text,
			bg = spec.bg,
			fg = spec.fg,
			border = spec.border,
			size = UDim2.new(0.25, -6, 1, 0),
			textSize = 11,
			font = FONT_HEAVY,
			layoutOrder = i,
			onClick = spec.fn,
		})
	end

	local caseGridWrap = Instance.new("Frame")
	caseGridWrap.Position = UDim2.fromOffset(0, 46)
	caseGridWrap.Size = UDim2.new(1, 0, 1, -46)
	caseGridWrap.BackgroundTransparency = 1
	caseGridWrap.Parent = casesPage

	local caseGrid = Instance.new("UIGridLayout")
	caseGrid.CellSize = UDim2.new(0.5, -6, 0.5, -6)
	caseGrid.CellPadding = UDim2.fromOffset(12, 12)
	caseGrid.SortOrder = Enum.SortOrder.LayoutOrder
	caseGrid.Parent = caseGridWrap

	local caseDefs: { Inventory.ItemDef } = {}
	for _, def in Inventory.ITEMS do
		if def.kind == "Case" and not def.retired then
			table.insert(caseDefs, def)
		end
	end
	table.sort(caseDefs, function(a, b)
		return a.tier < b.tier
	end)

	local caseTierColors = { C.sub, C.sky, C.epic, C.gold }
	local caseCountLabels: { [string]: TextLabel } = {}

	for idx, def in caseDefs do
		local accent = caseTierColors[def.tier] or C.gold
		local card = Instance.new("Frame")
		card.LayoutOrder = idx
		card.BackgroundColor3 = C.card
		card.Parent = caseGridWrap
		corner(card, 5)
		stroke(card, accent, 1, 0.45)
		pad(card, 10, 12, 10, 12)

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(66, 66)
		icon.Position = UDim2.fromOffset(0, 2)
		icon.BackgroundTransparency = 1
		icon.Image = def.icon or ""
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = card

		label({
			parent = card,
			text = def.name,
			size = 14,
			font = FONT_HEAVY,
			color = accent,
			frameSize = UDim2.new(1, -78, 0, 18),
			pos = UDim2.fromOffset(78, 6),
		})
		local heldLbl = label({
			parent = card,
			text = "HELD: 0",
			size = 18,
			font = FONT_HEAVY,
			color = C.text,
			frameSize = UDim2.new(1, -78, 0, 24),
			pos = UDim2.fromOffset(78, 28),
		})
		caseCountLabels[def.id] = heldLbl

		local btnRow = Instance.new("Frame")
		btnRow.Position = UDim2.new(0, 0, 1, -34)
		btnRow.Size = UDim2.new(1, 0, 0, 32)
		btnRow.BackgroundTransparency = 1
		btnRow.Parent = card
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.Padding = UDim.new(0, 6)
		rl.Parent = btnRow

		for bi, delta in AdminConfig.CASE_PRESETS do
			local neg = delta < 0
			button({
				parent = btnRow,
				text = shortNum(delta),
				bg = if neg then Color3.fromHex("2E1C20") else C.surface,
				fg = if neg then C.coral else accent,
				border = if neg then C.coral else C.strokeBright,
				size = UDim2.new(1 / (#AdminConfig.CASE_PRESETS + 1), -5, 1, 0),
				textSize = 12,
				font = FONT_HEAVY,
				layoutOrder = bi,
				onClick = function()
					send("addItem", { itemId = def.id, amount = delta })
				end,
			})
		end
		button({
			parent = btnRow,
			text = "ZERO",
			bg = Color3.fromHex("2E1C20"),
			fg = C.coral,
			border = C.coral,
			size = UDim2.new(1 / (#AdminConfig.CASE_PRESETS + 1), -5, 1, 0),
			textSize = 10,
			font = FONT_HEAVY,
			layoutOrder = 99,
			onClick = function()
				send("setItem", { itemId = def.id, amount = 0 })
			end,
		})
	end

	-- =========================================================================
	-- TAB 4: UTILITIES & DANGER ZONE
	-- =========================================================================
	local utilPage = makePage("Utilities")
	pad(utilPage, 12, 12, 12, 12)
	local utilGrid = Instance.new("UIGridLayout")
	utilGrid.CellSize = UDim2.new(0.5, -6, 0.5, -6)
	utilGrid.CellPadding = UDim2.fromOffset(12, 12)
	utilGrid.SortOrder = Enum.SortOrder.LayoutOrder
	utilGrid.Parent = utilPage

	local dailyCard = makeSectionCard(utilPage, "DAILY SHOP CONTROLS", C.sky, 1)
	label({
		parent = dailyCard,
		text = "Force a fresh daily shop roll or re-enable the free daily skin & slots.",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 24),
	})
	local dailyRow = Instance.new("Frame")
	dailyRow.Position = UDim2.fromOffset(0, 62)
	dailyRow.Size = UDim2.new(1, 0, 0, 36)
	dailyRow.BackgroundTransparency = 1
	dailyRow.Parent = dailyCard
	local dl = Instance.new("UIListLayout")
	dl.FillDirection = Enum.FillDirection.Horizontal
	dl.Padding = UDim.new(0, 8)
	dl.Parent = dailyRow
	button({
		parent = dailyRow,
		text = "REROLL DAILY",
		bg = C.sky,
		fg = C.darkText,
		size = UDim2.new(0.5, -4, 1, 0),
		font = FONT_HEAVY,
		onClick = function()
			send("rerollDaily")
		end,
	})
	button({
		parent = dailyRow,
		text = "RESET FREE & SLOTS",
		bg = C.surface,
		fg = C.mint,
		border = C.mint,
		size = UDim2.new(0.5, -4, 1, 0),
		font = FONT_HEAVY,
		onClick = function()
			send("resetDailyFree")
		end,
	})

	local flagsCard = makeSectionCard(utilPage, "LOGIN & BUNDLE FLAGS", C.gold, 2)
	label({
		parent = flagsCard,
		text = "Unlock today's 7-day login claim or toggle Starter Bundle ownership.",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 24),
	})
	local flagsRow = Instance.new("Frame")
	flagsRow.Position = UDim2.fromOffset(0, 62)
	flagsRow.Size = UDim2.new(1, 0, 0, 36)
	flagsRow.BackgroundTransparency = 1
	flagsRow.Parent = flagsCard
	local fl = Instance.new("UIListLayout")
	fl.FillDirection = Enum.FillDirection.Horizontal
	fl.Padding = UDim.new(0, 8)
	fl.Parent = flagsRow
	button({
		parent = flagsRow,
		text = "UNLOCK LOGIN",
		bg = C.gold,
		fg = C.darkText,
		size = UDim2.new(0.36, -5, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("resetLogin")
		end,
	})
	button({
		parent = flagsRow,
		text = "STARTER: ON",
		bg = C.surface,
		fg = C.mint,
		border = C.strokeBright,
		size = UDim2.new(0.32, -5, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("toggleStarter", { flag = true })
		end,
	})
	button({
		parent = flagsRow,
		text = "STARTER: OFF",
		bg = C.surface,
		fg = C.sub,
		border = C.strokeBright,
		size = UDim2.new(0.32, -5, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("toggleStarter", { flag = false })
		end,
	})

	local tasksCard = makeSectionCard(utilPage, "TASK PATH", C.mint, 2)
	label({
		parent = tasksCard,
		text = "Skip the showing part (no rewards) or start the Path again at Recruit.",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 24),
	})
	local tasksRow = Instance.new("Frame")
	tasksRow.Position = UDim2.fromOffset(0, 62)
	tasksRow.Size = UDim2.new(1, 0, 0, 36)
	tasksRow.BackgroundTransparency = 1
	tasksRow.Parent = tasksCard
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 8)
	tl.Parent = tasksRow
	button({
		parent = tasksRow,
		text = "SKIP PART",
		bg = C.surface,
		fg = C.mint,
		border = C.strokeBright,
		size = UDim2.new(0.48, -5, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("taskSkip")
		end,
	})
	button({
		parent = tasksRow,
		text = "RESET PATH",
		bg = C.surface,
		fg = C.sub,
		border = C.strokeBright,
		size = UDim2.new(0.48, -5, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("taskReset")
		end,
	})

	local dangerCard = makeSectionCard(utilPage, "DANGER ZONE · FULL PROFILE WIPE", C.coral, 3)
	label({
		parent = dangerCard,
		text = "Resets coins, tickets, cases, skins and level back to a brand-new save.",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 24),
	})
	local resetBtn: TextButton
	resetBtn = button({
		parent = dangerCard,
		text = "RESET TARGET SAVE (CLICK TWICE)",
		bg = Color3.fromHex("361A1F"),
		fg = C.coral,
		border = C.coral,
		size = UDim2.new(1, 0, 0, 38),
		textSize = 12,
		font = FONT_HEAVY,
		onClick = function()
			local now = os.clock()
			if now - resetArmedAt <= 4 then
				resetArmedAt = 0
				resetBtn.Text = "RESET TARGET SAVE (CLICK TWICE)"
				resetBtn.BackgroundColor3 = Color3.fromHex("361A1F")
				send("resetProfile")
			else
				resetArmedAt = now
				resetBtn.Text = "CONFIRM WIPE FOR "
					.. string.upper(selectedPlayer.DisplayName)
					.. "?"
				resetBtn.BackgroundColor3 = Color3.fromHex("6B1B24")
				showToast(false, "Click again within 4s to confirm full save wipe")
			end
		end,
	})
	resetBtn.Position = UDim2.fromOffset(0, 62)

	local onbCard = makeSectionCard(utilPage, "QUICK MATCH & ONBOARDING", C.mint, 4)
	label({
		parent = onbCard,
		text = "Launch an instant in-lobby bot match (no save wipe) or test onboarding.",
		size = 11,
		color = C.sub,
		pos = UDim2.fromOffset(0, 22),
		truncate = true,
	})
	local quickRow = Instance.new("Frame")
	quickRow.Position = UDim2.fromOffset(0, 44)
	quickRow.Size = UDim2.new(1, 0, 0, 32)
	quickRow.BackgroundTransparency = 1
	quickRow.Parent = onbCard
	local quickLayout = Instance.new("UIListLayout")
	quickLayout.FillDirection = Enum.FillDirection.Horizontal
	quickLayout.Padding = UDim.new(0, 6)
	quickLayout.Parent = quickRow
	for _, spec in
		{
			{ label = "1V1", mode = "1v1", bg = C.gold, fg = C.darkText, border = nil },
			{ label = "2V2", mode = "2v2", bg = C.surface, fg = C.sky, border = C.sky },
			{ label = "3V3", mode = "3v3", bg = C.surface, fg = C.sky, border = C.sky },
			{ label = "BEGINNER", mode = "beginner", bg = C.surface, fg = C.mint, border = C.mint },
		}
	do
		button({
			parent = quickRow,
			text = spec.label,
			bg = spec.bg,
			fg = spec.fg,
			border = spec.border,
			size = UDim2.new(0.25, -4.5, 1, 0),
			textSize = 11,
			font = FONT_HEAVY,
			onClick = function()
				send("quickLocalMatch", { mode = spec.mode })
				if selectedPlayer == localPlayer then
					setOpen(false)
				end
			end,
		})
	end
	local onbRow = Instance.new("Frame")
	onbRow.Position = UDim2.fromOffset(0, 82)
	onbRow.Size = UDim2.new(1, 0, 0, 32)
	onbRow.BackgroundTransparency = 1
	onbRow.Parent = onbCard
	local onbLayout = Instance.new("UIListLayout")
	onbLayout.FillDirection = Enum.FillDirection.Horizontal
	onbLayout.Padding = UDim.new(0, 8)
	onbLayout.Parent = onbRow
	button({
		parent = onbRow,
		text = "START FULL ONBOARDING",
		bg = C.mint,
		fg = C.darkText,
		size = UDim2.new(0.5, -4, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("startOnboarding")
		end,
	})
	button({
		parent = onbRow,
		text = "JUMP TO FREE CASE",
		bg = C.surface,
		fg = C.gold,
		border = C.gold,
		size = UDim2.new(0.5, -4, 1, 0),
		textSize = 11,
		font = FONT_HEAVY,
		onClick = function()
			send("testFreeCase")
		end,
	})
	if RunService:IsStudio() then
		local quickBtn = button({
			parent = onbCard,
			text = "1-ROUND MATCH: OFF",
			bg = C.surface,
			fg = C.sub,
			border = C.strokeBright,
			size = UDim2.new(1, 0, 0, 28),
			textSize = 11,
			font = FONT_HEAVY,
			onClick = function()
				local on = workspace:GetAttribute("QuickMatch") == true
				adminRequest:FireServer("toggleQuickMatch", localPlayer.UserId, { flag = not on })
			end,
		})
		quickBtn.Position = UDim2.fromOffset(0, 120)
		local quickStroke = quickBtn:FindFirstChildOfClass("UIStroke")
		local function syncQuickMatch()
			local on = workspace:GetAttribute("QuickMatch") == true
			quickBtn.Text = if on then "1-ROUND MATCH: ON" else "1-ROUND MATCH: OFF"
			quickBtn.TextColor3 = if on then C.mint else C.sub
			if quickStroke then
				quickStroke.Color = if on then C.mint else C.strokeBright
			end
		end
		workspace:GetAttributeChangedSignal("QuickMatch"):Connect(syncQuickMatch)
		syncQuickMatch()
	end

	-- =========================================================================
	-- LIVE REFRESH LOGIC
	-- =========================================================================
	refreshSkinsView = function()
		if not selectedPlayer or not selectedPlayer.Parent then
			return
		end
		local ownedSkins = PlayerData.skins(selectedPlayer)
		ownedFilterBtn.BackgroundColor3 = if ownedOnly then C.mint else C.card
		ownedFilterBtn.TextColor3 = if ownedOnly then C.darkText else C.sub

		if selectedLine then
			grantScopeBtn.Text = "+ " .. string.upper(selectedLine)
			removeScopeBtn.Text = "- " .. string.upper(selectedLine)
		else
			grantScopeBtn.Text = "+ GRANT ALL"
			removeScopeBtn.Text = "- CLEAR ALL"
		end

		-- Count owned per line
		local ownedByLine: { [string]: number } = {}
		local totalOwned = 0
		for _, entry in allSkins do
			if PlayerData.owns(ownedSkins, entry.gun, entry.line) then
				ownedByLine[entry.line] = (ownedByLine[entry.line] or 0) + 1
				totalOwned += 1
			end
		end

		for _, row in lineRows do
			local active = row.line == selectedLine
			row.btn.BackgroundColor3 = if active then C.cardHover else C.surface
			if row.line == nil then
				row.countLbl.Text = string.format("%d/%d", totalOwned, #allSkins)
			else
				local have = ownedByLine[row.line] or 0
				local total = 0
				for _, ls in allLines do
					if ls.line == row.line then
						total = ls.count
						break
					end
				end
				row.countLbl.Text = string.format("%d/%d", have, total)
				row.countLbl.TextColor3 = if have == total and total > 0 then C.mint else C.sub
			end
		end

		for _, ref in skinCards do
			local e = ref.entry
			local owns = PlayerData.owns(ownedSkins, e.gun, e.line)
			local matchLine = selectedLine == nil or e.line == selectedLine
			local matchOwned = not ownedOnly or owns
			local matchSearch = skinSearch == ""
				or string.find(string.lower(Weapons.nameOf(e.gun)), skinSearch, 1, true) ~= nil
				or string.find(string.lower(e.gun), skinSearch, 1, true) ~= nil
				or string.find(string.lower(e.line), skinSearch, 1, true) ~= nil
			ref.btn.Visible = matchLine and matchOwned and matchSearch
			if ref.btn.Visible then
				ref.badge.Text = if owns then "OWNED" else "+ ADD"
				ref.badge.TextColor3 = if owns then C.darkText else C.sub
				ref.badge.BackgroundColor3 = if owns then C.mint else C.surface
				ref.border.Color = if owns then C.mint else C.stroke
				ref.border.Transparency = if owns then 0.25 else 0.35
			end
		end
	end

	refreshCasesView = function()
		if not selectedPlayer or not selectedPlayer.Parent then
			return
		end
		local items = PlayerData.items(selectedPlayer)
		for id, lbl in caseCountLabels do
			lbl.Text = "HELD: " .. fmt(items[id] or 0)
		end
	end

	refreshAll = function()
		if not selectedPlayer or not selectedPlayer.Parent then
			selectedPlayer = localPlayer
		end
		local p = selectedPlayer
		headerTargetBadge.Text = "TARGET: " .. p.DisplayName .. " (@" .. p.Name .. ")"
		local coins = PlayerData.coins(p)
		local tickets = PlayerData.tickets(p)
		local lvl = StateValues.get(p, "Level")
		local xp = StateValues.get(p, "Xp")
		local xpNeed = StateValues.get(p, "XpNeed")
		local streak = StateValues.get(p, "WinStreak")
		local wins = StateValues.get(p, "Wins")
		local kills = StateValues.get(p, "Kills")

		statCoins.Text = fmt(coins)
		statTickets.Text = fmt(tickets)
		statLevel.Text = string.format(
			"LV %d  (%s / %s)",
			if typeof(lvl) == "number" then lvl else 1,
			fmt(if typeof(xp) == "number" then xp else 0),
			fmt(if typeof(xpNeed) == "number" then xpNeed else 100)
		)
		statStreak.Text = string.format(
			"%d  ·  %dW / %dK",
			if typeof(streak) == "number" then streak else 0,
			if typeof(wins) == "number" then wins else 0,
			if typeof(kills) == "number" then kills else 0
		)

		local ownedSkins = PlayerData.skins(p)
		local ownedCount = 0
		for _, entry in allSkins do
			if PlayerData.owns(ownedSkins, entry.gun, entry.line) then
				ownedCount += 1
			end
		end
		local caseTotal = 0
		for _, n in PlayerData.items(p) do
			caseTotal += n
		end
		statOwned.Text = string.format("%d/%d  ·  %d", ownedCount, #allSkins, caseTotal)

		if activeTab == "Skins" then
			refreshSkinsView()
		elseif activeTab == "Cases" then
			refreshCasesView()
		end
	end

	local function bindTarget(p: Player)
		for _, c in targetConns do
			c:Disconnect()
		end
		table.clear(targetConns)
		selectedPlayer = p
		resetArmedAt = 0
		resetBtn.Text = "RESET TARGET SAVE (CLICK TWICE)"
		resetBtn.BackgroundColor3 = Color3.fromHex("361A1F")

		local function watchState(key: string)
			table.insert(
				targetConns,
				StateValues.changed(p, key):Connect(function()
					if isOpen then
						refreshAll()
						refreshRoster()
					end
				end)
			)
		end
		for _, key in { "Coins", "Tickets", "Level", "Xp", "WinStreak", "Wins", "Kills" } do
			watchState(key)
		end

		local function watchVal(name: string)
			local v = p:FindFirstChild(name)
			if v and v:IsA("StringValue") then
				table.insert(
					targetConns,
					v:GetPropertyChangedSignal("Value"):Connect(function()
						if isOpen then
							refreshAll()
						end
					end)
				)
			end
		end
		watchVal(PlayerData.SKINS)
		watchVal(PlayerData.REPLICA)
		table.insert(
			targetConns,
			p.ChildAdded:Connect(function(child)
				if child.Name == PlayerData.SKINS or child.Name == PlayerData.REPLICA then
					if child:IsA("StringValue") then
						table.insert(
							targetConns,
							child:GetPropertyChangedSignal("Value"):Connect(function()
								if isOpen then
									refreshAll()
								end
							end)
						)
					end
					if isOpen then
						refreshAll()
					end
				end
			end)
		)

		refreshAll()
		refreshRoster()
	end

	refreshRoster = function()
		for _, child in rosterScroll:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local list = Players:GetPlayers()
		table.sort(list, function(a, b)
			if a == localPlayer then
				return true
			elseif b == localPlayer then
				return false
			end
			return a.DisplayName < b.DisplayName
		end)
		for idx, p in list do
			local active = p == selectedPlayer
			local chip = Instance.new("TextButton")
			chip.Name = "Player_" .. p.UserId
			chip.LayoutOrder = idx
			chip.Size = UDim2.fromOffset(188, 42)
			chip.BackgroundColor3 = if active then C.cardHover else C.card
			chip.Text = ""
			chip.AutoButtonColor = false
			corner(chip, 5)
			stroke(
				chip,
				if active then C.gold else C.stroke,
				if active then 1.5 else 1,
				if active then 0 else 0.3
			)
			chip.Parent = rosterScroll

			local avatar = Instance.new("ImageLabel")
			avatar.Size = UDim2.fromOffset(32, 32)
			avatar.Position = UDim2.fromOffset(5, 5)
			avatar.BackgroundColor3 = C.bg
			avatar.Image = thumbCache[p.UserId] or ""
			corner(avatar, 4)
			avatar.Parent = chip

			if not thumbCache[p.UserId] then
				task.spawn(function()
					local ok, url = pcall(
						Players.GetUserThumbnailAsync,
						Players,
						p.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
					if ok and typeof(url) == "string" then
						thumbCache[p.UserId] = url
						if avatar.Parent then
							avatar.Image = url
						end
					end
				end)
			end

			local nameText = p.DisplayName .. (if p == localPlayer then " (YOU)" else "")
			label({
				parent = chip,
				text = nameText,
				size = 12,
				font = FONT_HEAVY,
				color = if active then C.gold else C.text,
				frameSize = UDim2.new(1, -46, 0, 15),
				pos = UDim2.fromOffset(42, 4),
				truncate = true,
			})
			local lvl = StateValues.get(p, "Level")
			label({
				parent = chip,
				text = string.format(
					"Lv.%d · %s c",
					if typeof(lvl) == "number" then lvl else 1,
					fmt(PlayerData.coins(p))
				),
				size = 10,
				font = FONT_BOLD,
				color = C.sub,
				frameSize = UDim2.new(1, -46, 0, 14),
				pos = UDim2.fromOffset(42, 22),
				truncate = true,
			})

			chip.Activated:Connect(function()
				bindTarget(p)
			end)
		end
	end

	-- =========================================================================
	-- TAB 5: MATCH BOTS (difficulty and level of the bots in this match, live)
	-- =========================================================================
	local DIFF_COLOR: { [string]: Color3 } = {
		Easy = C.mint,
		Normal = C.sky,
		Hard = C.gold,
		Insane = C.coral,
		Ultra = C.epic,
	}
	local function botRequest(action: string, payload: { [string]: any })
		adminRequest:FireServer(action, localPlayer.UserId, payload)
	end

	local botsPage = makePage("Bots")
	pad(botsPage, 12, 12, 12, 12)

	-- All bots: difficulty (also the default for bots made later) and level
	local allCard =
		makeSectionCard(botsPage, "ALL BOTS IN THIS MATCH  ·  ALSO SETS NEW BOTS", C.mint, 1)
	allCard.Size = UDim2.new(1, 0, 0, 116)
	local allDiff = Instance.new("Frame")
	allDiff.Position = UDim2.fromOffset(0, 26)
	allDiff.Size = UDim2.new(1, 0, 0, 32)
	allDiff.BackgroundTransparency = 1
	allDiff.Parent = allCard
	local allDiffLayout = Instance.new("UIListLayout")
	allDiffLayout.FillDirection = Enum.FillDirection.Horizontal
	allDiffLayout.Padding = UDim.new(0, 6)
	allDiffLayout.SortOrder = Enum.SortOrder.LayoutOrder
	allDiffLayout.Parent = allDiff
	for i, name in BotsConfig.ORDER do
		local tone = DIFF_COLOR[name] or C.text
		button({
			parent = allDiff,
			text = string.upper(name),
			bg = C.surface,
			fg = tone,
			border = tone,
			size = UDim2.new(1 / #BotsConfig.ORDER, -5, 1, 0),
			textSize = 12,
			font = FONT_HEAVY,
			layoutOrder = i,
			onClick = function()
				botRequest("botDifficulty", { botId = 0, difficulty = name })
			end,
		})
	end
	makePresetRow(allCard, 66, AdminConfig.BOT_LEVEL_PRESETS, C.mint, " LV", function(n: number)
		botRequest("botLevel", { botId = 0, add = n })
	end)

	local botList = Instance.new("ScrollingFrame")
	botList.Position = UDim2.fromOffset(0, 128)
	botList.Size = UDim2.new(1, 0, 1, -128)
	botList.BackgroundTransparency = 1
	botList.BorderSizePixel = 0
	botList.ScrollBarThickness = 4
	botList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	botList.CanvasSize = UDim2.new()
	botList.Parent = botsPage
	local botListLayout = Instance.new("UIListLayout")
	botListLayout.Padding = UDim.new(0, 6)
	botListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	botListLayout.Parent = botList

	local function botRow(seat: Configuration, order: number)
		local botId = StateValues.get(seat, "BotId")
		if typeof(botId) ~= "number" then
			return
		end
		local level = StateValues.get(seat, "Level")
		local diff = StateValues.get(seat, "Difficulty")
		local team = StateValues.get(seat, "TeamId")
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 40)
		row.BackgroundColor3 = C.card
		row.Parent = botList
		corner(row, 4)
		stroke(row, C.stroke, 1, 0.2)
		label({
			parent = row,
			text = string.format(
				"%s  ·  TEAM %s  ·  LV %s",
				seat.Name,
				tostring(team or "?"),
				tostring(level or "?")
			),
			size = 12,
			font = FONT_BOLD,
			color = C.text,
			frameSize = UDim2.new(0, 250, 1, 0),
			pos = UDim2.fromOffset(10, 0),
			truncate = true,
		})
		local diffName = if typeof(diff) == "string" then diff else "?"
		label({
			parent = row,
			text = string.upper(diffName),
			size = 12,
			font = FONT_HEAVY,
			color = DIFF_COLOR[diffName] or C.sub,
			frameSize = UDim2.new(0, 70, 1, 0),
			pos = UDim2.fromOffset(262, 0),
		})
		local picks = Instance.new("Frame")
		picks.Position = UDim2.fromOffset(336, 5)
		picks.Size = UDim2.new(0, 330, 0, 30)
		picks.BackgroundTransparency = 1
		picks.Parent = row
		local pl = Instance.new("UIListLayout")
		pl.FillDirection = Enum.FillDirection.Horizontal
		pl.Padding = UDim.new(0, 4)
		pl.SortOrder = Enum.SortOrder.LayoutOrder
		pl.Parent = picks
		for i, name in BotsConfig.ORDER do
			local tone = DIFF_COLOR[name] or C.text
			local on = name == diffName
			button({
				parent = picks,
				text = string.upper(name),
				bg = if on then tone:Lerp(C.surface, 0.55) else C.surface,
				fg = tone,
				border = if on then tone else C.strokeBright,
				size = UDim2.fromOffset(62, 30),
				textSize = 10,
				font = FONT_HEAVY,
				layoutOrder = i,
				onClick = function()
					botRequest("botDifficulty", { botId = botId, difficulty = name })
				end,
			})
		end
		local box = Instance.new("TextBox")
		box.Position = UDim2.new(1, -150, 0, 5)
		box.Size = UDim2.fromOffset(80, 30)
		box.BackgroundColor3 = C.input
		box.Text = ""
		box.PlaceholderText = "level"
		box.TextColor3 = C.text
		box.PlaceholderColor3 = C.dim
		box.FontFace = FONT_BOLD
		box.TextSize = 12
		box.ClearTextOnFocus = true
		box.Parent = row
		corner(box, 4)
		stroke(box, C.stroke, 1, 0.2)
		local setLevel = button({
			parent = row,
			text = "SET LV",
			bg = C.surface,
			fg = C.mint,
			border = C.strokeBright,
			size = UDim2.fromOffset(60, 30),
			textSize = 10,
			font = FONT_HEAVY,
			onClick = function()
				local n = tonumber(box.Text)
				if n and n == n then
					botRequest("botLevel", { botId = botId, level = math.floor(n) })
				else
					showToast(false, "Type a level number first")
				end
			end,
		})
		setLevel.Position = UDim2.new(1, -66, 0, 5)
	end

	local botsShown = ""
	refreshBotsView = function()
		local seats = MatchState.botSeats()
		table.sort(seats, function(a, b)
			return a.Name < b.Name
		end)
		-- rebuild only when something shown changed (keeps a level being typed)
		local parts = {}
		for _, seat in seats do
			table.insert(
				parts,
				string.format(
					"%s:%s:%s:%s",
					seat.Name,
					tostring(StateValues.get(seat, "Level")),
					tostring(StateValues.get(seat, "Difficulty")),
					tostring(StateValues.get(seat, "TeamId"))
				)
			)
		end
		local key = table.concat(parts, "|")
		if key == botsShown then
			return
		end
		botsShown = key
		for _, c in botList:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if #seats == 0 then
			label({
				parent = botList,
				text = "No bots in this match. Start a match or pad duel with bots, then open this tab.",
				size = 12,
				font = FONT_MED,
				color = C.sub,
				frameSize = UDim2.new(1, -8, 0, 30),
			})
			return
		end
		for i, seat in seats do
			botRow(seat, i)
		end
	end
	task.spawn(function()
		while gui.Parent do
			task.wait(1)
			if isOpen and activeTab == "Bots" then
				refreshBotsView()
			end
		end
	end)

	Players.PlayerAdded:Connect(function()
		if isOpen then
			refreshRoster()
		end
	end)
	Players.PlayerRemoving:Connect(function(leaving: Player)
		if leaving == selectedPlayer then
			bindTarget(localPlayer)
		elseif isOpen then
			refreshRoster()
		end
	end)

	toggleBtn.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- the hotkey even when the game took the key (in a match F8 is also the Mod dev panel's input action)
		if input.KeyCode == AdminConfig.HOTKEY and UserInputService:GetFocusedTextBox() == nil then
			setOpen(not isOpen)
			return
		end
		if processed then
			return
		end
		if input.KeyCode == AdminConfig.HOTKEY then
			setOpen(not isOpen)
		elseif isOpen and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)

	switchTab("Economy")
	bindTarget(localPlayer)
end

return AdminPanelController
