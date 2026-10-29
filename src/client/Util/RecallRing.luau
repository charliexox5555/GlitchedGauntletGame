--!strict
-- Recall's range ring (vault/01 Design/Abilities/Recall.md → Range ring),
-- like Chamber's: a subtle dashed violet ring on the floor at the teleport
-- range around your anchor, only on your screen (ModController drives it: the
-- planted anchor, or the hologram while you aim the plant). Each dash sits on
-- the floor found under it (stairs, ramps), so the ring follows the ground;
-- where there is no floor (a drop) the ring has a gap. It turns red while
-- you're outside the range.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RecallRing = {}

local DASHES = 72
local DASH_FILL = 0.62 -- share of each step that's drawn (the rest is the gap)
local WIDTH = 0.22
local LIFT = 0.07 -- studs above the floor
local SEARCH_UP = 6 -- the floor is looked for from this far above the centre
local SEARCH_DOWN = 24
local MAX_STEP = 4 -- studs of height between dash ends that still join
local REBUILD_MOVE = 0.4 -- studs the centre moves before the floor is found again
local REBUILD_EVERY = 0.12 -- seconds, at most, between rebuilds while it moves
local VIOLET = Color3.fromHex("9B6BFF")
local RED = Color3.fromHex("F87171")
local INSIDE_ALPHA = 0.55
local OUTSIDE_ALPHA = 0.3

local folder: Folder? = nil
local dashes: { Part } = {}
local center: Vector3? = nil
local radius = 0
local builtAt = -math.huge
local inside = true

local function parts(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "RecallRing"
	made.Parent = Workspace
	folder = made
	table.clear(dashes)
	for i = 1, DASHES do
		local p = Instance.new("Part")
		p.Name = "Dash" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false -- invisible to every raycast
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = VIOLET
		p.Transparency = 1
		p.Size = Vector3.new(WIDTH, 0.04, 1)
		p.Parent = made
		dashes[i] = p
	end
	return made
end

-- Bodies don't hold the ring up: floors only.
local function floorParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(exclude, dummies)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function rebuild(at: Vector3, r: number)
	parts()
	local params = floorParams()
	local points: { Vector3? } = {}
	for i = 1, DASHES do
		local a = (i - 1) / DASHES * math.pi * 2
		local top = at + Vector3.new(math.cos(a) * r, SEARCH_UP, math.sin(a) * r)
		local hit = Workspace:Raycast(top, Vector3.new(0, -(SEARCH_UP + SEARCH_DOWN), 0), params)
		points[i] = if hit then hit.Position + Vector3.new(0, LIFT, 0) else nil
	end
	for i, p in dashes do
		local a, b = points[i], points[i % DASHES + 1]
		if a and b and math.abs(a.Y - b.Y) <= MAX_STEP then
			-- The dash: the first DASH_FILL of the step from a toward b.
			local to = a:Lerp(b, DASH_FILL)
			local length = (to - a).Magnitude
			p.Size = Vector3.new(WIDTH, 0.04, math.max(length, 0.05))
			p.CFrame = CFrame.lookAt(a:Lerp(to, 0.5), to)
			p.Transparency = if inside then INSIDE_ALPHA else OUTSIDE_ALPHA
		else
			p.Transparency = 1
		end
	end
end

-- Shows the ring of radius `r` around `at` (the anchor or the hologram);
-- `isInside`: whether you stand inside the range (violet) or not (red).
function RecallRing.show(at: Vector3, r: number, isInside: boolean)
	local now = os.clock()
	local c = center
	local moved = c == nil or (c - at).Magnitude > REBUILD_MOVE or r ~= radius
	local insideChanged = isInside ~= inside
	inside = isInside
	if moved and now - builtAt >= REBUILD_EVERY then
		center = at
		radius = r
		builtAt = now
		rebuild(at, r)
	elseif insideChanged then
		for _, p in dashes do
			if p.Transparency < 1 then
				p.Transparency = if inside then INSIDE_ALPHA else OUTSIDE_ALPHA
			end
		end
	end
	if insideChanged then
		for _, p in dashes do
			p.Color = if inside then VIOLET else RED
		end
	end
end

function RecallRing.hide()
	if center == nil then
		return
	end
	center = nil
	for _, p in dashes do
		p.Transparency = 1
	end
end

return RecallRing
