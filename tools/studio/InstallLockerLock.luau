--!strict
-- Installs the Locker's locked-gun chains (tools/blender/build_locker_lock.py -> asset below) as
-- ReplicatedStorage.LockerV3Stage.LockChains. Run in Studio Edit (MCP execute_luau or the command bar), then save
-- the place. Controllers/LockerV3Controller clones it in front of a locked gun and scales it to the gun.
-- The pivot faces the front (the keyhole side), up through the shackle, so the controller can lookAt the camera.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSET = 117306657900034 -- "GG Locker Lock Chains v2" (group 11116787; 14 links a strand)
local GOLD = Color3.fromHex("D49A2A") -- (F2B530 bloomed into flat yellow; Metal shows the facets)
local DARK = Color3.fromHex("2A1D0C")

local stage = ReplicatedStorage:FindFirstChild("LockerV3Stage")
assert(stage, "ReplicatedStorage.LockerV3Stage missing")
local old = stage:FindFirstChild("LockChains")
if old then
	old:Destroy()
end

local loaded = InsertService:LoadAsset(ASSET)
local model = Instance.new("Model")
model.Name = "LockChains"
for _, d in loaded:GetDescendants() do
	if d:IsA("MeshPart") then
		d.Parent = model
	end
end
loaded:Destroy()

local parts: { [string]: MeshPart } = {}
for _, p in model:GetChildren() do
	if p:IsA("MeshPart") then
		parts[p.Name] = p
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = if p.Name == "Keyhole"
			then Enum.Material.SmoothPlastic
			else Enum.Material.Metal
		p.Reflectance = 0
		p.Color = if p.Name == "Keyhole" then DARK else GOLD
	end
end
local padlock = assert(parts.Padlock, "no Padlock mesh")
local keyhole = assert(parts.Keyhole, "no Keyhole mesh")
local shackle = assert(parts.Shackle, "no Shackle mesh")

-- the pivot: at the padlock, looking out of its front (toward the keyhole), up through the shackle
local centre = padlock.Position
local up = (shackle.Position - centre).Unit
local toKey = keyhole.Position - centre
local front = (toKey - up * toKey:Dot(up)).Unit
local pivot = CFrame.lookAt(centre, centre + front, up)
model.PrimaryPart = padlock
padlock.PivotOffset = padlock.CFrame:ToObjectSpace(pivot)
-- its width and height along the pivot (GetExtentsSize follows the primary part's own axes, not the pivot)
local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
for _, p in parts do
	local h = p.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local local3 = pivot:PointToObjectSpace(
					p.CFrame:PointToWorldSpace(h * Vector3.new(sx, sy, sz))
				)
				lo = lo:Min(local3)
				hi = hi:Max(local3)
			end
		end
	end
end
model:SetAttribute("Width", hi.X - lo.X)
-- the padlock body's own width: the Locker sizes the lock by it, so the chains run off the screen
local plo, phi = math.huge, -math.huge
do
	local h = padlock.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x = pivot:PointToObjectSpace(
					padlock.CFrame:PointToWorldSpace(h * Vector3.new(sx, sy, sz))
				).X
				plo, phi = math.min(plo, x), math.max(phi, x)
			end
		end
	end
end
model:SetAttribute("PadlockWidth", phi - plo)
model:SetAttribute("Height", hi.Y - lo.Y)
model.Parent = stage

return string.format(
	"LockChains: %d parts, width %.2f, height %.2f, depth %.2f (pivot space)",
	#model:GetChildren(),
	hi.X - lo.X,
	hi.Y - lo.Y,
	hi.Z - lo.Z
)
