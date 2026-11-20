--!strict
-- Install the private flat FBX round using the same axes as InstallFlatSkin.
type PartSpec = {
	center: { number },
	size: { number },
	color: string,
	material: string,
	glow: boolean,
}
type RoundSpec = { assetId: number, version: string, parts: { [string]: PartSpec } }

return function(spec: RoundSpec): Model
	local run = game:GetService("RunService")
	assert(run:IsStudio() and not run:IsRunning() and game.PlaceId == 133387545285290)
	local skins = game:GetService("ReplicatedStorage"):WaitForChild("WeaponSkins")
	local asset = game:GetService("InsertService"):LoadAsset(spec.assetId)
	local model = Instance.new("Model")
	model.Name = "ShadowMistRound"
	local rotation = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
	for name, finish in spec.parts do
		local source = asset:FindFirstChild(name, true)
		assert(source and source:IsA("MeshPart"), "Missing round mesh " .. name)
		local part = source:Clone()
		local s, c = finish.size, finish.center
		local size = Vector3.new(s[1], s[3], s[2])
		assert((source.Size / 100 - size).Magnitude < 0.01, "Round import scale mismatch")
		part.Size = size
		part.CFrame = CFrame.new(-c[2], c[3], -c[1]) * rotation
		part.TextureID = ""
		part.Color = Color3.fromHex(finish.color)
		part.Material = if finish.glow
			then Enum.Material.Neon
			else (Enum.Material :: any)[finish.material]
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("SkinSourceAsset", spec.assetId)
	model:SetAttribute("SkinVersion", spec.version)
	asset:Destroy()
	local previous = skins:FindFirstChild(model.Name)
	if previous then
		previous:Destroy()
	end
	model.Parent = skins
	game:GetService("ChangeHistoryService")
		:SetWaypoint("Install Shadow Mist round " .. spec.version)
	return model
end
