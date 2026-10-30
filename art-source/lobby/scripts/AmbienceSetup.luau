--!strict
-- AmbienceSetup: builds Workspace.Lobby.Ambience and tags the art the ambience animates
-- (phase 1, step 6). Studio, edit mode. Run it through the Studio MCP (or the Command Bar)
-- as the bundle from ambience_bundle.py, which defines CLIENT_SOURCE (the text of
-- AmbienceClient.luau) above this body. Re-runnable: it clears its own tags and rebuilds the
-- Ambience folder. Re-run it after any Art_*.luau script, because publishArt replaces the Art
-- folders (and with them the tags set here).
--
-- Owns: Workspace.Lobby.Ambience (the AmbienceClient Script and the particle hosts), the
-- Lobby_* ambience tags and the Spin*/Amb* attributes below. Touches nothing else except
-- ModelStreamingMode = Atomic on the small display models it spins.

assert(game.PlaceId == 133387545285290, "not the Lobby")

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local TAGS =
	{ "Lobby_Turntable", "Lobby_PadRing", "Lobby_Pulse", "Lobby_Flicker", "Lobby_LedScreen" }
local ATTRS = {
	"SpinCenter",
	"SpinPeriod",
	"SpinPhase",
	"SpinSwing",
	"AmbPeriod",
	"AmbDepth",
	"AmbPhase",
	"AmbFace",
	"AmbStyle",
	"AmbColor",
}

-- Particle sprites (tools/vfx/make_lobby_vfx.py; Decals 134469003945987 / 74222974828437).
local DUST_IMAGE = "rbxassetid://129992924430621"
local WISP_IMAGE = "rbxassetid://137038686936629"

local REPORT: { string } = {}
local function note(s: string)
	table.insert(REPORT, s)
end

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "no Workspace.Lobby")
local art = lobby:FindFirstChild("Art")
assert(art, "no Workspace.Lobby.Art")
local greybox = lobby:FindFirstChild("Greybox")

local function path(root: Instance?, ...: string): Instance?
	local cur = root
	for _, name in { ... } do
		if not cur then
			return nil
		end
		cur = cur:FindFirstChild(name)
	end
	return cur
end

-- ------------------------------------------------------------------ clear old tags

for _, tagName in TAGS do
	for _, inst in CollectionService:GetTagged(tagName) do
		inst:RemoveTag(tagName)
		for _, a in ATTRS do
			inst:SetAttribute(a, nil)
		end
	end
end

local counts: { [string]: number } = {}
local function tag(inst: Instance, tagName: string, attrs: { [string]: any })
	inst:AddTag(tagName)
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
	counts[tagName] = (counts[tagName] or 0) + 1
end

local spunParts = 0
local spunCollide = 0
local function spin(inst: Instance, center: Vector3, period: number, phase: number, swing: number?)
	tag(
		inst,
		"Lobby_Turntable",
		{ SpinCenter = center, SpinPeriod = period, SpinPhase = phase, SpinSwing = swing }
	)
	if inst:IsA("Model") then
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			spunParts += 1
			if d.CanCollide then
				spunCollide += 1
			end
			if not d.Anchored then
				note("WARNING unanchored spin part " .. d:GetFullName())
			end
		end
	end
end

-- Largest horizontal distance of any part corner from the axis (fit check for cases/decks).
local function reach(inst: Instance, center: Vector3): number
	local best = 0
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					for _, sy in { -1, 1 } do
						local p =
							d.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						best = math.max(best, Vector2.new(p.X - center.X, p.Z - center.Z).Magnitude)
					end
				end
			end
		end
	end
	return best
end

-- Largest swivel (degrees, both ways, up to `limit`) that keeps every corner of every part of
-- `inst` at least `gap` studs short of the surroundings, by raycasting out from the axis at
-- each corner's height and bearing. 0 when even a small swivel would touch something.
local function maxSwing(
	inst: Instance,
	center: Vector3,
	exclude: { Instance },
	limit: number,
	gap: number
): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local corners: { Vector3 } = {}
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(
							corners,
							d.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						)
					end
				end
			end
		end
	end
	local axis = CFrame.new(center)
	local function clear(theta: number): boolean
		local turn = axis * CFrame.Angles(0, theta, 0) * axis:Inverse()
		for _, p in corners do
			local q = turn * p
			local flat = Vector3.new(q.X - center.X, 0, q.Z - center.Z)
			local dist = flat.Magnitude
			if dist > 0.05 then
				local hit = workspace:Raycast(
					Vector3.new(center.X, q.Y, center.Z),
					flat.Unit * (dist + gap),
					params
				)
				if hit then
					return false
				end
			end
		end
		return true
	end
	local best = 0
	local step = 2.5
	local theta = step
	while theta <= limit do
		if clear(math.rad(theta)) and clear(-math.rad(theta)) then
			best = theta
		else
			break
		end
		theta += step
	end
	return best
end

-- ------------------------------------------------------------------ Armoury gun turntables

local chapels = path(art, "Weapons", "Chapels")
if chapels then
	local k = 0
	for _, ch in chapels:GetChildren() do
		local tt = ch:FindFirstChild("Turntable")
		if ch:IsA("Model") and tt and tt:IsA("Model") then
			k += 1
			local c = tt:GetPivot().Position
			local gun = ch:FindFirstChild("Gun")
			if not gun then
				continue
			end
			-- The display guns are longer than their bays are deep, so a full turn would cut
			-- through the trophy wall: they swivel to show their profile instead, as far as the
			-- chapel allows (checked against everything but the turntable set itself).
			local movers: { Instance } = { gun }
			for _, d in tt:GetChildren() do
				if d:IsA("BasePart") and string.find(d.Name, "_Deck$") then
					table.insert(movers, d)
				end
			end
			for _, d in ch:GetChildren() do
				if string.find(d.Name, "^Rod%d") or string.find(d.Name, "^Saddle%d") then
					table.insert(movers, d)
				end
			end
			local r = reach(gun, c)
			local exclude: { Instance } = { tt }
			for _, m in movers do
				table.insert(exclude, m)
			end
			local swing = maxSwing(gun, c, exclude, 30, 0.4)
			if swing >= 7.5 then
				for _, m in movers do
					spin(m, c, 18, k * 2.25, swing)
				end
			end
			note(string.format("%s gun reach %.2f swing +-%.1f deg", ch.Name, r, swing))
		end
	end
	note("chapel turntables " .. k)
else
	note("MISSING Art.Weapons.Chapels")
end

-- ------------------------------------------------------------------ Market featured podiums

local built = path(art, "Market_Street", "Built")
if built then
	local k = 0
	for _, pod in built:GetChildren() do
		if pod:IsA("Model") and string.find(pod.Name, "^Podium%d$") then
			k += 1
			local c = pod:GetPivot().Position
			local period, phase = 24, k * 8
			for _, d in pod:GetChildren() do
				if
					d.Name == "FeaturedPodium_Turntable"
					or d.Name == "FeaturedPodium_Cradle"
					or string.find(d.Name, "^Show_")
				then
					spin(d, c, period, phase)
					if string.find(d.Name, "^Show_") then
						note(string.format("%s %s reach %.2f", pod.Name, d.Name, reach(d, c)))
					end
				end
			end
		end
	end
	note("featured podiums " .. k)
else
	note("MISSING Art.Market_Street.Built")
end

-- ------------------------------------------------------------------ Duels queue pad rings

local bays = art:FindFirstChild("DuelsBays")
if bays then
	for _, pad in bays:GetChildren() do
		local mode = string.match(pad.Name, "^(%d)v%d_.+_Pad$")
		-- Only the live modes breathe; dormant 4v4 / Gauntlet rings stay still.
		if pad:IsA("Model") and (mode == "1" or mode == "2" or mode == "3") then
			local ring: BasePart? = nil
			for _, d in pad:GetChildren() do
				if d:IsA("BasePart") and string.find(d.Name, "Ring_Glow$") then
					ring = d
				end
			end
			if ring then
				-- A slow ripple down the hall: pads nearer the entrance peak first.
				local z = pad:GetPivot().Position.Z
				tag(ring, "Lobby_PadRing", {
					AmbPeriod = 3.6,
					AmbDepth = 0.4,
					AmbPhase = (260 + z) * 0.03,
				})
			end
		end
	end
else
	note("MISSING Art.DuelsBays")
end

-- ------------------------------------------------------------------ ENTER RANGE gate pulse

local rangeArt = art:FindFirstChild("Range")
local gate: Instance? = nil
if rangeArt then
	for _, m in rangeArt:GetChildren() do
		if m.Name == "EnterGate" and m:IsA("Model") and m:GetPivot().Position.X < 0 then
			gate = m
		end
	end
end
if gate then
	for _, d in gate:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "EnterGate_Light_Glow" or d.Name == "FrontGlow") then
			tag(
				d,
				"Lobby_Pulse",
				{ AmbPeriod = 4, AmbDepth = if d.Name == "FrontGlow" then 0.35 else 0.25 }
			)
		end
	end
	local glow = path(rangeArt, "Lights", "GateGlow")
	local light = glow and glow:FindFirstChildWhichIsA("Light")
	if light then
		tag(light, "Lobby_Pulse", { AmbPeriod = 4, AmbDepth = 0.35 })
	end
else
	note("MISSING Art.Range.EnterGate")
end

-- ------------------------------------------------------------------ Hero rifle accents

local hero = path(art, "Weapons", "Hero")
if hero then
	local heroGun = hero:FindFirstChild("HeroGun")
	if heroGun then
		for _, d in heroGun:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				tag(d, "Lobby_Pulse", { AmbPeriod = 5, AmbDepth = 0.45 })
			end
		end
	end
	local ringGlow = path(hero, "Dais", "HeroDais_Ring_Glow")
	if ringGlow then
		tag(ringGlow, "Lobby_Pulse", { AmbPeriod = 5, AmbDepth = 0.18, AmbPhase = 2.5 })
	end
end

-- ------------------------------------------------------------------ LED screens

local function faceOf(part: Instance): string
	local gui = part:FindFirstChildWhichIsA("SurfaceGui")
	return if gui then gui.Face.Name else "Front"
end

local ledWall = path(greybox, "Wing_Market", "LEDWall")
if ledWall then
	tag(ledWall, "Lobby_LedScreen", {
		AmbFace = faceOf(ledWall),
		AmbStyle = "Shimmer",
		AmbColor = Color3.fromHex("FFE6C4"),
		AmbPeriod = 9,
	})
else
	note("MISSING Greybox.Wing_Market.LEDWall")
end
local status = path(rangeArt, "Sign_StatusScreen", "Text")
if status then
	tag(status, "Lobby_LedScreen", {
		AmbFace = faceOf(status),
		AmbStyle = "Scan",
		AmbColor = Color3.fromHex("BFE3FF"),
		AmbPeriod = 5,
	})
else
	note("MISSING Art.Range.Sign_StatusScreen.Text")
end

-- The four rotunda leaderboards (the first screens a player sees at spawn): a slow glassy
-- sheen, each a quarter-cycle apart, so the room never looks frozen. Phase 2 fills their
-- data; the overlay sits above it and never touches it.
local rotunda = path(greybox, "Rotunda")
if rotunda then
	for i = 1, 4 do
		local board = rotunda:FindFirstChild("Leaderboard_" .. i)
		if board and board:IsA("BasePart") and board:FindFirstChildWhichIsA("SurfaceGui") then
			tag(board, "Lobby_LedScreen", {
				AmbFace = faceOf(board),
				AmbStyle = "Shimmer",
				AmbColor = Color3.fromHex("F2F0EA"),
				AmbPeriod = 12,
				AmbPhase = i * 3,
			})
		end
	end
end

-- ------------------------------------------------------------------ flickering practicals

-- Two fluorescent bars over the far corners of the real range hall (RangeFar), which reads
-- as the working, service end of the lobby. Subtle stutters only.
local roof = path(art, "RangeFar", "Roof")
if roof then
	for _, want in { Vector3.new(36, 33, 1240), Vector3.new(-36, 33, 1060) } do
		for _, m in roof:GetChildren() do
			if m:IsA("Model") and (m:GetPivot().Position - want).Magnitude < 1 then
				for _, d in m:GetChildren() do
					if d:IsA("BasePart") and string.find(d.Name, "_Glow$") then
						tag(d, "Lobby_Flicker", {})
					end
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ Ambience folder

local old = lobby:FindFirstChild("Ambience")
if old then
	old:Destroy()
end
local amb = Instance.new("Folder")
amb.Name = "Ambience"

local client = Instance.new("Script")
client.Name = "AmbienceClient"
client.RunContext = Enum.RunContext.Client
client.Source = CLIENT_SOURCE
client.Parent = amb

local emitters = Instance.new("Folder")
emitters.Name = "Emitters"
emitters.Parent = amb

local function host(name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.AudioCanCollide = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cf
	p.Parent = emitters
	return p
end

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, pt in points do
		table.insert(kps, NumberSequenceKeypoint.new(pt[1], pt[2], pt[3] or 0))
	end
	return NumberSequence.new(kps)
end

-- Slow, lit dust motes in a volume.
local function dust(parent: Part, rate: number, brightness: number, color: Color3)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Dust"
	e.Texture = DUST_IMAGE
	e.Color = ColorSequence.new(color)
	e.LightInfluence = 1
	e.LightEmission = 0
	e.Brightness = brightness
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(180, 180)
	e.Speed = NumberRange.new(0.12, 0.35)
	e.Acceleration = Vector3.new(0, -0.01, 0)
	e.Drag = 0
	e.Lifetime = NumberRange.new(10, 16)
	e.Rate = rate
	e.Size = seq({ { 0, 0.36, 0.1 }, { 1, 0.36, 0.1 } })
	e.Transparency = seq({ { 0, 1 }, { 0.2, 0.3 }, { 0.8, 0.3 }, { 1, 1 } })
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.LockedToPart = false
	e.Parent = parent
end

-- Low, slow haze rolling off the cave floor (stage haze at the battle-pass dais).
local function wisps(parent: Part, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Wisps"
	e.Texture = WISP_IMAGE
	e.Color = ColorSequence.new(Color3.fromHex("D8CFC2"))
	-- Partly self-lit so the haze still reads faintly in the dim corners of the cave.
	e.LightInfluence = 0.6
	e.LightEmission = 0
	e.Brightness = 1
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(35, 35)
	e.Speed = NumberRange.new(0.2, 0.45)
	e.Acceleration = Vector3.new(0.05, 0.03, 0)
	e.Drag = 0.15
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = rate
	e.Size = seq({ { 0, 3.5, 0.6 }, { 1, 10, 2 } })
	e.Transparency = seq({ { 0, 1 }, { 0.15, 0.72 }, { 0.6, 0.8 }, { 1, 1 } })
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.LockedToPart = false
	e.Parent = parent
end

-- Sunbeam dust: a box leaning along the sun ray through the oculus (rim lip ~y 54, R16),
-- from just above the floor to just under the rim, 16 wide (the lit shaft is ~R8-10 at the
-- floor) so the motes stay in the light.
do
	local sun = Lighting:GetSunDirection()
	if sun.Y < 0.2 then
		sun = Vector3.yAxis
	end
	local top, bottom = 52, 2
	local mid = (top + bottom) / 2
	local oculus = Vector3.new(0, 54, 0)
	local centre = oculus - sun * ((oculus.Y - mid) / sun.Y)
	local length = (top - bottom) / sun.Y
	local right = sun:Cross(Vector3.zAxis)
	right = if right.Magnitude > 0.1 then right.Unit else Vector3.xAxis
	local beam =
		host("SunbeamDust", CFrame.fromMatrix(centre, right, sun), Vector3.new(16, length, 16))
	dust(beam, 10, 2, Color3.fromHex("FFF1DC"))
	note(
		string.format(
			"sunbeam centre (%.1f, %.1f, %.1f) len %.1f",
			centre.X,
			centre.Y,
			centre.Z,
			length
		)
	)
end

-- Market cavern: dust hanging in the battle-pass key light, low haze at both ends of the
-- dais (seen against the dark rock from the path) and one wisp just inside the mouth (all
-- clear of the path, kiosks, dais and rock; checked against their bounds).
do
	local caveDust = host("CaveDust", CFrame.new(-312, 9, 0), Vector3.new(22, 14, 36))
	dust(caveDust, 4, 1.5, Color3.fromHex("FFE2BC"))
	wisps(host("CaveWispN", CFrame.new(-319, 0.6, -27), Vector3.new(5, 1, 4)), 1.2)
	wisps(host("CaveWispS", CFrame.new(-319, 0.6, 27), Vector3.new(5, 1, 4)), 1.2)
	wisps(host("CaveWispMouth", CFrame.new(-268, 0.6, -26), Vector3.new(5, 1, 4)), 1)
end

amb.Parent = lobby

for _, tagName in TAGS do
	note(string.format("%s %d", tagName, counts[tagName] or 0))
end
note(string.format("spun parts %d (CanCollide %d)", spunParts, spunCollide))
local parts, emitterCount, rate = 0, 0, 0
for _, d in amb:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("ParticleEmitter") then
		emitterCount += 1
		rate += d.Rate
	end
end
note(string.format("Ambience: %d parts, %d emitters, total rate %.1f/s", parts, emitterCount, rate))
return table.concat(REPORT, "\n")
