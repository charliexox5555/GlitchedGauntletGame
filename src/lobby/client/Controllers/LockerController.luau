--!strict
-- The Locker v4 (vault/02 Art/UI Locker.md): a big 3D gun you can turn and a
-- skin per gun, RIVALS-style. The screen is Studio-built (StarterGui.Locker,
-- templates UiTemplates.Lobby.GunCard / GunGroup / SkinTile, backup
-- tools/studio/BuildLocker.luau); this fills and animates it.
--
-- Two views. Main: the gun list (left), the gun, its name, and SKIN / CHARM /
-- FINISHER tiles. SKIN opens the skins tray: the list and tiles slide away,
-- the gun lifts to the middle, a strip of skin tiles slides up; clicking a
-- tile equips it (LockerRequest → Services/LockerService → LockerSkins).
--
-- The gun is drawn in a full-screen ViewportFrame on flat blue (a real
-- far-off set opened dark for ~3 s). It turns about its own centre: drag turns
-- it any way (smoothed), letting go eases it back to its pose; it never turns
-- on its own. The camera slides so the gun sits in the middle of the free area
-- in each view. Scroll zooms.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiSfx = require(game:GetService("ReplicatedStorage").Shared.UiSfx)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local Locker = require(ReplicatedStorage.Shared.Locker)
local SkinStore = require(ReplicatedStorage.Shared.SkinStore)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local Pivot = require(script.Parent.Parent.Util.Pivot)
local Plates = require(script.Parent.Parent.Util.Plates)
local Router = require(script.Parent.Parent.Util.Router)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module

local LockerController = {}

local player = Players.LocalPlayer
local DESIGN = Vector2.new(1920, 1080)
local CARD = Color3.fromHex("141417")
local ALLY = Color3.fromHex("3FE0F2")
local INK, WHITE = Color3.fromHex("1A1A1D"), Color3.new(1, 1, 1)
local BACK = Enum.EasingStyle.Back

local CLASSES = {
	{ "Sidearm", "SIDEARMS" },
	{ "SMG", "SMGS" },
	{ "Shotgun", "SHOTGUNS" },
	{ "Rifle", "RIFLES" },
	{ "Sniper", "SNIPERS" },
	{ "MachineGun", "HEAVY" },
	{ "Melee", "MELEE" },
}
-- every item is scaled to fit a box: at most this long and this tall (a
-- pistol stops at the height, a rifle at the length; melee a bit smaller)
local GUN_LENGTH = 5 -- studs on the stage, a sidearm (~840 px on the 1080 canvas)
local GUN_HEIGHT = 2
-- Long guns get more of the stage (owner 2026-11-20: "the Vandal and larger
-- guns should be more zoomed in"; before, every gun was fitted to the same
-- 5-stud length, so rifles read thin). Multiplies GUN_LENGTH / GUN_HEIGHT.
local CLASS_SIZE: { [string]: number } = {
	Sidearm = 1,
	SMG = 1.12,
	Shotgun = 1.2,
	Rifle = 1.24,
	Sniper = 1.28,
	MachineGun = 1.28,
	Melee = 0.8,
}
local FOV = 30
local POSE_YAW = math.rad(-90 + 26) -- the side toward the camera, turned a little
local POSE_TILT = math.rad(22) -- muzzle raised, in screen space
local DRAG_SPEED = math.rad(0.24) -- per pixel
local DRAG_FOLLOW = 6 -- how fast the drawn turn catches up with the drag (per second)
local RETURN_TIME = 1.2 -- letting go: the ease back to the pose
-- idle wobble: a slow bob and sway on mismatched periods so it never loops visibly
local WOBBLE_BOB = 0.05 -- studs
local WOBBLE_YAW, WOBBLE_PITCH, WOBBLE_ROLL = math.rad(3.2), math.rad(1.6), math.rad(1.2)
local ZOOM_MIN, ZOOM_MAX = 0.75, 1.3
-- where the gun sits on screen in each view: design px from the canvas's
-- centre (the canvas is a fit canvas, Shared/UiLayout, so it is as wide as the
-- screen and its groups hug its edges or centre); the camera slides so the
-- gun's centre lands there (owner 2026-11-22: on a phone the gun sat off its
-- spot and the gun list showed beside the skins)
local MAIN_SPOT = Vector2.new(280, -20)
local TRAY_SPOT = Vector2.new(0, -160)
local TRAY_ZOOM = 1.3 -- the skins view pulls back so the gun clears the title
-- the floor shadow sits this far under the gun's centre (canvas px at zoom 1)
local FLOOR_DROP = 190
local MUTED = Color3.fromHex("B8B8BB")
-- gun pictures (shared/ItemIcons) are all cut to the same width, so a pistol
-- drawn in the full box looks as long as a rifle: each class gets a share of
-- the box's width
local ICON_WIDTH: { [string]: number } = {
	Sidearm = 0.56,
	SMG = 0.74,
	Shotgun = 0.86,
	Rifle = 1,
	Sniper = 1,
	MachineGun = 1,
	Melee = 0.56,
}

local gui: ScreenGui
local canvas: Frame
local gunsList: ScrollingFrame
local tray: Frame
local strip: ScrollingFrame
local kinds: Frame
local gunName: TextLabel
local skinTag: Frame
local soonLabel: TextLabel
local templates: Folder
local floorShadow: Frame

local isOpen = false
local trayOpen = false
local selectedGun = "Vandal"
local previewLine = "Stock"
local tab = "WEAPONS"
local gunCards: { [string]: GuiButton } = {}

-- stage
local stageView: ViewportFrame? = nil
local stageLight: ImageLabel? = nil -- Backdrop.BackCanvas.Light
local backCanvas: Frame? = nil -- Backdrop.BackCanvas (the floor shadow's frame)
local stageCam: Camera? = nil
local gunOnStand: Model? = nil
local standPos = Vector3.zero
local cameraHome = CFrame.new()
local renderConn: RBXScriptConnection? = nil
local dragTarget = Instance.new("CFrameValue") -- where the drag wants the gun
local dragShown = CFrame.new() -- what's drawn (eases toward the target)
local wobbleAmount = 1 -- 0 while dragging, eases back to 1 when left alone
local swapRot = Instance.new("CFrameValue") -- the entrance on a swap
local zoomValue = Instance.new("NumberValue")
zoomValue.Value = 1
local spotValue = Instance.new("Vector3Value") -- the screen spot (canvas px)
local dragging = false
local lastPos: Vector3? = nil
local dragTween: Tween? = nil

local resetClose: () -> () = function() end

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function equippedLine(gunId: string): string
	return Locker.equipped(player)[gunId] or "Stock"
end

-- The lines this player owns for a gun (Stock first): skins come from case
-- openings now (Shared/PlayerData), so the Locker only lists owned ones.
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

local function lineTitle(line: string): string
	return if line == "Stock" then "DEFAULT" else string.upper(line)
end

-- dark ink on light colours, white on dark ones
local function inkOn(c: Color3): Color3
	return if (c.R * 0.3 + c.G * 0.59 + c.B * 0.11) > 0.55 then INK else WHITE
end

-- A skin line's emblem (template UiTemplates.Lobby.SkinEmblem): its image from
-- Locker.EMBLEMS once the art exists, else a diamond in the line's colour
-- with its first letter. `d` is the size in px.
local function makeEmblem(parent: Instance, line: string, d: number, order: number?): Frame
	local e = (templates:WaitForChild("SkinEmblem") :: Frame):Clone()
	e.Name = "Emblem"
	e.Size = UDim2.fromOffset(d, d)
	e.LayoutOrder = order or 1
	local color = Locker.COLORS[line] or WHITE
	local art = child(e, "Art") :: ImageLabel
	local id = Locker.EMBLEMS[line]
	local hasArt = id ~= nil and id ~= ""
	art.Visible = hasArt
	if hasArt then
		art.Image = id :: string
		art.ImageColor3 = color
	end
	local diamond = child(e, "Diamond") :: Frame
	local letter = child(e, "Letter") :: TextLabel
	diamond.Visible = not hasArt
	letter.Visible = not hasArt
	diamond.BackgroundColor3 = color
	letter.Text = string.sub(lineTitle(line), 1, 1)
	letter.TextColor3 = inkOn(color)
	if parent:IsA("GuiObject") then
		e.ZIndex = parent.ZIndex + 2
		for _, c in e:GetChildren() do
			if c:IsA("GuiObject") then
				c.ZIndex = parent.ZIndex + (if c.Name == "Diamond" then 2 else 3)
			end
		end
	end
	e.Parent = parent
	return e
end

local function clearEmblems(parent: Instance)
	for _, c in parent:GetChildren() do
		if c.Name == "Emblem" then
			c:Destroy()
		end
	end
end

-- Models -------------------------------------------------------------------------------
-- A clean, anchored copy laid out the same way for every item (longest side
-- left-right, thinnest toward the camera: a bat lies along, a fan shows its
-- open face), with its pivot at its centre so it turns about its middle. (Util/ItemStage)
local presentable = require(script.Parent.Parent.Util.ItemStage).presentable

-- A live picture of a model (skin tiles): side view, framed to fit.
local function thumb(parent: GuiObject, model: Model, w: number, h: number, pos: UDim2)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Thumb"
	vf.Position = pos
	vf.Size = UDim2.fromOffset(w, h)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromHex("D3D3D6")
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
	local t = os.clock()
	local wobble = CFrame.new(0, math.sin(t * 1.05) * WOBBLE_BOB, 0)
		* CFrame.Angles(
			math.sin(t * 0.73 + 1.3) * WOBBLE_PITCH,
			math.sin(t * 0.52) * WOBBLE_YAW,
			math.sin(t * 0.61 + 2.1) * WOBBLE_ROLL
		)
	wobble = CFrame.new():Lerp(wobble, wobbleAmount)
	local screen = dragShown * wobble * swapRot.Value * CFrame.Angles(0, 0, POSE_TILT)
	return CFrame.new(standPos) * camRot * screen * camRot:Inverse() * CFrame.Angles(0, POSE_YAW, 0)
end

-- The camera position that puts the gun's centre at canvas point `spot`.
-- A spot (design px from the canvas centre) on the screen (absolute px), and
-- the canvas's design-px-to-screen-px factor.
local function spotOnScreen(spot: Vector2): (Vector2, number)
	local fit = canvas and canvas:FindFirstChild("Fit")
	local factor = if fit and fit:IsA("UIScale") then fit.Scale else 1
	if not canvas then
		return spot, factor
	end
	return canvas.AbsolutePosition + canvas.AbsoluteSize / 2 + spot * factor, factor
end

local function cameraFor(spot: Vector2, zoom: number): CFrame
	-- where the spot is in the stage view (it covers the whole screen, the
	-- canvas only the part under Roblox's top bar), and the view's own shape
	local fx, fy = 0.5 + spot.X / DESIGN.X, 0.5 + spot.Y / DESIGN.Y
	local aspect, k = DESIGN.X / DESIGN.Y, 1
	local view = stageView
	if view and view.AbsoluteSize.X > 0 and view.AbsoluteSize.Y > 0 then
		local p, factor = spotOnScreen(spot)
		local vs = view.AbsoluteSize
		fx = (p.X - view.AbsolutePosition.X) / vs.X
		fy = (p.Y - view.AbsolutePosition.Y) / vs.Y
		aspect = vs.X / vs.Y
		-- the gun keeps its size next to the UI: a view taller than the
		-- canvas pulls the camera back
		k = vs.Y / math.max(DESIGN.Y * factor, 1)
	end
	local dist = (cameraHome.Position - standPos).Magnitude * zoom * k
	local halfH = dist * math.tan(math.rad(FOV / 2))
	local halfW = halfH * aspect
	-- screen fraction -> offset from the view centre, in studs at the gun's distance
	local dx = (fx - 0.5) * 2 * halfW
	local dy = (fy - 0.5) * 2 * halfH
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
	local k = if cfg then CLASS_SIZE[cfg.class] or 1 else 1
	local scale =
		math.min(GUN_LENGTH * k / math.max(size.Z, 0.3), GUN_HEIGHT * k / math.max(size.Y, 0.3))
	m:ScaleTo(math.clamp(scale, 0.4, 4))
	-- ScaleTo keeps the model's original scaling origin, which moves it off the
	-- centre set in presentable(): centre the pivot again after scaling, or it
	-- turns about a point 1-2 studs away and sits off its screen spot
	local box = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position)
	m.Parent = view
	gunOnStand = m
	if animate then
		UiSfx.claim() -- switching guns / skins is silent (owner 2026-11-20), no click either
		swapRot.Value = CFrame.new(0, -0.3, 0)
			* CFrame.Angles(math.rad(-12), math.rad(-18), math.rad(-6))
		tween(swapRot, 0.55, { Value = CFrame.new() }, BACK)
	end
	m:PivotTo(poseCFrame())
end

local function onRender(dt: number)
	-- the drawn turn eases toward the drag (smooth, no jumps); the wobble
	-- fades out while dragging and back in once the gun is home
	dragShown = dragShown:Lerp(dragTarget.Value, 1 - math.exp(-dt * DRAG_FOLLOW))
	local resting = not dragging and dragTween == nil
	wobbleAmount += ((if resting then 1 else 0) - wobbleAmount) * math.min(
		1,
		dt * (if resting then 1.2 else 6)
	)
	local m = gunOnStand
	if m then
		m:PivotTo(poseCFrame())
	end
	local cam = stageCam
	if cam then
		local s = spotValue.Value
		local goal = cameraFor(Vector2.new(s.X, s.Y), zoomValue.Value)
		cam.CFrame = cam.CFrame:Lerp(goal, 1 - math.exp(-dt * 10))
		-- the floor shadow follows the gun's spot and shrinks as it pulls back
		local z = math.max(zoomValue.Value, 0.5)
		-- the same screen point, in the back canvas's own design px
		local p, factor = spotOnScreen(Vector2.new(s.X, s.Y))
		local back = backCanvas
		local bf = if back and back.AbsoluteSize.Y > 0 then back.AbsoluteSize.Y / DESIGN.Y else 1
		local at = if back then (p - back.AbsolutePosition) / bf else p
		local k = factor / bf
		floorShadow.Position = UDim2.fromOffset(at.X, at.Y + FLOOR_DROP / z * k)
		floorShadow.Size = UDim2.fromOffset(520 / z * k, 44 / z * k)
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

	local vf = Instance.new("ViewportFrame")
	vf.Name = "Stage"
	vf.Size = UDim2.fromScale(1, 1)
	-- see-through, over Backdrop (the stage colour, shade and floor shadow)
	-- and under the Canvas
	-- see-through over Backdrop (the violet wash over the blurred lobby)
	vf.BackgroundTransparency = 1
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(150, 158, 196)
	vf.LightColor = Color3.fromRGB(255, 250, 242)
	vf.LightDirection = Vector3.new(-0.55, -1, -0.75)
	vf.ZIndex = 1
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
	local classLabel = canvas:FindFirstChild("GunClass")
	if classLabel and classLabel:IsA("TextLabel") then
		classLabel.Text = if cfg
			then string.upper(if cfg.class == "MachineGun" then "HEAVY" else cfg.class)
			else ""
	end
	-- the room's light takes the skin line's colour (each skin changes the
	-- space around the gun, like a lit scene; Stock / no colour = soft white)
	if stageLight then
		local c = Locker.COLORS[previewLine]
		tween(stageLight, 0.5, {
			ImageColor3 = if c and previewLine ~= "Stock" then c else Color3.fromHex("C8C8D0"),
			ImageTransparency = if c and previewLine ~= "Stock" then 0.58 else 0.7,
		})
	end
	-- the skin on the stage: its emblem and name
	clearEmblems(skinTag)
	makeEmblem(skinTag, previewLine, 30, 1)
	local label = skinTag:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = lineTitle(previewLine)
	end
	-- the SKIN tile shows the equipped skin (inside its pop holder: the holder
	-- has no Value label, so the words used to stay on the template's skin)
	local skinHolder = kinds:FindFirstChild("SKIN")
	local skinTile = if skinHolder then Pivot.item(skinHolder) else nil
	if skinTile and skinTile:IsA("GuiObject") then
		local eq = equippedLine(selectedGun)
		clearEmblems(skinTile)
		local e = makeEmblem(skinTile, eq, 64)
		e.Position = UDim2.fromOffset(28, 28)
		local value = skinTile:FindFirstChild("Value")
		if value and value:IsA("TextLabel") then
			value.Text = lineTitle(eq)
		end
	end
end

local function styleGunCard(card: GuiButton, on: boolean)
	tween(card, 0.14, {
		BackgroundColor3 = if on then ALLY else CARD,
		BackgroundTransparency = if on then 0 else 0.25,
	})
	local name = card:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		name.TextColor3 = if on then INK else WHITE
	end
	local icon = card:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		-- a rendered picture keeps its own colours; a flat silhouette is tinted
		icon.ImageColor3 = if StateValues.get(icon, "Rendered") == true or not on
			then WHITE
			else INK
	end
end

local function refreshGunCards()
	for gunId, card in gunCards do
		local on = gunId == selectedGun
		-- the card shows the gun in its equipped skin (ItemIcons, pre-rendered
		-- like RIVALS' list), the flat silhouette if there's no picture
		local icon = card:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			local pic = ItemIcons.get(gunId, equippedLine(gunId))
			icon.Image = pic or Theme.GUN[gunId] or ""
			StateValues.set(icon, "Rendered", pic ~= nil)
		end
		styleGunCard(card, on)
		-- the equipped skin: its emblem and name under the gun's name
		local row = card:FindFirstChild("Skin")
		if row then
			local line = equippedLine(gunId)
			clearEmblems(row)
			makeEmblem(row, line, 14, 1)
			local label = row:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.Text = lineTitle(line)
				label.TextColor3 = if on then INK elseif line == "Stock" then MUTED else WHITE
			end
		end
	end
end

-- Call after the card is parented: a layout item is wrapped so it grows from
-- its centre, anything else is re-anchored to its centre.
local function hoverable(card: GuiButton, lift: number?)
	Pivot.prepare(card)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = card
	local up = lift or 1.03
	card.MouseEnter:Connect(function()
		tween(pop, 0.12, { Scale = up })
	end)
	card.MouseLeave:Connect(function()
		tween(pop, 0.14, { Scale = 1 })
	end)
	card.Activated:Connect(function()
		local dip = tween(pop, 0.07, { Scale = up * 0.95 })
		dip.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				tween(pop, 0.24, { Scale = up })
			end
		end)
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
		local headRow = group:FindFirstChild("HeadRow")
		local head = headRow and headRow:FindFirstChild("Head")
		if head and head:IsA("TextLabel") then
			head.Text = class[2]
		end
		local count = headRow and headRow:FindFirstChild("Count")
		if count and count:IsA("TextLabel") then
			count.Text = tostring(#ids)
		end
		local grid = child(group, "Grid") :: Frame
		for i, id in ids do
			local card = (templates:WaitForChild("GunCard") :: GuiButton):Clone()
			card.Name = id
			card.LayoutOrder = i
			local icon = child(card, "Icon") :: ImageLabel
			icon.Image = Theme.GUN[id] or ""
			local share = ICON_WIDTH[class[1]] or 1
			icon.Size = UDim2.fromOffset(math.floor(icon.Size.X.Offset * share), icon.Size.Y.Offset)
			local name = child(card, "Name") :: TextLabel
			local cfg = Weapons.get(id)
			name.Text = string.upper(if cfg then cfg.displayName else id)
			card.Activated:Connect(function()
				if selectedGun ~= id then
					selectGun(id)
				end
			end)
			card.Parent = grid
			hoverable(card)
			gunCards[id] = card
		end
		group.Parent = gunsList
	end
	refreshGunCards()
end

-- Skins tray ---------------------------------------------------------------------------
-- The previewed tile fills with its line's colour (ink text on light ones);
-- the rest are dark plates. A check marks the equipped one.
local function refreshTiles()
	local equipped = equippedLine(selectedGun)
	for _, holder in strip:GetChildren() do
		local t = Pivot.item(holder)
		if t:IsA("GuiButton") then
			local on = t.Name == previewLine
			local color = Locker.COLORS[t.Name] or WHITE
			tween(t, 0.16, {
				BackgroundColor3 = if on then color else CARD,
				BackgroundTransparency = if on then 0 else 0.2,
			})
			local name = t:FindFirstChild("Name")
			if name and name:IsA("TextLabel") then
				name.TextColor3 = if on then inkOn(color) else WHITE
			end
			-- on a filled tile the emblem turns ink (a light line colour would hide it)
			local e = t:FindFirstChild("Emblem")
			if e then
				local mark = if on then inkOn(color) else color
				local diamond = e:FindFirstChild("Diamond")
				local letter = e:FindFirstChild("Letter")
				local art = e:FindFirstChild("Art")
				if diamond and diamond:IsA("Frame") then
					diamond.BackgroundColor3 = mark
				end
				if letter and letter:IsA("TextLabel") then
					letter.TextColor3 = if on then color else inkOn(color)
				end
				if art and art:IsA("ImageLabel") then
					art.ImageColor3 = mark
				end
			end
			local check = t:FindFirstChild("Check")
			if check and check:IsA("GuiObject") then
				check.Visible = t.Name == equipped
			end
			local pop = t:FindFirstChild("Pop")
			if pop and pop:IsA("UIScale") then
				tween(pop, 0.16, { Scale = if on then 1.04 else 1 })
			end
		end
	end
	local count = tray:FindFirstChild("Count")
	if count and count:IsA("TextLabel") then
		count.Text = string.format("%d OWNED", #ownedLines(selectedGun))
	end
end

local function buildTiles()
	for _, c in strip:GetChildren() do
		if c:IsA("GuiButton") or StateValues.get(c, "PivotHolder") == true then
			c:Destroy()
		end
	end
	strip.CanvasPosition = Vector2.zero
	for i, line in ownedLines(selectedGun) do
		local t = (templates:WaitForChild("SkinTile") :: GuiButton):Clone()
		t.Name = line
		t.LayoutOrder = i
		local w, h = t.Size.X.Offset, t.Size.Y.Offset
		local pic = ItemIcons.get(selectedGun, line)
		local model = if pic then nil else Locker.skinModel(selectedGun, line)
		if pic then
			local art = Instance.new("ImageLabel")
			art.Name = "Thumb"
			art.Position = UDim2.fromOffset(10, 48)
			art.Size = UDim2.fromOffset(w - 20, h - 100)
			art.BackgroundTransparency = 1
			art.Image = pic
			art.ScaleType = Enum.ScaleType.Fit
			art.ZIndex = t.ZIndex + 1
			art.Parent = t
		elseif model then
			thumb(t, model, w - 20, h - 100, UDim2.fromOffset(10, 48))
		end
		local e = makeEmblem(t, line, 32)
		e.Position = UDim2.fromOffset(16, 14)
		local name = child(t, "Name") :: TextLabel
		name.Text = lineTitle(line)
		t.Activated:Connect(function()
			LockerController.preview(line)
			if equippedLine(selectedGun) ~= line then
				LobbyNet.event("LockerRequest"):FireServer("equip", selectedGun, line)
			end
			refreshTiles()
		end)
		t.Parent = strip
		hoverable(t, 1.04)
	end
	refreshTiles()
end

local function home(obj: GuiObject): UDim2
	local h = StateValues.get(obj, "Home")
	if typeof(h) ~= "UDim2" then
		h = obj.Position
		StateValues.set(obj, "Home", h)
	end
	return h :: UDim2
end

local function moveName(x: number)
	for _, n in { "GunClass", "GunName", "SkinTag" } do
		local g = canvas:FindFirstChild(n)
		if g and g:IsA("GuiObject") then
			local h = home(g)
			tween(g, 0.45, { Position = UDim2.new(0.5, x, h.Y.Scale, h.Y.Offset) })
		end
	end
end

-- The skins view: the gun goes in the middle of the free band between the
-- name block and the tray, pulled back to fit it (a phone's canvas is
-- shorter than 1080, so a fixed spot ran into the title).
local TRAY_FREE = 498 -- design px of that band on a 1920 x 1080 canvas
local function trayView(): (Vector2, number)
	local fit = canvas:FindFirstChild("Fit")
	local factor = if fit and fit:IsA("UIScale") and fit.Scale > 0 then fit.Scale else 1
	local h = canvas.AbsoluteSize.Y / factor
	if h <= 0 then
		return TRAY_SPOT, TRAY_ZOOM
	end
	local function y(o: GuiObject, edge: number): number
		local at = home(o)
		local size = o.Size.Y.Scale * h + o.Size.Y.Offset
		return at.Y.Scale * h + at.Y.Offset + (edge - o.AnchorPoint.Y) * size
	end
	local tag = canvas:FindFirstChild("SkinTag")
	local top = if tag and tag:IsA("GuiObject") then y(tag, 1) else 200
	local bottom = y(tray, 0)
	local free = math.max(bottom - top, 120)
	return Vector2.new(0, (top + bottom) / 2 - h / 2),
		TRAY_ZOOM * math.max(1, TRAY_FREE / free) ^ 0.85
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
	local side = canvas:FindFirstChild("Side")
	local sideHome = if side and side:IsA("GuiObject") then home(side) else nil
	if open then
		buildTiles()
		tween(gunsList, 0.35, { Position = gunsHome + UDim2.fromOffset(-620, 0) })
		if side and sideHome then
			tween(side, 0.35, { Position = sideHome + UDim2.fromOffset(-640, 0) })
		end
		tween(kinds, 0.3, { Position = kindsHome + UDim2.fromOffset(0, 260) })
		tray.Visible = true
		tray.Position = trayHome + UDim2.fromOffset(0, 340)
		tween(tray, 0.45, { Position = trayHome })
		local spot, zoom = trayView()
		tween(spotValue, 0.6, { Value = Vector3.new(spot.X, spot.Y, 0) })
		tween(zoomValue, 0.6, { Value = zoom })
		moveName(spot.X)
	else
		tween(gunsList, 0.4, { Position = gunsHome })
		if side and sideHome then
			tween(side, 0.4, { Position = sideHome })
		end
		tween(kinds, 0.4, { Position = kindsHome })
		local t = tween(tray, 0.3, { Position = trayHome + UDim2.fromOffset(0, 340) })
		t.Completed:Once(function()
			if not trayOpen then
				tray.Visible = false
			end
		end)
		tween(spotValue, 0.6, { Value = Vector3.new(MAIN_SPOT.X, MAIN_SPOT.Y, 0) })
		tween(zoomValue, 0.6, { Value = 1 })
		moveName(MAIN_SPOT.X)
		if previewLine ~= equippedLine(selectedGun) then
			LockerController.preview(equippedLine(selectedGun))
		end
	end
end

-- Tabs -------------------------------------------------------------------------------
local WEAPON_PARTS = { "Guns", "Kinds", "Hint", "GunClass", "GunName", "SkinTag", "DragArea" }

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
					c.TextColor3 = if on then INK else Color3.fromHex("B8B8BB")
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
	-- hide the whole 3D stage, not the gun's parts: Textures and Decals ignore
	-- LocalTransparencyModifier, so the skin's textures floated on (owner,
	-- 2026-11-16: "the gun outline should disappear")
	if stageView then
		stageView.Visible = weapons
	end
	floorShadow.Visible = weapons
	soonLabel.Visible = not weapons
	soonLabel.Text = if name == "ABILITIES" then "MOD COLLECTION  ·  SOON" else "EMOTES  ·  SOON"
end

-- Open / close -----------------------------------------------------------------------
local function slideIn(obj: GuiObject, dx: number, dy: number, delay: number)
	local h = home(obj)
	obj.Position = h + UDim2.fromOffset(dx, dy)
	task.delay(delay, function()
		if isOpen then
			tween(obj, 0.45, { Position = h })
		end
	end)
end

-- What the Locker shows once you're "in": the screen, the stage and its
-- staged entrance (open() gets here through the wipe).
local function reveal()
	trayOpen = false
	tray.Visible = false
	tray.Position = home(tray)
	gui.Enabled = true
	enterStage()
	setTab("WEAPONS")
	if next(gunCards) == nil then
		buildGuns()
	end
	selectGun(if Locker.gunModel(selectedGun) then selectedGun else "Vandal")
	moveName(MAIN_SPOT.X)
	resetClose()
	-- the open, in a beat: the wash fades in, the panel and its list slide in,
	-- the cards cascade, the gun swings in big, the header drops in piece by
	-- piece, the tiles rise one after another, the close pops last
	local backdrop = gui:FindFirstChild("Backdrop")
	if backdrop and backdrop:IsA("Frame") then
		-- opaque (owner 2026-11-20: no see-through blurred world behind the
		-- gun): the charcoal gradient, the skin-tinted light and the floor shadow
		backdrop.BackgroundTransparency = 1
		tween(backdrop, 0.3, { BackgroundTransparency = 0 })
		local shade = backdrop:FindFirstChild("Shade")
		if shade and shade:IsA("Frame") then
			shade.BackgroundTransparency = 1
			tween(shade, 0.4, { BackgroundTransparency = 0 })
		end
	end
	local side = canvas:FindFirstChild("Side")
	if side and side:IsA("GuiObject") then
		slideIn(side, -180, 0, 0)
	end
	slideIn(child(canvas, "Title"), -80, 0, 0.04)
	slideIn(child(canvas, "Tabs"), -80, 0, 0.07)
	slideIn(gunsList, -120, 0, 0.06)
	local n = 0
	for _, card in gunCards do
		local sc = card:FindFirstChild("Pop")
		if sc and sc:IsA("UIScale") and n < 18 then
			n += 1
			sc.Scale = 0.82
			task.delay(0.1 + n * 0.018, function()
				if isOpen then
					tween(sc, 0.3, { Scale = 1 })
				end
			end)
		end
	end
	-- the gun swings in from a big angle (overrides the swap's small entrance)
	swapRot.Value = CFrame.new(0, -0.8, 0)
		* CFrame.Angles(math.rad(-16), math.rad(-42), math.rad(-8))
	tween(swapRot, 0.75, { Value = CFrame.new() })
	slideIn(child(canvas, "GunClass"), 0, -50, 0.12)
	slideIn(child(canvas, "GunName"), 0, -50, 0.16)
	slideIn(child(canvas, "SkinTag"), 0, -50, 0.2)
	slideIn(kinds, 0, 160, 0.14)
	local t = 0
	for _, holder in kinds:GetChildren() do
		local tile = Pivot.item(holder)
		local sc = tile:FindFirstChild("Pop")
		if sc and sc:IsA("UIScale") then
			t += 1
			sc.Scale = 0.8
			task.delay(0.22 + t * 0.06, function()
				if isOpen then
					tween(sc, 0.32, { Scale = 1 })
				end
			end)
		end
	end
	local closeB = child(canvas, "Close") :: GuiObject
	local cs = closeB:FindFirstChild("Pop")
	if cs and cs:IsA("UIScale") then
		cs.Scale = 0
		task.delay(0.3, function()
			if isOpen then
				tween(cs, 0.3, { Scale = 1 })
			end
		end)
	end
end

local function conceal()
	trayOpen = false
	gui.Enabled = false
	gunsList.Position = home(gunsList)
	kinds.Position = home(kinds)
	leaveStage()
end

-- Going into the Locker, after RIVALS' (vault/02 Art/UI Lobby Overhaul.md →
-- Locker): the world camera rises (accelerating, RISE studs in RISE_TIME),
-- a charcoal wipe sweeps down the screen, and while it covers the screen the
-- Locker appears behind it, so you come out of the wipe in a new place.
-- Leaving: the wipe sweeps back up and the camera is home again under it.
-- Reduced motion: straight in and out.
-- a little more subtle than RIVALS' (owner 2026-11-20): was 25 studs, 0.9 / 0.75 s
local RISE, RISE_TIME = 14, 0.32
local WIPE_IN, WIPE_OUT = 0.72, 0.6
local wipe: Frame
local savedCamType: Enum.CameraType? = nil
local passToken = 0

local function restoreCamera()
	if savedCamType then
		workspace.CurrentCamera.CameraType = savedCamType
		savedCamType = nil
	end
end

-- Run the wipe from one end to the other; `atCover` runs when it covers the
-- screen (half way: the wipe is two screens tall, eased In-Out).
local function sweep(fromY: number, toY: number, time: number, atCover: () -> ())
	wipe.Visible = true
	wipe.Position = UDim2.new(0.5, 0, fromY, 0)
	local tw = TweenService:Create(
		wipe,
		TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
		{ Position = UDim2.new(0.5, 0, toY, 0) }
	)
	tw:Play()
	task.delay(time * 0.5, atCover)
	tw.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			wipe.Visible = false
		end
	end)
end

-- Every skin this player owns, asked for from the server (Shared/SkinStore: skins are delivered on
-- demand; the equipped ones are usually here already). Arrivals redraw below.
local function wantOwned()
	local list: { { string } } = {}
	for gun, lines in PlayerData.skins(player) do
		for _, line in lines do
			table.insert(list, { line, SkinStore.modelName(gun, line) })
		end
	end
	SkinStore.want(list)
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	wantOwned()
	passToken += 1
	local my = passToken
	UiSfx.cue("LockerIn")
	if UiMotion.reduced() then
		reveal()
		return
	end
	local cam = workspace.CurrentCamera
	if not savedCamType then
		savedCamType = cam.CameraType
	end
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(
		cam,
		TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = cam.CFrame * CFrame.new(0, RISE, 0) }
	):Play()
	sweep(-1, 2, WIPE_IN, function()
		if passToken == my and isOpen then
			reveal()
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
		restoreCamera()
		return
	end
	sweep(2, -1, WIPE_OUT, function()
		if passToken == my and not isOpen then
			conceal()
			restoreCamera()
		end
	end)
end

local function release()
	if not dragging then
		return
	end
	dragging = false
	lastPos = nil
	local tw = tween(
		dragTarget,
		RETURN_TIME,
		{ Value = CFrame.new() },
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	dragTween = tw
	tw.Completed:Once(function()
		if dragTween == tw then
			dragTween = nil
		end
	end)
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
	gunsList = child(canvas, "Guns")
	tray = child(canvas, "Tray")
	strip = child(tray, "Strip")
	kinds = child(canvas, "Kinds")
	gunName = child(canvas, "GunName")
	skinTag = child(canvas, "SkinTag")
	soonLabel = child(canvas, "Soon")
	local back = child(child(gui, "Backdrop"), "BackCanvas") :: Frame
	backCanvas = back
	floorShadow = child(back, "Floor")
	local light = back:FindFirstChild("Light")
	stageLight = if light and light:IsA("ImageLabel") then light else nil
	templates = UiRoot.templates():WaitForChild("Lobby") :: Folder
	for _, o in { gunsList, kinds, tray, child(canvas, "GunName"), child(canvas, "SkinTag") } do
		home(o :: GuiObject)
	end

	Plates.deepen(gui)
	-- the wipe (above everything, two screens tall, soft top and bottom edges)
	local wipeGui = Instance.new("ScreenGui")
	wipeGui.Name = "LockerWipe"
	wipeGui.ResetOnSpawn = false
	wipeGui.IgnoreGuiInset = true
	wipeGui.ScreenInsets = Enum.ScreenInsets.None
	wipeGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	wipeGui.ClipToDeviceSafeArea = false
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
	wipeGui.Parent = playerGui
	wipe = w
	Router.register("Locker", { open = open, close = close, screen = "Locker" })
	resetClose = CloseButton.hook(child(canvas, "Close") :: GuiButton, function()
		Router.close()
	end)
	for _, b in (child(canvas, "Tabs") :: Frame):GetChildren() do
		if b:IsA("GuiButton") then
			b.Activated:Connect(function()
				if tab ~= b.Name then
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
					setTray(true)
				end
			end)
		end
	end
	local backButton = child(tray, "Back") :: GuiButton
	hoverable(backButton)
	backButton.Activated:Connect(function()
		setTray(false)
	end)
	Locker.observe(player, function()
		if isOpen then
			refreshGunCards()
			refreshHeader()
			if trayOpen then
				refreshTiles()
			end
		end
	end)
	-- a skin delivered on demand: the gun on the stand and the tiles pick it up
	local redrawQueued = false
	SkinStore.arrived:Connect(function(line: string, name: string)
		if not isOpen then
			return
		end
		if line == previewLine and name == SkinStore.modelName(selectedGun, line) then
			placeGun(selectedGun, previewLine, false)
		end
		if trayOpen and not redrawQueued then
			redrawQueued = true
			task.delay(0.2, function()
				redrawQueued = false
				if isOpen and trayOpen then
					buildTiles()
					refreshTiles()
				end
			end)
		end
	end)
	-- a new skin (a case opening) adds a tile while the tray is open
	task.spawn(function()
		local value = player:WaitForChild(PlayerData.SKINS, 60)
		if value and value:IsA("StringValue") then
			value.Changed:Connect(function()
				if isOpen and trayOpen then
					buildTiles()
					refreshTiles()
				end
			end)
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
