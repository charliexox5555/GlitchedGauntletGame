--!strict
-- One full-screen lobby menu at a time (Queue, Shop, Battle Pass, Locker,
-- Settings, Range). Opening one closes the current; while any is open the
-- world blurs and desaturates behind it and the character stops walking.
-- Menus register { open(arg), close() }; the HUD listens to `onChanged`.

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fx = require(script.Parent.Fx)
local Sound = require(script.Parent.Sound)

export type Menu = {
	open: (arg: any?) -> (),
	close: () -> (),
	-- The button gamepad selection starts on (LihFolk: Gamepad and Console UX).
	focus: (() -> GuiObject?)?,
}

local Router = {}

local BLUR_SIZE = 16
local SATURATION = -0.25

local menus: { [string]: Menu } = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}

local blur = Instance.new("BlurEffect")
blur.Name = "LobbyMenuBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "LobbyMenuGrade"
grade.Saturation = 0
grade.Enabled = false
grade.Parent = Lighting

local controls: any = nil
local function getControls(): any
	if controls then
		return controls
	end
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return (require(module) :: any):GetControls()
		end)
		if ok then
			controls = result
		end
	end
	return controls
end

local function setWorldDimmed(on: boolean)
	if on then
		blur.Enabled = true
		grade.Enabled = true
		-- Blur Size isn't motion, so it eases under reduced motion too.
		TweenService:Create(blur, TweenInfo.new(Fx.MOTION.dimIn), { Size = BLUR_SIZE }):Play()
		Fx.tween(grade, Fx.MOTION.dimIn, { Saturation = SATURATION })
	else
		TweenService:Create(blur, TweenInfo.new(Fx.MOTION.dimOut), { Size = 0 }):Play()
		Fx.tween(grade, Fx.MOTION.dimOut, { Saturation = 0 }, Enum.EasingStyle.Quad)
		task.delay(Fx.MOTION.dimOut + 0.02, function()
			if current == nil then
				blur.Enabled = false
				grade.Enabled = false
			end
		end)
	end
	local c = getControls()
	if c then
		pcall(function()
			if on then
				c:Disable()
			else
				c:Enable()
			end
		end)
	end
end

local function notify()
	for _, cb in listeners do
		task.spawn(cb, current)
	end
end

function Router.register(name: string, menu: Menu)
	menus[name] = menu
end

function Router.current(): string?
	return current
end

function Router.open(name: string, arg: any?)
	local menu = menus[name]
	if not menu then
		return
	end
	if current == name then
		menu.open(arg) -- re-open with a new argument (e.g. a preselected mode)
		return
	end
	local previous = current
	if previous then
		menus[previous].close()
	else
		setWorldDimmed(true)
		Sound.play("Open")
	end
	current = name
	menu.open(arg)
	-- Gamepad selection lands inside the menu at the start of its entrance.
	if menu.focus and UserInputService.GamepadEnabled then
		local target = menu.focus()
		if target then
			GuiService.SelectedObject = target
		end
	end
	notify()
end

function Router.close()
	local name = current
	if not name then
		return
	end
	current = nil
	menus[name].close()
	GuiService.SelectedObject = nil
	Sound.play("Close")
	setWorldDimmed(false)
	notify()
end

function Router.toggle(name: string, arg: any?)
	if current == name then
		Router.close()
	else
		Router.open(name, arg)
	end
end

function Router.onChanged(cb: (string?) -> ())
	table.insert(listeners, cb)
end

-- Gamepad B / keyboard Backspace back out of a menu. Esc can't be used: Roblox
-- reserves it for its own menu, so it never reaches the game unprocessed.
UserInputService.InputBegan:Connect(function(input, processed)
	if not current then
		return
	end
	-- B is "processed" while a button is selected, so it doesn't check that flag.
	if
		input.KeyCode == Enum.KeyCode.ButtonB
		or (input.KeyCode == Enum.KeyCode.Backspace and not processed)
	then
		Router.close()
	end
end)

return Router
