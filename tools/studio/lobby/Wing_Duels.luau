--!strict
-- Lobby greybox: the Duels wing, straight ahead of spawn (north). A long dark
-- queue hall in the plan's horror-lobby mood. One dead-straight 22-wide aisle
-- runs up x = 0, so from spawn the whole hall reads as a perspective of arches
-- ending at the GAUNTLET gate. Pad bays line both sides, grouped into mode
-- sections: 1V1 (6 bays, nearest), 2V2 (4), 3V3 (4), then the dormant 4V4 bays
-- and the GAUNTLET chamber with its round apse.
--
-- Section rhythm (compress, release): every section opens through a low arch
-- (16) carrying its mode title, then the aisle rises to a 26 nave while the bays
-- sit under a 14 soffit on either side, like side chapels.
-- Run it as a bundle: `python tools/studio/lobby/bundle.py Wing_Duels`.

local AISLE = 11 -- aisle half-width: 22 wide
local BAY_X = 12 -- bays start here; a 1-stud kerb sits between
local SOFFIT = 14 -- bay ceiling
local NAVE = 26 -- aisle ceiling inside a section
local ARCH = 16 -- aisle ceiling under an arch
local ARCH_DEPTH = 4
local DIVIDER = 2 -- wall between neighbouring bays
local FLOOR = 0.05 -- wing floor top: just above the hub floor where they overlap
local AISLE_TOP = 0.11

local duelsRock = Color3.fromHex("2E2F33")
local dimText = Color3.fromRGB(190, 192, 196)
local ROCK: PartOpts = { material = Enum.Material.Slate }
local NEON: PartOpts = { material = Enum.Material.Neon, collide = false }
local OFF: PartOpts = { collide = false }

type Section = {
	key: string,
	title: string,
	color: Color3,
	live: boolean,
	party: number,
	depth: number, -- bay depth across x
	len: number, -- bay length along z
	perSide: number,
}

local SECTIONS: { Section } = {
	{
		key = "1v1",
		title = "1V1",
		color = C.m1v1,
		live = true,
		party = 2,
		depth = 12,
		len = 12,
		perSide = 3,
	},
	{
		key = "2v2",
		title = "2V2",
		color = C.m2v2,
		live = true,
		party = 4,
		depth = 15,
		len = 15,
		perSide = 2,
	},
	{
		key = "3v3",
		title = "3V3",
		color = C.m3v3,
		live = true,
		party = 6,
		depth = 16,
		len = 17,
		perSide = 2,
	},
	{
		key = "4v4",
		title = "4V4",
		color = C.m4v4,
		live = false,
		party = 8,
		depth = 17,
		len = 18,
		perSide = 1,
	},
}

-- Outer x of a section's back wall.
local function outerX(s: Section): number
	return BAY_X + s.depth + 2
end

-- A section arch across the whole hall, zN..zS (zN further north). Its piers
-- run out to xOut, so they also close the step between two section widths.
local function arch(
	f: Instance,
	name: string,
	zN: number,
	zS: number,
	xOut: number,
	top: number,
	lines: { Line }?
)
	box(f, name .. "_Floor", -xOut, xOut, -2, FLOOR, zN, zS, C.duelsFloor)
	box(f, name .. "_Header", -AISLE, AISLE, ARCH, top, zN, zS, duelsRock, ROCK)
	for _, side in { -1, 1 } do
		box(f, name .. "_Pier", side * AISLE, side * xOut, 0, top, zN, zS, C.duelsWall)
		-- Chamfered shoulder where pier meets header, so the opening reads as a
		-- portal rather than a square hole (clear width at head height stays 22).
		make(
			f,
			name .. "_Shoulder",
			Vector3.new(3, 3, zS - zN),
			CFrame.new(side * AISLE, ARCH, (zN + zS) / 2) * CFrame.Angles(0, 0, math.rad(45)),
			C.duelsWall
		)
	end
	box(f, name .. "_RedEdge", -8.8, 8.8, ARCH - 0.2, ARCH, zS - 0.3, zS, C.duelsRed, NEON)
	if lines then
		sign(f, name .. "_Title", 20, 8, Vector3.new(0, 21, zS + 0.2), SOUTH, lines)
	end
end

-- One mode section from zS north. Returns its north end.
local function section(f: Instance, s: Section, zS: number): number
	local n = s.key
	local zN = zS - (s.perSide * s.len + (s.perSide - 1) * DIVIDER)
	local xb = BAY_X + s.depth -- back wall inner face
	local xo = outerX(s)
	local ring = s.live and s.color or C.unpowered

	box(f, n .. "_Floor", -xo, xo, -2, FLOOR, zN, zS, C.duelsFloor)
	box(f, n .. "_NaveCeiling", -AISLE - 1, AISLE + 1, NAVE, NAVE + 1, zN, zS, C.steel)
	for _, side in { -1, 1 } do
		box(f, n .. "_Kerb", side * AISLE, side * BAY_X, 0, 0.3, zN, zS, C.steel)
		box(f, n .. "_Soffit", side * AISLE, side * xo, SOFFIT, SOFFIT + 1, zN, zS, C.duelsWall)
		box(
			f,
			n .. "_SoffitEdge",
			side * AISLE,
			side * (AISLE + 0.4),
			SOFFIT - 0.2,
			SOFFIT - 0.05,
			zN,
			zS,
			C.duelsRed,
			NEON
		)
		-- Raw rock above the bays closes the nave up to its ceiling.
		box(
			f,
			n .. "_Clerestory",
			side * AISLE,
			side * (AISLE + 1),
			SOFFIT + 0.5,
			NAVE + 0.5,
			zN,
			zS,
			duelsRock,
			ROCK
		)
		box(f, n .. "_BackWall", side * xb, side * xo, 0, SOFFIT + 1, zN, zS, C.duelsWall)
		box(f, n .. "_TrussRail", side * 5.5, side * 6.5, NAVE - 4, NAVE - 3, zN, zS, C.steel)

		for i = 1, s.perSide do
			local b1 = zS - (i - 1) * (s.len + DIVIDER)
			local b0 = b1 - s.len
			local zc = (b0 + b1) / 2
			local bay = string.format("%s_Bay%s%d", n, side < 0 and "W" or "E", i)
			pad(
				f,
				bay,
				math.min(side * BAY_X, side * xb),
				math.max(side * BAY_X, side * xb),
				b0,
				b1,
				s.color,
				s.live
			)
			-- Light panel under the soffit: the pool of light over each pad.
			box(
				f,
				bay .. "_LightDeck",
				side * (BAY_X + 3),
				side * (xb - 3),
				SOFFIT - 0.15,
				SOFFIT - 0.07,
				b0 + 3,
				b1 - 3,
				C.white,
				OFF
			)
			sign(
				f,
				bay .. "_Sign",
				s.len - 3,
				6,
				Vector3.new(side * (xb - 0.2), 9.5, zc),
				Vector3.new(-side, 0, 0),
				{
					{ text = s.title, cap = 2.5, color = s.live and s.color or C.unpowered },
					{
						text = s.live and string.format("0 / %d QUEUED", s.party) or "SOON",
						cap = 1.2,
						color = s.live and C.white or C.unpowered,
					},
				}
			)
			-- Mode-colour edge under the sign.
			box(
				f,
				bay .. "_SignEdge",
				side * (xb - 0.35),
				side * xb,
				6.2,
				6.45,
				zc - (s.len - 3) / 2,
				zc + (s.len - 3) / 2,
				ring,
				s.live and NEON or OFF
			)
			if i < s.perSide then
				box(
					f,
					bay .. "_Divider",
					side * AISLE,
					side * xb,
					0,
					SOFFIT + 0.5,
					b0 - DIVIDER,
					b0,
					C.duelsWall
				)
			end
			if side > 0 then
				box(
					f,
					n .. "_Truss" .. i,
					-AISLE,
					AISLE,
					NAVE - 5,
					NAVE - 4,
					zc - 0.5,
					zc + 0.5,
					C.steel
				)
			end
		end
	end
	return zN
end

-- Entry vestibule, z -64.6..-78: the side walls start at the portal jambs. Four
-- queue terminals sit between pilasters; most players walk straight past them
-- (or press Play).
local function buildEntry(f: Instance, zN: number)
	local zS = -64.6
	box(f, "Entry_Floor", -26, 26, -2, FLOOR, zN, zS, C.duelsFloor)
	box(f, "Entry_Ceiling", -28, 28, NAVE - 1, NAVE, zN, zS, C.steel)
	for _, side in { -1, 1 } do
		local face = Vector3.new(-side, 0, 0)
		box(f, "Entry_Wall", side * 26, side * 28, -2, NAVE, zN, -62.82, C.duelsWall)
		for _, z in { { -64.6, -66.1 }, { -70.5, -72 } } do
			box(f, "Entry_Pilaster", side * 24.5, side * 26, 0, NAVE - 1, z[2], z[1], C.duelsWall)
		end
		for _, zc in { -68.3, -75 } do
			box(f, "Entry_Terminal", side * 23.5, side * 26, 0, 4.2, zc - 1.5, zc + 1.5, C.steel)
			sign(
				f,
				"Entry_TerminalScreen",
				2.6,
				1.8,
				Vector3.new(side * 23.3, 3.2, zc),
				face,
				{ { text = "QUEUE", cap = 0.6 } },
				nil,
				C.screen
			)
		end
		sign(f, "Entry_QueueSign", 11, 3, Vector3.new(side * 24.3, 10.5, -71.25), face, {
			{ text = "QUEUE TERMINALS", cap = 1.2 },
			{ text = "OR JUST PRESS PLAY", cap = 0.9, color = dimText },
		})
	end
end

-- The GAUNTLET chamber: the hall's destination. A taller room (34) that ends in
-- a round apse (echoing the rotunda), with a dais and a dormant gate on the axis.
local function buildChamber(f: Instance, zS: number)
	local cz, r, top = -260, 36, 34
	box(f, "Chamber_Floor", -r - 2, r + 2, -2, FLOOR, -299, zS, C.duelsFloor)
	box(f, "Chamber_Roof", -r - 2, r + 2, top, top + 1, -299, zS, C.steel)
	for _, side in { -1, 1 } do
		box(f, "Chamber_Wall", side * r, side * (r + 2), -2, ARCH, cz, zS, C.duelsWall)
		box(f, "Chamber_WallRock", side * r, side * (r + 2), ARCH, top + 1, cz, zS, duelsRock, ROCK)
		for _, z in { -228, -250 } do
			cylinder(
				f,
				"Chamber_Column",
				side * 33,
				z,
				1.5,
				0,
				top,
				C.steel,
				{ material = Enum.Material.Metal }
			)
		end
		pad(
			f,
			side < 0 and "GauntletW" or "GauntletE",
			side < 0 and -30 or 12,
			side < 0 and -12 or 30,
			-248,
			-230,
			C.gauntlet,
			false
		)
		sign(
			f,
			"Gauntlet_Sign",
			12,
			6,
			Vector3.new(side * (r - 0.2), 9.5, -239),
			Vector3.new(-side, 0, 0),
			{
				{ text = "GAUNTLET", cap = 2.5, color = C.unpowered },
				{ text = "SOON", cap = 1.2, color = C.unpowered },
			}
		)
	end
	arc(f, "Apse", r, r + 2, 270, 90, -2, top + 1, duelsRock, ROCK, nil, 0, cz)

	-- Dais and dormant gate on the axis: the end of the perspective from spawn.
	cylinder(f, "Dais_Apron", 0, -270, 20, -1, AISLE_TOP, C.duelsAisle)
	cylinder(f, "Dais_Low", 0, -270, 16, -1, 0.6, C.concrete)
	cylinder(f, "Dais_High", 0, -270, 12, -1, 1.2, C.steel, { material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		box(f, "Gate_Column", side * 17, side * 21, 0, 30, -287, -283, C.steel)
	end
	box(f, "Gate_Lintel", -21, 21, 26, 30, -287, -283, C.steel)
	box(f, "Gate_RedEdge", -17, 17, 25.8, 26, -284, -283, C.duelsRed, NEON)
	-- Kept within y 7-19 so its middle shows through every arch from spawn.
	sign(f, "Gate_Title", 34, 12, Vector3.new(0, 13, -282.8), SOUTH, {
		{ text = "GAUNTLET", cap = 5, color = C.gauntlet },
		{ text = "COMING SOON", cap = 1.6, color = dimText },
	})
end

local function buildDuels(f: Instance)
	local z = -78
	buildEntry(f, z)
	local prevOut = 28 -- the entry walls
	for i, s in SECTIONS do
		local zN = z - ARCH_DEPTH
		local tint = s.live and s.color or s.color:Lerp(C.unpowered, 0.6)
		arch(f, "Arch" .. i, zN, z, math.max(prevOut, outerX(s)), NAVE + 1, {
			{ text = s.title, cap = 4, color = tint },
			{
				text = s.live and string.format("%d PLAYERS", s.party) or "COMING SOON",
				cap = 1.2,
				color = dimText,
			},
		})
		z = section(f, s, zN)
		prevOut = outerX(s)
	end
	-- Chamber arch: taller header, the last compression before the big room.
	arch(f, "ArchGauntlet", z - ARCH_DEPTH, z, 38, 35, {
		{ text = "GAUNTLET", cap = 3.5, color = C.gauntlet:Lerp(C.unpowered, 0.35) },
		{ text = "COMING SOON", cap = 1.2, color = dimText },
	})
	buildChamber(f, z - ARCH_DEPTH)

	-- Aisle runner with red edges from the portal to the dais apron.
	box(f, "Aisle", -AISLE, AISLE, -1, AISLE_TOP, -250, -64.6, C.duelsAisle)
	for _, side in { -1, 1 } do
		box(
			f,
			"AisleRed",
			side * 10.6,
			side * 10.9,
			AISLE_TOP,
			AISLE_TOP + 0.05,
			-250,
			-64.6,
			C.duelsRed,
			NEON
		)
	end

	-- On the first arch's back: the way home for players walking out.
	sign(f, "HubSign", 14, 4.5, Vector3.new(0, 19, -82.2), NORTH, {
		{ text = "HUB", cap = 2.2 },
		{ text = "BACK TO SPAWN", cap = 1, color = dimText },
	})
end

local duels = newSection("Wing_Duels")
buildDuels(duels)
publish(duels)
