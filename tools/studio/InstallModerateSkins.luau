--!strict
-- Studio-only installer for the moderate runtime mesh packages and the shared
-- Bulldog/Stinger corrections. The stock rig supplies every gameplay joint.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")

assert(
	RunService:IsStudio()
		and not RunService:IsRunning()
		and game.GameId == 10772880160
		and (game.PlaceId == 133387545285290 or game.PlaceId == 71551303511506),
	"Glitched Gauntlet match or lobby Studio Edit only"
)

local stocks = ReplicatedStorage:WaitForChild("Weapons")
local skins = ReplicatedStorage:WaitForChild("WeaponSkins")
local rotation = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
local imageCache: { [number]: string } = {}
local replacementCache: { [string]: MeshPart } = {}
local Installer = {}

local function vector(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function stockAxes(v: { number }): Vector3
	return Vector3.new(-v[2], v[3], -v[1])
end

local function image(id: number): string
	if imageCache[id] then
		return imageCache[id]
	end
	local asset = InsertService:LoadAsset(id)
	local decal = asset:FindFirstChildWhichIsA("Decal", true)
	local texture = if decal then decal.Texture else ""
	asset:Destroy()
	assert(texture ~= "", "Image asset did not resolve: " .. id)
	imageCache[id] = texture
	return texture
end

local function packageParts(id: number): (Instance, { [string]: MeshPart })
	local package = InsertService:LoadAsset(id)
	local parts = {}
	for _, p in package:GetDescendants() do
		if p:IsA("MeshPart") then
			assert(not parts[p.Name], "Duplicate package mesh " .. p.Name)
			parts[p.Name] = p
		end
	end
	return package, parts
end

local function attach(model: Model, source: MeshPart, name: string, spec: any): MeshPart
	local handle = assert(model.PrimaryPart, "Missing model Handle")
	local rig = assert(model:FindFirstChild("Rig"), "Missing stock Rig")
	local joint = rig:FindFirstChild(spec.bone)
	assert(joint and joint:IsA("BasePart"), "Missing stock joint " .. spec.bone)
	local s = spec.size
	local wanted = Vector3.new(math.max(s[1], 0.001), math.max(s[3], 0.001), math.max(s[2], 0.001))
	assert((source.Size / 100 - wanted).Magnitude < 0.012, "Scale mismatch on " .. name)
	local part = source:Clone()
	part.Name = name
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") or child:IsA("Texture") or child:IsA("Decal") then
			child:Destroy()
		end
	end
	part.Size = wanted
	part.CFrame = handle.CFrame * CFrame.new(stockAxes(spec.center)) * rotation
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.CollisionFidelity = Enum.CollisionFidelity.Box
	part.TextureID = ""
	part.Transparency = 1 - (spec.opacity or 1)
	local weld = Instance.new("Weld")
	weld.Name = "SkinCosmeticWeld"
	weld.Part0 = joint
	weld.Part1 = part
	weld.C0 = joint.CFrame:ToObjectSpace(part.CFrame)
	weld.Parent = part
	if spec.motion and spec.pivot and spec.axis then
		part:SetAttribute("CosmeticInspect", spec.motion)
		if spec.travel then
			part:SetAttribute("CosmeticInspectTravel", spec.travel)
		end
		part:SetAttribute(
			"CosmeticInspectPivot",
			joint.CFrame:PointToObjectSpace(handle.CFrame:PointToWorldSpace(stockAxes(spec.pivot)))
		)
		part:SetAttribute(
			"CosmeticInspectAxis",
			joint.CFrame:VectorToObjectSpace(handle.CFrame:VectorToWorldSpace(stockAxes(spec.axis)))
		)
	end
	part.Parent = model
	return part
end

local function verifyLocators(stock: Model, variant: Model)
	local a = assert(stock.PrimaryPart, "Missing stock Handle")
	local b = assert(variant.PrimaryPart, "Missing variant Handle")
	for _, original in stock:GetDescendants() do
		if original:IsA("Attachment") then
			local target = variant:FindFirstChild(original.Name, true)
			assert(target and target:IsA("Attachment"), original.Name .. " went missing")
			assert(
				a.CFrame
					:ToObjectSpace(original.WorldCFrame)
					:FuzzyEq(b.CFrame:ToObjectSpace(target.WorldCFrame), 1e-4),
				original.Name .. " moved"
			)
		end
	end
end

local function finishPart(part: MeshPart, spec: any, maps: any?, tiles: any?)
	if spec.kind == "pbr" then
		assert(maps, "PBR atlas missing")
		part.Color = Color3.new(1, 1, 1)
		part.Material = Enum.Material.SmoothPlastic
		local surface = Instance.new("SurfaceAppearance")
		surface.ColorMap = maps.Color
		surface.MetalnessMap = maps.Metalness
		surface.RoughnessMap = maps.Roughness
		surface.NormalMap = maps.Normal
		surface.Parent = part
	else
		assert(spec.color, "Flat finish missing")
		part.Color = Color3.fromHex(spec.color)
		part.Material = (Enum.Material :: any)[spec.material]
		part.Reflectance = spec.reflectance or 0
		if spec.pattern and tiles then
			local tile = assert(tiles[spec.pattern], "Missing pattern tile " .. spec.pattern)
			for _, face in Enum.NormalId:GetEnumItems() do
				local t = Instance.new("Texture")
				t.Name = "Pattern"
				t.Texture = image(tile.id)
				t.Face = face
				t.StudsPerTileU = tile.studs
				t.StudsPerTileV = tile.studs
				t.Parent = part
			end
		end
	end
end

function Installer.install(job: any): any
	local stock = stocks:FindFirstChild(job.gun)
	assert(stock and stock:IsA("Model") and stock.PrimaryPart, "Missing stock rig " .. job.gun)
	local package, imported = packageParts(job.assetId)
	local variant = stock:Clone()
	local passed, result = pcall(function()
		local maps = nil
		if job.maps then
			maps = {}
			for name, id in job.maps do
				maps[name] = image(id)
			end
		end
		local replaced = {}
		for _, name in job.replaced do
			replaced[name] = true
		end
		for _, obj in variant:GetChildren() do
			if obj:IsA("MeshPart") then
				local prefix = obj.Name:match("^[^_]+")
				if replaced[obj.Name] or (prefix and replaced[prefix]) then
					obj:Destroy()
				end
			end
		end
		local total = 0
		for name, spec in job.parts do
			local p =
				attach(variant, assert(imported[name], "Missing package mesh " .. name), name, spec)
			finishPart(p, spec, maps, job.tiles)
			total += 1
		end
		verifyLocators(stock, variant)
		assert(total > 0, "No geometry installed")
		variant.Name = job.gun
		variant:SetAttribute("SkinLine", job.line)
		variant:SetAttribute("SkinVersion", job.version)
		variant:SetAttribute("SkinReady", true)
		variant:SetAttribute("PreviewGeometry", job.line .. "_" .. job.gun .. "_" .. job.version)
		if job.gun == "Knife" then
			variant:SetAttribute("SkinItem", "Knife")
		end
		local line = skins:FindFirstChild(job.line)
		if not line then
			line = Instance.new("Folder")
			line.Name = job.line
			line.Parent = skins
		end
		local old = line:FindFirstChild(job.gun)
		variant.Parent = line
		if old then
			old:Destroy()
		end
		return { line = job.line, gun = job.gun, parts = total, version = job.version }
	end)
	package:Destroy()
	if not passed then
		variant:Destroy()
		error(result)
	end
	return result
end

local function replaceOverlay(model: Model, part: MeshPart, patch: any)
	if part.MeshId == patch.mesh then
		return
	end
	assert(part.MeshId == patch.original, "Unexpected mesh on " .. part:GetFullName())
	local handle = assert(model.PrimaryPart, "Missing overlay Handle")
	local weld = part:FindFirstChildOfClass("Weld")
	assert(weld and weld.Part0 and weld.Part1 == part, "Original overlay weld missing")
	local originalPivot = part:GetPivot()
	local originalSize, originalCF = part.Size, part.CFrame
	local offset = vector(patch.new.center) - vector(patch.old.center)
	local x, y, z = table.unpack(patch.axes)
	local axes = CFrame.fromMatrix(
		Vector3.zero,
		Vector3.new(x, 0, 0),
		Vector3.new(0, 0, z),
		Vector3.new(0, y, 0)
	)
	local cf = originalCF * axes
		+ handle.CFrame:VectorToWorldSpace(Vector3.new(-offset.Y, offset.Z, -offset.X))
	local fitted = originalSize * (vector(patch.new.size) / vector(patch.old.size))
	local texture = part.TextureID
	local collide, touch, query = part.CanCollide, part.CanTouch, part.CanQuery
	local key = patch.mesh .. "/" .. part.CollisionFidelity.Name .. "/" .. part.RenderFidelity.Name
	local mesh = replacementCache[key]
	if not mesh then
		-- selene: allow(undefined_variable)
		mesh = AssetService:CreateMeshPartAsync(Content.fromUri(patch.mesh), {
			CollisionFidelity = part.CollisionFidelity,
			RenderFidelity = part.RenderFidelity,
		})
		assert(
			(mesh.MeshSize - vector(patch.size)).Magnitude < 0.001,
			"Overlay mesh dimensions changed"
		)
		replacementCache[key] = mesh
	end
	part:ApplyMesh(mesh)
	part.Size = Vector3.new(fitted.X, fitted.Z, fitted.Y)
	part.CFrame = cf
	part.TextureID = texture
	part.CanCollide, part.CanTouch, part.CanQuery = collide, touch, query
	part.PivotOffset = cf:ToObjectSpace(originalPivot)
	weld.C0 = weld.Part0.CFrame:ToObjectSpace(cf) * weld.C1
	part:SetAttribute("SkinMeshPatch", true)
end

function Installer.repair(job: any): any
	local package, imported = packageParts(job.seatId)
	local seatName, seatSpec = next(job.seat)
	local source = assert(imported[seatName], "Missing sight pedestal")
	local result = {}
	local function patchFolder(folder: Instance)
		for _, gun in { "Bulldog", "Stinger" } do
			local model = folder:FindFirstChild(gun)
			if not model or not model:IsA("Model") then
				continue
			end
			local notes = {}
			for name, patch in job.overlays[gun] do
				local p = model:FindFirstChild(name)
				if p and p:IsA("MeshPart") then
					if p.MeshId == patch.original then
						replaceOverlay(model, p, patch)
						table.insert(notes, name .. " replaced")
					elseif p.MeshId == patch.mesh then
						table.insert(notes, name .. " already fixed")
					else
						table.insert(notes, name .. " has separate geometry")
					end
				end
			end
			if gun == "Bulldog" and not model:FindFirstChild(seatName) then
				local p = attach(model, source, seatName, seatSpec)
				finishPart(p, seatSpec)
				local sight = model:FindFirstChild("Sights_Dark")
				if sight and sight:IsA("MeshPart") then
					p.Color = sight.Color
					p.Material = sight.Material
				end
				table.insert(notes, "front sight seated")
			end
			model:SetAttribute("GeometryRepair", "BulldogStinger-v01")
			table.insert(result, { target = model:GetFullName(), notes = notes })
		end
	end
	local ok, err = pcall(function()
		patchFolder(stocks)
		for _, line in skins:GetChildren() do
			patchFolder(line)
		end
	end)
	package:Destroy()
	if not ok then
		error(err)
	end
	return result
end

return Installer
