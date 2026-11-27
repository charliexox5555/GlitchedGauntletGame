--!strict
-- The draft: 3 guns on top, then one column per key (Q / E / T) like Gauntlet:
-- Glitched (vault/01 Design/Match Flow.md). An empty slot's column shows a new
-- ability for it; a filled slot's column shows that ability's upgrade cards
-- (Path A or B, or a glitch card), or MAXED.
-- The server dealt these cards and checks every pick; this only shows them and
-- asks. The screen itself is the Studio-built DraftScreen (Util/DraftScreen,
-- every device); this owns the offer, keys, remote calls and the hint text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local CoreUi = require(ReplicatedStorage.Shared.CoreUi)
local InputGlyphs = require(ReplicatedStorage.Shared.InputGlyphs)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local Device = require(script.Parent.Parent.Util.Device)
local DraftScreen = require(script.Parent.Parent.Util.DraftScreen)
local Ui = require(script.Parent.Parent.Util.Ui)
local UiSound = require(script.Parent.Parent.Util.UiSound)

local DraftController = {}

local player = Players.LocalPlayer
local C = Theme.COLORS

local URGENT = 5 -- seconds left when the hint names your default pick
local GUN_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local SLOT_KEYS = { [Enum.KeyCode.Q] = 1, [Enum.KeyCode.E] = 2, [Enum.KeyCode.T] = 3 }
local PAD_STEPS: { [Enum.KeyCode]: { guns: boolean, by: number } } = {
	[Enum.KeyCode.ButtonL1] = { guns = false, by = -1 },
	[Enum.KeyCode.ButtonR1] = { guns = false, by = 1 },
	[Enum.KeyCode.DPadLeft] = { guns = true, by = -1 },
	[Enum.KeyCode.DPadRight] = { guns = true, by = 1 },
}

-- Upgrade numbers worth showing on a card ("PEAK  14 → 21 STUDS"), in order.
local STATS: { { key: string, label: string, unit: string } } = {
	{ key = "charges", label = "CHARGES", unit = "" },
	{ key = "damage", label = "DAMAGE", unit = "" },
	{ key = "slamDamage", label = "SLAM DMG", unit = "" },
	{ key = "heal", label = "HEAL", unit = " HP" },
	{ key = "hinder", label = "HINDER", unit = " S" },
	{ key = "reveal", label = "REVEAL", unit = " S" },
	{ key = "peak", label = "PEAK", unit = " STUDS" },
	{ key = "distance", label = "DISTANCE", unit = " STUDS" },
	{ key = "maxLength", label = "LENGTH", unit = " STUDS" },
	{ key = "range", label = "RANGE", unit = " STUDS" },
	{ key = "radius", label = "RADIUS", unit = " STUDS" },
	{ key = "pulses", label = "PULSES", unit = "" },
	{ key = "freeze", label = "FREEZE", unit = " S" },
	{ key = "duration", label = "DURATION", unit = " S" },
	{ key = "life", label = "ROLL TIME", unit = " S" },
	{ key = "maxActive", label = "MAX ACTIVE", unit = "" },
	{ key = "cooldown", label = "COOLDOWN", unit = " S" },
}

-- A pickable gun or card on the screen (the keys and gamepad use these).
type Card = {
	id: string,
	slot: number, -- 0 for guns
	button: GuiObject?, -- its hit area on the screen (gamepad selection)
	pick: () -> (),
}

-- The touch arrangement (Util/Device.compact): the hint says "tap" and leads
-- with the clock. Read once at start.
local compact = false
local lockHint: TextLabel? = nil
local gunCards: { Card } = {}
local abilityCards: { Card } = {}
local offer: MatchState.DraftOffer? = nil
local selectedGun: string? = nil
local selectedAbility: string? = nil
local isOpen = false
local locked = false
local shownHint = ""

local function setOpen(value: boolean)
	if isOpen == value then
		return
	end
	isOpen = value
	CameraController.setCursorVisible(value)
	-- Gamepad: selection starts on the picked power card (LihFolk: Gamepad and Console UX); LB / RB and the
	-- D-pad step the picks, A picks the selected card, X locks in.
	if UserInputService.GamepadEnabled then
		task.defer(function()
			local first = abilityCards[1] or gunCards[1]
			GuiService.SelectedObject = if value and first then first.button else nil
		end)
	end
	-- Roblox's chat steps aside while the draft fills the screen (it sits at
	-- the left middle in a match, over the first column on smaller screens).
	CoreUi.menuMode(value)
	UiSound.play(if value then "Open" else "Close")
	DraftScreen.setOpen(value)
end

local function nothingToPick(o: MatchState.DraftOffer): boolean
	return #o.abilities == 0 and #(o.upgrades or {}) == 0
end

local function canLock(): boolean
	local o = offer
	if not o then
		return false
	end
	-- the gun loadout (Locker) replaced the gun row: an offer with no guns needs only the card
	return (selectedGun ~= nil or #o.guns == 0) and (selectedAbility ~= nil or nothingToPick(o))
end

-- A card's text: the level's note, without its "Path name: " lead on an
-- upgrade card (the card's title already names the path).
local function cardNote(id: string, level: string): string
	local stats = Mods.stats(id, level)
	local note: string = if stats then stats.note or "" else ""
	local def = Mods.def(id)
	local pathName = if def then (def.paths :: any)[string.sub(level, 1, 1)] else nil
	if pathName and string.sub(note, 1, #pathName + 1) == pathName .. ":" then
		local rest = string.gsub(string.sub(note, #pathName + 2), "^%s+", "")
		return string.upper(string.sub(rest, 1, 1)) .. string.sub(rest, 2)
	end
	return note
end

local function levelNumber(level: string): number
	if level == "" then
		return 0
	end
	return tonumber(string.sub(level, 2, 2)) or 1
end

local function number(v: number): string
	return if v == math.floor(v) then tostring(v) else string.format("%.1f", v)
end

-- Notes describe behavior and trade-offs. The stat row calls out up to two
-- measured changes, derived from the actual previous level.
local function statLine(id: string, from: string, to: string): string
	local def = Mods.def(id)
	local levelDef = def and def.levels[to]
	if levelDef and typeof((levelDef :: any).card) == "string" and (levelDef :: any).card ~= "" then
		return (levelDef :: any).card :: string
	end
	local a, b = Mods.stats(id, from), Mods.stats(id, to)
	if not a or not b then
		return ""
	end
	local lines: { string } = {}
	for _, s in STATS do
		local old, new = (a :: any)[s.key], (b :: any)[s.key]
		if typeof(new) ~= "number" or new == old then
			continue
		end
		if s.key == "cooldown" and (typeof(old) ~= "number" or old == 0) and new > 0 then
			table.insert(lines, string.format("RECHARGE %s S", number(new)))
		elseif typeof(old) == "number" then
			table.insert(
				lines,
				string.format("%s %s → %s%s", s.label, number(old), number(new), s.unit)
			)
		end
		if #lines == 2 then
			break
		end
	end
	return table.concat(lines, " · ")
end

local function chargesText(id: string): string
	local stats = Mods.stats(id, "L1")
	if not stats then
		return ""
	end
	local charges = (stats :: any).charges or 1
	local cooldown = (stats :: any).cooldown or 0
	if cooldown > 0 then
		return string.format(
			"%d CHARGE%s  ·  %s S COOLDOWN",
			charges,
			if charges == 1 then "" else "S",
			number(cooldown)
		)
	end
	return string.format("%d PER ROUND", charges)
end

-- A card's short name for the hint ("Recon", "Stim · Quick Stims").
local function cardName(key: string): string
	local id, level = string.match(key, "^(%w+):(%w+)$")
	local def = Mods.def(id or key)
	if not def then
		return key
	end
	local pathName = if level then (def.paths :: any)[string.sub(level, 1, 1)] else nil
	return if pathName then def.name .. " · " .. pathName else def.name
end

local function hintText(): (string, Color3)
	local o = offer
	if not o then
		return "", C.textSecondary
	end
	if locked then
		return "Locked in. Waiting for the other players.", C.ready
	end
	local touch = compact
	-- a controller gets its own buttons (owner 2026-11-26: it said keyboard keys on a controller)
	local pad = not touch and InputGlyphs.mode() == "Gamepad"
	local withGuns = #gunCards > 0
	if pad then
		local bumpers = InputGlyphs.padName(Enum.KeyCode.ButtonL1)
			.. " / "
			.. InputGlyphs.padName(Enum.KeyCode.ButtonR1)
		local lockKey = InputGlyphs.padName(Enum.KeyCode.ButtonX)
		if canLock() then
			return if withGuns
				then `{bumpers}: power  ·  D-Pad: gun  ·  {lockKey}: LOCK IN`
				else `{bumpers}: change power  ·  {lockKey}: LOCK IN`,
				C.textSecondary
		end
		return if withGuns
			then `D-Pad: pick a gun  ·  {bumpers}: pick a power`
			else `{bumpers}: pick a power`,
			C.textSecondary
	end
	if canLock() then
		return if touch then "Ready: tap LOCK IN." else "Ready: press Enter or LOCK IN.",
			C.textSecondary
	end
	local left = MatchState.timeLeft()
	if left <= URGENT and left > 0 then
		-- What the server gives you if the clock runs out (DraftService.close).
		local gun = selectedGun or o.guns[1]
		local config = gun and Weapons.get(gun)
		local first = selectedAbility
			or o.abilities[1]
			or (o.upgrades and o.upgrades[1] and o.upgrades[1].key)
		local parts: { string } = {}
		if config then
			table.insert(parts, config.displayName)
		end
		if first then
			table.insert(parts, cardName(first))
		end
		return string.format(
			"%ds left. You'll get: %s",
			math.ceil(left),
			table.concat(parts, " + ")
		),
			C.gold
	end
	if not selectedGun and #o.guns > 0 then
		return if touch
			then "Tap a gun, then one card."
			else "Pick a gun (1, 2, 3) and one card (Q, E, T).",
			C.textSecondary
	end
	if not nothingToPick(o) then
		return if touch and selectedGun
			then string.format(
				"Gun: %s. Now tap one card (tap another gun to change).",
				string.upper(
					(Weapons.get(selectedGun :: string) or {} :: any).displayName
						or tostring(selectedGun)
				)
			)
			else "Now pick one card: a new power or an upgrade (Q, E, T).",
			C.textSecondary
	end
	return "", C.textSecondary
end

local function updateHint()
	local label = lockHint
	if not label then
		return
	end
	local text, color = hintText()
	if compact and offer and not locked then
		local left = math.max(0, math.ceil(MatchState.timeLeft()))
		text = string.format("%d:%02d  ·  %s", left // 60, left % 60, text)
	end
	if text ~= shownHint then
		shownHint = text
		label.Text = text
		label.TextColor3 = color
	end
end

-- LOCK IN's summary: "SHERIFF  +  HIGH RISE".
local function picksText(): string
	local parts: { string } = {}
	local gun = selectedGun
	if gun then
		local config = Weapons.get(gun)
		table.insert(parts, string.upper(if config then config.displayName else gun))
	end
	local key = selectedAbility
	if key then
		local id, level = string.match(key, "^(%w+):(%w+)$")
		local def = Mods.def(id or key)
		local pathName = if def and level then (def.paths :: any)[string.sub(level, 1, 1)] else nil
		table.insert(parts, string.upper(pathName or (if def then def.name else key)))
	end
	return table.concat(parts, "  +  ")
end

local function refreshSelection()
	DraftScreen.refresh(selectedGun, selectedAbility, canLock() and not locked, locked, picksText())
	updateHint()
end

local function lock()
	if locked then
		return
	end
	if canLock() then
		locked = true
		Net.event("DraftPick"):FireServer("Lock")
		UiSound.play("LockIn")
		refreshSelection()
		DraftScreen.press(true)
		return
	end
	-- Not ready: a "no" shake and the hint flashes.
	UiSound.play("Denied")
	DraftScreen.press(false)
	local label = lockHint
	if label then
		label.TextColor3 = C.gold
		Ui.tween(label, 0.6, { TextColor3 = C.textSecondary })
	end
end

-- Keys: 1 / 2 / 3 pick a gun, Q / E / T a card in that column (pressing the
-- same key again steps through its cards), Enter locks in. A gamepad moves
-- between cards with the D-pad and picks with A; X locks in (the LOCK IN
-- chip shows its glyph, Shared/InputGlyphs).
local function onKey(input: InputObject)
	if not isOpen or UserInputService:GetFocusedTextBox() then
		return
	end
	local key = input.KeyCode
	if
		key == Enum.KeyCode.Return
		or key == Enum.KeyCode.KeypadEnter
		or key == Enum.KeyCode.ButtonX
	then
		lock()
		return
	end
	for i, k in GUN_KEYS do
		local card = gunCards[i]
		if key == k and card then
			card.pick()
			return
		end
	end
	-- Controller: LB / RB step through the power cards, D-pad left / right through the guns; the pick follows,
	-- and the selection ring moves with it (A on a selected card picks it too, through GuiService).
	local step = PAD_STEPS[key]
	if step then
		local list = if step.guns then gunCards else abilityCards
		if #list == 0 then
			return
		end
		local current = if step.guns then selectedGun else selectedAbility
		local at = 0
		for i, c in list do
			if c.id == current then
				at = i
			end
		end
		local nextCard = list[(at - 1 + step.by) % #list + 1]
		if at == 0 then
			nextCard = list[if step.by > 0 then 1 else #list]
		end
		nextCard.pick()
		if nextCard.button then
			GuiService.SelectedObject = nextCard.button
		end
		return
	end
	-- A slot's own key (Settings kMod1-3, Q / E / T by default) cycles that column; new powers sit on the
	-- first empty slot's key.
	local slot: number? = nil
	for s = 1, ModsConfig.SLOTS do
		if table.find((InputGlyphs.keysFor("Mod" .. s)), key) then
			slot = s
			break
		end
	end
	slot = slot or SLOT_KEYS[key]
	if not slot then
		return
	end
	local column: { Card } = {}
	for _, c in abilityCards do
		if c.slot == slot then
			table.insert(column, c)
		end
	end
	if #column == 0 then
		UiSound.play("Denied")
		return
	end
	local at = 0
	for i, c in column do
		if c.id == selectedAbility then
			at = i
		end
	end
	column[at % #column + 1].pick()
end

-- The gun's shield line, or 0 when the phase gives everyone the same shield.
local function gunShield(phaseName: string, id: string): number
	for _, phase in MatchConfig.PHASES do
		if phase.name == phaseName and phase.flatShield then
			return 0
		end
	end
	return MatchState.shieldFor(phaseName, id)
end

-- The first empty slot: where any new power lands (slots fill in draft order, vault/01 Design/Loadout and
-- Power Deck.md), nil when all are filled.
local function firstFree(o: MatchState.DraftOffer): number?
	for slot = 1, ModsConfig.SLOTS do
		if (o.kit[slot] or "") == "" then
			return slot
		end
	end
	return nil
end

-- What the screen shows for an offer (Util/DraftScreen fills it in).
local function screenView(o: MatchState.DraftOffer): DraftScreen.View
	local guns: { DraftScreen.GunView } = {}
	for _, id in if o.focus then {} else o.guns do
		local config = Weapons.get(id)
		table.insert(guns, {
			id = id,
			name = if config then config.displayName else id,
			image = Theme.GUN[id] or "",
			shield = gunShield(o.phase, id),
		})
	end
	local columns: { DraftScreen.ColumnView } = {}
	local free = firstFree(o)
	local newShown = 0
	for slot = 1, ModsConfig.SLOTS do
		local owned = o.kit[slot] or ""
		local level = (o.levels or {})[slot] or ""
		local col: DraftScreen.ColumnView = {}
		if owned == "" then
			-- Each empty column shows the next new power; all of them go on the first empty slot (its key).
			newShown += 1
			local id = o.abilities[newShown]
			local def = id and Mods.def(id)
			if id and def then
				col.keySlot = free
				local l1Note = cardNote(id, "L1")
				col.new = {
					key = id,
					name = def.name,
					role = def.role,
					color = Theme.ROLE[def.role] or C.ally,
					art = Theme.CARD_ART[id] or "",
					note = if string.sub(l1Note, -1) == "." then l1Note else l1Note .. ".",
					charges = chargesText(id),
				}
			end
		else
			local def = Mods.def(owned)
			local name = string.upper(if def then def.name else owned)
			local color = if def then Theme.ROLE[def.role] or C.ally else C.ally
			local paths: { DraftScreen.PathView } = {}
			for _, c in o.upgrades or {} do
				if c.slot == slot then
					local path = string.sub(c.level, 1, 1)
					local glitch = path == "G"
					local stat = statLine(c.id, level, c.level)
					table.insert(paths, {
						key = c.key,
						name = if def then (def.paths :: any)[path] or c.level else c.level,
						tag = if glitch
							then name .. "  ·  GLITCHED"
							else string.format("%s  ·  LV %d", name, levelNumber(c.level)),
						stat = stat,
						color = color,
						art = Theme.CARD_ART[c.id] or "",
						glitch = glitch,
					})
				end
			end
			if #paths > 0 then
				col.paths = paths
			elseif not o.focus then -- focus (onboarding): nothing to pick here, the column hides
				local pathName = if def then (def.paths :: any)[string.sub(level, 1, 1)] else nil
				col.maxed = {
					icon = if def then def.icon else "",
					sub = string.format(
						"%s  ·  %s LV %d",
						name,
						string.upper(pathName or ""),
						levelNumber(level)
					),
				}
			end
		end
		columns[slot] = col
	end
	local enemy: { DraftScreen.EnemyView } = {}
	for _, entry in o.enemyKit do
		local id, level = string.match(entry, "^(%w+):(%w+)$")
		local def = id and Mods.def(id)
		if def and level then
			table.insert(enemy, {
				icon = def.icon,
				color = Theme.ROLE[def.role] or C.enemy,
				level = levelNumber(level),
			})
		end
	end
	return { guns = guns, columns = columns, enemy = enemy, focus = o.focus }
end

-- Fill the Studio-built screen. The card records keep the key and gamepad
-- logic above working (they carry the id, slot, hit area and pick).
local function showScreen(o: MatchState.DraftOffer)
	local function record(id: string, slot: number, onPick: () -> ()): Card
		return {
			id = id,
			slot = slot,
			button = DraftScreen.button(id),
			pick = function()
				if locked then
					return
				end
				onPick()
				refreshSelection()
				UiSound.play("Select")
			end,
		}
	end
	DraftScreen.show(screenView(o), {
		gun = function(i: number)
			local c = gunCards[i]
			if c then
				c.pick()
			end
		end,
		card = function(key: string)
			for _, c in abilityCards do
				if c.id == key then
					c.pick()
					return
				end
			end
		end,
		lock = lock,
		canHover = function(): boolean
			return not locked
		end,
	})
	for _, id in if o.focus then {} else o.guns do
		table.insert(
			gunCards,
			record(id, 0, function()
				selectedGun = id
				Net.event("DraftPick"):FireServer("Gun", id)
			end)
		)
	end
	-- New powers all land on the first empty slot, so its key cycles through them.
	local free = firstFree(o)
	if free then
		for _, id in o.abilities do
			if Mods.def(id) then
				table.insert(
					abilityCards,
					record(id, free, function()
						selectedAbility = id
						Net.event("DraftPick"):FireServer("Ability", id)
					end)
				)
			end
		end
	end
	for _, c in o.upgrades or {} do
		table.insert(
			abilityCards,
			record(c.key, c.slot, function()
				selectedAbility = c.key
				Net.event("DraftPick"):FireServer("Ability", c.key)
			end)
		)
	end
	lockHint = DraftScreen.hint()
	refreshSelection()
	setOpen(true)
end

local function show(o: MatchState.DraftOffer)
	if o.hidden then
		-- A new player's first round (Config/Onboarding SCRIPT): no pick screen, the kit is already on.
		offer = nil
		return
	end
	table.clear(gunCards)
	table.clear(abilityCards)
	offer = o
	-- Something is always selected, so doing nothing is a fine choice.
	selectedGun = o.gun or o.guns[1]
	selectedAbility = o.ability or o.abilities[1] or (o.upgrades[1] and o.upgrades[1].key)
	locked = false
	shownHint = ""
	-- The first offer can land before the screen reaches PlayerGui: it opens
	-- once the screen binds (DraftController.start).
	if DraftScreen.active() then
		showScreen(o)
	end
end

-- The screen closes once you've locked in, or when the draft ends.
local function syncVisibility()
	if MatchState.phase() ~= "Draft" or StateValues.get(player, "DraftLocked") == true then
		setOpen(false)
	end
end

function DraftController.isOpen(): boolean
	return isOpen
end

function DraftController.start()
	compact = Device.compact()
	-- An offer that landed before the screen bound opens once it does.
	DraftScreen.start(nil, function()
		local o = offer
		if
			o
			and not locked
			and MatchState.phase() == "Draft"
			and StateValues.get(player, "DraftLocked") ~= true
		then
			o.gun, o.ability = selectedGun, selectedAbility
			show(o)
		end
	end)
	Net.event("DraftOffer").OnClientEvent:Connect(function(o: MatchState.DraftOffer)
		-- Queued while this client was starting up: that draft is already over.
		if o.endsAt > workspace:GetServerTimeNow() then
			show(o)
		end
	end)
	MatchState.changed("Phase"):Connect(syncVisibility)
	StateValues.changed(player, "DraftLocked"):Connect(syncVisibility)
	UiSound.preload()
	UserInputService.InputBegan:Connect(onKey)
	-- The hint counts down your default pick in the last seconds.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if isOpen then
				updateHint()
			end
		end
	end)
	-- Started up mid-draft: ask for the cards.
	if MatchState.phase() == "Draft" then
		Net.event("DraftPick"):FireServer("Sync")
	end
end

return DraftController
