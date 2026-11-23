--!strict
-- Close Slipframe accents made from the licensed ProPack.
-- One private Roblox asset per take. The stock gun report and tail still play.
local GunSoundAssets = require(script.Parent.GunSoundAssets)
local GunSounds = require(script.Parent.GunSounds)

local takes: { [string]: { GunSoundAssets.Take } } = {
	guardian_shot = { { asset = "rbxassetid://129286388410119", length = 0.12, gain = 1 } },
	vandal_shot = { { asset = "rbxassetid://112835049745152", length = 0.12, gain = 1 } },
	spectre_shot = { { asset = "rbxassetid://97677382044836", length = 0.12, gain = 1 } },
	operator_shot = { { asset = "rbxassetid://137778108574056", length = 0.12, gain = 1 } },
	classic_shot = { { asset = "rbxassetid://122799416376691", length = 0.12, gain = 1 } },
	draw = { { asset = "rbxassetid://127653726560680", length = 0.133, gain = 1 } },
	mag_seat = { { asset = "rbxassetid://89087749170620", length = 0.12, gain = 1 } },
	inspect_open = { { asset = "rbxassetid://81642817945001", length = 0.165, gain = 1 } },
	inspect_seat = { { asset = "rbxassetid://85429031347948", length = 0.12, gain = 1 } },
	arc_draw = { { asset = "rbxassetid://120552544886095", length = 0.185, gain = 1 } },
	arc_release = { { asset = "rbxassetid://110408890101293", length = 0.18602, gain = 1 } },
	arc_seat = { { asset = "rbxassetid://129452873743582", length = 0.12, gain = 1 } },
	arc_slash = { { asset = "rbxassetid://139472976624310", length = 0.15702, gain = 1 } },
	arc_heavy = { { asset = "rbxassetid://84071723307365", length = 0.23702, gain = 1 } },
}

local function cue(name: string, volume: number): GunSounds.GunSound
	return { id = "slipframe:" .. name, volume = volume, pitch = { 0.98, 1.02 } }
end

local shots: { [string]: GunSounds.GunSound } = {
	Guardian = cue("guardian_shot", 0.19),
	Vandal = cue("vandal_shot", 0.16),
	Spectre = cue("spectre_shot", 0.22),
	Operator = cue("operator_shot", 0.2),
	Classic = cue("classic_shot", 0.24),
}

local handling: { [string]: GunSounds.GunSound } = {
	SlipframeDraw = cue("draw", 0.30),
	MagIn = cue("mag_seat", 0.27),
	SlipframeInspectOpen = cue("inspect_open", 0.38),
	SlipframeInspectSeat = cue("inspect_seat", 0.31),
}

local handlingPitch: { [string]: number } = {
	Vandal = 1.02,
	Spectre = 1.07,
	Operator = 0.92,
	Classic = 1.09,
}

return table.freeze({
	takes = takes,
	shots = shots,
	handling = handling,
	handlingPitch = handlingPitch,
	arc = table.freeze({
		draw = cue("arc_draw", 0.28),
		release = cue("arc_release", 0.37),
		seat = cue("arc_seat", 0.33),
		slash = cue("arc_slash", 0.19),
		heavy = cue("arc_heavy", 0.25),
	}),
	-- Match the draw wake-up and the insert lift and seat in SlipframeEffects.
	drawAt = 0.58,
	inspectOpenAt = 0.22,
	inspectSeatAt = 0.84,
})
