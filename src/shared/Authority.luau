--!strict
-- Who owns a player's movement and inputs (both sides read this).
--
-- The game was built for Roblox Server Authority (Workspace.AuthorityMode =
-- Server): the server simulates every player from their replicated inputs and
-- camera, and each client predicts itself. The owner turned it off on
-- 2026-11-11 (AuthorityMode = Automatic: it lagged for players). In that mode
-- the server gets NO inputs and NO camera from a player (every InputAction
-- reads false, Player:GetCameraState errors), and each client owns its own
-- character, as in a classic Roblox game. So, when `server()` is false:
--   * the server does not run the movement / Mod / pose simulation for real
--     players (shared/Simulation; it would write a standing-still state over
--     the client's own); bots are still simulated on the server;
--   * the client reports its move state with its aim (the Aim remote) for
--     everyone else to see;
--   * the checks that compared a shot or a Mod use against the server's own
--     copy of your stance, aim and camera are off (WeaponService, ModService).
-- vault/04 Tech/Architecture.md → "Authority mode".

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(script.Parent.Config.Combat)

local Authority = {}

local cached: boolean? = nil

-- True when the server simulates players (Server Authority is on).
function Authority.server(): boolean
	local known = cached
	if known ~= nil then
		return known
	end
	local ok, on = pcall(function(): boolean
		return (Workspace :: any).AuthorityMode == (Enum :: any).AuthorityMode.Server
	end)
	local value = if ok then on else Combat.SERVER_AUTHORITY_FALLBACK
	cached = value
	if RunService:IsServer() then
		-- Once per server, so the Output says which way the game is running.
		print(
			string.format(
				"[Authority] Server Authority is %s (%s)",
				if value then "ON" else "OFF: clients own their movement, input checks are off",
				if ok then "Workspace.AuthorityMode" else "Config/Combat SERVER_AUTHORITY_FALLBACK"
			)
		)
	end
	return value
end

return Authority
