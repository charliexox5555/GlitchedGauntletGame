--!strict
-- Mod effect colours per viewer (Mods.md → VFX colour by viewer): cyan for
-- you and your team, orange-red for enemies. Each client recolours locally,
-- so the same grenade is cyan to its thrower and orange-red to the target.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local TeamColor = {}

TeamColor.ALLY = Config.COLORS.ally
TeamColor.ENEMY = Config.COLORS.enemy
TeamColor.GLITCH = Config.COLORS.glitch

-- Colour for an effect owned by team `team` (a number), or by an instance
-- (Player, character, dummy).
function TeamColor.forTeam(team: number?): Color3
	local mine = Teams.of(Players.LocalPlayer)
	if team ~= nil and team == mine then
		return TeamColor.ALLY
	end
	return TeamColor.ENEMY
end

function TeamColor.forOwner(owner: Instance?): Color3
	if owner == Players.LocalPlayer then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(Teams.of(owner))
end

function TeamColor.isFriendly(team: number?): boolean
	return team ~= nil and team == Teams.of(Players.LocalPlayer)
end

return TeamColor
