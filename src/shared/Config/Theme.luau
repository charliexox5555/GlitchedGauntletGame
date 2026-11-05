--!strict
-- UI v1 tokens (vault/02 Art/UI Design.md, the Figma "Theme" variables): every
-- colour, font and image the UI builders use. Layouts are designed at 1920 x
-- 1080 in Offset and scaled by Util/Ui. Images are white so they tint with
-- ImageColor3; their sources are in art-source/ui (tools/ui_shapes.py,
-- tools/blender/render_ui_gun.py).

local UiStyle = require(script.Parent.UiStyle)

-- v2 (2026-11-05): the match UI shares the Lobby's look. These v1 token names
-- now resolve to Config/UiStyle values, so change colours and fonts THERE.
local S = UiStyle.COLOR
local F = UiStyle.FONT

-- A solid stand-in for "white at alpha over the surface" (dividers, lines).
local function over(alpha: number): Color3
	return S.surface:Lerp(S.white, alpha)
end

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

export type TextStyle = { font: Font, size: number }

return table.freeze({
	DESIGN = Vector2.new(1920, 1080),

	COLORS = table.freeze({
		scrim = S.scrim,
		panel = S.surface,
		card = S.surface,
		raised = S.surfaceSelected,
		hover = S.surfaceHover,
		lineSoft = over(0.14),
		lineStrong = over(0.3),
		text = S.text,
		textSecondary = S.textSecondary,
		textDim = S.textMuted,
		onAccent = S.onPrimary,
		ally = S.ally,
		enemy = S.enemy,
		gold = S.primary,
		glitch = S.glitch,
		ready = S.success,
		white = S.white,
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
	-- v2 type: Montserrat Heavy for display and numbers (wider than v1's
	-- Oswald, so sizes are about 0.8x), Builder Sans for labels and body.
	TEXT = table.freeze({
		displayXL = { font = F.display, size = 104 },
		displayL = { font = F.display, size = 46 },
		displayM = { font = F.display, size = 32 },
		titleCard = { font = F.display, size = 32 },
		titleS = { font = F.label, size = 20 },
		numberHud = { font = F.display, size = 60 },
		timer = { font = F.display, size = 36 },
		label = { font = F.label, size = 15 },
		bodyM = { font = F.body, size = 17 },
		bodyS = { font = F.body, size = 15 },
		key = { font = F.label, size = 16 },
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
	-- card's cut corner and a bottom fade baked in (tools/ui_chatgpt.py, made with ChatGPT). A card
	-- without one shows its big faded icon instead.
	CARD_ART = table.freeze({
		Dash = "rbxassetid://140533506579264",
		Updraft = "rbxassetid://104192200505705",
		Molly = "rbxassetid://85118788731965",
		Firewall = "rbxassetid://74192677647271",
		Frost = "rbxassetid://138876276704481",
		Recon = "rbxassetid://134354078754707",
		HealOrb = "rbxassetid://91450560774587",
		Stim = "rbxassetid://136778934313659",
		Recall = "rbxassetid://81529533451310",
	} :: { [string]: string }),

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
