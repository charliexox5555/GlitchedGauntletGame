--!strict
-- The Locker v3 (vault/01 Design/Loadout and Power Deck.md → "Locker v3 mockup" and "Step 2 plan"; owner
-- 2026-11-26: "Yes, this direction"). RIVALS' weapon-page structure in our style:
--   * the stage is its own copy of the lobby's Locker room, 3,000 studs away where nobody walks
--     (Workspace.LockerV3Room, tools/studio/BuildLockerRoom.luau; owner 2026-11-26: "I can walk around and see
--     myself in the locker"): the camera at FOV 20 with depth of field on the armoury wall, the gun (in its
--     equipped skin) or the power card floating in the middle. Opening rises the camera behind a wipe (as v4 did).
--   * GUNS: the loadout card, the Primary and Secondary lists (Config/Loadout), EQUIP / UNLOCK (coins) /
--     TRY IN THE RANGE through LockerGunRequest (Services/LockerService; an unlock asks first in a confirm
--     window), SKIN opens a strip of EVERY skin of that gun: owned ones equip (LockerRequest), the rest preview
--     with their tier so players see what they work towards. Overview shows the gun's numbers (Config/Weapons).
--   * POWERS: the deck of 10 and every power; the power is a real 3D card (the draft card's face, the logo on
--     the back, a coloured edge) that leans toward the mouse, turns when dragged and flips; ADD TO DECK /
--     REMOVE through LockerModRequest.
--   * KNIFE: the knife and its skins.
-- The screen is Studio-built (StarterGui.LockerV3; the build script tools/studio/BuildLockerV3.luau, then
-- tools/studio/PromoteLockerV3.luau turned the mockup into templates: RowOwned / RowLocked, TileOwned /
-- TileLocked); the card is ReplicatedStorage.LockerV3Stage.PowerCard. This module fills and moves them.
-- Not yet (build order step 3): weapon levels, contracts, statistics; their rows stay hidden.

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local InputMode = require(ReplicatedStorage.Shared.InputMode)
local LoadoutConfig = require(ReplicatedStorage.Shared.Config.Loadout)
local LobbyConfig = require(ReplicatedStorage.Lobby.Config)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local Mods = require(ReplicatedStorage.Shared.Mods)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local SkinsConfig = require(ReplicatedStorage.Shared.Config.Skins)
local SkinStore = require(ReplicatedStorage.Shared.SkinStore)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local RangeTransition = require(script.Parent.Parent.Util.RangeTransition)
local PowerCardFace = require(script.Parent.Parent.Util.PowerCardFace)
local Router = require(script.Parent.Parent.Util.Router)
local ArmedHideController = require(script.Parent.ArmedHideController)

local LockerV3Controller = {}

local player = Players.LocalPlayer

-- the stage (the lobby Locker room, LobbyV5.Shell.Locker; camera looking +X, screen right = +Z)
local ROOM_OFFSET = Vector3.new(0, 0, -3000) -- tools/studio/BuildLockerRoom.luau OFFSET
local STAGE = Vector3.new(80, 6.6, -1600) + ROOM_OFFSET
local CAMERA = CFrame.lookAt(
	Vector3.new(67, 7.8, -1600) + ROOM_OFFSET,
	Vector3.new(80, 6.8, -1600) + ROOM_OFFSET
)
local FOV = 20
local RISE, RISE_TIME = 14, 0.32 -- the camera lifts off as the wipe comes up (Locker v4's open)
local WIPE_IN, WIPE_OUT = 0.72, 0.6
local GUN_LENGTH = 4.1 -- every gun is scaled to about this long (pistols read as big as rifles)
local GUN_REST = CFrame.Angles(0, math.rad(14), 0)
	* CFrame.Angles(math.rad(-24), 0, 0)
	* CFrame.Angles(0, math.pi, 0)
local CARD_REST = CFrame.Angles(0, math.rad(90 - 12), 0)
local CARD_LIFT = Vector3.new(0, 0.3, 0)
local DRAG_YAW = math.rad(0.35) -- per pixel
local DRAG_PITCH = math.rad(0.3)
local STICK_YAW = math.rad(220) -- per second at full right-stick tilt
local STICK_DEAD = 0.2 -- right-stick dead zone
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
local overviewCard: Frame
local lockPlate: Frame
local skinStrip: ScrollingFrame
local card: Model? = nil
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
local wipe: Frame? = nil
local passToken = 0
local confirmFrame: Frame? = nil
local confirmGun = ""
local confirmReturn: GuiObject? = nil -- the UNLOCK button: a controller's selection returns here
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

-- feel: hover and press ------------------------------------------------------------------------------------------------

-- A chunky or round button grows a little on hover and dips on press, from its centre (memory: pops scale from
-- the centre). Its anchor moves to the centre first, keeping it where it was.
local function juice(b: GuiButton)
	if b:GetAttribute("Juiced") then
		return
	end
	b:SetAttribute("Juiced", true)
	local a = b.AnchorPoint
	local size = b.Size
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = b.Position
		+ UDim2.new(
			size.X.Scale * (0.5 - a.X),
			size.X.Offset * (0.5 - a.X),
			size.Y.Scale * (0.5 - a.Y),
			size.Y.Offset * (0.5 - a.Y)
		)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = b
	UiMotion.button(b, pop, function() end, { hover = 1.05 })
end

-- A list row or tile brightens under the mouse (rows sit in layouts, so they don't move).
local function hoverTint(b: GuiButton)
	b.MouseEnter:Connect(function()
		local bg = b:FindFirstChild("Bg")
		if bg and bg:IsA("ImageLabel") and bg.ImageColor3 == PANEL then
			UiMotion.tween(bg, 0.12, { ImageTransparency = 0.12 })
		elseif b.BackgroundTransparency < 1 then
			UiMotion.tween(b, 0.12, { BackgroundColor3 = Color3.fromHex("24242A") })
		end
	end)
	b.MouseLeave:Connect(function()
		local bg = b:FindFirstChild("Bg")
		if bg and bg:IsA("ImageLabel") and bg.ImageColor3 == PANEL then
			UiMotion.tween(bg, 0.12, { ImageTransparency = 0.3 })
		elseif b.BackgroundTransparency < 1 then
			UiMotion.tween(b, 0.12, { BackgroundColor3 = Color3.fromHex("141418") })
		end
	end)
end

-- stage ---------------------------------------------------------------------------------------------------------

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
	-- Average seconds per round: a burst gun's rounds come `burst.interval` apart, then the gap.
	local function interval(c: any): number
		local b = c.burst
		if b then
			return (c.fireInterval + (b.count - 1) * b.interval) / b.count
		end
		return c.fireInterval
	end
	local function dps(c: any): number
		return c.damage.body * (c.pellets or 1) / math.max(interval(c), 0.01)
	end
	local best = { dps = 1, rate = 1, mag = 1 }
	for _, list in { LoadoutConfig.PRIMARIES, LoadoutConfig.SECONDARIES } do
		for _, gid in list do
			local g = Weapons.get(gid)
			if g then
				best.dps = math.max(best.dps, dps(g))
				best.rate = math.max(best.rate, 1 / interval(g))
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
			1 / interval(c) / best.rate,
			string.format("%.1f / s", 1 / interval(c)),
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
	local o = overviewCard
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

local rebuildGunRows: () -> ()

local function refreshGunRows()
	local g = guns()
	-- A row is cloned from the owned or the locked template. The rows are built when the Locker loads, which
	-- can be before the save arrives (the starter pair only), so a gun owned since then rebuilds them; without
	-- this an equipped gun showed LOCKED and its price.
	for id, row in rows do
		if row:GetAttribute("BuiltOwned") ~= (g.owned[id] == true) then
			rebuildGunRows()
			break
		end
	end
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
		overviewCard.Visible = false
	end
	-- one Overview card, under whichever gun panel shows
	overviewCard.Parent = if owned then ownedPanel else lockedPanel
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
		UiMotion.slideIn(find(right, "Stack") :: GuiObject, 28, 0, 0, 0.24)
	end
	selectedGun = id
	refreshGunRows()
	refreshGunPanel()
end

-- skins: a strip of the owned skins for the gun on the stage (Locker v4's tray, simpler) --------------------------

-- Every skin of the gun: owned ones first (Locker order), then the rest by tier, so players see what's out there.
local function skinLines(gunId: string): { { line: string, owned: boolean } }
	local skins = PlayerData.skins(player)
	local owned, locked = {}, {}
	for _, line in Locker.linesFor(gunId) do
		if PlayerData.owns(skins, gunId, line) then
			table.insert(owned, { line = line, owned = true })
		else
			table.insert(locked, { line = line, owned = false })
		end
	end
	local function order(line: string): number
		local tier = SkinCases.tierOf(gunId, line)
		local def = tier and SkinsConfig.TIERS[tier]
		return if def then def.order else 99
	end
	table.sort(locked, function(a, b)
		local oa, ob = order(a.line), order(b.line)
		if oa ~= ob then
			return oa < ob
		end
		return a.line < b.line
	end)
	for _, e in locked do
		table.insert(owned, e)
	end
	return owned
end

local function skinGun(): string
	return if mode == "knife" then "Knife" else selectedGun
end

refreshSkins = function()
	for _, t in skinTiles do
		t:Destroy()
	end
	table.clear(skinTiles)
	local gunId = skinGun()
	local gunOwned = mode == "knife" or guns().owned[gunId] == true
	local on = equippedLine(gunId)
	local tpl = find(skinStrip, "Template") :: GuiButton
	for i, e in skinLines(gunId) do
		local line = e.line
		local t = tpl:Clone()
		t.Name = line
		t.LayoutOrder = i
		t.Visible = true
		set(t, "Name", "Text", string.upper(if line == "Stock" then "Default" else line))
		set(t, "Name", "TextTransparency", if e.owned then 0 else 0.35)
		set(t, "Art", "Image", SkinArt.side(gunId, line) or Theme.GUN[gunId] or "")
		set(t, "Art", "ImageTransparency", if e.owned then 0 else 0.45)
		set(t, "On", "Visible", e.owned and gunOwned and line == on)
		local tier = if line == "Stock" then nil else SkinCases.tierOf(gunId, line)
		local tierDef = tier and SkinsConfig.TIERS[tier]
		local tierLabel = t:FindFirstChild("Tier")
		if tierLabel and tierLabel:IsA("TextLabel") then
			tierLabel.Visible = tierDef ~= nil
			tierLabel.Text = if tierDef then tierDef.name else ""
			tierLabel.TextColor3 = if tierDef then tierDef.color else WHITE
		end
		local lock = t:FindFirstChild("Lock")
		if lock and lock:IsA("GuiObject") then
			lock.Visible = not e.owned
		end
		local bg = t:FindFirstChild("Bg")
		if bg and bg:IsA("ImageLabel") then
			bg.ImageColor3 = if line == previewLine then WHITE else PANEL
			bg.ImageTransparency = if line == previewLine then 0.8 else 0.25
		end
		t.Activated:Connect(function()
			previewLine = line
			showGun(gunId, line, not gunOwned)
			if e.owned and gunOwned and line ~= equippedLine(gunId) then
				LobbyNet.event("LockerRequest"):FireServer("equip", gunId, line)
			elseif not e.owned then
				local where = if tierDef and not tierDef.inCases then "bundles" else "skin cases"
				say(`{if tierDef then tierDef.name else "SKIN"} · from {where}`)
			end
			refreshSkins()
		end)
		hoverTint(t)
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
		UiMotion.slideIn(skinStrip, 0, 40, 0, 0.26)
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
	local c = card
	if c then
		PowerCardFace.fill(c, id, if owned then "" else "POWER PACK")
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
		paint(b, GOLD, "OPEN POWER PACKS", true)
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
	if selectedPower ~= id then
		UiMotion.slideIn(find(right, "Stack") :: GuiObject, 28, 0, 0, 0.24)
	end
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
	-- the new tab's list and cards come in from their sides
	UiMotion.slideIn(find(left, if gunsMode then "Guns" else "Powers") :: GuiObject, -40, 0, 0, 0.3)
	UiMotion.slideIn(find(right, "Stack") :: GuiObject, 40, 0, 0.03, 0.3)
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

-- Phones (vault/02 Art/UI Device Check 2026-11-27.md): the screen is edge to edge (ScreenInsets None, so the stage
-- and shades cover the notch), but the panels keep to the device safe area, and the left column starts under
-- Roblox's top-bar buttons (on a 401 px tall phone its loadout card sat under them). Desktop is unchanged.
local LIST_TOP, LIST_BOTTOM = 96, 1056 -- design px: the left column's content (Loadout / Deck to the list's foot)
local EDGE_GAP = 6 -- px between Roblox's buttons and our panels
local function place(obj: GuiObject, pos: UDim2)
	StateValues.set(obj, "Home", pos) -- UiMotion.slideIn eases to the home
	obj.Position = pos
end
local function fit()
	local size = gui.AbsoluteSize
	local s = size.Y / 1080
	for _, c in gui:GetChildren() do
		local u = c:FindFirstChild("Fit")
		if u and u:IsA("UIScale") then
			u.Scale = s
		end
	end
	-- the safe area and Roblox's buttons, in this screen's pixels
	local full = GuiService:GetInsetArea(Enum.ScreenInsets.None)
	local safe = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
	local padL, padR = math.max(safe.Min.X - full.Min.X, 0), math.max(full.Max.X - safe.Max.X, 0)
	local padT, padB = math.max(safe.Min.Y - full.Min.Y, 0), math.max(full.Max.Y - safe.Max.Y, 0)
	local inset = GuiService.TopbarInset
	local guiTop = full.Min.Y + GuiService:GetGuiInset().Y -- TopbarInset is screen pixels
	local barBottom = if inset.Height > 0 then inset.Max.Y - guiTop else padT
	local barRight = if inset.Height > 0 then inset.Min.X - full.Min.X else 0
	local usable = math.max(size.Y - padT - padB, 1)

	-- left column: under Roblox's buttons, shrunk just enough to keep its foot on screen
	local listTop = math.max(barBottom + EDGE_GAP, padT)
	local fitL = math.min(s, (size.Y - padB - EDGE_GAP - listTop) / (LIST_BOTTOM - LIST_TOP))
	local leftFit = left:FindFirstChild("Fit")
	if leftFit and leftFit:IsA("UIScale") then
		leftFit.Scale = fitL
	end
	place(left, UDim2.fromOffset(padL, math.max(padT, listTop - LIST_TOP * fitL)))
	-- right column and coins: inside the safe area
	local sideFit = usable / 1080
	local rightFit = right:FindFirstChild("Fit")
	if rightFit and rightFit:IsA("UIScale") then
		rightFit.Scale = math.min(s, sideFit)
	end
	place(right, UDim2.new(1, -padR, 0, padT))
	local topRight = gui:FindFirstChild("TopRight")
	if topRight and topRight:IsA("GuiObject") then
		place(topRight, UDim2.new(1, -padR, 0, padT))
	end
	place(bottom, UDim2.new(0.5, 0, 1, -padB))
	-- the title + tabs: centred, slid right if their left end reaches Roblox's buttons
	local topX = 0
	local title = top:FindFirstChild("Title")
	if title and title:IsA("TextLabel") and barRight > 0 then
		local slack = title.AbsoluteSize.X - title.TextBounds.X
		local alignShift = if title.TextXAlignment == Enum.TextXAlignment.Right
			then slack
			elseif title.TextXAlignment == Enum.TextXAlignment.Center then slack / 2
			else 0
		local centredLeft = gui.AbsolutePosition.X + size.X / 2 - top.AbsoluteSize.X / 2
		local shifted = top.AbsolutePosition.X - centredLeft -- the slide this function gave it last time
		local textLeft = title.AbsolutePosition.X + alignShift - shifted
		local reach = barRight + EDGE_GAP - (textLeft - gui.AbsolutePosition.X)
		if reach > 0 then
			topX = reach
		end
	end
	place(top, UDim2.new(0.5, topX, 0, padT))
	local box = confirmFrame and confirmFrame:FindFirstChild("Box")
	local u = box and box:FindFirstChild("Fit")
	if u and u:IsA("UIScale") then
		u.Scale = s
	end
end

-- The columns come in from their edges, a beat apart (UI Theme v4 motion: Quint out, no overshoot).
local function entrance()
	UiMotion.slideIn(left, -90, 0, 0, 0.42)
	UiMotion.slideIn(right, 90, 0, 0.05, 0.42)
	UiMotion.slideIn(top, 0, -50, 0.03, 0.36)
	UiMotion.slideIn(find(gui, "TopRight") :: GuiObject, 0, -50, 0.06, 0.36)
	UiMotion.slideIn(bottom, 0, 70, 0.08, 0.4)
end

-- The wipe: two screens tall, run from one end to the other; `atCover` when it covers the screen.
local function runWipe(fromY: number, toY: number, time: number, atCover: () -> ())
	local w = wipe
	if not w then
		atCover()
		return
	end
	w.Visible = true
	w.Position = UDim2.new(0.5, 0, fromY, 0)
	local tw = TweenService:Create(
		w,
		TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
		{ Position = UDim2.new(0.5, 0, toY, 0) }
	)
	tw:Play()
	task.delay(time * 0.5, atCover)
	tw.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			w.Visible = false
		end
	end)
end

local function reveal(arg: any?)
	if stageFolder or dof then
		-- reopened during the close wipe: that close never concealed, so drop its stage first (it left a
		-- second blur in Lighting for good, a stage folder and a doubled render binding)
		RunService:UnbindFromRenderStep("LockerV3")
		for _, c in openConnections do
			c:Disconnect()
		end
		table.clear(openConnections)
		if dof then
			dof:Destroy()
			dof = nil
		end
		if stageFolder then
			stageFolder:Destroy()
			stageFolder = nil
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "LockerV3Stage"
	local c = PowerCardFace.clone()
	if c then
		c.Parent = folder
		card = c
		local _, sw = PowerCardFace.front(c)
		sweep = sw
		c:PivotTo(CFrame.new(0, -500, 0))
	end
	folder.Parent = workspace
	stageFolder = folder
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "LockerV3Focus"
	d.FarIntensity = 0.75
	d.NearIntensity = 0
	d.FocusDistance = 0.1
	d.InFocusRadius = 15
	d.Parent = Lighting
	dof = d
	RunService:BindToRenderStep("LockerV3", Enum.RenderPriority.Last.Value, onRender)
	gui.Enabled = true
	fit()
	hideOthers()
	table.insert(openConnections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	table.insert(
		openConnections,
		RunService.Heartbeat:Connect(function()
			hideOthers() -- screens that come back on while the Locker is open (HUD refreshes)
		end)
	)
	-- `{ gun = id }` opens on that gun (the first-unlock callout, Controllers/OnboardingController)
	local focusGun = if typeof(arg) == "table" then (arg :: any).gun else nil
	selectedGun = if typeof(focusGun) == "string" and rows[focusGun]
		then focusGun
		else guns().primary
	refreshCoins()
	setMode(if arg == "powers" then "powers" else "guns")
	entrance()
end

local function conceal()
	RunService:UnbindFromRenderStep("LockerV3")
	for _, c in openConnections do
		c:Disconnect()
	end
	table.clear(openConnections)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	-- closed by a pad duel or the range starting: the lobby screens go to ArmedHide, not back on screen
	ArmedHideController.refresh()
	if dof then
		dof:Destroy()
		dof = nil
	end
	if stageFolder then
		stageFolder:Destroy()
		stageFolder = nil
	end
	current, card, sweep = nil, nil, nil
	dragging = false
	gui.Enabled = false
	if confirmFrame then
		confirmFrame.Visible = false
	end
	local camera = workspace.CurrentCamera
	camera.FieldOfView = savedFov
	camera.CameraType = savedCamType or Enum.CameraType.Custom
	savedCamType = nil
end

local function open(arg: any?)
	if isOpen then
		return
	end
	isOpen = true
	passToken += 1
	local my = passToken
	UiSfx.cue("LockerIn")
	local camera = workspace.CurrentCamera
	if not savedCamType then
		savedCamType = camera.CameraType
		savedFov = camera.FieldOfView
	end
	if UiMotion.reduced() then
		reveal(arg)
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	-- the camera lifts off (not in first person in the Range: the arms would float up with it)
	if PlayZone.get(player) ~= "Range" then
		TweenService:Create(
			camera,
			TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = camera.CFrame * CFrame.new(0, RISE, 0) }
		):Play()
	end
	runWipe(-1, 2, WIPE_IN, function()
		if passToken == my and isOpen then
			reveal(arg)
		end
	end)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	passToken += 1
	local my = passToken
	UiSfx.cue("LockerOut")
	if UiMotion.reduced() then
		conceal()
		return
	end
	runWipe(2, -1, WIPE_OUT, function()
		if passToken == my and not isOpen then
			conceal()
		end
	end)
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
		row:SetAttribute("BuiltOwned", owned)
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
		hoverTint(row)
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

-- Rows keep the template they were built with: a change in ownership (an unlock, the save landing) rebuilds them.
function rebuildGunRows()
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
	buildGunRows()
end

local tilesFor = "" -- the owned set the tiles were built for
local function buildTiles()
	local m = mods()
	-- A tile only shows owned or locked: an equip or any other save change keeps the grid (code audit 2026-11-27:
	-- it was rebuilt, ~20 tiles cloned, on every change while POWERS was open).
	local ownedIds: { string } = {}
	for id, on in m.owned do
		if on then
			table.insert(ownedIds, id)
		end
	end
	table.sort(ownedIds)
	local key = table.concat(ownedIds, ",")
	if key == tilesFor and next(tiles) ~= nil then
		return
	end
	tilesFor = key
	local grid = find(left, "Powers.List.Grid")
	local ownedTpl = find(grid, "TileOwned") :: GuiButton
	local lockedTpl = find(grid, "TileLocked") :: GuiButton
	ownedTpl.Visible, lockedTpl.Visible = false, false
	for _, t in tiles do
		t:Destroy()
	end
	table.clear(tiles)
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
		hoverTint(t)
		t.Parent = grid
		tiles[id] = t
	end
end

-- the unlock confirmation -----------------------------------------------------------------------------------------------

local function hideConfirm()
	local c = confirmFrame
	if not c or not c.Visible then
		return
	end
	local shade = find(c, "Shade") :: GuiObject
	local pop = find(c, "Box.Body.Pop") :: UIScale
	-- a controller's selection goes back to the UNLOCK button behind it
	c.SelectionGroup = false
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(c) then
		local buy = confirmReturn
		GuiService.SelectedObject = if buy and buy.Visible then buy else nil
	end
	UiMotion.out(shade, { BackgroundTransparency = 1 }, 0.14)
	UiMotion.out(pop, { Scale = 0.92 }, 0.14).Completed:Once(function()
		if confirmFrame == c and not c:GetAttribute("Opening") then
			c.Visible = false
		end
	end)
	c:SetAttribute("Opening", false)
end

local function showConfirm(id: string)
	local c = confirmFrame
	if not c then
		return
	end
	local price = GunLoadout.price(id) or 0
	confirmGun = id
	local body = find(c, "Box.Body")
	set(body, "Title", "Text", `UNLOCK {string.upper(gunName(id))}?`)
	set(body, "Render", "Image", Theme.GUN[id] or "")
	set(body, "Price.Amount", "Text", commas(price))
	set(body, "Sub", "Text", `You'll have {commas(coins() - price)} coins left`)
	c:SetAttribute("Opening", true)
	c.Visible = true
	-- a controller's selection stays inside the window and starts on UNLOCK
	c.SelectionGroup = true
	for _, side in { "Up", "Down", "Left", "Right" } do
		(c :: any)["SelectionBehavior" .. side] = Enum.SelectionBehavior.Stop
	end
	if InputMode.gamepad() then
		GuiService.SelectedObject = find(body, "Ok") :: GuiObject
	end
	local shade = find(c, "Shade") :: GuiObject
	local pop = find(body, "Pop") :: UIScale
	shade.BackgroundTransparency = 1
	pop.Scale = 0.9
	UiMotion.tween(shade, 0.2, { BackgroundTransparency = 0.45 })
	UiMotion.tween(pop, 0.26, { Scale = 1 })
	task.delay(0.3, function()
		c:SetAttribute("Opening", false)
	end)
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
	-- The screen lives in PlayerScripts.UI.Lobby (2026-11-27: was StarterGui, which also copied it into every
	-- match server) and Shared/UiRoot mounts it on lobby servers only.
	local g = player:WaitForChild("PlayerGui"):WaitForChild("LockerV3", 20)
	if not (g and g:IsA("ScreenGui")) then
		warn(
			"[LockerV3] UI.Lobby.LockerV3 missing (tools/studio/BuildLockerV3.luau + PromoteLockerV3.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	gui.ResetOnSpawn = false
	-- fit() owns this screen's "Fit" scales (Shared/UiLayout leaves CustomFit ones alone)
	for _, d in gui:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "Fit" then
			d:SetAttribute("CustomFit", true)
		end
	end
	left = find(gui, "Left") :: Frame
	right = find(gui, "Right") :: Frame
	top = find(gui, "Top") :: Frame
	bottom = find(gui, "Bottom") :: Frame
	center = find(gui, "Center") :: Frame
	local stack = find(right, "Stack")
	ownedPanel = find(stack, "GunOwned") :: Frame
	lockedPanel = find(stack, "GunLocked") :: Frame
	powerPanel = find(stack, "Power") :: Frame
	overviewCard = find(ownedPanel, "Overview") :: Frame
	lockPlate = find(center, "Lock") :: Frame
	skinStrip = find(bottom, "Skins") :: ScrollingFrame
	skinStrip.Visible = false
	-- a long strip starts at its left end (centred, a scrolling list opens in its middle)
	local stripLayout = skinStrip:FindFirstChildOfClass("UIListLayout")
	if stripLayout then
		stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
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
	for _, panel in { ownedPanel, lockedPanel, powerPanel } do
		set(panel, "Details.Favorite", "Visible", false) -- favourites: not built
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

	Router.register("Locker", {
		open = open,
		close = close,
		screen = "LockerV3",
		clear = true,
		-- B closes the confirm window, then the skin strip, before the Locker
		back = function(): boolean
			local cf = confirmFrame
			if cf and cf.Visible then
				hideConfirm()
				return true
			elseif stripOpen then
				setStrip(false)
				return true
			end
			return false
		end,
	})

	-- the wipe (above everything, two screens tall, soft top and bottom edges; Locker v4's)
	local wipeGui = Instance.new("ScreenGui")
	wipeGui.Name = "LockerV3Wipe"
	wipeGui:SetAttribute("LobbyGui", true) -- the match client never clears it (src/client init)
	wipeGui:SetAttribute("KeepWithLocker", true)
	wipeGui.ResetOnSpawn = false
	wipeGui.IgnoreGuiInset = true
	wipeGui.ScreenInsets = Enum.ScreenInsets.None
	wipeGui.DisplayOrder = 60
	local w = Instance.new("Frame")
	w.Name = "Wipe"
	w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Size = UDim2.fromScale(1, 2)
	w.BackgroundColor3 = Color3.fromHex("121215")
	w.BorderSizePixel = 0
	w.Visible = false
	local edge = Instance.new("UIGradient")
	edge.Rotation = 90
	edge.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.9, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	edge.Parent = w
	w.Parent = wipeGui
	wipeGui.Parent = player.PlayerGui
	wipe = w

	-- hover / press on every chunky and round button
	for _, path in
		{
			"Right.Stack.GunOwned.Equip.Button",
			"Right.Stack.GunOwned.Actions.OverviewRow.Button",
			"Right.Stack.GunLocked.Unlock.Buy.Button",
			"Right.Stack.GunLocked.Unlock.Try.Button",
			"Right.Stack.GunLocked.Actions.OverviewRow.Button",
			"Right.Stack.Power.DeckButton.Button",
			"Bottom.GunBar.Back.Button",
			"Bottom.GunBar.Skin.Button",
			"Bottom.PowerBar.Back.Button",
			"Bottom.PowerBar.Flip.Button",
		}
	do
		juice(find(gui, path) :: GuiButton)
	end
	for _, b in find(top, "Tabs"):GetChildren() do
		if b:IsA("GuiButton") then
			juice(b)
		end
	end

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
		showConfirm(selectedGun)
	end)
	onPress(lockedPanel, "Unlock.Try.Button", function()
		-- straight to the Range behind its loading card (LobbyServer RangeService checks the zone)
		Router.close()
		RangeTransition.travel()
	end)
	-- the confirm window
	local c = gui:FindFirstChild("Confirm")
	if c and c:IsA("Frame") then
		confirmFrame = c
		c.Visible = false
		confirmReturn = find(lockedPanel, "Unlock.Buy.Button") :: GuiObject
		local shadeHit = find(c, "Shade")
		if shadeHit:IsA("GuiObject") then
			shadeHit.Selectable = false -- a tap-outside catcher, not a stop for the D-pad
		end
		onPress(c, "Box.Body.Ok", function()
			hideConfirm()
			if confirmGun ~= "" then
				requestGun("unlock", confirmGun)
			end
		end)
		onPress(c, "Box.Body.Cancel", hideConfirm)
		onPress(c, "Shade", hideConfirm)
		for _, name in { "Ok", "Cancel" } do
			juice(find(c, "Box.Body." .. name) :: GuiButton)
		end
	end
	-- Overview opens / closes its bars (owned and locked panels share one Overview, on the owned panel)
	for _, panel in { ownedPanel, lockedPanel } do
		onPress(panel, "Actions.OverviewRow.Button", function()
			local o = overviewCard :: Frame
			o.Visible = not o.Visible
		end)
	end
	-- the deck
	onPress(powerPanel, "DeckButton.Button", function()
		local m = mods()
		local id = selectedPower
		if not m.owned[id] then
			-- a locked power: straight to the power cases in the Shop
			Router.close()
			Router.open("Shop", "CASES")
			return
		end
		if modBusy then
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
	-- One pointer turns it: the mouse, or the first finger down (a second finger, e.g. a pinch or a tap
	-- on a button, doesn't make the card jump between the two fingers).
	local dragTouch: InputObject? = nil
	local function settle()
		dragging = false
		dragTouch = nil
		targetPitch = 0
		local step = if mode == "powers" then math.pi else 2 * math.pi -- a card settles on its nearer face
		targetYaw = math.round(targetYaw / step) * step
	end
	dragZone.InputBegan:Connect(function(input: InputObject)
		if dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		elseif input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragTouch = input
		else
			return
		end
		lastPos = Vector2.new(input.Position.X, input.Position.Y)
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not (isOpen and dragging) then
			return
		end
		local follows = if dragTouch
			then input == dragTouch
			else input.UserInputType == Enum.UserInputType.MouseMovement
		if follows then
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
			(dragTouch and input == dragTouch)
			or (not dragTouch and input.UserInputType == Enum.UserInputType.MouseButton1)
		then
			settle()
		end
	end)
	-- a controller: the right stick turns the stage (the left stick and D-pad move the selection)
	local stickTurning = false
	RunService.Heartbeat:Connect(function(dt: number)
		if
			not isOpen
			or dragging
			or not UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
		then
			return
		end
		local stick = Vector2.zero
		for _, s in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if s.KeyCode == Enum.KeyCode.Thumbstick2 then
				stick = Vector2.new(s.Position.X, s.Position.Y)
			end
		end
		if stick.Magnitude > STICK_DEAD then
			stickTurning = true
			targetYaw += stick.X * STICK_YAW * dt
			targetPitch = math.clamp(-stick.Y * math.rad(40), math.rad(-40), math.rad(40))
		elseif stickTurning then
			stickTurning = false
			settle()
		end
	end)
end

function LockerV3Controller.isOpen(): boolean
	return isOpen
end

return LockerV3Controller
