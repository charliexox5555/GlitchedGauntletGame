--!strict
-- Fields written by Movement, Abilities and Poses during fixed simulation
-- steps. CharacterService creates the values before either side steps a body.

local Config = require(script.Parent.Parent.Config.Mods)
local StateValues = require(script.Parent.Parent.StateValues)

local names = {
	"MoveState",
	"SlideStart",
	"SlideEnd",
	"SlideDir",
	"SlideJumpSpeed",
	"CrouchHeld",
	"CrouchPressAt",
	"SprintBlock",
	"RunSince",
	"WasGrounded",
	"AirSince",
	"DashWindows",
	"DashDecoy",
	"DashDecoyRun",
	"DashStart",
	"DashUntil",
	"DashVelocity",
	"DashTune",
	"Dashing",
	"UpdraftAt",
	"UpdraftLaunch",
	"Updrafting",
	"UpdraftSlam",
	"UpdraftSlamStart",
	"UpdraftSlamPos",
	"UpdraftSlamAt",
	"RecallSeen",
	"RecallAt",
	"PoseDashSeen",
	"PoseUpdraftSeen",
	"PoseUseSeen",
	"ModResetSeen",
}
for slot = 1, Config.SLOTS do
	for _, suffix in { "In", "CastAt", "Key", "SerialSeen", "Charges", "RechargeAt" } do
		table.insert(names, "Mod" .. slot .. suffix)
	end
end

local ready: { [Model]: boolean } = setmetatable({}, { __mode = "k" })
local Fields = {}

function Fields.prepare(character: Model)
	StateValues.prepare(character, names)
	ready[character] = true
end

function Fields.ready(character: Model): boolean
	if ready[character] then
		return true
	end
	if not StateValues.hasFields(character, names) then
		return false
	end
	ready[character] = true
	return true
end

return Fields
