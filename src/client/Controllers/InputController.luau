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

-- Clean press / release edges per action. An action with a touch-button
-- binding as well as keys can fire Pressed twice for one press (measured in
-- Studio: two Pressed ~50 ms apart, no Released between), which would cancel
-- a Mod hold on the spot or double a semi-auto shot. A Pressed with no
-- Released since the last one is dropped, and so is a Released with no Pressed.
type Edges = { down: boolean, pressed: BindableEvent, released: BindableEvent }
local edges: { [string]: Edges } = {}

local function watch(name: string, action: InputAction)
	local e: Edges = {
		down = false,
		pressed = Instance.new("BindableEvent"),
		released = Instance.new("BindableEvent"),
	}
	edges[name] = e
	action.Pressed:Connect(function()
		if not e.down then
			e.down = true
			e.pressed:Fire()
		end
	end)
	action.Released:Connect(function()
		if e.down then
			e.down = false
			e.released:Fire()
		end
	end)
end

function InputController.init()
	local ctx = Players.LocalPlayer:WaitForChild("PlayContext") :: InputContext
	for name in Bindings do
		local action = ctx:WaitForChild(name, 10)
		if action and action:IsA("InputAction") then
			actions[name] = action
			watch(name, action)
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

local function edgesFor(name: string): Edges
	local e = edges[name]
	assert(e, "unknown input action " .. name)
	return e
end

function InputController.onPressed(name: string, fn: () -> ()): RBXScriptConnection
	return edgesFor(name).pressed.Event:Connect(fn)
end

function InputController.onReleased(name: string, fn: () -> ()): RBXScriptConnection
	return edgesFor(name).released.Event:Connect(fn)
end

-- Links on-screen touch buttons (named in Config/Input) to their actions.
-- Safe to call more than once on the same buttons (one binding each).
function InputController.bindTouchButtons(root: Instance)
	for name, b in Bindings do
		local action = actions[name]
		if b.touch and action and not action:FindFirstChild("Touch_" .. b.touch) then
			local button = root:FindFirstChild(b.touch, true)
			if button and button:IsA("GuiButton") then
				local binding = Instance.new("InputBinding")
				binding.Name = "Touch_" .. b.touch
				binding.UIButton = button
				binding.Parent = action
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
