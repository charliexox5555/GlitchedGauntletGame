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
	rootMotor: Motor6D?, -- the clip's "Root" joint (the whole gun's kick)
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

local function isCharmAttachmentPart(p: BasePart): boolean
	return p.Name == "Charm" or string.sub(p.Name, 1, 9) == "CharmLoop"
end

-- Builds the pose list from the model's joints (at rest), then anchors every
-- part and switches the joints off. Call before the first `solve`.
function ViewmodelRig.new(model: Model, handle: BasePart): ViewmodelRig
	local rigFolder = model:FindFirstChild("Rig")
	local motorsFolder = rigFolder and rigFolder:FindFirstChild("Motors")
	local root = motorsFolder and motorsFolder:FindFirstChild("Root")
	local rootMotor = if root and root:IsA("Motor6D") then root else nil
	local rootPart = if rootMotor and rootMotor.Part1 then rootMotor.Part1 else nil

	local edges: { [BasePart]: { Edge } } = {}
	local joints: { Instance } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local p0, p1 = d.Part0, d.Part1
			if p0 and p1 then
				if d.Name == "Charm" or p1.Name == "Charm" then
					-- Keep Charm locked rigidly to Root (self-healing Handle -> Root misbindings).
					d.Transform = CFrame.identity
					local effectiveP0 = if p0 == handle
							and rootPart
							and rootPart ~= handle
						then rootPart
						else p0
					addEdge(edges, effectiveP0, p1, nil)
					addEdge(edges, p1, effectiveP0, nil)
				else
					-- Animated only from Part0 to Part1.
					addEdge(edges, p0, p1, d)
					addEdge(edges, p1, p0, nil)
				end
			end
			table.insert(joints, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local p0, p1 = (d :: any).Part0 :: BasePart?, (d :: any).Part1 :: BasePart?
			if p0 and p1 then
				local effectiveP0 = if p0 == handle
						and rootPart
						and rootPart ~= handle
						and isCharmAttachmentPart(p1)
					then rootPart
					else p0
				local effectiveP1 = if p1 == handle
						and rootPart
						and rootPart ~= handle
						and isCharmAttachmentPart(p0)
					then rootPart
					else p1
				addEdge(edges, effectiveP0, effectiveP1, nil)
				addEdge(edges, effectiveP1, effectiveP0, nil)
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
		rootMotor = rootMotor,
		links = links,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		world = world,
	}
end

-- Works out every part's CFrame with the handle at `handleCf` (into
-- `rig.world` and `rig.cframes`), without moving anything yet. `rootWeight`
-- (0..1, default 1) scales how much of the clip's Root joint motion is used:
-- aiming keeps the sight still while the action, mag and hands still move.
function ViewmodelRig.solve(rig: ViewmodelRig, handleCf: CFrame, rootWeight: number?)
	local world = rig.world
	local cframes = rig.cframes
	world[rig.handle] = handleCf
	cframes[1] = handleCf
	for i, link in rig.links do
		local parentCf = world[link.parent] or handleCf
		local motor = link.motor
		local cf: CFrame
		if motor then
			local transform = motor.Transform
			if motor == rig.rootMotor and rootWeight and rootWeight < 1 then
				transform = CFrame.new():Lerp(transform, math.max(rootWeight, 0))
			end
			cf = parentCf * motor.C0 * transform * motor.C1:Inverse()
		else
			cf = parentCf * link.offset
		end
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
