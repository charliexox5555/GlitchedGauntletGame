--!strict
-- Lays out an icon sheet for the item-icon renders (vault/02 Art/UI Lobby
-- Overhaul.md → Shop: RIVALS shows pre-rendered item pictures, not live 3D).
-- Lobby place, Edit mode. Puts StarterGui._IconSheet on screen: up to
-- COLS x ROWS guns / skins, each in its own ViewportFrame at the same 3/4 angle,
-- on a flat background (`BG` set to black, then white). Two captures of the
-- same sheet give each pixel's alpha (tools/render/icon_sheet.py), so edges
-- are clean without a colour key. Delete _IconSheet when done.
--
-- Call: run this file's Source with loadstring; it returns function(list,
-- white) that lays out `list` on a black (white = false) or white sheet.
--   list: { "Weapons/Vandal", "WeaponSkins/Prism/Vandal", ... }

local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

local COLS, ROWS = 5, 4

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

return function(list: { string }, white: boolean): string
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
	bg.BackgroundColor3 = if white then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	bg.Parent = sg
	local missing = {}
	for i, path in list do
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
		vf.Ambient = Color3.fromRGB(185, 185, 195)
		vf.LightColor = Color3.new(1, 1, 1)
		vf.LightDirection = Vector3.new(-0.4, -1, -0.5)
		local m = presentable(src)
		local _, size = m:GetBoundingBox()
		m.Parent = vf
		local cam = Instance.new("Camera")
		cam.FieldOfView = 12
		local aspect = (1920 / COLS) / (1080 / ROWS)
		-- the 3/4 tilt shows some depth (X) above and below: frame for it
		local half = math.max((size.Y + size.X * 0.35) / 2, size.Z / 2 / aspect) * 1.2
		local dist = half / math.tan(math.rad(cam.FieldOfView / 2)) + size.X
		local yaw, pitch = math.rad(18), math.rad(14)
		local dir = Vector3.new(
			math.cos(yaw) * math.cos(pitch),
			math.sin(pitch),
			math.sin(yaw) * math.cos(pitch)
		)
		cam.CFrame = CFrame.lookAt(dir * dist, Vector3.zero)
		cam.Parent = vf
		vf.CurrentCamera = cam
		vf.Parent = bg
	end
	sg.Parent = SG
	return string.format(
		"%d on the sheet, missing: %s",
		#list - #missing,
		table.concat(missing, ", ")
	)
end
