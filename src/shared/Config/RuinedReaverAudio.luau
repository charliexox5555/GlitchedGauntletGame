--!strict
local GunSoundAssets = require(script.Parent.GunSoundAssets)

export type Layer = {
	id: string,
	volume: number,
	pitch: number,
	start: number?,
	cut: number?,
}

-- Roblox Creator Store recordings by Pro Sound Effects. Lengths measured in Match Studio.
local takes: { [string]: { GunSoundAssets.Take } } = {
	grit = { { asset = "rbxassetid://9114657970", gain = 1, length = 1.003 } },
	edge = { { asset = "rbxassetid://9125900174", gain = 1, length = 1.493 } },
	grip = { { asset = "rbxassetid://9116193501", gain = 1, length = 0.462 } },
	bronze = { { asset = "rbxassetid://9113132124", gain = 1, length = 0.772 } },
	shards = { { asset = "rbxassetid://9125874341", gain = 1, length = 1.570 } },
	resonance = { { asset = "rbxassetid://9125644410", gain = 1, length = 2.069 } },
}

local swings: { [string]: { Layer } } = {
	Slash1 = {
		{ id = "reaver:edge", volume = 0.21, pitch = 1.16, start = 0.053, cut = 0.20 },
		{ id = "reaver:grit", volume = 0.065, pitch = 1.23, start = 0.115, cut = 0.20 },
	},
	Slash2 = {
		{ id = "reaver:edge", volume = 0.17, pitch = 1.30, start = 0.052, cut = 0.18 },
		{ id = "reaver:grit", volume = 0.045, pitch = 1.31, start = 0.11, cut = 0.17 },
	},
	Slash3 = {
		{ id = "reaver:edge", volume = 0.24, pitch = 1.06, start = 0.047, cut = 0.25 },
		{ id = "reaver:grit", volume = 0.085, pitch = 1.08, start = 0.12, cut = 0.25 },
	},
	HeavyStab = {
		{ id = "reaver:edge", volume = 0.31, pitch = 0.84, start = 0.062, cut = 0.33 },
		{ id = "reaver:grit", volume = 0.12, pitch = 0.78, start = 0.135, cut = 0.33 },
	},
}

local inspectGrip: { Layer } = {
	{ id = "reaver:grip", volume = 0.32, pitch = 0.96 },
	{ id = "reaver:bronze", volume = 0.095, pitch = 1.08, cut = 0.18 },
}

local inspectSplit: { Layer } = {
	{ id = "reaver:shards", volume = 0.14, pitch = 1.05, start = 0.12, cut = 0.48 },
	{ id = "reaver:resonance", volume = 0.12, pitch = 0.84, start = 0.20, cut = 2.30 },
}

return {
	takes = takes,
	swings = swings,
	swingLead = 0.055,
	inspectGrip = inspectGrip,
	inspectSplit = inspectSplit,
}
