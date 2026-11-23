--!strict
-- Studio build (Edit mode): ServerStorage.DuelsCage, the cage that closes the lobby's duels area in a hosted server
-- (a queued match's reserved server: pads are off there, players queue from the menu; owner 2026-11-23).
-- Services/PadDuelService clones it into Workspace only in hosted servers. Built around the LobbyV5 duel pads
-- (tags LobbyPadSquare / LobbyQueue) with a margin: square posts, a bar every BAR_STEP studs, three rails and a
-- thin red top strip (one accent), all collidable and anchored. Idempotent. Check a capture, then save the place.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local MARGIN = 6 -- studs around the pads
local HEIGHT = 14 -- studs tall (well over a jump)
local POST = 1.2 -- post thickness
local BAR = 0.35 -- bar thickness
local BAR_STEP = 2 -- studs between bars
local POST_STEP = 10 -- studs between posts
local METAL = Color3.fromHex("2B2B30")
local ACCENT = Color3.fromHex("FF4D5E")

local root = workspace:FindFirstChild("LobbyV5")
assert(root, "Workspace.LobbyV5 missing")
local lo = Vector3.new(math.huge, math.huge, math.huge)
local hi = -lo
local found = 0
for _, tag in { "LobbyPadSquare", "LobbyQueue" } do
	for _, p in CollectionService:GetTagged(tag) do
		if p:IsA("BasePart") and p:IsDescendantOf(root) then
			found += 1
			local h = p.Size / 2
			lo = lo:Min(p.Position - h)
			hi = hi:Max(p.Position + h)
		end
	end
end
assert(found > 0, "no duel pads tagged inside LobbyV5")
lo -= Vector3.new(MARGIN, 0, MARGIN)
hi += Vector3.new(MARGIN, 0, MARGIN)
local floorY = lo.Y

local old = ServerStorage:FindFirstChild("DuelsCage")
if old then
	old:Destroy()
end
local cage = Instance.new("Model")
cage.Name = "DuelsCage"

local function part(
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3,
	material: Enum.Material
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.Position = at
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = cage
	return p
end

-- One side from a to b (flat, at floor height).
local function side(a: Vector3, b: Vector3)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local dir = flat.Unit
	local along = math.abs(dir.X) > 0.5
	local function span(l: number, thick: number, h: number): Vector3
		return if along then Vector3.new(l, h, thick) else Vector3.new(thick, h, l)
	end
	-- posts, bars
	local posts = math.max(1, math.floor(len / POST_STEP))
	for i = 0, posts do
		local at = a + dir * (len * i / posts)
		part(
			"Post",
			Vector3.new(POST, HEIGHT, POST),
			Vector3.new(at.X, floorY + HEIGHT / 2, at.Z),
			METAL,
			Enum.Material.Metal
		)
	end
	local bars = math.floor(len / BAR_STEP)
	for i = 1, bars - 1 do
		local at = a + dir * (i * BAR_STEP)
		part(
			"Bar",
			Vector3.new(BAR, HEIGHT, BAR),
			Vector3.new(at.X, floorY + HEIGHT / 2, at.Z),
			METAL,
			Enum.Material.Metal
		)
	end
	-- rails, and the red strip on top
	local mid = (a + b) / 2
	for _, y in { 0.4, HEIGHT * 0.5, HEIGHT - 0.4 } do
		part(
			"Rail",
			span(len + POST, 0.6, 0.6),
			Vector3.new(mid.X, floorY + y, mid.Z),
			METAL,
			Enum.Material.Metal
		)
	end
	part(
		"Strip",
		span(len + POST, 0.7, 0.18),
		Vector3.new(mid.X, floorY + HEIGHT + 0.09, mid.Z),
		ACCENT,
		Enum.Material.Neon
	)
end

local c1 = Vector3.new(lo.X, floorY, lo.Z)
local c2 = Vector3.new(hi.X, floorY, lo.Z)
local c3 = Vector3.new(hi.X, floorY, hi.Z)
local c4 = Vector3.new(lo.X, floorY, hi.Z)
side(c1, c2)
side(c2, c3)
side(c3, c4)
side(c4, c1)
cage.Parent = ServerStorage
return `DuelsCage: {found} pads, box {lo} .. {hi}, {#cage:GetChildren()} parts`
