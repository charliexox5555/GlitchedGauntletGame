--!strict
-- Builds the Input Action System context from Config/Input at runtime, so
-- every binding lives in data. Other controllers read actions by name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindings = require(ReplicatedStorage.Shared.Config.Input)

local InputController = {}

local context: InputContext? = nil
local actions: { [string]: InputAction } = {}

local function addBinding(action: InputAction, key: Enum.KeyCode)
	local binding = Instance.new("InputBinding")
	binding.Name = key.Name
	binding.KeyCode = key
	binding.Parent = action
end

function InputController.init()
	local ctx = Instance.new("InputContext")
	ctx.Name = "PlayContext"
	for name, b in Bindings do
		local action = Instance.new("InputAction")
		action.Name = name
		action.Type = Enum.InputActionType.Bool
		for _, key in b.keys do
			addBinding(action, key)
		end
		for _, key in b.gamepad do
			addBinding(action, key)
		end
		action.Parent = ctx
		actions[name] = action
	end
	-- Client-side instance: lives only on this machine.
	ctx.Parent = ReplicatedStorage
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
		if b.touch then
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
