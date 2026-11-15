--!strict
-- Called with rows generated from the upload journal and Blender manifests.
local function install(rows: { any }): { any }
	local RunService = game:GetService("RunService")
	assert(
		RunService:IsStudio() and not RunService:IsRunning() and game.PlaceId == 133387545285290,
		"Gameplay Studio Edit only"
	)
	local rs = game:GetService("ReplicatedStorage")
	local stocks = rs:WaitForChild("Weapons")
	local function folder(parent: Instance, name: string): Instance
		local old = parent:FindFirstChild(name)
		if old then
			assert(old:IsA("Folder"), old:GetFullName())
			return old
		end
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local skins = folder(rs, "WeaponSkins")
	local results = {}
	for _, row in rows do
		local line = folder(skins, row.line)
		local existing = line:FindFirstChild(row.item)
		if existing then
			assert(
				existing:GetAttribute("SkinVersion") == row.version
					and existing:GetAttribute("SkinReady") == true,
				"Existing skin needs review " .. existing:GetFullName()
			)
			table.insert(results, { item = row.item, reused = true })
			continue
		end
		local stock = stocks:FindFirstChild(row.item)
		assert(stock and stock:IsA("Model") and stock.PrimaryPart, "No stock rig for " .. row.item)
		local clone = stock:Clone()
		local applied, neon = 0, 0
		for _, part in clone:GetChildren() do
			if not part:IsA("MeshPart") then
				continue
			end
			local suffix = string.match(part.Name, "_(%w+)$")
			local stem = string.match(part.Name, "^(.-)_%w+$") or part.Name
			if part.Material == Enum.Material.Neon then
				part.Color = Color3.fromHex(row.neon)
				neon += 1
			elseif
				suffix ~= "Brass"
				and suffix ~= "Glass"
				and not row.protected[stem]
				and not row.protected[part.Name]
			then
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				local appearance = Instance.new("SurfaceAppearance")
				appearance.Name = row.line .. "_" .. row.version
				appearance.ColorMap = "rbxassetid://" .. row.maps.Color
				appearance.NormalMap = "rbxassetid://" .. row.maps.Normal
				appearance.RoughnessMap = "rbxassetid://" .. row.maps.Roughness
				appearance.MetalnessMap = "rbxassetid://" .. row.maps.Metalness
				part.TextureID = ""
				part.Color = Color3.new(1, 1, 1)
				part.Reflectance = 0
				appearance.Parent = part
				applied += 1
			end
		end
		assert(applied > 0, "No mapped parts for " .. row.item)
		clone:SetAttribute("SkinLine", row.line)
		clone:SetAttribute("SkinVersion", row.version)
		clone:SetAttribute("SkinReady", true)
		clone.Parent = line
		table.insert(results, { item = row.item, pbr = applied, neon = neon })
		if #results % 4 == 0 then
			task.wait()
		end
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Install skin preview templates")
	return results
end

return install
