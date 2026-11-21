--!nocheck
-- Lobby V5 SIGNS v3 everywhere else (vault/02 Art/Lobby V5 Plan.md, "Signs v3"). ONE-TIME placement record (needs
-- V5Kit.LobbyKit + LobbyWay). Owner 2026-11-21: the v2 signs "don't fit our vibe, and we need to make something new.
-- Same with the 1v1, 2v2, 3v3 signs." Replaces the last v2 signs with the facility wayfinding sign (LobbyWay.sign):
-- * DUELS and LOCKER: on the gateway header face on stand-offs, lit by goosenecks; their outriggers go;
-- * RANGE: standing on the bay girder on two posts (the tilted posts, clamps and feet go);
-- * the 8 queue bays: the mode as the word ("1V1"), "DUELS · 2 PLAYERS" under it, hung from the gantry runway beam,
--   with a status strip below. MatchLift's contract is kept: the bay's `Sign` model has a direct child `Face` whose
--   SurfaceGui's first Frame (flashed gold) holds a right-aligned TextLabel (set to MATCH FOUND).

local SS = game:GetService("ServerStorage")
local W = require(SS.V5Kit.LobbyWay:Clone())
local K = W.K
local V = Vector3.new
local L = K.L
local shell = workspace.LobbyV5.Shell
local gates = shell.Hub.Gateways
local INK = Color3.fromRGB(18, 19, 22)

-- 1. GATEWAYS --------------------------------------------------------------------------------------------------------
local GATES = {
	{
		name = "Duels",
		F = K.frame(V(0, 0, -42), V(0, 0, 1)),
		top = 25.0,
		h = 5.0,
		area = K.AREA.duels,
		word = "DUELS",
		sub = "1V1  ·  2V2  ·  3V3",
		code = "ZONE D-01",
	},
	{
		name = "Locker",
		F = K.frame(V(40, 0, 0), V(-1, 0, 0)),
		top = 18.7,
		h = 3.8,
		area = K.AREA.locker,
		word = "LOCKER",
		sub = "LOADOUT  ·  SKINS",
		code = "ZONE L-02",
	},
}
for _, g in GATES do
	local gate = gates["Gateway_" .. g.name]
	for _, c in gate:GetChildren() do
		if c.Name:match("^Sign_") then
			c:Destroy()
		end
	end
	if gate:FindFirstChild("Steel") then
		for _, c in gate.Steel:GetChildren() do
			if c.Name == "Outrigger" then
				c:Destroy()
			end
		end
	end
	W.sign(g.F * CFrame.new(0, g.top, 1.7), gate, {
		name = "Sign_" .. string.upper(g.name),
		word = g.word,
		sub = g.sub,
		code = g.code,
		icon = g.area.icon,
		col = g.area.col,
		h = g.h,
		mount = "wall",
		standoff = 1.7,
		lamps = true,
	})
end

-- 2. RANGE: standing on the bay girder (top y 19.6, z 0 .. 1.1 in the bay frame) -----------------------------------
do
	local bay = shell.Hub.RangeBay
	local F = K.frame(V(0, 0, 42), V(0, 0, -1))
	for _, c in bay:GetChildren() do
		if
			c.Name:match("^Sign_")
			or c.Name == "SignPost"
			or c.Name == "PostClamp"
			or c.Name == "PostFoot"
		then
			c:Destroy()
		end
	end
	W.sign(F * CFrame.new(0, 19.6 + 0.4 + 0.8 + 4.6, 0.95), bay, {
		name = "Sign_RANGE",
		word = "RANGE",
		sub = "SIMULATION BAY  ·  LIVE FIRE",
		code = "ZONE R-04",
		icon = K.AREA.range.icon,
		col = K.AREA.range.col,
		h = 4.6,
		mount = "stand",
		stand = 0.8,
		lamps = true,
	})
end

-- 3. QUEUE BAYS ------------------------------------------------------------------------------------------------------
local DUELS = K.AREA.duels.col
local BEAM_Y = 26.1 -- underside of Duels.Gantry.Runway_F
local done = {}
for _, bay in shell.Duels.QueueBays:GetChildren() do
	local mode = bay.Name:match("_(%dv%d)$")
	if mode then
		local xs = {}
		for _, d in bay:GetDescendants() do
			if
				d:IsA("BasePart")
				and game:GetService("CollectionService"):HasTag(d, "LobbyPadSquare")
			then
				table.insert(xs, d.Position.X)
			end
		end
		local cx = 0
		for _, x in xs do
			cx += x / #xs
		end
		local old = bay:FindFirstChild("Sign")
		if old then
			old:Destroy()
		end
		local per = tonumber(mode:sub(1, 1)) * 2
		local hang = 2.2
		local Fh = K.frame(V(cx - K.O.X, BEAM_Y - hang, -97.8), V(0, 0, 1))
		local m, Wd, Fs = W.sign(Fh, bay, {
			name = "Sign",
			word = string.upper(mode),
			sub = ("DUELS  ·  %d PLAYERS"):format(per),
			icon = K.AREA.duels.icon,
			col = DUELS,
			h = 2.8,
			tilt = 12,
			mount = "hang",
			hang = hang,
		})
		-- the status strip: a cut plate hung under the sign on two links; its face carries the MatchLift contract
		local sw, sh = Wd * 0.74, 0.8
		local Fst = Fs * CFrame.new(0, -1.4 - 0.45 - sh / 2, 0)
		W.cutPlate(Fst, m, "StripPlate", sw, sh, 0.25, -0.35, 0, L.plate)
		for _, x in { -sw * 0.35, sw * 0.35 } do
			K.lpart(
				Fs,
				m,
				"Link",
				V(x - 0.06, -1.4 - 0.47, -0.24),
				V(x + 0.06, -1.4 + 0.05, -0.12),
				L.steel
			)
		end
		local face = K.part(
			m,
			"Face",
			V(sw - 0.3, sh - 0.16, 0.02),
			Fst * CFrame.new(0, 0, 0.02) * CFrame.Angles(0, math.pi, 0),
			K.paint(Color3.new(0, 0, 0))
		)
		face.Transparency = 1
		K.ghost(face)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Brightness = 1.1
		gui.Parent = face
		local bg = Instance.new("Frame")
		bg.Name = "Strip"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = K.dim(DUELS, 0.12)
		bg.Parent = gui
		local chev = Instance.new("TextLabel")
		chev.BackgroundTransparency = 1
		chev.Size = UDim2.new(0.2, 0, 1, 0)
		chev.Position = UDim2.fromOffset(8, 0)
		chev.FontFace = K.RUBIK_H
		chev.TextSize = math.floor((sh - 0.16) * 40 * 0.7)
		chev.Text = "»"
		chev.TextColor3 = INK
		chev.TextXAlignment = Enum.TextXAlignment.Left
		chev.Parent = bg
		local t = Instance.new("TextLabel")
		t.Name = "Status"
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -10, 1, 0)
		t.FontFace = K.RUBIK_B
		t.TextSize = math.floor((sh - 0.16) * 40 * 0.55)
		t.Text = "STEP IN TO QUEUE"
		t.TextColor3 = INK
		t.TextXAlignment = Enum.TextXAlignment.Right
		t.Parent = bg
		-- the pad light under the sign
		local pl = K.ghost(
			K.part(
				m,
				"PadLight",
				V(1, 0.2, 1),
				CFrame.new((Fst * V(0, -0.7, 0))),
				K.paint(Color3.new(0, 0, 0))
			)
		)
		pl.Transparency = 1
		K.spot(m, pl, Enum.NormalId.Bottom, Color3.fromRGB(255, 236, 214), 1.4, 22, 70)
		table.insert(done, bay.Name)
	end
end
return "signs v3: gateways, range, " .. #done .. " bays"
