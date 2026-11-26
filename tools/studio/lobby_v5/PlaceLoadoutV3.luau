--!nocheck
-- Lobby V5 RANGE: loadout terminal v3 (vault/01 Design/Range v5.md §3). Owner 2026-11-25: "the load out selectors
-- should look better and more professional". Swaps the six `RangeLoadout` terminals for the Blender kiosk
-- (tools/blender/lobby_v5/v5_loadout.py, asset 103199802564419): a grey body, charcoal trim, gunmetal cradles, a teal
-- glow in the gun bay with a real light, and a screen (SurfaceGui on a thin face part over the leaning screen mesh,
-- whose 15° tilt is baked into the mesh). The tag `RangeLoadout` goes on the new Body (WorldPrompts puts the
-- LOADOUT prompt there). Safe to run again. Edit mode; save the place after.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local IS = game:GetService("InsertService")
local V = Vector3.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local TEAL = Color3.fromHex("2bd9a8")
local RUBIK_H = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local RUBIK_B = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local ASSET = 103199802564419
local LOOK = {
	Body = { rgb(168, 170, 176), Enum.Material.SmoothPlastic, true },
	Trim = { rgb(40, 42, 46), Enum.Material.SmoothPlastic, true },
	Steel = { rgb(96, 99, 106), Enum.Material.Metal, false },
	Glow = { TEAL:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Neon, false },
	Screen = { rgb(14, 16, 20), Enum.Material.SmoothPlastic, false },
}

-- 1. the kit model (ServerStorage.V5Kit.Terminal3), pivot on the floor at its centre, front -Z ---------------------------
local old = SS.V5Kit:FindFirstChild("Terminal3")
if old then
	old:Destroy()
end
local raw = IS:LoadAsset(ASSET)
local kit = Instance.new("Model")
kit.Name = "Terminal3"
for _, p in raw:GetDescendants() do
	if p:IsA("MeshPart") then
		local role = string.match((string.gsub(p.Name, "%.%d+$", "")), "^Terminal3_(%a+)$")
		local look = role and LOOK[role]
		if look then
			p.Name = role
			p.Anchored, p.CanTouch = true, false
			p.Color, p.Material, p.CanCollide = look[1], look[2], look[3]
			p.CastShadow = role ~= "Glow"
			p.Parent = kit
		end
	end
end
raw:Destroy()
kit.WorldPivot = CFrame.new(0, 0, 0)
local screenMesh = kit:FindFirstChild("Screen")
-- the face the SurfaceGui draws on: the screen's own plane (centre (0, 5.779, -0.930), top tipped back 15°), 0.03 proud
local face = Instance.new("Part")
face.Name = "ScreenFace"
face.Anchored, face.CanCollide, face.CanTouch, face.CanQuery = true, false, false, false
face.Size = V(2.96, 1.64, 0.02)
face.Color = rgb(10, 12, 15)
face.Material = Enum.Material.SmoothPlastic
face.CastShadow = false
local tilt = CFrame.new(0, 5.7786, -0.9303) * CFrame.Angles(math.rad(15.03), 0, 0)
face.CFrame = tilt * CFrame.new(0, 0, -0.03)
face.Parent = kit
if screenMesh then
	screenMesh.CanQuery = false
end

local gui = Instance.new("SurfaceGui")
gui.Name = "Screen"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 150
gui.LightInfluence = 0
gui.Brightness = 1.15
gui.MaxDistance = 120
gui.Parent = face
local function label(parent, text, font, size, col, pos, anchor, w)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = text
	l.TextSize = size
	l.TextColor3 = col
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.AnchorPoint = anchor or Vector2.zero
	l.Position = pos
	l.Size = UDim2.new(0, w or 400, 0, size + 4)
	l.Parent = parent
	return l
end
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = rgb(16, 18, 22)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new(rgb(255, 255, 255), rgb(150, 156, 166))
grad.Parent = bg
-- left accent bar (the UI theme's slash accent), the title, a ruled sub-label, the gun icon and the key hint
local bar = Instance.new("Frame")
bar.BackgroundColor3 = TEAL
bar.BorderSizePixel = 0
bar.Position = UDim2.fromOffset(26, 34)
bar.Size = UDim2.fromOffset(8, 86)
bar.Parent = bg
label(bg, "RANGE ARMORY", RUBIK_B, 18, TEAL, UDim2.fromOffset(48, 30))
label(bg, "LOADOUT", RUBIK_H, 64, Color3.new(1, 1, 1), UDim2.fromOffset(44, 50), nil, 380)
label(bg, "GUNS  ·  SKINS  ·  LOCKER", RUBIK_B, 17, rgb(170, 176, 186), UDim2.fromOffset(48, 122))
local rule = Instance.new("Frame")
rule.BackgroundColor3 = rgb(60, 64, 72)
rule.BorderSizePixel = 0
rule.Position = UDim2.fromOffset(26, 160)
rule.Size = UDim2.new(1, -52, 0, 2)
rule.Parent = bg
-- no key chip on the screen (2026-11-26): the key differs by device; the player's own hint shows it
label(bg, "CHOOSE YOUR GUNS", RUBIK_H, 22, Color3.new(1, 1, 1), UDim2.fromOffset(26, 186))
local icon = Instance.new("ImageLabel")
icon.BackgroundTransparency = 1
icon.Image = "rbxassetid://94062620763078" -- the Locker's HUD icon (LobbyKit K.AREA.locker)
icon.ImageColor3 = TEAL
icon.AnchorPoint = Vector2.new(1, 0)
icon.Position = UDim2.new(1, -26, 0, 30)
icon.Size = UDim2.fromOffset(86, 86)
icon.Parent = bg

-- the light the bay glow casts
local glow = kit:FindFirstChild("Glow")
if glow then
	local l = Instance.new("PointLight")
	l.Color = TEAL
	l.Brightness = 1.1
	l.Range = 7
	l.Shadows = false
	l.Parent = glow
end
kit.Parent = SS.V5Kit

-- 2. swap the six terminals ----------------------------------------------------------------------------------------------
local loadouts = workspace.LobbyV5.Range.Loadouts
local swapped = 0
for _, m in loadouts:GetChildren() do
	if m:IsA("Model") and string.match(m.Name, "^Loadout%d+$") then
		local pivot = m:GetPivot()
		-- the old kit's pivot sits on the floor at its centre facing -Z; keep its yaw, drop any tilt
		local look = pivot.LookVector * V(1, 0, 1)
		local at = V(pivot.X, workspace.LobbyV5.Range.Shell.Floor.Position.Y + 1, pivot.Z)
		local new = kit:Clone()
		new.Name = m.Name
		new:PivotTo(CFrame.lookAt(at, at + look.Unit))
		CS:AddTag(new.Body, "RangeLoadout")
		for k, v in m:GetAttributes() do
			new:SetAttribute(k, v)
		end
		m:Destroy()
		new.Parent = loadouts
		swapped += 1
	end
end
return ("terminal v3 in %d spots"):format(swapped)

--[[ 3. (2026-11-26, owner: "a couple more around the map, and they also are a bit too large ... too tall") Run after
the above, once:

local CS = game:GetService("CollectionService")
local SCALE = 0.75 -- 7.2 -> 5.4 studs tall, just under a player
local function shrink(m)
	if (m:GetAttribute("Scaled") or 1) == SCALE then
		return
	end
	m:ScaleTo(SCALE)
	m:SetAttribute("Scaled", SCALE)
	for _, d in m:GetDescendants() do
		if d:IsA("SurfaceGui") then
			d.PixelsPerStud = 150 / SCALE -- the same screen layout on the smaller face
		elseif d:IsA("PointLight") then
			d.Range, d.Brightness = 5.5, 0.9
		end
	end
end
shrink(SS.V5Kit.Terminal3)
for _, m in workspace.LobbyV5.Range.Loadouts:GetChildren() do
	if m:IsA("Model") then
		shrink(m)
	end
end
-- three more (range-local x, deck y, z; the way the screen faces): the gallery, the west terrace, the sniper perch
local RO = CFrame.new(0, 0, 2600)
for _, s in {
	{ "Loadout7", -30, 12, -118.4, Vector3.new(0, 0, 1) },
	{ "Loadout8", -128.4, 15, 10, Vector3.new(1, 0, 0) },
	{ "Loadout9", 54, 24, -118.4, Vector3.new(0, 0, 1) },
} do
	local m = SS.V5Kit.Terminal3:Clone()
	m.Name = s[1]
	local at = RO * Vector3.new(s[2], s[3], s[4])
	m:PivotTo(CFrame.lookAt(at, at + s[5]))
	CS:AddTag(m.Body, "RangeLoadout")
	m.Parent = workspace.LobbyV5.Range.Loadouts
end
]]
