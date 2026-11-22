--!strict
-- Hero shots for the Shop's bundle cards (vault/01 Design/Shop Economy and Art v1.md → Art
-- plan): one skin per sheet, near side-on with a slight front three-quarter turn, muzzle
-- a touch up, filling the screen so the capture is as big as it gets. Same capture flow
-- as RenderPortraits.luau: Lobby place, Edit mode, StarterGui.ShowDevelopmentGui = true;
-- capture on black, set _IconSheet.BG white, capture again; then
--   python tools/render/icon_sheet.py BLACK WHITE art-source/ui/shop/heroes "<PATH>" --cols 1 --rows 1 --maxw 1600
-- and rename Gun_Line.png to hero_<line>.png. Delete _IconSheet when done.
--   PATH: "WeaponSkins/<Line>/<Gun>"

local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

local PATH = "WeaponSkins/RuinBlighted/Vandal" -- set per shot
local TILT = math.rad(9)
local YAW, PITCH = math.rad(14), math.rad(-5)
local FOV = 22

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

local node: Instance? = RS
for part in string.gmatch(PATH, "[^/]+") do
	node = node and node:FindFirstChild(part)
end
assert(node and node:IsA("Model"), "RenderHeroShots: no model at " .. PATH)

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

local dir =
	Vector3.new(-math.cos(YAW) * math.cos(PITCH), math.sin(PITCH), math.sin(YAW) * math.cos(PITCH))
local look = CFrame.lookAt(dir, Vector3.zero)
local right, up = look.RightVector, look.UpVector
local t = math.tan(math.rad(FOV / 2))
local vp = workspace.CurrentCamera.ViewportSize
local aspect = vp.X / vp.Y

local vf = Instance.new("ViewportFrame")
vf.Name = PATH
vf.BackgroundTransparency = 1
vf.Size = UDim2.fromScale(1, 1)
vf.Ambient = Color3.fromRGB(138, 138, 150)
vf.LightColor = Color3.new(1, 1, 1)
vf.LightDirection = Vector3.new(0.6, -1, -0.35)
local m = presentable(node :: Model)
m:PivotTo(CFrame.Angles(TILT, 0, 0))
local box = m:GetBoundingBox()
m:PivotTo(CFrame.new(-box.Position) * m:GetPivot())
m.Parent = vf
local cf, size = m:GetBoundingBox()
local extX, extY, depth = 0, 0, 0
for _, sx in { -1, 1 } do
	for _, sy in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = cf:PointToWorldSpace(size * Vector3.new(sx, sy, sz) / 2)
			extX = math.max(extX, math.abs(p:Dot(right)))
			extY = math.max(extY, math.abs(p:Dot(up)))
			depth = math.max(depth, p:Dot(dir))
		end
	end
end
-- the vertical field of view fits the height, or the width over the screen's aspect
local ext = math.max(extY, extX / aspect)
local cam = Instance.new("Camera")
cam.FieldOfView = FOV
cam.CFrame = CFrame.lookAt(dir * (ext / t * 1.06 + depth), Vector3.zero)
cam.Parent = vf
vf.CurrentCamera = cam
vf.Parent = bg
sg.Parent = SG
pcall(function()
	game:GetService("ContentProvider"):PreloadAsync({ sg })
end)
task.wait(5) -- SurfaceAppearance textures load late
return "hero sheet ready: " .. PATH
