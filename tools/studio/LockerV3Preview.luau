--!strict
-- Locker v3 MOCKUP preview: the Source of StarterGui.LockerV3.Preview (built by tools/studio/BuildLockerV3.luau).
-- Does nothing unless workspace attribute LockerV3Preview = true when Play starts. Then it opens the mockup in
-- the lobby's Locker room: a long-lens camera (FOV 20) with depth of field on the armoury wall, our gun or the
-- power card floating in the middle. Click guns, powers and tabs; drag the middle to turn the gun or card.
-- Mockup only: no data, no remotes. The real Locker gets its own off-world copy of the room.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if workspace:GetAttribute("LockerV3Preview") ~= true then
	return
end

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)

local gui = script.Parent :: ScreenGui
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STAGE = Vector3.new(80, 6.6, -1600)
local CAMERA = CFrame.lookAt(Vector3.new(67, 7.8, -1600), Vector3.new(80, 6.8, -1600))
local FOV = 20
local GUN_LENGTH = 4.1 -- every gun is scaled to about this long (pistols read as big as rifles)
-- rest poses, camera looking +X (right of screen = +Z)
local GUN_REST = CFrame.Angles(0, math.rad(14), 0)
	* CFrame.Angles(math.rad(-24), 0, 0)
	* CFrame.Angles(0, math.pi, 0)
local CARD_REST = CFrame.Angles(0, math.rad(90 - 12), 0)
local DRAG_YAW = math.rad(0.35) -- per pixel
local DRAG_PITCH = math.rad(0.3)
local EASE = 12

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromHex("07080B")
local CYAN = Color3.fromHex("3FE0F2")
local GOLD = { Color3.fromHex("FFE066"), Color3.fromHex("F2A51C") }
local DARK = { Color3.fromHex("41444E"), Color3.fromHex("24262D") }
local LIGHT = { Color3.fromHex("FFFFFF"), Color3.fromHex("C9CED8") }
local INK = Color3.fromHex("17130A")

task.wait(2) -- let the lobby's own UI settle first
pcall(function()
	player:RequestStreamAroundAsync(STAGE)
end)

local function find(parent: Instance, path: string): Instance
	local node: Instance = parent
	for name in string.gmatch(path, "[^%.]+") do
		node = node:WaitForChild(name, 5) :: Instance
	end
	return node
end
local function label(parent: Instance, path: string): TextLabel
	return find(parent, path) :: TextLabel
end
local function set(parent: Instance, path: string, prop: string, value: any)
	local node: any = find(parent, path)
	node[prop] = value
end

local left = find(gui, "Left") :: Frame
local right = find(gui, "Right") :: Frame
local top = find(gui, "Top") :: Frame
local bottom = find(gui, "Bottom") :: Frame
local center = find(gui, "Center") :: Frame
local stage = (ReplicatedStorage:WaitForChild("LockerV3Stage") :: Folder):Clone()
local showcase = find(stage, "Showcase") :: Folder
local card = find(stage, "PowerCard") :: Model
local stack = find(right, "Stack") :: Frame
local ownedPanel = find(stack, "GunOwned") :: Frame
local lockedPanel = find(stack, "GunLocked") :: Frame
local powerPanel = find(stack, "Power") :: Frame
local lockPlate = find(center, "Lock") :: Frame
local dragZone = find(gui, "DragZone") :: TextButton

-- open ------------------------------------------------------------------------------------------------------
local connections: { RBXScriptConnection } = {}
local hiddenGuis: { ScreenGui } = {}
local hiddenParts: { BasePart } = {}
local open = true

stage.Parent = workspace
gui.Enabled = true

local dof = Instance.new("DepthOfFieldEffect")
dof.Name = "LockerV3Focus"
dof.FarIntensity = 0.75
dof.NearIntensity = 0
dof.FocusDistance = 0.1
dof.InFocusRadius = 15
dof.Parent = Lighting

local function hideLocal(root: Instance)
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.LocalTransparencyModifier < 1 then
			p.LocalTransparencyModifier = 1
			table.insert(hiddenParts, p)
		end
	end
end
-- the room's NPC and the display guns on the pedestals between the camera and the wall
local lobby = workspace:FindFirstChild("LobbyV5")
local armorer = lobby and lobby:FindFirstChild("Armorer", true)
if armorer then
	hideLocal(armorer)
end
local circle = lobby and lobby:FindFirstChild("GunCircle", true)
if circle then
	-- the plinth circle the gun floats over (it would sit in front of the camera)
	hideLocal(circle)
end
local displays = workspace:FindFirstChild("LobbyGunDisplays")
if displays then
	for _, m in displays:GetDescendants() do
		if m:IsA("Model") and m.Parent == displays then
			local p = m:GetPivot().Position
			if
				p.X < 92
				and (Vector3.new(p.X, 0, p.Z) - Vector3.new(STAGE.X, 0, STAGE.Z)).Magnitude < 16
			then
				hideLocal(m)
			end
		end
	end
end

local camera = workspace.CurrentCamera
RunService:BindToRenderStep("LockerV3Camera", Enum.RenderPriority.Last.Value, function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	camera.CFrame = CAMERA
end)

local function fit()
	local s = gui.AbsoluteSize.Y / 1080
	for _, c in { left, right, top, bottom, center, find(gui, "TopRight") } do
		local u = c:FindFirstChildOfClass("UIScale")
		if u then
			u.Scale = s
		end
	end
end
fit()
table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))

-- keep the lobby's screens off while the mockup is open
local function hideOthers()
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			g.Enabled = false
			if not table.find(hiddenGuis, g) then
				table.insert(hiddenGuis, g)
			end
		end
	end
end
hideOthers()
task.spawn(function()
	while open do
		hideOthers()
		task.wait(0.5)
	end
end)

-- the stage ---------------------------------------------------------------------------------------------------
local mode = "guns" -- "guns" | "powers"
local yaw, pitch, targetYaw, targetPitch = 0, 0, 0, 0
local dragging = false
local lastPos = Vector2.zero
local current: Model? = nil
local centerOffset = CFrame.new()

local function showGun(id: string, isLocked: boolean)
	if current then
		current:Destroy()
	end
	local src = showcase:FindFirstChild(id)
	if not src then
		local weapons = ReplicatedStorage:FindFirstChild("Weapons")
		src = weapons and weapons:FindFirstChild(id)
	end
	if not (src and src:IsA("Model")) then
		current = nil
		return
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if isLocked then
				d.LocalTransparencyModifier = 0.5
			end
		end
	end
	m:PivotTo(CFrame.new())
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * math.clamp(GUN_LENGTH / math.max(size.X, size.Y, size.Z), 0.8, 2.3))
	m:PivotTo(CFrame.new())
	local box = m:GetBoundingBox()
	centerOffset = CFrame.new(box.Position)
	m.Parent = stage
	current = m
	-- a little swing in on every swap
	yaw = targetYaw - math.rad(50)
end

local function cardPivot(): CFrame
	local t = os.clock()
	local bob = CFrame.new(0, math.sin(t * 1.3) * 0.05, 0)
	local hoverYaw, hoverPitch = 0, 0
	if not dragging then
		local m = UserInputService:GetMouseLocation()
		local size = camera.ViewportSize
		hoverYaw = math.clamp((m.X / size.X - 0.5) * 2, -1, 1) * math.rad(10)
		hoverPitch = math.clamp((m.Y / size.Y - 0.5) * 2, -1, 1) * math.rad(8)
	end
	local turn = CFrame.fromAxisAngle(Vector3.yAxis, yaw + hoverYaw)
		* CFrame.fromAxisAngle(Vector3.zAxis, pitch + hoverPitch)
	return CFrame.new(STAGE + Vector3.new(0, 0.3, 0)) * bob * turn * CARD_REST
end

local front = find(card, "Face.Front.Card") :: Frame
local sweep = find(front, "Shine.Sweep") :: UIGradient
table.insert(
	connections,
	RunService.RenderStepped:Connect(function(dt)
		local a = 1 - math.exp(-dt * EASE)
		yaw += (targetYaw - yaw) * a
		pitch += (targetPitch - pitch) * a
		if mode == "guns" then
			card:PivotTo(CFrame.new(0, -500, 0))
			if current then
				local t = os.clock()
				local bob = CFrame.new(0, math.sin(t * 1.2) * 0.04, 0)
					* CFrame.Angles(0, math.sin(t * 0.7) * 0.03, 0)
				local turn = CFrame.fromAxisAngle(Vector3.yAxis, yaw)
					* CFrame.fromAxisAngle(Vector3.zAxis, pitch)
				current:PivotTo(CFrame.new(STAGE) * bob * turn * GUN_REST * centerOffset:Inverse())
			end
		else
			local cf = cardPivot()
			card:PivotTo(cf)
			-- the shine slides as the card turns toward or away from the light
			local look = cf.LookVector
			sweep.Offset = Vector2.new(math.clamp(look.Z * 1.6 - look.Y * 0.8, -0.9, 0.9), 0)
		end
	end)
)

-- dragging: grab anywhere off the panels
table.insert(
	connections,
	dragZone.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			lastPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
)
table.insert(
	connections,
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local d = p - lastPos
			lastPos = p
			targetYaw += d.X * DRAG_YAW
			targetPitch = math.clamp(targetPitch + d.Y * DRAG_PITCH, math.rad(-40), math.rad(40))
		end
	end)
)
table.insert(
	connections,
	UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
			targetPitch = 0
			if mode == "powers" then
				-- a card settles on whichever face is nearer
				targetYaw = math.round(targetYaw / math.pi) * math.pi
			else
				targetYaw = math.round(targetYaw / (2 * math.pi)) * 2 * math.pi
			end
		end
	end)
)

-- buttons -------------------------------------------------------------------------------------------------------
local function paint(button: Instance, colors: { Color3 }, words: string, ink: boolean)
	local bg = button:FindFirstChild("Bg")
	local fill = bg and bg:FindFirstChild("Fill")
	if fill and fill:IsA("UIGradient") then
		fill.Color = ColorSequence.new(colors[1], colors[2])
	end
	local l = button:FindFirstChild("Label")
	if l and l:IsA("TextLabel") then
		l.Text = words
		l.TextColor3 = if ink then INK else WHITE
		local stroke = l:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Enabled = not ink
		end
	end
end

local gunRows: { ImageButton } = {}
for _, r in find(left, "Guns.List"):GetChildren() do
	if r:IsA("ImageButton") and r:GetAttribute("Gun") then
		table.insert(gunRows, r)
	end
end
local tiles: { ImageButton } = {}
for _, t in find(left, "Powers.List.Grid"):GetChildren() do
	if t:IsA("ImageButton") and t:GetAttribute("Power") then
		table.insert(tiles, t)
	end
end
table.sort(tiles, function(a, b)
	return a.LayoutOrder < b.LayoutOrder
end)

local selectedRow: ImageButton? = nil
local selectedTile: ImageButton? = nil

local function setDetails(
	panel: Instance,
	name: string,
	role: string,
	roleColor: Color3,
	blurb: string
)
	label(panel, "Details.Name").Text = string.upper(name)
	local r = label(panel, "Details.Role")
	r.Text = role
	r.TextColor3 = roleColor
	local s = find(panel, "Details.Slash") :: Frame
	s.BackgroundColor3 = roleColor
	label(panel, "Details.Blurb").Text = blurb
end

local function refreshEquip(row: ImageButton)
	local equipButton = find(ownedPanel, "Equip.Button")
	if row:GetAttribute("Equipped") then
		paint(equipButton, DARK, "EQUIPPED", false)
	else
		paint(equipButton, GOLD, "EQUIP", true)
	end
end

local function selectGun(row: ImageButton)
	if selectedRow then
		local bg = find(selectedRow, "Bg") :: ImageLabel
		bg.ImageColor3 = PANEL
		bg.ImageTransparency = 0.3
		set(selectedRow, "Sel", "Visible", false)
	end
	selectedRow = row
	local bg = find(row, "Bg") :: ImageLabel
	bg.ImageColor3 = WHITE
	bg.ImageTransparency = 0.8
	set(row, "Sel", "Visible", true)
	local owned = row:GetAttribute("Owned") == true
	local id = row:GetAttribute("Gun") :: string
	ownedPanel.Visible = owned
	lockedPanel.Visible = not owned
	powerPanel.Visible = false
	lockPlate.Visible = not owned
	local panel = if owned then ownedPanel else lockedPanel
	setDetails(
		panel,
		row:GetAttribute("GunName") :: string,
		row:GetAttribute("Role") :: string,
		if owned then CYAN else Color3.fromHex("C8CCD4"),
		row:GetAttribute("Blurb") :: string
	)
	if owned then
		local lv = row:GetAttribute("Level") :: number
		label(ownedPanel, "Level.Number").Text = tostring(lv)
		label(ownedPanel, "Level.Reward.Text").Text = "Reward at LV " .. tostring((lv // 5 + 1) * 5)
		refreshEquip(row)
	else
		local price = row:GetAttribute("Price") :: number
		local words = if price >= 1000
			then string.format("%d,%03d", price // 1000, price % 1000)
			else tostring(price)
		label(lockedPanel, "Unlock.Buy.Button.Label").Text = words
	end
	showGun(id, not owned)
end

local function fillCard(id: string, lv: number, owned: boolean)
	local def = (ModsConfig :: any).defs[id]
	local roleColor = Theme.ROLE[def.role] or WHITE
	local art = find(front, "Art") :: ImageLabel
	art.Image = Theme.CARD_ART[id] or ""
	art.ImageTransparency = 0
	set(front, "Band", "BackgroundColor3", roleColor)
	label(front, "Title").Text = string.upper(def.name)
	label(front, "Role").Text = string.upper(def.role)
	label(front, "Note").Text = def.levels.L1.note .. "."
	label(front, "Level").Text = if owned then "LV " .. lv else "POWER CASE"
	local back = find(card, "Face.Back.Card")
	set(back, "Band", "BackgroundColor3", roleColor)
	set(card, "Edge", "Color", roleColor)
	return def, roleColor
end

local function pathNote(def: any, p: string): string
	local best: string? = nil
	for k, v in def.levels do
		if
			string.sub(k, 1, 1) == p
			and typeof(v) == "table"
			and v.note
			and (not best or k < best)
		then
			best = k
		end
	end
	local note = if best then def.levels[best].note else ""
	note = string.gsub(note, "^[^:]+: ", "")
	return string.upper(string.sub(note, 1, 1)) .. string.sub(note, 2)
end

local function deckCount(): number
	local n = 0
	for _, t in tiles do
		if t:GetAttribute("InDeck") then
			n += 1
		end
	end
	return n
end

local function refreshDeck()
	local deck = find(left, "Powers.Deck")
	local i = 0
	for _, t in tiles do
		if t:GetAttribute("InDeck") then
			i += 1
			local slot = deck:FindFirstChild("Slot" .. i)
			if slot then
				local id = t:GetAttribute("Power") :: string
				local def = (ModsConfig :: any).defs[id]
				set(slot, "Art", "Image", Theme.CARD_ART[id] or "")
				local band = find(slot, "Band") :: Frame
				band.Visible = true
				band.BackgroundColor3 = Theme.ROLE[def.role] or WHITE
				set(slot, "Name", "Text", string.upper(def.name))
				set(slot, "Plus", "Visible", false)
			end
		end
		local tag = t:FindFirstChild("InDeck")
		if tag and tag:IsA("Frame") then
			tag.Visible = t:GetAttribute("InDeck") == true
		end
	end
	for j = i + 1, 10 do
		local slot = deck:FindFirstChild("Slot" .. j)
		if slot then
			set(slot, "Art", "Image", "")
			set(slot, "Band", "Visible", false)
			set(slot, "Name", "Text", "")
			set(slot, "Plus", "Visible", true)
		end
	end
	label(deck, "Count").Text = string.format("%d / 10", i)
end

local function refreshDeckButton(tile: ImageButton)
	local b = find(powerPanel, "DeckButton.Button")
	if tile:GetAttribute("Owned") ~= true then
		paint(b, GOLD, "OPEN POWER CASES", true)
	elseif tile:GetAttribute("InDeck") then
		paint(b, DARK, "IN DECK · REMOVE", false)
	else
		paint(b, GOLD, "ADD TO DECK", true)
	end
end

local function selectPower(tile: ImageButton, spin: boolean)
	if selectedTile then
		set(selectedTile, "Sel", "Visible", false)
	end
	selectedTile = tile
	set(tile, "Sel", "Visible", true)
	local id = tile:GetAttribute("Power") :: string
	local owned = tile:GetAttribute("Owned") == true
	local lv = tile:GetAttribute("Level") :: number
	local def, roleColor = fillCard(id, lv, owned)
	setDetails(
		powerPanel,
		def.name,
		string.upper(def.role) .. (if owned then "" else " · LOCKED"),
		roleColor,
		def.levels.L1.note .. "."
	)
	label(powerPanel, "Level.Number").Text = tostring(math.max(lv, 1))
	set(powerPanel, "Level", "Visible", owned) -- a locked power has no level yet
	for _, p in { "A", "B", "G" } do
		label(powerPanel, "Paths.Path" .. p .. ".Name").Text = string.upper(def.paths[p] or "")
		label(powerPanel, "Paths.Path" .. p .. ".Note").Text = pathNote(def, p)
		if p ~= "G" then
			set(powerPanel, "Paths.Path" .. p .. ".Chip", "BackgroundColor3", roleColor)
		end
	end
	refreshDeckButton(tile)
	if spin then
		-- a fresh card flips in: one full turn into place
		yaw = targetYaw - 2 * math.pi
	end
end

local function setMode(newMode: string, tab: string)
	mode = newMode
	for _, b in find(top, "Tabs"):GetChildren() do
		if b:IsA("ImageButton") then
			local active = b:GetAttribute("Tab") == tab
			paint(b, if active then LIGHT else DARK, b:GetAttribute("Tab") :: string, active)
			local bg = find(b, "Bg") :: ImageLabel
			bg.ImageTransparency = if active then 0 else 0.3
		end
	end
	local guns = newMode == "guns"
	set(left, "Guns", "Visible", guns)
	set(left, "Powers", "Visible", not guns)
	set(bottom, "GunBar", "Visible", guns)
	set(bottom, "PowerBar", "Visible", not guns)
	targetYaw, targetPitch = 0, 0
	if guns then
		if current then
			current.Parent = stage
		end
		if tab == "KNIFE" then
			ownedPanel.Visible = true
			lockedPanel.Visible = false
			powerPanel.Visible = false
			lockPlate.Visible = false
			setDetails(
				ownedPanel,
				"Knife",
				"MELEE · SKINS ONLY",
				CYAN,
				"Every player has one. Pick a knife skin to make it yours."
			)
			showGun("Knife", false)
		elseif selectedRow then
			selectGun(selectedRow)
		end
	else
		ownedPanel.Visible = false
		lockedPanel.Visible = false
		lockPlate.Visible = false
		powerPanel.Visible = true
		if current then
			current.Parent = nil
		end
		if selectedTile then
			selectPower(selectedTile, true)
		end
	end
end

for _, r in gunRows do
	table.insert(
		connections,
		r.Activated:Connect(function()
			selectGun(r)
		end)
	)
end
for _, t in tiles do
	table.insert(
		connections,
		t.Activated:Connect(function()
			selectPower(t, true)
		end)
	)
end
for _, b in find(top, "Tabs"):GetChildren() do
	if b:IsA("ImageButton") then
		table.insert(
			connections,
			b.Activated:Connect(function()
				local tab = b:GetAttribute("Tab") :: string
				setMode(if tab == "POWERS" then "powers" else "guns", tab)
			end)
		)
	end
end

-- EQUIP: the row becomes this slot's equipped gun, the loadout card follows
table.insert(
	connections,
	(find(ownedPanel, "Equip.Button") :: ImageButton).Activated:Connect(function()
		local row = selectedRow
		if not row or row:GetAttribute("Owned") ~= true then
			return
		end
		local slotName = row:GetAttribute("SlotName") :: string
		for _, r in gunRows do
			if r:GetAttribute("SlotName") == slotName then
				r:SetAttribute("Equipped", r == row)
				local tag = r:FindFirstChild("Equipped")
				if tag and tag:IsA("TextLabel") then
					tag.Visible = r == row
				end
			end
		end
		local slot = find(left, "Guns.Loadout." .. slotName)
		local id = row:GetAttribute("Gun") :: string
		set(slot, "Render", "Image", Theme.GUN[id] or "")
		set(slot, "Name", "Text", string.upper(row:GetAttribute("GunName") :: string))
		refreshEquip(row)
	end)
)

-- the deck button: add / remove (max 10)
table.insert(
	connections,
	(find(powerPanel, "DeckButton.Button") :: ImageButton).Activated:Connect(function()
		local tile = selectedTile
		if not tile or tile:GetAttribute("Owned") ~= true then
			return
		end
		if tile:GetAttribute("InDeck") then
			tile:SetAttribute("InDeck", false)
		elseif deckCount() < 10 then
			tile:SetAttribute("InDeck", true)
		end
		refreshDeck()
		refreshDeckButton(tile)
	end)
)

-- Overview: open / close the stat bars under the actions
table.insert(
	connections,
	(find(ownedPanel, "Actions.OverviewRow.Button") :: ImageButton).Activated:Connect(function()
		local o = find(ownedPanel, "Overview") :: Frame
		o.Visible = not o.Visible
	end)
)

table.insert(
	connections,
	(find(bottom, "PowerBar.Flip.Button") :: ImageButton).Activated:Connect(function()
		targetYaw += math.pi
	end)
)

-- BACK closes the mockup and gives the lobby back
local function close()
	if not open then
		return
	end
	open = false
	RunService:UnbindFromRenderStep("LockerV3Camera")
	for _, c in connections do
		c:Disconnect()
	end
	for _, p in hiddenParts do
		p.LocalTransparencyModifier = 0
	end
	for _, g in hiddenGuis do
		g.Enabled = true
	end
	dof:Destroy()
	stage:Destroy()
	gui.Enabled = false
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end
for _, path in { "GunBar.Back.Button", "PowerBar.Back.Button" } do
	table.insert(connections, (find(bottom, path) :: ImageButton).Activated:Connect(close))
end

-- start on the equipped primary, Dash selected in powers; workspace LockerV3State can open powers / a locked gun
for _, r in gunRows do
	if r:GetAttribute("Gun") == "Vandal" then
		selectedRow = r
	end
end
selectedTile = tiles[1]
refreshDeck()
if selectedRow then
	selectGun(selectedRow)
end
local function applyState()
	local s = workspace:GetAttribute("LockerV3State")
	if s == "powers" then
		setMode("powers", "POWERS")
	elseif s == "locked" then
		setMode("guns", "GUNS")
		for _, r in gunRows do
			if r:GetAttribute("Gun") == "Operator" then
				selectGun(r)
			end
		end
	elseif s == "guns" then
		setMode("guns", "GUNS")
	end
end
applyState()
table.insert(connections, workspace:GetAttributeChangedSignal("LockerV3State"):Connect(applyState))
