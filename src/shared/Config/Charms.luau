--!strict
-- All 32 weapon charms (Season 1 Battle Pass + Strike Pack + Overdrive Pack).
-- Models live in ReplicatedStorage.Charms.<Id> (installed via tools/studio/BuildCharms.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(script.Parent.Weapons)

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"
export type Source = "BattlePass" | "StrikePack" | "OverdrivePack"

export type FxSpec = {
	idle: string,
	fire: string,
	kill: string,
	screen: ("counter" | "radar")?,
	spinAxis: Vector3?,
	spinSpeed: number?,
	stickTilt: boolean?,
}

export type CharmDef = {
	id: string,
	name: string,
	rarity: Rarity,
	source: Source,
	description: string,
	accent: Color3,
	weight: number,
	scale: number?,
	fx: FxSpec,
}

local Charms = {}

Charms.CHARM_SCALE = 0.56

-- Dynamic per-class & per-gun multipliers so charms fit compact sidearms
-- without crowding while staying readable on full-length rifles and LMGs.
Charms.CLASS_SCALE = {
	Sidearm = 0.72,
	SMG = 0.86,
	Shotgun = 0.96,
	Rifle = 1.00,
	Sniper = 1.06,
	MachineGun = 1.10,
} :: { [string]: number }

Charms.GUN_SCALE = {
	Classic = 0.68,
	Shorty = 0.70,
	Akimbo = 0.68,
	Ghost = 0.72,
	Sheriff = 0.78,
	Stinger = 0.84,
	Spectre = 0.88,
	Bulldog = 0.94,
	Judge = 0.96,
	Bucky = 0.98,
	Phantom = 1.00,
	Vandal = 1.00,
	Guardian = 1.02,
	Marshal = 1.02,
	Ares = 1.08,
	Operator = 1.08,
	Odin = 1.12,
} :: { [string]: number }

Charms.DUPLICATE_COINS = {
	Common = 100,
	Rare = 250,
	Epic = 500,
	Legendary = 1000,
}

Charms.DEFS = {
	-- Season 1 Battle Pass (8)
	ArcadeToken = {
		id = "ArcadeToken",
		name = "ARCADE TOKEN",
		rarity = "Common",
		source = "BattlePass",
		description = "Stamped gold Draft Duels arcade token.",
		accent = Color3.fromRGB(245, 194, 56),
		weight = 1.0,
		fx = { idle = "sheen", fire = "glint", kill = "coinburst" },
	},
	IceCube = {
		id = "IceCube",
		name = "ICE CUBE",
		rarity = "Rare",
		source = "BattlePass",
		description = "Frosted ice cube locked inside a corner clasp.",
		accent = Color3.fromRGB(136, 230, 255),
		weight = 1.15,
		scale = 0.88,
		fx = { idle = "frost", fire = "frostpuff", kill = "frostnova" },
	},
	Joystick = {
		id = "Joystick",
		name = "JOYSTICK",
		rarity = "Rare",
		source = "BattlePass",
		description = "Arcade flight stick that tilts with recoil.",
		accent = Color3.fromRGB(0, 229, 255),
		weight = 0.95,
		fx = { idle = "neon", fire = "stickkick", kill = "arcadeburst", stickTilt = true },
	},
	PixelHeart = {
		id = "PixelHeart",
		name = "PIXEL HEART",
		rarity = "Rare",
		source = "BattlePass",
		description = "Glowing 8-bit life heart with beveled frame.",
		accent = Color3.fromRGB(255, 62, 136),
		weight = 0.90,
		fx = { idle = "heartbeat", fire = "pulse", kill = "heartburst" },
	},
	SnowflakeShard = {
		id = "SnowflakeShard",
		name = "SNOWFLAKE SHARD",
		rarity = "Rare",
		source = "BattlePass",
		description = "Six-pointed crystalline winter star.",
		accent = Color3.fromRGB(150, 238, 255),
		weight = 0.95,
		fx = { idle = "frost", fire = "frostpuff", kill = "frostnova" },
	},
	GameCartridge = {
		id = "GameCartridge",
		name = "GAME CARTRIDGE",
		rarity = "Epic",
		source = "BattlePass",
		description = "Retro ROM cartridge with illuminated gold pins.",
		accent = Color3.fromRGB(63, 224, 242),
		weight = 1.05,
		fx = { idle = "glitch", fire = "spark", kill = "glitchburst" },
	},
	ThunderOrb = {
		id = "ThunderOrb",
		name = "THUNDER ORB",
		rarity = "Epic",
		source = "BattlePass",
		description = "High-voltage core suspended between twin coils.",
		accent = Color3.fromRGB(255, 212, 62),
		weight = 1.10,
		fx = { idle = "electric", fire = "arc", kill = "thunderburst" },
	},
	HighScore = {
		id = "HighScore",
		name = "HIGH SCORE",
		rarity = "Legendary",
		source = "BattlePass",
		description = "Live miniature scoreboard tracking your match kills.",
		accent = Color3.fromRGB(255, 198, 52),
		weight = 1.10,
		fx = { idle = "neon", fire = "pulse", kill = "scorepop", screen = "counter" },
	},

	-- Strike Pack (12)
	DraftTicket = {
		id = "DraftTicket",
		name = "DRAFT TICKET",
		rarity = "Common",
		source = "StrikePack",
		description = "Embossed arena entry ticket.",
		accent = Color3.fromRGB(245, 192, 54),
		weight = 0.85,
		fx = { idle = "sheen", fire = "glint", kill = "coinburst" },
	},
	BrassBullet = {
		id = "BrassBullet",
		name = "BRASS BULLET",
		rarity = "Common",
		source = "StrikePack",
		description = "Heavy caliber FMJ pendant.",
		accent = Color3.fromRGB(228, 174, 52),
		weight = 1.25,
		fx = { idle = "sheen", fire = "glint", kill = "sparkburst" },
	},
	DogTags = {
		id = "DogTags",
		name = "DOG TAGS",
		rarity = "Common",
		source = "StrikePack",
		description = "Twin brushed steel arena tags.",
		accent = Color3.fromRGB(180, 190, 206),
		weight = 0.90,
		fx = { idle = "sheen", fire = "glint", kill = "sparkburst" },
	},
	FragPin = {
		id = "FragPin",
		name = "FRAG PIN",
		rarity = "Common",
		source = "StrikePack",
		description = "Pulled brass safety ring and spoon lever.",
		accent = Color3.fromRGB(240, 188, 58),
		weight = 0.95,
		fx = { idle = "sheen", fire = "glint", kill = "sparkburst" },
	},
	MiniHelmet = {
		id = "MiniHelmet",
		name = "MINI HELMET",
		rarity = "Rare",
		source = "StrikePack",
		description = "Tactical visor helmet with cyan optics.",
		accent = Color3.fromRGB(63, 224, 242),
		weight = 1.15,
		fx = { idle = "neon", fire = "pulse", kill = "electricburst" },
	},
	TargetPlate = {
		id = "TargetPlate",
		name = "TARGET PLATE",
		rarity = "Rare",
		source = "StrikePack",
		description = "Range gong scarred by a tight shot.",
		accent = Color3.fromRGB(237, 50, 68),
		weight = 1.10,
		fx = { idle = "sheen", fire = "glint", kill = "crimsonburst" },
	},
	FragGrenade = {
		id = "FragGrenade",
		name = "FRAG GRENADE",
		rarity = "Rare",
		source = "StrikePack",
		description = "Miniaturized pineapple fragmentation shell.",
		accent = Color3.fromRGB(112, 168, 108),
		weight = 1.30,
		fx = { idle = "sheen", fire = "spark", kill = "emberburst" },
	},
	MicroBlade = {
		id = "MicroBlade",
		name = "MICRO BLADE",
		rarity = "Rare",
		source = "StrikePack",
		description = "Double-beveled tanto knife pendant.",
		accent = Color3.fromRGB(203, 213, 230),
		weight = 0.90,
		fx = { idle = "sheen", fire = "glint", kill = "sparkburst" },
	},
	MoltenCore = {
		id = "MoltenCore",
		name = "MOLTEN CORE",
		rarity = "Epic",
		source = "StrikePack",
		description = "Superheated magma shard caged in gunmetal.",
		accent = Color3.fromRGB(255, 110, 32),
		weight = 1.15,
		fx = { idle = "ember", fire = "emberflare", kill = "emberburst" },
	},
	GlitchDie = {
		id = "GlitchDie",
		name = "GLITCH DIE",
		rarity = "Epic",
		source = "StrikePack",
		description = "Corner-mounted die pulsing with magenta pips.",
		accent = Color3.fromRGB(255, 76, 212),
		weight = 1.05,
		fx = { idle = "glitch", fire = "spark", kill = "glitchburst" },
	},
	CrownTrophy = {
		id = "CrownTrophy",
		name = "CROWN TROPHY",
		rarity = "Legendary",
		source = "StrikePack",
		description = "Imperial tournament crown with amber crest.",
		accent = Color3.fromRGB(255, 210, 74),
		weight = 1.20,
		fx = { idle = "goldglint", fire = "pulse", kill = "coinburst" },
	},
	AceSkull = {
		id = "AceSkull",
		name = "ACE SKULL",
		rarity = "Legendary",
		source = "StrikePack",
		description = "Carved titanium skull whose eyes flare on kills.",
		accent = Color3.fromRGB(255, 62, 82),
		weight = 1.20,
		fx = { idle = "crimson", fire = "pulse", kill = "crimsonburst" },
	},

	-- Overdrive Pack (12)
	HazardSign = {
		id = "HazardSign",
		name = "HAZARD SIGN",
		rarity = "Common",
		source = "OverdrivePack",
		description = "High-visibility caution triangle.",
		accent = Color3.fromRGB(245, 186, 40),
		weight = 0.90,
		fx = { idle = "sheen", fire = "glint", kill = "sparkburst" },
	},
	BatteryCell = {
		id = "BatteryCell",
		name = "BATTERY CELL",
		rarity = "Common",
		source = "OverdrivePack",
		description = "Segmented cyan energy cell.",
		accent = Color3.fromRGB(63, 224, 242),
		weight = 1.05,
		fx = { idle = "neon", fire = "pulse", kill = "electricburst" },
	},
	CompassRose = {
		id = "CompassRose",
		name = "COMPASS ROSE",
		rarity = "Common",
		source = "OverdrivePack",
		description = "Four-point steel and gold tactical star.",
		accent = Color3.fromRGB(245, 194, 56),
		weight = 0.95,
		fx = { idle = "sheen", fire = "glint", kill = "coinburst" },
	},
	Keycard = {
		id = "Keycard",
		name = "KEYCARD",
		rarity = "Common",
		source = "OverdrivePack",
		description = "Slotted security pass with gold smart chip.",
		accent = Color3.fromRGB(242, 190, 56),
		weight = 0.85,
		fx = { idle = "sheen", fire = "glint", kill = "sparkburst" },
	},
	DashWing = {
		id = "DashWing",
		name = "DASH WING",
		rarity = "Rare",
		source = "OverdrivePack",
		description = "Aerodynamic wing with glowing slipstream vanes.",
		accent = Color3.fromRGB(63, 224, 242),
		weight = 0.85,
		fx = { idle = "neon", fire = "pulse", kill = "electricburst" },
	},
	FrostCrystal = {
		id = "FrostCrystal",
		name = "FROST CRYSTAL",
		rarity = "Rare",
		source = "OverdrivePack",
		description = "Clustered arctic ice spires in a claw socket.",
		accent = Color3.fromRGB(181, 245, 255),
		weight = 1.05,
		fx = { idle = "frost", fire = "frostpuff", kill = "frostnova" },
	},
	ClockworkGear = {
		id = "ClockworkGear",
		name = "CLOCKWORK GEAR",
		rarity = "Rare",
		source = "OverdrivePack",
		description = "Free-spinning brass cogwheel in a gunmetal frame.",
		accent = Color3.fromRGB(235, 184, 66),
		weight = 1.15,
		fx = {
			idle = "sheen",
			fire = "spinkick",
			kill = "coinburst",
			spinAxis = Vector3.zAxis,
			spinSpeed = 2.1,
		},
	},
	MiniTsuba = {
		id = "MiniTsuba",
		name = "MINI TSUBA",
		rarity = "Rare",
		source = "OverdrivePack",
		description = "Katana hilt & octagonal guard with wrapped grip.",
		accent = Color3.fromRGB(72, 216, 255),
		weight = 1.00,
		fx = { idle = "neon", fire = "pulse", kill = "electricburst" },
	},
	PlasmaPrism = {
		id = "PlasmaPrism",
		name = "PLASMA PRISM",
		rarity = "Epic",
		source = "OverdrivePack",
		description = "Violet rift crystal suspended inside three claws.",
		accent = Color3.fromRGB(200, 75, 255),
		weight = 1.10,
		fx = { idle = "plasma", fire = "spark", kill = "plasmaburst" },
	},
	PhantomLantern = {
		id = "PhantomLantern",
		name = "PHANTOM LANTERN",
		rarity = "Epic",
		source = "OverdrivePack",
		description = "Caged spectral core drifting with teal mist.",
		accent = Color3.fromRGB(93, 228, 204),
		weight = 1.10,
		fx = { idle = "mist", fire = "mistpuff", kill = "mistburst" },
	},
	ReactorCore = {
		id = "ReactorCore",
		name = "REACTOR CORE",
		rarity = "Legendary",
		source = "OverdrivePack",
		description = "Gyroscopic containment ring over a cyan singularity.",
		accent = Color3.fromRGB(63, 224, 242),
		weight = 1.25,
		fx = {
			idle = "electric",
			fire = "arc",
			kill = "electricburst",
			spinAxis = Vector3.zAxis,
			spinSpeed = 2.6,
		},
	},
	KillRadar = {
		id = "KillRadar",
		name = "KILL RADAR",
		rarity = "Legendary",
		source = "OverdrivePack",
		description = "Sweeping sonar scope that pings & logs match kills.",
		accent = Color3.fromRGB(63, 240, 212),
		weight = 1.15,
		fx = { idle = "neon", fire = "radarping", kill = "radarlock", screen = "radar" },
	},
} :: { [string]: CharmDef }

Charms.ORDER = {
	-- Season 1 Battle Pass
	"ArcadeToken",
	"IceCube",
	"Joystick",
	"PixelHeart",
	"SnowflakeShard",
	"GameCartridge",
	"ThunderOrb",
	"HighScore",
	-- Strike Pack
	"DraftTicket",
	"BrassBullet",
	"DogTags",
	"FragPin",
	"MiniHelmet",
	"TargetPlate",
	"FragGrenade",
	"MicroBlade",
	"MoltenCore",
	"GlitchDie",
	"CrownTrophy",
	"AceSkull",
	-- Overdrive Pack
	"HazardSign",
	"BatteryCell",
	"CompassRose",
	"Keycard",
	"DashWing",
	"FrostCrystal",
	"ClockworkGear",
	"MiniTsuba",
	"PlasmaPrism",
	"PhantomLantern",
	"ReactorCore",
	"KillRadar",
}

Charms.PACKS = {
	StrikePack = {
		id = "StrikePack",
		name = "STRIKE PACK",
		charms = {
			"DraftTicket",
			"BrassBullet",
			"DogTags",
			"FragPin",
			"MiniHelmet",
			"TargetPlate",
			"FragGrenade",
			"MicroBlade",
			"MoltenCore",
			"GlitchDie",
			"CrownTrophy",
			"AceSkull",
		},
	},
	OverdrivePack = {
		id = "OverdrivePack",
		name = "OVERDRIVE PACK",
		charms = {
			"HazardSign",
			"BatteryCell",
			"CompassRose",
			"Keycard",
			"DashWing",
			"FrostCrystal",
			"ClockworkGear",
			"MiniTsuba",
			"PlasmaPrism",
			"PhantomLantern",
			"ReactorCore",
			"KillRadar",
		},
	},
}

Charms.SOURCE_LABEL = {
	BattlePass = "BATTLE PASS",
	StrikePack = "STRIKE PACK",
	OverdrivePack = "OVERDRIVE PACK",
}

function Charms.get(id: string): CharmDef?
	return Charms.DEFS[id]
end

function Charms.scaleFor(gunId: string?, gunModel: Model?): number
	if gunId then
		local exact = Charms.GUN_SCALE[gunId]
		if exact then
			return exact
		end
		local w = Weapons.get(gunId)
		if w then
			local byClass = Charms.CLASS_SCALE[w.class]
			if byClass then
				return byClass
			end
		end
	end
	if gunModel then
		local _, sz = gunModel:GetBoundingBox()
		local mScale = math.max(gunModel:GetScale(), 0.05)
		local len = math.max(sz.X, sz.Y, sz.Z) / mScale
		return math.clamp(len / 3.98, 0.68, 1.12)
	end
	return 1.0
end

function Charms.exists(id: string): boolean
	return Charms.DEFS[id] ~= nil
end

function Charms.model(id: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("Charms")
	local m = folder and folder:FindFirstChild(id)
	return if m and m:IsA("Model") then m else nil
end

function Charms.all(): { CharmDef }
	local out: { CharmDef } = {}
	for _, id in Charms.ORDER do
		local def = Charms.DEFS[id]
		if def then
			table.insert(out, def)
		end
	end
	return out
end

return Charms
