--!strict
-- The Locker v3 (vault/01 Design/Loadout and Power Deck.md → "Locker v3 mockup" and "Step 2 plan"; owner
-- 2026-11-26: "Yes, this direction"). RIVALS' weapon-page structure in our style:
--   * the stage is the lobby's own Locker room: the camera at FOV 20 with depth of field on the armoury wall,
--     the gun (in its equipped skin) or the power card floating in the middle. While it is open the plinth
--     circle, the Armorer, the floating displays and every character near the shot are hidden locally.
--   * GUNS: the loadout card, the Primary and Secondary lists (Config/Loadout), EQUIP / UNLOCK (coins) /
--     TRY IN THE RANGE through LockerGunRequest (Services/LockerService), SKIN opens a strip of owned skins
--     (LockerRequest, as Locker v4 did), Overview shows the gun's numbers (Config/Weapons).
--   * POWERS: the deck of 10 and every power; the power is a real 3D card (the draft card's face, the logo on
--     the back, a coloured edge) that leans toward the mouse, turns when dragged and flips; ADD TO DECK /
--     REMOVE through LockerModRequest.
--   * KNIFE: the knife and its skins.
-- The screen is Studio-built (StarterGui.LockerV3; the build script tools/studio/BuildLockerV3.luau, then
-- tools/studio/PromoteLockerV3.luau turned the mockup into templates: RowOwned / RowLocked, TileOwned /
-- TileLocked); the card is ReplicatedStorage.LockerV3Stage.PowerCard. This module fills and moves them.
-- Not yet (build order step 3): weapon levels, contracts, statistics; their rows stay hidden.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local LoadoutConfig = require(ReplicatedStorage.Shared.Config.Loadout)
local LobbyConfig = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local Mods = require(ReplicatedStorage.Shared.Mods)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local SkinStore = require(ReplicatedStorage.Shared.SkinStore)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local Router = require(script.Parent.Parent.Util.Router)

local LockerV3Controller = {}

local player = Players.LocalPlayer

-- the stage (the lobby Locker room, LobbyV5.Shell.Locker; camera looking +X, screen right = +Z)
local STAGE = Vector3.new(80, 6.6, -1600)
local CAMERA = CFrame.lookAt(Vector3.new(67, 7.8, -1600), Vector3.new(80, 6.8, -1600))
local FOV = 20
local HIDE_RADIUS = 16 -- characters and displays this close to the stage are hidden while open
local GUN_LENGTH = 4.1 -- every gun is scaled to about this long (pistols read as big as rifles)
local GUN_REST = CFrame.Angles(0, math.rad(14), 0)
	* CFrame.Angles(math.rad(-24), 0, 0)
	* CFrame.Angles(0, math.pi, 0)
local CARD_REST = CFrame.Angles(0, math.rad(90 - 12), 0)
local CARD_LIFT = Vector3.new(0, 0.3, 0)
local DRAG_YAW = math.rad(0.35) -- per pixel
local DRAG_PITCH = math.rad(0.3)
local EASE = 12
local HOVER_YAW, HOVER_PITCH = math.rad(10), math.rad(8)

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromHex("07080B")
local CYAN = Color3.fromHex("3FE0F2")
local LOCKED_ROLE = Color3.fromHex("C8CCD4")
local INK = Color3.fromHex("17130A")
local GOLD = { Color3.fromHex("FFE066"), Color3.fromHex("F2A51C") }
local DARK = { Color3.fromHex("41444E"), Color3.fromHex("24262D") }
local LIGHT = { Color3.fromHex("FFFFFF"), Color3.fromHex("C9CED8") }

type Mode = "guns" | "powers" | "knife"

local gui: ScreenGui
local left: Frame
local right: Frame
local top: Frame
local bottom: Frame
local center: Frame
local ownedPanel: Frame
local lockedPanel: Frame
local powerPanel: Frame
local lockPlate: Frame
local skinStrip: ScrollingFrame
local card: Model? = nil
local front: Frame? = nil
local sweep: UIGradient? = nil

local isOpen = false
local mode: Mode = "guns"
local selectedGun = LoadoutConfig.STARTER.Primary
local selectedPower = ""
local previewLine = "Stock"
local stripOpen = false
local rows: { [string]: GuiButton } = {}
local tiles: { [string]: GuiButton } = {}
local skinTiles: { GuiButton } = {}
local current: Model? = nil
local centerOffset = CFrame.new()
local stageFolder: Folder? = nil
local yaw, pitch, targetYaw, targetPitch = 0, 0, 0, 0
local dragging = false
local lastPos = Vector2.zero
local hiddenParts: { BasePart } = {}
local hiddenGuis: { ScreenGui } = {}
local openConnections: { RBXScriptConnection } = {}
local savedCamType: Enum.CameraType? = nil
local savedFov = 70
local dof: DepthOfFieldEffect? = nil
local gunBusy = false
local modBusy = false
local toast: TextLabel? = nil

local function find(parent: Instance, path: string): Instance
	local node: Instance = parent
	for name in string.gmatch(path, "[^%.]+") do
		node = node:WaitForChild(name, 10) :: Instance
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
-- a button's click (by path under `parent`)
local function onPress(parent: Instance, path: string, fn: () -> ())
	local button = find(parent, path) :: GuiButton
	button.Activated:Connect(fn)
end

local function guns(): GunLoadout.Loadout
	return PlayerData.guns(player)
end
local function mods(): ModLoadout.Loadout
	return PlayerData.mods(player)
end
local function coins(): number
	local c = StateValues.get(player, "Coins")
	return if typeof(c) == "number" then c else 0
end
local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function gunName(id: string): string
	local cfg = Weapons.get(id)
	return if cfg then cfg.displayName else id
end
local function equippedLine(gunId: string): string
	return Locker.equipped(player)[gunId] or "Stock"
end

-- A short message over the bottom bar (refusals: not enough coins, busy, ...).
local function say(text: string)
	local t = toast
	if not t then
		return
	end
	t.Text = text
	t.TextTransparency = 0
	t.Visible = true
	local token = os.clock()
	t:SetAttribute("At", token)
	task.delay(2.2, function()
		if t:GetAttribute("At") == token then
			t.Visible = false -- (its UIStroke would still show at TextTransparency 1)
		end
	end)
end

-- a chunky button's colours and words (the template's Bg.Fill gradient and Label)
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

-- stage ---------------------------------------------------------------------------------------------------------

local function hideLocal(root: Instance)
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.LocalTransparencyModifier < 1 then
			p.LocalTransparencyModifier = 1
			table.insert(hiddenParts, p)
		end
	end
end

local function nearStage(p: Vector3): boolean
	return (Vector3.new(p.X, 0, p.Z) - Vector3.new(STAGE.X, 0, STAGE.Z)).Magnitude < HIDE_RADIUS
end

-- Things between the camera and the wall: the plinth circle, the Armorer, the floating displays, characters.
local function clearShot()
	local lobby = workspace:FindFirstChild("LobbyV5")
	for _, name in { "GunCircle", "Armorer" } do
		local o = lobby and lobby:FindFirstChild(name, true)
		if o then
			hideLocal(o)
		end
	end
	local displays = workspace:FindFirstChild("LobbyGunDisplays")
	if displays then
		for _, m in displays:GetChildren() do
			if
				m:IsA("Model")
				and m:GetPivot().Position.X < 92
				and nearStage(m:GetPivot().Position)
			then
				hideLocal(m)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		local c = other.Character
		if c and c.PrimaryPart and nearStage(c.PrimaryPart.Position) then
			hideLocal(c)
		end
	end
end

local function showGun(id: string, line: string, isLocked: boolean)
	local folder = stageFolder
	if current then
		current:Destroy()
		current = nil
	end
	if not folder then
		return
	end
	local src = Locker.skinModel(id, line) or Locker.gunModel(id)
	if line ~= "Stock" and not Locker.skinModel(id, line) then
		SkinStore.want({ { line, SkinStore.modelName(id, line) } }) -- placed when it arrives
	end
	if not src then
		return
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if isLocked then
				d.LocalTransparencyModifier = 0.5
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	m:PivotTo(CFrame.new())
	local _, size = m:GetBoundingBox()
	m:ScaleTo(
		m:GetScale() * math.clamp(GUN_LENGTH / math.max(size.X, size.Y, size.Z, 0.3), 0.8, 2.3)
	)
	m:PivotTo(CFrame.new())
	local box = m:GetBoundingBox()
	centerOffset = CFrame.new(box.Position)
	m.Parent = folder
	current = m
	yaw = targetYaw - math.rad(50) -- a little swing in on every swap
end

local function cardPivot(): CFrame
	local camera = workspace.CurrentCamera
	local t = os.clock()
	local bob = CFrame.new(0, math.sin(t * 1.3) * 0.05, 0)
	local hoverYaw, hoverPitch = 0, 0
	if not dragging and UserInputService.MouseEnabled then
		local m = UserInputService:GetMouseLocation()
		local size = camera.ViewportSize
		hoverYaw = math.clamp((m.X / size.X - 0.5) * 2, -1, 1) * HOVER_YAW
		hoverPitch = math.clamp((m.Y / size.Y - 0.5) * 2, -1, 1) * HOVER_PITCH
	end
	local turn = CFrame.fromAxisAngle(Vector3.yAxis, yaw + hoverYaw)
		* CFrame.fromAxisAngle(Vector3.zAxis, pitch + hoverPitch)
	return CFrame.new(STAGE + CARD_LIFT) * bob * turn * CARD_REST
end

local function onRender(dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV
	camera.CFrame = CAMERA
	local a = 1 - math.exp(-dt * EASE)
	yaw += (targetYaw - yaw) * a
	pitch += (targetPitch - pitch) * a
	local c = card
	if mode == "powers" then
		if c then
			local cf = cardPivot()
			c:PivotTo(cf)
			local look = cf.LookVector
			if sweep then
				sweep.Offset = Vector2.new(math.clamp(look.Z * 1.6 - look.Y * 0.8, -0.9, 0.9), 0)
			end
		end
	else
		if c then
			c:PivotTo(CFrame.new(0, -500, 0))
		end
		if current then
			local t = os.clock()
			local bob = CFrame.new(0, math.sin(t * 1.2) * 0.04, 0)
				* CFrame.Angles(0, math.sin(t * 0.7) * 0.03, 0)
			local turn = CFrame.fromAxisAngle(Vector3.yAxis, yaw)
				* CFrame.fromAxisAngle(Vector3.zAxis, pitch)
			current:PivotTo(CFrame.new(STAGE) * bob * turn * GUN_REST * centerOffset:Inverse())
		end
	end
end

-- guns ------------------------------------------------------------------------------------------------------------

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
	set(panel, "Details.Slash", "BackgroundColor3", roleColor)
	label(panel, "Details.Blurb").Text = blurb
end

-- Overview: the gun's numbers as bars against the best in the active set.
local function fillOverview(id: string)
	local cfg = Weapons.get(id)
	if not cfg then
		return
	end
	local function dps(c: any): number
		return c.damage.body * (c.pellets or 1) / math.max(c.fireInterval, 0.01)
	end
	local best = { dps = 1, rate = 1, mag = 1 }
	for _, list in { LoadoutConfig.PRIMARIES, LoadoutConfig.SECONDARIES } do
		for _, gid in list do
			local g = Weapons.get(gid)
			if g then
				best.dps = math.max(best.dps, dps(g))
				best.rate = math.max(best.rate, 1 / g.fireInterval)
				best.mag = math.max(best.mag, g.magSize)
			end
		end
	end
	local c = cfg :: any
	local pellets = c.pellets or 1
	local stats = {
		{
			"DAMAGE",
			math.min(dps(c) / best.dps, 1),
			if pellets > 1
				then `{c.damage.body} × {pellets}`
				else `{c.damage.body} / {c.damage.head}`,
		},
		{
			"FIRE RATE",
			1 / c.fireInterval / best.rate,
			string.format("%.1f / s", 1 / c.fireInterval),
		},
		{
			"HANDLING",
			math.clamp(1 - (c.spread and c.spread.first or 1) / 2, 0.05, 1),
			string.format("%.2f° spread", c.spread and c.spread.first or 0),
		},
		{
			"MOBILITY",
			math.clamp((c.moveMultiplier or 1) / 1.05, 0.05, 1),
			string.format("%d%%", math.floor((c.moveMultiplier or 1) * 100 + 0.5)),
		},
		{
			"RELOAD",
			math.clamp(1.6 / math.max(c.reloadTime, 0.5), 0.05, 1),
			string.format("%.1f s", c.reloadTime),
		},
		{ "MAGAZINE", c.magSize / best.mag, tostring(c.magSize) },
	}
	local o = find(ownedPanel, "Overview")
	for i, r in stats do
		local n = o:FindFirstChild("N" .. i)
		local b = o:FindFirstChild("B" .. i)
		local v = o:FindFirstChild("V" .. i)
		if n and n:IsA("TextLabel") then
			n.Text = r[1]
		end
		local fill = b and b:FindFirstChild("Fill")
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.fromScale(math.clamp(r[2], 0.04, 1), 1)
		end
		if v and v:IsA("TextLabel") then
			v.Text = r[3]
		end
	end
end

local function refreshLoadoutCard()
	local g = guns()
	for slotName, id in { Primary = g.primary, Secondary = g.secondary } do
		local slot = find(left, "Guns.Loadout." .. slotName)
		set(slot, "Render", "Image", Theme.GUN[id] or "")
		set(slot, "Name", "Text", string.upper(gunName(id)))
	end
end

local function styleRow(row: GuiButton, on: boolean)
	local bg = row:FindFirstChild("Bg")
	if bg and bg:IsA("ImageLabel") then
		bg.ImageColor3 = if on then WHITE else PANEL
		bg.ImageTransparency = if on then 0.8 else 0.3
	end
	local sel = row:FindFirstChild("Sel")
	if sel and sel:IsA("GuiObject") then
		sel.Visible = on
	end
end

local function refreshGunRows()
	local g = guns()
	for id, row in rows do
		local owned = g.owned[id] == true
		local equipped = id == g.primary or id == g.secondary
		local tag = row:FindFirstChild("Equipped")
		if tag and tag:IsA("TextLabel") then
			tag.Visible = equipped
		end
		row:SetAttribute("Owned", owned)
		styleRow(row, id == selectedGun and mode ~= "knife")
	end
	local function count(list: { string }): number
		local n = 0
		for _, id in list do
			if g.owned[id] then
				n += 1
			end
		end
		return n
	end
	local list = find(left, "Guns.List")
	local hp = list:FindFirstChild("HeadPRIMARY")
	local hs = list:FindFirstChild("HeadSECONDARY")
	if hp then
		set(
			hp,
			"Count",
			"Text",
			`{count(LoadoutConfig.PRIMARIES)} / {#LoadoutConfig.PRIMARIES} OWNED`
		)
	end
	if hs then
		set(
			hs,
			"Count",
			"Text",
			`{count(LoadoutConfig.SECONDARIES)} / {#LoadoutConfig.SECONDARIES} OWNED`
		)
	end
	refreshLoadoutCard()
end

local refreshSkins: () -> ()

local function refreshGunPanel()
	local g = guns()
	local id = selectedGun
	local owned = g.owned[id] == true or mode == "knife"
	ownedPanel.Visible = owned
	lockedPanel.Visible = not owned
	powerPanel.Visible = false
	lockPlate.Visible = not owned
	local role = LoadoutConfig.ROLES[id]
	if mode == "knife" then
		setDetails(
			ownedPanel,
			"Knife",
			"MELEE · SKINS ONLY",
			CYAN,
			"Everyone carries one. Pick a skin to make it yours."
		)
	else
		setDetails(
			if owned then ownedPanel else lockedPanel,
			gunName(id),
			if role then role[1] else "",
			if owned then CYAN else LOCKED_ROLE,
			if role then role[2] else ""
		)
	end
	local equipHolder = find(ownedPanel, "Equip") :: Frame
	equipHolder.Visible = mode ~= "knife"
	local equipButton = find(equipHolder, "Button")
	if id == g.primary or id == g.secondary then
		paint(equipButton, DARK, "EQUIPPED", false)
	else
		paint(equipButton, GOLD, "EQUIP", true)
	end
	local actionsCard = find(ownedPanel, "Actions") :: Frame
	actionsCard.Visible = mode ~= "knife"
	if mode == "knife" then
		set(ownedPanel, "Overview", "Visible", false)
	end
	if not owned then
		local price = GunLoadout.price(id) or 0
		local buy = find(lockedPanel, "Unlock.Buy.Button")
		set(buy, "Label", "Text", commas(price))
		set(
			lockedPanel,
			"Unlock.Buy.Sub",
			"Text",
			if coins() >= price
				then "Yours forever, every mode"
				else `You need {commas(price - coins())} more coins`
		)
	end
	fillOverview(id)
	previewLine = if owned then equippedLine(id) else "Stock"
	showGun(id, previewLine, not owned)
	if stripOpen then
		refreshSkins()
	end
end

local function selectGun(id: string)
	if selectedGun ~= id then
		UiSfx.claim()
	end
	selectedGun = id
	refreshGunRows()
	refreshGunPanel()
end

-- skins: a strip of the owned skins for the gun on the stage (Locker v4's tray, simpler) --------------------------

local function ownedLines(gunId: string): { string }
	local skins = PlayerData.skins(player)
	local out: { string } = {}
	for _, line in Locker.linesFor(gunId) do
		if PlayerData.owns(skins, gunId, line) then
			table.insert(out, line)
		end
	end
	return out
end

refreshSkins = function()
	for _, t in skinTiles do
		t:Destroy()
	end
	table.clear(skinTiles)
	local gunId = if mode == "knife" then "Knife" else selectedGun
	local on = equippedLine(gunId)
	local tpl = find(skinStrip, "Template") :: GuiButton
	for i, line in ownedLines(gunId) do
		local t = tpl:Clone()
		t.Name = line
		t.LayoutOrder = i
		t.Visible = true
		set(t, "Name", "Text", string.upper(if line == "Stock" then "Default" else line))
		set(t, "Art", "Image", SkinArt.side(gunId, line) or Theme.GUN[gunId] or "")
		set(t, "On", "Visible", line == on)
		local bg = t:FindFirstChild("Bg")
		if bg and bg:IsA("ImageLabel") then
			bg.ImageColor3 = if line == previewLine then WHITE else PANEL
			bg.ImageTransparency = if line == previewLine then 0.8 else 0.25
		end
		t.Activated:Connect(function()
			previewLine = line
			showGun(gunId, line, false)
			if line ~= equippedLine(gunId) then
				LobbyNet.event("LockerRequest"):FireServer("equip", gunId, line)
			end
			refreshSkins()
		end)
		t.Parent = skinStrip
		table.insert(skinTiles, t)
	end
end

local function setStrip(open: boolean)
	stripOpen = open
	skinStrip.Visible = open
	set(bottom, "Hint", "Visible", not open)
	if open then
		refreshSkins()
	end
end

-- powers -----------------------------------------------------------------------------------------------------------

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

local function fillCard(id: string, owned: boolean)
	local f = front
	local c = card
	local def = Mods.def(id)
	if not (f and c and def) then
		return
	end
	local roleColor = Theme.ROLE[def.role] or WHITE
	set(f, "Art", "Image", Theme.CARD_ART[id] or "")
	set(f, "Band", "BackgroundColor3", roleColor)
	set(f, "Title", "Text", string.upper(def.name))
	set(f, "Role", "Text", string.upper(def.role))
	set(f, "Note", "Text", ((def.levels.L1 :: any).note or "") .. ".")
	set(f, "Level", "Text", if owned then "" else "POWER CASE")
	local back = c:FindFirstChild("Back", true)
	local backCard = back and back:FindFirstChild("Card")
	if backCard then
		set(backCard, "Band", "BackgroundColor3", roleColor)
	end
	local edge = c:FindFirstChild("Edge")
	if edge and edge:IsA("BasePart") then
		edge.Color = roleColor
	end
end

local function refreshDeck()
	local m = mods()
	local deck = find(left, "Powers.Deck")
	local i = 0
	for _, id in ModsConfig.ORDER do
		if m.equipped[id] and Mods.isBuilt(id) then
			i += 1
			local slot = deck:FindFirstChild("Slot" .. i)
			local def = Mods.def(id)
			if slot and def then
				set(slot, "Art", "Image", Theme.CARD_ART[id] or "")
				set(slot, "Band", "Visible", true)
				set(slot, "Band", "BackgroundColor3", Theme.ROLE[def.role] or WHITE)
				set(slot, "Name", "Text", string.upper(def.name))
				set(slot, "Plus", "Visible", false)
			end
		end
	end
	for j = i + 1, ModsConfig.DECK_SIZE do
		local slot = deck:FindFirstChild("Slot" .. j)
		if slot then
			set(slot, "Art", "Image", "")
			set(slot, "Band", "Visible", false)
			set(slot, "Name", "Text", "")
			set(slot, "Plus", "Visible", true)
		end
	end
	set(deck, "Count", "Text", `{i} / {ModsConfig.DECK_SIZE}`)
	local owned = 0
	for id, tile in tiles do
		local has = m.owned[id] == true
		if has then
			owned += 1
		end
		local tag = tile:FindFirstChild("InDeck")
		if tag and tag:IsA("GuiObject") then
			tag.Visible = m.equipped[id] == true
		end
	end
	local head = find(left, "Powers.List"):FindFirstChild("HeadALL POWERS")
	if head then
		local n = 0
		for _ in tiles do
			n += 1
		end
		set(head, "Count", "Text", `{owned} / {n} OWNED`)
	end
end

local function refreshPowerPanel()
	local id = selectedPower
	local def = Mods.def(id)
	if not def then
		return
	end
	local m = mods()
	local owned = m.owned[id] == true
	local roleColor = Theme.ROLE[def.role] or WHITE
	fillCard(id, owned)
	setDetails(
		powerPanel,
		def.name,
		string.upper(def.role) .. (if owned then "" else " · LOCKED"),
		roleColor,
		((def.levels.L1 :: any).note or "") .. "."
	)
	for _, p in { "A", "B", "G" } do
		set(
			powerPanel,
			"Paths.Path" .. p .. ".Name",
			"Text",
			string.upper((def.paths :: any)[p] or "")
		)
		set(powerPanel, "Paths.Path" .. p .. ".Note", "Text", pathNote(def, p))
		if p ~= "G" then
			set(powerPanel, "Paths.Path" .. p .. ".Chip", "BackgroundColor3", roleColor)
		end
	end
	local b = find(powerPanel, "DeckButton.Button")
	if not owned then
		paint(b, DARK, "FROM POWER CASES", false)
	elseif m.equipped[id] then
		paint(
			b,
			DARK,
			if ModLoadout.canUnequip(m, id) then "IN DECK · REMOVE" else "IN DECK",
			false
		)
	else
		paint(b, GOLD, if ModLoadout.canEquip(m, id) then "ADD TO DECK" else "DECK FULL", true)
	end
	for tid, tile in tiles do
		local sel = tile:FindFirstChild("Sel")
		if sel and sel:IsA("GuiObject") then
			sel.Visible = tid == id
		end
	end
end

local function selectPower(id: string, spin: boolean)
	selectedPower = id
	refreshPowerPanel()
	if spin then
		yaw = targetYaw - 2 * math.pi -- a fresh card flips in: one full turn into place
	end
end

-- tabs -------------------------------------------------------------------------------------------------------------

local function setMode(newMode: Mode)
	mode = newMode
	local tabName = if newMode == "guns"
		then "GUNS"
		elseif newMode == "powers" then "POWERS"
		else "KNIFE"
	for _, b in find(top, "Tabs"):GetChildren() do
		if b:IsA("GuiButton") then
			local active = b:GetAttribute("Tab") == tabName
			paint(b, if active then LIGHT else DARK, b:GetAttribute("Tab") :: string, active)
			local bg = b:FindFirstChild("Bg")
			if bg and bg:IsA("ImageLabel") then
				bg.ImageTransparency = if active then 0 else 0.3
			end
		end
	end
	local gunsMode = newMode ~= "powers"
	set(left, "Guns", "Visible", gunsMode)
	set(left, "Powers", "Visible", not gunsMode)
	set(bottom, "GunBar", "Visible", gunsMode)
	set(bottom, "PowerBar", "Visible", not gunsMode)
	targetYaw, targetPitch = 0, 0
	setStrip(false)
	if gunsMode then
		if newMode == "knife" then
			selectedGun = "Knife"
		elseif not GunLoadout.slotOf(selectedGun) then
			selectedGun = guns().primary
		end
		refreshGunRows()
		refreshGunPanel()
	else
		if current then
			current:Destroy()
			current = nil
		end
		ownedPanel.Visible = false
		lockedPanel.Visible = false
		lockPlate.Visible = false
		powerPanel.Visible = true
		refreshDeck()
		if selectedPower == "" or not tiles[selectedPower] then
			for _, id in ModsConfig.ORDER do
				if tiles[id] then
					selectedPower = id
					break
				end
			end
		end
		selectPower(selectedPower, true)
	end
end

local function refreshCoins()
	local amount = find(gui, "TopRight.Coins.Amount") :: TextLabel
	amount.Text = commas(coins())
end

-- open / close -------------------------------------------------------------------------------------------------------

local function hideOthers()
	for _, g in player.PlayerGui:GetChildren() do
		if
			g:IsA("ScreenGui")
			and g ~= gui
			and g.Enabled
			and g.Name ~= "LockerWipe"
			and not g:GetAttribute("KeepWithLocker")
		then
			g.Enabled = false
			if not table.find(hiddenGuis, g) then
				table.insert(hiddenGuis, g)
			end
		end
	end
end

local function fit()
	local s = gui.AbsoluteSize.Y / 1080
	for _, c in gui:GetChildren() do
		local u = c:FindFirstChild("Fit")
		if u and u:IsA("UIScale") then
			u.Scale = s
		end
	end
end

local function open(arg: any?)
	if isOpen then
		return
	end
	isOpen = true
	UiSfx.cue("LockerIn")
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(STAGE)
		end)
	end)
	local src = ReplicatedStorage:FindFirstChild("LockerV3Stage")
	local folder = Instance.new("Folder")
	folder.Name = "LockerV3Stage"
	local cardSrc = src and src:FindFirstChild("PowerCard")
	if cardSrc and cardSrc:IsA("Model") then
		local c = cardSrc:Clone()
		c.Parent = folder
		card = c
		local face = c:FindFirstChild("Face")
		local f = face and face:FindFirstChild("Front")
		local fc = f and f:FindFirstChild("Card")
		front = if fc and fc:IsA("Frame") then fc else nil
		local shine = fc and fc:FindFirstChild("Shine")
		local sw = shine and shine:FindFirstChild("Sweep")
		sweep = if sw and sw:IsA("UIGradient") then sw else nil
		c:PivotTo(CFrame.new(0, -500, 0))
	end
	folder.Parent = workspace
	stageFolder = folder
	local camera = workspace.CurrentCamera
	savedCamType = camera.CameraType
	savedFov = camera.FieldOfView
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "LockerV3Focus"
	d.FarIntensity = 0.75
	d.NearIntensity = 0
	d.FocusDistance = 0.1
	d.InFocusRadius = 15
	d.Parent = Lighting
	dof = d
	clearShot()
	RunService:BindToRenderStep("LockerV3", Enum.RenderPriority.Last.Value, onRender)
	gui.Enabled = true
	fit()
	hideOthers()
	table.insert(openConnections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	table.insert(
		openConnections,
		RunService.Heartbeat:Connect(function()
			-- other screens that come back on while the Locker is open (HUD refreshes) and players walking in
			hideOthers()
		end)
	)
	selectedGun = guns().primary
	refreshCoins()
	setMode(if arg == "powers" then "powers" else "guns")
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	UiSfx.cue("LockerOut")
	RunService:UnbindFromRenderStep("LockerV3")
	for _, c in openConnections do
		c:Disconnect()
	end
	table.clear(openConnections)
	for _, p in hiddenParts do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	table.clear(hiddenParts)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	if dof then
		dof:Destroy()
		dof = nil
	end
	if stageFolder then
		stageFolder:Destroy()
		stageFolder = nil
	end
	current, card, front, sweep = nil, nil, nil, nil
	dragging = false
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	camera.FieldOfView = savedFov
	camera.CameraType = savedCamType or Enum.CameraType.Custom
	savedCamType = nil
end

-- build the lists from the templates ------------------------------------------------------------------------------------

local function buildGunRows()
	local list = find(left, "Guns.List") :: ScrollingFrame
	local ownedTpl = find(list, "RowOwned") :: GuiButton
	local lockedTpl = find(list, "RowLocked") :: GuiButton
	ownedTpl.Visible, lockedTpl.Visible = false, false
	local headP = list:FindFirstChild("HeadPRIMARY") :: GuiObject?
	local headS = list:FindFirstChild("HeadSECONDARY") :: GuiObject?
	local order = 0
	local g = guns()
	local function add(id: string)
		order += 1
		local owned = g.owned[id] == true
		local row = (if owned then ownedTpl else lockedTpl):Clone()
		row.Name = "Row" .. id
		row.LayoutOrder = order
		row.Visible = true
		row:SetAttribute("Gun", id)
		set(row, "Render", "Image", Theme.GUN[id] or "")
		set(row, "Name", "Text", string.upper(gunName(id)))
		if owned then
			local lv = row:FindFirstChild("Level")
			if lv and lv:IsA("GuiObject") then
				lv.Visible = false -- weapon levels: build order step 3
			end
		else
			local price = row:FindFirstChild("Price")
			if price and price:IsA("TextLabel") then
				price.Text = commas(GunLoadout.price(id) or 0)
			end
		end
		row.Activated:Connect(function()
			if mode == "knife" then
				setMode("guns")
			end
			selectGun(id)
		end)
		row.Parent = list
		rows[id] = row
	end
	if headP then
		order += 1
		headP.LayoutOrder = order
	end
	for _, id in LoadoutConfig.PRIMARIES do
		add(id)
	end
	if headS then
		order += 1
		headS.LayoutOrder = order
	end
	for _, id in LoadoutConfig.SECONDARIES do
		add(id)
	end
end

-- Rows were built for the ownership at open time: an unlock swaps that gun's row for the owned look.
local function rebuildGunRows()
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
	buildGunRows()
end

local function buildTiles()
	local grid = find(left, "Powers.List.Grid")
	local ownedTpl = find(grid, "TileOwned") :: GuiButton
	local lockedTpl = find(grid, "TileLocked") :: GuiButton
	ownedTpl.Visible, lockedTpl.Visible = false, false
	for _, t in tiles do
		t:Destroy()
	end
	table.clear(tiles)
	local m = mods()
	for i, id in ModsConfig.ORDER do
		local def = Mods.def(id)
		if not def or not Mods.isBuilt(id) then
			continue
		end
		local owned = m.owned[id] == true or def.free == true
		local roleColor = Theme.ROLE[def.role] or WHITE
		local t = (if owned then ownedTpl else lockedTpl):Clone()
		t.Name = "Tile" .. id
		t.LayoutOrder = i
		t.Visible = true
		set(t, "Art", "Image", Theme.CARD_ART[id] or "")
		set(t, "Name", "Text", string.upper(def.name))
		if owned then
			set(t, "Band", "BackgroundColor3", roleColor)
			set(t, "Sub", "Text", string.upper(def.role))
			set(t, "Sub", "TextColor3", roleColor)
			local lv = t:FindFirstChild("Level")
			if lv and lv:IsA("GuiObject") then
				lv.Visible = false -- power levels: build order step 3
			end
		end
		t.Activated:Connect(function()
			selectPower(id, true)
		end)
		t.Parent = grid
		tiles[id] = t
	end
end

-- requests -----------------------------------------------------------------------------------------------------------------

local function requestGun(action: string, id: string)
	if gunBusy then
		return
	end
	gunBusy = true
	LobbyNet.event("LockerGunRequest"):FireServer(action, id)
	task.delay(5, function()
		gunBusy = false -- a reply that never came never locks the buttons
	end)
end

local REASONS: { [string]: string } = {
	coins = "Not enough coins",
	busy = "Not now: a match is starting",
	loading = "Still loading your save",
	slow = "Too fast, try again",
	notOwned = "You don't own that gun yet",
	owned = "Already yours",
}

local function onGunReply(action: unknown, id: unknown, ok: unknown, reason: unknown)
	gunBusy = false
	if not isOpen then
		return
	end
	if ok == true then
		if action == "unlock" then
			UiSfx.cue("Purchase")
			rebuildGunRows()
			say(`{string.upper(gunName(if typeof(id) == "string" then id else ""))} UNLOCKED`)
		end
		refreshGunRows()
		refreshGunPanel()
	elseif reason ~= "same" then
		say(
			REASONS[if typeof(reason) == "string" then reason else ""]
				or "Couldn't save that, try again"
		)
	end
end

-- init -------------------------------------------------------------------------------------------------------------------------

function LockerV3Controller.start()
	if not LobbyConfig.LOCKER_V3 then
		return
	end
	local g = player:WaitForChild("PlayerGui"):WaitForChild("LockerV3", 20)
	if not (g and g:IsA("ScreenGui")) then
		warn(
			"[LockerV3] StarterGui.LockerV3 missing (tools/studio/BuildLockerV3.luau + PromoteLockerV3.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	gui.ResetOnSpawn = false
	left = find(gui, "Left") :: Frame
	right = find(gui, "Right") :: Frame
	top = find(gui, "Top") :: Frame
	bottom = find(gui, "Bottom") :: Frame
	center = find(gui, "Center") :: Frame
	local stack = find(right, "Stack")
	ownedPanel = find(stack, "GunOwned") :: Frame
	lockedPanel = find(stack, "GunLocked") :: Frame
	powerPanel = find(stack, "Power") :: Frame
	lockPlate = find(center, "Lock") :: Frame
	skinStrip = find(bottom, "Skins") :: ScrollingFrame
	skinStrip.Visible = false
	local t = bottom:FindFirstChild("Toast")
	toast = if t and t:IsA("TextLabel") then t else nil
	if toast then
		toast.Visible = false
	end
	skinStrip.Position = UDim2.new(0.5, 0, 0, 30) -- above the round buttons, over the drag hint (hidden while open)

	-- not built yet (build order step 3): levels, contracts, statistics, power previews; charms and kill FX
	for _, path in
		{
			"Level",
			"Actions.Contracts",
			"Actions.Statistics",
		}
	do
		set(ownedPanel, path, "Visible", false)
	end
	set(powerPanel, "Level", "Visible", false)
	set(powerPanel, "Actions", "Visible", false)
	set(bottom, "GunBar.Charm", "Visible", false)
	set(bottom, "GunBar.KillFx", "Visible", false)
	-- two round buttons left (Back, Skin): centre them like the powers bar
	set(bottom, "GunBar", "Position", (find(bottom, "PowerBar") :: GuiObject).Position)
	set(ownedPanel, "Actions.OverviewRow.Sub", "Text", "Damage, fire rate, handling")
	set(lockedPanel, "Actions.OverviewRow.Sub", "Text", "Damage, fire rate, handling")
	local actions = find(ownedPanel, "Actions") :: Frame
	actions.Size = UDim2.fromOffset(actions.Size.X.Offset, 88)
	set(actions, "OverviewRow", "Position", UDim2.fromOffset(0, 8))
	local overviewLine = find(actions, "OverviewRow"):FindFirstChild("Line")
	if overviewLine and overviewLine:IsA("GuiObject") then
		overviewLine.Visible = false
	end

	buildGunRows()
	buildTiles()

	Router.register("Locker", { open = open, close = close, screen = "LockerV3", clear = true })

	-- tabs
	for _, b in find(top, "Tabs"):GetChildren() do
		if b:IsA("GuiButton") then
			b.Activated:Connect(function()
				local tab = b:GetAttribute("Tab")
				setMode(
					if tab == "POWERS" then "powers" elseif tab == "KNIFE" then "knife" else "guns"
				)
			end)
		end
	end
	-- EQUIP / UNLOCK / TRY
	onPress(ownedPanel, "Equip.Button", function()
		local g2 = guns()
		if
			mode == "guns"
			and g2.owned[selectedGun]
			and selectedGun ~= g2.primary
			and selectedGun ~= g2.secondary
		then
			requestGun("equip", selectedGun)
		end
	end)
	onPress(lockedPanel, "Unlock.Buy.Button", function()
		local price = GunLoadout.price(selectedGun)
		if price and coins() < price then
			say(REASONS.coins)
			return
		end
		requestGun("unlock", selectedGun)
	end)
	onPress(lockedPanel, "Unlock.Try.Button", function()
		Router.close()
		Router.open("Range")
	end)
	-- Overview opens / closes its bars (owned and locked panels share one Overview, on the owned panel)
	for _, panel in { ownedPanel, lockedPanel } do
		onPress(panel, "Actions.OverviewRow.Button", function()
			local o = find(ownedPanel, "Overview") :: Frame
			o.Visible = not o.Visible
		end)
	end
	-- the deck
	onPress(powerPanel, "DeckButton.Button", function()
		local m = mods()
		local id = selectedPower
		if modBusy or not m.owned[id] then
			if not m.owned[id] then
				say("Powers come from power cases")
			end
			return
		end
		local equip = not m.equipped[id]
		if equip and not ModLoadout.canEquip(m, id) then
			say("Your deck is full")
			return
		elseif not equip and not ModLoadout.canUnequip(m, id) then
			say(`Keep at least {ModsConfig.DECK_MIN} powers in your deck`)
			return
		end
		modBusy = true
		LobbyNet.event("LockerModRequest"):FireServer(id, equip)
	end)
	LobbyNet.event("LockerModRequest").OnClientEvent:Connect(function(saved: unknown)
		modBusy = false
		if saved ~= true and isOpen then
			say("Couldn't save your deck, try again")
		end
	end)
	LobbyNet.event("LockerGunRequest").OnClientEvent:Connect(onGunReply)
	-- the bottom bar
	for _, path in { "GunBar.Back.Button", "PowerBar.Back.Button" } do
		onPress(bottom, path, function()
			if stripOpen then
				setStrip(false)
			else
				Router.close()
			end
		end)
	end
	onPress(bottom, "GunBar.Skin.Button", function()
		local g2 = guns()
		if mode == "knife" or g2.owned[selectedGun] then
			setStrip(not stripOpen)
		end
	end)
	onPress(bottom, "PowerBar.Flip.Button", function()
		targetYaw += math.pi
	end)

	-- live data: the save's guns / deck / skins / coins
	local function onData()
		if not isOpen then
			return
		end
		if mode == "powers" then
			buildTiles()
			refreshDeck()
			refreshPowerPanel()
		else
			refreshGunRows()
			if stripOpen then
				refreshSkins()
			end
		end
	end
	task.spawn(function()
		for _, name in { PlayerData.GUNS, PlayerData.MODS, PlayerData.SKINS } do
			local v = player:WaitForChild(name, 60)
			if v and v:IsA("StringValue") then
				v.Changed:Connect(onData)
			end
		end
	end)
	StateValues.changed(player, "Coins"):Connect(function()
		if isOpen then
			refreshCoins()
			if mode ~= "powers" then
				refreshGunPanel() -- the unlock card's "you need N more coins"
			end
		end
	end)
	Locker.observe(player, function()
		if isOpen and stripOpen then
			refreshSkins()
		end
	end)
	SkinStore.arrived:Connect(function(line: string, name: string)
		if
			isOpen
			and mode ~= "powers"
			and line == previewLine
			and name == SkinStore.modelName(selectedGun, line)
		then
			showGun(selectedGun, line, false)
		end
	end)
	-- turning: grab the stage (anywhere off the panels) and drag
	local dragZone = find(gui, "DragZone") :: GuiButton
	dragZone.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			lastPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not (isOpen and dragging) then
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
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
			targetPitch = 0
			local step = if mode == "powers" then math.pi else 2 * math.pi -- a card settles on its nearer face
			targetYaw = math.round(targetYaw / step) * step
		end
	end)
end

function LockerV3Controller.isOpen(): boolean
	return isOpen
end

return LockerV3Controller
