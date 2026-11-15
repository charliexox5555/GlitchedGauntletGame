--!strict
-- Install the original Bat mesh package in the Studio-only melee skin slot.
local function install(data: any, assetId: number, maps: any): Model
	local run = game:GetService("RunService")
	assert(
		run:IsStudio() and not run:IsRunning() and game.PlaceId == 133387545285290,
		"Gameplay Studio Edit only"
	)
	local rs = game:GetService("ReplicatedStorage")
	local line = rs:WaitForChild("WeaponSkins"):WaitForChild("PopCircuit")
	local old = line:FindFirstChild("Bat")
	if old then
		assert(old:IsA("Model") and old:GetAttribute("SkinReady") == true, "Existing Bat needs review")
		return old
	end
	local raw = game:GetService("InsertService"):LoadAsset(assetId)
	local pieces: { [string]: MeshPart } = {}
	for _, part in raw:GetDescendants() do
		if part:IsA("MeshPart") then
			pieces[part.Name] = part
		end
	end
	local function position(v: { number }): Vector3
		return Vector3.new(-v[2], v[3], -v[1])
	end
	local function rigid(part: BasePart)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.Anchored = false
	end
	local model = Instance.new("Model")
	model.Name = "Bat"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.one * 0.2
	handle.Transparency = 1
	rigid(handle)
	handle.Parent = model
	model.PrimaryPart = handle
	local rig = Instance.new("Folder")
	rig.Name = "Rig"
	rig.Parent = model
	local motors = Instance.new("Folder")
	motors.Name = "Motors"
	motors.Parent = rig
	local root = handle:Clone()
	root.Name = "Root"
	root.Parent = rig
	local rootMotor = Instance.new("Motor6D")
	rootMotor.Name = "Root"
	rootMotor.Part0 = handle
	rootMotor.Part1 = root
	rootMotor.Parent = motors

	-- The cloud importer placed FBX +X along mesh-local -X, +Y along +Z
	-- and +Z along +Y. Use the same mesh rotation as the stock importer.
	local axes = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, -Vector3.xAxis, -Vector3.yAxis)
	for _, p in data.parts do
		local part = assert(pieces[p.name], "Missing Bat mesh " .. p.name):Clone()
		part:ClearAllChildren()
		part.CFrame = CFrame.new(position(p.center)) * axes
		rigid(part)
		part.TextureID = ""
		if p.material == "Neon" then
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromHex("61F2FF")
		else
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new(1, 1, 1)
			local surface = Instance.new("SurfaceAppearance")
			surface.Name = "PopCircuit_v01"
			surface.ColorMap = "rbxassetid://" .. maps.Color
			surface.NormalMap = "rbxassetid://" .. maps.Normal
			surface.RoughnessMap = "rbxassetid://" .. maps.Roughness
			surface.MetalnessMap = "rbxassetid://" .. maps.Metalness
			surface.Parent = part
		end
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = root.CFrame:ToObjectSpace(part.CFrame)
		weld.Parent = part
		part.Parent = model
	end
	local anchors: { [string]: Attachment } = {}
	for _, locator in data.locators do
		local a = Instance.new("Attachment")
		a.Name = locator.name
		local m = locator.matrix
		a.Position = position({ m[1][4], m[2][4], m[3][4] })
		a.Parent = if locator.name == "RightGrip" then handle else root
		anchors[a.Name] = a
	end
	for name, shift in { Blue = -0.045, Pink = 0, Violet = 0.045 } do
		local a, b = anchors.TrailInner:Clone(), anchors.TrailOuter:Clone()
		a.Name = "TrailBase" .. name
		b.Name = "TrailTip" .. name
		a.Position += Vector3.new(shift, 0, 0)
		b.Position += Vector3.new(shift, 0, 0)
		a.Position = a.Position:Lerp(b.Position, 0.60)
		b.Position = b.Position:Lerp(a.Position, 0.42)
		a.Parent = root
		b.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "PopCircuit" .. name
		trail.Attachment0 = a
		trail.Attachment1 = b
		trail.Color = ColorSequence.new(
			Color3.fromHex(({ Blue = "539BFF", Pink = "FF9DD8", Violet = "6554C9" })[name])
		)
		trail.Transparency = NumberSequence.new(0.14, 1)
		trail.WidthScale = NumberSequence.new(1, 0.12)
		trail.Lifetime = 0.12
		trail.MinLength = 0.02
		trail.LightEmission = 0.35
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = model
	end
	raw:Destroy()
	model:SetAttribute("WeaponId", "Knife")
	model:SetAttribute("PreviewMeleeModel", "Bat")
	model:SetAttribute("SkinLine", "PopCircuit")
	model:SetAttribute("SkinVersion", "v01")
	model:SetAttribute("SkinReady", true)
	model.Parent = line
	game:GetService("ChangeHistoryService"):SetWaypoint("Install PopCircuit Bat")
	return model
end

return install
