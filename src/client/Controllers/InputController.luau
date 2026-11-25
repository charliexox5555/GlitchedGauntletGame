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
local touchBindings: { [InputAction]: InputBinding } = {}

-- Clean press / release edges per action. An action with a touch-button
-- binding as well as keys can fire Pressed twice for one press (measured in
-- Studio: two Pressed ~50 ms apart, no Released between), which would cancel
-- a Mod hold on the spot or double a semi-auto shot. A Pressed with no
-- Released since the last one is dropped, and so is a Released with no Pressed.
type Edges = { down: boolean, at: number, pressed: BindableEvent, released: BindableEvent }
-- A duplicate Pressed comes within a few frames; one later than this is a
-- new press (in case a Released was lost).
local DUPLICATE_WINDOW = 0.2
local edges: { [string]: Edges } = {}

local function watch(name: string, action: InputAction)
	local e: Edges = {
		down = false,
		at = -math.huge,
		pressed = Instance.new("BindableEvent"),
		released = Instance.new("BindableEvent"),
	}
	edges[name] = e
	action.Pressed:Connect(function()
		local now = os.clock()
		if not e.down or now - e.at > DUPLICATE_WINDOW then
			e.down = true
			e.at = now
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

-- TOGGLE AIM / CROUCH / SPRINT (Settings, keyboard and controller; phones
-- toggle in TouchController): while a row is on, the server puts that
-- action's keys on "<Name>Toggle" and each press here flips the real action.
local toggled: { [string]: boolean } = {}

local function setToggled(name: string, on: boolean)
	local action = actions[name]
	if not action then
		return
	end
	toggled[name] = on
	if action:GetState() ~= on then
		action:Fire(on)
	end
end

-- Drops every held toggle (death, a new character, a toggle row turned off).
function InputController.releaseToggles()
	for name, on in toggled do
		if on then
			setToggled(name, false)
		end
	end
end

-- Drops one held toggle (WeaponController: a new weapon drops a toggled aim).
function InputController.releaseToggle(name: string)
	if toggled[name] then
		setToggled(name, false)
	end
end

local function watchToggle(name: string, toggle: InputAction)
	toggle.Pressed:Connect(function()
		setToggled(name, not toggled[name])
	end)
	-- the row turned off (the keys left this action): let go
	toggle.ChildRemoved:Connect(function()
		if #toggle:GetChildren() == 0 and toggled[name] then
			setToggled(name, false)
		end
	end)
end

local INIT_WAIT = 10 -- seconds init() may wait for the server's input context and actions, in total

function InputController.init()
	local player = Players.LocalPlayer
	-- init() runs before every other controller's start(): one shared deadline, not a wait per action (a missing
	-- action used to cost 10 s each, in a row) and not forever for the context (2026-11-25 loading audit).
	local deadline = os.clock() + INIT_WAIT
	local found = player:WaitForChild("PlayContext", INIT_WAIT)
	if not (found and found:IsA("InputContext")) then
		warn("[Health] C input: no PlayContext after", INIT_WAIT, "s; controls start without it")
		return
	end
	local ctx: InputContext = found
	for name, b in Bindings do
		local left = deadline - os.clock()
		local action = ctx:FindFirstChild(name)
			or (if left > 0 then ctx:WaitForChild(name, left) else nil)
		if action and action:IsA("InputAction") then
			if action.Type == Enum.InputActionType.Bool and action:GetState() == true then
				action:Fire(false)
			end
			actions[name] = action
			watch(name, action)
		end
		local toggle = if b.toggle then ctx:FindFirstChild(name .. "Toggle") else nil
		if toggle and toggle:IsA("InputAction") then
			watchToggle(name, toggle)
			-- a toggle left on by the last match client (destroyed with it)
			if
				action
				and action:IsA("InputAction")
				and #toggle:GetChildren() > 0
				and action:GetState()
			then
				action:Fire(false)
			end
		end
	end
	ctx.Enabled = player:GetAttribute("GameSettingsOpen") ~= true
	context = ctx
	player.CharacterAdded:Connect(InputController.releaseToggles)
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
		if b.touch and action then
			local button = root:FindFirstChild(b.touch, true)
			if button and button:IsA("GuiButton") then
				local bindingName = "Touch_" .. b.touch
				local old = action:FindFirstChild(bindingName)
				if old and old:IsA("InputBinding") and old.UIButton == button then
					touchBindings[action] = old
					continue
				end
				if old then
					old:Destroy()
				end
				local binding = Instance.new("InputBinding")
				binding.Name = bindingName
				binding.UIButton = button
				binding.Parent = action
				touchBindings[action] = binding
			end
		end
	end
end

function InputController.clearTouchButtons(release: boolean)
	for action, binding in touchBindings do
		binding:Destroy()
		if release and action:GetState() == true then
			action:Fire(false)
		end
	end
	table.clear(touchBindings)
end

function InputController.setEnabled(enabled: boolean)
	if context then
		context.Enabled = enabled
	end
end

return InputController
