--!strict
-- The one UI motion module (lobby and match; vault/02 Art/UI Lobby
-- Overhaul.md → System). Numbers are Config/UiStyle.KIT.motion: RIVALS'
-- beats (hover 1.125, press 0.875, 0.25 s, pages from 0.75) with our easing,
-- Quint Out and no overshoot (owner rule, memory "UI motion clean").
-- Pops are UIScales; a scaled thing must grow from its centre (Util/Pivot).
-- Reduced motion (Roblox's setting or our Settings toggle): moves, scales and
-- shakes jump to their end; fades and colours still ease.
--
--   tween(obj, time, goal, style?, dir?)  Quint Out by default
--   rest(pop, scale)                      ease a pop to a resting scale (hover)
--   press(pop, card?)                     dip from its rest and ease back
--   nudge(obj, home)                      a short shake (locked / SOON things)
--   slideIn(obj, dx, dy, delay)           from an offset to its saved home
--   popIn(pop, delay, from?)              grow in from `from` (default 0.8)
--   pageIn(fit)                           a page opens from 0.75 of its fit
--   button(btn, pop, onClick, opts?)      hover / press / gamepad / click

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local UiStyle = require(script.Parent.Config.UiStyle)

local M = UiStyle.KIT.motion
local QUINT, OUT, IN = Enum.EasingStyle.Quint, Enum.EasingDirection.Out, Enum.EasingDirection.In

local UiMotion = {}
UiMotion.M = M

local override: boolean? = nil

function UiMotion.reduced(): boolean
	if override ~= nil then
		return override
	end
	return GuiService.ReducedMotionEnabled
end

function UiMotion.setReduced(on: boolean?)
	override = on
end

-- properties that are motion (jump under reduced motion); the rest ease
local MOVES = { Position = true, Size = true, Rotation = true, Scale = true, CFrame = true }

function UiMotion.tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	if UiMotion.reduced() then
		local eased: { [string]: any } = {}
		for k, v in goal do
			if MOVES[k] then
				(obj :: any)[k] = v
			else
				eased[k] = v
			end
		end
		goal = eased
	end
	local t = TweenService:Create(obj, TweenInfo.new(time, style or QUINT, dir or OUT), goal)
	t:Play()
	return t
end

-- an exit: Quint In, quick
function UiMotion.out(obj: Instance, goal: { [string]: any }, time: number?): Tween
	return UiMotion.tween(obj, time or M.quick, goal, QUINT, IN)
end

function UiMotion.rest(pop: UIScale, scale: number)
	pop:SetAttribute("Rest", scale)
	UiMotion.tween(pop, M.beat, { Scale = scale })
end

function UiMotion.press(pop: UIScale, card: boolean?)
	local r = pop:GetAttribute("Rest")
	local home = if typeof(r) == "number" then r else 1
	-- unsaid: a button hovered to 1.125 dips like a button, anything else
	-- (cards, tiles, an unhovered touch) dips gently
	local isCard = if card ~= nil then card else home < (M.hover + M.hoverCard) / 2
	local dip =
		UiMotion.tween(pop, 0.07, { Scale = home * (if isCard then M.pressCard else M.press) })
	dip.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			UiMotion.tween(pop, M.beat, { Scale = home })
		end
	end)
end

function UiMotion.nudge(obj: GuiObject, home: UDim2)
	if UiMotion.reduced() then
		return
	end
	task.spawn(function()
		for _, dx in M.nudge do
			UiMotion.tween(
				obj,
				0.05,
				{ Position = home + UDim2.fromOffset(dx, 0) },
				Enum.EasingStyle.Quad
			).Completed
				:Wait()
		end
	end)
end

-- The object's resting position, saved the first time it slides.
function UiMotion.home(obj: GuiObject): UDim2
	local h = obj:GetAttribute("Home")
	if typeof(h) == "UDim2" then
		return h
	end
	obj:SetAttribute("Home", obj.Position)
	return obj.Position
end

function UiMotion.slideIn(obj: GuiObject?, dx: number, dy: number, delay: number?, time: number?)
	if not obj then
		return
	end
	local home = UiMotion.home(obj)
	obj.Position = home + UDim2.fromOffset(dx, dy)
	local function go()
		UiMotion.tween(obj, time or M.long, { Position = home })
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

function UiMotion.popIn(pop: UIScale, delay: number?, from: number?)
	pop.Scale = from or 0.8
	local function go()
		local r = pop:GetAttribute("Rest")
		UiMotion.tween(pop, M.beat + 0.07, { Scale = if typeof(r) == "number" then r else 1 })
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

-- A page opens from 0.75 of its fitted size (its canvas is centre-anchored,
-- so it grows from the middle). `fit` is the page's one Fit UIScale; `target`
-- is the fitted scale it should end at.
function UiMotion.pageIn(fit: UIScale, target: number)
	fit.Scale = if UiMotion.reduced() then target else target * M.pageFrom
	UiMotion.tween(fit, M.beat + 0.05, { Scale = target })
end

export type ButtonOptions = {
	card: boolean?, -- big cards / tiles: a small hover (1.04) instead of 1.125
	hover: number?, -- a custom hover scale
	enabled: (() -> boolean)?,
	onHover: ((boolean) -> ())?,
}

-- Hover / press / gamepad selection / click for a Studio-built button whose
-- pop is `pop` (a UIScale that grows from its centre: Util/Pivot).
function UiMotion.button(
	btn: GuiButton,
	pop: UIScale,
	onClick: () -> (),
	opts: ButtonOptions?
): { RBXScriptConnection }
	local o: ButtonOptions = opts or {}
	local up = o.hover or (if o.card then M.hoverCard else M.hover)
	local over = false
	local function hover(on: boolean)
		if over == on then
			return
		end
		over = on
		local live = o.enabled == nil or o.enabled()
		UiMotion.rest(pop, if on and live then up else 1)
		if o.onHover then
			o.onHover(on)
		end
	end
	return {
		btn.MouseEnter:Connect(function()
			hover(true)
		end),
		btn.MouseLeave:Connect(function()
			hover(false)
		end),
		btn.SelectionGained:Connect(function()
			hover(true)
		end),
		btn.SelectionLost:Connect(function()
			hover(false)
		end),
		btn.Activated:Connect(function()
			if o.enabled == nil or o.enabled() then
				UiMotion.press(pop, o.card)
			end
			onClick()
		end),
	}
end

return UiMotion
