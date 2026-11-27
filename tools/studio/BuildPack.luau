--!strict
-- Builds the SURGE power pack template ReplicatedStorage.Crates.PowerPack from its uploaded mesh
-- (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26: a card pack that rips open).
-- Source: tools/blender/crates/build_power_pack.py -> art-source/lobby/Exports/PowerPack.fbx (asset ASSET).
-- Run in Edit mode (command bar or MCP execute_luau); re-run after a re-upload. Save the place after.
--
-- Every part is anchored: Util/PackOpening places them each frame (the pack shakes, Top_Seal tears off from its
-- notch on the left and flies away pivoting on TopPivot, its right end). Blender to Roblox: (x, y, z) -> (-x, z, y).
-- The front label (Body_Label) carries the art as a SurfaceGui (Surge theme: charcoal, the gold bolt, SURGE,
-- POWER PACK); no game logo on it (the game's name is being changed back to Draft Duels).

local ASSET = 73626878472922
local BOLT = "rbxassetid://135481311713094" -- art-source/ui/pack/surge_bolt.png
local TOP_PIVOT = Vector3.new(-0.86, 0.93, 0) -- build_power_pack.py TOP_PIVOT in Roblox axes

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local GOLD = Color3.fromHex("FFC83D")

local LOOK: { [string]: { Color3 | Enum.Material } } = {
	Body_Foil = { Color3.fromHex("2B2D33"), Enum.Material.Foil },
	Body_Seal = { Color3.fromHex("C9961F"), Enum.Material.Foil },
	Top_Seal = { Color3.fromHex("C9961F"), Enum.Material.Foil },
	Body_Label = { Color3.fromHex("141518"), Enum.Material.SmoothPlastic },
}

local loaded = InsertService:LoadAsset(ASSET)
local model = Instance.new("Model")
model.Name = "PowerPack"
local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(0.2, 0.2, 0.2)
root.CFrame = CFrame.new()
root.Transparency = 1
root.Anchored = true
root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
root.Parent = model
model.PrimaryPart = root

local parts: { [string]: MeshPart } = {}
for _, d in loaded:GetDescendants() do
	if d:IsA("MeshPart") then
		local p = d:Clone()
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
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

-- the label art: a SurfaceGui on the plate's front face (the plate faces -Z, the pack's front)
local label = parts.Body_Label
local gui = Instance.new("SurfaceGui")
gui.Name = "Art"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(640, 760)
gui.LightInfluence = 0.15
gui.Brightness = 1.1
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ClipsDescendants = true
gui.Parent = label

local back = Instance.new("Frame")
back.Name = "Back"
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.new(1, 1, 1)
back.BorderSizePixel = 0
back.Parent = gui
local bg = Instance.new("UIGradient")
bg.Rotation = 90
bg.Color = ColorSequence.new(Color3.fromHex("26282F"), Color3.fromHex("101114"))
bg.Parent = back
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 28)
corner.Parent = back
-- two slanted gold bands behind the bolt (the surge)
for i, spec in { { 0.36, 120, 0.82 }, { 0.6, 46, 0.7 } } do
	local band = Instance.new("Frame")
	band.Name = "Band" .. i
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, spec[1])
	band.Size = UDim2.fromOffset(1100, spec[2])
	band.Rotation = -18
	band.BackgroundColor3 = GOLD
	band.BackgroundTransparency = spec[3]
	band.BorderSizePixel = 0
	band.ZIndex = 1
	band.Parent = gui
end
local bolt = Instance.new("ImageLabel")
bolt.Name = "Bolt"
bolt.BackgroundTransparency = 1
bolt.Image = BOLT
bolt.ScaleType = Enum.ScaleType.Fit
bolt.AnchorPoint = Vector2.new(0.5, 0)
bolt.Position = UDim2.new(0.5, 0, 0, 52)
bolt.Size = UDim2.fromOffset(260, 330)
bolt.ZIndex = 3
bolt.Parent = gui
local function text(name: string, t: string, font: Font, size: number, color: Color3, y: number)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = t
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.fromOffset(600, size + 10)
	l.ZIndex = 4
	l.Parent = gui
	return l
end
text("Title", "SURGE", HEAVY, 132, Color3.fromHex("F4F6F9"), 404)
text("Kind", "POWER PACK", HEAVY, 50, GOLD, 548)
local rule = Instance.new("Frame")
rule.Name = "Rule"
rule.AnchorPoint = Vector2.new(0.5, 0)
rule.Position = UDim2.new(0.5, 0, 0, 626)
rule.Size = UDim2.fromOffset(420, 4)
rule.BackgroundColor3 = GOLD
rule.BackgroundTransparency = 0.35
rule.BorderSizePixel = 0
rule.ZIndex = 4
rule.Parent = gui
text("Foot", "1 POWER  ·  NEVER A DUPLICATE", BOLD, 26, Color3.fromHex("A9B2BF"), 650)

model:SetAttribute("TopPivot", TOP_PIVOT)
model:SetAttribute("Source", "tools/studio/BuildPack.luau, asset " .. ASSET)
local folder = ReplicatedStorage:FindFirstChild("Crates")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Crates"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("PowerPack")
if old then
	old:Destroy()
end
model.Parent = folder
local info = {}
for name, p in parts do
	table.insert(info, `{name} pos={p.Position} size={p.Size} rot={p.CFrame.LookVector}`)
end
return "built Crates.PowerPack\n" .. table.concat(info, "\n")
