--!strict
-- Builds ReplicatedStorage.Crates.GoodieBag from its uploaded mesh (tools/blender/crates/build_goodie_bag.py,
-- vault/02 Art/Goodie Bag.md). Run in the Lobby place's edit DataModel (Studio MCP execute_luau or the command
-- bar); re-run after a re-upload, then save the place. Util/BagOpening anchors and moves the whole model by its
-- pivot (no rig): an invisible Root at the floor centre is the PrimaryPart. Parts keep the FBX names
-- (Sack_Body, Top_Hardware, ...) so Config/Crates colours them by role suffix; "Top" parts fly off on the pop.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSET = 100430777047300 -- GoodieBag_v03.fbx

local loaded = InsertService:LoadAsset(ASSET)
local model = Instance.new("Model")
model.Name = "GoodieBag"
local parts: { BasePart } = {}
for _, d in loaded:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end
assert(#parts > 0, "no parts in asset " .. ASSET)
-- floor centre of everything
local minY, sum = math.huge, Vector3.zero
for _, p in parts do
	minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
	sum += p.Position
end
local centre = sum / #parts
local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(0.2, 0.2, 0.2)
root.Transparency = 1
root.Anchored = true
root.CanCollide = false
root.CanQuery = false
root.CanTouch = false
root.CFrame = CFrame.new(centre.X, minY, centre.Z)
root.Parent = model
for _, p in parts do
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
end
loaded:Destroy()
model.PrimaryPart = root
model:PivotTo(CFrame.new())
model:SetAttribute("Tier", 10)
model:SetAttribute("Source", "tools/studio/BuildGoodieBag.luau, asset " .. ASSET)

local folder = ReplicatedStorage:FindFirstChild("Crates")
assert(folder, "ReplicatedStorage.Crates missing")
local old = folder:FindFirstChild("GoodieBag")
if old then
	old:Destroy()
end
model.Parent = folder
local names = {}
for _, p in parts do
	table.insert(names, p.Name)
end
return `built Crates.GoodieBag: {#parts} parts ({table.concat(names, ", ")})`
