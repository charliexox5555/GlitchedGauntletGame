--!strict
-- Lobby greybox: the hub (spawn rotunda + outer ring, with the ring ends of the
-- four portals). Run it as a bundle: `python tools/studio/lobby/bundle.py Hub`.
-- The wings are separate Wing_*.luau scripts.

local function buildRotunda(f: Instance)
	-- Floor: one disc for the rotunda over the hub floor (built in Ring).
	cylinder(f, "RotundaFloor", 0, 0, 44, -0.98, 0.02, C.floor)
	cylinder(f, "SunPatchInlay", 0, -10.05, 16, -0.96, 0.04, C.sunPatch)
	cylinder(f, "SpawnDais", 0, 0, 12, 0, 0.5, C.brass, { material = Enum.Material.Metal })
	box(f, "DaisNorthArrow", -0.6, 0.6, 0.5, 0.56, -11, -2, C.white, { collide = false })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.2, 12)
	spawn.CFrame = CFrame.new(0, 0.6, -3) -- faces north (-Z), toward Duels
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = f

	-- Colonnade: 8 piers and 4 slim columns, ring beam, drum, dome, oculus.
	for k = 0, 7 do
		local b = 22.5 + 45 * k
		local x, z = polar(44, b)
		local pos = Vector3.new(x, 14, z)
		make(
			f,
			"Pier_" .. k,
			Vector3.new(3, 28, 3),
			CFrame.lookAt(pos, Vector3.new(0, 14, 0)),
			C.concrete
		)
	end
	for k = 0, 3 do
		local x, z = polar(44, 45 + 90 * k)
		cylinder(
			f,
			"SlimColumn_" .. k,
			x,
			z,
			0.6,
			0,
			28,
			C.steel,
			{ material = Enum.Material.Metal }
		)
	end
	arc(f, "RingBeam", 42.5, 45.5, 0, 360, 28, 31, C.concrete)
	arc(f, "Drum", 44, 45.5, 0, 360, 31, 46, C.concrete)
	-- Shallow coffered dome (greybox: tilted panels) from y 46 at R44 up to the
	-- oculus rim at y 54, R16.
	local slope = math.sqrt(28 * 28 + 8 * 8)
	for k = 0, 31 do
		local bm = k * SEG + SEG / 2
		local mx, mz = polar(30, bm)
		local ix, iz = polar(16, bm)
		local width = 2 * 44 * math.sin(math.rad(SEG / 2)) + 0.2
		make(
			f,
			"Dome_" .. k,
			Vector3.new(width, 1, slope),
			CFrame.lookAt(Vector3.new(mx, 50, mz), Vector3.new(ix, 54, iz)),
			C.concrete
		)
	end
	arc(f, "OculusShaft", 16, 17.5, 0, 360, 54, 60, C.concrete)

	-- Leaderboards on the diagonals, facing the centre (y 12-25.5, so the two
	-- north boards sit in the default camera's first frame). Their backs point
	-- ring walkers to the wings on either side (as seen from the ring).
	local boards = {
		{ 45, "TOP WINS TODAY", "< WEAPONS | DUELS >" },
		{ 315, "TOP RATING", "< DUELS | MARKET >" },
		{ 135, "TOP STREAKS", "< RANGE | WEAPONS >" },
		{ 225, "MOST ELIMS (WEEK)", "< MARKET | RANGE >" },
	}
	-- Short rows, so 1.8-cap names fit an 18-wide board and read from spawn.
	local rows = "1  NOVA   42\n2  KAIRO  37\n3  VEX    31"
	for i, bd in boards do
		local x, z = polar(42.5, bd[1] :: number)
		local pos = Vector3.new(x, 18.75, z)
		local inward = (Vector3.new(0, 18.75, 0) - pos).Unit
		sign(f, "Leaderboard_" .. i, 18, 13.5, pos, inward, {
			{ text = bd[2] :: string, cap = 2.4 },
			{ text = rows, cap = 1.8, color = Color3.fromRGB(200, 205, 212) },
		}, { { text = bd[3] :: string, cap = 2.0 } }, C.screen)
	end

	-- Pier plaques pointing at the side wings (they sit outside the first frame).
	-- 15 wide: "WEAPONS >" at a readable cap is about 14 studs of GothamBlack.
	for _, pl in { { 22.5, "WEAPONS  >" }, { 337.5, "<  MARKET" } } do
		local x, z = polar(42.3, pl[1] :: number)
		local pos = Vector3.new(x, 10.5, z)
		sign(
			f,
			"Plaque",
			15,
			3,
			pos,
			(Vector3.new(0, 10.5, 0) - pos).Unit,
			{ { text = pl[2] :: string, cap = 2.2 } }
		)
	end
end

local function buildRing(f: Instance)
	cylinder(f, "HubFloor", 0, 0, 70, -2, 0, C.ringFloor)
	arc(f, "SlideBand", 54, 58, 0, 360, -0.97, 0.03, C.oak, nil, 4)
	arc(f, "RingCeiling", 44, 70, 0, 360, 28, 29, C.concrete, nil, 13)

	for k = 0, 31 do
		local b0 = k * SEG
		local b1 = b0 + SEG
		local bm = b0 + SEG / 2
		if inAny(bm, PORTALS) then
			arcPiece(
				f,
				"PortalLintel_" .. k,
				68,
				70,
				b0,
				b1,
				16,
				28,
				C.rock,
				{ material = Enum.Material.Slate }
			)
		elseif inAny(bm, ALCOVES) then
			arcPiece(
				f,
				"AlcoveHead_" .. k,
				68,
				70,
				b0,
				b1,
				12,
				28,
				C.rock,
				{ material = Enum.Material.Slate }
			)
		else
			arcPiece(
				f,
				"RockWall_" .. k,
				68,
				70,
				b0,
				b1,
				0,
				28,
				C.rock,
				{ material = Enum.Material.Slate }
			)
		end
	end

	-- Seating alcoves cut into the rock: lip, three oak tiers, back, sides, roof.
	for i, a in ALCOVES do
		local b0, b1 = a[1], a[2]
		local n = "Alcove" .. i
		arc(f, n .. "Floor", 68, 82, b0, b1, -2, 0, C.ringFloor)
		arc(f, n .. "Tier1", 71, 74, b0, b1, 0, 1.5, C.oak, { material = Enum.Material.Wood })
		arc(f, n .. "Tier2", 74, 77, b0, b1, 0, 3, C.oak, { material = Enum.Material.Wood })
		arc(f, n .. "Tier3", 77, 80, b0, b1, 0, 4.5, C.oak, { material = Enum.Material.Wood })
		arc(f, n .. "Back", 80, 82, b0, b1, 0, 12, C.rock, { material = Enum.Material.Slate })
		arc(f, n .. "Roof", 68, 82, b0, b1, 12, 13, C.rock, { material = Enum.Material.Slate })
		for _, b in { b0, b1 } do
			local x, z = polar(75, b)
			make(
				f,
				n .. "Side",
				Vector3.new(1, 12, 14),
				CFrame.lookAt(Vector3.new(x, 6, z), Vector3.new(0, 6, 0)),
				C.rock,
				{ material = Enum.Material.Slate }
			)
		end
	end

	-- Portal title bands above each opening (y 16.5-26.5). They hang in front of
	-- the curved lintel: flat panels at R67.4 sank into its chord ends, so the
	-- side titles sit at R66.3 and the two-segment DUELS band at R64.4.
	local titles = {
		{ 0, 64.4, 40, "DUELS", 5.5, "STEP ON A PAD TO QUEUE" },
		{ 90, 66.3, 26, "WEAPONS", 4, "GUNS + LOCKER" },
		{ 180, 66.3, 26, "RANGE", 4.5, "PRACTICE" },
		{ 270, 66.3, 26, "MARKET", 4.5, "SHOP + BATTLE PASS" },
	}
	for _, t in titles do
		local x, z = polar(t[2] :: number, t[1] :: number)
		local pos = Vector3.new(x, 21.5, z)
		sign(
			f,
			"Title_" .. (t[4] :: string),
			t[3] :: number,
			10,
			pos,
			(Vector3.new(0, 21.5, 0) - pos).Unit,
			{
				{ text = t[4] :: string, cap = t[5] :: number },
				{ text = t[6] :: string, cap = 1.2, color = Color3.fromRGB(190, 192, 196) },
			}
		)
	end

	-- Throat walls and roofs where the straight wings meet the round ring.
	for _, s in { -1, 1 } do
		-- Market (s = -1) and Weapons (s = 1)
		box(f, "ThroatFloor", s * 66, s * 72, -2, 0, -13.27, 13.27, C.ringFloor)
		box(f, "ThroatRoof", s * 66.69, s * 72, 16, 17, -13.27, 13.27, C.concrete)
		box(f, "ThroatSideN", s * 66.7, s * 72, 0, 28, -14.27, -13.27, C.concrete)
		box(f, "ThroatSideS", s * 66.7, s * 72, 0, 28, 13.27, 14.27, C.concrete)
	end
	box(f, "RangeThroatFloor", -14, 14, -2, 0, 66, 70, C.ringFloor)
	box(f, "RangeThroatSideW", -14, -13.27, -8, 28, 66.7, 71, C.concrete)
	box(f, "RangeThroatSideE", 13.27, 14, -8, 28, 66.7, 71, C.concrete)
end

-- The template's baseplate would cover the sunken Range, and its spawn would
-- compete with ours.
for _, name in { "Baseplate", "SpawnLocation" } do
	local inst = workspace:FindFirstChild(name)
	if inst then
		inst:Destroy()
	end
end

local rotunda = newSection("Rotunda")
buildRotunda(rotunda)
publish(rotunda)
local ring = newSection("Ring")
buildRing(ring)
publish(ring)

-- Planned sun (Lobby Art Plan, Lighting): due south, 80 degrees up, so the
-- skylight beam lands on the spawn. Ambient is lifted for the greybox walk only;
-- step 6 sets the real values.
Lighting.ClockTime = 12
Lighting.GeographicLatitude = 33.5
Lighting.Ambient = Color3.fromRGB(105, 105, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 125)
