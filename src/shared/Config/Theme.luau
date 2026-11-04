--!strict
-- UI v1 tokens (vault/02 Art/UI Design.md, the Figma "Theme" variables): every
-- colour, font and image the UI builders use. Layouts are designed at 1920 x
-- 1080 in Offset and scaled by Util/Ui. Images are white so they tint with
-- ImageColor3; their sources are in art-source/ui (tools/ui_shapes.py,
-- tools/blender/render_ui_gun.py).

local Mods = require(script.Parent.Mods)

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function family(name: string, weight: Enum.FontWeight): Font
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight)
end

export type TextStyle = { font: Font, size: number }

return table.freeze({
	DESIGN = Vector2.new(1920, 1080),

	COLORS = table.freeze({
		scrim = hex("07090D"),
		panel = hex("11151C"),
		card = hex("181D26"),
		raised = hex("212833"),
		hover = hex("2A3340"),
		lineSoft = hex("2C3440"),
		lineStrong = hex("4A5564"),
		text = hex("F5F7FA"),
		textSecondary = hex("A7B0BC"),
		textDim = hex("69727F"),
		onAccent = hex("11151C"),
		ally = Mods.COLORS.ally,
		enemy = Mods.COLORS.enemy,
		gold = hex("FFD23F"),
		glitch = Mods.COLORS.glitch,
		ready = hex("3FD68A"),
		white = Color3.new(1, 1, 1),
	}),

	-- Ability role (Config/Mods `role`) → its tag and card tint.
	ROLE = table.freeze({
		Mobility = hex("2BD9A8"),
		Damage = hex("FF7A3D"),
		Control = hex("C15CFF"),
		Info = hex("4C8DFF"),
		Sustain = hex("6BE36F"),
		["Team buff"] = hex("FFC53D"),
		Escape = hex("8E7CFF"),
	} :: { [string]: Color3 }),

	-- Two families (Oswald for titles and numbers, Montserrat for the rest),
	-- both built into Roblox. Sizes are design pixels at 1080p.
	TEXT = table.freeze({
		displayXL = { font = family("Oswald", Enum.FontWeight.Bold), size = 132 },
		displayL = { font = family("Oswald", Enum.FontWeight.Bold), size = 56 },
		displayM = { font = family("Oswald", Enum.FontWeight.Bold), size = 40 },
		titleCard = { font = family("Oswald", Enum.FontWeight.Bold), size = 44 },
		titleS = { font = family("Oswald", Enum.FontWeight.SemiBold), size = 22 },
		numberHud = { font = family("Oswald", Enum.FontWeight.Bold), size = 76 },
		timer = { font = family("Oswald", Enum.FontWeight.Medium), size = 44 },
		label = { font = family("Montserrat", Enum.FontWeight.Bold), size = 13 },
		bodyM = { font = family("Montserrat", Enum.FontWeight.SemiBold), size = 17 },
		bodyS = { font = family("Montserrat", Enum.FontWeight.Medium), size = 14 },
		key = { font = family("Montserrat", Enum.FontWeight.ExtraBold), size = 16 },
	} :: { [string]: TextStyle }),

	-- 9-slice and plate images. CutFill/CutLine: 128 px with 32 px cuts.
	IMAGE = table.freeze({
		cutFill = "rbxassetid://114001205380779",
		cutLine = "rbxassetid://133929957168839",
		cutSlice = Rect.new(32, 32, 96, 96),
		keyTabFill = "rbxassetid://100556433700426",
		keyTabLine = "rbxassetid://88766408351666",
		plateLeft = "rbxassetid://95460803996667",
		plateRight = "rbxassetid://130204200588244",
		plateTimer = "rbxassetid://71190887271064",
		slant = "rbxassetid://134164025577708",
		shieldFill = "rbxassetid://140143399835490",
		shieldLine = "rbxassetid://110634147222863",
	}),

	ICON = table.freeze({
		Reroll = "rbxassetid://76943756189839",
		Lock = "rbxassetid://125270489944006",
		Shield = "rbxassetid://140209747168333",
		Skull = "rbxassetid://113224984089670",
		Glitch = "rbxassetid://130733349548186",
	}),

	-- Art behind a new ability's card (Config/Mods ids): 760 x 600 images with the
	-- card's cut corner and a bottom fade baked in (tools/ui_chatgpt.py). A card
	-- without one shows its big faded icon instead.
	CARD_ART = table.freeze({} :: { [string]: string }),

	-- Side renders of each gun, muzzle to the right (Config/Weapons ids).
	GUN = table.freeze({
		Akimbo = "rbxassetid://118285175926149",
		Ares = "rbxassetid://96613332773828",
		Bucky = "rbxassetid://88312933499038",
		Bulldog = "rbxassetid://79547096711800",
		Classic = "rbxassetid://118047947087335",
		Ghost = "rbxassetid://91264904103058",
		Guardian = "rbxassetid://95750645844874",
		Judge = "rbxassetid://139952156835621",
		Knife = "rbxassetid://113310955014391",
		Marshal = "rbxassetid://89611157168298",
		Odin = "rbxassetid://128757177107087",
		Operator = "rbxassetid://92451135914779",
		Outlaw = "rbxassetid://121058485145773",
		Phantom = "rbxassetid://105129497036866",
		Sheriff = "rbxassetid://122134937133172",
		Shorty = "rbxassetid://89671651186868",
		Spectre = "rbxassetid://81957247180190",
		Stinger = "rbxassetid://129471363958580",
		Vandal = "rbxassetid://108427985127422",
	} :: { [string]: string }),

	-- Seconds (vault/02 Art/UI Design.md → Motion).
	MOTION = table.freeze({
		select = 0.12,
		enter = 0.25,
		exit = 0.15,
		pop = 0.1,
	}),
})
