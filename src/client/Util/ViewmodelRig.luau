--!strict
-- Poses a first-person gun model by hand, every frame. Every part is anchored;
-- `solve` works out where each one goes for a given handle CFrame (animated
-- joints from their Motor6D, C0 * Transform * C1⁻¹ with Transform written by
-- GunAnimator; everything else at its rest offset from the part it was welded
-- to), and `apply` moves them all with one BulkMoveTo. The viewmodel solves
-- the gun and the arms first and applies everything at the end of the same
-- render step, so nothing can lag or drift relative to anything else.

type Link = {
	part: BasePart,
	parent: BasePart,
	motor: Motor6D?, -- animated joint, else a fixed offset
	offset: CFrame, -- rest offset from `parent`
}

export type ViewmodelRig = {
	handle: BasePart,
	links: { Link }, -- parents always come before their children
	parts: { BasePart }, -- handle first, then `links` in order
	cframes: { CFrame }, -- solved CFrames, in `parts` order
	world: { [BasePart]: CFrame }, -- solved CFrame of every part
}

local ViewmodelRig = {}

type Edge = { other: BasePart, motor: Motor6D? }

local function addEdge(edges: { [BasePart]: { Edge } }, a: BasePart, b: BasePart, motor: Motor6D?)
	local list = edges[a]
	if not list then
		list = {}
		edges[a] = list
	end
	table.insert(list, { other = b, motor = motor })
end

-- Builds the pose list from the model's joints (at rest), then anchors every
-- part and switches the joints off. Call before the first `solve`.
function ViewmodelRig.new(model: Model, handle: BasePart): ViewmodelRig
	local edges: { [BasePart]: { Edge } } = {}
	local joints: { Instance } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 then
				-- Animated only from Part0 to Part1.
				addEdge(edges, p0, p1, d)
				addEdge(edges, p1, p0, nil)
			end
			table.insert(joints, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local p0, p1 = (d :: any).Part0 :: BasePart?, (d :: any).Part1 :: BasePart?
			if p0 and p1 then
				addEdge(edges, p0, p1, nil)
				addEdge(edges, p1, p0, nil)
			end
			table.insert(joints, d)
		end
	end

	local links: { Link } = {}
	local visited: { [BasePart]: boolean } = { [handle] = true }
	local queue: { BasePart } = { handle }
	local head = 1
	while head <= #queue do
		local q = queue[head]
		head += 1
		for _, e in edges[q] or {} do
			local p = e.other
			if not visited[p] then
				visited[p] = true
				local motor = e.motor
				table.insert(links, {
					part = p,
					parent = q,
					motor = if motor and motor.Part0 == q then motor else nil,
					offset = q.CFrame:ToObjectSpace(p.CFrame),
				})
				table.insert(queue, p)
			end
		end
	end
	-- Anything not joined to the rest rides the handle at its rest offset.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not visited[d] then
			visited[d] = true
			table.insert(links, {
				part = d,
				parent = handle,
				motor = nil,
				offset = handle.CFrame:ToObjectSpace(d.CFrame),
			})
		end
	end

	for _, j in joints do
		if j:IsA("Motor6D") then
			j.Enabled = false -- keeps its Transform for GunAnimator; we apply it
		else
			j:Destroy()
		end
	end
	local parts: { BasePart } = { handle }
	for _, link in links do
		table.insert(parts, link.part)
	end
	local world: { [BasePart]: CFrame } = {}
	for _, p in parts do
		p.Anchored = true
		world[p] = p.CFrame
	end
	return {
		handle = handle,
		links = links,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		world = world,
	}
end

-- Works out every part's CFrame with the handle at `handleCf` (into
-- `rig.world` and `rig.cframes`), without moving anything yet.
function ViewmodelRig.solve(rig: ViewmodelRig, handleCf: CFrame)
	local world = rig.world
	local cframes = rig.cframes
	world[rig.handle] = handleCf
	cframes[1] = handleCf
	for i, link in rig.links do
		local parentCf = world[link.parent] or handleCf
		local motor = link.motor
		local cf = if motor
			then parentCf * motor.C0 * motor.Transform * motor.C1:Inverse()
			else parentCf * link.offset
		world[link.part] = cf
		cframes[i + 1] = cf
	end
end

-- Moves every part to its solved CFrame. `root` is the WorldRoot the gun lives
-- in (the viewmodel keeps each gun in its own WorldModel, see
-- ViewmodelController).
function ViewmodelRig.apply(rig: ViewmodelRig, root: WorldRoot)
	root:BulkMoveTo(rig.parts, rig.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

return ViewmodelRig
