--!strict
-- Server half of the movement simulation (shared/Simulation/Movement). The
-- server's result is authoritative; clients predict the same steps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementSim = require(ReplicatedStorage.Shared.Simulation.Movement)

local MovementService = {}

function MovementService.start()
	MovementSim.initialize()
end

return MovementService
