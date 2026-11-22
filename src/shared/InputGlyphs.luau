--!strict
-- Key hints that follow the device (vault/04 Tech/UI Architecture.md §9 step 5;
-- owner 2026-11-22: LOCK IN showed "ENTER" on a phone). A key chip in a
-- Studio screen (a frame with a Face.Label, or any frame holding a TextLabel
-- named Label) carries one of:
--   KeyAction = "Mod1"   an input action (Config/Input): keyboard shows its
--                        key, a gamepad shows its button's glyph;
--   KeyText = "ENTER"    a keyboard-only shortcut (draft, match end, play menu);
--                        it hides on a gamepad unless KeyGamepad names a
--                        KeyCode ("ButtonA").
-- Touch hides every chip (taps need no shortcut). Gamepad glyphs come from
-- UserInputService:GetImageForKeyCode, so Xbox and PlayStation each get
-- their own pictures. Client only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Bindings = require(ReplicatedStorage.Shared.Config.Input)
local InputMode = require(ReplicatedStorage.Shared.InputMode)

local InputGlyphs = {}

export type Mode = "Touch" | "Keyboard" | "Gamepad"

-- Short keyboard names for chips.
local NAMES: { [string]: string } = {
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Return = "ENTER",
	KeypadEnter = "ENTER",
	LeftShift = "SHIFT",
	RightShift = "SHIFT",
	LeftControl = "CTRL",
	RightControl = "CTRL",
	LeftAlt = "ALT",
	Space = "SPACE",
	Tab = "TAB",
	Escape = "ESC",
	Backspace = "BKSP",
	MouseLeftButton = "LMB",
	MouseRightButton = "RMB",
	MouseMiddleButton = "MMB",
}

local function studioTouch(): boolean
	if not RunService:IsStudio() then
		return false
	end
	local folder = Workspace:FindFirstChild("GauntletState")
	local v = folder and folder:FindFirstChild("ForceTouchUI")
	return v ~= nil and v:IsA("StringValue") and v.Value == "t"
end

-- Studio test switch: Workspace.GauntletState.ForceInput = "sgamepad" /
-- "skeyboard" / "stouch" (StateValues string encoding) shows that input's
-- key hints without the device.
local function studioForced(): Mode?
	if not RunService:IsStudio() then
		return nil
	end
	local folder = Workspace:FindFirstChild("GauntletState")
	local v = folder and folder:FindFirstChild("ForceInput")
	if v and v:IsA("StringValue") then
		local m = string.lower(string.sub(v.Value, 2))
		return if m == "gamepad"
			then "Gamepad"
			elseif m == "keyboard" then "Keyboard"
			elseif m == "touch" then "Touch"
			else nil
	end
	return nil
end

function InputGlyphs.mode(): Mode
	local forced = studioForced()
	if forced then
		return forced
	end
	if studioTouch() then
		return "Touch"
	end
	local ok, preferred = true, InputMode.preferred() -- (Settings FORCE CONTROLS wins)
	if ok then
		if preferred == Enum.PreferredInput.Touch then
			return "Touch"
		elseif preferred == Enum.PreferredInput.Gamepad then
			return "Gamepad"
		end
		return "Keyboard"
	end
	return if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Touch"
		elseif
			UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
		then "Gamepad"
		else "Keyboard"
end

function InputGlyphs.keyName(code: Enum.KeyCode): string
	return NAMES[code.Name] or string.upper(code.Name)
end

-- The binding an action uses now: the player's own PlayContext (the server
-- puts their saved Settings keybinds there, server/Services/InputContextService),
-- else Config/Input. setOverride wins over both (tests, previews).
local function isPad(code: Enum.KeyCode): boolean
	local n = code.Name
	return string.sub(n, 1, 6) == "Button"
		or string.sub(n, 1, 4) == "DPad"
		or string.sub(n, 1, 10) == "Thumbstick"
end

local function context(): Instance?
	local player = if RunService:IsClient() then Players.LocalPlayer else nil
	return player and player:FindFirstChild("PlayContext")
end

local function liveKeys(action: string): ({ Enum.KeyCode }?, { Enum.KeyCode }?)
	local ctx = context()
	local a = ctx and ctx:FindFirstChild(action)
	if not a then
		return nil, nil
	end
	local keys: { Enum.KeyCode }, pad: { Enum.KeyCode } = {}, {}
	-- (a TOGGLE row moves the keys to "<Name>Toggle": read both)
	local toggle = ctx and ctx:FindFirstChild(action .. "Toggle")
	for _, holder in { a, toggle } do
		for _, c in (holder :: Instance):GetChildren() do
			if c:IsA("InputBinding") and c.KeyCode.Value ~= 0 and c.UIButton == nil then
				table.insert(if isPad(c.KeyCode) then pad else keys, c.KeyCode)
			end
		end
	end
	-- Config order first (the main key before the alt), then any others.
	local b = Bindings[action]
	local function order(list: { Enum.KeyCode }, pref: { Enum.KeyCode })
		table.sort(list, function(x, y)
			local ix, iy = table.find(pref, x) or math.huge, table.find(pref, y) or math.huge
			if ix ~= iy then
				return ix < iy
			end
			return x.Value < y.Value
		end)
	end
	order(keys, if b then b.keys else {})
	order(pad, if b then b.gamepad else {})
	return keys, pad
end

local overrides: { [string]: { keys: { Enum.KeyCode }?, gamepad: { Enum.KeyCode }? } } = {}

function InputGlyphs.setOverride(
	action: string,
	keys: { Enum.KeyCode }?,
	gamepad: { Enum.KeyCode }?
)
	overrides[action] = { keys = keys, gamepad = gamepad }
	InputGlyphs.refreshAll()
end

function InputGlyphs.keysFor(action: string): ({ Enum.KeyCode }, { Enum.KeyCode })
	local b = Bindings[action]
	local o = overrides[action]
	local liveK, liveP = liveKeys(action)
	local keys = (o and o.keys) or liveK or (if b then b.keys else {})
	local pad = (o and o.gamepad) or liveP or (if b then b.gamepad else {})
	return keys, pad
end

local function labelOf(chip: Instance): TextLabel?
	local face = chip:FindFirstChild("Face")
	local label = (face and face:FindFirstChild("Label")) or chip:FindFirstChild("Label", true)
	return if label and label:IsA("TextLabel") then label else nil
end

local function glyphOf(chip: GuiObject, label: TextLabel): ImageLabel
	local glyph = chip:FindFirstChild("Glyph", true)
	if glyph and glyph:IsA("ImageLabel") then
		return glyph
	end
	local made = Instance.new("ImageLabel")
	made.Name = "Glyph"
	made.BackgroundTransparency = 1
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromScale(1.15, 1.15)
	made.ScaleType = Enum.ScaleType.Fit
	made.ZIndex = label.ZIndex + 1
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = made
	made.Parent = label.Parent
	return made
end

-- Shows a chip the way the current input wants it.
function InputGlyphs.apply(chip: GuiObject)
	local label = labelOf(chip)
	if not label then
		return
	end
	local action = chip:GetAttribute("KeyAction")
	local text = chip:GetAttribute("KeyText")
	local padName = chip:GetAttribute("KeyGamepad")
	local mode = InputGlyphs.mode()
	-- Only undo a hide this module made: screens that switch a chip on and
	-- off themselves (draft LOCK IN, column tabs) keep their say, and ask
	-- InputGlyphs.shows first.
	local function hide()
		if chip.Visible then
			chip:SetAttribute("KeyHidden", true)
		end
		chip.Visible = false
	end
	local function show()
		if chip:GetAttribute("KeyHidden") then
			chip:SetAttribute("KeyHidden", nil)
			chip.Visible = true
		end
	end
	local keyText: string? = nil
	local padCode: Enum.KeyCode? = nil
	if typeof(action) == "string" then
		local keys, pad = InputGlyphs.keysFor(action)
		keyText = if keys[1] then InputGlyphs.keyName(keys[1]) else nil
		padCode = pad[1]
	elseif typeof(text) == "string" then
		keyText = text
		if typeof(padName) == "string" then
			local ok, code = pcall(function()
				return (Enum.KeyCode :: any)[padName]
			end)
			padCode = if ok then code else nil
		end
	else
		return
	end
	local glyph = chip:FindFirstChild("Glyph", true)
	if mode == "Touch" then
		hide()
	elseif mode == "Gamepad" then
		if padCode then
			local g = glyphOf(chip, label)
			g.Image = UserInputService:GetImageForKeyCode(padCode)
			g.Visible = true
			label.TextTransparency = 1
			show()
		else
			hide()
		end
	else
		if glyph and glyph:IsA("ImageLabel") then
			glyph.Visible = false
		end
		label.TextTransparency = 0
		if keyText then
			label.Text = keyText
			show()
		else
			hide()
		end
	end
end

-- Whether a chip shows at all with the current input (screens that switch
-- a chip on and off themselves ask this first).
function InputGlyphs.shows(chip: Instance): boolean
	local mode = InputGlyphs.mode()
	if mode == "Touch" then
		return false
	end
	local action = chip:GetAttribute("KeyAction")
	if mode == "Gamepad" then
		if typeof(action) == "string" then
			local _, pad = InputGlyphs.keysFor(action)
			return pad[1] ~= nil
		end
		return chip:GetAttribute("KeyGamepad") ~= nil
	end
	return true
end

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isChip(d: Instance): boolean
	return d:IsA("GuiObject")
		and (d:GetAttribute("KeyAction") ~= nil or d:GetAttribute("KeyText") ~= nil)
end

-- Applies to every key chip in `gui` now and whenever the input changes;
-- chips cloned in later (list rows) are applied too.
function InputGlyphs.watch(gui: Instance)
	if watched[gui] then
		return
	end
	watched[gui] = true
	for _, d in gui:GetDescendants() do
		if isChip(d) then
			InputGlyphs.apply(d :: GuiObject)
		end
	end
	gui.DescendantAdded:Connect(function(d: Instance)
		if isChip(d) then
			task.defer(InputGlyphs.apply, d :: GuiObject)
		end
	end)
end

function InputGlyphs.refreshAll()
	for gui in watched do
		if gui.Parent then
			for _, d in gui:GetDescendants() do
				if isChip(d) then
					InputGlyphs.apply(d :: GuiObject)
				end
			end
		end
	end
end

local changed = Instance.new("BindableEvent")
InputGlyphs.changed = changed.Event

if RunService:IsClient() then
	local last = InputGlyphs.mode()
	local function check()
		local now = InputGlyphs.mode()
		if now ~= last then
			last = now
			InputGlyphs.refreshAll()
			changed:Fire(now)
		end
	end
	InputMode.changed:Connect(check)
	UserInputService.LastInputTypeChanged:Connect(check)
	-- Keybinds changed (the server rebuilt bindings in PlayContext): redraw
	-- once the burst of adds and removes is over.
	local pending = false
	local function rebound()
		if pending then
			return
		end
		pending = true
		task.delay(0.1, function()
			pending = false
			InputGlyphs.refreshAll()
			changed:Fire(InputGlyphs.mode())
		end)
	end
	task.spawn(function()
		local player = Players.LocalPlayer
		local ctx = player and player:WaitForChild("PlayContext", 60)
		if ctx then
			ctx.DescendantAdded:Connect(rebound)
			ctx.DescendantRemoving:Connect(rebound)
			rebound()
		end
	end)
end

return InputGlyphs
