--!strict
-- The touch layout editor (vault/02 Art/UI Mobile Controls.md → Build plan
-- v1), opened from Settings → TOUCH → LAYOUT EDITOR. It previews a copy of the
-- match's touch screen (UI.Match.Touch) with every button showing and the
-- Studio-built bar (UI.Lobby.TouchEditor, tools/studio/BuildTouchEditor.luau)
-- on top:
--   tap a button to pick it, drag to move it; − / + resize it; HIDE hides its
--   group; 1 / 2 / 3 switch layouts; RESET puts this layout back to default;
--   CANCEL throws the changes away, DONE hands them to Settings to save.
-- Spots are saved by Shared/TouchLayout as fractions of the screen, so a
-- layout made on one device fits another. Client only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local TouchControls = require(ReplicatedStorage.Shared.Config.TouchControls)
local TouchLayout = require(ReplicatedStorage.Shared.TouchLayout)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local LobbyKit = require(script.Parent.LobbyKit)
local Plates = require(script.Parent.Plates)

local TouchEditor = {}

type Values = { [string]: any }
type Session = {
	preview: ScreenGui,
	bar: ScreenGui,
	root: Frame,
	values: Values, -- a working copy of the player's settings
	selected: string?,
	drag: { input: InputObject, start: Vector2, centre: Vector2 }?,
	conns: { RBXScriptConnection },
	onDone: (changes: Values?) -> (),
}

local C = LobbyKit.C
local player = Players.LocalPlayer
local session: Session? = nil

local function deepCopy(t: any): any
	if typeof(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

local function profileKey(s: Session): string
	local _, p = TouchLayout.active(s.values)
	return "touchLayout" .. p
end

local function layoutOf(s: Session): TouchLayout.Layout
	local key = profileKey(s)
	local l = s.values[key]
	if typeof(l) ~= "table" then
		l = {}
		s.values[key] = l
	end
	return l
end

local function objectOf(s: Session, name: string): GuiObject?
	local o = s.root:FindFirstChild(name, true)
	return if o and o:IsA("GuiObject") then o else nil
end

-- What the player grabs for an object: the stick for its resting spot.
local function handleOf(s: Session, name: string): GuiObject?
	if name == "StickRest" then
		local stick = s.root:FindFirstChild("Stick")
		return if stick and stick:IsA("GuiObject") then stick else nil
	end
	return objectOf(s, name)
end

-- The floating stick sits on its resting spot while editing.
local function placeStick(s: Session)
	local stick = s.root:FindFirstChild("Stick")
	local rest = objectOf(s, "StickRest")
	if stick and stick:IsA("GuiObject") and rest then
		local c = rest.AbsolutePosition + rest.AbsoluteSize / 2 - s.root.AbsolutePosition
		stick.AnchorPoint = Vector2.new(0.5, 0.5)
		stick.Position = UDim2.fromOffset(c.X, c.Y)
		stick.Visible = true
	end
end

local function labelOf(name: string): string
	local g = TouchControls.GROUP_OF[name]
	return if g then g.label else (TouchControls.EXTRA_LABELS :: any)[name] or name
end

local function sizeOf(s: Session, name: string): number
	local e = layoutOf(s)[name]
	return if e then e[3] else 1
end

local function barButton(s: Session, name: string): TextButton?
	local row = s.bar:FindFirstChild("Row", true)
	local b = row and row:FindFirstChild(name)
	return if b and b:IsA("TextButton") then b else nil
end

local function setLabel(b: TextButton?, text: string?, on: boolean?)
	if not b then
		return
	end
	local label = b:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		if text then
			label.Text = text
		end
		label.TextColor3 = if on then C.ink else C.white
	end
	b.BackgroundColor3 = if on then C.white else C.navy
end

-- The bar and the ring follow the state.
local function drawBar(s: Session)
	local _, p = TouchLayout.active(s.values)
	for i = 1, TouchControls.PROFILES do
		setLabel(barButton(s, "P" .. i), nil, i == p)
	end
	local name = s.selected
	local row = s.bar:FindFirstChild("Row", true)
	local sizeLabel = row and row:FindFirstChild("Size")
	if sizeLabel and sizeLabel:IsA("TextLabel") then
		sizeLabel.Text = if name
			then string.format("%d%%", math.floor(sizeOf(s, name) * 100 + 0.5))
			else "SIZE"
	end
	local g = name and TouchControls.GROUP_OF[name]
	local hideButton = barButton(s, "Hide")
	if name == "AmmoReadout" then
		setLabel(hideButton, if s.values.touchShowAmmo == false then "SHOW" else "HIDE", false)
	elseif g and g.canHide then
		setLabel(
			hideButton,
			if s.values["touch" .. g.key .. "On"] == false then "SHOW" else "HIDE",
			false
		)
	else
		setLabel(hideButton, "—", false)
	end
	local hint = s.bar:FindFirstChild("Hint", true)
	if hint and hint:IsA("TextLabel") then
		hint.Text = if name
			then labelOf(name) .. "  ·  DRAG TO MOVE"
			else "TAP A BUTTON, THEN DRAG IT"
	end
	local ring = s.bar:FindFirstChild("Selection")
	if ring and ring:IsA("GuiObject") then
		local h = name and handleOf(s, name)
		ring.Visible = h ~= nil
		if h then
			local c = h.AbsolutePosition + h.AbsoluteSize / 2 - s.bar.AbsolutePosition
			local d = math.max(h.AbsoluteSize.X, h.AbsoluteSize.Y) + 10
			ring.Position = UDim2.fromOffset(c.X, c.Y)
			ring.Size = UDim2.fromOffset(d, d)
		end
	end
end

local function redraw(s: Session)
	TouchLayout.refresh(s.root, s.values, true)
	placeStick(s)
	drawBar(s)
end

-- The movable object under a pointer (the same hit-test as the HUD).
local function pick(s: Session, position: Vector3): string?
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local ok, list = pcall(function()
		return pg:GetGuiObjectsAtPosition(position.X, position.Y)
	end)
	if not ok then
		return nil
	end
	local stick = s.root:FindFirstChild("Stick")
	for _, o in list do
		if o:IsDescendantOf(s.bar) and o:IsA("GuiButton") then
			return nil -- the bar's own buttons
		end
		if o:IsDescendantOf(s.preview) then
			local at: Instance? = o
			while at and at ~= s.root do
				if TouchControls.MOVABLE[at.Name] and at.Name ~= "StickRest" then
					return at.Name
				end
				if stick and at == stick then
					return "StickRest"
				end
				at = at.Parent
			end
		end
	end
	return nil
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Moves the picked object by the drag so far.
local function dragTo(s: Session, position: Vector3)
	local d = s.drag
	local name = s.selected
	if not d or not name then
		return
	end
	local delta = Vector2.new(position.X, position.Y) - d.start
	local root = s.root
	local rs = root.AbsoluteSize
	if rs.X <= 0 or rs.Y <= 0 then
		return
	end
	local c = d.centre + delta - root.AbsolutePosition
	local left = s.values.touchLeftHanded == true
	local fx, fy = math.clamp(c.X / rs.X, 0.02, 0.98), math.clamp(c.Y / rs.Y, 0.02, 0.98)
	local entry = { if left then 1 - fx else fx, fy, sizeOf(s, name) }
	layoutOf(s)[name] = entry
	local o = objectOf(s, name)
	if o then
		TouchLayout.place(root, o, entry, left)
	end
	if name == "StickRest" then
		placeStick(s)
	end
	drawBar(s)
end

local function resize(s: Session, step: number)
	local name = s.selected
	local o = name and objectOf(s, name)
	if not name or not o then
		return
	end
	local layout = layoutOf(s)
	local left = s.values.touchLeftHanded == true
	local e = layout[name] or TouchLayout.entryOf(s.root, o, left, 1)
	local size = math.clamp(
		math.floor((e[3] + step) * 10 + 0.5) / 10,
		TouchControls.SIZE_MIN,
		TouchControls.SIZE_MAX
	)
	layout[name] = { e[1], e[2], size }
	redraw(s)
end

local function toggleHide(s: Session)
	local name = s.selected
	if not name then
		return
	end
	if name == "AmmoReadout" then
		s.values.touchShowAmmo = s.values.touchShowAmmo == false
	else
		local g = TouchControls.GROUP_OF[name]
		if not g or not g.canHide then
			UiSfx.cue("Denied")
			return
		end
		local id = "touch" .. g.key .. "On"
		s.values[id] = s.values[id] == false
	end
	redraw(s)
end

local function finish(changes: Values?)
	local s = session
	if not s then
		return
	end
	session = nil
	for _, c in s.conns do
		c:Disconnect()
	end
	s.preview:Destroy()
	s.bar.Enabled = false
	local ring = s.bar:FindFirstChild("Selection")
	if ring and ring:IsA("GuiObject") then
		ring.Visible = false
	end
	s.onDone(changes)
end

-- The settings the editor changed, for Settings to save.
local function changesOf(s: Session): Values
	local out: Values =
		{ touchProfile = s.values.touchProfile, touchShowAmmo = s.values.touchShowAmmo }
	for i = 1, TouchControls.PROFILES do
		out["touchLayout" .. i] = s.values["touchLayout" .. i] or {}
	end
	for _, g in TouchControls.GROUPS do
		if g.canHide then
			out["touch" .. g.key .. "On"] = s.values["touch" .. g.key .. "On"]
		end
	end
	return out
end

function TouchEditor.isOpen(): boolean
	return session ~= nil
end

-- Closes without saving (Settings closing underneath).
function TouchEditor.cancel()
	finish(nil)
end

function TouchEditor.open(values: Values, onDone: (changes: Values?) -> ())
	if session then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	local bar = pg:FindFirstChild("TouchEditor")
	if not bar or not bar:IsA("ScreenGui") then
		warn("[TouchEditor] PlayerGui.TouchEditor missing (tools/studio/BuildTouchEditor.luau)")
		onDone(nil)
		return
	end
	local preview = UiRoot.source("Match", "Touch"):Clone()
	preview.Name = "TouchEditPreview"
	UiRoot.applyLayer(preview)
	preview.DisplayOrder = 90
	preview.Enabled = true
	-- a dark wash so it reads as edit mode (under the buttons)
	local wash = Instance.new("Frame")
	wash.Name = "EditWash"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = Color3.new(0, 0, 0)
	wash.BackgroundTransparency = 0.45
	wash.ZIndex = 0
	wash.Parent = preview
	for _, d in preview:GetDescendants() do
		if d:IsA("GuiButton") then
			d.Interactable = false
			d.Visible = true
		elseif d.Name == "AmmoReadout" and d:IsA("GuiObject") then
			d.Visible = true
		end
	end
	preview.Parent = pg
	local root = preview:WaitForChild("Root") :: Frame
	local s: Session = {
		preview = preview,
		bar = bar,
		root = root,
		values = deepCopy(values),
		selected = nil,
		drag = nil,
		conns = {},
		onDone = onDone,
	}
	session = s
	bar.Enabled = true

	local function hook(name: string, fn: () -> ())
		local b = barButton(s, name)
		if b then
			Plates.finish(b)
			for _, c in LobbyKit.button(b, fn) do
				table.insert(s.conns, c)
			end
		end
	end
	hook("Cancel", function()
		finish(nil)
	end)
	hook("Done", function()
		finish(changesOf(s))
	end)
	hook("Reset", function()
		s.values[profileKey(s)] = {}
		s.selected = nil
		redraw(s)
	end)
	for i = 1, TouchControls.PROFILES do
		hook("P" .. i, function()
			s.values.touchProfile = tostring(i)
			s.selected = nil
			redraw(s)
		end)
	end
	hook("Smaller", function()
		resize(s, -TouchControls.SIZE_STEP)
	end)
	hook("Bigger", function()
		resize(s, TouchControls.SIZE_STEP)
	end)
	hook("Hide", function()
		toggleHide(s)
	end)

	table.insert(
		s.conns,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if not isPointer(input) or s.drag then
				return
			end
			local name = pick(s, input.Position)
			if not name then
				return
			end
			s.selected = name
			local h = handleOf(s, name)
			if h then
				s.drag = {
					input = input,
					start = Vector2.new(input.Position.X, input.Position.Y),
					centre = h.AbsolutePosition + h.AbsoluteSize / 2,
				}
			end
			drawBar(s)
		end)
	)
	table.insert(
		s.conns,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local d = s.drag
			if not d then
				return
			end
			if
				input == d.input
				or (
					d.input.UserInputType == Enum.UserInputType.MouseButton1
					and input.UserInputType == Enum.UserInputType.MouseMovement
				)
			then
				dragTo(s, input.Position)
			end
		end)
	)
	table.insert(
		s.conns,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local d = s.drag
			if d and (input == d.input or input.UserInputType == d.input.UserInputType) then
				s.drag = nil
			end
		end)
	)
	task.defer(redraw, s) -- after the preview has its size
end

return TouchEditor
