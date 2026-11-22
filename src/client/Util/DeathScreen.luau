--!strict
-- The killed-by card (during the death camera) and the spectate bar (while
-- you watch someone), in the match UI style (vault/02 Art/UI Feed and
-- Spectate.md). The layout is built in Studio (StarterGui.DeathScreen, backup
-- tools/studio/BuildFeedScreens.luau); this fills and animates it.
-- SpectateController owns when each shows. Desktop only for now: phones keep
-- SpectateController's old bar.
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module (lobby + match)
local UiSound = require(script.Parent.UiSound)
local WaitGui = require(script.Parent.WaitGui)

local DeathScreen = {}

export type Fighter = {
	name: string,
	ally: boolean,
	image: string, -- headshot (rbxthumb) or the bot helmet
}

export type KilledBy = Fighter & {
	weapon: string, -- gun silhouette or Mod icon ("" hides it)
	isMod: boolean,
	gun: string, -- the gun's or Mod's name
	head: boolean,
	hp: number?, -- their HP left (nil hides it)
}

local DESIGN = Vector2.new(1920, 1080)
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local ALLY_CELL, ENEMY_CELL = Color3.fromHex("0D5C7A"), Color3.fromHex("8A1C24")
local SEGS = 10
local IN_TIME, OUT_TIME = 0.3, 0.2

type Card = {
	holder: Frame,
	pop: UIScale,
	strip: CanvasGroup,
	shadow: ImageLabel,
	shown: boolean,
	token: number,
}

type State = {
	gui: ScreenGui,
	killed: Card,
	spectate: Card,
	segs: { Frame },
	hpValue: TextLabel,
	shownHp: number,
}

local state: State? = nil
-- Your combat report against your killer (StatsService's CombatReport), shown
-- under the killed-by card until your next life.
local report: { dealt: number, taken: number }? = nil

local function showReport(s: State)
	local holder = s.killed.holder:FindFirstChild("Report")
	if not holder or not holder:IsA("Frame") then
		return
	end
	local r = report
	holder.Visible = r ~= nil
	local label = holder:FindFirstChild("Label")
	if r and label and label:IsA("TextLabel") then
		label.Text = string.format(
			'YOU DEALT <font color="#%s">%d</font>   ·   TOOK <font color="#%s">%d</font>',
			ALLY:ToHex(),
			r.dealt,
			ENEMY:ToHex(),
			r.taken
		)
	end
end
local cycle: ((step: number) -> ())? = nil -- set by SpectateController (may be before bind)
local overKeys = 0 -- the pointer is over a < > keycap (its click isn't also a Fire)

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

-- The shadow follows the strip, which sizes to its content.
local function fitShadow(c: Card)
	local scale = c.holder.AbsoluteSize.X / math.max(c.holder.Size.X.Offset, 1)
	if scale <= 0 then
		return
	end
	local size = c.strip.AbsoluteSize / scale
	c.shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	c.shadow.Position = UDim2.new(0.5, 0, 0.5, 8)
	c.shadow.Size = UDim2.fromOffset(size.X + 60, size.Y + 60)
end

local function card(holder: Frame, strip: CanvasGroup): Card
	local c: Card = {
		holder = holder,
		pop = child(holder, "Pop"),
		strip = strip,
		shadow = child(holder, "Shadow"),
		shown = false,
		token = 0,
	}
	strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitShadow(c)
	end)
	return c
end

-- In: rises a little from its centre and fades up. Out: fades and shrinks.
local function setShown(c: Card, on: boolean)
	if c.shown == on then
		return
	end
	c.shown = on
	c.token += 1
	local token = c.token
	if on then
		c.holder.Visible = true
		c.pop.Scale = 0.9
		c.strip.GroupTransparency = 1
		c.shadow.ImageTransparency = 1
		tween(c.pop, IN_TIME, { Scale = 1 })
		tween(c.strip, IN_TIME, { GroupTransparency = 0 })
		tween(c.shadow, IN_TIME, { ImageTransparency = 0.4 })
		task.defer(fitShadow, c)
	else
		tween(c.pop, OUT_TIME, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(
			c.strip,
			OUT_TIME,
			{ GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		tween(c.shadow, OUT_TIME, { ImageTransparency = 1 })
		task.delay(OUT_TIME, function()
			if token == c.token then
				c.holder.Visible = false
			end
		end)
	end
end

-- The cell + team block every card starts with.
local function fillFighter(strip: Instance, f: Fighter)
	local cell = child(strip, "Cell") :: Frame
	cell.BackgroundColor3 = if f.ally then ALLY_CELL else ENEMY_CELL
	local headshot = child(cell, "Headshot") :: ImageLabel
	headshot.Image = f.image
	local team = child(strip, "Team") :: Frame
	local color = if f.ally then ALLY else ENEMY
	team.BackgroundColor3 = color
	local cap = child(strip, "Cap") :: ImageLabel
	cap.ImageColor3 = color
	local label = child(team, "Label") :: TextLabel
	label.Text = string.upper(f.name)
end

local function bind(gui: ScreenGui)
	local canvas = child(gui, "Canvas") :: Frame
	local fit = child(canvas, "Fit") :: UIScale
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			fit.Scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.5, 1.5)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	local kb = child(canvas, "KilledBy") :: Frame
	local sp = child(canvas, "Spectate") :: Frame
	local row = child(sp, "Row") :: Frame
	local spStrip = child(row, "Strip") :: CanvasGroup
	local health = child(spStrip, "Health") :: Frame
	local bar = child(health, "Bar") :: Frame
	local segs: { Frame } = {}
	for i = 1, SEGS do
		segs[i] = child(bar, "Seg" .. i)
	end
	local s: State = {
		gui = gui,
		killed = card(kb, child(kb, "Strip")),
		spectate = card(sp, spStrip),
		segs = segs,
		hpValue = child(health, "Value"),
		shownHp = -1,
	}
	for name, step in { Prev = -1, Next = 1 } do
		local b = child(row, name) :: TextButton
		b.MouseEnter:Connect(function()
			overKeys += 1
		end)
		b.MouseLeave:Connect(function()
			overKeys = math.max(0, overKeys - 1)
		end)
		b.Activated:Connect(function()
			local fn = cycle
			if fn and s.spectate.shown then
				UiSound.play("Select")
				fn(step)
			end
		end)
	end
	kb.Visible = false
	sp.Visible = false
	state = s
end

function DeathScreen.start(isCompact: boolean)
	task.spawn(function()
		local gui = WaitGui("DeathScreen")
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		if isCompact then
			gui.Enabled = false -- phones keep the old bar for now
			return
		end
		bind(gui)
	end)
end

-- True while the pointer is over a < > keycap: SpectateController skips the
-- click's Fire / Aim press then, so one click cycles once.
function DeathScreen.overKeys(): boolean
	return overKeys > 0
end

function DeathScreen.active(): boolean
	return state ~= nil
end

-- The < > keycaps call this with -1 / +1.
function DeathScreen.onCycle(fn: (step: number) -> ())
	cycle = fn
end

function DeathScreen.killedBy(k: KilledBy)
	local s = state
	if not s then
		return
	end
	local strip = s.killed.strip
	fillFighter(strip, k)
	local weapon = child(strip, "Weapon") :: ImageLabel
	weapon.Image = k.weapon
	weapon.Visible = k.weapon ~= ""
	weapon.Size = if k.isMod then UDim2.fromOffset(44, 44) else UDim2.fromOffset(120, 44)
	local info = child(strip, "Info") :: Frame
	local gun = child(info, "Gun") :: TextLabel
	gun.Text = string.upper(k.gun)
	local head = child(info, "Head") :: TextLabel
	head.Visible = k.head
	local hp = child(strip, "HP") :: Frame
	hp.Visible = k.hp ~= nil
	local value = child(hp, "Value") :: TextLabel
	value.Text = tostring(math.max(0, math.ceil(k.hp or 0)))
	showReport(s)
	setShown(s.spectate, false)
	setShown(s.killed, true)
end

function DeathScreen.spectate(f: Fighter)
	local s = state
	if not s then
		return
	end
	fillFighter(s.spectate.strip, f)
	s.shownHp = -1
	setShown(s.killed, false)
	setShown(s.spectate, true)
	task.defer(fitShadow, s.spectate)
end

-- Their HP on the bar (only redrawn when it changes).
function DeathScreen.setHealth(hp: number, max: number)
	local s = state
	if not s then
		return
	end
	local value = math.max(0, math.ceil(hp))
	if value == s.shownHp then
		return
	end
	s.shownHp = value
	s.hpValue.Text = tostring(value)
	local lit = math.ceil(math.clamp(hp / math.max(max, 1), 0, 1) * SEGS)
	for i, seg in s.segs do
		seg.BackgroundTransparency = if i <= lit then 0 else 0.86
	end
end

-- The damage you dealt to your killer and took from them (this life).
function DeathScreen.setReport(dealt: number, taken: number)
	report = { dealt = math.max(0, math.floor(dealt)), taken = math.max(0, math.floor(taken)) }
	local s = state
	if s then
		showReport(s)
	end
end

function DeathScreen.hide()
	report = nil
	local s = state
	if s then
		setShown(s.killed, false)
		setShown(s.spectate, false)
	end
end

return DeathScreen
