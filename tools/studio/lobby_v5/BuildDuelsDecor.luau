--!nocheck
-- Lobby V5 DUELS DECOR (vault/02 Art/Lobby V5 Plan.md, "Duels decor"). ONE-TIME placement record (needs
-- V5Kit.LobbyKit + LobbyWay). Owner 2026-11-21: improve the decor "including the dual section". RIVALS puts a pier
-- with a lamp between every pair of pads and TVs where players wait; ours, on the deck (top y -1.0, z -60 .. -97):
-- * BOLLARD LAMPS along the chasm edge, one in every gap between the queue bays and one at each end (base plate,
--   octagonal post, head with a lit band, a stepped cap, a SpotLight pooling on the deck);
-- * four HOW-TO-PLAY boards on the bulkhead panels (bays 3, 4, 8, 9), each lit by an arm lamp. Facts only from the
--   design notes: a Mod draft every round, every round opens a weapon tier, headshots 1.5x, step on a pad to queue;
-- * two BENCHES for waiting players in front of bulkhead bays 2 and 10.

local SS = game:GetService("ServerStorage")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local D = workspace.LobbyV5.Shell.Duels
local DUELS = K.AREA.duels
local DECK = -1.0
local old = D:FindFirstChild("Decor")
if old then
	old:Destroy()
end
local decor = K.model(D, "Decor")
local function box(Fb, parent, name, a, b, lk)
	return K.lpart(Fb, parent, name, a, b, lk)
end

-- bollards
for _, x in { -104, -78, -52, -26, 0, 26, 52, 78, 104 } do
	local Fb = K.frame(V(x, DECK, -94.6), V(0, 0, 1))
	local m = K.model(decor, "Bollard")
	box(Fb, m, "BasePlate", V(-0.45, 0, -0.45), V(0.45, 0.1, 0.45), L.steel)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				Fb,
				m,
				"Bolt",
				V(sx * 0.32 - 0.06, 0.1, sz * 0.32 - 0.06),
				V(sx * 0.32 + 0.06, 0.16, sz * 0.32 + 0.06),
				L.dark
			)
		end
	end
	K.pipe(m, "Post", (Fb * V(0, 0.1, 0)) - K.O, (Fb * V(0, 2.5, 0)) - K.O, 0.42, L.dark)
	box(Fb, m, "Head", V(-0.42, 2.5, -0.42), V(0.42, 3.0, 0.42), L.dark)
	for _, sz in { -1, 1 } do
		K.ghost(
			box(
				Fb,
				m,
				"Band",
				V(-0.3, 2.56, sz * 0.42 - (sz > 0 and 0 or 0.03)),
				V(0.3, 2.74, sz * 0.42 + (sz > 0 and 0.03 or 0)),
				K.neon(Color3.fromRGB(156, 134, 102))
			)
		)
	end
	box(Fb, m, "Cap", V(-0.48, 3.0, -0.48), V(0.48, 3.1, 0.48), L.steel)
	box(Fb, m, "CapTop", V(-0.3, 3.1, -0.3), V(0.3, 3.18, 0.3), L.steel)
	local lp = K.ghost(
		box(Fb, m, "Light", V(-0.2, 2.46, -0.2), V(0.2, 2.5, 0.2), K.paint(Color3.new(0, 0, 0)))
	)
	lp.Transparency = 1
	K.spot(m, lp, Enum.NormalId.Bottom, K.WARM, 0.8, 9, 120)
end

-- how-to-play boards on the bulkhead panels (panel face at z -60.3, facing the deck)
local BOARDS = {
	{ x = -60, title = "THE DRAFT", sub = "PICK A MOD EVERY ROUND" },
	{ x = -44, title = "WEAPON TIERS", sub = "EVERY ROUND OPENS A NEW TIER" },
	{ x = 44, title = "HEADSHOTS", sub = "1.5× DAMAGE  ·  AIM HIGH" },
	{ x = 60, title = "QUEUE UP", sub = "STEP ONTO A PAD TO JOIN" },
}
for _, b in BOARDS do
	local Fw = K.frame(V(b.x, DECK, -60.3), V(0, 0, -1))
	local m = K.model(decor, "Board_" .. b.title:gsub("%s", ""))
	box(Fw, m, "Bezel", V(-4.4, 6.4, 0), V(4.4, 11.6, 0.3), L.dark)
	local scr = box(Fw, m, "Screen", V(-4.1, 6.7, 0.3), V(4.1, 11.3, 0.36), L.plate)
	scr.CastShadow = false
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0
	g.Brightness = 1.1
	g.Parent = scr
	W.board(
		g,
		{
			title = b.title,
			sub = b.sub,
			foot = "DUELS  ·  HOW TO PLAY",
			col = DUELS.col,
			icon = DUELS.icon,
			px = scr.Size.Y * 30,
		}
	)
	local lamp = box(Fw, m, "Lamp", V(-1.3, 12.1, 0.3), V(1.3, 12.5, 1.5), L.dark)
	box(Fw, m, "LampArm", V(-0.1, 12.15, 0), V(0.1, 12.35, 0.3), L.steel)
	K.spot(m, lamp, Enum.NormalId.Bottom, K.WARM, 0.9, 9, 90)
end

-- benches in front of bulkhead bays 2 and 10
local slatLk = K.paint(Color3.fromRGB(72, 74, 79))
for _, x in { -76, 76 } do
	local Fb = K.frame(V(x, DECK, -62.2), V(0, 0, -1))
	local m = K.model(decor, "Bench")
	for _, bx in { -2.4, 2.4 } do
		for _, z in { -0.55, 0.55 } do
			box(Fb, m, "Leg", V(bx - 0.09, 0.06, z - 0.09), V(bx + 0.09, 1.35, z + 0.09), L.steel)
		end
		box(Fb, m, "Foot", V(bx - 0.25, 0, -0.78), V(bx + 0.25, 0.06, 0.78), L.dark)
		box(Fb, m, "Rail", V(bx - 0.12, 1.35, -0.75), V(bx + 0.12, 1.5, 0.75), L.dark)
		box(Fb, m, "Brace", V(bx - 0.06, 0.45, -0.55), V(bx + 0.06, 0.57, 0.55), L.steel)
	end
	box(Fb, m, "Stretcher", V(-2.4, 0.45, -0.06), V(2.4, 0.57, 0.06), L.steel)
	for i = -1, 1 do
		box(Fb, m, "Slat", V(-3, 1.5, i * 0.52 - 0.22), V(3, 1.64, i * 0.52 + 0.22), slatLk)
	end
	for _, sx in { -1, 1 } do
		box(Fb, m, "EndCap", V(sx * 3, 1.45, -0.8), V(sx * 3.08, 1.7, 0.8), L.steel)
	end
end

local op = OverlapParams.new()
op.RespectCanCollide = false
local hits = {}
for _, p in decor:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 0.9 then
		for _, q in workspace:GetPartsInPart(p, op) do
			if not q:IsDescendantOf(decor) and q.Transparency < 0.9 then
				hits[p.Parent.Name .. "." .. p.Name .. " x " .. q:GetFullName():gsub(
					"Workspace.LobbyV5.Shell.",
					""
				)] =
					true
			end
		end
	end
end
local out = {}
for k in hits do
	table.insert(out, k)
end
return "duels decor; hits:\n" .. table.concat(out, "\n")
