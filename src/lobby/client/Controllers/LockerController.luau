--!strict
-- The Locker v3 (vault/02 Art/UI Locker.md): equip a skin per gun on a big 3D
-- gun you can turn, RIVALS-style. The screen is Studio-built (StarterGui.Locker,
-- templates UiTemplates.Lobby.GunCard / SkinCard / GunGroup, backup
-- tools/studio/BuildLocker.luau); this fills and animates it.
--
-- Opening it (Router "Locker", no blur) draws the gun in a full-screen
-- ViewportFrame on flat blue behind the UI (a real far-off set opened dark for
-- ~3 s: Roblox lights the area round the camera progressively). Left: every gun
-- as a card with its in-game icon, by class. Right: that gun's skins with a
-- live picture each. A selected card is a solid colour. Clicking a skin puts it
-- on the stand; EQUIP asks the server (LockerRequest, Services/LockerService),
-- which sets the Skin_<gun> attribute this reads.
--
-- Turning (owner: "rotate it around like all directions, then it goes back to
-- its original position like RIVALS"): drag on the stage turns the gun about
-- the screen's axes, any way; letting go tweens it back to its pose. It never
-- turns on its own. Scroll zooms.

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
local NAVY_HI = Color3.fromHex("2B3A5A")
local ALLY, GOLD = Color3.fromHex("3FE0F2"), Color3.fromHex("FFC83D")
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
local GUN_LENGTH = 4.7 -- studs: every item is scaled to about this
local FOV = 30
-- the pose: the model's side toward the camera, muzzle up to the right
local POSE_YAW = math.rad(-90 + 26) -- turned a little toward the camera
local POSE_TILT = math.rad(24) -- muzzle raised, in screen space
local DRAG_SPEED = math.rad(0.42) -- per pixel
local ZOOM_MIN, ZOOM_MAX = 0.75, 1.3

local gui: ScreenGui
local canvas: Frame
local fit: UIScale
local gunsList: ScrollingFrame
local skinsList: ScrollingFrame
local equipButton: TextButton
local equipPop: UIScale
local gunName: TextLabel
local skinTag: Frame
local soonLabel: TextLabel
local templates: Folder

local isOpen = false
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
-- the turn the player adds (camera space) and the swap entrance: values that
-- tween back to identity; the zoom eases the same way
local dragRot = Instance.new("CFrameValue")
local swapRot = Instance.new("CFrameValue")
local zoomValue = Instance.new("NumberValue")
zoomValue.Value = 1
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

-- Models -------------------------------------------------------------------------------
-- A clean, anchored copy laid out the same way for every item: longest side
-- along Z (left-right on screen), thinnest along X (toward the camera), so a
-- bat lies along the screen and a fan shows its open face, like the guns.
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
	-- where each of the model's axes should point: long -> Z, mid -> Y, short -> X
	local target: { [string]: Vector3 } = {
		[axes[1][1]] = Vector3.zAxis,
		[axes[2][1]] = Vector3.yAxis,
		[axes[3][1]] = Vector3.xAxis,
	}
	local vx, vy, vz = target.X, target.Y, target.Z
	if vx:Cross(vy):Dot(vz) < 0 then
		vz = -vz -- keep it a rotation, not a mirror
	end
	m:PivotTo(CFrame.fromMatrix(Vector3.zero, vx, vy, vz))
	-- pivot at the centre so turning spins it in place
	local box = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position)
	m:PivotTo(CFrame.new())
	return m
end

-- A live picture of a model (skin cards): side view, framed to fit.
local function thumb(parent: GuiObject, model: Model, w: number, h: number, pos: UDim2)
	local old = parent:FindFirstChild("Thumb")
	if old then
		old:Destroy()
	end
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
	local half = math.max(size.Y, size.Z / (w / h)) / 2 * 1.02
	local dist = half / math.tan(math.rad(10)) + size.X / 2
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(dist, dist * 0.1, dist * 0.12), cf.Position)
	vf.Parent = parent
end

-- Stage -------------------------------------------------------------------------------
local function poseCFrame(): CFrame
	local camRot = cameraHome.Rotation
	-- the player's turn, the swap entrance and the tilt are in camera space;
	-- the yaw that shows the side is in model space
	local screen = dragRot.Value * swapRot.Value * CFrame.Angles(0, 0, POSE_TILT)
	return CFrame.new(standPos) * camRot * screen * camRot:Inverse() * CFrame.Angles(0, POSE_YAW, 0)
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
	-- melee reads big for its length (a bat is mostly handle): a bit smaller,
	-- so nothing reaches under the card columns
	local cfg = Weapons.get(gunId)
	local length = if cfg and cfg.class == "Melee" then GUN_LENGTH * 0.78 else GUN_LENGTH
	m:ScaleTo(math.clamp(length / math.max(size.Z, 0.5), 0.5, 4))
	m.Parent = view
	gunOnStand = m
	if animate then
		-- rises a little and settles into the pose
		swapRot.Value = CFrame.new(0, -0.35, 0)
			* CFrame.Angles(math.rad(-14), math.rad(-22), math.rad(-8))
		tween(swapRot, 0.5, { Value = CFrame.new() }, BACK)
	end
	m:PivotTo(poseCFrame())
end

local function onRender(dt: number)
	local m = gunOnStand
	if m then
		m:PivotTo(poseCFrame())
	end
	local cam = stageCam
	if cam then
		local look = cameraHome.LookVector
		local dist = (cameraHome.Position - standPos).Magnitude
		local target = standPos - look * dist * zoomValue.Value
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(target, target + look), math.min(1, dt * 14))
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
		else CFrame.lookAt(standPos + Vector3.new(0, 0.6, 11.5), standPos)
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
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.CFrame = cameraHome * CFrame.new(0, 0, 2.5) -- glides in
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = gui
	stageView = vf
	stageCam = cam
	dragRot.Value = CFrame.new()
	swapRot.Value = CFrame.new()
	zoomValue.Value = 1
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

-- Cards -------------------------------------------------------------------------------
local function refreshEquip()
	local equipped = equippedLine(selectedGun) == previewLine
	setFill(equipButton, if equipped then NAVY_HI else GOLD)
	local label = equipButton:FindFirstChild("Label")
	local sub = equipButton:FindFirstChild("Sub")
	local go = equipButton:FindFirstChild("Go")
	if label and label:IsA("TextLabel") then
		label.Text = if equipped then "EQUIPPED" else "EQUIP"
		label.TextColor3 = if equipped then WHITE else INK
	end
	if sub and sub:IsA("TextLabel") then
		local cfg = Weapons.get(selectedGun)
		sub.Text = lineTitle(previewLine)
			.. "  "
			.. string.upper(if cfg then cfg.displayName else selectedGun)
		sub.TextColor3 = if equipped then WHITE else INK
	end
	if go and go:IsA("TextLabel") then
		go.Visible = not equipped
	end
end

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
	end
end

-- a selected card is a solid colour; the rest are dark see-through plates
local function styleCard(card: GuiButton, on: boolean, color: Color3)
	tween(card, 0.14, {
		BackgroundColor3 = if on then color else CARD,
		BackgroundTransparency = if on then 0 else CARD_T,
	})
	local name = card:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		name.TextColor3 = if on then INK else WHITE
	end
end

local function refreshGunCards()
	for gunId, card in gunCards do
		styleCard(card, gunId == selectedGun, ALLY)
		local icon = card:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.ImageColor3 = if gunId == selectedGun then INK else WHITE
		end
		local chip = card:FindFirstChild("Skin")
		local line = equippedLine(gunId)
		if chip and chip:IsA("GuiObject") then
			chip.Visible = line ~= "Stock"
			setFill(chip, Locker.COLORS[line] or WHITE)
		end
	end
end

local function hoverable(card: GuiButton)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = card
	card.MouseEnter:Connect(function()
		tween(pop, 0.12, { Scale = 1.03 })
		Sound.play("Hover")
	end)
	card.MouseLeave:Connect(function()
		tween(pop, 0.14, { Scale = 1 })
	end)
	card.Activated:Connect(function()
		pop.Scale = 0.96
		tween(pop, 0.22, { Scale = 1.03 }, BACK)
	end)
end

local function refreshSkins()
	if skinsList:GetAttribute("Gun") ~= selectedGun then
		for _, c in skinsList:GetChildren() do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		skinsList:SetAttribute("Gun", selectedGun)
		skinsList.CanvasPosition = Vector2.zero
		local lines = Locker.linesFor(selectedGun)
		for i, line in lines do
			local card = (templates:WaitForChild("SkinCard") :: GuiButton):Clone()
			card.Name = line
			card.LayoutOrder = i
			local model = Locker.skinModel(selectedGun, line)
			if model then
				thumb(card, model, 220, 118, UDim2.fromOffset(8, 10))
			end
			local swatch = card:FindFirstChild("Swatch")
			if swatch and swatch:IsA("GuiObject") then
				setFill(swatch, Locker.COLORS[line] or WHITE)
			end
			local name = child(card, "Name") :: TextLabel
			name.Text = lineTitle(line)
			hoverable(card)
			card.Activated:Connect(function()
				if previewLine ~= line then
					Sound.play("Select")
					LockerController.preview(line)
				end
			end)
			card.Parent = skinsList
		end
		local count = canvas:FindFirstChild("SkinsCount")
		if count and count:IsA("TextLabel") then
			count.Text = string.format("%d OWNED", #lines)
		end
	end
	local equipped = equippedLine(selectedGun)
	for _, card in skinsList:GetChildren() do
		if card:IsA("GuiButton") then
			styleCard(card, card.Name == previewLine, Locker.COLORS[card.Name] or WHITE)
			local swatch = card:FindFirstChild("Swatch")
			if swatch and swatch:IsA("GuiObject") then
				swatch.Visible = card.Name ~= previewLine -- the whole card is the colour
			end
			local eq = card:FindFirstChild("Equipped")
			if eq and eq:IsA("GuiObject") then
				eq.Visible = card.Name == equipped
			end
		end
	end
end

function LockerController.preview(line: string)
	previewLine = line
	placeGun(selectedGun, line, true)
	refreshHeader()
	refreshEquip()
	refreshSkins()
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

-- Tabs -------------------------------------------------------------------------------
local WEAPON_PARTS = {
	"Guns",
	"Skins",
	"SkinsHead",
	"SkinsCount",
	"Equip",
	"Kinds",
	"Hint",
	"GunName",
	"SkinTag",
	"DragArea",
}

local function setTab(name: string)
	tab = name
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

local function slideIn(obj: GuiObject, dx: number, delay: number)
	local home = obj:GetAttribute("Home")
	if typeof(home) ~= "UDim2" then
		home = obj.Position
		obj:SetAttribute("Home", home)
	end
	obj.Position = (home :: UDim2) + UDim2.fromOffset(dx, 0)
	task.delay(delay, function()
		if isOpen then
			tween(obj, 0.45, { Position = home })
		end
	end)
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	refit()
	enterStage()
	setTab("WEAPONS")
	if next(gunCards) == nil then
		buildGuns()
	end
	selectGun(if Locker.gunModel(selectedGun) then selectedGun else "Vandal")
	for _, item in
		{
			{ "Guns", -140, 0.02 },
			{ "Title", -90, 0 },
			{ "Tabs", -90, 0.04 },
			{ "Skins", 140, 0.04 },
			{ "SkinsHead", 140, 0.02 },
			{ "SkinsCount", 140, 0.02 },
			{ "Equip", 180, 0.08 },
			{ "Close", 90, 0 },
		}
	do
		local g = canvas:FindFirstChild(item[1])
		if g and g:IsA("GuiObject") then
			slideIn(g, item[2], item[3])
		end
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	leaveStage()
end

local function equip()
	if equippedLine(selectedGun) == previewLine then
		return
	end
	Sound.play("LockIn")
	equipPop.Scale = 0.9
	tween(equipPop, 0.36, { Scale = 1 }, BACK)
	LobbyNet.event("LockerRequest"):FireServer("equip", selectedGun, previewLine)
end

-- let go: the gun eases back to its pose
local function release()
	if not dragging then
		return
	end
	dragging = false
	lastPos = nil
	dragTween = tween(dragRot, 0.7, { Value = CFrame.new() }, QUINT)
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
	skinsList = child(canvas, "Skins")
	equipButton = child(canvas, "Equip")
	gunName = child(canvas, "GunName")
	skinTag = child(canvas, "SkinTag")
	soonLabel = child(canvas, "Soon")
	templates = ReplicatedStorage:WaitForChild("UiTemplates"):WaitForChild("Lobby") :: Folder
	equipPop = Instance.new("UIScale")
	equipPop.Name = "Pop"
	equipPop.Parent = equipButton
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	Router.register("Locker", { open = open, close = close, clear = true })
	equipButton.Activated:Connect(equip)
	equipButton.MouseEnter:Connect(function()
		if equippedLine(selectedGun) ~= previewLine then
			tween(equipPop, 0.16, { Scale = 1.03 })
			Sound.play("Hover")
		end
	end)
	equipButton.MouseLeave:Connect(function()
		tween(equipPop, 0.16, { Scale = 1 })
	end)
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
	player.AttributeChanged:Connect(function(name: string)
		if isOpen and string.sub(name, 1, 5) == "Skin_" then
			refreshGunCards()
			refreshEquip()
			refreshSkins()
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
			-- left / right turns about the screen's up axis, up / down about its right axis
			dragRot.Value = CFrame.Angles(d.Y * DRAG_SPEED, d.X * DRAG_SPEED, 0) * dragRot.Value
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local over = gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
			for _, o in over do
				if o:IsDescendantOf(gunsList) or o:IsDescendantOf(skinsList) then
					return -- scrolling a list, not zooming
				end
			end
			local goal = math.clamp(zoomValue.Value - input.Position.Z * 0.08, ZOOM_MIN, ZOOM_MAX)
			tween(zoomValue, 0.25, { Value = goal })
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
