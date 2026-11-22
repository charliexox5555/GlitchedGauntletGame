--!strict
-- The status tray (vault/02 Art/UI Match Extras.md): your active effects as
-- circles in a centred row just above the Mod cells, each an icon in a navy
-- disc with a 24-segment ring that drains as it runs out (no time text,
-- like Valorant). Debuffs ring red, buffs cyan. Above the row sits the Mod
-- hint (ModController.hint, fed by ModHudController). The layout is built in
-- Studio (StarterGui.StatusTray, entry template UiTemplates.Status.Entry,
-- backup tools/studio/BuildMatchExtras.luau). Desktop only for now.
--
-- Timed effects come from the character's server-time end attributes
-- (Config/StatusEffects: HinderedUntil, FrozenUntil, StimmedUntil,
-- StimStrongUntil; Mods/Molly: BurningUntil). The full length isn't sent, so
-- it's noted when an effect starts (or is extended). Revealed comes from the
-- ModFx event (`reveal`). Static entries (Barrier's hits, Crash Recovery's
-- state) have a full ring and are set by their owners (`setStatic`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiLayout = require(ReplicatedStorage.Shared.UiLayout)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Mods = require(ReplicatedStorage.Shared.Mods)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)
local WaitGui = require(script.Parent.WaitGui)

local StatusTray = {}

export type Static = {
	icon: string,
	label: string,
	buff: boolean,
	count: number?,
}

local player = Players.LocalPlayer

local DESIGN = Vector2.new(1920, 1080)
local SEGMENTS = 24
local ABOVE_MODS = 114 -- design px above the bottom HUD's Mod row anchor
local PHONE_BOOST = 1.6 -- touch: the row and hint this much bigger than height / 1080
local TABLET_BOOST = 1.15
local TOUCH_Y = 0.8 -- touch: the row's centre, as a share of the screen height
local ALLY, ENEMY = Color3.fromHex("3FE0F2"), Color3.fromHex("FF6B57")
local GOLD, WHITE = Color3.fromHex("FFC83D"), Color3.new(1, 1, 1)
local SPENT = 0.82 -- a drained segment's transparency

type Kind = {
	key: string,
	attr: string,
	mod: string,
	label: string,
	buff: boolean,
	order: number,
	sourceAttr: string?, -- a character attribute naming the Mod whose icon shows
}

-- Timed effects, in tray order (debuffs first).
local TIMED: { Kind } = {
	{
		key = "Frozen",
		attr = "FrozenUntil",
		mod = "Frost",
		label = "FROZEN",
		buff = false,
		order = 1,
	},
	{
		key = "Hindered",
		attr = "HinderedUntil",
		mod = "Frost",
		label = "HINDERED",
		buff = false,
		order = 2,
	},
	{
		key = "Blinded",
		attr = StatusEffects.blinded.attribute,
		mod = "Flash",
		label = StatusEffects.blinded.label,
		buff = false,
		order = 2,
	},
	{
		key = "Burning",
		attr = "BurningUntil",
		mod = "Molly",
		label = "BURNING",
		buff = false,
		order = 3,
	},
	{
		-- Heal Orb's heal over time or Stim's Heal Zone: the icon is the newest
		-- source's Mod (HealingSource), both written by the server.
		key = "Healing",
		attr = StatusEffects.healing.attribute,
		sourceAttr = StatusEffects.healing.sourceAttribute,
		mod = "HealOrb",
		label = StatusEffects.healing.label,
		buff = true,
		order = 5,
	},
	{
		key = "StimStrong",
		attr = "StimStrongUntil",
		mod = "Stim",
		label = "STRONG STIM",
		buff = true,
		order = 6,
	},
	{
		key = "Stimmed",
		attr = "StimmedUntil",
		mod = "Stim",
		label = "STIMMED",
		buff = true,
		order = 7,
	},
}

type Entry = {
	holder: Frame,
	pop: UIScale,
	segs: { ImageLabel },
	icon: ImageLabel,
	count: Frame,
	countLabel: TextLabel,
	tagLabel: TextLabel,
	leaving: boolean,
}

type State = {
	gui: ScreenGui,
	holder: Frame,
	fit: UIScale,
	row: Frame,
	hint: Frame,
	hintPlate: Frame,
	hintLabel: TextLabel,
	template: Frame,
	entries: { [string]: Entry },
	shownHint: string,
}

local state: State? = nil
local totals: { [string]: number } = {} -- key → full length (s), noted at start
local lastUntil: { [string]: number } = {}
local revealedUntil = 0
local revealedTotal = 0
local statics: { [string]: Static } = {}

local function tween(obj: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		goal
	):Play()
end

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function iconOf(modId: string): string
	local def = Mods.def(modId)
	return if def then def.icon else ""
end

-- A new circle pops in from its centre.
local function entry(s: State, key: string, order: number): Entry
	local e = s.entries[key]
	if e and not e.leaving then
		return e
	end
	if e then
		e.holder:Destroy()
	end
	local holder = s.template:Clone()
	holder.Name = key
	holder.LayoutOrder = order
	local body = child(holder, "Body") :: Frame
	local ring = child(body, "Ring") :: Frame
	local segs: { ImageLabel } = {}
	for i = 1, SEGMENTS do
		segs[i] = child(ring, "Seg" .. i)
	end
	local disc = child(body, "Disc") :: Frame
	local count = child(body, "Count") :: Frame
	local tag = child(holder, "Tag") :: Frame
	local made: Entry = {
		holder = holder,
		pop = child(body, "Pop"),
		segs = segs,
		icon = child(disc, "Icon"),
		count = count,
		countLabel = child(count, "Label"),
		tagLabel = child(tag, "Label"),
		leaving = false,
	}
	made.pop.Scale = 0.4
	holder.Parent = s.row
	tween(made.pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	s.entries[key] = made
	return made
end

local function drop(s: State, key: string)
	local e = s.entries[key]
	if not e or e.leaving then
		return
	end
	e.leaving = true
	tween(e.pop, 0.18, { Scale = 0 }, Enum.EasingStyle.Quad)
	task.delay(0.19, function()
		if s.entries[key] == e then
			s.entries[key] = nil
		end
		e.holder:Destroy()
	end)
end

-- Fills an entry: its look, and how much of the ring is left (0..1).
local function draw(
	e: Entry,
	icon: string,
	label: string,
	buff: boolean,
	left: number,
	count: number?
)
	e.icon.Image = icon
	e.tagLabel.Text = label
	local color = if buff then ALLY else ENEMY
	-- Smooth drain: whole segments lit, the one going out fades.
	local exact = math.clamp(left, 0, 1) * SEGMENTS
	local full = math.floor(exact)
	for i, seg in e.segs do
		seg.ImageColor3 = color
		if i <= full then
			seg.ImageTransparency = 0
		elseif i == full + 1 then
			seg.ImageTransparency = SPENT - (SPENT * (exact - full))
		else
			seg.ImageTransparency = SPENT
		end
	end
	e.count.Visible = count ~= nil
	if count then
		e.countLabel.Text = tostring(count)
	end
end

local function step()
	local s = state
	if not s then
		return
	end
	local character = player.Character
	local serverNow = Workspace:GetServerTimeNow()
	local active: { [string]: boolean } = {}
	for _, kind in TIMED do
		local untilAt = if character then StateValues.get(character, kind.attr) else nil
		local left = if typeof(untilAt) == "number" then untilAt - serverNow else 0
		if left > 0.05 then
			-- A new or extended effect: note its full length now.
			if (lastUntil[kind.key] or 0) < (untilAt :: number) - 0.05 then
				totals[kind.key] = math.max(left, 0.1)
			end
			lastUntil[kind.key] = untilAt :: number
			active[kind.key] = true
			local e = entry(s, kind.key, kind.order)
			local source = if kind.sourceAttr and character
				then StateValues.get(character, kind.sourceAttr)
				else nil
			local modId = if typeof(source) == "string" and Mods.def(source)
				then source
				else kind.mod
			draw(e, iconOf(modId), kind.label, kind.buff, left / (totals[kind.key] or left))
		else
			lastUntil[kind.key] = 0
		end
	end
	local revealLeft = revealedUntil - os.clock()
	if revealLeft > 0 then
		active.Revealed = true
		draw(
			entry(s, "Revealed", 4),
			iconOf("Recon"),
			StatusEffects.detected.label,
			false,
			revealLeft / math.max(revealedTotal, 0.1)
		)
	end
	-- Barrier: hits left on you (HealOrb's Barrier path).
	local hits = if character then StateValues.get(character, "BarrierHits") else nil
	if typeof(hits) == "number" and hits > 0 then
		active.Barrier = true
		draw(
			entry(s, "Barrier", 8),
			iconOf("HealOrb"),
			"BARRIER",
			true,
			1,
			if hits > 1 then hits else nil
		)
	end
	for key, info in statics do
		active[key] = true
		draw(entry(s, key, 9), info.icon, info.label, info.buff, 1, info.count)
	end
	local any = false
	for key, e in s.entries do
		if not active[key] then
			drop(s, key)
		elseif not e.leaving then
			any = true
		end
	end
	s.row.Visible = any or next(s.entries) ~= nil
end

local function bind(gui: ScreenGui)
	local holder = child(gui, "Holder") :: Frame
	local hint = child(holder, "Hint") :: Frame
	local plate = child(hint, "Plate") :: Frame
	local s: State = {
		gui = gui,
		holder = holder,
		fit = child(holder, "Fit"),
		row = child(holder, "Row"),
		hint = hint,
		hintPlate = plate,
		hintLabel = child(plate, "Label"),
		template = UiRoot.templates():WaitForChild("Status"):WaitForChild("Entry") :: Frame,
		entries = {},
		shownHint = "",
	}
	-- The row sizes to its entries, so it keeps its 1080p pixel design and one
	-- UIScale (vault/04 Tech/UI Architecture.md §5). Desktop: over the bottom
	-- HUD's Mod row, scaled like it (no 0.6 floor: that pushed UI off phones).
	-- Touch: bigger (PHONE_BOOST), above the bottom centre, between the stick
	-- and the fire cluster (owner 2026-11-22: no old hints on phones).
	local function refit()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local family = UiLayout.family()
		if family == "Phone" or family == "Tablet" then
			local scale = size.Y
				/ DESIGN.Y
				* (if family == "Phone" then PHONE_BOOST else TABLET_BOOST)
			s.fit.Scale = scale
			holder.Position = UDim2.fromScale(0.5, TOUCH_Y)
		else
			local scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.35, 1.5)
			s.fit.Scale = scale
			holder.Position = UDim2.new(0.5, 0, 0.965, -ABOVE_MODS * scale)
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	state = s
	RunService.RenderStepped:Connect(step)
end

function StatusTray.start(_isCompact: boolean?)
	task.spawn(function()
		local gui = WaitGui("StatusTray")
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		bind(gui)
	end)
end

function StatusTray.active(): boolean
	return state ~= nil
end

-- An enemy Recon dart revealed you for `duration` seconds.
function StatusTray.reveal(duration: number)
	if typeof(duration) == "number" and duration > 0 and duration == duration then
		-- A repeat scan while still detected refreshes the one entry (never a
		-- second one, never a shorter end).
		local untilAt = os.clock() + duration
		if untilAt >= revealedUntil then
			revealedTotal = duration
			revealedUntil = untilAt
		end
	end
end

-- A state with no timer (full ring), or nil to clear it.
function StatusTray.setStatic(key: string, info: Static?)
	statics[key] = info
end

-- The Mod hint over the tray ("" hides it); a warning reads gold and kicks.
function StatusTray.setHint(message: string, warning: boolean)
	local s = state
	if not s then
		return
	end
	local key = message .. (if warning then "!" else "")
	if key == s.shownHint then
		return
	end
	s.shownHint = key
	s.hint.Visible = message ~= ""
	s.hintLabel.Text = string.upper(message)
	s.hintLabel.TextColor3 = if warning then GOLD else WHITE
	if warning and message ~= "" then
		for i, dx in { -8, 6, -3, 0 } do
			task.delay((i - 1) * 0.04, function()
				s.hintPlate.Position = UDim2.new(0.5, dx, 0.5, 0)
			end)
		end
	end
end

return StatusTray
