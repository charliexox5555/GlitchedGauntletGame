--!strict
-- Lobby UI motion kit. Timings are named tokens (LihFolk: UI Motion Language
-- and Timing; LihFolk UI Spec): feedback 0.05-0.1 s, exits 0.12 s with In
-- easing and no overshoot, entrances about 0.22 s, big reveals 0.4 s. Pops and
-- presses use a child "PopScale" UIScale (the cluster's "Fit" UIScale is
-- Layout's). Reduced motion (GuiService.ReducedMotionEnabled or the Settings
-- toggle) turns movement into fades: positions, sizes, rotations and pops jump
-- to their end value, loops and sweeps stop, transparency and colour still ease.
-- Idle loops pause while their ScreenGui is disabled.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Sound = require(script.Parent.Sound)
local Style = require(script.Parent.Style)

local Fx = {}

local C = Style.COLOR

Fx.MOTION = table.freeze({
	press = 0.05,
	hover = 0.1,
	exit = 0.12,
	dimIn = 0.18,
	dimOut = 0.12,
	enter = 0.22,
	settle = 0.28, -- press release / pop settle (Back Out)
	reveal = 0.4, -- MATCH FOUND, the bars' entrance
	stagger = 0.04, -- per item; totals stay under 0.4 s
})

Fx.HOVER_SCALE = 1.04
Fx.PRESS_SCALE = 0.96
Fx.HOVER_LIFT = 3

local reducedOverride: boolean? = nil

function Fx.reduced(): boolean
	if reducedOverride ~= nil then
		return reducedOverride
	end
	local ok, v = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and v == true
end

-- The Settings toggle (nil = follow the Roblox setting).
function Fx.setReduced(on: boolean?)
	reducedOverride = on
end

local MOVEMENT = { Position = true, Size = true, Rotation = true, Scale = true, Offset = true }

function Fx.tween(
	obj: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	if Fx.reduced() then
		local rest: { [string]: any } = {}
		local any = false
		for k, v in props do
			if MOVEMENT[k] then
				(obj :: any)[k] = v
			else
				rest[k] = v
				any = true
			end
		end
		if not any then
			return nil
		end
		props = rest
	end
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Exits: fast, In easing, no overshoot.
function Fx.out(obj: Instance, props: { [string]: any }): Tween?
	return Fx.tween(obj, Fx.MOTION.exit, props, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- Idle loops, grouped per ScreenGui so they pause while it's hidden.
local loopsByGui: { [Instance]: { Tween } } = setmetatable({}, { __mode = "k" }) :: any

local function watch(gui: LayerCollector, tween: Tween)
	local list = loopsByGui[gui]
	if not list then
		list = {}
		loopsByGui[gui] = list
		if gui:IsA("ScreenGui") then
			gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				for _, t in loopsByGui[gui] or {} do
					if gui.Enabled and not Fx.reduced() then
						t:Play()
					else
						t:Pause()
					end
				end
			end)
		end
	end
	table.insert(list, tween)
end

-- A looping tween (Sine in/out, reversing by default) for glows, pulses and
-- spinners. Skipped under reduced motion when it moves things.
function Fx.loop(obj: Instance, time: number, props: { [string]: any }, reverses: boolean?): Tween?
	local moves = false
	for k in props do
		if MOVEMENT[k] then
			moves = true
		end
	end
	if moves and Fx.reduced() then
		return nil
	end
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(
			time,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			if reverses == nil then true else reverses
		),
		props
	)
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	if gui then
		watch(gui, tween)
		if not gui:IsA("ScreenGui") or gui.Enabled then
			tween:Play()
		end
	else
		tween:Play()
	end
	return tween
end

function Fx.scale(obj: GuiObject): UIScale
	local existing = obj:FindFirstChild("PopScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local s = Instance.new("UIScale")
	s.Name = "PopScale"
	s.Parent = obj
	return s
end

-- Pop: scale up a touch, then settle back with Back easing.
function Fx.pop(obj: GuiObject, amount: number?)
	if Fx.reduced() then
		return
	end
	local s = Fx.scale(obj)
	s.Scale = amount or 1.08
	Fx.tween(s, Fx.MOTION.settle, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- A soft light band that sweeps across `parent` once each time the returned
-- function is called. The band is unrotated (its gradient is angled) so the
-- clip frame really clips it.
function Fx.shine(parent: GuiObject, color: Color3?, strength: number?): () -> ()
	local clip = Instance.new("Frame")
	clip.Name = "Shine"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = 8
	clip.Parent = parent
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = color or C.white
	band.Size = UDim2.fromScale(0.6, 1)
	band.AnchorPoint = Vector2.new(0.5, 0)
	band.Position = UDim2.fromScale(-0.4, 0)
	band.ZIndex = 8
	band.Parent = clip
	local peak = 1 - (strength or 0.18)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, peak),
		NumberSequenceKeypoint.new(0.55, peak),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = band
	return function()
		if Fx.reduced() then
			return
		end
		band.Position = UDim2.fromScale(-0.4, 0)
		TweenService:Create(band, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			Position = UDim2.fromScale(1.4, 0),
		}):Play()
	end
end

-- The gamepad focus ring (LihFolk: Gamepad and Console UX): a 3 px gold
-- outline 4 px outside the button, its corner the button's own radius + 4
-- (nested-radius rule), so the ring is concentric with rounded buttons.
local rings: { [number]: Frame } = {}

local function ringFor(button: GuiObject): Frame
	local corner = button:FindFirstChildWhichIsA("UICorner")
	local radius = 0
	if corner then
		local r = corner.CornerRadius
		radius = if r.Scale >= 0.5 then 999 else r.Offset + 4
	end
	local ring = rings[radius]
	if ring then
		return ring
	end
	ring = Instance.new("Frame")
	ring.Name = "LobbySelectionRing"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 8, 1, 8)
	ring.Position = UDim2.fromOffset(-4, -4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.primary
	stroke.Thickness = 3
	stroke.Parent = ring
	if radius > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = if radius >= 999 then UDim.new(0.5, 0) else UDim.new(0, radius)
		c.Parent = ring
	end
	rings[radius] = ring
	return ring
end

-- Each button's resting position, so hover lifts and entrances share one base.
local bases: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any

function Fx.base(obj: GuiObject): UDim2
	return bases[obj] or obj.Position
end

export type ButtonOptions = {
	lift: GuiObject?, -- object whose Position lifts on hover (default: none)
	liftBy: number?, -- design px (default Fx.HOVER_LIFT)
	onHover: ((boolean) -> ())?,
	shine: (() -> ())?,
	silent: boolean?,
	enabled: (() -> boolean)?,
	noScale: boolean?, -- skip the 1.04 hover scale (big cards)
	onPress: ((down: boolean) -> ())?, -- e.g. sink a primary button's face
}

-- Hover / press / click feel for any GuiButton. `onClick` runs on Activated
-- (mouse, touch and gamepad). Full-size buttons are re-anchored at their centre
-- so the hover and press scale from the middle without moving the layout.
function Fx.button(button: GuiButton, onClick: () -> (), opts: ButtonOptions?)
	local o: ButtonOptions = opts or {}
	if
		button.AnchorPoint == Vector2.zero
		and button.Position == UDim2.new()
		and button.Size == UDim2.fromScale(1, 1)
	then
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromScale(0.5, 0.5)
	end
	button.SelectionImageObject = ringFor(button)
	local scale = Fx.scale(button)
	local liftBy = o.liftBy or Fx.HOVER_LIFT
	if o.lift then
		bases[o.lift] = o.lift.Position
	end
	local hovering = false
	local rest = 1

	local function setHover(on: boolean)
		if hovering == on then
			return
		end
		hovering = on
		rest = if on and not o.noScale then Fx.HOVER_SCALE else 1
		if on and not o.silent then
			Sound.play("Hover")
		end
		Fx.tween(scale, Fx.MOTION.hover, { Scale = rest }, Enum.EasingStyle.Quad)
		local lift = o.lift
		if lift then
			local base = Fx.base(lift)
			Fx.tween(lift, Fx.MOTION.hover, {
				Position = if on then base + UDim2.fromOffset(0, -liftBy) else base,
			}, Enum.EasingStyle.Quad)
		end
		if on and o.shine then
			o.shine()
		end
		if o.onHover then
			o.onHover(on)
		end
	end

	button.MouseEnter:Connect(function()
		setHover(true)
	end)
	button.MouseLeave:Connect(function()
		setHover(false)
	end)
	button.SelectionGained:Connect(function()
		setHover(true)
	end)
	button.SelectionLost:Connect(function()
		setHover(false)
	end)
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if
			t == Enum.UserInputType.MouseButton1
			or t == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			Fx.tween(scale, Fx.MOTION.press, { Scale = Fx.PRESS_SCALE }, Enum.EasingStyle.Quad)
			if o.onPress then
				o.onPress(true)
			end
		end
	end)
	button.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if
			o.onPress
			and (
				t == Enum.UserInputType.MouseButton1
				or t == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA
			)
		then
			o.onPress(false)
		end
	end)
	button.Activated:Connect(function()
		if o.enabled and not o.enabled() then
			Sound.play("Denied")
			Fx.shake(button)
			Fx.tween(scale, Fx.MOTION.settle, { Scale = rest }, Enum.EasingStyle.Back)
			return
		end
		if not o.silent then
			Sound.play("Select")
		end
		Fx.tween(scale, Fx.MOTION.settle, { Scale = rest }, Enum.EasingStyle.Back)
		onClick()
	end)
end

-- A short horizontal shake (denied / not allowed). Reduced motion: a red flash.
function Fx.shake(obj: GuiObject)
	if Fx.reduced() then
		local before = obj.BackgroundColor3
		obj.BackgroundColor3 = C.danger
		Fx.tween(obj, 0.3, { BackgroundColor3 = before })
		return
	end
	local base = obj.Position
	task.spawn(function()
		for _, dx in { 8, -7, 5, -3, 0 } do
			obj.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		obj.Position = base
	end)
end

-- A small rotating diamond, used for "searching". Reduced motion: it only pulses.
function Fx.spinner(parent: Instance, size: number, color: Color3, props: { [string]: any }?): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	for k, v in props or {} do
		(holder :: any)[k] = v
	end
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.5)
	outer.Size = UDim2.fromScale(0.7, 0.7)
	outer.BackgroundTransparency = 1
	outer.Rotation = 45
	outer.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = outer
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.32, 0.32)
	inner.BorderSizePixel = 0
	inner.BackgroundColor3 = color
	inner.Rotation = 45
	inner.Parent = holder
	holder.Parent = parent
	Fx.loop(outer, 1.1, { Rotation = 45 + 180 }, false)
	Fx.loop(inner, 0.55, { BackgroundTransparency = 0.6 })
	return holder
end

-- The subtle glitch accent: a cyan and a magenta copy of a label flick out to
-- either side for a few frames. Used on the hero buttons and MATCH FOUND only.
function Fx.glitch(label: TextLabel)
	local parent = label.Parent
	if not parent or Fx.reduced() then
		return
	end
	for i, color in { C.ally, C.glitch } do
		local ghost = label:Clone()
		for _, child in ghost:GetChildren() do
			child:Destroy()
		end
		ghost.Name = "Ghost"
		ghost.TextColor3 = color
		ghost.TextTransparency = 0.35
		ghost.ZIndex = math.max(1, label.ZIndex - 1)
		ghost.Parent = parent
		local dx = if i == 1 then -3 else 3
		ghost.Position = label.Position + UDim2.fromOffset(dx, 0)
		TweenService:Create(ghost, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
			Position = label.Position,
			TextTransparency = 1,
		}):Play()
		task.delay(0.2, function()
			ghost:Destroy()
		end)
	end
end

function Fx.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Fx
