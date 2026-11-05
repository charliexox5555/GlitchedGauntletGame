--!strict
-- The UI v2 theme lives in ReplicatedStorage.Shared.Config.UiStyle (shared with
-- the match HUD); this alias keeps the Lobby's requires short.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage.Shared.Config.UiStyle)
