--!nocheck
-- Lobby V5 SIGNS v2 (vault/02 Art/Lobby V5 Plan.md, "Character pass"). ONE-TIME placement record run through the
-- Studio MCP after LobbySigns.luau is installed as ServerStorage.V5Kit.LobbySigns. Owner 2026-11-20: the badges "look
-- too generic ... not much character"; "I like the signs more in our V4 lobby, but ... not copy them".
-- Replaces the badges with hanging layered signs (medallion + 3D emblem, extruded letters, sub-tag) and adds the
-- entrance steel (outriggers, braces, capitals, kick plates, gate ID, caution plate, status lamp, conduit, floor
-- chevrons) to the Duels, Locker and Shop gateways; signs inside the Shop (MARKET, BATTLE PASS) and the Locker.
-- Removes the locker's painted floor emblem. The Range gets its own bay (BuildRangeBay.luau).

local S = require(game:GetService("ServerStorage").V5Kit.LobbySigns:Clone())
local K = S.K
local V = Vector3.new
local Shell = workspace.LobbyV5.Shell
local gates = Shell.Hub.Gateways

local function clear(model, patterns)
	for _, c in model:GetChildren() do
		for _, p in patterns do
			if string.match(c.Name, p) then
				c:Destroy()
				break
			end
		end
	end
end

local GATES = {
	{
		name = "Duels",
		F = K.frame(V(0, 0, -42), V(0, 0, 1)),
		W = 34,
		H = 18,
		P = 7,
		T = 26,
		crown = 2,
		area = K.AREA.duels,
		word = "DUELS",
		sub = "1V1  ·  2V2  ·  3V3",
		emblem = "versus",
		signH = 5.2,
		gateId = "GATE D-01",
		caution = {
			{ text = "CAUTION", size = 34, heavy = true },
			{ text = "FIGHTERS", size = 22 },
			{ text = "ONLY", size = 22 },
		},
	},
	{
		name = "Locker",
		F = K.frame(V(40, 0, 0), V(-1, 0, 0)),
		W = 14,
		H = 13,
		P = 6,
		T = 20,
		crown = 2,
		area = K.AREA.locker,
		word = "LOCKER",
		sub = "LOADOUT  ·  SKINS",
		emblem = "padlock",
		signH = 4.0,
		gateId = "GATE L-02",
		caution = {
			{ text = "NOTICE", size = 34, heavy = true },
			{ text = "GEAR UP", size = 22 },
			{ text = "BEFORE DUELS", size = 18 },
		},
	},
	{
		name = "Shop",
		F = K.frame(V(-40, 0, 0), V(1, 0, 0)),
		W = 14,
		H = 12.5,
		P = 4,
		T = 18,
		crown = 3,
		area = K.AREA.shop,
		word = "SHOP",
		sub = "ITEMS  ·  BATTLE PASS",
		emblem = "bag",
		signH = 4.2,
		gateId = "S-03",
		caution = {
			{ text = "NOTICE", size = 30, heavy = true },
			{ text = "NO", size = 20 },
			{ text = "REFUNDS", size = 20 },
		},
	},
}
for _, g in GATES do
	local gate = gates["Gateway_" .. g.name]
	clear(gate, { "^Badge_", "^WashLamp$", "^Steel$", "^Sign_" })
	S.gatewaySteel(g.F, gate, g)
end
-- the Duels portal's buttresses stand where its conduit would run
for _, n in { "Conduit", "JunctionBox" } do
	local c = gates.Gateway_Duels.Steel:FindFirstChild(n)
	if c then
		c:Destroy()
	end
end

-- the rock walls beside the Duels portal stand in front of its outer 2 studs (raycast scan): trim every frame piece
-- past |x| = 21.3 back to it (pieces wholly past it go), move the two plates inward
do
	local g = gates.Gateway_Duels
	local F = K.frame(V(0, 0, -42), V(0, 0, 1))
	local CLIP, right = 21.3, F.RightVector
	local function span(p)
		local cf, s = p.CFrame, p.Size
		local hx = math.abs(cf.RightVector:Dot(right)) * s.X / 2
			+ math.abs(cf.UpVector:Dot(right)) * s.Y / 2
			+ math.abs(cf.LookVector:Dot(right)) * s.Z / 2
		local cx = F:PointToObjectSpace(cf.Position).X
		return cx - hx, cx + hx
	end
	local function cutAlongX(p, newLen, shift)
		local cf = p.CFrame
		for _, ax in { { "X", cf.RightVector }, { "Y", cf.UpVector }, { "Z", cf.LookVector } } do
			if math.abs(ax[2]:Dot(right)) > 0.99 then
				local s = p.Size
				p.Size = V(
					if ax[1] == "X" then newLen(s.X) else s.X,
					if ax[1] == "Y" then newLen(s.Y) else s.Y,
					if ax[1] == "Z" then newLen(s.Z) else s.Z
				)
				p.CFrame = cf + right * shift
				return
			end
		end
	end
	for _, d in g:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Transparency < 1
			and not d:FindFirstAncestor("Sign_DUELS")
			and d.Parent
		then
			local lo, hi = span(d)
			if lo < -CLIP - 0.01 and hi > CLIP + 0.01 then
				local cx = F:PointToObjectSpace(d.Position).X
				cutAlongX(d, function()
					return 2 * CLIP
				end, -cx)
			else
				for _, sd in { 1, -1 } do
					local a, b = if sd > 0 then lo else -hi, if sd > 0 then hi else -lo
					if b > CLIP + 0.01 then
						if a >= CLIP - 0.05 then
							d:Destroy()
						elseif a > 0 then
							local cut = b - CLIP
							cutAlongX(d, function(l)
								return l - cut
							end, -sd * cut / 2)
						end
						break
					end
				end
			end
		end
	end
	for _, n in { "Caution", "GateId" } do
		local m = g.Steel:FindFirstChild(n)
		if m then
			local piv = m:GetPivot()
			local cx = F:PointToObjectSpace(piv.Position).X
			m:PivotTo(piv - right * (cx - math.sign(cx) * 19.4))
		end
	end
end

-- the season screen over the Duels gateway goes up, clear of the sign's outriggers
local scr = Shell.Hub.Dressing.Screens:FindFirstChild("Screen_N")
if scr and not scr:GetAttribute("RaisedForSign") then
	scr:PivotTo(scr:GetPivot() + V(0, 5, 0))
	scr:SetAttribute("RaisedForSign", true)
end

-- SHOP: MARKET hangs from the ceiling over the slat wall, BATTLE PASS sits on its panel
local shop = Shell.Shop
local SF = K.frame(V(-40, 0, 0), V(1, 0, 0))
clear(shop.SlatWall, { "^Badge_", "^Sign_" })
S.sign(
	SF * CFrame.new(0, 17.2, -58.8),
	shop.SlatWall, -- clear of the soffit band
	{
		word = "MARKET",
		sub = "OPEN NOW",
		col = K.AREA.shop.col,
		emblem = "bag",
		h = 3.4,
		hang = 0.8,
		tilt = 8,
	}
)
clear(shop.BattlePass, { "^Badge_", "^Sign_" })
local FB = SF * CFrame.new(22, 0, -37) * CFrame.Angles(0, math.rad(-90), 0)
S.sign(FB * CFrame.new(0.75, 13.3, 0.8), shop.BattlePass, {
	word = "BATTLE PASS",
	sub = "SEASON 1",
	col = K.AREA.pass.col,
	emblem = "rank",
	h = 3.4,
	hang = 0,
	tilt = 0,
})

-- LOCKER: the sign hangs from the ceiling in front of the gun wall's soffit; the painted floor emblem goes
local locker = Shell.Locker
clear(locker.GunWall, { "^Badge_", "^Sign_" })
-- hung low enough that its medallion clears the I-beam at x 98
S.sign(K.frame(V(99.0, 16.6, 0), V(-1, 0, 0)), locker.GunWall, {
	word = "LOCKER",
	sub = "LOADOUT  ·  SKINS",
	col = K.AREA.locker.col,
	emblem = "padlock",
	h = 2.8,
	hang = 1.4,
	tilt = 8,
})
local pol = locker:FindFirstChild("Polish")
local em = pol and pol:FindFirstChild("FloorEmblem")
if em then
	em:Destroy()
end
return "signs built"
