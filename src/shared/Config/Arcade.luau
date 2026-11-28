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
	chaseFrom: number, -- inspect progress (0..1) where the button chase starts
	chaseTo: number,
	chaseSteps: number, -- buttons lit in turn over the chase
	finaleFrom: number, -- all three lit together
	finaleTo: number,
}

-- Every Arcade gun uses the same flat_group part names on its fixed Root bone
-- (vault/02 Art/Skins/Arcade/Gun Brief.md); only the screen's pixel size and the shot's
-- travel differ, from each gun's build script (PX in tools/blender/arcade/<NN>_<gun>.py).
local function profile(pixel: number, shotTravel: number): Profile
	return {
		bone = "Root",
		buttons = { "SK_Root_ARButton1", "SK_Root_ARButton2", "SK_Root_ARButton3" },
		ship = "SK_Root_ARScreenShip",
		shot = "SK_Root_ARScreenShot",
		stars = "SK_Root_ARScreenStars",
		blip = "SK_Root_ARScreenBlip",
		deckLight = "SK_Root_ARDeckLight",
		pixel = pixel,
		shotTravel = shotTravel,
		pressDepth = 0.006,
		fireTime = 0.12,
		seatTime = 0.3,
		shipBob = 0.55,
		starBlink = 0.42,
		chaseFrom = 0.16,
		chaseTo = 0.6,
		chaseSteps = 9,
		finaleFrom = 0.62,
		finaleTo = 0.78,
	}
end

local profiles: { [string]: Profile } = {
	Vandal = profile(0.0085, 4),
	Phantom = profile(0.0085, 4),
	Spectre = profile(0.0085, 4),
	Guardian = profile(0.0085, 4),
	Bulldog = profile(0.0085, 4),
	Odin = profile(0.0085, 4),
	Operator = profile(0.0115, 4),
	Marshal = profile(0.0075, 3),
	Bucky = profile(0.011, 3),
	Stinger = profile(0.0085, 4),
	Classic = profile(0.0055, 3),
	Sheriff = profile(0.0085, 3),
	Shorty = profile(0.0072, 3),
	Ghost = profile(0.00484, 3),
}

return table.freeze(profiles)
