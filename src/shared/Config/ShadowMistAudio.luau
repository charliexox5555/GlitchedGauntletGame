--!strict
-- Private group audio from vault/06 Assets/RuinationType.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	fireFirst = {
		{ asset = "rbxassetid://123166450710947", length = 0.507104, gain = 1 }, -- Shot01_first.wav
	},
	fire = {
		{ asset = "rbxassetid://87203558517059", length = 0.507104, gain = 1 }, -- Shot01.wav
		{ asset = "rbxassetid://104068372047591", length = 0.507104, gain = 1 }, -- Shot02.wav
		{ asset = "rbxassetid://113756583156411", length = 0.507104, gain = 1 }, -- Shot03.wav
		{ asset = "rbxassetid://102077165598838", length = 0.507104, gain = 1 }, -- Shot04.wav
		{ asset = "rbxassetid://85324740541804", length = 0.507104, gain = 1 }, -- Shot05.wav
		{ asset = "rbxassetid://132768767668510", length = 0.507104, gain = 1 }, -- Shot06.wav
		{ asset = "rbxassetid://73763731187567", length = 0.507104, gain = 1 }, -- Shot07.wav
		{ asset = "rbxassetid://134614608789507", length = 0.507104, gain = 1 }, -- Shot08.wav
	},
	fireLast = {
		{ asset = "rbxassetid://105168159199489", length = 2.531687, gain = 1 }, -- Lastwithtail.wav
	},
	tail = {
		{ asset = "rbxassetid://91127806282382", length = 2.531687, gain = 1 }, -- Shot_00_Tail_only_01.wav
	},
	drawAir = {
		{ asset = "rbxassetid://71837714958039", length = 0.486500, gain = 1 }, -- Draw_air.wav
	},
	lock = {
		{ asset = "rbxassetid://127777880181237", length = 1.000000, gain = 1 }, -- Draw shard lock and reload seat accent.wav
	},
	rack = {
		{ asset = "rbxassetid://113756944229245", length = 0.486500, gain = 1 }, -- Cock1.wav
		{ asset = "rbxassetid://74691334536930", length = 0.486500, gain = 1 }, -- Cock2.wav
		{ asset = "rbxassetid://125319969265943", length = 0.486500, gain = 1 }, -- Cock3.wav
		{ asset = "rbxassetid://73467317635310", length = 0.486500, gain = 1 }, -- Cock4.wav
	},
	magOut = {
		{ asset = "rbxassetid://134064518746759", length = 0.500000, gain = 1 }, -- MagUnload01.wav
		{ asset = "rbxassetid://129168958134982", length = 0.446021, gain = 1 }, -- MagUnload02.wav
		{ asset = "rbxassetid://108521518892061", length = 0.500000, gain = 1 }, -- MagUnload03.wav
		{ asset = "rbxassetid://109960864342083", length = 0.446021, gain = 1 }, -- MagUnload04.wav
	},
	magIn = {
		{ asset = "rbxassetid://125296274850275", length = 0.862375, gain = 1 }, -- MagSeats01.wav
		{ asset = "rbxassetid://121824390120130", length = 0.862375, gain = 1 }, -- MagSeats02.wav
		{ asset = "rbxassetid://76003347763419", length = 0.862375, gain = 1 }, -- MagSeats03.wav
		{ asset = "rbxassetid://128570236121668", length = 0.862375, gain = 1 }, -- MagSeats04.wav
		{ asset = "rbxassetid://81769911531496", length = 0.862375, gain = 1 }, -- MagSeats05.wav
	},
	magForm = {
		{ asset = "rbxassetid://75609328597756", length = 0.726500, gain = 1 }, -- MagMaterializing.wav
	},
	magThrow = {
		{ asset = "rbxassetid://77178489004439", length = 0.486500, gain = 1 }, -- MagGrabbedandthrown.wav
	},
	inspect = {
		{ asset = "rbxassetid://126131354441128", length = 0.646500, gain = 1 }, -- StartingInspect.wav
	},
	inspectBed = {
		{ asset = "rbxassetid://124013117464568", length = 2.000000, gain = 1 }, -- DuringInspect.wav
	},
	guardianFire = {
		{ asset = "rbxassetid://139432816401942", length = 2.191729, gain = 1 }, -- Shot01.wav
		{ asset = "rbxassetid://75783865517916", length = 2.478354, gain = 1 }, -- Shot02.wav
		{ asset = "rbxassetid://84311425100097", length = 2.354875, gain = 1 }, -- Shot03.wav
		{ asset = "rbxassetid://108480473573709", length = 2.510271, gain = 1 }, -- Shot04.wav
	},
	spectreFire = {
		{ asset = "rbxassetid://109755573843533", length = 0.507104, gain = 1 }, -- Shot01.wav
		{ asset = "rbxassetid://87853184716071", length = 0.507104, gain = 1 }, -- Shot02.wav
		{ asset = "rbxassetid://128322655351838", length = 0.507104, gain = 1 }, -- Shot03.wav
		{ asset = "rbxassetid://137890441151198", length = 0.507104, gain = 1 }, -- Shot04.wav
		{ asset = "rbxassetid://80432823582003", length = 0.507104, gain = 1 }, -- Shot05.wav
		{ asset = "rbxassetid://112224327060233", length = 0.507104, gain = 1 }, -- Shot06.wav
		{ asset = "rbxassetid://95611891993665", length = 0.507104, gain = 1 }, -- Shot07.wav
		{ asset = "rbxassetid://94749737304028", length = 0.507104, gain = 1 }, -- Shot08.wav
		{ asset = "rbxassetid://71538550686790", length = 0.507104, gain = 1 }, -- Shot09.wav
	},
	spectreFirst = {
		{ asset = "rbxassetid://113650874213693", length = 0.507104, gain = 1 }, -- Shot00_first_01.wav
	},
	spectreLast = {
		{ asset = "rbxassetid://83416211571926", length = 1.858812, gain = 1 }, -- Shot00_last_with_tail_01.wav
	},
	spectreTail = {
		{ asset = "rbxassetid://110132616148222", length = 1.858812, gain = 1 }, -- shot_00_tail_only_01.wav
	},
	operatorFire = {
		{ asset = "rbxassetid://120583832473036", length = 4.593750, gain = 1 }, -- Shot01.wav
		{ asset = "rbxassetid://128544658070365", length = 4.593750, gain = 1 }, -- Shot02.wav
		{ asset = "rbxassetid://71787565006684", length = 4.593750, gain = 1 }, -- Shot03.wav
		{ asset = "rbxassetid://71839253682558", length = 4.593750, gain = 1 }, -- Shot04.wav
	},
	ghostFire = {
		{ asset = "rbxassetid://125900247843077", length = 1.573875, gain = 1 }, -- Shot01.wav
		{ asset = "rbxassetid://129887493656211", length = 1.521344, gain = 1 }, -- Shot02.wav
		{ asset = "rbxassetid://75037205452819", length = 1.739969, gain = 1 }, -- Shot03.wav
		{ asset = "rbxassetid://132487182722121", length = 1.521344, gain = 1 }, -- Shot04.wav
	},
}

local function cue(name: string, volume: number): GunSounds.GunSound
	return { id = "shadow:" .. name, volume = volume }
end

type Report = {
	fire: GunSounds.GunSound,
	fireFirst: GunSounds.GunSound?,
	fireLast: GunSounds.GunSound?,
	tail: GunSounds.GunSound?,
}

local reports: { [string]: Report } = {
	Vandal = {
		fire = cue("fire", 1),
		fireFirst = cue("fireFirst", 1),
		fireLast = cue("fireLast", 1),
		tail = cue("tail", 0.65),
	},
	Guardian = { fire = cue("guardianFire", 0.92) },
	Spectre = {
		fire = cue("spectreFire", 0.92),
		fireFirst = cue("spectreFirst", 0.92),
		fireLast = cue("spectreLast", 0.92),
		tail = cue("spectreTail", 0.65),
	},
	Operator = { fire = cue("operatorFire", 0.9) },
	Ghost = { fire = cue("ghostFire", 0.92) },
}

return table.freeze({
	takes = takes,
	reports = reports,
	drawAir = cue("drawAir", 0.72),
	lock = cue("lock", 0.64),
	magForm = cue("magForm", 0.83),
	magThrow = cue("magThrow", 0.64),
	magOut = cue("magOut", 0.75),
	magIn = cue("magIn", 0.8),
	rack = cue("rack", 0.82),
	inspect = cue("inspect", 0.65),
	inspectBed = cue("inspectBed", 0.9),
})
