--!strict
-- The UI v2 builders live in ReplicatedStorage.Shared.UiKit (shared with the
-- match HUD); this alias keeps the Lobby's requires short.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage.Shared.UiKit)
