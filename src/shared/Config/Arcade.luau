--!strict
-- Arcade skin line (Season 1 battle pass, Rare): first-person cabinet effects
-- (Util/ArcadeEffects, vault/02 Art/Skins/Arcade/Build Ledger.md).
-- Distances are unscaled studs in the imported cosmetic mesh's axes:
-- local -X points toward the muzzle, +Y up and +Z out of the left face.
export type Profile = {
	bone: string,
	buttons: { string }, -- flat_group parts, rear to front
	ship: string,
	shot: string,
	stars: string,
	blip: string?,
	deckLight: string?, -- flashes the lit button's colour (visible in the hip hold)
	pixel: number, -- one screen pixel
	shotTravel: number, -- pixels the shot moves per fire pulse
	pressDepth: number, -- how far a button sinks on a shot
	fireTime: number, -- press and light, seconds
	seatTime: number, -- all buttons flash when the mag seats
	shipBob: number, -- seconds per idle ship bob step
	starBlink: number, -- seconds per idle star blink
	chaseStep: number, -- inspect chase, seconds per button
}

local profiles: { [string]: Profile } = {
	Vandal = {
		bone = "Root",
		buttons = { "SK_Root_ARButton1", "SK_Root_ARButton2", "SK_Root_ARButton3" },
		ship = "SK_Root_ARScreenShip",
		shot = "SK_Root_ARScreenShot",
		stars = "SK_Root_ARScreenStars",
		blip = "SK_Root_ARScreenBlip",
		deckLight = "SK_Root_ARDeckLight",
		pixel = 0.0085,
		shotTravel = 4,
		pressDepth = 0.006,
		fireTime = 0.12,
		seatTime = 0.3,
		shipBob = 0.55,
		starBlink = 0.42,
		chaseStep = 0.09,
	},
}

return table.freeze(profiles)
