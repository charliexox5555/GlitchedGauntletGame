--!strict
-- Original art-only pass. Lobby place only. Re-runnable; no range/gameplay changes.
assert(game.PlaceId == 133387545285290, "Wrong place")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local lobby = workspace:FindFirstChild("Lobby") :: Folder
local art = lobby:FindFirstChild("Art") :: Folder
local grey = lobby:FindFirstChild("Greybox") :: Folder
local lib = SS:FindFirstChild("LobbyKit") :: Folder
local old = art:FindFirstChild("ProfessionalPass")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "ProfessionalPass"
root:SetAttribute("Version", "2026-11-04")
root.Parent = art
local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local entrances = folder("Entrances")
local duelDecor = folder("DuelPresentation")
local displays = folder("DisplayProps")
local C = {
	ink = Color3.fromHex("101720"),
	panel = Color3.fromHex("1E2833"),
	row = Color3.fromHex("283544"),
	white = Color3.fromHex("EEF2F5"),
	muted = Color3.fromHex("A0ADBB"),
	red = Color3.fromHex("DB615A"),
	gold = Color3.fromHex("C8A36A"),
	green = Color3.fromHex("51C6A0"),
	blue = Color3.fromHex("5C9CDD"),
	purple = Color3.fromHex("B393E0"),
	steel = Color3.fromHex("5F6E7D"),
}
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function clone(
	piece: string,
	parent: Instance,
	cf: CFrame,
	scale: number?,
	name: string?
): Model
	local source = lib:FindFirstChild(piece)
	assert(source and source:IsA("Model"), piece)
	local m = source:Clone() :: Model
	m.Name = name or piece
	if scale then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end
	return m
end
local function hide(inst: Instance)
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			if d:GetAttribute("Professional_PreviousTransparency") == nil then
				d:SetAttribute("Professional_PreviousTransparency", d.Transparency)
			end
			d.Transparency = 1
		elseif d:IsA("SurfaceGui") then
			if d:GetAttribute("Professional_PreviousEnabled") == nil then
				d:SetAttribute("Professional_PreviousEnabled", d.Enabled)
			end
			d.Enabled = false
		end
	end
end
local function gui(p: BasePart, face: Enum.NormalId?, replace: boolean?): SurfaceGui
	if replace then
		for _, d in p:GetChildren() do
			if d:IsA("SurfaceGui") and d.Face == (face or Enum.NormalId.Front) then
				if d.Name == "ProfessionalGui" then
					d:Destroy()
				else
					d:SetAttribute("Professional_PreviousEnabled", d.Enabled)
					d.Enabled = false
				end
			end
		end
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "ProfessionalGui"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 25
	g.LightInfluence = 0
	g.Brightness = 1
	g.AlwaysOnTop = false
	g.MaxDistance = 145
	g.ZOffset = 0
	g.Parent = p
	return g
end
local function frame(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	radius: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Parent = parent
	if radius then
		local r = Instance.new("UICorner")
		r.CornerRadius = UDim.new(0, radius)
		r.Parent = f
	end
	return f
end
local function text(
	parent: Instance,
	name: string,
	value: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3?,
	bold: boolean?,
	align: Enum.TextXAlignment?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(x, y)
	t.Size = UDim2.fromScale(w, h)
	t.Text = value
	t.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	t.TextColor3 = color or C.white
	t.TextWrapped = true
	t.TextScaled = true
	t.TextStrokeTransparency = 1
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Parent = parent
	return t
end
local center = Enum.TextXAlignment.Center
local right = Enum.TextXAlignment.Right
local function spin(m: Model, pivot: Vector3, period: number, swing: number?)
	m:SetAttribute("SpinCenter", pivot)
	m:SetAttribute("SpinPeriod", period)
	m:SetAttribute("SpinPhase", 0)
	m:SetAttribute("SpinSwing", swing or 0)
	CS:AddTag(m, "Lobby_Turntable")
end
local function pulse(p: BasePart)
	p:SetAttribute("AmbPeriod", 4.5)
	p:SetAttribute("AmbDepth", 0.25)
	p:SetAttribute("AmbPhase", 0)
	CS:AddTag(p, "Lobby_Pulse")
end

-- Typography across the existing non-range architecture. Keep tiny museum labels compact.
local fontCount = 0
for _, d in lobby:GetDescendants() do
	if
		d:IsA("TextLabel")
		and not d:GetFullName():lower():find("range")
		and not d:IsDescendantOf(root)
	then
		if d:GetAttribute("Professional_PreviousFont") == nil then
			d:SetAttribute("Professional_PreviousFont", d.Font.Name)
		end
		d.Font = if d.Text:find("<font") then Enum.Font.GothamBold else Enum.Font.GothamMedium
		d.TextStrokeTransparency = 1
		fontCount += 1
	end
end

-- Original portal plaques follow the existing panel's measured CFrame. Blender front is +Z.
local portals = (art:FindFirstChild("Ring") :: Folder):FindFirstChild("Portals") :: Folder
local portalData = {
	{
		key = "DUELS",
		id = "01",
		sub = "SOLO  /  DUO  /  SQUAD",
		color = C.red,
		scale = 1,
		width = 40,
	},
	{
		key = "MARKET",
		id = "02",
		sub = "SKINS  /  CHARMS  /  COLLECTIONS",
		color = C.gold,
		scale = 0.68,
		width = 27.2,
	},
	{
		key = "WEAPONS",
		id = "03",
		sub = "ARMOURY  /  LOCKER",
		color = C.blue,
		scale = 0.68,
		width = 27.2,
	},
}
for _, v in portalData do
	local band = portals:FindFirstChild("TitleBand_" .. v.key) :: Model
	local original = band:FindFirstChild("Title_" .. v.key) :: BasePart
	local cf = original.CFrame + original.CFrame.LookVector * 0.65
	hide(band)
	local header = clone(
		"ArenaHeader",
		entrances,
		cf * CFrame.Angles(0, math.pi, 0),
		v.scale,
		"Header_" .. v.key
	)
	for _, p in header:GetDescendants() do
		if p:IsA("BasePart") and p.Name:find("Accent") then
			p.Color = v.color
		end
	end
	local face = part(
		entrances,
		"PortalText_" .. v.key,
		Vector3.new(v.width * 0.76, 6.1 * v.scale, 0.06),
		cf * CFrame.new(0, 0, -0.64 * v.scale),
		C.ink
	)
	local g = gui(face)
	g.MaxDistance = 180
	text(g, "Eyebrow", v.id .. "  /  GAUNTLET", 0.12, 0.035, 0.76, 0.12, v.color, true, center)
	text(g, "Destination", v.key, 0.04, 0.20, 0.92, 0.62, C.white, true, center)
	text(g, "Contents", v.sub, 0.03, 0.87, 0.94, 0.09, C.muted, false, center)
	for _, side in { -1, 1 } do
		local finCF = cf
			* CFrame.new(side * (if v.key == "DUELS" then 23.6 else 12.2), -cf.Y, 0)
			* CFrame.Angles(0, math.pi, 0)
		local fin = clone(
			"ArenaFin",
			entrances,
			finCF,
			if v.key == "DUELS" then 1 else 0.87,
			"Fin_" .. v.key .. side
		)
		for _, p in fin:GetDescendants() do
			if p:IsA("BasePart") and p.Name:find("Glow") then
				p.Color = v.color
				pulse(p)
			end
		end
	end
	if v.key == "DUELS" then
		local crest = clone(
			"VersusCrest",
			entrances,
			cf * CFrame.new(17, 0, -0.9) * CFrame.Angles(0, math.pi, 0),
			0.55,
			"DuelCrest"
		)
		crest:SetAttribute("Purpose", "Original versus emblem")
		for _, p in header:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "ArenaHeader_Accent-1" then
				p.Transparency = 1
			end
		end
	end
	task.wait()
end

-- Four deliberately designed leaderboard screens, using static art data only.
local rot = grey:FindFirstChild("Rotunda") :: Folder
local boardNames = { "DAILY WINS", "RATING", "BEST STREAK", "WEEKLY ELIMS" }
local accents = { C.gold, C.red, C.green, C.blue }
for i = 1, 4 do
	local board = rot:FindFirstChild("Leaderboard_" .. i) :: BasePart
	local g = gui(board, Enum.NormalId.Front, true)
	frame(g, "Background", 0, 0, 1, 1, C.ink)
	frame(g, "TopLine", 0, 0, 1, 0.018, accents[i])
	text(g, "Brand", "GAUNTLET  /  STANDINGS", 0.07, 0.045, 0.86, 0.065, accents[i], true)
	text(g, "Title", boardNames[i], 0.07, 0.15, 0.86, 0.12, C.white, true)
	text(g, "ColPlayer", "PLAYER", 0.17, 0.32, 0.55, 0.05, C.muted)
	text(g, "ColScore", "SCORE", 0.72, 0.32, 0.2, 0.05, C.muted, false, right)
	for rank, entry in { { "NOVA", "42" }, { "KAIRO", "37" }, { "VEX", "31" } } do
		local y = 0.405 + (rank - 1) * 0.155
		local row =
			frame(g, "Row" .. rank, 0.055, y, 0.89, 0.13, if rank == 1 then C.row else C.panel, 4)
		frame(row, "RankMark", 0, 0, 0.012, 1, if rank == 1 then accents[i] else C.steel)
		text(
			row,
			"Rank",
			string.format("%02d", rank),
			0.035,
			0.21,
			0.095,
			0.58,
			if rank == 1 then accents[i] else C.muted,
			true
		)
		text(row, "Name", entry[1], 0.16, 0.21, 0.55, 0.58, C.white, true)
		text(row, "Score", entry[2], 0.75, 0.21, 0.21, 0.58, C.white, true, right)
	end
	frame(g, "FooterRule", 0.07, 0.895, 0.86, 0.002, C.steel)
	text(g, "Footer", "EXHIBITION", 0.07, 0.925, 0.45, 0.035, C.muted)
	text(g, "Season", "SEASON 01", 0.57, 0.925, 0.36, 0.035, accents[i], true, right)
end

-- Duel signs: consistent grid, clear mode, individually numbered bays and party slot motifs.
local duels = grey:FindFirstChild("Wing_Duels") :: Folder
local modes = {
	["1v1"] = { label = "1V1", sub = "SOLO", count = 2, color = C.green },
	["2v2"] = { label = "2V2", sub = "DUO", count = 4, color = C.blue },
	["3v3"] = { label = "3V3", sub = "SQUAD", count = 6, color = C.purple },
	["4v4"] = { label = "4V4", sub = "COMING SOON", count = 8, color = C.muted },
}
local bayCount = 0
for _, p in duels:GetChildren() do
	if p:IsA("BasePart") then
		local mode, side, idx = p.Name:match("^(%dv%d)_Bay([WE])(%d)_Sign$")
		if mode then
			local v = modes[mode]
			bayCount += 1
			local g = gui(p, Enum.NormalId.Front, true)
			frame(g, "Background", 0, 0, 1, 1, C.ink)
			frame(g, "Accent", 0.035, 0.08, 0.012, 0.84, v.color)
			text(
				g,
				"Bay",
				"DUEL BAY  /  " .. side .. "0" .. idx,
				0.09,
				0.07,
				0.82,
				0.11,
				C.muted,
				true
			)
			text(g, "Mode", v.label, 0.09, 0.24, 0.62, 0.39, v.color, true)
			text(g, "Format", v.sub, 0.09, 0.72, 0.54, 0.12, C.white, true)
			text(g, "Status", tostring(v.count) .. " PLAYERS", 0.09, 0.88, 0.82, 0.07, C.muted)
			for k = 1, v.count do
				frame(
					g,
					"Slot" .. k,
					0.73 + ((k - 1) % 2) * 0.105,
					0.29 + math.floor((k - 1) / 2) * 0.125,
					0.07,
					0.085,
					v.color,
					2
				)
			end
			local padName = mode .. "_Bay" .. side .. idx .. "_Pad"
			local pad = (art:FindFirstChild("DuelsBays") :: Folder):FindFirstChild(padName) :: Model
			if pad then
				local cf, sz = pad:GetBoundingBox()
				local pos = Vector3.new(cf.X, 0.63, cf.Z)
				local ground = part(
					duelDecor,
					"BayMedallion_" .. side .. idx .. mode,
					Vector3.new(0.065, 5.8, 5.8),
					CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
					C.panel
				)
				ground.Shape = Enum.PartType.Cylinder
				local floorCF = CFrame.lookAt(
					pos + Vector3.new(0, 0.085, 0),
					Vector3.new(0, pos.Y + 0.085, pos.Z)
				)
				local face = part(
					duelDecor,
					"BayFloorGraphic",
					Vector3.new(4.1, 0.04, 3.5),
					floorCF,
					C.panel
				)
				local fg = gui(face, Enum.NormalId.Top)
				fg.PixelsPerStud = 20
				fg.MaxDistance = 65
				text(fg, "Versus", "VS", 0.13, 0.19, 0.74, 0.45, v.color, true, center)
				text(
					fg,
					"BayNumber",
					side .. "0" .. idx,
					0.13,
					0.7,
					0.74,
					0.13,
					C.muted,
					true,
					center
				)
			end
		elseif p.Name:match("^Arch%d_Title$") or p.Name == "ArchGauntlet_Title" then
			local label = p:FindFirstChildWhichIsA("SurfaceGui")
			local mode = p.Name:match("^Arch(%d)_Title$")
			local v = if mode
				then modes[mode .. "v" .. mode]
				else { label = "GAUNTLET", sub = "THE CHAMPIONS HALL", color = C.gold }
			local g = gui(p, Enum.NormalId.Front, true)
			frame(g, "Background", 0, 0, 1, 1, C.ink)
			text(
				g,
				"Eyebrow",
				if mode then "DUELS  /  " .. v.sub else "THE FINAL CHALLENGE",
				0.08,
				0.08,
				0.84,
				0.12,
				v.color,
				true,
				center
			)
			text(g, "Mode", v.label, 0.08, 0.29, 0.84, 0.43, C.white, true, center)
			frame(g, "Underline", 0.3, 0.83, 0.4, 0.025, v.color)
		elseif p.Name == "Entry_QueueSign" then
			local g = gui(p, Enum.NormalId.Front, true)
			frame(g, "Background", 0, 0, 1, 1, C.ink)
			text(g, "Title", "FIND YOUR DUEL", 0.06, 0.17, 0.88, 0.35, C.white, true, center)
			text(
				g,
				"Subtitle",
				"SOLO  /  DUO  /  SQUAD",
				0.06,
				0.66,
				0.88,
				0.16,
				C.muted,
				false,
				center
			)
		end
	end
end

-- Broken centre line: small forward chevrons rhythmically lead down the existing open aisle.
for z = -89, -205, -14 do
	for _, s in { -1, 1 } do
		part(
			duelDecor,
			"AisleChevron",
			Vector3.new(2.05, 0.035, 0.23),
			CFrame.new(s * 0.65, 0.12, z) * CFrame.Angles(0, s * math.rad(38), 0),
			C.steel
		)
	end
end

-- Far chamber landmark. The pedestal stays still while the upper gauntlet gently swivels.
local trophy =
	clone("GauntletTrophy", displays, CFrame.new(0, 1.29, -270), 1.65, "ChampionGauntlet")
for _, p in trophy:GetDescendants() do
	if p:IsA("BasePart") and p.Color == Color3.fromHex("CDA45C") then
		p.Color = Color3.fromHex("94784F")
	end
end
local sculpture = Instance.new("Model")
sculpture.Name = "AnimatedGauntlet"
sculpture.Parent = trophy
sculpture.WorldPivot = CFrame.new(0, 8, -270)
for _, p in trophy:GetChildren() do
	if p:IsA("BasePart") and not p.Name:find("Plinth") and not p.Name:find("Mount") then
		p.Parent = sculpture
	end
end
spin(sculpture, Vector3.new(0, 8, -270), 38, 10)
local gateTitle = duels:FindFirstChild("Gate_Title") :: BasePart
if gateTitle then
	if gateTitle:GetAttribute("Professional_PreviousCFrame") == nil then
		gateTitle:SetAttribute("Professional_PreviousCFrame", gateTitle.CFrame)
		gateTitle:SetAttribute("Professional_PreviousSize", gateTitle.Size)
	end
	gateTitle.Size = Vector3.new(31, 4.8, 0.3)
	gateTitle.CFrame = CFrame.new(0, 25.6, -268) * gateTitle.CFrame.Rotation
	for _, x in { -12, 12 } do
		part(
			displays,
			"ChampionsHeaderHanger",
			Vector3.new(0.16, 5.6, 0.16),
			CFrame.new(x, 30.8, -268),
			C.steel,
			Enum.Material.Metal
		)
	end
	local g = gui(gateTitle, Enum.NormalId.Front, true)
	frame(g, "Background", 0, 0, 1, 1, C.ink)
	text(g, "Title", "THE GAUNTLET", 0.05, 0.17, 0.9, 0.38, C.gold, true, center)
	text(g, "Subtitle", "CHAMPIONS ARE MADE HERE", 0.05, 0.69, 0.9, 0.12, C.muted, false, center)
end
local plaque = part(
	displays,
	"TrophyPlaque",
	Vector3.new(8, 1.6, 0.13),
	CFrame.new(0, 2.7, -263.2) * CFrame.Angles(0, math.pi, 0),
	C.ink
)
local pg = gui(plaque)
text(pg, "Title", "EARN YOUR PLACE", 0.06, 0.15, 0.88, 0.34, C.gold, true, center)
text(pg, "Sub", "THE GAUNTLET", 0.06, 0.65, 0.88, 0.16, C.muted, false, center)
local heroKey = (art:FindFirstChild("DuelsChamber") :: Folder):FindFirstChild("HeroKey")
if heroKey then
	local l = heroKey:FindFirstChildWhichIsA("Light")
	if l then
		if l:GetAttribute("Professional_PreviousBrightness") == nil then
			l:SetAttribute("Professional_PreviousBrightness", l.Brightness)
		end
		l.Brightness = 2
	end
end
local keyLight =
	part(displays, "TrophyLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 20, -261), C.white)
keyLight.Transparency = 1
local light = Instance.new("PointLight")
light.Color = Color3.fromHex("E6D3B1")
light.Range = 27
light.Brightness = 1.1
light.Shadows = false
light.Parent = keyLight

-- Sculptural crest repeats above the first section, giving a strong mid-distance destination.
clone("VersusCrest", duelDecor, CFrame.new(0, 10.5, -78.2), 0.7, "EntryVersus")

-- Decor only: original case and key models replace the blank shop-item shapes.
local built = (art:FindFirstChild("Market_Street") :: Folder):FindFirstChild("Built") :: Folder
for _, shop in built:GetChildren() do
	if
		shop:IsA("Model")
		and (
			shop.Name == "Shop_CHARMS"
			or shop.Name == "Shop_CURRENCY"
			or shop.Name == "Shop_BUNDLES"
		)
	then
		local item = shop:FindFirstChild(
			if shop.Name == "Shop_BUNDLES"
				then "Show_crate"
				elseif shop.Name == "Shop_CHARMS" then "Show_charm"
				else "Show_coins"
		)
		if item and item:IsA("Model") then
			local cf = item:GetPivot()
			hide(item)
			CS:RemoveTag(item, "Lobby_Turntable")
			if shop.Name == "Shop_BUNDLES" then
				clone(
					"EquipmentCase",
					displays,
					cf * CFrame.Angles(0, math.pi / 2, 0),
					0.8,
					"BundleCase"
				)
			else
				local key = clone(
					"KeyDisplay",
					displays,
					cf * CFrame.Angles(0, math.pi / 2, 0),
					if shop.Name == "Shop_CHARMS" then 0.45 else 0.65,
					shop.Name .. "_Key"
				)
				if shop.Name == "Shop_CHARMS" then
					for _, p in key:GetDescendants() do
						if p:IsA("BasePart") and p.Material == Enum.Material.Metal then
							p.Color = C.muted
						end
					end
				end
				spin(key, key:GetPivot().Position, 26, 22)
			end
		end
	end
end

for _, d in (art:FindFirstChild("DuelsChamber") :: Folder):GetDescendants() do
	if
		d:IsA("BasePart")
		and d.Material == Enum.Material.Neon
		and (d.Name:find("Ring_Glow") or d.Name:find("Slit_Glow") or d.Name:find("Strip_Glow"))
	then
		if d:GetAttribute("Professional_PreviousColor") == nil then
			d:SetAttribute("Professional_PreviousColor", d.Color)
		end
		d.Color = Color3.fromHex("A8874C")
	end
end
local gateLight = (art:FindFirstChild("DuelsChamber") :: Folder):FindFirstChild("Gate_Light")
if gateLight then
	local l = gateLight:FindFirstChildWhichIsA("Light")
	if l then
		if l:GetAttribute("Professional_PreviousBrightness") == nil then
			l:SetAttribute("Professional_PreviousBrightness", l.Brightness)
		end
		l.Brightness = 0.85
	end
end

-- Three properly seated equipment cases in the armoury entry; none occupy a walking lane.
for _, v in { { 100, 0, 21 }, { 102, 0, 25 }, { 100, 2.5, 21 } } do
	clone(
		"EquipmentCase",
		displays,
		CFrame.new(v[1], v[2], v[3]) * CFrame.Angles(0, -math.pi / 2, 0),
		1,
		"ArmouryCase"
	)
end

for _, d in (art:FindFirstChild("DuelsChamber") :: Folder):GetDescendants() do
	if d:IsA("BasePart") and d.Name == "GauntletGate_TitleBacker" then
		if d:GetAttribute("Professional_PreviousColor") == nil then
			d:SetAttribute("Professional_PreviousColor", d.Color)
			d:SetAttribute("Professional_PreviousMaterial", d.Material.Name)
			d:SetAttribute("Professional_PreviousVariant", d.MaterialVariant)
		end
		d.Color = Color3.fromHex("303943")
		d.Material = Enum.Material.Metal
		d.MaterialVariant = ""
	end
end

-- Separation of known floor overlays. This is a deliberate depth hierarchy, not a blanket mesh offset.
local separationCount = 0
local function offset(p: BasePart, delta: Vector3, reason: string)
	if p:GetAttribute("Professional_SurfaceOffset") == nil then
		p:SetAttribute("Professional_SurfaceOffset", delta)
		p.CFrame += delta
		p:SetAttribute("Professional_SurfaceFix", reason)
		separationCount += 1
	end
end
for _, d in (art:FindFirstChild("DuelsChamber") :: Folder):GetDescendants() do
	if d:IsA("BasePart") and d.Name == "GauntletDais_Nose" then
		offset(d, Vector3.new(0, 0.045, 0), "Nosing shared the deck plane")
	end
end
for _, d in (art:FindFirstChild("Rotunda") :: Folder):GetDescendants() do
	if d:IsA("BasePart") then
		if d.Name == "SpawnDais_CompassRing" then
			offset(d, Vector3.new(0, 0.065, 0), "Compass ring separated from crossing arrow tip")
		elseif d.Name == "RotundaFloor_SunInlay" then
			offset(d, Vector3.new(0, 0.04, 0), "Inlay separated from floor guide layers")
		elseif d.Name:match("RotundaFloor_Line[NEWS]_Glow") then
			offset(d, Vector3.new(0, 0.12, 0), "Guide strip separated from inlay layers")
		end
	end
end

local parts, meshes, guis = 0, 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
	if d:IsA("MeshPart") then
		meshes += 1
	end
	if d:IsA("SurfaceGui") then
		guis += 1
	end
end
return {
	newParts = parts,
	newMeshParts = meshes,
	newSurfaceGuis = guis,
	bays = bayCount,
	fontsUpdated = fontCount,
	surfaceSeparations = separationCount,
}
