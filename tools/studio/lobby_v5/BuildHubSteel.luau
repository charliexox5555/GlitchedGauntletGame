--!nocheck
-- Lobby V5 HUB STEEL (vault/02 Art/Lobby V5 Plan.md, "Character pass"). ONE-TIME placement record (needs
-- ServerStorage.V5Kit.LobbySigns). Owner 2026-11-20: "they have things just support beams and all those aspects to
-- their map that really brings it together".
-- 1. Four steel H-columns in the rock corners beside the Locker and the Range (the Duels corners already have the
--    portal buttresses; the Shop corners would block its display windows). Each stands free of the jagged rock,
--    placed by raycasts 1.15 in front of the nearest rock or pipe run (the runs pass behind; a column under a
--    cable tray ends in a cap that carries it), on a bolted base plate with a hazard sleeve and collars,
--    tied back to the rock at two heights (each tie measured to the rock it meets); the tops run up into the rock.
-- 2. A box lighting truss between the two lift towers (y 27-29.4) with lattice faces, bolted end plates and four
--    hanging spot lamps.

local S = require(game:GetService("ServerStorage").V5Kit.LobbySigns:Clone())
local K = S.K
local V = Vector3.new
local hub = workspace.LobbyV5.Shell.Hub
local old = hub:FindFirstChild("Steel")
if old then
	old:Destroy()
end
local steel = K.model(hub, "Steel")
local colLk = K.look("Metal 2022", Color3.fromRGB(64, 66, 71))
local plateLk = K.look("Metal 2022", Color3.fromRGB(96, 98, 104))
local hazardLk = K.paint(Color3.fromRGB(196, 152, 34))
local rpAll = RaycastParams.new() -- rock plus the pipe runs and lamps on it: columns stand in front of all of it
rpAll.FilterType = Enum.RaycastFilterType.Include
rpAll.FilterDescendantsInstances = { hub.Rock, hub.Dressing.Pipes, hub.Dressing.WallLamps }
local rpRock = RaycastParams.new()
rpRock.FilterType = Enum.RaycastFilterType.Include
rpRock.FilterDescendantsInstances = { hub.Rock }
local function dist(d, y, side, s, rp)
	local o = K.O + V(0, y, 0) + side * s + d * 20
	local hit = workspace:Raycast(o, d * 60, rp)
	return if hit then 20 + (hit.Position - o).Magnitude else 60
end

-- 1. corner columns
local TOP = 50
local pipeOp = OverlapParams.new()
pipeOp.FilterType = Enum.RaycastFilterType.Include
pipeOp.FilterDescendantsInstances = { hub.Dressing.Pipes }
for j = 1, 4 do
	local a = math.rad(22.5 + 45 * j)
	local d = V(math.sin(a), 0, -math.cos(a))
	local side = K.UP:Cross(d)
	local minD = math.huge
	for y = 1, 31, 2 do
		for _, s in { -1.1, 0, 1.1 } do
			minD = math.min(minD, dist(d, y, side, s, rpAll))
		end
	end
	local r = minD - 1.15
	local F = K.frame(d * r, -d) -- z faces the hub centre
	local c = K.model(steel, "Column_" .. j)
	local shaft = {
		K.lpart(F, c, "FlangeF", V(-0.8, 0, 0.5), V(0.8, TOP, 0.75), colLk),
		K.lpart(F, c, "FlangeB", V(-0.8, 0, -0.75), V(0.8, TOP, -0.5), colLk),
		K.lpart(F, c, "Web", V(-0.15, 0, -0.5), V(0.15, TOP, 0.5), colLk),
	}
	-- a cable tray higher up: the column ends under it with a cap and carries it
	local lowest = math.huge
	for _, p in shaft do
		for _, q in workspace:GetPartsInPart(p, pipeOp) do
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						lowest = math.min(
							lowest,
							(q.CFrame * CFrame.new(
								q.Size.X / 2 * sx,
								q.Size.Y / 2 * sy,
								q.Size.Z / 2 * sz
							)).Position.Y - K.O.Y
						)
					end
				end
			end
		end
	end
	if lowest < TOP then
		for _, p in shaft do
			p:Destroy()
		end
		local top = lowest - 0.06
		K.lpart(F, c, "FlangeF", V(-0.8, 0, 0.5), V(0.8, top - 0.3, 0.75), colLk)
		K.lpart(F, c, "FlangeB", V(-0.8, 0, -0.75), V(0.8, top - 0.3, -0.5), colLk)
		K.lpart(F, c, "Web", V(-0.15, 0, -0.5), V(0.15, top - 0.3, 0.5), colLk)
		K.lpart(F, c, "TrayCap", V(-1.0, top - 0.3, -1.0), V(1.0, top, 1.0), plateLk)
	end
	K.lpart(F, c, "Base", V(-1.4, 0, -1.4), V(1.4, 0.3, 1.4), plateLk)
	for _, x in { -1.05, 1.05 } do
		for _, z in { -1.05, 1.05 } do
			K.lpart(F, c, "Bolt", V(x - 0.14, 0.3, z - 0.14), V(x + 0.14, 0.45, z + 0.14), K.L.dark)
		end
	end
	local sleeve = K.lpart(F, c, "Sleeve", V(-0.92, 0.3, 0.75), V(0.92, 2.4, 0.85), hazardLk)
	K.texture(sleeve, Enum.NormalId.Back, K.TEX.hazard, 2)
	for _, y in { 10, 22 } do
		K.lpart(F, c, "Collar", V(-0.95, y, -0.9), V(0.95, y + 0.6, 0.9), plateLk)
	end
	-- tie-backs to the rock at heights where the way is clear of pipes and lamps
	for _, y0 in { 16, 28 } do
		for _, dy in { 0, 1.5, -1.5, 3, -3 } do
			local y = y0 + dy
			local clear = true
			for _, s in { -0.6, 0, 0.6 } do
				for _, yy in { y - 0.6, y + 0.6 } do
					if dist(d, yy, side, s, rpAll) < dist(d, yy, side, s, rpRock) - 0.05 then
						clear = false
					end
				end
			end
			if clear then
				local reach = math.min(dist(d, y, side, 0, rpRock) - r + 0.4, 12)
				K.lpart(F, c, "TieBack", V(-0.2, y - 0.2, -reach), V(0.2, y + 0.2, -0.75), colLk)
				K.lpart(
					F,
					c,
					"TiePlate",
					V(-0.55, y - 0.55, -reach - 0.2),
					V(0.55, y + 0.55, -reach),
					plateLk
				)
				K.lpart(
					F,
					c,
					"TieClamp",
					V(-0.35, y - 0.35, -0.95),
					V(0.35, y + 0.35, -0.75),
					plateLk
				)
				break
			end
		end
	end
end

-- 2. lighting truss between the lift towers (tower inner faces at x = +-18, centred z = -17)
local tr = K.model(steel, "LiftTruss")
local X0, X1, Y0, Y1, Z0, Z1 = -18, 18, 27, 29.4, -18.2, -15.8
local F = CFrame.new(K.O)
for _, y in { Y0, Y1 } do
	for _, z in { Z0, Z1 } do
		K.lpart(F, tr, "Chord", V(X0, y - 0.15, z - 0.15), V(X1, y + 0.15, z + 0.15), colLk)
	end
end
local n = 15
local step = (X1 - X0) / n
for i = 0, n do
	local x = X0 + i * step
	for _, z in { Z0, Z1 } do
		K.lpart(F, tr, "Post", V(x - 0.08, Y0, z - 0.08), V(x + 0.08, Y1, z + 0.08), plateLk)
	end
	for _, y in { Y0, Y1 } do
		K.lpart(F, tr, "Rung", V(x - 0.08, y - 0.08, Z0), V(x + 0.08, y + 0.08, Z1), plateLk)
	end
	if i < n then
		local sgn = if i % 2 == 0 then 1 else -1
		for _, z in { Z0, Z1 } do -- diagonals on the two long faces
			local Fz = F * CFrame.new(0, 0, z)
			S.bar(
				Fz,
				tr,
				"Diagonal",
				V(x, if sgn > 0 then Y0 else Y1, 0),
				V(x + step, if sgn > 0 then Y1 else Y0, 0),
				0.12,
				-0.06,
				0.06,
				plateLk
			)
		end
	end
end
for _, x in { X0, X1 } do
	local sx = if x < 0 then -1 else 1
	K.lpart(
		F,
		tr,
		"EndPlate",
		V(x - 0.1 * sx, Y0 - 0.6, Z0 - 0.6),
		V(x + 0.15 * sx, Y1 + 0.6, Z1 + 0.6),
		plateLk
	)
end
for _, x in { -13.5, -4.5, 4.5, 13.5 } do
	local l = K.model(tr, "SpotLamp")
	K.lpart(F, l, "Hanger", V(x - 0.1, Y0 - 1.0, -17.1), V(x + 0.1, Y0 - 0.15, -16.9), K.L.dark)
	local body = K.lpart(
		F,
		l,
		"Body",
		V(x - 0.55, Y0 - 1.9, -17.55),
		V(x + 0.55, Y0 - 1.0, -16.45),
		K.L.dark
	)
	K.ghost(
		K.lpart(
			F,
			l,
			"Lens",
			V(x - 0.42, Y0 - 1.98, -17.42),
			V(x + 0.42, Y0 - 1.9, -16.58),
			K.L.white
		)
	)
	K.spot(l, body, Enum.NormalId.Bottom, K.WARM, 1.0, 34, 55)
end
return "hub steel built"
