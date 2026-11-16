--!strict
-- Run in the Gauntlet Edit session with the v02 manifest and upload IDs.
local function install(assetId: number, parts: { [string]: any }, maps: { [string]: string }): Model
	local runService = game:GetService("RunService")
	assert(
		runService:IsStudio() and not runService:IsRunning() and game.PlaceId == 133387545285290,
		"Gauntlet gameplay Studio Edit only"
	)

	local rs = game:GetService("ReplicatedStorage")
	local stock = rs.Weapons.Vandal :: Model
	local handle = assert(stock.PrimaryPart)
	local skins = rs:FindFirstChild("WeaponSkins")
	local line = skins and skins:FindFirstChild("Moltframe")
	assert(
		not (line and line:FindFirstChild("Vandal")),
		"Version the installed Moltframe template first"
	)
	local insertService = game:GetService("InsertService")
	local package = insertService:LoadAsset(assetId)
	local imported: { [string]: MeshPart } = {}
	for _, obj in package:GetDescendants() do
		if obj:IsA("MeshPart") then
			imported[obj.Name] = obj
		end
	end

	local variant = stock:Clone()
	local variantHandle = assert(variant.PrimaryPart)
	local rig = variant:FindFirstChild("Rig")
	assert(rig, "Vandal rig missing")
	local replaced = {
		Receiver = true,
		Handguard = true,
		Stock = true,
		Pins = true,
		Neon = true,
		Rail = true,
		Mag = true,
		Grip = true,
		Barrel = true,
	}
	local ok, err = pcall(function()
		for _, obj in variant:GetChildren() do
			if obj:IsA("MeshPart") then
				local part = obj.Name:match("^[^_]+")
				if part and replaced[part] then
					obj:Destroy()
				end
			end
		end

		-- The FBX importer applies (-x,z,y) to the model. Rotate the result
		-- onto the stock handle axes to get (-y,z,-x).
		local rotation = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
		for name, spec in parts do
			local source = assert(imported[name], "Missing imported mesh " .. name)
			local part = source:Clone()
			local center = spec.center
			local dimensions = spec.size
			local expectedSize = Vector3.new(dimensions[1], dimensions[3], dimensions[2])
			assert((expectedSize - source.Size).Magnitude < 0.006, "Import scale mismatch " .. name)
			local joint = rig:FindFirstChild(spec.bone)
			assert(joint and joint:IsA("BasePart"), "Missing joint " .. spec.bone)
			part.CFrame = variantHandle.CFrame
				* CFrame.new(-center[2], center[3], -center[1])
				* rotation
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Massless = true
			part.CollisionFidelity = Enum.CollisionFidelity.Box
			part.Color = Color3.fromHex(spec.color)
			part.Material = if spec.metal then Enum.Material.Metal else Enum.Material.SmoothPlastic
			if spec.mapped then
				local appearance = Instance.new("SurfaceAppearance")
				appearance.Name = "Moltframe_v02"
				appearance.ColorMap = maps.ColorMap
				appearance.RoughnessMap = maps.RoughnessMap
				appearance.MetalnessMap = maps.MetalnessMap
				part.Color = Color3.new(1, 1, 1)
				appearance.Parent = part
			end
			part.Parent = variant
			local weld = Instance.new("Weld")
			weld.Name = "MoltframeCosmeticWeld"
			weld.Part0 = joint
			weld.Part1 = part
			weld.C0 = joint.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end

		for _, name in { "AimPoint", "RightGrip", "LeftGrip", "Muzzle", "Eject" } do
			local a = stock:FindFirstChild(name, true) :: Attachment?
			local b = variant:FindFirstChild(name, true) :: Attachment?
			assert(a and b, "Missing stock locator " .. name)
			assert(
				handle.CFrame
					:ToObjectSpace(a.WorldCFrame)
					:FuzzyEq(variantHandle.CFrame:ToObjectSpace(b.WorldCFrame), 0.0001),
				name .. " moved"
			)
		end
	end)
	package:Destroy()
	if not ok then
		variant:Destroy()
		error(err)
	end

	if not skins then
		skins = Instance.new("Folder")
		skins.Name = "WeaponSkins"
		skins.Parent = rs
	end
	if not line then
		line = Instance.new("Folder")
		line.Name = "Moltframe"
		line.Parent = skins
	end
	variant:SetAttribute("SkinLine", "Moltframe")
	variant:SetAttribute("SkinVersion", "v02")
	variant:SetAttribute("SkinReady", true)
	variant:SetAttribute("PreviewGeometry", "Moltframe_Vandal_v02")
	variant.Parent = line
	game:GetService("ChangeHistoryService"):SetWaypoint("Install Moltframe Vandal v02")
	return variant
end

return install
