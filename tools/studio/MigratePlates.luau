--!strict
-- Lobby place, Edit mode: replace every cap-built slanted plate (a body with
-- CapL / CapR slant images) with ONE sliced image, PlateArt.Skin, using
-- Config/UiPlates.slant (vault/02 Art/UI Polish Pass.md → 3). Same geometry
-- as lobby Util/Plates.build (which also converts any cap plate still built
-- by code at run time). Scope: StarterGui and ReplicatedStorage.UiTemplates.
-- Copies the touched guis to ServerStorage.PlateMigrationBackup first.
-- Run once (it skips plates that already have PlateArt). Save the place after.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local UiPlates = require(ReplicatedStorage.Shared.Config.UiPlates)
local ART = UiPlates.slant
local REACH = 0.87

local roots: { Instance } = { StarterGui }
local templates = ReplicatedStorage:FindFirstChild("UiTemplates")
if templates then
	table.insert(roots, templates)
end

-- backup
local backup = ServerStorage:FindFirstChild("PlateMigrationBackup")
if not backup then
	local b = Instance.new("Folder")
	b.Name = "PlateMigrationBackup"
	for _, root in roots do
		local copy = Instance.new("Folder")
		copy.Name = root.Name
		for _, c in root:GetChildren() do
			local ok, cl = pcall(function()
				return c:Clone()
			end)
			if ok and cl then
				cl.Parent = copy
			end
		end
		copy.Parent = b
	end
	b.Parent = ServerStorage
end

local done, skipped = 0, 0
for _, root in roots do
	for _, body in root:GetDescendants() do
		if not body:IsA("GuiObject") then
			continue
		end
		local capL = body:FindFirstChild("CapL")
		local capR = body:FindFirstChild("CapR")
		if not (capL and capL:IsA("ImageLabel") and capR and capR:IsA("ImageLabel")) then
			continue
		end
		if body:FindFirstChild("PlateArt") then
			skipped += 1
			continue
		end
		local base = capL.ZIndex
		local ext = math.max(2, math.floor(capL.Size.X.Offset * REACH + 0.5))
		capL:Destroy()
		capR:Destroy()
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") then
				c.ZIndex = math.max(c.ZIndex, base + 2)
			end
		end
		for _, g in body:GetChildren() do
			if g:IsA("UIGradient") then
				g:Destroy()
			end
		end
		local hide = Instance.new("UIGradient")
		hide.Name = "HideFill"
		hide.Transparency = NumberSequence.new(1)
		hide.Parent = body
		local back = Instance.new("Frame")
		back.Name = "PlateArt"
		back.BackgroundTransparency = 1
		back.Size = UDim2.fromScale(1, 1)
		back.ZIndex = base
		back.Parent = body
		local skin = Instance.new("ImageLabel")
		skin.Name = "Skin"
		skin.BackgroundTransparency = 1
		skin.Image = ART.image
		skin.ScaleType = Enum.ScaleType.Slice
		skin.SliceCenter = ART.slice
		skin.SliceScale = ext / ART.ends
		skin.Position = UDim2.fromOffset(-ext, 0)
		skin.Size = UDim2.new(1, ext * 2, 1, 0)
		skin.ZIndex = base
		-- the edit-time look: tinted like the run-time paint (colour lifted 0.1)
		local c = (body :: GuiObject).BackgroundColor3
		skin.ImageColor3 = c:Lerp(Color3.new(1, 1, 1), 0.1)
		skin.ImageTransparency = (body :: GuiObject).BackgroundTransparency
		skin.Parent = back
		done += 1
	end
end
return string.format("plates migrated %d, already done %d", done, skipped)
