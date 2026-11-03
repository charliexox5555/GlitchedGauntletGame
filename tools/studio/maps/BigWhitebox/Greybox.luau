--!strict
-- Big Whitebox (vault/01 Design/Maps/Big Whitebox.md): the Whitebox look scaled
-- up for 3v3-4v4, like RIVALS' Big Arena. Same white panel kit and the same
-- cover heights (low 3, full 7+); a bigger room with more cover, three lanes,
-- two perches per side. Map space: origin on the floor at the centre, team A
-- (blue) spawns at -Z, team B (yellow) at +Z; 180-degree rotational symmetry,
-- so only team A's half is listed and each piece is also placed rotated.
--
--   python tools/studio/maps/bundle.py BigWhitebox Greybox -o big.luau

newMap("BigWhitebox", CFrame.new(0, 200, -1500))

local PANEL = "rbxassetid://104451231800023" -- Whitebox panel texture (image id)
local PANEL_TINT = Color3.fromRGB(124, 128, 148)
local BLUE = Color3.fromRGB(61, 111, 214)
local YELLOW = Color3.fromRGB(242, 190, 46)

local COLORS = {
	floor = Color3.fromRGB(221, 224, 232),
	wall = Color3.fromRGB(207, 210, 220),
	cover = Color3.fromRGB(211, 214, 224),
	pillar = Color3.fromRGB(180, 185, 200),
	perch = Color3.fromRGB(196, 200, 213),
	frame = Color3.fromRGB(230, 232, 239),
}

-- The Whitebox panel overlay on every face (8-stud panels, centred).
local function panel(p: BasePart)
	for _, face in Enum.NormalId:GetEnumItems() do
		local t = Instance.new("Texture")
		t.Texture = PANEL
		t.Face = face
		t.StudsPerTileU = 8
		t.StudsPerTileV = 8
		t.Color3 = PANEL_TINT
		t.Parent = p
	end
end

-- Map size.
local ROOM_X = 60 -- half width
local ROOM_Z = 88 -- half length
local ALCOVE_X = 20 -- half width of a spawn alcove
local ALCOVE_D = 18 -- depth
local WALL_H = 48
local WALL_T = 6

type Piece = {
	name: string,
	size: Vector3,
	x: number,
	y: number?,
	z: number,
	yaw: number?,
	kind: string,
	wedge: boolean?,
}

-- Team A's half (z <= 0). y is the bottom (0 = floor) unless given.
local HALF: { Piece } = {
	-- Spawn exit and the near zone.
	{ name = "Baffle", size = Vector3.new(20, 10, 3), x = 0, z = -76, kind = "cover" },
	{ name = "CornerCube_R", size = Vector3.new(8, 8, 8), x = 56, z = -84, kind = "cover" },
	{ name = "CornerCube_L", size = Vector3.new(8, 8, 8), x = -36, z = -84, kind = "cover" },
	-- Left lane: a perch with a ramp up from the middle side.
	{ name = "Perch_L", size = Vector3.new(26, 7, 22), x = -47, z = -62, kind = "perch" },
	{
		name = "PerchRamp_L",
		size = Vector3.new(10, 7, 14),
		x = -39,
		z = -44,
		yaw = 180,
		kind = "perch",
		wedge = true,
	},
	{ name = "LowWall_L", size = Vector3.new(8, 3, 3), x = -24, z = -46, kind = "cover" },
	{ name = "Slab_L", size = Vector3.new(16, 8, 4), x = -40, z = -26, kind = "cover" },
	{ name = "WallBox_L", size = Vector3.new(6, 8, 12), x = -57, z = -12, kind = "cover" },
	-- Middle: staggered walls toward the diamond.
	{ name = "MidWall", size = Vector3.new(14, 8, 3), x = -4, z = -52, kind = "cover" },
	{ name = "LowWall_M", size = Vector3.new(8, 3, 3), x = 10, z = -40, kind = "cover" },
	{ name = "MidBlock", size = Vector3.new(10, 8, 10), x = 8, z = -20, kind = "cover" },
	-- Right lane: a window frame (shoot through, walk round) and a long slab.
	{ name = "FramePost_A", size = Vector3.new(4, 12, 4), x = 32, z = -50, kind = "frame" },
	{ name = "FramePost_B", size = Vector3.new(4, 12, 4), x = 46, z = -50, kind = "frame" },
	{ name = "FrameSill", size = Vector3.new(10, 3, 4), x = 39, z = -50, kind = "frame" },
	{ name = "FrameLintel", size = Vector3.new(10, 3, 4), x = 39, y = 9, z = -50, kind = "frame" },
	{ name = "Slab_R", size = Vector3.new(16, 8, 4), x = 40, z = -30, kind = "cover" },
	{ name = "LowWall_R", size = Vector3.new(8, 3, 3), x = 48, z = -16, kind = "cover" },
	{ name = "Perch_R", size = Vector3.new(18, 7, 14), x = 51, z = -66, kind = "perch" },
	{
		name = "PerchRamp_R",
		size = Vector3.new(8, 7, 12),
		x = 55,
		z = -53,
		yaw = 180,
		kind = "perch",
		wedge = true,
	},
	-- Halfway line (each is mirrored onto the other side).
	{ name = "SideBlock", size = Vector3.new(10, 8, 12), x = -34, z = 0, kind = "cover" },
	{ name = "Pillar_A", size = Vector3.new(6, 48, 6), x = -16, z = -30, kind = "pillar" },
	{ name = "Pillar_B", size = Vector3.new(6, 48, 6), x = 22, z = -30, kind = "pillar" },
}

local function placePiece(folder: Instance, p: Piece, team: string, rotate: boolean)
	local x, z, yaw = p.x, p.z, p.yaw or 0
	if rotate then
		x, z, yaw = -x, -z, yaw + 180
	end
	local y = (p.y or 0) + p.size.Y / 2
	local color = COLORS[p.kind] or COLORS.cover
	local name = p.name .. "_" .. team
	local part = if p.wedge
		then wedge(folder, name, p.size, at(x, y, z, yaw), color)
		else box(folder, name, p.size, at(x, y, z, yaw), color)
	panel(part)
	-- Slanted tops don't take the panel grid well; keep them plain.
	if p.wedge then
		for _, t in part:GetChildren() do
			t:Destroy()
		end
	end
end

-- Floor, walls and alcoves ------------------------------------------------------

do
	local g = section("Greybox", "Shell")
	local floor =
		box(g, "Floor_Main", Vector3.new(ROOM_X * 2, 4, ROOM_Z * 2), at(0, -2, 0), COLORS.floor)
	panel(floor)
	for _, side in { { -1, "A" }, { 1, "B" } } do
		local s, team = side[1], side[2]
		local zAlc = s * (ROOM_Z + ALCOVE_D / 2)
		panel(
			box(
				g,
				"Floor_Alcove_" .. team,
				Vector3.new(ALCOVE_X * 2, 4, ALCOVE_D),
				at(0, -2, zAlc),
				COLORS.floor
			)
		)
		-- End wall either side of the alcove mouth.
		local endW = ROOM_X - ALCOVE_X
		local endZ = s * (ROOM_Z + WALL_T / 2)
		for _, lr in { -1, 1 } do
			panel(
				box(
					g,
					string.format("EndWall_%s_%s", team, if lr < 0 then "L" else "R"),
					Vector3.new(endW + WALL_T, WALL_H, WALL_T),
					at(lr * (ALCOVE_X + endW / 2 + WALL_T / 2), WALL_H / 2, endZ),
					COLORS.wall
				)
			)
			-- Alcove side walls.
			panel(
				box(
					g,
					string.format("AlcoveSide_%s_%s", team, if lr < 0 then "L" else "R"),
					Vector3.new(WALL_T, WALL_H, ALCOVE_D),
					at(lr * (ALCOVE_X + WALL_T / 2), WALL_H / 2, zAlc),
					COLORS.wall
				)
			)
		end
		panel(
			box(
				g,
				"AlcoveBack_" .. team,
				Vector3.new(ALCOVE_X * 2 + WALL_T * 2, WALL_H, WALL_T),
				at(0, WALL_H / 2, s * (ROOM_Z + ALCOVE_D + WALL_T / 2)),
				COLORS.wall
			)
		)
	end
	for _, lr in { -1, 1 } do
		panel(
			box(
				g,
				if lr < 0 then "Wall_West" else "Wall_East",
				Vector3.new(WALL_T, WALL_H, ROOM_Z * 2 + WALL_T * 2),
				at(lr * (ROOM_X + WALL_T / 2), WALL_H / 2, 0),
				COLORS.wall
			)
		)
	end
	report("Shell: room 120 x 176, alcoves 40 x 18, walls 48")
end

-- Cover ---------------------------------------------------------------------------

do
	local c = section("Greybox", "Cover")
	-- The centre diamond (one piece, on the axis).
	panel(box(c, "Diamond", Vector3.new(20, 14, 20), at(0, 7, 0, 45), COLORS.cover))
	local n = 1
	for _, p in HALF do
		placePiece(c, p, "A", false)
		placePiece(c, p, "B", true)
		n += 2
	end
	report(string.format("Cover: %d pieces (180-degree pairs + the diamond)", n))
end

-- Team paint: bands at the alcove backs and on the baffles, so you know your end.
do
	local p = section("Greybox", "Paint")
	for _, side in { { -1, "A", BLUE }, { 1, "B", YELLOW } } do
		local s, team, color = side[1], side[2] :: string, side[3] :: Color3
		local band = box(
			p,
			"Band_Back_" .. team,
			Vector3.new(ALCOVE_X * 2, 2.5, 0.1),
			at(0, 1.25, s * (ROOM_Z + ALCOVE_D - 0.05)),
			color,
			{ castShadow = false }
		)
		decor(band)
		local baffleBand = box(
			p,
			"Band_Baffle_" .. team,
			Vector3.new(20.1, 2, 3.1),
			at(0, 9, s * 76),
			color,
			{ castShadow = false }
		)
		decor(baffleBand)
		for _, lr in { -1, 1 } do
			local pb = box(
				p,
				string.format("Band_Pillar_%s_%d", team, lr),
				Vector3.new(6.1, 2, 6.1),
				at(
					if s < 0 then (if lr < 0 then -16 else 22) else (if lr < 0 then 16 else -22),
					13,
					s * 30
				),
				color,
				{ castShadow = false }
			)
			decor(pb)
		end
	end
	report("Paint: team bands")
end

-- Spawns and barriers -------------------------------------------------------------

do
	spawnsClear()
	for _, side in { { -1, "A" }, { 1, "B" } } do
		local s, team = side[1], side[2]
		local z = s * (ROOM_Z + ALCOVE_D / 2 + 2)
		for i, x in { -12, -4, 4, 12 } do
			-- Facing the room.
			spawnPad(team, i, at(x * -s, 0, z, if s < 0 then 180 else 0))
		end
		barrier(
			"Barrier_" .. team,
			Vector3.new(ALCOVE_X * 2, WALL_H, 1),
			at(0, WALL_H / 2, s * (ROOM_Z + 0.5))
		)
	end
	report("Spawns: 4 per team in the alcoves; barriers across the alcove mouths")
end
