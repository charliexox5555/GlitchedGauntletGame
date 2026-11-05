--!strict
-- Lobby UI motion kit (vault/02 Art/UI Design.md → Motion): hover lift, press
-- pop through UIScale (never Size), a light sweep, a breathing glow, a spinner
-- and a tiny chromatic "glitch" twitch for accents. Plain TweenService: a newer
-- tween on the same property replaces the older one, so calls can overlap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Sound = require(script.Parent.Sound)

local Fx = {}

local C = Theme.COLORS

function Fx.tween(
	obj: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- A looping tween (Sine in/out, reversing) for glows and pulses. Returns it so
-- the caller can :Cancel() it.
function Fx.loop(obj: Instance, time: number, props: { [string]: any }): Tween
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		props
	)
	tween:Play()
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
	local s = Fx.scale(obj)
	s.Scale = amount or 1.08
	Fx.tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
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
	band.BackgroundTransparency = 0
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
		band.Position = UDim2.fromScale(-0.4, 0)
		Fx.tween(band, 0.55, { Position = UDim2.fromScale(1.4, 0) }, Enum.EasingStyle.Quad)
	end
end

export type ButtonOptions = {
	lift: GuiObject?, -- object whose Position lifts on hover (default: none)
	liftBy: number?, -- design px (default 6)
	onHover: ((boolean) -> ())?,
	shine: (() -> ())?,
	silent: boolean?,
	enabled: (() -> boolean)?,
}

-- Hover / press / click feel for any GuiButton. `onClick` runs on Activated.
function Fx.button(button: GuiButton, onClick: () -> (), opts: ButtonOptions?)
	local o: ButtonOptions = opts or {}
	local scale = Fx.scale(button)
	local liftBy = o.liftBy or 6
	local basePos: UDim2? = if o.lift then o.lift.Position else nil
	local hovering = false

	local function setHover(on: boolean)
		if hovering == on then
			return
		end
		hovering = on
		if on and not o.silent then
			Sound.play("Hover")
		end
		if o.lift and basePos then
			local target = if on then basePos + UDim2.fromOffset(0, -liftBy) else basePos
			Fx.tween(o.lift, if on then 0.18 else 0.14, { Position = target })
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
		Fx.tween(scale, 0.14, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		setHover(true)
	end)
	button.SelectionLost:Connect(function()
		setHover(false)
	end)
	button.MouseButton1Down:Connect(function()
		Fx.tween(scale, 0.07, { Scale = 0.95 }, Enum.EasingStyle.Quad)
	end)
	button.Activated:Connect(function()
		if o.enabled and not o.enabled() then
			Sound.play("Denied")
			Fx.shake(button)
			Fx.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			return
		end
		if not o.silent then
			Sound.play("Select")
		end
		scale.Scale = 0.95
		Fx.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		onClick()
	end)
end

-- A short horizontal shake (denied / not allowed).
function Fx.shake(obj: GuiObject)
	local base = obj.Position
	task.spawn(function()
		for _, dx in { 8, -7, 5, -3, 0 } do
			obj.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		obj.Position = base
	end)
end

-- A small rotating diamond, used for "searching".
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
	TweenService:Create(
		outer,
		TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, -1),
		{ Rotation = 45 + 180 }
	):Play()
	Fx.loop(inner, 0.55, { BackgroundTransparency = 0.6 })
	holder.Parent = parent
	return holder
end

-- The subtle glitch accent: a cyan and a magenta copy of a label flick out to
-- either side for a few frames. Use sparingly (hover on the hero button,
-- "MATCH FOUND").
function Fx.glitch(label: TextLabel)
	local parent = label.Parent
	if not parent then
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
		Fx.tween(ghost, 0.16, {
			Position = label.Position,
			TextTransparency = 1,
		}, Enum.EasingStyle.Quad)
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
