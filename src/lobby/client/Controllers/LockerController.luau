--!strict
-- The Locker (vault/02 Art/UI Locker.md): equip a skin per gun on a live 3D
-- gun you can turn. The screen is Studio-built (StarterGui.Locker, templates
-- UiTemplates.Lobby.GunCard / SkinCard / GunGroup, backup
-- tools/studio/BuildLocker.luau); this fills and animates it.
--
-- Opening it (Router "Locker", no blur) clones ReplicatedStorage.LockerStage
-- into a full-screen ViewportFrame behind the UI and puts the selected gun on
-- the plinth. (A real far-off set with the camera cut there was tried first:
-- Roblox lights the area round the camera progressively, so it opened dark
-- for ~3 s. The ViewportFrame lights instantly, needs no camera move or
-- streaming, and works the same on phones.) Left: every gun as a picture card by class.
-- Right: that gun's skins as picture cards; clicking one puts it on the
-- stand, EQUIP asks the server (LockerRequest, Services/LockerService) which
-- sets the Skin_<gun> attribute this reads. Drag on the stage to turn the gun,
-- scroll to zoom; it turns slowly on its own when left alone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Router = require(script.Parent.Parent.Util.Router)
local Sound = require(script.Parent.Parent.Util.Sound)

local LockerController = {}

local player = Players.LocalPlayer
local DESIGN = Vector2.new(1920, 1080)
local NAVY, NAVY_HI = Color3.fromHex("1C2740"), Color3.fromHex("2B3A5A")
local ALLY, GOLD = Color3.fromHex("3FE0F2"), Color3.fromHex("FFC83D")
local INK, WHITE = Color3.fromHex("141A26"), Color3.new(1, 1, 1)
local BACK, QUINT = Enum.EasingStyle.Back, Enum.EasingStyle.Quint
local OUT = Enum.EasingDirection.Out

-- class order on the left, and the header each gets
local CLASSES = {
	{ "Sidearm", "SIDEARMS" },
	{ "SMG", "SMGS" },
	{ "Shotgun", "SHOTGUNS" },
	{ "Rifle", "RIFLES" },
	{ "Sniper", "SNIPERS" },
	{ "MachineGun", "HEAVY" },
	{ "Melee", "MELEE" },
}
local GUN_LENGTH = 3.9 -- studs on the stand (every gun scaled to about this)
local FOV = 30
local IDLE_SPIN = math.rad(9) -- per second, after a few seconds untouched

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
local stage: Model? = nil
local gunOnStand: Model? = nil
local standBase: CFrame = CFrame.new()
local cameraHome: CFrame = CFrame.new()
local stageView: ViewportFrame? = nil
local stageCam: Camera? = nil
local yaw, pitch, zoom = 0, 0, 1
local spinLeft = 0 -- radians of a swap spin still to turn (one full turn)
local lastTouch = 0
local dragging = false
local renderConn: RBXScriptConnection? = nil
local gunCards: { [string]: GuiButton } = {}
local tab = "WEAPONS"

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

-- body + its slanted caps in one colour
local function setFill(body: GuiObject, color: Color3)
	body.BackgroundColor3 = color
	for _, c in body:GetChildren() do
		if c:IsA("ImageLabel") and (c.Name == "CapL" or c.Name == "CapR") then
			c.ImageColor3 = color
		end
	end
end

-- A picture of a real model in a ViewportFrame: side view, muzzle right.
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
	local m = model:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m:PivotTo(CFrame.new())
	local cf, size = m:GetBoundingBox()
	m.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 20
	cam.Parent = vf
	vf.CurrentCamera = cam
	local half = math.max(size.Y, size.Z / (w / h)) / 2 * 0.98
	local dist = half / math.tan(math.rad(10)) + size.X / 2
	cam.CFrame =
		CFrame.lookAt(cf.Position + Vector3.new(dist, dist * 0.12, dist * 0.16), cf.Position)
	vf.Parent = parent
end

-- Stage ------------------------------------------------------------------------------
local function anchorClone(model: Model): Model
	local m = model:Clone()
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
	return m
end

-- Put `line` on `gunId` on the stand: scaled to one length, centred, then
-- turned by yaw / pitch every frame.
local function placeGun(gunId: string, line: string, spin: boolean)
	local s = stage
	if not s then
		return
	end
	local source = Locker.skinModel(gunId, line) or Locker.gunModel(gunId)
	if not source then
		return
	end
	if gunOnStand then
		gunOnStand:Destroy()
	end
	local m = anchorClone(source)
	m.Name = "Gun"
	m:PivotTo(CFrame.new())
	local _, size = m:GetBoundingBox()
	local length = math.max(size.Z, size.Y, 0.5)
	m:ScaleTo(math.clamp(GUN_LENGTH / length, 0.6, 3))
	-- pivot at the bounding box centre (the model sits unrotated at the
	-- origin here), so turning spins it in place over the plinth
	local box = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position)
	m.Parent = s
	gunOnStand = m
	if spin then
		spinLeft = math.pi * 2 -- one full turn that lands back on the same angle
		lastTouch = os.clock()
	end
end

local function standCFrame(): CFrame
	-- muzzle to the right (yaw -90), the hero angle, then the player's turn
	return standBase
		* CFrame.Angles(0, math.rad(-90 + 22) + yaw, 0)
		* CFrame.Angles(math.rad(-8) + pitch, 0, 0)
end

local function onRender(dt: number)
	local m = gunOnStand
	if not m then
		return
	end
	if spinLeft > 0.001 then
		local step = math.max(spinLeft * math.min(1, dt * 5), math.min(spinLeft, dt * 0.6))
		yaw += step
		spinLeft -= step
	elseif not dragging and os.clock() - lastTouch > 3 then
		yaw += IDLE_SPIN * dt
		pitch += (0 - pitch) * math.min(1, dt * 2) -- level out slowly
	end
	m:PivotTo(standCFrame())
	local cam = stageCam
	if cam then
		local look = cameraHome.LookVector
		local target = cameraHome.Position
			+ look * (cameraHome.Position - standBase.Position).Magnitude * (1 - zoom)
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(target, target + look), math.min(1, dt * 12))
	end
end

local function enterStage()
	local template = ReplicatedStorage:FindFirstChild("LockerStage")
	if not template then
		warn("[Locker] ReplicatedStorage.LockerStage missing (tools/studio/BuildLocker.luau)")
		return
	end
	-- the stage lives in a full-screen ViewportFrame under the UI
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Stage"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = Color3.fromHex("1D2B66")
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(118, 128, 170)
	vf.LightColor = Color3.fromRGB(255, 250, 242)
	vf.LightDirection = Vector3.new(-0.7, -1, -0.6)
	vf.ZIndex = 0
	local s = template:Clone() :: Model
	s.Name = "LockerStageLocal"
	for _, d in s:GetDescendants() do
		if d:IsA("Light") then
			d:Destroy() -- ViewportFrames use their own light
		end
	end
	s.Parent = vf
	stage = s
	local spot = s:FindFirstChild("GunSpot")
	local camValue = s:FindFirstChild("CameraCFrame")
	standBase = if spot and spot:IsA("CFrameValue") then spot.Value else s:GetPivot()
	cameraHome = if camValue and camValue:IsA("CFrameValue")
		then camValue.Value
		else standBase * CFrame.new(0, 1, 11)
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.CFrame = cameraHome * CFrame.new(0, 0, 3) -- glides in
	cam.Parent = vf
	vf.CurrentCamera = cam
	stageCam = cam
	vf.Parent = gui
	stageView = vf
	yaw, pitch, zoom = 0, 0, 1
	lastTouch = os.clock() -- hold the hero angle a moment before idling
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
	stage = nil
	stageCam = nil
	gunOnStand = nil
end

-- Cards -------------------------------------------------------------------------------
local refreshSkins: () -> () = function() end

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
			then string.upper(cfg.class == "MachineGun" and "HEAVY" or cfg.class)
			else ""
		label.Text = lineTitle(previewLine) .. "  ·  " .. class
	end
end

local function preview(line: string, spin: boolean)
	previewLine = line
	placeGun(selectedGun, line, spin)
	refreshHeader()
	refreshEquip()
	refreshSkins()
end

local function refreshGunChips()
	for gunId, card in gunCards do
		local chip = card:FindFirstChild("Skin")
		local line = equippedLine(gunId)
		if chip and chip:IsA("GuiObject") then
			chip.Visible = line ~= "Stock"
			setFill(chip, Locker.COLORS[line] or WHITE)
		end
		local on = gunId == selectedGun
		card.BackgroundColor3 = if on then ALLY else NAVY
		card.BackgroundTransparency = if on then 0 else 0.08
		local name = card:FindFirstChild("Name")
		if name and name:IsA("TextLabel") then
			name.TextColor3 = if on then INK else WHITE
		end
	end
end

local function selectGun(gunId: string)
	selectedGun = gunId
	refreshGunChips()
	preview(equippedLine(gunId), true)
end

refreshSkins = function()
	-- rebuild only when the gun changed; otherwise restyle in place
	local built = skinsList:GetAttribute("Gun") == selectedGun
	if not built then
		for _, c in skinsList:GetChildren() do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		skinsList:SetAttribute("Gun", selectedGun)
		for i, line in Locker.linesFor(selectedGun) do
			local card = (templates:WaitForChild("SkinCard") :: GuiButton):Clone()
			card.Name = line
			card.LayoutOrder = i
			local model = Locker.skinModel(selectedGun, line)
			if model then
				thumb(card, model, 192, 100, UDim2.fromOffset(6, 4))
			end
			local foot = child(card, "Foot") :: Frame
			foot.BackgroundColor3 = Locker.COLORS[line] or WHITE
			local name = child(foot, "Name") :: TextLabel
			name.Text = lineTitle(line)
			local pop = Instance.new("UIScale")
			pop.Name = "Pop"
			pop.Parent = card
			card.MouseEnter:Connect(function()
				tween(pop, 0.16, { Scale = 1.04 }, BACK)
				Sound.play("Hover")
			end)
			card.MouseLeave:Connect(function()
				tween(pop, 0.16, { Scale = 1 })
			end)
			card.Activated:Connect(function()
				if previewLine ~= line then
					Sound.play("Select")
					pop.Scale = 0.94
					tween(pop, 0.3, { Scale = 1 }, BACK)
					preview(line, true)
				end
			end)
			card.Parent = skinsList
			-- cascade in
			pop.Scale = 0.8
			task.delay(0.03 * i, function()
				tween(pop, 0.32, { Scale = 1 }, BACK)
			end)
		end
		local count = canvas:FindFirstChild("SkinsCount")
		if count and count:IsA("TextLabel") then
			count.Text = string.format("%d OWNED", #Locker.linesFor(selectedGun))
		end
	end
	local equipped = equippedLine(selectedGun)
	for _, card in skinsList:GetChildren() do
		if not card:IsA("GuiButton") then
			continue
		end
		local onStage = card.Name == previewLine
		card.BackgroundColor3 = if onStage then NAVY_HI else NAVY
		card.BackgroundTransparency = if onStage then 0 else 0.08
		local foot = card:FindFirstChild("Foot")
		local on = foot and foot:FindFirstChild("On")
		if on and on:IsA("GuiObject") then
			on.Visible = onStage
		end
		local eq = card:FindFirstChild("Equipped")
		if eq and eq:IsA("GuiObject") then
			eq.Visible = card.Name == equipped
		end
	end
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
			local model = Locker.gunModel(id)
			if model then
				thumb(card, model, 188, 74, UDim2.fromOffset(8, 4))
			end
			local name = child(card, "Name") :: TextLabel
			local cfg = Weapons.get(id)
			name.Text = string.upper(if cfg then cfg.displayName else id)
			local pop = Instance.new("UIScale")
			pop.Name = "Pop"
			pop.Parent = card
			card.MouseEnter:Connect(function()
				tween(pop, 0.16, { Scale = 1.04 }, BACK)
				Sound.play("Hover")
			end)
			card.MouseLeave:Connect(function()
				tween(pop, 0.16, { Scale = 1 })
			end)
			card.Activated:Connect(function()
				if selectedGun ~= id then
					Sound.play("Select")
					pop.Scale = 0.94
					tween(pop, 0.3, { Scale = 1 }, BACK)
					selectGun(id)
				end
			end)
			card.Parent = grid
			gunCards[id] = card
		end
		group.Parent = gunsList
	end
	refreshGunChips()
end

-- Tabs -------------------------------------------------------------------------------
local WEAPON_PARTS =
	{ "Guns", "Skins", "SkinsHead", "SkinsCount", "Equip", "Kinds", "Hint", "GunName", "SkinTag" }

local function setTab(name: string)
	tab = name
	local tabs = child(canvas, "Tabs") :: Frame
	for _, b in tabs:GetChildren() do
		if b:IsA("GuiButton") then
			local on = b.Name == name
			b.BackgroundTransparency = if on then 0 else 1
			for _, c in b:GetChildren() do
				if c:IsA("ImageLabel") then
					c.ImageTransparency = if on then 0 else 1
				elseif c:IsA("TextLabel") then
					c.TextColor3 = if on then INK else Color3.fromHex("8E98A8")
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
			if d:IsA("BasePart") and d.Name ~= "Handle" then
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
			tween(obj, 0.42, { Position = home }, QUINT)
		end
	end)
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	enterStage()
	gui.Enabled = true
	refit()
	setTab("WEAPONS")
	if next(gunCards) == nil then
		buildGuns()
	end
	selectGun(if Locker.gunModel(selectedGun) then selectedGun else "Vandal")
	-- entrance: the columns slide in from their edges, the title drops
	for _, item in
		{
			{ "Guns", -120, 0.02 },
			{ "Title", -80, 0 },
			{ "Tabs", -80, 0.04 },
			{ "Skins", 120, 0.04 },
			{ "SkinsHead", 120, 0.02 },
			{ "SkinsCount", 120, 0.02 },
			{ "Equip", 160, 0.08 },
			{ "Close", 80, 0 },
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
			tween(equipPop, 0.18, { Scale = 1.04 }, BACK)
			Sound.play("Hover")
		end
	end)
	equipButton.MouseLeave:Connect(function()
		tween(equipPop, 0.18, { Scale = 1 })
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
	-- the server confirms an equip by setting the attribute
	player.AttributeChanged:Connect(function(name: string)
		if isOpen and string.sub(name, 1, 5) == "Skin_" then
			refreshGunChips()
			refreshEquip()
			refreshSkins()
		end
	end)
	-- drag on the stage (not on a card) to turn the gun; scroll to zoom
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not isOpen or processed or tab ~= "WEAPONS" then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			spinLeft = 0
			lastTouch = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
			lastTouch = os.clock()
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
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
			yaw += math.rad(input.Delta.X * 0.45)
			pitch = math.clamp(pitch + math.rad(input.Delta.Y * 0.3), math.rad(-35), math.rad(35))
			lastTouch = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			zoom = math.clamp(zoom - input.Position.Z * 0.08, 0.7, 1.25)
			lastTouch = os.clock()
		end
	end)
end

return LockerController
