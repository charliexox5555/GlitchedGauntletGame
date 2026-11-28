--!strict
-- Builds ReplicatedStorage.Crates.CharmBox from the uploaded Blender FBX (asset 72211581809363).
-- Run in Studio Edit (command bar or execute_luau); save the place afterwards.

local ASSET = 72211581809363
local LID_PIVOT = Vector3.new(0, 0.345, 0.59) -- rear top hinge in Root space

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local GOLD = Color3.fromHex("F5C238")

local LOOK: { [string]: { Color3 | Enum.Material } } = {
	Body_Box = { Color3.fromRGB(37, 40, 46), Enum.Material.SmoothPlastic },
	Body_Trim = { Color3.fromRGB(17, 18, 22), Enum.Material.Metal },
	Body_Glow = { GOLD, Enum.Material.Neon },
	Body_Label = { Color3.fromRGB(14, 16, 22), Enum.Material.SmoothPlastic },
	Body_Interior = { Color3.fromRGB(8, 9, 12), Enum.Material.SmoothPlastic },
	Lid_Box = { Color3.fromRGB(37, 40, 46), Enum.Material.SmoothPlastic },
	Lid_Trim = { Color3.fromRGB(17, 18, 22), Enum.Material.Metal },
}

local loaded = InsertService:LoadAsset(ASSET)
local model = Instance.new("Model")
model.Name = "CharmBox"
model:SetAttribute("LidPivot", LID_PIVOT)

local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(0.2, 0.2, 0.2)
root.CFrame = CFrame.new()
root.Transparency = 1
root.Anchored = true
root.CanCollide = false
root.CanQuery = false
root.CanTouch = false
root.Parent = model
model.PrimaryPart = root

local parts: { [string]: MeshPart } = {}
for _, d in loaded:GetDescendants() do
	if d:IsA("MeshPart") then
		local p = d:Clone()
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		local look = LOOK[p.Name]
		if look then
			p.Color = look[1] :: Color3
			p.Material = look[2] :: Enum.Material
		end
		p.Parent = model
		parts[p.Name] = p
	end
end
loaded:Destroy()

for name in LOOK do
	assert(parts[name], "missing mesh part " .. name)
end

-- Front label SurfaceGui on Body_Label (faces -Z, Enum.NormalId.Front)
local label = parts.Body_Label
local gui = Instance.new("SurfaceGui")
gui.Name = "Art"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(512, 440)
gui.LightInfluence = 0.15
gui.Brightness = 1.15
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ClipsDescendants = true
gui.Parent = label

local back = Instance.new("Frame")
back.Name = "Back"
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromHex("0E1016")
back.BorderSizePixel = 0
back.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = back

local border = Instance.new("UIStroke")
border.Name = "AccentBorder"
border.Color = GOLD
border.Thickness = 6
border.Parent = back

for i, spec in { { 0.28, 74, 0.78 }, { 0.50, 40, 0.78 } } do
	local band = Instance.new("Frame")
	band.Name = "Stripe" .. i
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, spec[1])
	band.Size = UDim2.fromOffset(900, spec[2])
	band.Rotation = -14
	band.BackgroundColor3 = GOLD
	band.BackgroundTransparency = spec[3]
	band.BorderSizePixel = 0
	band.ZIndex = 1
	band.Parent = back
end

-- Faceted diamond emblem in upper half
local diamond = Instance.new("Frame")
diamond.Name = "Diamond"
diamond.AnchorPoint = Vector2.new(0.5, 0.5)
diamond.Position = UDim2.fromScale(0.5, 0.34)
diamond.Size = UDim2.fromOffset(96, 96)
diamond.Rotation = 45
diamond.BackgroundColor3 = GOLD
diamond.BorderSizePixel = 0
diamond.ZIndex = 2
diamond.Parent = back

local innerDiamond = Instance.new("Frame")
innerDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
innerDiamond.Position = UDim2.fromScale(0.5, 0.5)
innerDiamond.Size = UDim2.fromOffset(60, 60)
innerDiamond.BackgroundColor3 = Color3.fromHex("0E1016")
innerDiamond.BorderSizePixel = 0
innerDiamond.ZIndex = 3
innerDiamond.Parent = diamond

local coreDiamond = Instance.new("Frame")
coreDiamond.Name = "DiamondCore"
coreDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
coreDiamond.Position = UDim2.fromScale(0.5, 0.5)
coreDiamond.Size = UDim2.fromOffset(30, 30)
coreDiamond.BackgroundColor3 = GOLD
coreDiamond.BorderSizePixel = 0
coreDiamond.ZIndex = 4
coreDiamond.Parent = innerDiamond

local title = Instance.new("TextLabel")
title.Name = "TitleLabel"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0.06, 0, 0.57, 0)
title.Size = UDim2.new(0.88, 0, 0, 64)
title.FontFace = HEAVY
title.Text = "STRIKE"
title.TextSize = 54
title.TextColor3 = Color3.fromHex("F6F8FC")
title.ZIndex = 5
title.Parent = back

local sub = Instance.new("TextLabel")
sub.Name = "SubLabel"
sub.BackgroundTransparency = 1
sub.Position = UDim2.new(0.06, 0, 0.74, 0)
sub.Size = UDim2.new(0.88, 0, 0, 38)
sub.FontFace = BOLD
sub.Text = "CHARM BOX"
sub.TextSize = 30
sub.TextColor3 = GOLD
sub.ZIndex = 5
sub.Parent = back

local crates = ReplicatedStorage:FindFirstChild("Crates")
if not crates then
	local folder = Instance.new("Folder")
	folder.Name = "Crates"
	folder.Parent = ReplicatedStorage
	crates = folder
end

local existing = crates:FindFirstChild("CharmBox")
if existing then
	existing:Destroy()
end
model.Parent = crates

return "Built ReplicatedStorage.Crates.CharmBox cleanly"
