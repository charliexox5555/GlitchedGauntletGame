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
			{ id = "atlas:AmbHarbour", volume = 0.45 }, -- distant harbour and industry
			{ id = "atlas:AmbWind", volume = 0.28 }, -- wind
		},
		room = { id = "atlas:AmbRoom", volume = 0.55 }, -- inside the sheds
	},
	-- The older maps: beds only (a hook; no emitters or rooms placed yet). Boxes
	-- are 300 x 220 x 360 around each map's world origin (maps sit 1500 apart).
	Dockyard = {
		center = Vector3.new(-1500, 210, 0),
		size = Vector3.new(300, 220, 360),
		beds = {
			{ id = "atlas:AmbHarbour", volume = 0.45 },
			{ id = "atlas:AmbWind", volume = 0.28 },
		},
	},
	Rooftops = {
		center = Vector3.new(1500, 200, 1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "atlas:AmbCity", volume = 0.45 }, { id = "atlas:AmbWind", volume = 0.24 } },
	},
	OldTown = {
		center = Vector3.new(0, 210, 1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "atlas:AmbCity", volume = 0.3 }, { id = "atlas:AmbWind", volume = 0.2 } },
	},
	Snowpeak = {
		center = Vector3.new(-1500, 210, -1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "atlas:AmbWind", volume = 0.42 } },
	},
	Metro = { -- an underground station: the warehouse room tone as the bed
		center = Vector3.new(1500, 200, 0),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "atlas:AmbRoom", volume = 0.45 }, { id = "atlas:AmbHum", volume = 0.12 } },
	},
	Bunker = {
		center = Vector3.new(-1500, 200, 1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "atlas:AmbRoom", volume = 0.45 } },
	},
	Greenhouse = {
		center = Vector3.new(1500, 210, -1500),
		size = Vector3.new(300, 220, 360),
		beds = { { id = "atlas:AmbWind", volume = 0.18 }, { id = "atlas:AmbRoom", volume = 0.2 } },
	},
	-- Rooftops2: a sunny city block, two team roofs over a sunken Pit. No
	-- enterable rooms, so no room tone. Playable area about 97 x 161 at world
	-- origin (3000, 200, 0); the box takes in the drop to the street.
	Rooftops2 = {
		center = Vector3.new(3000, 190, 0),
		size = Vector3.new(300, 220, 360),
		beds = {
			{ id = "atlas:AmbCity", volume = 0.45 }, -- the city below: traffic, a train
			{ id = "atlas:AmbWind", volume = 0.24 }, -- wind across the roofs
		},
	},
}

local SPOTS: { [string]: Spot } = {
	-- Rooftops2 ------------------------------------------------------------
	-- Rooftop air-conditioning units, a loop at each.
	AC = { id = "atlas:AmbAC", volume = 0.55, range = 40, loop = true, pitch = { 1 } },
	-- Pigeons cooing on the ledges and tank houses.
	Pigeon = {
		id = "atlas:AmbPigeon",
		volume = 0.5,
		range = 60,
		pitch = { 0.94, 1.06 },
		interval = { 12, 28 },
	},
	-- A pigeon taking off.
	Flap = {
		id = "atlas:AmbFlap",
		volume = 0.45,
		range = 70,
		pitch = { 0.92, 1.08 },
		interval = { 25, 55 },
	},
	-- Car horns in the street below.
	CarHorn = {
		id = "atlas:AmbCarHorn",
		volume = 0.5,
		range = 170,
		pitch = { 0.95, 1.05 },
		interval = { 15, 35 },
	},
	-- Sirens far off across the city.
	Siren = {
		id = "atlas:AmbSiren",
		volume = 0.6,
		range = 1200,
		pitch = { 0.97, 1.03 },
		interval = { 35, 75 },
	},
	-- Dockyard2 ------------------------------------------------------------
	-- Water lapping against the pier: a loop at each quay edge emitter.
	Water = { id = "atlas:AmbWater", volume = 0.7, range = 60, loop = true },
	-- The crane's motor, a low hum (a real motor recording played slower).
	CraneHum = { id = "atlas:AmbHum", volume = 0.45, range = 60, loop = true, pitch = { 0.62 } },
	-- Gulls over the water.
	Gulls = {
		id = "atlas:AmbGulls",
		volume = 0.55,
		range = 180,
		pitch = { 0.94, 1.08 },
		interval = { 10, 24 },
	},
	-- A distant ship's horn, rare.
	Horn = {
		id = "atlas:AmbHorn",
		volume = 0.6,
		range = 1200,
		pitch = { 0.92, 1.0 },
		interval = { 40, 80 },
	},
	-- Metal creaks in the container stacks.
	Creak = {
		id = "atlas:AmbCreak",
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
