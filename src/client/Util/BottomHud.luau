--!strict
-- The bottom combat HUD (vault/02 Art/UI Combat HUD Mockup.md): health +
-- shield (bottom-left), ammo (bottom-right) and the three Mod slots
-- (bottom-centre), plus the weapon hotbar (every loadout slot, the held one
-- lit) and key hints above the ammo. The layout is built in Studio (StarterGui.BottomHud, backup
-- tools/studio/BuildBottomHud.luau); this module only fills it in. It is fed by
-- the controllers that already own the data: HudController (health, shield,
-- weapon, ammo, reload, spectating) and ModHudController (each Mod slot).
-- Desktop only for now: on phones it stays hidden and the old panels show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Bindings = require(ReplicatedStorage.Shared.Config.Input)
local InputGlyphs = require(ReplicatedStorage.Shared.InputGlyphs)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module (lobby + match)
local WaitGui = require(script.Parent.WaitGui)

local TouchHud = require(script.Parent.TouchHud)

local BottomHud = {}

export type LoadoutEntry = {
	slot: string, -- "Primary" | "Secondary" | "Melee"
	id: string?,
	ammo: number,
	mag: number,
}

export type ModInfo = {
	id: string?,
	icon: string,
	role: string?,
	level: string,
	key: string,
	cooling: boolean,
	share: number, -- 0..1 of the cooldown still to go
	seconds: string,
	charges: number,
	max: number,
	held: boolean,
	denied: number, -- seconds since the last denied use
	active: number, -- 0..1 of an active effect left
}

local DESIGN = Vector2.new(1920, 1080)
local WHITE = Color3.new(1, 1, 1)
local TEXT = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("A3A3A6")
local RED = Color3.fromHex("FF4D5E")
local AMBER = Color3.fromHex("FFB547")
local CHIP = Color3.fromHex("FF9AA5") -- health just lost, before it drains
local SHIELD = Color3.fromHex("3FE0F2")
local CYAN = Color3.fromHex("2FD3E6")
local EMPTY_CELL = Color3.fromHex("262629") -- an undrafted Mod slot (navy plate)
local NAVY = Color3.fromHex("262629") -- the flat panel face
local HELD_CELL = Color3.fromHex("3C3C3F") -- the held hotbar slot: a brighter face, no outline
local LOW_FACE = Color3.fromHex("5A1622") -- the health panel pulses toward this when low
local FACE_Y = 40 -- a Mod cell's centre in its slot (the Face is anchored 0.5, 0.5)

local EMPTY_SEG = 0.86 -- transparency of an empty segment or spent round
local LOW_HEALTH = 0.35 -- share of max health that turns the panel red
local LOW_AMMO = 0.25
local CHIP_HOLD = 0.4 -- seconds the lost health holds before draining
local CHIP_DRAIN = 0.35
local HIT_SHAKE = 0.25
local MAX_TICKS = 30 -- bigger mags draw one fill bar instead of ticks
local ROUNDS_WIDTH = 200

type Ui = {
	gui: ScreenGui,
	health: Frame,
	hpNumber: Frame,
	hpIcon: ImageLabel,
	hpFace: { GuiObject },
	shieldChip: Frame,
	shieldNumber: Frame,
	hpSegs: { Frame },
	shieldSegs: { Frame },
	ammo: Frame,
	gun: ImageLabel,
	mag: Frame,
	size: TextLabel,
	gunName: TextLabel,
	rounds: Frame,
	reloadBar: Frame,
	reloadFill: Frame,
	mods: Frame,
	slots: { Slot },
	loadout: { [string]: LoadoutCell },
}
type LoadoutCell = {
	holder: Frame,
	pop: UIScale,
	cell: CanvasGroup,
	icon: ImageLabel,
	ammo: TextLabel,
	equipped: Frame,
	edge: UIStroke,
}
type Slot = {
	root: Frame,
	pop: UIScale,
	cell: CanvasGroup,
	icon: ImageLabel,
	iconShadow: ImageLabel,
	glint: Frame,
	cooldown: Frame,
	seconds: Frame,
	activeBar: Frame,
	pips: { Frame },
	level: TextLabel,
	edge: UIStroke,
	key: TextLabel,
	keyPlate: Frame,
	shown: string?,
	wasCooling: boolean,
	held: boolean,
}

local ui: Ui? = nil
local onActive: { () -> () } = {}

-- Last values, so a late bind (the gui arrives after the first updates) catches up.
local weaponName, weaponId = "", nil :: string?
local ammoNow, ammoMag = 0, 0
local ammoReserve: number? = nil
local reloadProgress: number? = nil
local spectating = false
local shownHealth = -1
local chipFrac = 1
local chipHoldUntil = 0
local hitAt = -math.huge
local tickCount = -1
local loadoutNow: { LoadoutEntry } = {}
local equippedNow: string? = nil
local shownEquipped: string? = nil

local tween = UiMotion.tween

local function setNumber(frame: Frame, text: string, color: Color3?)
	for _, part in { "Shadow", "Value" } do
		local label = frame:FindFirstChild(part)
		if label and label:IsA("TextLabel") then
			label.Text = text
			if part == "Value" and color then
				label.TextColor3 = color
			end
		end
	end
end

local function numbered(parent: Instance, prefix: string, count: number): { Frame }
	local list = {}
	for i = 1, count do
		list[i] = parent:WaitForChild(prefix .. i) :: Frame
	end
	return list
end

function BottomHud.active(): boolean
	return ui ~= nil
end

-- Runs fn once the Studio gui is bound (now, if it already is).
function BottomHud.onActive(fn: () -> ())
	if ui then
		fn()
	else
		table.insert(onActive, fn)
	end
end

-- Rebuild the round ticks for a mag size: one tick per round up to MAX_TICKS,
-- else a single fill bar.
local function buildTicks(r: Ui, mag: number)
	if mag == tickCount then
		return
	end
	tickCount = mag
	for _, child in r.rounds:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if mag <= 0 then
		return
	end
	local count = if mag <= MAX_TICKS then mag else 1
	local width = if count == 1
		then ROUNDS_WIDTH
		else math.clamp(math.floor((ROUNDS_WIDTH - (count - 1) * 2) / count), 3, 8)
	for i = 1, count do
		local tick = Instance.new("Frame")
		tick.Name = "R" .. i
		tick.LayoutOrder = i
		tick.Size = UDim2.fromOffset(width, 12)
		tick.BackgroundColor3 = TEXT
		tick.BorderSizePixel = 0
		tick.ZIndex = 2
		if count == 1 then
			-- big mags: a track with a fill
			tick.BackgroundTransparency = EMPTY_SEG
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = TEXT
			fill.BorderSizePixel = 0
			fill.ZIndex = 2
			fill.Parent = tick
		end
		tick.Parent = r.rounds
	end
end

local function drawAmmo()
	local r = ui
	if not r then
		return
	end
	local knife = ammoMag <= 0
	r.mag.Visible = not knife
	r.size.Visible = not knife
	r.rounds.Visible = not knife
	r.gun.Image = if weaponId then Theme.GUN[weaponId] or "" else ""
	local reloading = reloadProgress ~= nil
	r.reloadBar.Visible = reloading
	if reloadProgress then
		r.reloadFill.Size = UDim2.fromScale(math.clamp(reloadProgress, 0, 1), 1)
	end
	r.gunName.Text = if reloading
		then "RELOADING"
		elseif ammoNow == 0 and ammoReserve == 0 and not knife then "NO AMMO"
		else string.upper(weaponName)
	r.gunName.TextColor3 = if reloading then WHITE else MUTED
	if knife then
		return
	end
	local color = if ammoNow == 0 then RED elseif ammoNow <= ammoMag * LOW_AMMO then AMBER else WHITE
	setNumber(r.mag, tostring(ammoNow), color)
	r.size.Text = "/" .. (if ammoReserve == nil then "∞" else tostring(ammoReserve))
	r.size.TextColor3 = if ammoReserve == 0 then RED else MUTED
	buildTicks(r, ammoMag)
	local tickColor = if color == WHITE then TEXT else color
	if ammoMag <= MAX_TICKS then
		-- the left ticks empty first, so the full ones sit next to the number
		for _, tick in r.rounds:GetChildren() do
			if tick:IsA("Frame") then
				local spent = tick.LayoutOrder <= ammoMag - ammoNow
				tick.BackgroundColor3 = tickColor
				tick.BackgroundTransparency = if spent then EMPTY_SEG else 0
			end
		end
	else
		local track = r.rounds:FindFirstChild("R1")
		local fill = track and track:FindFirstChild("Fill")
		if track and track:IsA("Frame") and fill and fill:IsA("Frame") then
			track.BackgroundColor3 = tickColor
			fill.BackgroundColor3 = tickColor
			fill.Size = UDim2.fromScale(math.clamp(ammoNow / ammoMag, 0, 1), 1)
		end
	end
end

function BottomHud.setWeapon(displayName: string, id: string?)
	weaponName, weaponId = displayName, id
	drawAmmo()
end

function BottomHud.setAmmo(ammo: number, magSize: number, reserve: number?)
	ammoNow, ammoMag, ammoReserve = ammo, magSize, reserve
	drawAmmo()
	TouchHud.setAmmo(ammo, magSize, reserve) -- the touch screen's readout
end

function BottomHud.setReload(progress: number?)
	reloadProgress = progress
	drawAmmo()
end

function BottomHud.setSpectating(on: boolean)
	spectating = on
	local r = ui
	if r then
		-- Health stays: it shows the watched fighter's (HudController.setSubject).
		r.health.Visible = true
		r.ammo.Visible = true -- the watched fighter's gun and rounds (SpectateController)
		-- The Mod row shows the watched fighter's while you spectate
		-- (ModHudController draws theirs; setModsVisible shows or hides it).
		local row = r.gui:FindFirstChild("Root")
		for _, name in { "Loadout", "Hints" } do
			local part = row and row:FindFirstChild(name, true)
			if part and part:IsA("GuiObject") then
				part.Visible = not on
			end
		end
	end
end

-- Called every frame by HudController with the local character's state.
function BottomHud.setHealth(health: number, max: number, shield: number, dt: number)
	TouchHud.setHealth(health, max, shield) -- the touch screen's simple bar
	local r = ui
	if not r then
		return
	end
	local frac = if max > 0 then math.clamp(health / max, 0, 1) else 0
	local low = frac < LOW_HEALTH
	local now = os.clock()
	local whole = math.ceil(health)
	if whole ~= shownHealth then
		if shownHealth >= 0 and whole < shownHealth then
			chipHoldUntil = now + CHIP_HOLD
			hitAt = now
		end
		shownHealth = whole
		setNumber(r.hpNumber, tostring(whole))
	end
	if frac >= chipFrac then
		chipFrac = frac -- healed or respawned: nothing to drain
	elseif now >= chipHoldUntil then
		chipFrac = math.max(frac, chipFrac - dt / CHIP_DRAIN)
	end

	-- a hit flashes the number red and shakes the panel
	local sinceHit = now - hitAt
	local flash = math.clamp(1 - sinceHit / 0.4, 0, 1)
	local base = if low then RED else WHITE
	local value = r.hpNumber:FindFirstChild("Value")
	if value and value:IsA("TextLabel") then
		value.TextColor3 = base:Lerp(RED, flash)
	end
	r.hpIcon.ImageColor3 = if low then RED else WHITE
	-- low health: the panel's face pulses toward a dark red
	local face = if low then NAVY:Lerp(LOW_FACE, 0.5 + 0.5 * math.sin(now * 6)) else NAVY
	for _, part in r.hpFace do
		if part:IsA("ImageLabel") then
			part.ImageColor3 = face
		elseif part:IsA("Frame") then
			part.BackgroundColor3 = face
		end
	end
	local shake = if sinceHit < HIT_SHAKE
		then math.sin(sinceHit * 70) * 5 * (1 - sinceHit / HIT_SHAKE)
		else 0
	local body = r.health:FindFirstChild("Body")
	if body and body:IsA("Frame") then
		body.Position = UDim2.fromOffset(shake, 0)
	end

	-- 10 health segments (each a tenth of max): full, partial, just lost (chip), empty
	local n = #r.hpSegs
	for i, seg in r.hpSegs do
		local fill = math.clamp(frac * n - (i - 1), 0, 1)
		local chipFill = math.clamp(chipFrac * n - (i - 1), 0, 1)
		if fill > 0 then
			seg.BackgroundColor3 = if low then RED else TEXT
			seg.BackgroundTransparency = EMPTY_SEG * (1 - fill)
		elseif chipFill > 0 then
			seg.BackgroundColor3 = CHIP
			seg.BackgroundTransparency = 0.15
		else
			seg.BackgroundColor3 = if low then RED else TEXT
			seg.BackgroundTransparency = EMPTY_SEG
		end
	end

	-- shield: the chip shows the value; 5 segments, each a fifth of MAX_SHIELD
	local hasShield = shield > 0
	r.shieldChip.Visible = hasShield
	if hasShield then
		setNumber(r.shieldNumber, tostring(math.ceil(shield)))
	end
	local per = Combat.MAX_SHIELD / #r.shieldSegs
	for i, seg in r.shieldSegs do
		local fill = math.clamp(shield / per - (i - 1), 0, 1)
		seg.BackgroundColor3 = SHIELD
		seg.BackgroundTransparency = if fill > 0 then EMPTY_SEG * (1 - fill) else 0.92
	end
end

-- Every loadout slot (from WeaponController): the held one is lit and
-- underlined, the others dim with their ammo; a swap pops the new one.
local function drawLoadout()
	local r = ui
	if not r then
		return
	end
	local present: { [string]: LoadoutEntry } = {}
	for _, e in loadoutNow do
		present[e.slot] = e
	end
	for name, c in r.loadout do
		local e = present[name]
		c.holder.Visible = e ~= nil
		if e then
			c.icon.Image = if e.id then Theme.GUN[e.id] or "" else ""
			c.ammo.Text = if e.mag > 0 then tostring(e.ammo) else ""
			c.ammo.TextColor3 = if e.mag > 0 and e.ammo == 0 then RED else WHITE
			local held = name == equippedNow
			c.cell.GroupTransparency = if held then 0 else 0.3
			c.cell.BackgroundColor3 = if held then HELD_CELL else NAVY
			c.equipped.Visible = held
		end
	end
	if equippedNow ~= shownEquipped then
		shownEquipped = equippedNow
		local c = if equippedNow then r.loadout[equippedNow] else nil
		if c then
			c.pop.Scale = 1.12
			tween(c.pop, 0.3, { Scale = 1 })
		end
	end
end

function BottomHud.setLoadout(entries: { LoadoutEntry }, equipped: string?)
	loadoutNow = entries
	equippedNow = equipped
	drawLoadout()
	TouchHud.setLoadout(entries, equipped) -- the touch screen's weapon slots
end

-- Called every frame by ModHudController; spectating keeps the row hidden.
function BottomHud.setModsVisible(any: boolean)
	local r = ui
	if r then
		r.mods.Visible = any -- yours, or the watched fighter's (ModHudController)
	end
end

function BottomHud.isSpectating(): boolean
	return spectating
end

-- A shine sweeps across a Mod cell (ready again, or newly drafted).
local function glint(s: Slot)
	s.glint.Position = UDim2.fromScale(-0.6, 0.5)
	tween(s.glint, 0.55, { Position = UDim2.fromScale(1.6, 0.5) }, Enum.EasingStyle.Quad)
end

-- Called every frame per slot by ModHudController.
function BottomHud.setMod(index: number, info: ModInfo)
	local r = ui
	local s = r and r.slots[index]
	if not s then
		return
	end
	local role = if info.role then Theme.ROLE[info.role] else nil
	local color = role or CYAN
	-- only drafted Mods show; the row centres itself on them (like Valorant)
	s.root.Visible = info.id ~= nil
	local shown = if info.id then info.id .. ":" .. info.level else nil
	if shown ~= s.shown then
		s.shown = shown
		s.icon.Image = info.icon
		s.icon.Visible = info.id ~= nil
		s.iconShadow.Image = info.icon
		s.iconShadow.Visible = info.id ~= nil
		-- a drafted Mod is a bright block in its role colour; an empty slot a dim plate
		s.cell.BackgroundColor3 = if info.id then color else EMPTY_CELL
		s.level.Text = if info.level == "L1" or info.id == nil then "" else info.level
		s.cell.GroupTransparency = if info.id then 0 else 0.55
		if info.id then
			-- a new Mod pops in with a shine
			s.pop.Scale = 0.7
			tween(s.pop, 0.36, { Scale = 1 })
			glint(s)
		end
	end
	s.key.Text = info.key

	-- cooling: a dark curtain over the colour lifts as it recharges
	s.icon.ImageTransparency = if info.cooling then 0.35 else 0
	s.iconShadow.ImageTransparency = if info.cooling then 0.85 else 0.65
	s.cooldown.Size = UDim2.fromScale(
		1,
		if info.cooling then math.clamp(if info.share > 0 then info.share else 1, 0, 1) else 0
	)
	setNumber(s.seconds, info.seconds)
	if s.wasCooling and not info.cooling and info.id ~= nil then
		-- ready again: a pop and a shine
		s.pop.Scale = 1.14
		tween(s.pop, 0.36, { Scale = 1 })
		glint(s)
	end
	s.wasCooling = info.cooling

	for i, pip in s.pips do
		pip.Visible = info.max > 1 and i <= info.max
		pip.BackgroundTransparency = if i <= info.charges then 0 else 0.75
	end
	s.activeBar.Size = UDim2.new(math.clamp(info.active, 0, 1), 0, 0, 3)
	s.activeBar.BackgroundColor3 = WHITE

	-- held: a white edge and a lift; denied: a red edge and a shake
	if info.held ~= s.held then
		s.held = info.held
		if not (s.pop.Scale > 1.05) then
			tween(s.pop, 0.12, { Scale = if info.held then 1.06 else 1 })
		end
	end
	-- the Face is centred in its slot (it pops from the middle); the shake
	-- offsets it from that home
	local face = s.cell.Parent :: Frame
	local shake = if info.denied < 0.35
		then math.sin(info.denied * 60) * 4 * (1 - info.denied / 0.35)
		else 0
	face.Position = UDim2.new(0.5, shake, 0, FACE_Y)
	if info.denied < 0.35 then
		s.edge.Color = RED
		s.edge.Transparency = 0
	else
		s.edge.Color = WHITE
		s.edge.Transparency = if info.held then 0.1 else 1
	end
end

local function bind(gui: ScreenGui)
	local root = gui:WaitForChild("Root") :: Frame
	local health = root:WaitForChild("Health") :: Frame
	local hpBody = health:WaitForChild("Body") :: Frame
	local segs = hpBody:WaitForChild("Segments") :: Frame
	local chip = hpBody:WaitForChild("ShieldChip") :: Frame
	-- The right side is one column (hotbar, ammo, key hints) in a vertical list
	-- with one UIScale, so they stack and can't overlap at any screen size.
	local right = root:WaitForChild("Right") :: Frame
	local ammo = right:WaitForChild("Ammo") :: Frame
	local amBody = ammo:WaitForChild("Body") :: Frame
	local rounds = amBody:WaitForChild("Rounds") :: Frame
	local reloadBar = amBody:WaitForChild("ReloadBar") :: Frame
	local mods = root:WaitForChild("Mods") :: Frame
	local loadoutRow = right:WaitForChild("Loadout") :: Frame
	local hints = right:WaitForChild("Hints") :: Frame
	-- The hint keycaps show the real bindings (Config/Input) for the input in
	-- use: a key name, a gamepad glyph, or nothing (Shared/InputGlyphs).
	for _, pair in hints:GetChildren() do
		local key = pair:FindFirstChild("Key")
		if key and key:IsA("GuiObject") and (Bindings :: any)[pair.Name] then
			if key:GetAttribute("KeyAction") == nil then
				key:SetAttribute("KeyAction", pair.Name)
			end
			InputGlyphs.apply(key)
		end
	end
	local loadout: { [string]: LoadoutCell } = {}
	for _, name in { "Primary", "Secondary", "Melee" } do
		local holder = loadoutRow:WaitForChild(name) :: Frame
		local cell = holder:WaitForChild("Cell") :: CanvasGroup
		loadout[name] = {
			holder = holder,
			pop = cell:WaitForChild("Pop") :: UIScale,
			cell = cell,
			icon = cell:WaitForChild("Icon") :: ImageLabel,
			ammo = cell:WaitForChild("Ammo") :: TextLabel,
			equipped = cell:WaitForChild("Equipped") :: Frame,
			edge = cell:WaitForChild("Edge") :: UIStroke,
		}
	end
	local slots: { Slot } = {}
	for i = 1, 3 do
		local slot = mods:WaitForChild("Slot" .. i) :: Frame
		local face = slot:WaitForChild("Face") :: Frame
		local cell = face:WaitForChild("Cell") :: CanvasGroup
		local key = slot:WaitForChild("Key") :: Frame
		slots[i] = {
			root = slot,
			pop = face:WaitForChild("Pop") :: UIScale,
			cell = cell,
			icon = cell:WaitForChild("Icon") :: ImageLabel,
			iconShadow = cell:WaitForChild("IconShadow") :: ImageLabel,
			glint = cell:WaitForChild("Glint") :: Frame,
			cooldown = cell:WaitForChild("Cooldown") :: Frame,
			seconds = cell:WaitForChild("Seconds") :: Frame,
			activeBar = cell:WaitForChild("ActiveBar") :: Frame,
			pips = numbered(cell:WaitForChild("Charges"), "Pip", 3),
			level = cell:WaitForChild("Level") :: TextLabel,
			edge = cell:WaitForChild("Edge") :: UIStroke,
			key = (key:WaitForChild("Face") :: Frame):WaitForChild("Label") :: TextLabel,
			keyPlate = key,
			shown = "?",
			wasCooling = false,
			held = false,
		}
	end
	-- the Studio preview may leave a shine mid-sweep: park every glint
	for _, slot in slots do
		slot.glint.Position = UDim2.fromScale(-0.6, 0.5)
	end
	-- the Studio preview rounds only show the layout in Edit mode
	for _, child in rounds:GetChildren() do
		if StateValues.get(child, "Preview") then
			child:Destroy()
		end
	end
	local r: Ui = {
		gui = gui,
		health = health,
		hpNumber = hpBody:WaitForChild("HP") :: Frame,
		hpIcon = hpBody:WaitForChild("Icon") :: ImageLabel,
		hpFace = { hpBody, health:WaitForChild("Slant") :: GuiObject },
		shieldChip = chip,
		shieldNumber = chip:WaitForChild("Value") :: Frame,
		hpSegs = numbered(segs, "Hp", 10),
		shieldSegs = numbered(segs, "Shield", 5),
		ammo = ammo,
		gun = amBody:WaitForChild("Gun") :: ImageLabel,
		mag = amBody:WaitForChild("Mag") :: Frame,
		size = amBody:WaitForChild("MagSize") :: TextLabel,
		gunName = amBody:WaitForChild("GunName") :: TextLabel,
		rounds = rounds,
		reloadBar = reloadBar,
		reloadFill = reloadBar:WaitForChild("Fill") :: Frame,
		mods = mods,
		slots = slots,
		loadout = loadout,
	}

	-- One UIScale per cluster keeps the 1920 x 1080 layout proportional.
	local fits = {
		health:WaitForChild("Fit"),
		mods:WaitForChild("Fit"),
		right:WaitForChild("Fit"),
	}
	local function refit()
		local size = gui.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			local scale = math.clamp(math.min(size.X / DESIGN.X, size.Y / DESIGN.Y), 0.6, 1.5)
			for _, f in fits do
				(f :: UIScale).Scale = scale
			end
		end
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	ui = r
	tickCount = -1
	drawAmmo()
	drawLoadout()
	BottomHud.setSpectating(spectating)
	for _, fn in onActive do
		task.spawn(fn)
	end
	table.clear(onActive)
end

-- Bind once the StarterGui copy reaches PlayerGui (never blocks the caller).
function BottomHud.start()
	task.spawn(function()
		local gui = WaitGui("BottomHud")
		if not gui or not gui:IsA("ScreenGui") then
			return
		end
		if TouchHud.enabled() then
			-- Touch: the touch screen has its own health bar, weapon slots,
			-- ammo readout and Mod buttons (Util/TouchHud).
			gui.Enabled = false
			return
		end
		bind(gui)
	end)
end

return BottomHud
