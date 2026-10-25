--!strict
-- Reads the player's Input Action System context. The server builds it from
-- Config/Input and parents a copy under each Player (Server Authority sends
-- those inputs to the server simulation). Other controllers read actions by
-- name; touch buttons are linked here on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindings = require(ReplicatedStorage.Shared.Config.Input)

local InputController = {}

local context: InputContext? = nil
local actions: { [string]: InputAction } = {}

function InputController.init()
	local ctx = Players.LocalPlayer:WaitForChild("PlayContext") :: InputContext
	for name in Bindings do
		local action = ctx:WaitForChild(name, 10)
		if action and action:IsA("InputAction") then
			actions[name] = action
		end
	end
	context = ctx
end

function InputController.action(name: string): InputAction
	local a = actions[name]
	assert(a, "unknown input action " .. name)
	return a
end

function InputController.isDown(name: string): boolean
	local a = actions[name]
	return a ~= nil and a:GetState() == true
end

function InputController.onPressed(name: string, fn: () -> ()): RBXScriptConnection
	return InputController.action(name).Pressed:Connect(fn)
end

function InputController.onReleased(name: string, fn: () -> ()): RBXScriptConnection
	return InputController.action(name).Released:Connect(fn)
end

-- Links on-screen touch buttons (named in Config/Input) to their actions.
function InputController.bindTouchButtons(root: Instance)
	for name, b in Bindings do
		if b.touch and actions[name] then
			local button = root:FindFirstChild(b.touch, true)
			if button and button:IsA("GuiButton") then
				local binding = Instance.new("InputBinding")
				binding.Name = "Touch"
				binding.UIButton = button
				binding.Parent = actions[name]
			end
		end
	end
end

function InputController.setEnabled(enabled: boolean)
	if context then
		context.Enabled = enabled
	end
end

return InputController
