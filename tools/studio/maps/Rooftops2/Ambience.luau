--!strict
-- Rooftops2 ambience emitters (2026-11-05, lane F). Run in Studio (edit mode,
-- the match place) through the command bar or MCP; it rebuilds the "Ambience"
-- folder inside Workspace.Rooftops2 and touches nothing else (lane G's
-- Greybox / Art / Lighting stay as they are). Save the place after.
--
-- What it places (local coordinates from the map origin (3000, 200, 0); the
-- roofs span about x -48..48, z -80..80, the street is far below):
--   * AC: a loop on each rooftop and Pit air-conditioning unit (the nearest
--     four play, Config/Ambience MAX_LOOPS).
--   * Pigeon: cooing on the penthouses, the tank houses and the lift tower.
--   * Flap: a pigeon taking off from the two water tanks.
--   * CarHorn: horns in the street below, around the block.
--   * Siren: two far points across the city.
-- No rooms: nothing on Rooftops2 is enterable. Emitters are invisible,
-- anchored, non-colliding 1-stud parts tagged AmbienceEmitter with a Sound
-- attribute (a key of Config/Ambience SPOTS).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(3000, 200, 0)
local TAG_EMITTER = "AmbienceEmitter"

local EMITTERS: { { sound: string, at: Vector3 } } = {
	-- Air-conditioning units (Greybox "Roof AC" / "Pit AC" centres).
	{ sound = "AC", at = Vector3.new(-42, 4, 50) },
	{ sound = "AC", at = Vector3.new(0, 4, 32) },
	{ sound = "AC", at = Vector3.new(24, 4, 31) },
	{ sound = "AC", at = Vector3.new(-24, 4, -31) },
	{ sound = "AC", at = Vector3.new(0, 4, -32) },
	{ sound = "AC", at = Vector3.new(42, 4, -50) },
	{ sound = "AC", at = Vector3.new(-14, -4, 8) },
	{ sound = "AC", at = Vector3.new(14, -4, -8) },
	-- Pigeons on the high ledges.
	{ sound = "Pigeon", at = Vector3.new(0, 12, 56) },
	{ sound = "Pigeon", at = Vector3.new(0, 12, -56) },
	{ sound = "Pigeon", at = Vector3.new(42, 9, 74) },
	{ sound = "Pigeon", at = Vector3.new(-42, 9, -74) },
	{ sound = "Flap", at = Vector3.new(42, 23, 74) },
	{ sound = "Flap", at = Vector3.new(-42, 23, -74) },
	-- The street below.
	{ sound = "CarHorn", at = Vector3.new(80, -70, 20) },
	{ sound = "CarHorn", at = Vector3.new(-80, -70, -40) },
	{ sound = "CarHorn", at = Vector3.new(10, -70, 120) },
	-- Far across the city.
	{ sound = "Siren", at = Vector3.new(300, -40, 450) },
	{ sound = "Siren", at = Vector3.new(-350, -40, -400) },
}

local map = Workspace:FindFirstChild("Rooftops2")
assert(map, "Workspace.Rooftops2 not found (run in the match place)")
local old = map:FindFirstChild("Ambience")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Ambience"

for i, e in EMITTERS do
	local p = Instance.new("Part")
	p.Name = string.format("%s_%02d", e.sound, i)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(ORIGIN + e.at)
	p:SetAttribute("Sound", e.sound)
	CollectionService:AddTag(p, TAG_EMITTER)
	p.Parent = folder
end
folder.Parent = map
print(string.format("Rooftops2 ambience: %d emitters", #EMITTERS))
