--!strict
-- A small 3D stage for showing one item (a gun or skin) inside a ViewportFrame:
-- the model laid out upright and centred, fitted to a box, posed side-on
-- with a slight tilt, turned by dragging (it eases home when let go) and a
-- gentle idle wobble, with a swap entrance when the item changes. Used by the
-- Shop's skin-bundle preview (Controllers/ShopController). The Locker has its
-- own copy of the same rules (Controllers/LockerController, v4.1 notes in
-- vault/02 Art/UI Locker.md); fold it onto this one day.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ItemStage = {}
ItemStage.__index = ItemStage

local FOV = 30
local POSE_YAW = math.rad(-90 + 26) -- the side toward the camera, turned a little
local POSE_TILT = math.rad(18) -- muzzle raised, in screen space
local DRAG_SPEED = math.rad(0.24) -- per pixel
local DRAG_FOLLOW = 6 -- per second
local RETURN_TIME = 1.2
local WOBBLE_BOB = 0.05
local WOBBLE_YAW, WOBBLE_PITCH, WOBBLE_ROLL = math.rad(3.2), math.rad(1.6), math.rad(1.2)

export type Options = {
	length: number?, -- the box an item is fitted to (studs)
	height: number?,
	distance: number?, -- camera distance (studs)
}

type Self = {
	view: ViewportFrame,
	cam: Camera,
	model: Model?,
	length: number,
	height: number,
	distance: number,
	dragTarget: CFrameValue,
	dragShown: CFrame,
	swap: CFrameValue,
	wobble: number,
	dragging: boolean,
	lastPos: Vector3?,
	dragTween: Tween?,
	conns: { RBXScriptConnection },
	running: RBXScriptConnection?,
}
export type Stage = typeof(setmetatable({} :: Self, ItemStage))

-- A display copy of `source`: anchored, scripts stripped, laid out by its own
-- pivot (which carries "upright"), its longest axis along Z and thinnest
-- along X, and its pivot moved to its bounding-box centre so it turns about
-- its middle. (The PrimaryPart is cleared: with one set, Roblox takes the
-- pivot from that part and ignores WorldPivot.)
function ItemStage.presentable(source: Model): Model
	local m = source:Clone()
	m:PivotTo(CFrame.new())
	m.PrimaryPart = nil
	m.WorldPivot = CFrame.new()
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

-- A stage filling `parent` (a transparent ViewportFrame under its siblings).
function ItemStage.new(parent: GuiObject, opts: Options?): Stage
	local o = opts or {}
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Stage"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(150, 158, 196)
	vf.LightColor = Color3.fromRGB(255, 250, 242)
	vf.LightDirection = Vector3.new(-0.55, -1, -0.75)
	vf.ZIndex = parent.ZIndex
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	local self: Self = {
		view = vf,
		cam = cam,
		model = nil,
		length = o.length or 5,
		height = o.height or 2,
		distance = o.distance or 11,
		dragTarget = Instance.new("CFrameValue"),
		dragShown = CFrame.new(),
		swap = Instance.new("CFrameValue"),
		wobble = 1,
		dragging = false,
		lastPos = nil,
		dragTween = nil,
		conns = {},
		running = nil,
	}
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.4, self.distance), Vector3.zero)
	return setmetatable(self, ItemStage)
end

function ItemStage.pose(self: Stage): CFrame
	local camRot = self.cam.CFrame.Rotation
	local t = os.clock()
	local wobble = CFrame.new(0, math.sin(t * 1.05) * WOBBLE_BOB, 0)
		* CFrame.Angles(
			math.sin(t * 0.73 + 1.3) * WOBBLE_PITCH,
			math.sin(t * 0.52) * WOBBLE_YAW,
			math.sin(t * 0.61 + 2.1) * WOBBLE_ROLL
		)
	wobble = CFrame.new():Lerp(wobble, self.wobble)
	local screen = self.dragShown * wobble * self.swap.Value * CFrame.Angles(0, 0, POSE_TILT)
	return camRot * screen * camRot:Inverse() * CFrame.Angles(0, POSE_YAW, 0)
end

-- Shows `source` (or clears the stage with nil), fitted to the box; `small`
-- shrinks it (melee). The new item swings in.
function ItemStage.show(self: Stage, source: Model?, small: boolean?)
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if not source then
		return
	end
	local m = ItemStage.presentable(source)
	local _, size = m:GetBoundingBox()
	local k = if small then 0.8 else 1
	local scale =
		math.min(self.length * k / math.max(size.Z, 0.3), self.height * k / math.max(size.Y, 0.3))
	m:ScaleTo(math.clamp(scale, 0.3, 4))
	local box = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position) -- ScaleTo keeps the old origin
	m.Parent = self.view
	self.model = m
	self.swap.Value = CFrame.new(0, -0.3, 0)
		* CFrame.Angles(math.rad(-12), math.rad(-18), math.rad(-6))
	TweenService
		:Create(self.swap, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Value = CFrame.new(),
		})
		:Play()
	m:PivotTo(self:pose())
end

local function release(self: Stage)
	if not self.dragging then
		return
	end
	self.dragging = false
	self.lastPos = nil
	local tw = TweenService:Create(
		self.dragTarget,
		TweenInfo.new(RETURN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = CFrame.new() }
	)
	self.dragTween = tw
	tw:Play()
	tw.Completed:Once(function()
		if self.dragTween == tw then
			self.dragTween = nil
		end
	end)
end

-- Dragging on `area` turns the item; letting go eases it home.
function ItemStage.bindDrag(self: Stage, area: GuiButton)
	table.insert(
		self.conns,
		area.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self.dragging = true
				self.lastPos = input.Position
				if self.dragTween then
					self.dragTween:Cancel()
					self.dragTween = nil
				end
			end
		end)
	)
	table.insert(
		self.conns,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				self.dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local last = self.lastPos or input.Position
				local d = input.Position - last
				self.lastPos = input.Position
				self.dragTarget.Value = CFrame.Angles(d.Y * DRAG_SPEED, d.X * DRAG_SPEED, 0)
					* self.dragTarget.Value
			end
		end)
	)
	table.insert(
		self.conns,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				release(self)
			end
		end)
	)
end

-- Starts / stops drawing (call while the stage is on screen only).
function ItemStage.run(self: Stage, on: boolean)
	if on and not self.running then
		self.dragTarget.Value = CFrame.new()
		self.dragShown = CFrame.new()
		self.running = RunService.RenderStepped:Connect(function(dt: number)
			self.dragShown =
				self.dragShown:Lerp(self.dragTarget.Value, 1 - math.exp(-dt * DRAG_FOLLOW))
			local resting = not self.dragging and self.dragTween == nil
			self.wobble += ((if resting then 1 else 0) - self.wobble) * math.min(
				1,
				dt * (if resting then 1.2 else 6)
			)
			local m = self.model
			if m then
				m:PivotTo(self:pose())
			end
		end)
	elseif not on and self.running then
		self.running:Disconnect()
		self.running = nil
		self.dragging = false
	end
end

return ItemStage
