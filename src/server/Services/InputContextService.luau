--!strict
-- Builds the Input Action System context from Config/Input and gives every
-- player their own copy under the Player. Server Authority needs contexts
-- owned by a Player so that the inputs reach the server simulation (and are
-- replayed when the client resimulates).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindings = require(ReplicatedStorage.Shared.Config.Input)

local InputContextService = {}

local template: InputContext? = nil

local function addBinding(action: InputAction, key: Enum.KeyCode)
	local binding = Instance.new("InputBinding")
	binding.Name = key.Name
	binding.KeyCode = key
	binding.Parent = action
end

local function build(): InputContext
	local ctx = Instance.new("InputContext")
	ctx.Name = "PlayContext"
	for name, b in Bindings do
		local action = Instance.new("InputAction")
		action.Name = name
		action.Type = if b.kind == "Direction1D"
			then Enum.InputActionType.Direction1D
			else Enum.InputActionType.Bool
		for _, key in b.keys do
			addBinding(action, key)
		end
		for _, key in b.gamepad do
			addBinding(action, key)
		end
		action.Parent = ctx
	end
	return ctx
end

local function give(player: Player)
	if template and not player:FindFirstChild("PlayContext") then
		template:Clone().Parent = player
	end
end

function InputContextService.init()
	template = build()
end

function InputContextService.start()
	Players.PlayerAdded:Connect(give)
	for _, player in Players:GetPlayers() do
		give(player)
	end
end

return InputContextService
