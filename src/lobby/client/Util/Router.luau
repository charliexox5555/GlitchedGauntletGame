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

local CoreUi = require(script.Parent.CoreUi)
local InputMode = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("InputMode") :: ModuleScript
)
local Fx = require(script.Parent.Fx)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion)
local UiSfx = require(game:GetService("ReplicatedStorage").Shared.UiSfx)
-- pages that bring their own entrance sound (the Locker whooshes in)
local QUIET_OPEN: { [string]: boolean } = { Locker = true, Talk = true }

export type Menu = {
	open: (arg: any?) -> (),
	close: () -> (),
	-- The button gamepad selection starts on (LihFolk: Gamepad and Console UX).
	focus: (() -> GuiObject?)?,
	-- Its ScreenGui in PlayerGui: without `focus`, selection starts on the
	-- screen's first selectable button (lowest SelectionOrder), and either way
	-- the screen traps the selection so it can't wander into the HUD.
	screen: string?,
	-- No blur / grade behind it (the Locker shows its own 3D stage).
	clear: boolean?,
}

local Router = {}

-- RIVALS blurs the world 24 behind each page (Config/UiStyle.KIT.motion)
local BLUR_SIZE = UiMotion.M.blur
local BLUR_IN = UiMotion.M.blurIn
local SATURATION = -0.25

local menus: { [string]: Menu } = {}
local current: string? = nil
local listeners: { (string?) -> () } = {}
local blocked: (() -> boolean)? = nil

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

local function setWorldDimmed(on: boolean, clear: boolean?)
	-- Chat and the player list step aside while a full-screen menu is open.
	CoreUi.menuMode(on)
	if on and clear then
		blur.Enabled = false
		grade.Enabled = false
	elseif on then
		blur.Enabled = true
		grade.Enabled = true
		-- Blur Size isn't motion, so it eases under reduced motion too.
		TweenService
			:Create(blur, TweenInfo.new(BLUR_IN, Enum.EasingStyle.Quint), { Size = BLUR_SIZE })
			:Play()
		Fx.tween(grade, BLUR_IN, { Saturation = SATURATION })
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

local function screenOf(menu: Menu): ScreenGui?
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local found = pg and menu.screen and pg:FindFirstChild(menu.screen)
	return if found and found:IsA("ScreenGui") then found else nil
end

-- Selection stays inside an open menu's screen (SelectionGroup + Stop).
local function trap(menu: Menu, on: boolean)
	local gui = screenOf(menu)
	if not gui then
		return
	end
	gui.SelectionGroup = on
	local stop = if on then Enum.SelectionBehavior.Stop else Enum.SelectionBehavior.Escape
	gui.SelectionBehaviorUp = stop
	gui.SelectionBehaviorDown = stop
	gui.SelectionBehaviorLeft = stop
	gui.SelectionBehaviorRight = stop
end

local function usingGamepad(): boolean
	return InputMode.gamepad() -- (Settings FORCE CONTROLS wins)
end

-- Gamepad selection lands inside the menu: its own focus, else the screen's
-- first selectable button.
local function focusMenu(menu: Menu)
	if not usingGamepad() then
		return
	end
	local target = if menu.focus then menu.focus() else nil
	if target then
		GuiService.SelectedObject = target
		return
	end
	local gui = screenOf(menu)
	if gui then
		pcall(function()
			GuiService:Select(gui)
		end)
	end
end

function Router.current(): string?
	return current
end

-- While `fn` returns true no menu opens (MATCH FOUND owns the screen).
function Router.setBlocked(fn: () -> boolean)
	blocked = fn
end

function Router.open(name: string, arg: any?)
	local menu = menus[name]
	if not menu or (blocked and blocked()) then
		return
	end
	if current == name then
		menu.open(arg) -- re-open with a new argument (e.g. a preselected mode)
		return
	end
	local previous = current
	if previous then
		menus[previous].close()
		if menu.clear then
			setWorldDimmed(true, true)
		elseif menus[previous].clear then
			setWorldDimmed(true)
		end
	else
		setWorldDimmed(true, menu.clear)
	end
	current = name
	if not previous and not QUIET_OPEN[name] then
		UiSfx.play("PageOpen") -- from the world into a page (switching pages stays quiet)
	end
	if previous then
		trap(menus[previous], false)
	end
	menu.open(arg)
	trap(menu, true)
	-- Gamepad selection lands inside the menu at the start of its entrance.
	focusMenu(menu)
	notify()
end

function Router.close()
	local name = current
	if not name then
		return
	end
	current = nil
	menus[name].close()
	trap(menus[name], false)
	GuiService.SelectedObject = nil
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

-- Picking up a controller with a menu open gives it a selection.
pcall(function()
	InputMode.changed:Connect(function()
		local name = current
		if name and GuiService.SelectedObject == nil then
			focusMenu(menus[name])
		end
	end)
end)

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
		UiSfx.play("Back")
		Router.close()
	end
end)

return Router
