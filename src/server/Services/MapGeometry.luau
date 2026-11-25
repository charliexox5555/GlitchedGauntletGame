--!strict
-- Gameplay collision corrections for the installed Studio map templates.
-- Applied to each match's own clone before it enters the world.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BallisticGlass = require(Shared.Util.BallisticGlass)
local MapGeometry = {}

local OPEN_STAIRS: { [string]: { [string]: boolean } } = {
	Dockyard = { ["Roof stair"] = true },
	Wharf = { ["Office stair"] = true },
	Snowpeak4 = { ["Lodge stair"] = true, ["Station stair"] = true },
	Rooftops4 = { StairRamp = true },
	Greenhouse4 = { StairCol = true },
	CanyonOutpost = { ["Stair ramp"] = true },
	Metro4 = { ["Bridge stair"] = true, ["Hall stair"] = true },
}

local ROOF_BLOCKERS: { [string]: { [string]: boolean } } = {
	Snowpeak4 = { ["Lodge roof blocker"] = true },
	Rooftops4 = {
		AccessHutRoofGuard = true,
		BulkheadGuard = true,
		BulkheadRoofGuard = true,
		LiftRoomRoofGuard = true,
		OverrunRoofGuard = true,
		PlantRoomRoofGuard = true,
		ShedRoofGuard = true,
		StairHutRoofGuard = true,
	},
	Greenhouse4 = {
		BoilerHouseRoofGuard = true,
		PottingHouseRoofGuard = true,
		ShedRoofGuard = true,
	},
	CanyonOutpost = { ["Porch roof"] = true, ["Trading post roof"] = true },
	OldTown4 = { ["Kiosk roof"] = true, ["Roof hut roof"] = true },
}

local function openStair(wedge: WedgePart)
	-- Roblox wedges rise toward local +Z. Keep the original top plane,
	-- using a shallow slab in place of the solid volume beneath the treads.
	local size = wedge.Size
	local thickness = 0.45
	local angle = math.atan2(size.Y, size.Z)
	local slope = wedge.CFrame * CFrame.Angles(-angle, 0, 0)
	local slab = Instance.new("Part")
	slab.Name = wedge.Name
	slab.Size = Vector3.new(size.X, thickness, Vector2.new(size.Y, size.Z).Magnitude)
	slab.CFrame = slope * CFrame.new(0, -thickness / 2, 0)
	slab.Anchored = true
	slab.Transparency = 1
	slab.CastShadow = false
	slab.CanTouch = false
	slab.Material = wedge.Material
	slab.CollisionGroup = wedge.CollisionGroup
	slab.Parent = wedge.Parent
	wedge:Destroy()
end

local function markPane(pane: BasePart)
	pane.CanCollide = true
	pane.CanQuery = true
	pane:AddTag(BallisticGlass.TAG)
end

local function splitBridgeGlass(pane: BasePart, posts: { BasePart })
	-- Cut the continuous ribbon at the existing mullions so a hit opens one bay.
	local half = pane.Size.Z / 2
	local edges = { -half, half }
	for _, post in posts do
		local localPosition = pane.CFrame:PointToObjectSpace(post.Position)
		if math.abs(localPosition.X) < 0.3 and math.abs(localPosition.Z) < half - 0.5 then
			table.insert(edges, localPosition.Z)
			post.CanCollide = true
			post.CanQuery = true
		end
	end
	table.sort(edges)
	for i = 1, #edges - 1 do
		local left, right = edges[i], edges[i + 1]
		local bay = pane:Clone()
		bay.Size = Vector3.new(pane.Size.X, pane.Size.Y, right - left)
		bay.CFrame = pane.CFrame * CFrame.new(0, 0, (left + right) / 2)
		markPane(bay)
		bay.Parent = pane.Parent
	end
	pane:Destroy()
end

function MapGeometry.prepare(map: Model, id: string)
	local stairs = OPEN_STAIRS[id]
	local blockers = ROOF_BLOCKERS[id]
	local bridgePanes: { BasePart } = {}
	local bridgePosts: { BasePart } = {}
	for _, part in map:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local parent = part.Parent
		if not parent then
			continue
		end
		local name = part.Name:gsub("'$", "")
		if part.Transparency == 1 and part.CanCollide then
			if stairs and stairs[name] and part:IsA("WedgePart") then
				openStair(part)
				continue
			elseif blockers and blockers[name] and parent.Name == "Collision" then
				part:Destroy()
				continue
			end
		elseif
			id == "CanyonOutpost" and name == "Porch roof" and parent.Name == "Trading post"
			or id == "Snowpeak4" and name == "Porch roof" and parent.Name == "Lodge"
			or id == "OldTown4"
				and name == "Roof"
				and (parent.Name == "Kiosk" or parent.Name == "Roof hut")
		then
			part.CanCollide = true
			part.CanQuery = true
		end
		local greenhousePane = id == "Greenhouse4"
			and name == "Glass"
			and part.Material == Enum.Material.Glass
			and part.CanCollide
		if greenhousePane or part:HasTag(BallisticGlass.TAG) then
			markPane(part)
		elseif id == "Metro4" and parent.Name == "Footbridge" then
			if name == "Side glass" then
				table.insert(bridgePanes, part)
			elseif name == "End glass" then
				markPane(part)
			elseif name == "Glazing post" then
				table.insert(bridgePosts, part)
			end
		end
	end
	for _, pane in bridgePanes do
		splitBridgeGlass(pane, bridgePosts)
	end
end

return MapGeometry
