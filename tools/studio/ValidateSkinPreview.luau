--!strict
-- Run in gameplay Studio Edit after installing Prism. Disposable clones only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Preview = require(ReplicatedStorage.Shared.SkinPreview)
local Config = require(ReplicatedStorage.Shared.Config.SkinPreview)
assert(Preview.allowed(), "Gameplay Studio only")
local previous = workspace:GetAttribute(Config.ATTRIBUTE)
local clones = {}
local function appearance(model: Model): string
	local rows = {}
	for _, p in model:GetChildren() do
		if p:IsA("MeshPart") then
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			table.insert(
				rows,
				table.concat({
					p.Name,
					p.Color:ToHex(),
					p.Material.Name,
					p.MaterialVariant,
					tostring(p.Reflectance),
					p.TextureID,
					if sa
						then sa.ColorMap .. sa.NormalMap .. sa.RoughnessMap .. sa.MetalnessMap
						else "",
				}, "|")
			)
		end
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end
local function structure(model: Model): string
	local rows = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(
				rows,
				d.Name
					.. tostring(d.Size)
					.. tostring(d.CFrame)
					.. tostring(d.PivotOffset)
					.. tostring(d.Transparency)
					.. (if d:IsA("MeshPart") then d.MeshId else "")
			)
		elseif d:IsA("Motor6D") or d:IsA("Weld") then
			table.insert(
				rows,
				d.Name
					.. tostring(d.C0)
					.. tostring(d.C1)
					.. (if d.Part0 then d.Part0.Name else "")
					.. (if d.Part1 then d.Part1.Name else "")
			)
		elseif d:IsA("Attachment") then
			table.insert(rows, d.Name .. tostring(d.CFrame))
		end
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end
local ok, result = pcall(function()
	local report = {}
	for _, id in { "Vandal", "Classic" } do
		local model = ReplicatedStorage.Weapons[id]:Clone()
		table.insert(clones, model)
		local stock, shape = appearance(model), structure(model)
		for _, line in Config.LINES do
			workspace:SetAttribute(Config.ATTRIBUTE, line)
			Preview.apply(model)
			assert(structure(model) == shape, "structure changed: " .. line .. "/" .. id)
			local expected = if id == "Vandal" and line == "Prism" then "Prism" else "Stock"
			assert(model:GetAttribute("PreviewResolvedLine") == expected, "wrong fallback")
			assert((appearance(model) == stock) == (expected == "Stock"), "wrong appearance")
		end
		workspace:SetAttribute(Config.ATTRIBUTE, "Prism")
		Preview.apply(model)
		workspace:SetAttribute(Config.ATTRIBUTE, "Stock")
		Preview.apply(model)
		assert(appearance(model) == stock, "Stock did not restore exactly")
		table.insert(
			report,
			id .. ": five lines, fallback, exact Stock restoration, structure PASS"
		)
	end
	return report
end)
for _, model in clones do
	model:Destroy()
end
workspace:SetAttribute(Config.ATTRIBUTE, previous)
assert(ok, tostring(result))
return result
