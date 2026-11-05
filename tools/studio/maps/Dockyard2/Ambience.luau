--!strict
-- Dockyard2 ambience emitters and rooms (2026-11-05, lane F). Run in Studio
-- (edit mode, the match place) through the command bar or MCP; it rebuilds
-- the "Ambience" folder inside Workspace.Dockyard2 and touches nothing else
-- (lane G's Greybox / Art / Lighting stay as they are). Save the place after.
--
-- What it places (local coordinates from the map origin (-3000, 200, 0); the
-- deck is 136 x 236, the water plane all round at y -9.6, the Sheds at
-- x 42..68, z 24..60 and mirrored):
--   * Water: loops along both long quay edges and both ends, just above the water.
--   * CraneHum: one loop at the crane's cab.
--   * Gulls: three one-shot emitters out over the water.
--   * Horn: one far emitter out at sea, rare.
--   * Creak: one-shots on the crane boxes and the shed-yard stacks.
--   * Two invisible room boxes over the Shed interiors (tag AmbienceIndoor).
-- Emitters are invisible, anchored, non-colliding 1-stud parts tagged
-- AmbienceEmitter with a Sound attribute (a key of Config/Ambience SPOTS).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(-3000, 200, 0)
local TAG_EMITTER = "AmbienceEmitter"
local TAG_INDOOR = "AmbienceIndoor"

local EMITTERS: { { sound: string, at: Vector3 } } = {
	-- Water against the quay walls and the ends of the pier.
	{ sound = "Water", at = Vector3.new(70, -6, -90) },
	{ sound = "Water", at = Vector3.new(70, -6, -30) },
	{ sound = "Water", at = Vector3.new(70, -6, 30) },
	{ sound = "Water", at = Vector3.new(70, -6, 90) },
	{ sound = "Water", at = Vector3.new(-70, -6, -90) },
	{ sound = "Water", at = Vector3.new(-70, -6, -30) },
	{ sound = "Water", at = Vector3.new(-70, -6, 30) },
	{ sound = "Water", at = Vector3.new(-70, -6, 90) },
	{ sound = "Water", at = Vector3.new(0, -6, 122) },
	{ sound = "Water", at = Vector3.new(0, -6, -122) },
	-- The crane's motor, at the cab.
	{ sound = "CraneHum", at = Vector3.new(0, 40, 0) },
	-- Gulls out over the water.
	{ sound = "Gulls", at = Vector3.new(130, 30, 60) },
	{ sound = "Gulls", at = Vector3.new(-130, 30, -60) },
	{ sound = "Gulls", at = Vector3.new(20, 35, 190) },
	-- A ship far out.
	{ sound = "Horn", at = Vector3.new(400, 20, 700) },
	-- Creaks in the stacks.
	{ sound = "Creak", at = Vector3.new(28, 8, 0) },
	{ sound = "Creak", at = Vector3.new(-28, 8, 0) },
	{ sound = "Creak", at = Vector3.new(52, 8, 76) },
	{ sound = "Creak", at = Vector3.new(-52, 8, -76) },
}

-- The Shed interiors (walls 1 stud thick, 16 high), a little inside the walls.
local ROOMS: { { at: Vector3, size: Vector3 } } = {
	{ at = Vector3.new(55, 8, 42), size = Vector3.new(25, 16, 35) },
	{ at = Vector3.new(-55, 8, -42), size = Vector3.new(25, 16, 35) },
}

local map = Workspace:FindFirstChild("Dockyard2")
assert(map, "Workspace.Dockyard2 not found (run in the match place)")
local old = map:FindFirstChild("Ambience")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Ambience"

local function marker(name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = folder
	return p
end

for i, e in EMITTERS do
	local p = marker(string.format("%s_%02d", e.sound, i), CFrame.new(ORIGIN + e.at), Vector3.one)
	p:SetAttribute("Sound", e.sound)
	CollectionService:AddTag(p, TAG_EMITTER)
end
for i, r in ROOMS do
	local p = marker(string.format("Room_%02d", i), CFrame.new(ORIGIN + r.at), r.size)
	CollectionService:AddTag(p, TAG_INDOOR)
end
folder.Parent = map
print(string.format("Dockyard2 ambience: %d emitters, %d rooms", #EMITTERS, #ROOMS))
