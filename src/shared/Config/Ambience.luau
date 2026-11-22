--!strict
-- Map ambience (Controllers/AmbienceController), 2026-11-05. All sounds are
-- real CC0 recordings in the sound atlas (tools/audio/build_sfx.py; sources,
-- licences and alternates in vault/05 Production/Playtests/2026-11-05 Knife
-- and Sound Pass.md → Map ambience).
--
-- How it plays:
--   * Each map has a box (`center`, `size`). While the camera is inside it,
--     that map's `beds` loop 2D (stereo), fading in and out over FADE.
--   * Parts or attachments tagged TAG_EMITTER with a `Sound` attribute (a key
--     of SPOTS) are positional: loops (water at the pier edge, the crane's
--     hum) play at the emitter, only the nearest MAX_LOOPS within their range;
--     one-shots (gulls, horns, creaks) fire at random intervals while you're
--     in range.
--   * Parts tagged TAG_INDOOR are rooms (invisible boxes). With the camera
--     inside one, the outdoor ambience is muffled and turned down (INDOOR)
--     and the map's `room` tone comes up.
-- Placed by tools/studio/maps/<Map>/Ambience.luau (Dockyard2 first).
-- Volumes are mix levels: every file sits at a common loudness (beds -22
-- to -26 LUFS, one-shots about -24 LUFS momentary), well under the guns.

export type Bed = { id: string, volume: number }
export type Spot = {
	id: string,
	volume: number,
	range: number, -- studs: silent past this (InverseTapered to zero)
	loop: boolean?, -- a positional loop instead of one-shots
	pitch: { number }?, -- { min, max } playback speed (a loop uses min)
	interval: { number }?, -- one-shots: { min, max } seconds between plays
}
export type Map = {
	center: Vector3,
	size: Vector3,
	beds: { Bed },
	room: Bed?, -- the indoor tone (only where the map has TAG_INDOOR rooms)
}

local MAPS: { [string]: Map } = {
	-- Dockyard2: a container pier over open water on a bright afternoon.
	-- Playable deck 136 x 236 at world origin (-3000, 200, 0); the box takes
	-- in the quay walls and the water around the deck.
	Dockyard2 = {
		center = Vector3.new(-3000, 225, 0),
		size = Vector3.new(320, 160, 420),
		beds = {
			{ id = "sfx:AmbHarbour", volume = 0.45 }, -- distant harbour and industry
			{ id = "sfx:AmbWind", volume = 0.28 }, -- wind
		},
		room = { id = "sfx:AmbRoom", volume = 0.55 }, -- inside the sheds
	},
	-- Wharf (2026-11-20): the morning container wharf, pier 130 x 185 at (6000, 200, 6000); the box takes in
	-- the berth, the crane and the water round the pier. Beds only (no emitters placed yet).
	Wharf = {
		center = Vector3.new(6010, 215, 6000),
		size = Vector3.new(360, 160, 420),
		beds = {
			{ id = "sfx:AmbHarbour", volume = 0.45 },
			{ id = "sfx:AmbWind", volume = 0.26 },
		},
	},
	-- Metro4 (2026-11-20): the glazed station hall in the city, hall 230 x 210 at (6000, 200, 12500). Beds only.
	Metro4 = {
		center = Vector3.new(6000, 215, 12500),
		size = Vector3.new(260, 80, 240),
		beds = {
			{ id = "sfx:AmbCity", volume = 0.4 },
			{ id = "sfx:AmbWind", volume = 0.14 },
		},
	},
	-- OldTown4 (2026-11-21): the Collina hill town, 200 x 220 at (6000, 200, 26000). Beds only.
	OldTown4 = {
		center = Vector3.new(6000, 215, 26000),
		size = Vector3.new(260, 120, 300),
		beds = { { id = "sfx:AmbCity", volume = 0.3 }, { id = "sfx:AmbWind", volume = 0.2 } },
	},
	-- CanyonOutpost (2026-11-21): the mining outpost in a red canyon, 140 x 192 at (6000, 200, 54000); the box takes in
	-- the cliffs round it. Beds only: canyon wind.
	CanyonOutpost = {
		center = Vector3.new(6000, 215, 54000),
		size = Vector3.new(200, 90, 250),
		beds = { { id = "sfx:AmbWind", volume = 0.3 } },
	},
	-- Foundry4 (2026-11-21): the steel works at night, 150 x 192 at (6000, 200, 47000); the box takes in the mill sheds
	-- and the stoves round it. Beds only: the plant hum and a little wind.
	Foundry4 = {
		center = Vector3.new(6000, 212, 47000),
		size = Vector3.new(220, 90, 250),
		beds = { { id = "sfx:AmbHum", volume = 0.3 }, { id = "sfx:AmbWind", volume = 0.14 } },
	},
	-- Greenhouse4 (2026-11-21): the Victorian conservatory in a walled garden, 140 x 196 at (6000, 200, 40000); the box
	-- takes in the garden walls. Beds only.
	Greenhouse4 = {
		center = Vector3.new(6000, 210, 40000),
		size = Vector3.new(200, 80, 240),
		beds = { { id = "sfx:AmbWind", volume = 0.16 } },
	},
	-- Rooftops4 (2026-11-21): the city block at blue hour, 140 x 192 at (6000, 200, 33000); the box takes in the
	-- alleys and the street below. Beds only.
	Rooftops4 = {
		center = Vector3.new(6000, 195, 33000),
		size = Vector3.new(220, 110, 260),
		beds = { { id = "sfx:AmbCity", volume = 0.45 }, { id = "sfx:AmbWind", volume = 0.18 } },
	},
	-- Snowpeak4 (2026-11-21): the ski saddle, 150 x 190 at (6000, 200, 19000); the box takes in the slopes. Beds only.
	Snowpeak4 = {
		center = Vector3.new(6000, 210, 19000),
		size = Vector3.new(260, 120, 300),
		beds = { { id = "sfx:AmbWind", volume = 0.4 } },
	},
	-- The older maps: beds only (a hook; no emitters or rooms placed yet). Boxes
	-- are 300 x 220 x 360 around each map's world origin (maps sit 1500 apart).
	Dockyard = {
		center = Vector3.new(-1500, 210, 0),
		size = Vector3.new(300, 220, 360),
		beds = {
			{ id = "sfx:AmbHarbour", volume = 0.45 },
			{ id = "sfx:AmbWind", volume = 0.28 },
		},
	},
	Rooftops = {
		center = Vector3.new(1500, 200, 1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "sfx:AmbCity", volume = 0.45 }, { id = "sfx:AmbWind", volume = 0.24 } },
	},
	OldTown = {
		center = Vector3.new(0, 210, 1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "sfx:AmbCity", volume = 0.3 }, { id = "sfx:AmbWind", volume = 0.2 } },
	},
	Snowpeak = {
		center = Vector3.new(-1500, 210, -1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "sfx:AmbWind", volume = 0.42 } },
	},
	Metro = { -- an underground station: the warehouse room tone as the bed
		center = Vector3.new(1500, 200, 0),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "sfx:AmbRoom", volume = 0.45 }, { id = "sfx:AmbHum", volume = 0.12 } },
	},
	Bunker = {
		center = Vector3.new(-1500, 200, 1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "sfx:AmbRoom", volume = 0.45 } },
	},
	Greenhouse = {
		center = Vector3.new(1500, 210, -1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "sfx:AmbWind", volume = 0.18 }, { id = "sfx:AmbRoom", volume = 0.2 } },
	},
	-- Rooftops2: a sunny city block, two team roofs over a sunken Pit. No
	-- enterable rooms, so no room tone. Playable area about 97 x 161 at world
	-- origin (3000, 200, 0); the box takes in the drop to the street.
	Rooftops2 = {
		center = Vector3.new(3000, 190, 0),
		size = Vector3.new(300, 220, 360),
		beds = {
			{ id = "sfx:AmbCity", volume = 0.45 }, -- the city below: traffic, a train
			{ id = "sfx:AmbWind", volume = 0.24 }, -- wind across the roofs
		},
	},
}

local SPOTS: { [string]: Spot } = {
	-- Rooftops2 ------------------------------------------------------------
	-- Rooftop air-conditioning units, a loop at each.
	AC = { id = "sfx:AmbAC", volume = 0.55, range = 40, loop = true, pitch = { 1 } },
	-- Pigeons cooing on the ledges and tank houses.
	Pigeon = {
		id = "sfx:AmbPigeon",
		volume = 0.5,
		range = 60,
		pitch = { 0.94, 1.06 },
		interval = { 12, 28 },
	},
	-- A pigeon taking off.
	Flap = {
		id = "sfx:AmbFlap",
		volume = 0.45,
		range = 70,
		pitch = { 0.92, 1.08 },
		interval = { 25, 55 },
	},
	-- Car horns in the street below.
	CarHorn = {
		id = "sfx:AmbCarHorn",
		volume = 0.5,
		range = 170,
		pitch = { 0.95, 1.05 },
		interval = { 15, 35 },
	},
	-- Sirens far off across the city.
	Siren = {
		id = "sfx:AmbSiren",
		volume = 0.6,
		range = 1200,
		pitch = { 0.97, 1.03 },
		interval = { 35, 75 },
	},
	-- Dockyard2 ------------------------------------------------------------
	-- Water lapping against the pier: a loop at each quay edge emitter.
	Water = { id = "sfx:AmbWater", volume = 0.7, range = 60, loop = true },
	-- The crane's motor, a low hum (a real motor recording played slower).
	CraneHum = { id = "sfx:AmbHum", volume = 0.45, range = 60, loop = true, pitch = { 0.62 } },
	-- Gulls over the water.
	Gulls = {
		id = "sfx:AmbGulls",
		volume = 0.55,
		range = 180,
		pitch = { 0.94, 1.08 },
		interval = { 10, 24 },
	},
	-- A distant ship's horn, rare.
	Horn = {
		id = "sfx:AmbHorn",
		volume = 0.6,
		range = 1200,
		pitch = { 0.92, 1.0 },
		interval = { 40, 80 },
	},
	-- Metal creaks in the container stacks.
	Creak = {
		id = "sfx:AmbCreak",
		volume = 0.4,
		range = 45,
		pitch = { 0.85, 1.1 },
		interval = { 14, 32 },
	},
}

return table.freeze({
	TAG_EMITTER = "AmbienceEmitter",
	TAG_INDOOR = "AmbienceIndoor",
	-- Positional loops alive at once (the nearest win): a mobile-friendly cap.
	MAX_LOOPS = 4,
	TICK = 0.2, -- seconds between checks (map, indoor, emitters)
	FADE = 1.5, -- seconds to fade beds between maps
	INDOOR = table.freeze({
		blend = 0.6, -- seconds to cross between outdoor and indoor
		outdoorVolume = 0.35, -- the outdoor bus's share while indoors
		highCut = -16, -- dB on the outdoor bus's highs while indoors (walls muffle)
		midCut = -6,
	}),
	MAPS = table.freeze(MAPS),
	SPOTS = table.freeze(SPOTS),
})
