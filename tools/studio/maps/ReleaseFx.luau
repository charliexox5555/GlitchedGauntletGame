--!strict
-- Release-map polish (2026-11-21): positional ambience emitters (Config/Ambience SPOTS) and a few
-- cheap, stylised Life particle effects (Config/MapLife, tag LifeEmitter) on select release maps.
-- Spec and per-map list: vault/01 Design/Maps/Release Map Audit 2026-11-21.md → SFX / VFX.
-- Arena, BigArena and Snowpeak4 (snowfall, smoke and fire already) get nothing here.
--
-- Run in the match place, edit mode: paste as a ModuleScript and `require(it)()`, or
-- `loadstring(src)()`. Each run replaces <Map>.Ambience and the ReleaseFx folder in the map's Life
-- folder (<Map>.World.Life on the kit maps, <Map>.Life on Pier / Dockyard), so it is safe to re-run.
--
-- Positions are map-local (studs from the map's pivot). The duel maps are two halves turned 180°
-- about Y, so most entries are mirrored: (x, y, z) and (-x, y, -z).
-- Fields reach the controllers through shared AssetData rows (Config/AssetData/MatchMaps): one row per
-- sound kind ({ Sound = "<SPOTS key>" }) and one per emitter wake range ({ Range = studs }).

local CollectionService = game:GetService("CollectionService")

local AUTHORED = "GauntletAuthoredData"
local SOUND_ROW: { [string]: number } = {
	AC = 398,
	CarHorn = 399,
	CraneHum = 400,
	Creak = 401,
	Gulls = 403,
	Horn = 404,
	Pigeon = 405,
	Siren = 406,
	Water = 407,
	Furnace = 427,
	Fountain = 428,
	TrackHum = 429,
}
local RANGE_ROW: { [number]: number } = { [140] = 396, [170] = 397, [300] = 430 }

-- Our own stylised textures (Config/VfxTextures; MOTE is the Bunker2 sun-dust mote).
local TEX = {
	EMBER = "rbxassetid://101128795307568", -- MOLLY_EMBER: hot core + halo
	SMOKE = "rbxassetid://78112081932784", -- MOLLY_SMOKE_2x2: grey puff (the Rooftops2 steam)
	PUFF = "rbxassetid://86393263788167", -- DASH_PUFF_2x2: soft dust puff
	SPARKLE = "rbxassetid://131441026395130", -- MOD_SPARKLE: four-point star (the Dockyard2 glints)
	MOTE = "rbxassetid://139664604115042",
}

type Sound = { kind: string, at: Vector3 }
type Fx = { kind: string, at: Vector3, size: Vector3, rate: number?, range: number? }
type MapSpec = { sounds: { Sound }, fx: { Fx } }

local function mirror(list: { Vector3 }): { Vector3 }
	local out = table.clone(list)
	for _, v in list do
		table.insert(out, Vector3.new(-v.X, v.Y, -v.Z))
	end
	return out
end

local function sounds(kind: string, points: { Vector3 }): { Sound }
	local out = {}
	for _, p in points do
		table.insert(out, { kind = kind, at = p })
	end
	return out
end

local function join(...: { any }): { any }
	local out = {}
	for _, t in { ... } do
		for _, v in t do
			table.insert(out, v)
		end
	end
	return out
end

local SPEC: { [string]: MapSpec } = {
	Wharf = {
		sounds = join(
			sounds("Water", mirror({ Vector3.new(66, -4, 40), Vector3.new(12, -4, 94) })),
			sounds("Gulls", mirror({ Vector3.new(90, 30, 40) })),
			sounds("CraneHum", { Vector3.new(100, 42, -8) }),
			sounds("Horn", { Vector3.new(1400, 10, 300) })
		),
		fx = {},
	},
	Pier = {
		sounds = join(
			sounds("Water", mirror({ Vector3.new(46, -4, 40), Vector3.new(46, -4, -40) })),
			sounds("Gulls", mirror({ Vector3.new(60, 28, 0) }))
		),
		fx = {
			{
				kind = "Glints",
				at = Vector3.new(0, -4.85, 100),
				size = Vector3.new(150, 0.2, 40),
				range = 170,
			},
			{
				kind = "Glints",
				at = Vector3.new(0, -4.85, -100),
				size = Vector3.new(150, 0.2, 40),
				range = 170,
			},
		},
	},
	Dockyard = {
		sounds = join(
			sounds(
				"Water",
				mirror({
					Vector3.new(101, -4, 60),
					Vector3.new(101, -4, -60),
					Vector3.new(0, -4, 116),
				})
			),
			sounds("Gulls", mirror({ Vector3.new(80, 35, 40) })),
			sounds("CraneHum", { Vector3.new(0, 28, 0) }),
			sounds("Horn", { Vector3.new(0, 10, 700) })
		),
		fx = {
			{
				kind = "Glints",
				at = Vector3.new(0, -4.85, 140),
				size = Vector3.new(200, 0.2, 40),
				range = 170,
			},
			{
				kind = "Glints",
				at = Vector3.new(0, -4.85, -140),
				size = Vector3.new(200, 0.2, 40),
				range = 170,
			},
		},
	},
	Foundry4 = {
		-- The furnace mouth (west) and the pour pit (east) roar; embers lift off the molten runner.
		sounds = sounds("Furnace", { Vector3.new(-46, 4, 0), Vector3.new(47, 0, 0) }),
		fx = {
			{
				kind = "Embers",
				at = Vector3.new(-25, -0.6, 0),
				size = Vector3.new(40, 0.2, 5),
				rate = 5,
			},
			{
				kind = "Embers",
				at = Vector3.new(22, -0.6, 0),
				size = Vector3.new(40, 0.2, 5),
				rate = 5,
			},
			{
				kind = "Embers",
				at = Vector3.new(47, -3.2, 0),
				size = Vector3.new(5, 0.2, 6),
				rate = 3,
			},
			{
				kind = "Chimney",
				at = Vector3.new(42, 85.5, 116),
				size = Vector3.new(6, 0.2, 6),
				range = 300,
			},
			{
				kind = "Chimney",
				at = Vector3.new(-42, 85.5, -116),
				size = Vector3.new(6, 0.2, 6),
				range = 300,
			},
		},
	},
	Rooftops4 = {
		sounds = join(
			sounds("AC", mirror({ Vector3.new(28, 4, 68), Vector3.new(41, 15, 29) })),
			sounds("Pigeon", mirror({ Vector3.new(41, 12.5, 52) })),
			sounds("CarHorn", mirror({ Vector3.new(90, -56, 0) })),
			sounds("Siren", { Vector3.new(700, 40, 700) })
		),
		fx = {
			{
				kind = "Steam",
				at = Vector3.new(65, 9.3, 53),
				size = Vector3.new(2.4, 0.2, 2.4),
				rate = 3,
			},
			{
				kind = "Steam",
				at = Vector3.new(-65, 9.3, -53),
				size = Vector3.new(2.4, 0.2, 2.4),
				rate = 3,
			},
			{
				kind = "Steam",
				at = Vector3.new(41, 13.5, 52),
				size = Vector3.new(1.6, 0.2, 1.6),
				rate = 2.4,
			},
			{
				kind = "Steam",
				at = Vector3.new(-41, 13.5, -52),
				size = Vector3.new(1.6, 0.2, 1.6),
				rate = 2.4,
			},
		},
	},
	Greenhouse4 = {
		sounds = join(
			sounds("Fountain", { Vector3.new(0, 0.5, 0) }),
			sounds("Pigeon", mirror({ Vector3.new(51, 28, 27) }))
		),
		fx = {
			{
				kind = "Motes",
				at = Vector3.new(0, 10, 0),
				size = Vector3.new(60, 16, 44),
				rate = 4,
			},
		},
	},
	OldTown4 = {
		sounds = join(
			sounds("Fountain", mirror({ Vector3.new(22, 4, 54) })),
			sounds("Pigeon", mirror({ Vector3.new(4, 40, 0) }))
		),
		fx = {},
	},
	Metro4 = {
		sounds = sounds("TrackHum", mirror({ Vector3.new(118, 1, 0) })),
		fx = {},
	},
	CanyonOutpost = {
		sounds = sounds("Creak", { Vector3.new(2, 24, 0) }),
		fx = {
			{
				kind = "Dust",
				at = Vector3.new(0, 0.4, 0),
				size = Vector3.new(110, 0.2, 150),
				rate = 1.2,
			},
		},
	},
}

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

-- One emitter per kind. Rates are low (MapLife halves them on low graphics) and nothing is large
-- enough near eye height to hide a player.
local function emitter(kind: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = kind
	if kind == "Steam" then -- the Rooftops2 steam, as it was
		e.Texture = TEX.SMOKE
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.Color = ColorSequence.new(Color3.fromRGB(200, 204, 214))
		e.Size = seq({ { 0, 0.8 }, { 0.3, 3.6 }, { 1, 7.5 } })
		e.Transparency = seq({ { 0, 1 }, { 0.12, 0.5 }, { 0.5, 0.42 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(2.6, 3.6)
		e.Speed = NumberRange.new(2.2, 3)
		e.SpreadAngle = Vector2.new(8, 8)
		e.Acceleration = Vector3.new(1.3, 0.3, 0.3)
		e.Drag = 0.6
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
	elseif kind == "Chimney" then -- a slow dark plume high over the works
		e.Texture = TEX.SMOKE
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.Color = ColorSequence.new(Color3.fromRGB(78, 80, 90))
		e.Size = seq({ { 0, 3 }, { 0.4, 8 }, { 1, 14 } })
		e.Transparency = seq({ { 0, 1 }, { 0.1, 0.45 }, { 0.6, 0.6 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(7, 10)
		e.Speed = NumberRange.new(4, 6)
		e.SpreadAngle = Vector2.new(10, 10)
		e.Acceleration = Vector3.new(1.6, 0.2, 0.4)
		e.Drag = 0.4
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-10, 10)
		e.Rate = 1.4
	elseif kind == "Embers" then -- sparks lifting off the molten runner
		e.Texture = TEX.EMBER
		e.Color = ColorSequence.new(Color3.fromRGB(255, 176, 80), Color3.fromRGB(255, 92, 36))
		e.LightEmission = 1
		e.Brightness = 2
		e.Size = seq({ { 0, 0.4 }, { 0.7, 0.26 }, { 1, 0.08 } })
		e.Transparency = seq({ { 0, 0.1 }, { 0.75, 0.25 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(1.8, 3)
		e.Speed = NumberRange.new(3, 6)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0.6, 1.5, 0)
		e.Drag = 0.8
	elseif kind == "Dust" then -- a few soft puffs drifting across the canyon floor
		e.Texture = TEX.PUFF
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.Color = ColorSequence.new(Color3.fromRGB(206, 164, 124))
		e.Size = seq({ { 0, 2 }, { 1, 6 } })
		e.Transparency = seq({ { 0, 1 }, { 0.25, 0.8 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(3, 4.5)
		e.Speed = NumberRange.new(0.5, 1)
		e.Acceleration = Vector3.new(4, 0.3, 0)
		e.Drag = 0.5
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-15, 15)
	elseif kind == "Glints" then -- the Dockyard2 sun glints on the water
		e.Texture = TEX.SPARKLE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 252, 240))
		e.LightEmission = 1
		e.Size = seq({ { 0, 0 }, { 0.4, 0.7 }, { 1, 0 } })
		e.Lifetime = NumberRange.new(0.35, 0.75)
		e.Speed = NumberRange.new(0, 0)
		e.Rate = 12
	elseif kind == "Motes" then -- dust motes in the palm house light
		e.Texture = TEX.MOTE
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 205))
		e.LightEmission = 0.6
		e.Size = seq({ { 0, 0.18 }, { 1, 0.18 } })
		e.Transparency = seq({ { 0, 1 }, { 0.2, 0.35 }, { 0.8, 0.35 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(8, 12)
		e.Speed = NumberRange.new(0.1, 0.3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	return e
end

local function holder(name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	return p
end

local function tagRow(inst: Instance, row: number)
	CollectionService:AddTag(inst, "GGAsset_MatchMaps_" .. row)
	CollectionService:AddTag(inst, AUTHORED)
end

return function(only: string?): string
	local lines = {}
	for mapName, spec in SPEC do
		if only and mapName ~= only then
			continue
		end
		local map = workspace:FindFirstChild(mapName)
		if not map or not map:IsA("Model") then
			table.insert(lines, mapName .. ": not in Workspace, skipped")
			continue
		end
		local pivot = map:GetPivot()

		local old = map:FindFirstChild("Ambience")
		if old then
			old:Destroy()
		end
		local amb = Instance.new("Folder")
		amb.Name = "Ambience"
		for i, s in spec.sounds do
			local row = SOUND_ROW[s.kind]
			assert(row, "no AssetData row for sound " .. s.kind)
			local p =
				holder(string.format("%s_%02d", s.kind, i), pivot * CFrame.new(s.at), Vector3.one)
			CollectionService:AddTag(p, "AmbienceEmitter")
			tagRow(p, row)
			p.Parent = amb
		end
		amb.Parent = map

		local nFx = 0
		if #spec.fx > 0 then
			local world = map:FindFirstChild("World")
			local base: Instance = world or map
			local life = base:FindFirstChild("Life")
			if not life then
				life = Instance.new("Folder")
				life.Name = "Life"
				life.Parent = base
			end
			local prev = (life :: Instance):FindFirstChild("ReleaseFx")
			if prev then
				prev:Destroy()
			end
			local folder = Instance.new("Folder")
			folder.Name = "ReleaseFx"
			for i, f in spec.fx do
				local p =
					holder(string.format("%s_%02d", f.kind, i), pivot * CFrame.new(f.at), f.size)
				local e = emitter(f.kind)
				if f.rate then
					e.Rate = f.rate
				end
				CollectionService:AddTag(e, "LifeEmitter")
				local row = RANGE_ROW[f.range or 140]
				assert(row, "no AssetData row for range " .. tostring(f.range))
				tagRow(e, row)
				e.Parent = p
				p.Parent = folder
				nFx += 1
			end
			folder.Parent = life
		end
		table.insert(
			lines,
			string.format("%s: %d sound emitters, %d effects", mapName, #spec.sounds, nFx)
		)
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end
