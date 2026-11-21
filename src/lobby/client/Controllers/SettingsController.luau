--!strict
-- The lobby's Settings screen (vault/02 Art/UI Settings.md). Studio-built
-- StarterGui.Settings + row templates (tools/studio/BuildSettings.luau, then
-- BuildSettingsV2.luau); this fills them from Config/Settings through the
-- shared kit (Util/LobbyKit).
--
-- Tabs VIDEO / AUDIO / GAMEPLAY / CROSSHAIR / KEYBINDS, each a list of
-- sections and rows (toggle, slider with a typed value, dropdown, colour
-- picker, keybind boxes) and a RESET TAB at the end. INSPECT explains the row
-- you point at; on the crosshair tab it shows the crosshair (and hitmarker)
-- live. Values are the player's saved settings (Shared/PlayerSettings): edited
-- here, sent SEND_DELAY after the last change and when the screen closes, saved
-- by the Lobby's SettingsService. Live today: reduced motion and UI sounds;
-- the rest are saved for the systems that will read them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HitFx = require(ReplicatedStorage.Shared.Config.HitFx)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Plates = require(script.Parent.Parent.Util.Plates)

local SettingsController = {}

type Row = Settings.Row
type Values = PlayerSettings.Values

local player = Players.LocalPlayer
local C = LobbyKit.C
local DESIGN = Vector2.new(1920, 1080)
local PREVIEW_ZOOM = 3 -- the preview draws the 1080p crosshair this much bigger
local LIST_W = 940 -- the list's normal width (KEYBINDS widens it)
local LIST_WIDE = 1640
local ROW_W = 860
local SUB_INDENT = 44
local CROSSHAIR_TAB = 4

local values: Values = PlayerSettings.defaults()
local loaded = false -- the saved values arrived (until then nothing is sent)
local sendToken = 0
local sentJson = ""

local gui: ScreenGui
local canvas: Frame
local list: ScrollingFrame
local inspect: Frame
local head: TextLabel
local desc: TextLabel
local preview: Frame
local mark: Frame
local templates: Folder
local picker: GuiButton
local confirmBox: Frame
local dropList: Frame
local current = 0
local dragConns: { RBXScriptConnection } = {}
local refresh: { [string]: () -> () } = {} -- per shown row: redraw its control
local closePopups: () -> () = function() end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function disconnectDrags()
	for _, c in dragConns do
		c:Disconnect()
	end
	table.clear(dragConns)
end

--------------------------------------------------------------------------------
-- Values: apply, send

local function applyLive()
	UiMotion.setReduced(values.reducedMotion == true)
	UiSfx.setEnabled(values.uiSounds ~= false)
end

local function send()
	if not loaded then
		return
	end
	local json = PlayerSettings.encode(values)
	if json == sentJson then
		return
	end
	sentJson = json
	LobbyNet.event("SettingsRequest"):FireServer("save", values)
end

local function queueSend()
	sendToken += 1
	local token = sendToken
	task.delay(Settings.SEND_DELAY, function()
		if token == sendToken then
			send()
		end
	end)
end

local function dependsOn(id: string): boolean
	for _, row in Settings.BY_ID do
		if (row.showIf and row.showIf.id == id) or (row.lockIf and row.lockIf.id == id) then
			return true
		end
	end
	return false
end

local renderTab: (i: number, keepScroll: boolean?) -> () = function() end
local redraw: () -> () = function() end

local function set(id: string, v: any)
	values[id] = v
	applyLive()
	queueSend()
	if dependsOn(id) then
		renderTab(current, true) -- a row appears / unlocks
	else
		local r = refresh[id]
		if r then
			r()
		end
	end
	redraw()
end

local function locked(row: Row): boolean
	return row.lockIf ~= nil and values[row.lockIf.id] == row.lockIf.value
end

local function shown(row: Row): boolean
	return row.showIf == nil or values[row.showIf.id] == row.showIf.value
end

local function fmt(row: Row, v: number): string
	local step = row.step or 1
	local s = if step < 1 then string.format("%.1f", v) else tostring(math.floor(v + 0.5))
	return s .. (row.unit or "")
end

-- canvas design px of a point on screen (the canvas is scaled to fit)
local function toCanvas(p: Vector2): Vector2
	local k = canvas.AbsoluteSize.X / DESIGN.X
	return (p - canvas.AbsolutePosition) / math.max(k, 1e-3)
end

local function inside(obj: GuiObject, p: Vector2): boolean
	local a, s = obj.AbsolutePosition, obj.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

--------------------------------------------------------------------------------
-- The live crosshair preview (and the hitmarker, on its rows)

local inspected: Row? = nil

local function bar(
	parent: Instance,
	w: number,
	h: number,
	x: number,
	y: number,
	color: Color3,
	z: number,
	rot: number?
)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	f.ZIndex = z
	f.Parent = parent
end

local OUTLINE = Color3.fromHex("06080C")

local function drawCrosshair()
	mark:ClearAllChildren()
	mark.Rotation = if values.chX then 45 else 0
	local k = (values.chScale :: number) * PREVIEW_ZOOM
	local len = math.max(1, math.floor((values.chLength :: number) * k + 0.5))
	local th = math.max(1, math.floor((values.chThickness :: number) * k + 0.5))
	local gap = math.floor((values.chGap :: number) * k + 0.5)
	local o = if values.chOutline then math.max(1, math.floor(k + 0.5)) else 0
	local color = PlayerSettings.color(values, "chColor")
	local function piece(w: number, h: number, x: number, y: number)
		if o > 0 then
			bar(mark, w + o * 2, h + o * 2, x, y, OUTLINE, 5)
		end
		bar(mark, w, h, x, y, color, 6)
	end
	local d = gap + len / 2
	piece(th, len, 0, -d)
	piece(th, len, 0, d)
	piece(len, th, -d, 0)
	piece(len, th, d, 0)
	if values.chDot then
		local s = math.max(1, math.floor(2 * k + 0.5))
		piece(s, s, 0, 0)
	end
	-- the hitmarker, while a hitmarker row is inspected
	local row = inspected
	if not (row and string.sub(row.id, 1, 2) == "hm" and values.hmEnabled) then
		return
	end
	local hit =
		PlayerSettings.color(values, if row.id == "hmCritColor" then "hmCritColor" else "hmColor")
	local size = (values.hmSize :: number) / 100 * PREVIEW_ZOOM
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Rotation = -mark.Rotation
	holder.ZIndex = 7
	holder.Parent = mark
	local style = values.hmStyle
	if style == "Dot" then
		bar(holder, 5 * size, 5 * size, 0, 0, OUTLINE, 7)
		bar(holder, 3 * size, 3 * size, 0, 0, hit, 8)
		return
	end
	if style == "Original" then
		-- the match's own marker (Util/HitFeedback): HitFx's blade image on the
		-- diagonals, tips toward the centre, at its resting size
		local spec = HitFx.MARKER.Body
		local blade = spec.length * size
		local dist = (spec.gap * size) + blade / 2
		for i = 0, 3 do
			local a = math.rad(45 + i * 90)
			local img = Instance.new("ImageLabel")
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.BackgroundTransparency = 1
			img.Image = HitFx.TEXTURES.marker
			img.ImageColor3 = hit
			img.Rotation = 45 + 90 * i + 90
			img.Size = UDim2.fromOffset(blade * HitFx.MARKER_ASPECT, blade)
			img.Position = UDim2.fromOffset(math.cos(a) * dist, math.sin(a) * dist)
			img.ZIndex = 8
			img.Parent = holder
		end
		return
	end
	local l = 8 * size
	local w = 1.5 * size
	local r = 12 * size
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local x, y = math.cos(a) * r, math.sin(a) * r
		bar(holder, l + 2, w + 2, x, y, OUTLINE, 7, 45 + i * 90)
		bar(holder, l, w, x, y, hit, 8, 45 + i * 90)
	end
end

--------------------------------------------------------------------------------
-- Inspect

local function inspectRow(row: Row)
	if inspected == row then
		return
	end
	inspected = row
	head.Text = row.label
	local text = row.desc
	if locked(row) and row.lockIf then
		text ..= "  (" .. row.lockIf.why .. ")"
	end
	desc.Text = text
	desc.TextColor3 = if row.warn then C.red else C.muted
	for _, l in { head, desc } do
		l.TextTransparency = 0.6
		UiMotion.tween(l, 0.18, { TextTransparency = 0 })
	end
	redraw()
end

--------------------------------------------------------------------------------
-- Controls

local function fillToggle(control: Frame, row: Row, rowButton: GuiButton)
	local t = (templates:WaitForChild("SettingToggle") :: Frame):Clone()
	t.Parent = control
	local switch = child(t, "Switch") :: TextButton
	local state = child(switch, "State") :: TextLabel
	Plates.finish(switch)
	-- the knob: a dark block that slides to the ON / OFF side (Quint Out)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(46, 30)
	knob.BorderSizePixel = 0
	knob.ZIndex = state.ZIndex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = knob
	knob.Parent = switch
	state.Size = UDim2.new(0.55, 0, 1, 0)
	state.AnchorPoint = Vector2.new(0.5, 0)
	local first = true
	local function look()
		local on = values[row.id] == true
		local time = if first then 0 else 0.3
		first = false
		UiMotion.tween(switch, time, { BackgroundColor3 = if on then C.white else C.navyHi })
		UiMotion.tween(knob, time, {
			Position = UDim2.fromScale(if on then 0.76 else 0.24, 0.5),
			BackgroundColor3 = if on then C.ink else C.muted,
		})
		state.Text = if on then "ON" else "OFF"
		UiMotion.tween(state, time, {
			Position = UDim2.fromScale(if on then 0.34 else 0.66, 0),
			TextColor3 = if on then C.ink else C.muted,
		})
	end
	look()
	refresh[row.id] = look
	local function flip()
		if locked(row) then
			UiSfx.cue("Denied")
			return
		end
		local on = not (values[row.id] == true)
		UiSfx.cue(if on then "ToggleOn" else "ToggleOff")
		set(row.id, on)
	end
	LobbyKit.button(switch, flip)
	rowButton.Activated:Connect(flip)
end

local function fillSlider(control: Frame, row: Row)
	local s = (templates:WaitForChild("SettingSlider") :: Frame):Clone()
	s.Parent = control
	local track = child(s, "Track") :: TextButton
	local fill = child(track, "Fill") :: Frame
	local knob = child(track, "Knob") :: Frame
	local knobPop = child(knob, "Pop") :: UIScale
	local valueBox = child(s, "Value") :: TextBox
	local lo, hi = row.min or 0, row.max or 1
	local function show(ease: number?)
		local v = values[row.id] :: number
		local a = (v - lo) / (hi - lo)
		if ease and ease > 0 then
			UiMotion.tween(fill, ease, { Size = UDim2.fromScale(a, 1) })
			UiMotion.tween(knob, ease, { Position = UDim2.fromScale(a, 0.5) })
		else
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
		end
		if not valueBox:IsFocused() then
			valueBox.Text = fmt(row, v)
		end
	end
	show()
	refresh[row.id] = function()
		show(0.16)
	end
	local function setFromX(x: number)
		local a =
			math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = PlayerSettings.snap(row, lo + a * (hi - lo))
		if v ~= values[row.id] then
			values[row.id] = v
			applyLive()
			queueSend()
			redraw()
		end
		show()
	end
	-- typed value: numbers only, clamped and stepped
	valueBox.Focused:Connect(function()
		valueBox.Text = string.gsub(fmt(row, values[row.id]), "[^%d%.%-]", "")
	end)
	valueBox.FocusLost:Connect(function()
		local n = tonumber((string.gsub(valueBox.Text, "[^%d%.%-]", "")))
		if n and n == n and math.abs(n) ~= math.huge then
			set(row.id, PlayerSettings.snap(row, n))
		end
		valueBox.Text = fmt(row, values[row.id])
	end)
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		UiSfx.claim() -- sliders are silent (owner: Settings sounds were too much)
		setFromX(input.Position.X)
		UiMotion.rest(knobPop, LobbyKit.M.hover)
		disconnectDrags()
		table.insert(
			dragConns,
			UserInputService.InputChanged:Connect(function(move: InputObject)
				if
					move.UserInputType == Enum.UserInputType.MouseMovement
					or move.UserInputType == Enum.UserInputType.Touch
				then
					setFromX(move.Position.X)
				end
			end)
		)
		table.insert(
			dragConns,
			UserInputService.InputEnded:Connect(function(done: InputObject)
				if done.UserInputType == t then
					UiMotion.rest(knobPop, 1)
					disconnectDrags()
				end
			end)
		)
	end)
end

-- Force Controls: the new choice stays only if KEEP is pressed in time.
local confirmToken = 0
local keepFn: () -> () = function() end
local revertFn: () -> () = function() end
local function askKeep(row: Row, old: any)
	confirmToken += 1
	local token = confirmToken
	local body = child(confirmBox, "Body") :: TextLabel
	local pop = LobbyKit.pop(confirmBox)
	confirmBox.Visible = true
	UiMotion.popIn(pop)
	local function finish(keep: boolean)
		if token ~= confirmToken then
			return
		end
		confirmToken += 1
		confirmBox.Visible = false
		if not keep then
			set(row.id, old)
		end
		UiSfx.cue(if keep then "Confirm" else "Back")
	end
	keepFn = function()
		finish(true)
	end
	revertFn = function()
		finish(false)
	end
	task.spawn(function()
		for t = Settings.CONFIRM_SECONDS, 1, -1 do
			if token ~= confirmToken then
				return
			end
			body.Text = `IF YOUR CONTROLS STOPPED WORKING, WAIT: GOING BACK TO {string.upper(
				tostring(old)
			)} IN {t}`
			task.wait(1)
		end
		finish(false)
	end)
end

local function openDropdown(row: Row, anchor: GuiObject)
	closePopups()
	local optTemplate = templates:WaitForChild("DropOption") :: TextButton
	for _, c in dropList:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	for i, choice in row.choices or {} do
		local o = optTemplate:Clone()
		o.LayoutOrder = i
		local label = child(o, "Label") :: TextLabel
		label.Text = string.upper(choice)
		local picked = values[row.id] == choice
		o.BackgroundColor3 = if picked then C.white else C.navy
		label.TextColor3 = if picked then C.ink else C.white
		o.MouseEnter:Connect(function()
			if values[row.id] ~= choice then
				UiMotion.tween(o, 0.15, { BackgroundColor3 = C.navyHi })
			end
		end)
		o.MouseLeave:Connect(function()
			if values[row.id] ~= choice then
				UiMotion.tween(o, 0.15, { BackgroundColor3 = C.navy })
			end
		end)
		o.Activated:Connect(function()
			dropList.Visible = false
			local old = values[row.id]
			if old == choice then
				return
			end
			UiSfx.cue("Click")
			set(row.id, choice)
			if row.confirm then
				askKeep(row, old)
			end
		end)
		o.Parent = dropList
	end
	-- under the plate, in canvas px
	local at = toCanvas(anchor.AbsolutePosition + Vector2.new(0, anchor.AbsoluteSize.Y))
	local w = anchor.AbsoluteSize.X / (canvas.AbsoluteSize.X / DESIGN.X)
	dropList.Size = UDim2.fromOffset(w, 0)
	dropList.Position = UDim2.fromOffset(at.X, at.Y + 6)
	dropList.Visible = true
end

local function fillDropdown(control: Frame, row: Row)
	local d = (templates:WaitForChild("SettingDropdown") :: Frame):Clone()
	d.Parent = control
	local plate = child(d, "Plate") :: TextButton
	local label = child(plate, "Label") :: TextLabel
	Plates.finish(plate)
	local function look()
		label.Text = string.upper(tostring(values[row.id]))
	end
	look()
	refresh[row.id] = look
	LobbyKit.button(plate, function()
		if dropList.Visible then
			dropList.Visible = false
			return
		end
		openDropdown(row, plate)
	end)
end

-- the colour picker: hue / saturation wheel, brightness bar, RGB and hex
local pickRow: Row? = nil
local hsv = { 0, 0, 1 }
local pickerShow: () -> () = function() end

local function openPicker(row: Row)
	closePopups()
	pickRow = row
	local h, s, v = PlayerSettings.color(values, row.id):ToHSV()
	hsv = { h, s, v }
	local pickerHead = child(picker, "Head") :: TextLabel
	pickerHead.Text = row.label
	picker.Visible = true
	UiMotion.popIn(LobbyKit.pop(picker))
	pickerShow()
end

local function fillColor(control: Frame, row: Row)
	local c = (templates:WaitForChild("SettingColor") :: Frame):Clone()
	c.Parent = control
	local plate = child(c, "Plate") :: TextButton
	local swatch = child(plate, "Swatch") :: Frame
	local hexLabel = child(plate, "Hex") :: TextLabel
	Plates.finish(plate)
	local function look()
		swatch.BackgroundColor3 = PlayerSettings.color(values, row.id)
		hexLabel.Text = "#" .. tostring(values[row.id])
	end
	look()
	refresh[row.id] = look
	LobbyKit.button(plate, function()
		UiSfx.cue("Click")
		openPicker(row)
	end)
end

local function setupPicker()
	local wheel = child(picker, "Wheel") :: ImageButton
	local shade = child(wheel, "Shade") :: Frame
	local cursor = child(wheel, "Cursor") :: Frame
	local barBtn = child(picker, "Bar") :: TextButton
	local barGrad = barBtn:FindFirstChildWhichIsA("UIGradient")
	local barKnob = child(barBtn, "Knob") :: Frame
	local hexCell = child(picker, "Hex") :: Frame
	local hexBox = child(hexCell, "Box") :: TextBox
	local boxes: { TextBox } = {}
	for i, n in { "R", "G", "B" } do
		boxes[i] = child(child(picker, n), "Box") :: TextBox
	end

	local function colour(): Color3
		return Color3.fromHSV(hsv[1], hsv[2], hsv[3])
	end
	pickerShow = function()
		local h, s, v = hsv[1], hsv[2], hsv[3]
		local a = h * 2 * math.pi
		cursor.Position = UDim2.fromScale(0.5 + math.sin(a) * s / 2, 0.5 - math.cos(a) * s / 2)
		cursor.BackgroundColor3 = Color3.fromHSV(h, s, 1)
		shade.BackgroundTransparency = v
		if barGrad then
			barGrad.Color = ColorSequence.new(Color3.fromHSV(h, s, 1), Color3.new(0, 0, 0))
		end
		barKnob.Position = UDim2.fromScale(0.5, 1 - v)
		local c = colour()
		local rgb = { c.R, c.G, c.B }
		for i, b in boxes do
			if not b:IsFocused() then
				b.Text = tostring(math.floor(rgb[i] * 255 + 0.5))
			end
		end
		hexCell.BackgroundColor3 = c
		hexBox.TextColor3 = if v > 0.75 and (c.R * 0.3 + c.G * 0.59 + c.B * 0.11) > 0.6
			then C.ink
			else C.white
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. PlayerSettings.hex(c)
		end
	end
	local function commit()
		pickerShow()
		local row = pickRow
		if row then
			local hex = PlayerSettings.hex(colour())
			if values[row.id] ~= hex then
				set(row.id, hex)
			end
		end
	end
	local function fromWheel(p: Vector2)
		local r = wheel.AbsoluteSize.X / 2
		local centre = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local dx, dy = p.X - centre.X, p.Y - centre.Y
		hsv[1] = (math.atan2(dx, -dy) / (2 * math.pi)) % 1
		hsv[2] = math.clamp(math.sqrt(dx * dx + dy * dy) / math.max(r, 1), 0, 1)
		if hsv[3] < 0.05 then
			hsv[3] = 1 -- picking a hue on a black colour: make it visible
		end
		commit()
	end
	local function fromBar(p: Vector2)
		local a = (p.Y - barBtn.AbsolutePosition.Y) / math.max(barBtn.AbsoluteSize.Y, 1)
		hsv[3] = 1 - math.clamp(a, 0, 1)
		commit()
	end
	local function drag(target: GuiObject, onMove: (Vector2) -> ())
		target.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
				return
			end
			onMove(Vector2.new(input.Position.X, input.Position.Y))
			disconnectDrags()
			table.insert(
				dragConns,
				UserInputService.InputChanged:Connect(function(move: InputObject)
					if
						move.UserInputType == Enum.UserInputType.MouseMovement
						or move.UserInputType == Enum.UserInputType.Touch
					then
						onMove(Vector2.new(move.Position.X, move.Position.Y))
					end
				end)
			)
			table.insert(
				dragConns,
				UserInputService.InputEnded:Connect(function(done: InputObject)
					if done.UserInputType == t then
						disconnectDrags()
					end
				end)
			)
		end)
	end
	drag(wheel, fromWheel)
	drag(barBtn, fromBar)
	for i, b in boxes do
		b.FocusLost:Connect(function()
			local n = tonumber(b.Text)
			local c = colour()
			local rgb = { c.R, c.G, c.B }
			if n and n == n then
				rgb[i] = math.clamp(math.floor(n), 0, 255) / 255
				local h, s, v = Color3.new(rgb[1], rgb[2], rgb[3]):ToHSV()
				hsv = { h, s, v }
			end
			b.Text = "" -- pickerShow refills it
			commit()
		end)
	end
	hexBox.FocusLost:Connect(function()
		local t = string.upper((string.gsub(hexBox.Text, "[^%x]", "")))
		if #t == 3 then
			t = string.gsub(t, "(%x)", "%1%1")
		end
		if #t == 6 then
			local h, s, v = Color3.fromHex(t):ToHSV()
			hsv = { h, s, v }
		end
		hexBox.Text = ""
		commit()
	end)
	LobbyKit.button(child(picker, "Close") :: GuiButton, function()
		UiSfx.cue("Back")
		picker.Visible = false
		pickRow = nil
	end)
end

-- keybinds: click a box, press a key
local capture: { row: Row, col: number, label: TextLabel, since: number }? = nil
local MOUSE_KEYS: { [Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "MouseLeftButton",
	[Enum.UserInputType.MouseButton2] = "MouseRightButton",
	[Enum.UserInputType.MouseButton3] = "MouseMiddleButton",
}

local function keyText(name: string): string
	return if name == "" then "-" else Settings.keyLabel(name)
end

local function endCapture()
	local cap = capture
	capture = nil
	if cap then
		local r = refresh[cap.row.id]
		if r then
			r()
		end
	end
end

local function onCaptureInput(input: InputObject)
	local cap = capture
	if not cap or os.clock() - cap.since < 0.05 then
		return
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Escape then
		endCapture()
		return
	end
	local name: string? = nil
	if kc == Enum.KeyCode.Backspace or kc == Enum.KeyCode.Delete then
		name = ""
	elseif cap.col < 3 then
		if input.UserInputType == Enum.UserInputType.Keyboard and kc.Value ~= 0 then
			name = kc.Name
		else
			name = MOUSE_KEYS[input.UserInputType]
		end
	elseif string.find(input.UserInputType.Name, "^Gamepad") and kc.Value ~= 0 then
		if kc ~= Enum.KeyCode.Thumbstick1 and kc ~= Enum.KeyCode.Thumbstick2 then
			name = kc.Name
		end
	end
	if name == nil then
		return -- not a key for this column
	end
	local row = cap.row
	capture = nil
	local now = table.clone(values[row.id] :: { string })
	now[cap.col] = name
	UiSfx.cue("Click")
	set(row.id, now)
end

local function fillKeys(item: TextButton, row: Row)
	local keys = (templates:WaitForChild("SettingKeys") :: Frame):Clone()
	local control = item:FindFirstChild("Control")
	if control then
		control:Destroy()
	end
	keys.Parent = item
	local cells: { TextButton } = {}
	local labels: { TextLabel } = {}
	for i = 1, 3 do
		cells[i] = child(keys, "Key" .. i) :: TextButton
		labels[i] = child(cells[i], "Label") :: TextLabel
	end
	local function look()
		local now = values[row.id] :: { string }
		for i, l in labels do
			local waiting = capture ~= nil and capture.row == row and capture.col == i
			l.Text = if waiting then "PRESS A KEY" else keyText(now[i])
			l.TextSize = if waiting then 18 else 22
			l.TextColor3 = if waiting
				then C.cyan
				elseif row.locked then C.muted
				elseif now[i] == "" then C.muted
				else C.white
			cells[i].BackgroundColor3 = if waiting then C.ink else C.navyHi
		end
	end
	look()
	refresh[row.id] = look
	for i, cell in cells do
		LobbyKit.button(cell, function()
			if row.locked then
				UiSfx.cue("Denied")
				return
			end
			local was = capture
			capture = { row = row, col = i, label = labels[i], since = os.clock() }
			if was and was.row ~= row then
				local r = refresh[was.row.id]
				if r then
					r()
				end
			end
			look()
		end, {
			enabled = function()
				return not row.locked
			end,
		})
	end
end

--------------------------------------------------------------------------------
-- Rows and tabs

local function resetTab(tabIndex: number)
	local tab = Settings.TABS[tabIndex]
	for _, section in tab.sections do
		for _, row in section.rows do
			values[row.id] = PlayerSettings.default(row.id)
		end
	end
	applyLive()
	queueSend()
	UiSfx.cue("Back")
	renderTab(tabIndex, true)
end

local function addRow(row: Row, order: number, wide: boolean)
	local tpl = templates:WaitForChild("SettingRow") :: TextButton
	local isLocked = locked(row)
	local rowW = (if wide then LIST_WIDE - 60 else ROW_W) - (if row.sub then SUB_INDENT else 0)
	local item = LobbyKit.slot(tpl, list, function(r: TextButton)
		r.Name = row.id
		r.LayoutOrder = order
		r.Size = UDim2.fromOffset(rowW, if row.kind == "key" then 70 else 90)
		StateValues.set(r, "Slot", true)
		local nameLabel = child(r, "Name") :: TextLabel
		nameLabel.Text = row.label
		nameLabel.TextColor3 = if isLocked then C.muted else C.white
		nameLabel.TextSize = if row.sub then 23 else 26
		nameLabel.Size = UDim2.new(0, 420, 1, 0)
		local note = r:FindFirstChild("Note") :: TextLabel?
		local noteText = if isLocked and row.lockIf then row.lockIf.why else row.note
		if note and noteText then
			note.Text = noteText
			note.TextColor3 = if row.warn or isLocked then C.red else C.muted
			note.Visible = true
			nameLabel.Position = UDim2.fromOffset(30, -12)
		end
	end)
	-- a sub-row sits indented under its parent (its holder keeps the full width)
	if row.sub then
		local holder = item.Parent
		if holder and holder ~= list and holder:IsA("GuiObject") then
			holder.Size = UDim2.fromOffset(rowW + SUB_INDENT, item.Size.Y.Offset)
		end
	end
	if row.kind == "key" then
		fillKeys(item, row)
	else
		local control = child(item, "Control") :: Frame
		if row.kind == "toggle" then
			fillToggle(control, row, item)
		elseif row.kind == "slider" then
			fillSlider(control, row)
		elseif row.kind == "choice" then
			fillDropdown(control, row)
		elseif row.kind == "color" then
			fillColor(control, row)
		end
		if isLocked then
			for _, d in control:GetDescendants() do
				if d:IsA("GuiObject") then
					d.Active = false
				end
			end
			control.Visible = true
			local cover = Instance.new("Frame") -- dims the control
			cover.Name = "LockDim"
			cover.Size = UDim2.fromScale(1, 1)
			cover.BackgroundTransparency = 1
			cover.ZIndex = 20
			cover.Parent = control
			for _, d in control:GetDescendants() do
				if d:IsA("TextLabel") then
					d.TextTransparency = 0.55
				elseif d:IsA("ImageLabel") then
					d.ImageTransparency = 0.55
				end
			end
		end
	end
	-- hover: the row lifts its colour, its name eases in a little, INSPECT reads it
	item:SetAttribute("UiSound", if row.kind == "toggle" and not isLocked then nil else "none")
	local rowBg = item.BackgroundTransparency
	local rowColour = item.BackgroundColor3
	local nameLabel = child(item, "Name") :: TextLabel
	local nameHome = nameLabel.Position
	if row.sub then
		local holder = item.Parent
		if holder and holder ~= list then
			item.Position = UDim2.new(0.5, SUB_INDENT / 2, 0.5, 0)
		end
	end
	LobbyKit.button(item, function() end, {
		hover = 1,
		enabled = function()
			return false
		end,
		onHover = function(on: boolean)
			UiMotion.tween(item, 0.2, {
				BackgroundTransparency = if on then math.max(rowBg - 0.15, 0) else rowBg,
				BackgroundColor3 = if on then C.navyHi else rowColour,
			})
			UiMotion.tween(nameLabel, 0.25, {
				Position = if on then nameHome + UDim2.fromOffset(8, 0) else nameHome,
			})
			if on then
				inspectRow(row)
			end
		end,
	})
	return item
end

local function addSection(title: string, order: number, wide: boolean)
	local tpl = templates:WaitForChild("SettingSection") :: Frame
	local s = tpl:Clone()
	s.Name = "Section" .. order
	s.LayoutOrder = order
	s.Size = UDim2.fromOffset(if wide then LIST_WIDE - 60 else ROW_W, if order == 1 then 50 else 70)
	StateValues.set(s, "Slot", true);
	(child(s, "Title") :: TextLabel).Text = title
	s.Parent = list
end

renderTab = function(i: number, keepScroll: boolean?)
	current = i
	closePopups()
	capture = nil
	disconnectDrags()
	table.clear(refresh)
	local scroll = list.CanvasPosition
	LobbyKit.clearSlots(list)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local tab = Settings.TABS[i]
	local wide = tab.id == "keybinds"
	inspect.Visible = not wide
	list.Size = UDim2.fromOffset(if wide then LIST_WIDE else LIST_W, 740)
	preview.Visible = i == CROSSHAIR_TAB

	local order = 0
	local items: { GuiObject } = {}
	local firstRow: Row? = nil
	if wide then
		order += 1
		local h = (templates:WaitForChild("SettingKeyHeader") :: Frame):Clone()
		h.LayoutOrder = order
		h.Size = UDim2.fromOffset(LIST_WIDE - 60, 60)
		StateValues.set(h, "Slot", true)
		h.Parent = list
	end
	for _, section in tab.sections do
		order += 1
		addSection(section.title, order, wide)
		for _, row in section.rows do
			if shown(row) then
				order += 1
				table.insert(items, addRow(row, order, wide))
				firstRow = firstRow or row
			end
		end
	end
	order += 1
	local reset = (templates:WaitForChild("SettingReset") :: Frame):Clone()
	reset.LayoutOrder = order
	StateValues.set(reset, "Slot", true)
	reset.Parent = list
	local resetBtn = child(reset, "Button") :: TextButton
	Plates.finish(resetBtn)
	resetBtn:SetAttribute("UiSound", "none")
	LobbyKit.button(resetBtn, function()
		resetTab(i)
	end, {
		onHover = function(on: boolean)
			UiMotion.tween(resetBtn, 0.2, { BackgroundColor3 = if on then C.red else C.navyHi })
		end,
	})

	if keepScroll then
		task.defer(function()
			list.CanvasPosition = scroll
		end)
	else
		list.CanvasPosition = Vector2.zero
		-- the tab's rows rise in one after another
		for n, item in items do
			local pop = item:FindFirstChild("Pop")
			if pop and pop:IsA("UIScale") then
				local bg = item.BackgroundTransparency
				pop.Scale = 0.97
				item.BackgroundTransparency = 1
				task.delay(math.min(n - 1, 12) * 0.025, function()
					if item.Parent then
						UiMotion.tween(pop, 0.3, { Scale = 1 })
						UiMotion.tween(item, 0.3, { BackgroundTransparency = bg })
					end
				end)
			end
		end
		if firstRow then
			inspected = nil
			inspectRow(firstRow)
		end
	end
	redraw()
end

--------------------------------------------------------------------------------

local function loadSaved()
	task.spawn(function()
		local saved = PlayerSettings.read(player, 60)
		if not saved then
			warn("[Settings] the saved settings didn't arrive; changes won't be saved this session")
			return
		end
		values = saved
		sentJson = PlayerSettings.encode(values)
		loaded = true
		applyLive()
		if gui.Enabled and current > 0 then
			renderTab(current, true)
		end
	end)
end

function SettingsController.init()
	local g = player:WaitForChild("PlayerGui"):WaitForChild("Settings", 15)
	local folder = ReplicatedStorage:WaitForChild("UiTemplates", 15)
	local lobby = folder and folder:WaitForChild("Lobby", 15)
	if not (g and g:IsA("ScreenGui") and lobby) then
		warn(
			"[Settings] StarterGui.Settings or its templates missing (tools/studio/BuildSettingsV2.luau)"
		)
		return
	end
	gui = g
	gui.Enabled = false
	templates = lobby :: Folder
	canvas = child(gui, "Canvas") :: Frame
	list = child(canvas, "List") :: ScrollingFrame
	inspect = child(canvas, "Inspect") :: Frame
	head = child(inspect, "Head") :: TextLabel
	desc = child(inspect, "Desc") :: TextLabel
	preview = child(inspect, "Preview") :: Frame
	mark = child(preview, "Crosshair") :: Frame
	picker = child(canvas, "ColorPicker") :: GuiButton
	confirmBox = child(canvas, "Confirm") :: Frame
	dropList = child(canvas, "Dropdown") :: Frame
	redraw = drawCrosshair

	Plates.deepen(gui)
	setupPicker()
	LobbyKit.button(child(confirmBox, "Keep") :: GuiButton, function()
		keepFn()
	end)
	LobbyKit.button(child(confirmBox, "Revert") :: GuiButton, function()
		revertFn()
	end)

	closePopups = function()
		dropList.Visible = false
		picker.Visible = false
		pickRow = nil
	end
	-- a click outside an open dropdown / picker closes it; keybind capture
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not gui.Enabled then
			return
		end
		if capture then
			onCaptureInput(input)
			return
		end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		local p = Vector2.new(input.Position.X, input.Position.Y)
		if dropList.Visible and not inside(dropList, p) then
			task.defer(function()
				dropList.Visible = false
			end)
		end
		if picker.Visible and not inside(picker, p) then
			picker.Visible = false
			pickRow = nil
		end
	end)
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		dropList.Visible = false
	end)

	local tabs = child(canvas, "Tabs") :: Frame
	local buttons: { GuiButton } = {}
	for _, tab in Settings.TABS do
		table.insert(buttons, child(tabs, tab.label) :: GuiButton)
	end
	local pick = LobbyKit.tabs(buttons, function(i: number)
		renderTab(i)
	end)

	LobbyKit.page({
		name = "Settings",
		gui = gui,
		canvas = canvas,
		design = DESIGN,
		wash = child(gui, "Wash") :: Frame,
		close = child(canvas, "Close") :: GuiButton,
		focus = function()
			return list:FindFirstChildWhichIsA("GuiButton", true)
		end,
		-- phones: the title, tabs and list fill the screen; INSPECT steps
		-- aside (the full mobile settings come with the mobile UI)
		phone = {
			region = Rect.new(130, 20, 1090, 500),
			arrange = function()
				inspect.Visible = false
				local close = child(canvas, "Close") :: GuiObject
				close.Position = UDim2.fromOffset(1040, 76)
				list.Size = UDim2.fromOffset(940, 270)
			end,
		},
		onOpen = function(arg: any?)
			if arg == "crosshair" then
				pick(CROSSHAIR_TAB)
			elseif current == 0 then
				pick(1)
			else
				renderTab(current)
			end
		end,
		onClose = function()
			closePopups()
			capture = nil
			sendToken += 1
			send()
		end,
	})
	current = 0
	loadSaved()
end

return SettingsController
