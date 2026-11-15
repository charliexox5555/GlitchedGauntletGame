--!strict
-- The Locker v4 (vault/02 Art/UI Locker.md): a big 3D gun you can turn and a
-- skin per gun, RIVALS-style. The screen is Studio-built (StarterGui.Locker,
-- templates UiTemplates.Lobby.GunCard / GunGroup / SkinTile, backup
-- tools/studio/BuildLocker.luau); this fills and animates it.
--
-- Two views. Main: the gun list (left), the gun, its name, and SKIN / CHARM /
-- FINISHER tiles. SKIN opens the skins tray: the list and tiles slide away,
-- the gun lifts to the middle, a strip of skin tiles slides up; clicking a
-- tile equips it (LockerRequest → Services/LockerService → Skin_<gun>).
--
-- The gun is drawn in a full-screen ViewportFrame on flat blue (a real
-- far-off set opened dark for ~3 s). It turns about its own centre: drag turns
-- it any way (smoothed), letting go eases it back to its pose; it never turns
-- on its own. The camera slides so the gun sits in the middle of the free area
-- in each view. Scroll zooms.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)

local LockerController = {}

local player = Players.LocalPlayer
local DESIGN = Vector2.new(1920, 1080)
local CARD = Color3.fromHex("0B1236")
local CARD_T = 0.35
local ALLY = Color3.fromHex("3FE0F2")
local INK, WHITE = Color3.fromHex("141A26"), Color3.new(1, 1, 1)
local QUINT, BACK = Enum.EasingStyle.Quint, Enum.EasingStyle.Back
local OUT = Enum.EasingDirection.Out

local CLASSES = {
	{ "Sidearm", "SIDEARMS" },
	{ "SMG", "SMGS" },
	{ "Shotgun", "SHOTGUNS" },
	{ "Rifle", "RIFLES" },
	{ "Sniper", "SNIPERS" },
	{ "MachineGun", "HEAVY" },
	{ "Melee", "MELEE" },
}
local GUN_LENGTH = 5 -- studs: every item is scaled to about this (melee a bit less)
local FOV = 30
local POSE_YAW = math.rad(-90 + 26) -- the side toward the camera, turned a little
local POSE_TILT = math.rad(22) -- muzzle raised, in screen space
local DRAG_SPEED = math.rad(0.38) -- per pixel
local DRAG_FOLLOW = 14 -- how fast the gun catches up with the drag (per second)
local ZOOM_MIN, ZOOM_MAX = 0.75, 1.3
-- where the gun sits on screen in each view (canvas x, y): the middle of the
-- free area; the camera slides so the gun's centre lands there
local MAIN_SPOT = Vector2.new(1240, 520)
local TRAY_SPOT = Vector2.new(960, 400)

local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local gunsList: ScrollingFrame
local tray: Frame
local strip: ScrollingFrame
local kinds: Frame
local gunName: TextLabel
local skinTag: Frame
local soonLabel: TextLabel
local templates: Folder

local isOpen = false
local trayOpen = false
local selectedGun = "Vandal"
local previewLine = "Stock"
local tab = "WEAPONS"
local gunCards: { [string]: GuiButton } = {}

-- stage
local stageView: ViewportFrame? = nil
local stageCam: Camera? = nil
local gunOnStand: Model? = nil
local standPos = Vector3.zero
local cameraHome = CFrame.new()
local renderConn: RBXScriptConnection? = nil
local dragTarget = Instance.new("CFrameValue") -- where the drag wants the gun
local dragShown = CFrame.new() -- what's drawn (eases toward the target)
local swapRot = Instance.new("CFrameValue") -- the entrance on a swap
local zoomValue = Instance.new("NumberValue")
zoomValue.Value = 1
local spotValue = Instance.new("Vector3Value") -- the screen spot (canvas px)
local dragging = false
local lastPos: Vector3? = nil
local dragTween: Tween? = nil

local function tween(
	obj: Instance,
	t: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or QUINT, dir or OUT), goal)
	tw:Play()
	return tw
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function equippedLine(gunId: string): string
	local v = player:GetAttribute(Locker.attr(gunId))
	return if typeof(v) == "string" then v else "Stock"
end

local function lineTitle(line: string): string
	return if line == "Stock" then "DEFAULT" else string.upper(line)
end

local function setFill(body: GuiObject, color: Color3)
	body.BackgroundColor3 = color
	for _, c in body:GetChildren() do
		if c:IsA("ImageLabel") and (c.Name == "CapL" or c.Name == "CapR") then
			c.ImageColor3 = color
		end
	end
end

-- dark ink on light colours, white on dark ones
local function inkOn(c: Color3): Color3
	return if (c.R * 0.3 + c.G * 0.59 + c.B * 0.11) > 0.55 then INK else WHITE
end

-- Models -------------------------------------------------------------------------------
-- A clean, anchored copy laid out the same way for every item (longest side
-- left-right, thinnest toward the camera: a bat lies along, a fan shows its
-- open face), with its pivot at its centre so it turns about its middle.
local function presentable(source: Model): Model
	local m = source:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m:PivotTo(CFrame.new())
	local _, size = m:GetBoundingBox()
	local axes = { { "X", size.X }, { "Y", size.Y }, { "Z", size.Z } }
	table.sort(axes, function(a, b)
		return a[2] > b[2]
	end)
	local target: { [string]: Vector3 } = {
		[axes[1][1]] = Vector3.zAxis,
		[axes[2][1]] = Vector3.yAxis,
		[axes[3][1]] = Vector3.xAxis,
	}
	local vx, vy, vz = target.X, target.Y, target.Z
	if vx:Cross(vy):Dot(vz) < 0 then
		vz = -vz -- a rotation, not a mirror
	end
	m:PivotTo(CFrame.fromMatrix(Vector3.zero, vx, vy, vz))
	local box = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position)
	m:PivotTo(CFrame.new())
	return m
end

-- A live picture of a model (skin tiles): side view, framed to fit.
local function thumb(parent: GuiObject, model: Model, w: number, h: number, pos: UDim2)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Thumb"
	vf.Position = pos
	vf.Size = UDim2.fromOffset(w, h)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromHex("CDD3DF")
	vf.LightColor = WHITE
	vf.LightDirection = Vector3.new(-0.6, -1, -0.4)
	vf.ZIndex = parent.ZIndex + 1
	local m = presentable(model)
	local cf, size = m:GetBoundingBox()
	m.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 20
	cam.Parent = vf
	vf.CurrentCamera = cam
	local half = math.max(size.Y, size.Z / (w / h)) / 2 * 1.05
	local dist = half / math.tan(math.rad(10)) + size.X / 2
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(dist, dist * 0.1, dist * 0.12), cf.Position)
	vf.Parent = parent
end

-- Stage -------------------------------------------------------------------------------
local function poseCFrame(): CFrame
	local camRot = cameraHome.Rotation
	-- the drag, the swap entrance and the tilt turn it about the screen's axes,
	-- through its own centre; the yaw that shows its side is in model space
	local screen = dragShown * swapRot.Value * CFrame.Angles(0, 0, POSE_TILT)
	return CFrame.new(standPos) * camRot * screen * camRot:Inverse() * CFrame.Angles(0, POSE_YAW, 0)
end

-- The camera position that puts the gun's centre at canvas point `spot`.
local function cameraFor(spot: Vector2, zoom: number): CFrame
	local dist = (cameraHome.Position - standPos).Magnitude * zoom
	local halfH = dist * math.tan(math.rad(FOV / 2))
	local halfW = halfH * (DESIGN.X / DESIGN.Y)
	-- canvas px -> offset from the view centre, in studs at the gun's distance
	local dx = (spot.X / DESIGN.X - 0.5) * 2 * halfW
	local dy = (spot.Y / DESIGN.Y - 0.5) * 2 * halfH
	local rot = cameraHome.Rotation
	local pos = standPos - rot.LookVector * dist - rot.RightVector * dx + rot.UpVector * dy
	return CFrame.new(pos) * rot
end

local function placeGun(gunId: string, line: string, animate: boolean)
	local view = stageView
	if not view then
		return
	end
	local source = Locker.skinModel(gunId, line) or Locker.gunModel(gunId)
	if not source then
		return
	end
	if gunOnStand then
		gunOnStand:Destroy()
	end
	local m = presentable(source)
	m.Name = "Gun"
	local _, size = m:GetBoundingBox()
	local cfg = Weapons.get(gunId)
	local length = if cfg and cfg.class == "Melee" then GUN_LENGTH * 0.78 else GUN_LENGTH
	m:ScaleTo(math.clamp(length / math.max(size.Z, 0.5), 0.5, 4))
	m.Parent = view
	gunOnStand = m
	if animate then
		swapRot.Value = CFrame.new(0, -0.3, 0)
			* CFrame.Angles(math.rad(-12), math.rad(-18), math.rad(-6))
		tween(swapRot, 0.55, { Value = CFrame.new() }, BACK)
	end
	m:PivotTo(poseCFrame())
end

local function onRender(dt: number)
	-- the drawn turn eases toward the drag (smooth, no jumps)
	dragShown = dragShown:Lerp(dragTarget.Value, 1 - math.exp(-dt * DRAG_FOLLOW))
	local m = gunOnStand
	if m then
		m:PivotTo(poseCFrame())
	end
	local cam = stageCam
	if cam then
		local s = spotValue.Value
		local goal = cameraFor(Vector2.new(s.X, s.Y), zoomValue.Value)
		cam.CFrame = cam.CFrame:Lerp(goal, 1 - math.exp(-dt * 10))
	end
end

local function enterStage()
	local values = ReplicatedStorage:FindFirstChild("LockerStage")
	if not values then
		warn("[Locker] ReplicatedStorage.LockerStage missing (tools/studio/BuildLocker.luau)")
		return
	end
	local spot = values:FindFirstChild("GunSpot")
	local camValue = values:FindFirstChild("CameraCFrame")
	standPos = if spot and spot:IsA("CFrameValue") then spot.Value.Position else Vector3.zero
	cameraHome = if camValue and camValue:IsA("CFrameValue")
		then camValue.Value
		else CFrame.lookAt(standPos + Vector3.new(0, 0.5, 12), standPos)
	local bg = values:GetAttribute("Background")
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Stage"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = if typeof(bg) == "Color3" then bg else Color3.fromHex("2340D8")
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(150, 158, 196)
	vf.LightColor = Color3.fromRGB(255, 250, 242)
	vf.LightDirection = Vector3.new(-0.55, -1, -0.75)
	vf.ZIndex = 0
	spotValue.Value = Vector3.new(MAIN_SPOT.X, MAIN_SPOT.Y, 0)
	zoomValue.Value = 1
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.CFrame = cameraFor(MAIN_SPOT, 1.2) -- glides in
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = gui
	stageView = vf
	stageCam = cam
	dragTarget.Value = CFrame.new()
	dragShown = CFrame.new()
	swapRot.Value = CFrame.new()
	renderConn = RunService.RenderStepped:Connect(onRender)
end

local function leaveStage()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if stageView then
		stageView:Destroy()
		stageView = nil
	end
	stageCam = nil
	gunOnStand = nil
	dragging = false
end

-- Main view ----------------------------------------------------------------------------
local function refreshHeader()
	local cfg = Weapons.get(selectedGun)
	gunName.Text = string.upper(if cfg then cfg.displayName else selectedGun)
	local color = Locker.COLORS[previewLine] or WHITE
	setFill(skinTag, color)
	local label = skinTag:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		local class = if cfg
			then string.upper(if cfg.class == "MachineGun" then "HEAVY" else cfg.class)
			else ""
		label.Text = lineTitle(previewLine) .. "  ·  " .. class
		label.TextColor3 = inkOn(color)
	end
	-- the SKIN tile wears the equipped skin's colour and name
	local skinTile = kinds:FindFirstChild("SKIN")
	if skinTile and skinTile:IsA("GuiObject") then
		local eq = equippedLine(selectedGun)
		local c = Locker.COLORS[eq] or WHITE
		skinTile.BackgroundColor3 = c
		local value = skinTile:FindFirstChild("Value")
		local lbl = skinTile:FindFirstChild("Label")
		if value and value:IsA("TextLabel") then
			value.Text = lineTitle(eq)
			value.TextColor3 = inkOn(c)
		end
		if lbl and lbl:IsA("TextLabel") then
			lbl.TextColor3 = inkOn(c)
		end
	end
end

local function styleGunCard(card: GuiButton, on: boolean)
	tween(card, 0.14, {
		BackgroundColor3 = if on then ALLY else CARD,
		BackgroundTransparency = if on then 0 else CARD_T,
	})
	local name = card:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		name.TextColor3 = if on then INK else WHITE
	end
	local icon = card:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		icon.ImageColor3 = if on then INK else WHITE
	end
end

local function refreshGunCards()
	for gunId, card in gunCards do
		styleGunCard(card, gunId == selectedGun)
		local chip = card:FindFirstChild("Skin")
		local line = equippedLine(gunId)
		if chip and chip:IsA("GuiObject") then
			chip.Visible = line ~= "Stock"
			setFill(chip, Locker.COLORS[line] or WHITE)
		end
	end
end

local function hoverable(card: GuiButton, lift: number?)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = card
	local up = lift or 1.03
	card.MouseEnter:Connect(function()
		tween(pop, 0.12, { Scale = up })
		Sound.play("Hover")
	end)
	card.MouseLeave:Connect(function()
		tween(pop, 0.14, { Scale = 1 })
	end)
	card.Activated:Connect(function()
		pop.Scale = 0.95
		tween(pop, 0.24, { Scale = up }, BACK)
	end)
end

function LockerController.preview(line: string)
	previewLine = line
	placeGun(selectedGun, line, true)
	refreshHeader()
end

local function selectGun(gunId: string)
	selectedGun = gunId
	refreshGunCards()
	LockerController.preview(equippedLine(gunId))
end

local function buildGuns()
	for _, c in gunsList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(gunCards)
	for order, class in CLASSES do
		local ids: { string } = {}
		for id, cfg in Weapons.list do
			if cfg.class == class[1] and Locker.gunModel(id) then
				table.insert(ids, id)
			end
		end
		if #ids == 0 then
			continue
		end
		table.sort(ids, function(a, b)
			local ca, cb = Weapons.get(a), Weapons.get(b)
			local ta, tb = ca and ca.tier or 0, cb and cb.tier or 0
			if ta ~= tb then
				return ta < tb
			end
			return a < b
		end)
		local group = (templates:WaitForChild("GunGroup") :: Frame):Clone()
		group.Name = class[2]
		group.LayoutOrder = order
		local head = group:FindFirstChild("Head")
		if head and head:IsA("TextLabel") then
			head.Text = class[2]
		end
		local grid = child(group, "Grid") :: Frame
		for i, id in ids do
			local card = (templates:WaitForChild("GunCard") :: GuiButton):Clone()
			card.Name = id
			card.LayoutOrder = i
			local icon = child(card, "Icon") :: ImageLabel
			icon.Image = Theme.GUN[id] or ""
			local name = child(card, "Name") :: TextLabel
			local cfg = Weapons.get(id)
			name.Text = string.upper(if cfg then cfg.displayName else id)
			hoverable(card)
			card.Activated:Connect(function()
				if selectedGun ~= id then
					Sound.play("Select")
					selectGun(id)
				end
			end)
			card.Parent = grid
			gunCards[id] = card
		end
		group.Parent = gunsList
	end
	refreshGunCards()
end

-- Skins tray ---------------------------------------------------------------------------
local function refreshTiles()
	local equipped = equippedLine(selectedGun)
	for _, t in strip:GetChildren() do
		if t:IsA("GuiButton") then
			local check = t:FindFirstChild("Check")
			if check and check:IsA("GuiObject") then
				check.Visible = t.Name == equipped
			end
			local pop = t:FindFirstChild("Pop")
			if pop and pop:IsA("UIScale") then
				tween(pop, 0.16, { Scale = if t.Name == previewLine then 1.06 else 1 })
			end
		end
	end
	local count = tray:FindFirstChild("Count")
	if count and count:IsA("TextLabel") then
		count.Text = string.format("%d OWNED", #Locker.linesFor(selectedGun))
	end
end

local function buildTiles()
	for _, c in strip:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	strip.CanvasPosition = Vector2.zero
	for i, line in Locker.linesFor(selectedGun) do
		local t = (templates:WaitForChild("SkinTile") :: GuiButton):Clone()
		t.Name = line
		t.LayoutOrder = i
		t.BackgroundColor3 = Locker.COLORS[line] or WHITE
		local model = Locker.skinModel(selectedGun, line)
		if model then
			thumb(t, model, t.Size.X.Offset - 12, t.Size.Y.Offset - 56, UDim2.fromOffset(6, 8))
		end
		local name = child(t, "Name") :: TextLabel
		name.Text = lineTitle(line)
		hoverable(t, 1.06)
		t.Activated:Connect(function()
			Sound.play("Select")
			LockerController.preview(line)
			if equippedLine(selectedGun) ~= line then
				Sound.play("LockIn")
				LobbyNet.event("LockerRequest"):FireServer("equip", selectedGun, line)
			end
			refreshTiles()
		end)
		t.Parent = strip
	end
	refreshTiles()
end

local function home(obj: GuiObject): UDim2
	local h = obj:GetAttribute("Home")
	if typeof(h) ~= "UDim2" then
		h = obj.Position
		obj:SetAttribute("Home", h)
	end
	return h :: UDim2
end

local function moveName(x: number)
	for _, n in { "GunName", "SkinTag" } do
		local g = canvas:FindFirstChild(n)
		if g and g:IsA("GuiObject") then
			local h = home(g)
			tween(g, 0.45, { Position = UDim2.fromOffset(x, h.Y.Offset) })
		end
	end
end

local function setTray(open: boolean)
	if trayOpen == open then
		return
	end
	trayOpen = open
	local hint = canvas:FindFirstChild("Hint")
	if hint and hint:IsA("GuiObject") then
		hint.Visible = not open
	end
	local gunsHome, kindsHome, trayHome = home(gunsList), home(kinds), home(tray)
	if open then
		buildTiles()
		tween(gunsList, 0.35, { Position = gunsHome + UDim2.fromOffset(-620, 0) })
		tween(kinds, 0.3, { Position = kindsHome + UDim2.fromOffset(0, 260) })
		tray.Visible = true
		tray.Position = trayHome + UDim2.fromOffset(0, 340)
		tween(tray, 0.45, { Position = trayHome })
		tween(spotValue, 0.6, { Value = Vector3.new(TRAY_SPOT.X, TRAY_SPOT.Y, 0) })
		moveName(TRAY_SPOT.X)
	else
		tween(gunsList, 0.4, { Position = gunsHome })
		tween(kinds, 0.4, { Position = kindsHome })
		local t = tween(tray, 0.3, { Position = trayHome + UDim2.fromOffset(0, 340) })
		t.Completed:Once(function()
			if not trayOpen then
				tray.Visible = false
			end
		end)
		tween(spotValue, 0.6, { Value = Vector3.new(MAIN_SPOT.X, MAIN_SPOT.Y, 0) })
		moveName(MAIN_SPOT.X)
		if previewLine ~= equippedLine(selectedGun) then
			LockerController.preview(equippedLine(selectedGun))
		end
	end
end

-- Tabs -------------------------------------------------------------------------------
local WEAPON_PARTS = { "Guns", "Kinds", "Hint", "GunName", "SkinTag", "DragArea" }

local function setTab(name: string)
	tab = name
	if name ~= "WEAPONS" then
		setTray(false)
	end
	for _, b in (child(canvas, "Tabs") :: Frame):GetChildren() do
		if b:IsA("GuiButton") then
			local on = b.Name == name
			b.BackgroundTransparency = if on then 0 else 1
			for _, c in b:GetChildren() do
				if c:IsA("ImageLabel") then
					c.ImageTransparency = if on then 0 else 1
				elseif c:IsA("TextLabel") then
					c.TextColor3 = if on then INK else Color3.fromHex("AEB8D6")
				end
			end
		end
	end
	local weapons = name == "WEAPONS"
	for _, n in WEAPON_PARTS do
		local g = canvas:FindFirstChild(n)
		if g and g:IsA("GuiObject") then
			g.Visible = weapons
		end
	end
	if gunOnStand then
		for _, d in gunOnStand:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if weapons then 0 else 1
			end
		end
	end
	soonLabel.Visible = not weapons
	soonLabel.Text = if name == "ABILITIES" then "MOD COLLECTION  ·  SOON" else "EMOTES  ·  SOON"
end

-- Open / close -----------------------------------------------------------------------
local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(size.X / DESIGN.X, size.Y / DESIGN.Y)
	end
end

local function slideIn(obj: GuiObject, dx: number, dy: number, delay: number)
	local h = home(obj)
	obj.Position = h + UDim2.fromOffset(dx, dy)
	task.delay(delay, function()
		if isOpen then
			tween(obj, 0.45, { Position = h })
		end
	end)
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	trayOpen = false
	tray.Visible = false
	tray.Position = home(tray)
	gui.Enabled = true
	refit()
	enterStage()
	setTab("WEAPONS")
	if next(gunCards) == nil then
		buildGuns()
	end
	selectGun(if Locker.gunModel(selectedGun) then selectedGun else "Vandal")
	moveName(MAIN_SPOT.X)
	slideIn(gunsList, -160, 0, 0.02)
	slideIn(child(canvas, "Title"), -100, 0, 0)
	slideIn(child(canvas, "Tabs"), -100, 0, 0.04)
	slideIn(kinds, 0, 200, 0.08)
	slideIn(child(canvas, "Close"), 100, 0, 0)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	trayOpen = false
	gui.Enabled = false
	gunsList.Position = home(gunsList)
	kinds.Position = home(kinds)
	leaveStage()
end

local function release()
	if not dragging then
		return
	end
	dragging = false
	lastPos = nil
	dragTween = tween(dragTarget, 0.8, { Value = CFrame.new() }, QUINT)
end

function LockerController.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("Locker", 15)
	if not g or not g:IsA("ScreenGui") then
		warn("[Locker] StarterGui.Locker missing (tools/studio/BuildLocker.luau)")
		return
	end
	gui = g
	gui.Enabled = false
	canvas = child(gui, "Canvas")
	fit = child(canvas, "Fit")
	gunsList = child(canvas, "Guns")
	tray = child(canvas, "Tray")
	strip = child(tray, "Strip")
	kinds = child(canvas, "Kinds")
	gunName = child(canvas, "GunName")
	skinTag = child(canvas, "SkinTag")
	soonLabel = child(canvas, "Soon")
	templates = ReplicatedStorage:WaitForChild("UiTemplates"):WaitForChild("Lobby") :: Folder
	for _, o in { gunsList, kinds, tray, child(canvas, "GunName"), child(canvas, "SkinTag") } do
		home(o :: GuiObject)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	Router.register("Locker", { open = open, close = close, clear = true })
	local closeButton = child(canvas, "Close") :: GuiButton
	closeButton.Activated:Connect(function()
		Sound.play("Close")
		Router.close()
	end)
	for _, b in (child(canvas, "Tabs") :: Frame):GetChildren() do
		if b:IsA("GuiButton") then
			b.Activated:Connect(function()
				if tab ~= b.Name then
					Sound.play("Select")
					setTab(b.Name)
				end
			end)
		end
	end
	-- SKIN opens the tray; CHARM / FINISHER are soon
	for _, t in kinds:GetChildren() do
		if t:IsA("GuiButton") then
			hoverable(t)
			t.Activated:Connect(function()
				if t.Name == "SKIN" then
					Sound.play("Open")
					setTray(true)
				else
					Sound.play("Denied")
				end
			end)
		end
	end
	local backButton = child(tray, "Back") :: GuiButton
	hoverable(backButton)
	backButton.Activated:Connect(function()
		Sound.play("Close")
		setTray(false)
	end)
	player.AttributeChanged:Connect(function(name: string)
		if isOpen and string.sub(name, 1, 5) == "Skin_" then
			refreshGunCards()
			refreshHeader()
			if trayOpen then
				refreshTiles()
			end
		end
	end)

	-- turning: press on the stage, move, let go (positions, not mouse deltas:
	-- Roblox only fills mouse deltas while the mouse is locked)
	local dragArea = child(canvas, "DragArea") :: GuiButton
	dragArea.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			lastPos = input.Position
			if dragTween then
				dragTween:Cancel()
				dragTween = nil
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not isOpen then
			return
		end
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local last = lastPos or input.Position
			local d = input.Position - last
			lastPos = input.Position
			dragTarget.Value = CFrame.Angles(d.Y * DRAG_SPEED, d.X * DRAG_SPEED, 0)
				* dragTarget.Value
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			for _, o in gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
				if o:IsDescendantOf(gunsList) or o:IsDescendantOf(strip) then
					return -- scrolling a list, not zooming
				end
			end
			local goal = math.clamp(zoomValue.Value - input.Position.Z * 0.08, ZOOM_MIN, ZOOM_MAX)
			tween(zoomValue, 0.3, { Value = goal })
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			release()
		end
	end)
end

return LockerController
