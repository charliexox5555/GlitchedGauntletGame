-- TpPreviewSheet.luau: lays out the poses written by
-- `python -I tools/anim/tp_clips.py sheet ...` (src/shared/TpPreview.luau, a
-- temporary Rojo-synced data module) in Studio, Edit mode: one copy of the
-- block match body per pose, in a row, each holding the real gun, so a clip
-- can be judged from any camera before it is exported and uploaded
-- (vault/01 Design/Third Person Overhaul.md §5). Run with the Studio MCP's
-- execute_luau on the Edit datamodel. (If the Rojo plugin isn't syncing, put
-- the rows in a StringValue instead and read that: the pose rows are plain
-- text, `label|gun|view|Part:x,y,z,r00..r22;...`.) It returns the row's centre and length
-- for placing the camera. Everything it makes lives in Workspace.TpPreview:
-- delete that folder when done (it must not be saved with the place).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ORIGIN = Vector3.new(0, 203, -600) -- an empty spot, clear of the maps
local SPACING = 5
local GRIP_GUN = CFrame.new(0, -0.15, -0.5) * CFrame.Angles(-math.pi / 2, 0, 0) -- Config/Animations GUN_WORLD_GRIP
local GRIP_KNIFE = CFrame.new(0, -0.15, -0.05)

-- Fresh copies of the two modules: Studio caches a required module, so a
-- changed Config/Avatar (new meshes) would otherwise not show.
local fresh = Instance.new("Folder")
local config = Instance.new("Folder")
config.Name = "Config"
config.Parent = fresh
ReplicatedStorage.Shared.Config.Avatar:Clone().Parent = config
ReplicatedStorage.Shared.MatchBody:Clone().Parent = fresh
local Avatar = require((config :: any).Avatar)
local MatchBody = require((fresh :: any).MatchBody)

local source = ReplicatedStorage.Shared.TpPreview.Source
local body = string.match(source, "%[==%[\n(.-)\n%]==%]")
assert(body, "no pose data in TpPreview")

local folder = workspace:FindFirstChild("TpPreview")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "TpPreview"
folder.Parent = workspace

-- A floor and a backdrop, so poses read against something plain.
local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Material = Enum.Material.SmoothPlastic
floor.Color = Color3.fromRGB(150, 153, 160)
floor.Parent = folder

local desc = MatchBody.description(nil)
-- The range dummy's colours (TestRange/Dummies): what the owner looks at.
local skin = Color3.fromHex("A3A5A8")
local cloth = Color3.fromHex("4A4D52")
desc.HeadColor = skin
desc.TorsoColor = cloth
desc.LeftArmColor = skin
desc.RightArmColor = skin
desc.LeftLegColor = cloth
desc.RightLegColor = cloth
local template = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
for _, d in template:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		d:Destroy()
	end
end
MatchBody.dress(template)
for _, d in template:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
local humanoid = template:FindFirstChildOfClass("Humanoid")
if humanoid then
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

local rows = string.split(body, "\n")
for index, row in rows do
	local fields = string.split(row, "|")
	-- label | gun | view (degrees the copy is turned: 0 front, 90 its right side) | parts
	local label, gunId = fields[1], fields[2]
	local base = CFrame.new(ORIGIN + Vector3.new((index - (#rows + 1) / 2) * SPACING, 3, 0))
		* CFrame.Angles(0, math.rad(tonumber(fields[3]) or 0), 0)
	local rig = template:Clone()
	rig.Name = label .. "_" .. fields[3]
	local hand: CFrame? = nil
	for _, entry in string.split(fields[4], ";") do
		local name, numbers = table.unpack(string.split(entry, ":"))
		local n = {}
		for i, v in string.split(numbers, ",") do
			n[i] = tonumber(v)
		end
		local world = base
			* CFrame.new(n[1], n[2], n[3], n[4], n[5], n[6], n[7], n[8], n[9], n[10], n[11], n[12])
		local part = rig:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.CFrame = world
			local spec = Avatar.BLOCKS[name]
			local made = part:FindFirstChild(Avatar.BLOCK_NAME)
			if spec and made and made:IsA("BasePart") then
				made.CFrame = world * CFrame.new(spec.offset)
			end
			if name == "RightHand" then
				hand = world
			end
		end
	end
	rig.Parent = folder
	local gunTemplate = ReplicatedStorage.Weapons:FindFirstChild(gunId)
	if gunTemplate and hand and gunId ~= "None" then
		local gun = gunTemplate:Clone()
		for _, d in gun:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local handle = gun.PrimaryPart
		local target = hand * (if gunId == "Knife" then GRIP_KNIFE else GRIP_GUN)
		gun:PivotTo(target * handle.CFrame:Inverse() * gun:GetPivot())
		gun.Parent = rig
	end
end
template:Destroy()

local length = #rows * SPACING
floor.Size = Vector3.new(length + 12, 1, 24)
floor.CFrame = CFrame.new(ORIGIN + Vector3.new(0, -0.5, 0))
return string.format("rows=%d centre=%s length=%d", #rows, tostring(ORIGIN), length)
