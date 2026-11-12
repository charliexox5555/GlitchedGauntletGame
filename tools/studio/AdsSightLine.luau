--!strict
-- Dev tool, not shipped. Paste into the Command Bar (Edit mode), or run through the Studio MCP.
-- For every iron-sight gun in ReplicatedStorage.Weapons it repeats what
-- ViewmodelController.findOccluders does while aiming: five rays from the aiming
-- eye to the sight, against the gun's real colliders. Any part on that line whose
-- name has no "Sight" in it is hidden by the game while aiming, and because parts
-- are merged per material that leaves a hole in the gun (final pass 2026-11-11:
-- the Stinger's whole neon mesh vanished in ADS).
-- A clean gun prints an empty "would hide". Run it after rebuilding a gun or adding skin geometry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

local holder = Instance.new("Folder")
holder.Name = "_AdsSightLine"
holder.Parent = workspace

local lines = {}
for id, weapon in Weapons :: { [string]: any } do
	local template = (ReplicatedStorage :: any).Weapons:FindFirstChild(id)
	if typeof(weapon) ~= "table" or weapon.noAds or weapon.scope or not template then
		continue
	end
	local distance = weapon.adsDistance or VM.ADS_DISTANCE
	local offset = weapon.adsOffset or Vector3.zero
	local model = template:Clone()
	model:ScaleTo(weapon.viewmodelScale or VM.SCALE)
	model:PivotTo(CFrame.new(0, 500, 0))
	model.Parent = holder
	local handle = model.PrimaryPart :: BasePart
	local aim: Attachment? = nil
	local candidates: { Instance } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "AimPoint" then
			aim = d
		elseif d:IsA("BasePart") and d.Transparency < 1 then
			d.CanQuery = true
			table.insert(candidates, d)
		end
	end
	if not aim then
		table.insert(lines, id .. ": no AimPoint")
		continue
	end
	local aimRel = handle.CFrame:PointToObjectSpace(aim.WorldPosition)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local hide: { string } = {}
	local spread = 0.012
	for _, o in
		{
			Vector3.zero,
			Vector3.new(spread, 0, 0),
			Vector3.new(-spread, 0, 0),
			Vector3.new(0, spread, 0),
			Vector3.new(0, -spread, 0),
		}
	do
		local eye = handle.CFrame:PointToWorldSpace(aimRel - offset + o + Vector3.new(0, 0, distance))
		local dir = handle.CFrame.LookVector * (distance - 0.02)
		local remaining = table.clone(candidates)
		for _ = 1, 8 do
			params.FilterDescendantsInstances = remaining
			local result = workspace:Raycast(eye, dir, params)
			if not result then
				break
			end
			local name = result.Instance.Name
			if not string.find(name, "Sight") and not table.find(hide, name) then
				table.insert(hide, name)
			end
			local index = table.find(remaining, result.Instance)
			if not index then
				break
			end
			table.remove(remaining, index)
		end
	end
	table.insert(lines, string.format("%s: would hide [%s]", id, table.concat(hide, ", ")))
end
holder:Destroy()
table.sort(lines)
print("[AdsSightLine]\n" .. table.concat(lines, "\n"))
return table.concat(lines, "\n")
