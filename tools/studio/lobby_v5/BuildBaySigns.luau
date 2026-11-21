--!nocheck
-- Lobby V5 QUEUE BAY SIGNS v2 (vault/02 Art/Lobby V5 Plan.md, "Character pass"). ONE-TIME placement record (needs
-- ServerStorage.V5Kit.LobbySigns). Owner 2026-11-20: "let's redo the bay signs". Each bay's lightbox becomes a
-- hanging sign in the v2 style: the mode word (1V1 / 2V2 / 3V3) in extruded letters, a medallion whose emblem is
-- two clashing chevrons in the team colours (gold A, cyan B), and a STEP IN TO QUEUE status strip. It hangs from
-- the same gantry beam as before, with a pad light under it.
-- Contract kept for Util/MatchLift (flashSign): the bay's `Sign` model has a direct child part `Face` whose
-- SurfaceGui's first Frame is the strip's background (flashed gold) holding a right-aligned TextLabel (the status,
-- set to MATCH FOUND).

local S = require(game:GetService("ServerStorage").V5Kit.LobbySigns:Clone())
local K = S.K
local V = Vector3.new
local bays = workspace.LobbyV5.Shell.Duels.QueueBays
local GOLD, CYAN = Color3.fromHex("FFB627"), Color3.fromHex("2EC8FF")
local DUELS = K.AREA.duels.col
local INK = Color3.fromRGB(18, 19, 22)

-- the team chevrons: gold points at cyan, a white spark between
S.EMBLEM.teams = function(F, m, u, t, _lk, _dark)
	for _, side in { { -1, GOLD }, { 1, CYAN } } do
		local sx, col = side[1], side[2]
		local lk = K.paint(col)
		local tip = V(sx * 0.17 * u, 0, 0)
		S.bar(F, m, "Chevron", tip + V(sx * 0.58 * u, 0.62 * u, 0), tip, 0.24 * u, 0, t, lk)
		S.bar(F, m, "Chevron", tip + V(sx * 0.58 * u, -0.62 * u, 0), tip, 0.24 * u, 0, t, lk)
	end
	K.part(
		m,
		"Spark",
		V(0.3 * u, 0.3 * u, t + 0.04),
		F * CFrame.new(0, 0, (t + 0.04) / 2) * CFrame.Angles(0, 0, math.rad(45)),
		K.paint(Color3.fromRGB(240, 238, 232))
	)
end

local BEAM_Y = 26.1 -- underside of the gantry runway beam (Duels.Gantry.Runway_F) the old signs hung from
local done = {}
for _, bay in bays:GetChildren() do
	local old = bay:FindFirstChild("Sign")
	if old then
		local mode
		for _, d in old:GetDescendants() do
			if d:IsA("TextLabel") and d.TextXAlignment == Enum.TextXAlignment.Left then
				mode = d.Text
			end
		end
		local face = old:FindFirstChild("Face")
		local cx = face.Position.X
		old:Destroy()
		local hang = 2.0
		local Fh = K.frame(V(cx - K.O.X, BEAM_Y - hang, -97.8), V(0, 0, 1)) -- rods land on the beam at z -98
		local sign = S.sign(Fh, bay, {
			name = "Sign",
			word = mode,
			sub = "STEP IN TO QUEUE",
			col = DUELS,
			emblem = "teams",
			h = 3.2,
			hang = hang,
			tilt = 14,
		})
		-- the status strip: the tag's text part becomes `Face` with an opaque background frame holding the status
		local tagText = sign:FindFirstChild("TagText")
		tagText.Name = "Face"
		local gui = tagText:FindFirstChildWhichIsA("SurfaceGui")
		gui:ClearAllChildren()
		gui.LightInfluence = 0
		gui.Brightness = 1.1
		local bg = Instance.new("Frame")
		bg.Name = "Strip"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = K.dim(DUELS, 0.08)
		bg.Parent = gui
		local t = Instance.new("TextLabel")
		t.Name = "Status"
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -6, 1, 0)
		t.FontFace = K.RUBIK_B
		t.TextSize = math.floor(math.floor(gui.Parent.Size.Y * 24 * 0.55) * 0.82) -- right-aligned: smaller so it never clips
		t.Text = "STEP IN TO QUEUE"
		t.TextColor3 = INK
		t.TextXAlignment = Enum.TextXAlignment.Right
		t.Parent = bg
		-- a pad light under the sign
		local cf = tagText.CFrame
		local pl = K.part(
			sign,
			"PadLight",
			V(1, 0.2, 1),
			CFrame.new(cf.Position - V(0, 1.2, 0)),
			K.paint(Color3.new(0, 0, 0))
		)
		pl.Transparency = 1
		K.ghost(pl)
		K.spot(sign, pl, Enum.NormalId.Bottom, Color3.fromRGB(255, 236, 214), 1.4, 22, 70)
		table.insert(done, bay.Name .. ":" .. mode)
	end
end
return "bay signs: " .. table.concat(done, ", ")
