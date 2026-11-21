--!strict
-- Square "portrait" pictures of skins for tiles (CONTENTS rows, the info popup, the case
-- reveal), in the RIVALS style the owner pointed at (2026-11-20): the gun diagonal with
-- the muzzle up-left, a front three-quarter perspective view, stronger light. Rendered
-- once in Studio and uploaded as our own images (Shared/ItemPortraits); the side-on
-- pictures (RenderItemIcons.luau, Shared/ItemIcons) stay for the Locker's wide cards.
--
-- Lobby place, Edit mode, StarterGui.ShowDevelopmentGui = true while capturing (set it
-- back to false after). Lays out up to COLS x ROWS items on StarterGui._IconSheet;
-- capture on black, set BG white, capture again; tools/render/icon_sheet.py --cols 5
-- --rows 3 cuts them (alpha from the two captures). Delete _IconSheet when done.
--
-- Call: paste this file's body into the command bar / MCP execute_luau with LIST set.
--   LIST: { "WeaponSkins/Prism/Vandal", "Weapons/Vandal", ... } (max 15)

local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

local LIST: { string } = {} -- fill in
local COLS, ROWS = 5, 3
local TILT = math.rad(35) -- muzzle up
local YAW, PITCH = math.rad(28), math.rad(-8) -- front three-quarter, a little from below
local FOV = 26

local function presentable(source: Model): Model
	local m = source:Clone()
	m:PivotTo(CFrame.new())
	m.PrimaryPart = nil
	m.WorldPivot = CFrame.new()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
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
	local target: { [string]: Vector3 } =
		{ [axes[1][1]] = Vector3.zAxis, [axes[2][1]] = Vector3.yAxis, [axes[3][1]] = Vector3.xAxis }
	local vx, vy, vz = target.X, target.Y, target.Z
	if vx:Cross(vy):Dot(vz) < 0 then
		vz = -vz
	end
	m:PivotTo(CFrame.fromMatrix(Vector3.zero, vx, vy, vz))
	local box = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position)
	m:PivotTo(CFrame.new())
	return m
end

local function find(path: string): Model?
	local node: Instance? = RS
	for part in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return if node and node:IsA("Model") then node else nil
end

local old = SG:FindFirstChild("_IconSheet")
if old then
	old:Destroy()
end
local sg = Instance.new("ScreenGui")
sg.Name = "_IconSheet"
sg.IgnoreGuiInset = true
sg.ScreenInsets = Enum.ScreenInsets.None
sg.DisplayOrder = 10000
local bg = Instance.new("Frame")
bg.Name = "BG"
bg.Size = UDim2.fromScale(1, 1)
bg.BorderSizePixel = 0
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.Parent = sg
local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.BackgroundTransparency = 1
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.5)
holder.Size = UDim2.fromScale(1, 1)
holder.Parent = bg
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = COLS / ROWS
ar.Parent = holder

local dir = Vector3.new(-math.cos(YAW) * math.cos(PITCH), math.sin(PITCH), math.sin(YAW) * math.cos(PITCH))
local look = CFrame.lookAt(dir, Vector3.zero)
local right, up = look.RightVector, look.UpVector
local t = math.tan(math.rad(FOV / 2))
local missing = {}
for i, path in LIST do
	local src = find(path)
	if not src then
		table.insert(missing, path)
		continue
	end
	local col, row = (i - 1) % COLS, (i - 1) // COLS
	local vf = Instance.new("ViewportFrame")
	vf.Name = path
	vf.BackgroundTransparency = 1
	vf.Position = UDim2.fromScale(col / COLS, row / ROWS)
	vf.Size = UDim2.fromScale(1 / COLS, 1 / ROWS)
	vf.Ambient = Color3.fromRGB(138, 138, 150)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(0.6, -1, -0.35)
	local m = presentable(src)
	m:PivotTo(CFrame.Angles(TILT, 0, 0)) -- the muzzle (-Z) rises
	local box = m:GetBoundingBox()
	m:PivotTo(CFrame.new(-box.Position) * m:GetPivot())
	m.Parent = vf
	-- fit the projected box
	local cf, size = m:GetBoundingBox()
	local ext, depth = 0, 0
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf:PointToWorldSpace(size * Vector3.new(sx, sy, sz) / 2)
				ext = math.max(ext, math.abs(p:Dot(right)), math.abs(p:Dot(up)))
				depth = math.max(depth, p:Dot(dir))
			end
		end
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.CFrame = CFrame.lookAt(dir * (ext / t * 1.06 + depth), Vector3.zero)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = holder
end
sg.Parent = SG
pcall(function()
	game:GetService("ContentProvider"):PreloadAsync({ sg })
end)
task.wait(7) -- SurfaceAppearance textures load late
return string.format("%d on the sheet, missing: %s", #LIST - #missing, table.concat(missing, ", "))
