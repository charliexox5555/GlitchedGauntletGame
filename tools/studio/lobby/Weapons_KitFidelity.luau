--!strict
-- Weapons wing fix pass (performance audit): every kit MeshPart under ServerStorage.LobbyKit
-- with KitGroup "Weapons" or "GunDisplay" gets CollisionFidelity Box, so its clones in
-- Workspace.Lobby.Art.Weapons do not each load a convex-decomposition hull. All art parts are
-- CanCollide/CanQuery/CanTouch false (the greybox is the collision), so Box costs nothing.
-- Setting CollisionFidelity directly is ignored in this context; ApplyMesh from a part made by
-- AssetService:CreateMeshPartAsync(..., { CollisionFidelity = Box }) works and keeps Size,
-- CFrame, material and children. Run it after kit_bundle.py / gun_display_bundle.py and before
-- Art_Weapons (stand-alone; not bundled). Re-runnable: parts already on Box are skipped.
assert(game.PlaceId == 133387545285290, "not the Lobby")

local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local GROUPS = { Weapons = true, GunDisplay = true }

local lib = ServerStorage:FindFirstChild("LobbyKit")
assert(lib, "no ServerStorage.LobbyKit")

local byMesh: { [string]: { MeshPart } } = {}
local total = 0
for _, m in lib:GetChildren() do
	local g = m:GetAttribute("KitGroup")
	if typeof(g) == "string" and GROUPS[g] then
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") and d.CollisionFidelity ~= Enum.CollisionFidelity.Box then
				local list = byMesh[d.MeshId]
				if not list then
					list = {}
					byMesh[d.MeshId] = list
				end
				table.insert(list, d)
				total += 1
			end
		end
	end
end

local done, failed, meshes = 0, 0, 0
for meshId, parts in byMesh do
	meshes += 1
	local ok, template = pcall(function()
		return AssetService:CreateMeshPartAsync(
			Content.fromUri(meshId),
			{ CollisionFidelity = Enum.CollisionFidelity.Box }
		)
	end)
	if ok and template then
		for _, p in parts do
			if pcall(function()
				p:ApplyMesh(template)
			end) then
				done += 1
			else
				failed += 1
			end
		end
		template:Destroy()
	else
		failed += #parts
	end
	if meshes % 20 == 0 then
		task.wait()
	end
end

local line = string.format(
	"Weapons kit fidelity: %d parts (%d meshes) -> Box %d, failed %d",
	total,
	meshes,
	done,
	failed
)
print(line)
return line
