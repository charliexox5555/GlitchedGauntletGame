--!strict
-- A rendered icon for every charm (Blender, tools/blender/charms/render_icons.py ->
-- tools/render/fit_charm_icons.py; art-source/ui/charm-icons/). UI item art is a render,
-- never a ViewportFrame (owner); Util/CharmThumbnail uses these first.
local ICONS: { [string]: string } = {
	AceSkull = "rbxassetid://105326472602832",
	ArcadeToken = "rbxassetid://75506347257384",
	BatteryCell = "rbxassetid://91510941003422",
	BrassBullet = "rbxassetid://81368302006385",
	ClockworkGear = "rbxassetid://110405176023458",
	CompassRose = "rbxassetid://71347013345694",
	CrownTrophy = "rbxassetid://75523020150372",
	DashWing = "rbxassetid://131338583875701",
	DogTags = "rbxassetid://117858337696862",
	DraftTicket = "rbxassetid://128242049114721",
	FragGrenade = "rbxassetid://89368606393583",
	FragPin = "rbxassetid://88186563903056",
	FrostCrystal = "rbxassetid://113410399492109",
	GameCartridge = "rbxassetid://70491377644123",
	GlitchDie = "rbxassetid://114263233898773",
	HazardSign = "rbxassetid://128286639752867",
	HighScore = "rbxassetid://118699692176227",
	IceCube = "rbxassetid://89709369147465",
	Joystick = "rbxassetid://108924694305508",
	Keycard = "rbxassetid://110050108098409",
	KillRadar = "rbxassetid://93484726406871",
	MicroBlade = "rbxassetid://108459478457539",
	MiniHelmet = "rbxassetid://136099842659318",
	MiniTsuba = "rbxassetid://84272954228255",
	MoltenCore = "rbxassetid://115257175529299",
	PhantomLantern = "rbxassetid://111883064082550",
	PixelHeart = "rbxassetid://133244001168370",
	PlasmaPrism = "rbxassetid://100566184716525",
	ReactorCore = "rbxassetid://140538317358005",
	SnowflakeShard = "rbxassetid://136698529351944",
	TargetPlate = "rbxassetid://109681819670984",
	ThunderOrb = "rbxassetid://105085178808079",
}

local CharmIcons = {}

function CharmIcons.get(charmId: string): string?
	return ICONS[charmId]
end

return table.freeze(CharmIcons)
