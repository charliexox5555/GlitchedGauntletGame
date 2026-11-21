--!nocheck
-- Lobby V5 OVERLAP + GLITCH PASS (vault/02 Art/Lobby V5 Plan.md, "Overlap and glitch pass"). ONE-TIME record of the
-- in-place fixes made 2026-11-21 after the owner asked for "your overlapping glitch parts check". Found by three
-- scans over Workspace.LobbyV5.Shell: GetPartsInPart between areas, a coplanar-face scan (axis-aligned blocks whose
-- faces share a plane, overlap in area and differ in look = flicker), and per-area audits. Each fix is idempotent
-- (an attribute marks it). The build scripts were updated to match, so a rebuild comes out fixed too.
-- Not here: the Locker's two west wainscot slopes (turned the wrong way, 6 studs through the wall into the
-- vestibule) are rebuilt by BuildLockerArmory.luau.

local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local V = Vector3.new
local shell = workspace.LobbyV5.Shell
local F = K.frame(V(-40, 0, 0), V(1, 0, 0))
local function trim(p, axis, amount, keepSign) -- shorten along a local axis, keeping one face where it is
	local d =
		V(axis == "X" and amount or 0, axis == "Y" and amount or 0, axis == "Z" and amount or 0)
	p.Size -= d
	p.CFrame = p.CFrame * CFrame.new(d * 0.5 * keepSign)
end

-- Duels tunnel: its entry step was buried in the hub floor slab (a bare 1-stud ledge); out to the slab edge
local st = shell.Duels.Tunnel.Step
if not st:GetAttribute("MovedOutOfSlab") then
	st.CFrame += V(0, 0, -2)
	st:SetAttribute("MovedOutOfSlab", true)
end

-- Shop bar lamps: caps a touch wider and prouder than the rails (their outer faces were shared)
for _, d in shell.Shop:GetDescendants() do
	if
		d:IsA("BasePart")
		and (d.Name == "CapTop" or d.Name == "CapBottom")
		and not d:GetAttribute("Fixed")
	then
		d.Size += V(0.06, 0, 0.04)
		d.CFrame *= CFrame.new(0, 0, 0.02)
		d:SetAttribute("Fixed", true)
	end
end

-- Shop hall walls: span pieces stop 0.1 short of the bay openings (the bay sides own that face)
local edges = { -19, -35, -41, -57 }
for _, wn in { "Wall_L", "Wall_R" } do
	for _, p in shell.Shop.Hall[wn]:GetChildren() do
		if
			p:IsA("BasePart")
			and (p.Name == "Body" or p.Name == "Wainscot" or p.Name == "WainscotCap")
			and not p:GetAttribute("Fixed")
		then
			local lp = F:PointToObjectSpace(p.Position)
			local xw = F:VectorToObjectSpace(p.CFrame.RightVector)
			local z0, z1 = lp.Z - p.Size.X / 2, lp.Z + p.Size.X / 2
			for _, e in edges do
				if math.abs(z0 - e) < 0.01 then
					trim(p, "X", 0.1, xw.Z > 0 and 1 or -1)
				end
				if math.abs(z1 - e) < 0.01 then
					trim(p, "X", 0.1, xw.Z > 0 and -1 or 1)
				end
			end
			p:SetAttribute("Fixed", true)
		end
	end
end
-- Shop bays: jambs 8 .. 9.6 and the head ±9.6 cover the drape walls' front edges
for _, bay in shell.Shop.Bays:GetChildren() do
	for _, p in bay:GetChildren() do
		if p:IsA("BasePart") and not p:GetAttribute("Widened") then
			if p.Name == "Jamb" then
				local rel = p.CFrame:PointToObjectSpace(bay.Floor.Position)
				p.Size += V(0.6, 0, 0)
				p.CFrame *= CFrame.new(0.3 * (rel.X > 0 and -1 or 1), 0, 0)
				p:SetAttribute("Widened", true)
			elseif p.Name == "Head" then
				p.Size += V(1.2, 0, 0)
				p:SetAttribute("Widened", true)
			end
		end
	end
end
-- Shop portal: the front wall's wainscot stops behind the casing jambs (|x| 11), not at the opening edge
for _, p in shell.Shop.Hall.Wall_Front:GetChildren() do
	if
		p:IsA("BasePart")
		and (p.Name == "Wainscot" or p.Name == "WainscotCap")
		and not p:GetAttribute("Fixed")
	then
		local lp = F:PointToObjectSpace(p.Position)
		local xw = F:VectorToObjectSpace(p.CFrame.RightVector)
		for _, e in { -10, 10 } do
			for _, endX in { lp.X - p.Size.X / 2, lp.X + p.Size.X / 2 } do
				if math.abs(endX - e) < 0.01 then
					local localPlus = (xw.X > 0) == (endX > lp.X)
					trim(p, "X", 1, localPlus and -1 or 1)
				end
			end
		end
		p:SetAttribute("Fixed", true)
	end
end
-- Shop hall ceiling, coffer cheeks and top end 0.1 short of the junction's header face
for _, p in shell.Shop.Hall:GetChildren() do
	if
		p:IsA("BasePart")
		and (p.Name == "Ceiling" or p.Name == "CofferCheek" or p.Name == "CofferTop")
		and not p:GetAttribute("Fixed")
	then
		local zl = F:VectorToObjectSpace(p.CFrame.LookVector)
		trim(p, "Z", 0.1, zl.Z < 0 and 1 or -1)
		p:SetAttribute("Fixed", true)
	end
end
-- I-beam webs stop inside their end plates (their end faces were shared)
for _, b in shell.Shop:GetDescendants() do
	if
		b:IsA("Model")
		and b.Name == "Beam"
		and b:FindFirstChild("Web")
		and not b.Web:GetAttribute("Fixed")
	then
		b.Web.Size -= V(0.4, 0, 0)
		b.Web:SetAttribute("Fixed", true)
	end
end
-- Locker consoles: the hood lip hangs under the hood instead of through it
for _, c in shell.Locker.Armory:GetChildren() do
	local lip = c:FindFirstChild("HoodLip")
	if lip and not lip:GetAttribute("Fixed") then
		trim(lip, "Y", 0.22, -1)
		lip:SetAttribute("Fixed", true)
	end
end
-- Range bay: the wainscot face sits just behind the column webs it was flush with
for _, p in shell.Hub.RangeBay.SimBay:GetChildren() do
	if p:IsA("BasePart") and p.Name == "Wainscot" and not p:GetAttribute("Fixed") then
		local hi = p.Position.X + p.Size.X / 2 - K.O.X
		if math.abs(hi + 11.5) < 0.01 and math.abs(p.CFrame.RightVector.X) > 0.99 then
			trim(p, "X", 0.04, p.CFrame.RightVector.X > 0 and -1 or 1)
			p:SetAttribute("Fixed", true)
		end
	end
end
-- v3 signs: the corner bolts that sat on the accent tile go (LobbyWay now puts them clear of it)
for _, m in workspace.LobbyV5:GetDescendants() do
	if m:IsA("Model") and m:FindFirstChild("WordFace") and m:FindFirstChild("Tile") then
		for _, p in m:GetChildren() do
			if
				p.Name == "Bolt"
				and math.abs(m.Tile.CFrame:PointToObjectSpace(p.Position).X)
					< m.Tile.Size.X / 2 + 0.2
			then
				p:Destroy()
			end
		end
	end
end
return "glitch fixes applied"
