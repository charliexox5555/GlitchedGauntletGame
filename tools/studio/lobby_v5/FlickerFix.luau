--!nocheck
-- Coplanar-face (z-fighting) scan and fix for Lobby V5 (2026-11-21 hub 9/10 pass; the owner saw "a bunch of glitching
-- parts" in the shop). Run in the Lobby place (Edit) through the Studio MCP:
--   local FF = <this module>; FF.fix(workspace.LobbyV5.Shell.Shop)  -> { before, after per pass }
-- scan(root): every pair of block Parts whose faces share a plane, point the same way, overlap by more than 0.02 and
-- differ in colour or material, where a ray from 0.4 in front reaches one of them (so the pair can show). Wedges,
-- meshes and faces nobody can see (tops of downlights in the ceiling, bottoms on the floor) are not reported.
-- fix(root): steps the smaller part of each pair back along that face (0.02 for big parts, 0.035 mid, 0.05 small,
-- +0.01 per pass so two trims that moved together separate), up to four passes. Results 2026-11-21: Shop 112 -> 4,
-- Hub 112 -> 4, Duels 94 -> 0, Locker 12 -> 2, Range 20 -> 12 (all left are hidden bottoms or downlight tops).

local M = {}

function M.scan(root)
	local buckets = {}
	local function q(v, s)
		return math.floor(v / s + 0.5)
	end
	for _, p in root:GetDescendants() do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 1 then
			local cf, s = p.CFrame, p.Size / 2
			local axes = {
				{ cf.RightVector, s.X, cf.UpVector, s.Y, cf.LookVector, s.Z },
				{ cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z },
				{ cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y },
			}
			for _, a in axes do
				for _, sg in { 1, -1 } do
					local n = a[1] * sg
					local c = cf.Position + n * a[2]
					local key = q(n.X, 0.02) .. "," .. q(n.Y, 0.02) .. "," .. q(n.Z, 0.02) .. "|" .. q(n:Dot(c), 0.02)
					buckets[key] = buckets[key] or {}
					table.insert(buckets[key], { p = p, n = n, c = c, u = a[3], hu = a[4], v = a[5], hv = a[6] })
				end
			end
		end
	end
	local rp = RaycastParams.new()
	local out = {}
	for _, list in buckets do
		if #list > 1 and #list < 200 then
			for i = 1, #list do
				for j = i + 1, #list do
					local A, B = list[i], list[j]
					if A.p ~= B.p and not (A.p.Color == B.p.Color and A.p.Material == B.p.Material) then
						local uu, vv
						if math.abs(A.u:Dot(B.u)) > 0.999 then
							uu, vv = B.hu, B.hv
						elseif math.abs(A.u:Dot(B.v)) > 0.999 then
							uu, vv = B.hv, B.hu
						end
						if uu then
							local off = B.c - A.c
							local ox, oy = off:Dot(A.u), off:Dot(A.v)
							local x0, x1 = math.max(-A.hu, ox - uu), math.min(A.hu, ox + uu)
							local y0, y1 = math.max(-A.hv, oy - vv), math.min(A.hv, oy + vv)
							if x1 - x0 > 0.02 and y1 - y0 > 0.02 then
								local exposed = 0
								for _, t in { { 0.5, 0.5 }, { 0.15, 0.15 }, { 0.85, 0.85 }, { 0.15, 0.85 }, { 0.85, 0.15 } } do
									local P = A.c + A.u * (x0 + (x1 - x0) * t[1]) + A.v * (y0 + (y1 - y0) * t[2])
									local r = workspace:Raycast(P + A.n * 0.4, -A.n * 0.45, rp)
									if r and (r.Instance == A.p or r.Instance == B.p) and r.Distance > 0.38 then
										exposed += 1
									end
								end
								if exposed > 0 and A.p.Name ~= "Top" and B.p.Name ~= "Top" then
									table.insert(out, { A.p, B.p, A.n })
								end
							end
						end
					end
				end
			end
		end
	end
	return out
end

local function vol(p)
	return p.Size.X * p.Size.Y * p.Size.Z
end
local function step(p)
	local v = vol(p)
	return if v > 200 then 0.02 elseif v > 20 then 0.035 else 0.05
end
local function shrink(p, nrm, d)
	local cf = p.CFrame
	for _, a in { { cf.RightVector, "X" }, { cf.UpVector, "Y" }, { cf.LookVector, "Z" } } do
		if math.abs(a[1]:Dot(nrm)) > 0.999 then
			local s = p.Size
			if s[a[2]] <= d * 3 then
				return false
			end
			p.Size = Vector3.new(
				a[2] == "X" and s.X - d or s.X,
				a[2] == "Y" and s.Y - d or s.Y,
				a[2] == "Z" and s.Z - d or s.Z
			)
			p.CFrame = cf - nrm * (d / 2)
			return true
		end
	end
	return false
end

function M.fix(root)
	local log = {}
	for it = 1, 4 do
		local r = M.scan(root)
		table.insert(log, #r)
		if #r == 0 then
			break
		end
		local done = {}
		for _, e in r do
			local A, B, nrm = e[1], e[2], e[3]
			local p = vol(A) < vol(B) and A or B
			if not done[p] then
				done[p] = true
				if not shrink(p, nrm, step(p) + 0.01 * (it - 1)) then
					local o = if p == A then B else A
					if not done[o] then
						done[o] = true
						shrink(o, nrm, step(o))
					end
				end
			end
		end
		task.wait()
	end
	return log
end

return M
