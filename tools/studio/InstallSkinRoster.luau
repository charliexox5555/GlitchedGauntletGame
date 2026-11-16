--!strict
-- Rows come from the upload journal and Blender manifests. Optional mesh
-- patches carry corrected atlas islands and local repairs from Blender.
local function install(rows: { any }, patches: { [string]: any }?): { any }
	local RunService = game:GetService("RunService")
	assert(
		RunService:IsStudio()
			and not RunService:IsRunning()
			and game.GameId == 10772880160
			and (game.PlaceId == 133387545285290 or game.PlaceId == 71551303511506),
		"Gauntlet match or lobby Studio Edit only"
	)

	local rs = game:GetService("ReplicatedStorage")
	local stocks = assert(rs:FindFirstChild("Weapons"), "Stock weapon folder is missing")
	local assetService = game:GetService("AssetService")
	local skins = rs:FindFirstChild("WeaponSkins")
	assert(not skins or skins:IsA("Folder"), "WeaponSkins must be a Folder")
	local staged = {}
	local results = {}
	local meshes: { [string]: MeshPart } = {}
	local geometryUpdates: { [Model]: string } = {}

	local function size(v: { number }): Vector3
		return Vector3.new(v[1], v[2], v[3])
	end

	local function applyPatch(part: MeshPart, patch: any, handle: BasePart)
		assert(part.MeshId == patch.original, "Stock mesh changed: " .. part.Name)
		local weld = part:FindFirstChildOfClass("Weld")
		assert(weld and weld.Part0 and weld.Part1 == part, "Stock weld is missing: " .. part.Name)
		local originalPivot = part:GetPivot()
		local originalSize, originalCF = part.Size, part.CFrame
		local dimensions, previous = size(patch.new.size), size(patch.old.size)
		local offset = size(patch.new.center) - size(patch.old.center)
		local worldOffset = handle.CFrame:VectorToWorldSpace(Vector3.new(-offset.Y, offset.Z, -offset.X))
		local x, y, z = table.unpack(patch.axes)
		local axes = CFrame.fromMatrix(
			Vector3.zero, Vector3.new(x, 0, 0), Vector3.new(0, 0, z), Vector3.new(0, y, 0)
		)
		local cf = originalCF * axes + worldOffset
		local fittedSize = originalSize * (dimensions / previous)
		local key = patch.mesh .. "/" .. part.CollisionFidelity.Name .. "/" .. part.RenderFidelity.Name
		local mesh = meshes[key]
		if not mesh then
			mesh = assetService:CreateMeshPartAsync(Content.fromUri(patch.mesh), {
				CollisionFidelity = part.CollisionFidelity,
				RenderFidelity = part.RenderFidelity,
			})
			assert((mesh.MeshSize - size(patch.size)).Magnitude < 0.001, "Imported mesh size changed")
			meshes[key] = mesh
		end

		local canCollide, canTouch, canQuery = part.CanCollide, part.CanTouch, part.CanQuery
		local oldTexture = part.TextureID
		local attachments = {}
		for _, child in part:GetChildren() do
			if child:IsA("Attachment") then
				attachments[child] = originalCF * child.CFrame
			end
		end

		part:ApplyMesh(mesh)
		part.Size = Vector3.new(fittedSize.X, fittedSize.Z, fittedSize.Y)
		part.CFrame = cf
		part.PivotOffset = cf:ToObjectSpace(originalPivot)
		part.TextureID = oldTexture
		part.CanCollide = canCollide
		part.CanTouch = canTouch
		part.CanQuery = canQuery
		weld.C0 = weld.Part0.CFrame:ToObjectSpace(cf) * weld.C1
		for attachment, world in attachments do
			attachment.CFrame = cf:ToObjectSpace(world)
		end
		part:SetAttribute("SkinMeshPatch", true)
	end

	local ok, err = pcall(function()
		for _, row in rows do
			local gunPatch = patches and patches[row.item]
			local geometry = if gunPatch and next(gunPatch.parts)
				then row.line .. "_" .. row.item .. "_" .. row.version
				else nil
			local line = skins and skins:FindFirstChild(row.line)
			assert(not line or line:IsA("Folder"), row.line .. " must be a Folder")
			local existing = line and line:FindFirstChild(row.item)
			if existing then
				assert(
					existing:IsA("Model")
						and existing:GetAttribute("SkinVersion") == row.version
						and existing:GetAttribute("SkinReady") == true,
					"Existing skin needs review " .. existing:GetFullName()
				)
				if geometry and existing:GetAttribute("PreviewGeometry") ~= geometry then
					for name, patch in gunPatch.parts do
						local part = existing:FindFirstChild(name)
						assert(
							part and part:IsA("MeshPart") and part.MeshId == patch.mesh,
							"Existing skin is missing the mesh patch for " .. name
						)
					end
					geometryUpdates[existing] = geometry
				end
				table.insert(results, { item = row.item, line = row.line, reused = true })
				continue
			end
			local stock = stocks:FindFirstChild(row.item)
			assert(stock and stock:IsA("Model") and stock.PrimaryPart, "No stock rig for " .. row.item)
			local clone = stock:Clone()
			table.insert(staged, { line = row.line, model = clone })
			local applied, neon, patched = 0, 0, 0
			for _, part in clone:GetChildren() do
				if not part:IsA("MeshPart") then
					continue
				end
				local patch = gunPatch and gunPatch.parts[part.Name]
				if patch then
					applyPatch(part, patch, clone.PrimaryPart :: BasePart)
					patched += 1
				end
				local suffix = string.match(part.Name, "_(%w+)$")
				local stem = string.match(part.Name, "^(.-)_%w+$") or part.Name
				if row.protected[stem] or row.protected[part.Name] or suffix == "Brass" or suffix == "Glass" then
					continue
				end
				if part.Material == Enum.Material.Neon then
					part.Color = Color3.fromHex(row.neon)
					neon += 1
					continue
				end
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				local surface = Instance.new("SurfaceAppearance")
				surface.Name = row.line .. "_" .. row.version
				surface.ColorMap = "rbxassetid://" .. row.maps.Color
				surface.NormalMap = "rbxassetid://" .. row.maps.Normal
				surface.RoughnessMap = "rbxassetid://" .. row.maps.Roughness
				surface.MetalnessMap = "rbxassetid://" .. row.maps.Metalness
				part.TextureID = ""
				part.Color = Color3.new(1, 1, 1)
				part.Reflectance = 0
				surface.Parent = part
				applied += 1
			end
			assert(applied > 0, "No mapped parts for " .. row.item)
			local expectedPatches = 0
			for _ in (gunPatch and gunPatch.parts or {}) do
				expectedPatches += 1
			end
			assert(patched == expectedPatches, "Missing patched mesh on " .. row.item)
			clone:SetAttribute("SkinLine", row.line)
			clone:SetAttribute("SkinVersion", row.version)
			clone:SetAttribute("SkinReady", true)
			clone:SetAttribute("PreviewGeometry", geometry)
			table.insert(results, { item = row.item, line = row.line, pbr = applied, neon = neon, patched = patched })
		end
	end)
	for _, mesh in meshes do
		mesh:Destroy()
	end
	if not ok then
		for _, item in staged do
			item.model:Destroy()
		end
		error(tostring(err))
	end

	for model, geometry in geometryUpdates do
		model:SetAttribute("PreviewGeometry", geometry)
	end
	if #staged > 0 then
		if not skins then
			skins = Instance.new("Folder")
			skins.Name = "WeaponSkins"
			skins.Parent = rs
		end
		for _, item in staged do
			local line = skins:FindFirstChild(item.line)
			if not line then
				line = Instance.new("Folder")
				line.Name = item.line
				line.Parent = skins
			end
			item.model.Parent = line
		end
	end
	if #staged > 0 or next(geometryUpdates) then
		game:GetService("ChangeHistoryService"):SetWaypoint("Install skin preview templates")
	end
	return results
end

return install
