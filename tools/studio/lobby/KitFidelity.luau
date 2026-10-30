--!strict
-- Lobby art polish (performance audit): every MeshPart in ServerStorage.LobbyKit and
-- Workspace.Lobby.Art gets CollisionFidelity Box, so no art mesh loads a convex-decomposition
-- hull. Art MeshParts are CanCollide/CanQuery/CanTouch false (the greybox and the few
-- invisible collider Parts are the collision), so Box costs nothing. Colliding MeshParts are
-- left alone.
-- Setting CollisionFidelity directly is ignored in this context; ApplyMesh from a part made by
-- AssetService:CreateMeshPartAsync(..., { CollisionFidelity = Box }) works and keeps Size,
-- CFrame, material and children. Run it last, after kit_bundle.py / gun_display_bundle.py and
-- the Art_*.luau scripts (stand-alone; not bundled). Re-runnable: parts already on Box are
-- skipped.
assert(game.PlaceId == 133387545285290, "not the Lobby")

local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local ROOTS: { Instance? } = {
	ServerStorage:FindFirstChild("LobbyKit"),
	workspace:FindFirstChild("Lobby") and (workspace :: any).Lobby:FindFirstChild("Art"),
}

local byMesh: { [string]: { MeshPart } } = {}
local total = 0
for _, root in ROOTS do
	if not root then
		continue
	end
	for _, d in root:GetDescendants() do
		if
			d:IsA("MeshPart")
			and d.CollisionFidelity ~= Enum.CollisionFidelity.Box
			and not d.CanCollide
		then
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
	"Lobby kit fidelity: %d parts (%d meshes) -> Box %d, failed %d",
	total,
	meshes,
	done,
	failed
)
print(line)
return line
