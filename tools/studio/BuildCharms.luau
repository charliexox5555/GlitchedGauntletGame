--!strict
-- Builds all 32 charm Models in ReplicatedStorage.Charms from their uploaded FBX assets.
-- Generated from art-source/charms/Exports/*.json + assets.json. Save place after running.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type PartSpec = {
	name: string,
	role: string,
	mat: string,
	color: Color3,
	transp: number,
	origin: Vector3,
}

type CharmSpec = {
	id: string,
	asset: number,
	fx: Vector3,
	parts: { PartSpec },
}

local SPECS: { CharmSpec } = {
	{ id = "AceSkull", asset = 100866771500372, fx = Vector3.new(-0.00000, -0.21488, -0.00700), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(62, 71, 91), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(255, 62, 82), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Skull_Bone", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(220, 228, 240), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Skull_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(62, 71, 91), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "ArcadeToken", asset = 132334486018483, fx = Vector3.new(-0.00000, -0.22388, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Token_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(242, 193, 66), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Token_Recess", role = "body", mat = "Metal", color = Color3.fromRGB(184, 126, 26), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "BatteryCell", asset = 104348317935841, fx = Vector3.new(-0.00000, -0.23188, -0.00529), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(63, 224, 242), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Cell_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(54, 63, 82), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Cell_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "BrassBullet", asset = 88563169877494, fx = Vector3.new(-0.00000, -0.24088, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Bullet_Brass", role = "body", mat = "Metal", color = Color3.fromRGB(235, 184, 68), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Bullet_Copper", role = "body", mat = "Metal", color = Color3.fromRGB(212, 110, 58), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "ClockworkGear", asset = 74952172834784, fx = Vector3.new(-0.00000, -0.21627, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Wheel", role = "wheel", mat = "Metal", color = Color3.fromRGB(235, 184, 66), transp = 0.000, origin = Vector3.new(-0.00000, -0.24500, 0.00000) },
		{ name = "Body_Gear_Slate", role = "body", mat = "Metal", color = Color3.fromRGB(54, 62, 80), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "CompassRose", asset = 126104107621502, fx = Vector3.new(-0.00000, -0.22788, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(184, 194, 214), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Comp_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(184, 194, 214), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Comp_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(245, 194, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Comp_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(59, 68, 88), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "CrownTrophy", asset = 89986282200185, fx = Vector3.new(-0.00000, -0.21488, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(245, 192, 54), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(255, 210, 74), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Crown_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(245, 192, 54), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Crown_Dark", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(42, 47, 61), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "DashWing", asset = 98455954939618, fx = Vector3.new(-0.00650, -0.22138, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(63, 224, 242), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Wing_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(46, 53, 69), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Wing_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "DogTags", asset = 89825639920402, fx = Vector3.new(-0.00000, -0.21720, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(180, 190, 206), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Tag_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(180, 190, 206), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Tag_Dark", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(50, 58, 74), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Tag_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(235, 184, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "DraftTicket", asset = 85727738465148, fx = Vector3.new(-0.00000, -0.19888, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Ticket_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(242, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Ticket_Dark", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(46, 53, 69), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "FragGrenade", asset = 122892669232801, fx = Vector3.new(-0.00824, -0.21488, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(141, 151, 168), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Grenade_Olive", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(78, 104, 86), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Grenade_Brass", role = "body", mat = "Metal", color = Color3.fromRGB(238, 186, 58), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(141, 151, 168), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "FragPin", asset = 100464488809750, fx = Vector3.new(-0.00000, -0.23138, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Pin_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(78, 88, 107), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Pin_Brass", role = "body", mat = "Metal", color = Color3.fromRGB(240, 188, 58), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "FrostCrystal", asset = 131877049362108, fx = Vector3.new(-0.00110, -0.23988, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(136, 230, 255), transp = 0.280, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Clasp", role = "clasp", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(181, 245, 255), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "GameCartridge", asset = 107422245992503, fx = Vector3.new(0.00300, -0.22738, -0.00300), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(63, 224, 242), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Cart_Body", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(70, 80, 102), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Cart_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "GlitchDie", asset = 108350194335525, fx = Vector3.new(-0.00000, -0.23728, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(52, 59, 77), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Clasp", role = "clasp", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(255, 61, 203), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "HazardSign", asset = 102207319130456, fx = Vector3.new(-0.00000, -0.21188, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Hazard_Yellow", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(245, 196, 40), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Hazard_Dark", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(40, 46, 59), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "HighScore", asset = 117140507723214, fx = Vector3.new(-0.00000, -0.23138, -0.00450), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Screen", role = "screen", mat = "SmoothPlastic", color = Color3.fromRGB(62, 71, 89), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(60, 255, 158), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Console_Body", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(62, 71, 89), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Console_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "IceCube", asset = 78274106423235, fx = Vector3.new(-0.00403, -0.25919, 0.00048), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(156, 235, 255), transp = 0.400, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Clasp", role = "clasp", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(142, 232, 255), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "Joystick", asset = 89959797281750, fx = Vector3.new(-0.00000, -0.18753, -0.03147), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(162, 172, 192), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Stick_Base", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(58, 66, 84), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Stick_Red", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(240, 56, 75), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(162, 172, 192), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Stick_Chain_Metal", role = "stick", mat = "Metal", color = Color3.fromRGB(162, 172, 192), transp = 0.000, origin = Vector3.new(0.03600, -0.19711, -0.01875) },
		{ name = "Stick_Stick_Red", role = "stick", mat = "SmoothPlastic", color = Color3.fromRGB(240, 56, 75), transp = 0.000, origin = Vector3.new(0.03600, -0.19711, -0.01875) }
	} },
	{ id = "Keycard", asset = 86708424874786, fx = Vector3.new(-0.00000, -0.21438, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(242, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Card_Slate", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(74, 85, 107), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Card_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(242, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Card_Dark", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(35, 40, 52), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "KillRadar", asset = 128213988132348, fx = Vector3.new(-0.00000, -0.22185, -0.00150), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(242, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Screen", role = "screen", mat = "SmoothPlastic", color = Color3.fromRGB(60, 69, 88), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(60, 255, 158), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Radar_Body", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(60, 69, 88), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Radar_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(242, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "MicroBlade", asset = 81724165021732, fx = Vector3.new(-0.00000, -0.24288, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(238, 186, 58), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Blade_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(203, 213, 230), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Blade_Grip", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(46, 53, 69), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Blade_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(238, 186, 58), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "MiniHelmet", asset = 94377380205714, fx = Vector3.new(0.00365, -0.21238, -0.00665), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(235, 184, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(63, 224, 242), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Helm_Slate", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(70, 80, 102), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Helm_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(235, 184, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "MiniTsuba", asset = 81700385921448, fx = Vector3.new(-0.00000, -0.23188, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(166, 176, 194), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(72, 216, 255), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Hilt_Dark", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(44, 51, 68), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Hilt_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(166, 176, 194), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "MoltenCore", asset = 87670839056856, fx = Vector3.new(-0.00000, -0.23788, -0.02107), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 182), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(255, 100, 36), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Forge_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(46, 52, 66), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Forge_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 182), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "PhantomLantern", asset = 81263577948200, fx = Vector3.new(-0.00000, -0.23688, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(134, 146, 166), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(93, 228, 204), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Lantern_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(37, 43, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Lantern_Trim", role = "body", mat = "Metal", color = Color3.fromRGB(134, 146, 166), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "PixelHeart", asset = 92681106271018, fx = Vector3.new(-0.00000, -0.21638, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Edge", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(255, 160, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Heart_Red", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(232, 38, 68), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "PlasmaPrism", asset = 79821052390442, fx = Vector3.new(-0.00000, -0.22188, -0.02037), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(200, 75, 255), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Rift_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(44, 50, 66), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Rift_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "ReactorCore", asset = 128300807884364, fx = Vector3.new(-0.00000, -0.22254, -0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Ring", role = "ring", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, -0.25200, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(63, 224, 242), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Core_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(46, 53, 70), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Core_Gold", role = "body", mat = "Metal", color = Color3.fromRGB(245, 190, 56), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "SnowflakeShard", asset = 83430739616746, fx = Vector3.new(-0.00000, -0.22738, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(181, 244, 255), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Snow_Ice", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(154, 235, 255), transp = 0.150, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(154, 164, 180), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "TargetPlate", asset = 73803938798064, fx = Vector3.new(-0.00000, -0.21977, 0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(141, 151, 168), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Target_White", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(226, 232, 242), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Target_Red", role = "body", mat = "SmoothPlastic", color = Color3.fromRGB(237, 50, 68), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Chain_Metal", role = "body", mat = "Metal", color = Color3.fromRGB(141, 151, 168), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} },
	{ id = "ThunderOrb", asset = 71188902438019, fx = Vector3.new(0.00000, -0.23888, -0.00000), parts = {
		{ name = "Chain", role = "chain", mat = "Metal", color = Color3.fromRGB(170, 180, 200), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Neon", role = "neon", mat = "Neon", color = Color3.fromRGB(107, 94, 255), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Cage_Dark", role = "body", mat = "Metal", color = Color3.fromRGB(58, 66, 86), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) },
		{ name = "Body_Cage_Steel", role = "body", mat = "Metal", color = Color3.fromRGB(170, 180, 200), transp = 0.000, origin = Vector3.new(-0.00000, 0.00000, 0.00000) }
	} }
}

local function buildOne(folder: Folder, spec: CharmSpec)
	local loaded: Instance? = nil
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return InsertService:LoadAsset(spec.asset)
		end)
		if ok and res then
			loaded = res
			break
		end
		warn("[BuildCharms] LoadAsset retry", attempt, spec.id, res)
		task.wait(0.5 * attempt)
	end
	assert(loaded, "Failed to LoadAsset for " .. spec.id)
	local loadedInst = loaded :: Instance

	local byName: { [string]: MeshPart } = {}
	for _, d in loadedInst:GetDescendants() do
		if d:IsA("MeshPart") then
			byName[d.Name] = d
		end
	end

	local model = Instance.new("Model")
	model.Name = spec.id
	model:SetAttribute("CharmId", spec.id)
	model:SetAttribute("AssetId", spec.asset)

	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Size = Vector3.new(0.05, 0.05, 0.05)
	pivot.CFrame = CFrame.new()
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CanQuery = false
	pivot.CanTouch = false
	pivot.Massless = true
	pivot.CastShadow = false
	pivot.Parent = model
	model.PrimaryPart = pivot

	local fxAtt = Instance.new("Attachment")
	fxAtt.Name = "CharmFx"
	fxAtt.Position = spec.fx
	fxAtt.Parent = pivot

	local specMap: { [string]: PartSpec } = {}
	for _, ps in spec.parts do
		specMap[ps.name] = ps
	end

	for name, src in byName do
		local p = src:Clone()
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		local ps = specMap[name]
		if ps then
			p.Color = ps.color
			local matEnum = (Enum.Material :: any)[ps.mat]
			if matEnum then
				p.Material = matEnum
			end
			p.Transparency = ps.transp
			if ps.role == "neon" then
				p:SetAttribute("CharmNeon", true)
			elseif ps.role == "screen" then
				p:SetAttribute("CharmScreen", true)
			end
		end
		p.Parent = model
		if ps and (ps.role == "stick" or ps.role == "wheel" or ps.role == "ring") then
			local m = Instance.new("Motor6D")
			m.Name = "AnimMotor"
			m.Part0 = pivot
			m.Part1 = p
			local at = CFrame.new(ps.origin)
			m.C0 = pivot.CFrame:ToObjectSpace(at)
			m.C1 = p.CFrame:ToObjectSpace(at)
			m.Parent = p
			p:SetAttribute("CharmAnimRole", ps.role)
			p:SetAttribute("CharmAnimOrigin", ps.origin)
		else
			local w = Instance.new("WeldConstraint")
			w.Part0 = pivot
			w.Part1 = p
			w.Parent = p
		end
	end

	loadedInst:Destroy()
	local old = folder:FindFirstChild(spec.id)
	if old then
		old:Destroy()
	end
	model.Parent = folder
end

local folder = ReplicatedStorage:FindFirstChild("Charms")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Charms"
	folder.Parent = ReplicatedStorage
end

local FROM = 1
local TO = #SPECS
for i = FROM, TO do
	buildOne(folder :: Folder, SPECS[i])
	if i % 4 == 0 then
		task.wait()
	end
end
return "BUILT " .. (TO - FROM + 1)
