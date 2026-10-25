--!strict
-- Server half of the simulation (shared/Simulation: movement and the
-- third-person pose tracks). The server's result is authoritative; clients
-- predict the same steps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementSim = require(ReplicatedStorage.Shared.Simulation.Movement)
local PoseSim = require(ReplicatedStorage.Shared.Simulation.Poses)

local MovementService = {}

function MovementService.start()
	MovementSim.initialize()
	PoseSim.initialize()
end

return MovementService
