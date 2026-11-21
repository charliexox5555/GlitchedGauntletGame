--!nocheck
-- Lobby V5 ENTRANCES (vault/02 Art/Lobby V5 Plan.md, "Entrances and the shop"). ONE-TIME placement record run
-- through the Studio MCP after LobbyKit.luau is installed as ServerStorage.V5Kit.LobbyKit. Owner 2026-11-20: the
-- entrances "need to look better ... like Rivals and have different logos ... not as neon-y ... extravagant".
-- Replaces the plain jamb-and-lintel frames and the flat signs of the Duels portal, the Locker frame, the Range door
-- and the old Shop counter with one gateway design (K.gateway): proud pilasters, a cornice, soft accent light lines,
-- a lit reveal ring and each area's badge (HUD icon + word + subtitle, the HUD colour). BuildShop.luau then builds
-- the walk-in shop behind the west gateway.

local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local V = Vector3.new
local hub = workspace.LobbyV5.Shell.Hub

local function drop(parent, names)
	for _, n in names do
		local c = parent and parent:FindFirstChild(n)
		while c do
			c:Destroy()
			c = parent:FindFirstChild(n)
		end
	end
end
-- the old frames (keep the duels buttresses, the range shutter and its back), the old shop and the old signs
drop(hub.Portal_Duels, { "Pillar_W", "Pillar_E", "Lintel", "Cut_W", "Cut_E", "Threshold" })
drop(hub.Armoury, { "Jamb_N", "Jamb_S", "Lintel", "Cut_N", "Cut_S" })
drop(hub.RangeDoor, { "Jamb_W", "Jamb_E", "Lintel" })
drop(hub, { "Shop", "Gateways" })
drop(hub.Dressing, { "ShopFront" })
drop(hub.Dressing.Signs, { "Sign_Shop", "Sign_Duels", "Sign_Locker", "Sign_Range" })
for _, m in game:GetService("CollectionService"):GetTagged("SeasonMount") do
	if m:IsDescendantOf(workspace.LobbyV5) and m:GetAttribute("Slot") == "ShopWindow" then
		m:Destroy() -- rebuilt in the shop's window
	end
end
-- floor lane lines lead into each doorway (0.6 inside the opening), the Locker's continue inside at z +-6.4
local function setLine(p, a, b) -- hub-local corners at floor level, keep the thickness
	local lo, hi = a:Min(b), a:Max(b)
	p.Size = V(hi.X - lo.X, p.Size.Y, hi.Z - lo.Z)
	p.Position = K.O + V((lo.X + hi.X) / 2, p.Position.Y - K.O.Y, (lo.Z + hi.Z) / 2)
end
local lanes = { Line_E = {}, Line_W = {}, Line_S = {} }
for _, p in hub.Dressing.FloorMarks:GetChildren() do
	if lanes[p.Name] then
		table.insert(lanes[p.Name], p)
	end
end
for i, p in lanes.Line_E do
	local z = if i == 1 then -6.4 else 6.4
	setLine(p, V(21.5, 0, z - 0.2), V(39.6, 0, z + 0.2))
end
for i, p in lanes.Line_W do
	local z = if i == 1 then -6.4 else 6.4
	setLine(p, V(-39.6, 0, z - 0.2), V(-21.5, 0, z + 0.2))
end
for i, p in lanes.Line_S do
	local x = if i == 1 then -7.4 else 7.4
	setLine(p, V(x - 0.2, 0, 18.05), V(x + 0.2, 0, 41.6))
end
-- the range shutter becomes a ribbed roller door in guide rails
drop(hub.RangeDoor, { "Shutter" })
local shutter = K.model(hub.RangeDoor, "Shutter")
K.box(
	shutter,
	"Curtain",
	V(-8, 0, 44.95),
	V(8, 12, 45.45),
	K.look("Metal 2022", Color3.fromRGB(78, 80, 85))
)
for i = 0, 12 do
	local y = 0.95 + i * 0.85
	K.box(
		shutter,
		"Rib",
		V(-7.6, y, 44.85),
		V(7.6, y + 0.22, 44.95),
		K.look("Metal 2022", Color3.fromRGB(96, 98, 104))
	)
end
for _, sx in { -1, 1 } do
	K.box(shutter, "Rail", V(sx * 7.6, 0, 44.65), V(sx * 8.0, 12, 45.6), K.L.dark)
end

local gates = K.model(hub, "Gateways")
-- north: Duels (rock gap 42 wide, top 26; the buttresses stand 0.95 behind the face, so a thin fascia)
K.gateway(K.frame(V(0, 0, -42), V(0, 0, 1)), gates, {
	name = "Duels",
	W = 34,
	H = 18,
	P = 7,
	D = 8,
	T = 26,
	crown = 2,
	crownD = 0.9,
	cut = 4,
	area = K.AREA.duels,
	word = "DUELS",
	sub = "1V1  ·  2V2  ·  3V3",
	badgeH = 7.4,
	thY0 = -0.45,
	thY1 = 0.05,
})
-- east: Locker (gap 26, top 20; the vestibule behind is 14 wide)
K.gateway(K.frame(V(40, 0, 0), V(-1, 0, 0)), gates, {
	name = "Locker",
	W = 14,
	H = 13,
	P = 6,
	D = 6,
	T = 20,
	crown = 2,
	crownD = 1.5,
	cut = 2.5,
	area = K.AREA.locker,
	word = "LOCKER",
	sub = "LOADOUT  ·  SKINS",
	badgeH = 5.6,
	thY0 = 0,
	thY1 = 0.06,
})
-- south: Range (gap 30, top 18; still shuttered, the cuts stop in front of the shutter)
K.gateway(K.frame(V(0, 0, 42), V(0, 0, -1)), gates, {
	name = "Range",
	W = 16,
	H = 12,
	P = 5,
	D = 6,
	T = 18,
	crown = 2,
	crownD = 1.5,
	cut = 2.5,
	cutD = 2.6,
	area = K.AREA.range,
	word = "RANGE",
	sub = "COMING SOON",
	badgeH = 5.6,
	thY0 = 0,
	thY1 = 0.06,
})
-- west: Shop (gap 42, top 18.5; storefront wings and the room come from BuildShop.luau)
K.gateway(K.frame(V(-40, 0, 0), V(1, 0, 0)), gates, {
	name = "Shop",
	W = 14,
	H = 12.5,
	P = 4,
	D = 6,
	T = 18,
	crown = 3,
	crownD = 1.5,
	cut = 2.5,
	area = K.AREA.shop,
	word = "SHOP",
	sub = "ITEM SHOP  ·  BATTLE PASS",
	badgeH = 6.2,
	thY0 = 0,
	thY1 = 0.06,
})

for _, l in gates.Gateway_Range.Beam:GetDescendants() do
	if l:IsA("SpotLight") then
		l.Brightness = 0.7 -- softer on the shutter
	end
end

local n = 0
for _, d in gates:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("gateways built: %d pieces"):format(n)
