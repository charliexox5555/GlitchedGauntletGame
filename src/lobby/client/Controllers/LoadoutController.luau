--!strict
-- The range's LOADOUT menu (vault/01 Design/Range v5.md §4). Owner, 2026-11-25: "lets create a working load out
-- selector ... In that menu you can also access your locker". Opened from a range terminal (WorldPrompts hook
-- `RangeLoadout`: walk up to one, a hint shows over it, G / D-pad right / a tap opens the menu; the hint is drawn
-- here because ProximityPrompts never show inside the armed range, measured 2026-11-25). The screen is Studio-built (UI.Lobby.Loadout, backup tools/studio/BuildLoadoutMenu.luau); the gun
-- cards are the Locker's own templates (UI.Templates.Lobby.GunGroup / GunCard).
--
--   * PRIMARY / SECONDARY / MELEE tabs (or 1 / 2 / 3, or a slot card on the left) pick the slot;
--   * the right side lists every installed gun for that slot, grouped by class, in your equipped skin;
--   * clicking one asks the server for it (the existing PickWeapon remote: WeaponService checks the id, the
--     installed model, a live character and that you're in the range) and equips it; what you hold comes back in
--     WeaponState, which this menu mirrors (nothing is decided here);
--   * LOCKER opens the Locker; closing the Locker brings you back here.
-- While any lobby menu is open in the range, the mouse is freed and the match input paused (the match client's
-- `GameSettingsOpen` switch, the same one the Settings menu uses).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Locker = require(ReplicatedStorage.Shared.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Router = require(script.Parent.Parent.Util.Router)

local LoadoutController = {}

local player = Players.LocalPlayer
local C = LobbyKit.C
local ALLY = Color3.fromHex("3FE0F2") -- the picked card, like the Locker's list
local TEAL = Color3.fromHex("2BD9A8") -- the range's accent
local MENU = "Loadout"
local SETTINGS_SWITCH = "GameSettingsOpen" -- frees the mouse, pauses match input (CameraController, InputController)
local GROUP_WIDTH = 1070 -- the gun list's width inside the scroll (4 cards a row)
local TERMINAL_TAG = "RangeLoadout"
local REACH = 9 -- studs from a terminal's body to show its hint and take the key
local HINT_CHECK = 0.1 -- seconds between reach checks
local OPEN_KEYS: { [Enum.KeyCode]: boolean } =
	{ [Enum.KeyCode.G] = true, [Enum.KeyCode.DPadRight] = true }
local RUBIK_H = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik (Config/Theme)

local SLOTS: { Types.Slot } = { "Primary", "Secondary", "Melee" }
local CLASSES = {
	{ "Sidearm", "SIDEARMS" },
	{ "SMG", "SMGS" },
	{ "Shotgun", "SHOTGUNS" },
	{ "Rifle", "RIFLES" },
	{ "Sniper", "SNIPERS" },
	{ "MachineGun", "HEAVY" },
	{ "Melee", "MELEE" },
}
local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

local canvas: Frame? = nil
local gunsList: ScrollingFrame? = nil
local templates: Folder? = nil
local pickTab: ((number) -> ())? = nil
local isOpen = false
local slotIndex = 1
local held: { [Types.Slot]: string } = {} -- the server's last word on each slot
local cards: { [string]: GuiButton } = {}
local returnFromLocker = false
local hint: BillboardGui? = nil
local nearTerminal: BasePart? = nil
local freedMouse = false

local function child(parent: Instance, name: string): Instance
	return parent:WaitForChild(name, 5) or error(`[Loadout] missing {parent:GetFullName()}.{name}`)
end

local function installed(id: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	return folder ~= nil and folder:FindFirstChild(id) ~= nil
end

local function lineOf(id: string): string
	return Locker.equipped(player)[id] or "Stock"
end

local function picture(id: string): string
	return SkinArt.side(id, lineOf(id)) or Theme.GUN[id] or ""
end

local function title(id: string): string
	local cfg = Weapons.get(id)
	return string.upper(if cfg then cfg.displayName else id)
end

local function skinTitle(id: string): string
	local line = lineOf(id)
	return if line == "Stock" then "DEFAULT SKIN" else string.upper(line) .. " SKIN"
end

-- A slot's card: LobbyKit.button wraps a layout item in a holder of the same name (so it pops from its centre),
-- so look for the button itself.
local function slotCard(column: Instance, slot: string): GuiButton?
	for _, d in column:GetDescendants() do
		if d.Name == slot and d:IsA("GuiButton") then
			return d
		end
	end
	return nil
end

-- The left column: what each slot holds now; the picked slot is lit.
local function renderSlots()
	local c = canvas
	if not c then
		return
	end
	local column = c:FindFirstChild("Slots")
	if not column then
		return
	end
	for i, slot in SLOTS do
		local card = slotCard(column, slot)
		if not card then
			continue
		end
		local id = held[slot]
		local on = i == slotIndex
		UiMotion.tween(card, 0.16, {
			BackgroundColor3 = if on then C.navyHi else C.navy,
			BackgroundTransparency = if on then 0 else 0.2,
		})
		local icon = card:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.Image = if id then picture(id) else ""
		end
		local name = card:FindFirstChild("Name")
		if name and name:IsA("TextLabel") then
			name.Text = if id then title(id) else "EMPTY"
		end
		local skin = card:FindFirstChild("Skin")
		if skin and skin:IsA("TextLabel") then
			skin.Text = if id then skinTitle(id) else ""
		end
		local kicker = card:FindFirstChild("Kicker")
		if kicker and kicker:IsA("TextLabel") then
			kicker.TextColor3 = if on then TEAL else C.muted
		end
	end
end

local function styleCard(card: GuiButton, on: boolean)
	UiMotion.tween(card, 0.14, {
		BackgroundColor3 = if on then ALLY else C.navy,
		BackgroundTransparency = if on then 0 else 0.25,
	})
	local name = card:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		name.TextColor3 = if on then C.ink else C.white
	end
	local row = card:FindFirstChild("Skin")
	local label = row and row:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = if on then C.ink else C.muted
	end
end

local function refreshCards()
	local slot = SLOTS[slotIndex]
	for id, card in cards do
		styleCard(card, held[slot] == id)
		local icon = card:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.Image = picture(id)
		end
	end
end

local function choose(id: string)
	local cfg = Weapons.get(id)
	if not cfg or not installed(id) then
		return
	end
	if held[cfg.slot] == id then
		UiSfx.cue("Back")
		return
	end
	UiSfx.cue("Confirm")
	-- Shown at once; the server's WeaponState confirms it (or puts back what you really hold).
	held[cfg.slot] = id
	Net.event("PickWeapon"):FireServer(id)
	refreshCards()
	renderSlots()
end

-- The guns for the picked slot, grouped by class, the Locker's cards.
local function buildGuns()
	local list, tpl = gunsList, templates
	if not list or not tpl then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(cards)
	local slot = SLOTS[slotIndex]
	local order = 0
	for _, class in CLASSES do
		local ids: { string } = {}
		for _, cfg in Weapons.list do
			if cfg.slot == slot and cfg.class == class[1] and installed(cfg.id) then
				table.insert(ids, cfg.id)
			end
		end
		if #ids == 0 then
			continue
		end
		table.sort(ids, function(a: string, b: string): boolean
			local ca, cb = Weapons.get(a), Weapons.get(b)
			local ta, tb = if ca then ca.tier else 0, if cb then cb.tier else 0
			if ta ~= tb then
				return ta < tb
			end
			return title(a) < title(b)
		end)
		order += 1
		local group = (tpl:WaitForChild("GunGroup") :: Frame):Clone()
		group.Name = class[2]
		group.LayoutOrder = order
		local headRow = group:FindFirstChild("HeadRow")
		if headRow and headRow:IsA("GuiObject") then
			headRow.Size = UDim2.fromOffset(GROUP_WIDTH, headRow.Size.Y.Offset)
			local head = headRow:FindFirstChild("Head")
			if head and head:IsA("TextLabel") then
				head.Text = class[2]
			end
			local count = headRow:FindFirstChild("Count")
			if count and count:IsA("TextLabel") then
				count.Text = tostring(#ids)
			end
		end
		local grid = group:FindFirstChild("Grid")
		if not (grid and grid:IsA("GuiObject")) then
			continue
		end
		grid.Size = UDim2.new(0, GROUP_WIDTH, grid.Size.Y.Scale, grid.Size.Y.Offset)
		for i, id in ids do
			local card = (tpl:WaitForChild("GunCard") :: GuiButton):Clone()
			card.Name = id
			card.LayoutOrder = i
			local name = card:FindFirstChild("Name")
			if name and name:IsA("TextLabel") then
				name.Text = title(id)
			end
			local row = card:FindFirstChild("Skin")
			local label = row and row:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.Text = skinTitle(id)
			end
			card.Parent = grid
			LobbyKit.button(card, function()
				choose(id)
			end, { card = true })
			cards[id] = card
		end
		group.Parent = list
	end
	list.CanvasPosition = Vector2.zero
	refreshCards()
end

local function selectSlot(i: number)
	slotIndex = math.clamp(i, 1, #SLOTS)
	buildGuns()
	renderSlots()
end

-- What the server says each slot holds (sent to this player only; checked here before use).
local function onWeaponState(state: unknown)
	if typeof(state) ~= "table" then
		return
	end
	local slots = (state :: any).slots
	if typeof(slots) ~= "table" then
		return
	end
	for _, slot in SLOTS do
		local s = slots[slot]
		local id = if typeof(s) == "table" then s.id else nil
		held[slot] = if typeof(id) == "string" then id else nil
	end
	if isOpen then
		refreshCards()
		renderSlots()
	end
end

-- Any lobby menu open in the range frees the mouse (first person locks it) and pauses the match input.
local function onMenuChanged(name: string?)
	local inRange = PlayZone.get(player) == "Range"
	local want = inRange and name ~= nil
	if want ~= freedMouse then
		freedMouse = want
		player:SetAttribute(SETTINGS_SWITCH, want)
	end
	-- LOCKER from here: closing the Locker comes back to the loadout.
	if name == "Locker" then
		return
	end
	if name == nil and returnFromLocker and inRange then
		returnFromLocker = false
		task.defer(Router.open, MENU)
		return
	end
	returnFromLocker = false
end

local function entrance()
	local c = canvas
	if not c or UiMotion.reduced() then
		return
	end
	local column = c:FindFirstChild("Slots")
	if column and column:IsA("GuiObject") then
		UiMotion.slideIn(column, -24, 0, 0)
	end
	if gunsList then
		UiMotion.slideIn(gunsList, 24, 0, 0.04)
	end
end

-- The hint over the terminal you're at: a dark plate with the key chip, tappable on touch screens.
local function buildHint(parent: Instance): BillboardGui
	local g = Instance.new("BillboardGui")
	g.Name = "LoadoutHint"
	g.ResetOnSpawn = false
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Active = true
	g.Size = UDim2.fromOffset(236, 52)
	g.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	g.Enabled = false
	local plate = Instance.new("TextButton")
	plate.Name = "Plate"
	plate.Text = ""
	plate.AutoButtonColor = false
	plate.BackgroundColor3 = C.navy
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	plate.Size = UDim2.fromScale(1, 1)
	plate.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = plate
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundColor3 = C.white
	key.BorderSizePixel = 0
	key.Position = UDim2.fromOffset(10, 10)
	key.Size = UDim2.fromOffset(32, 32)
	key.FontFace = RUBIK_H
	key.TextSize = 20
	key.TextColor3 = C.ink
	key.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "»"
		else "G"
	key.Parent = plate
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 4)
	keyCorner.Parent = key
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(54, 0)
	label.Size = UDim2.new(1, -60, 1, 0)
	label.FontFace = RUBIK_H
	label.TextSize = 22
	label.TextColor3 = C.white
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "CHOOSE GUNS"
	label.Parent = plate
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BackgroundColor3 = TEAL
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 10, 1, 0)
	bar.Size = UDim2.new(1, -20, 0, 3)
	bar.Parent = plate
	plate.Activated:Connect(function()
		if nearTerminal and Router.current() == nil then
			Router.open(MENU)
		end
	end)
	g.Parent = parent
	return g
end

-- The terminal body within reach (nil when none, or when not in the range / a menu is open).
local function terminalInReach(): BasePart?
	if PlayZone.get(player) ~= "Range" or Router.current() ~= nil then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = REACH
	for _, inst in CollectionService:GetTagged(TERMINAL_TAG) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local d = (inst.Position - root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = inst, d
			end
		end
	end
	return best
end

local function watchTerminals()
	while true do
		local found = terminalInReach()
		local h = hint
		if h and found ~= nearTerminal then
			nearTerminal = found
			h.Adornee = found
			h.Enabled = found ~= nil
		end
		task.wait(HINT_CHECK)
	end
end

function LoadoutController.start()
	local pg = player:WaitForChild("PlayerGui")
	local screen = pg:WaitForChild(MENU, 30)
	if not (screen and screen:IsA("ScreenGui")) then
		warn("[Loadout] no UI.Lobby.Loadout screen (run tools/studio/BuildLoadoutMenu.luau)")
		return
	end
	local c = child(screen, "Canvas") :: Frame
	canvas = c
	gunsList = child(c, "Guns") :: ScrollingFrame
	templates = UiRoot.templates():WaitForChild("Lobby") :: Folder
	LobbyKit.deepen(screen)

	local tabs: { GuiButton } = {}
	for _, name in { "PRIMARY", "SECONDARY", "MELEE" } do
		table.insert(tabs, child(child(c, "Tabs"), name) :: GuiButton)
	end
	pickTab = LobbyKit.tabs(tabs, selectSlot)
	local column = child(c, "Slots")
	for i, slot in SLOTS do
		local card = slotCard(column, slot)
		if card then
			LobbyKit.button(card, function()
				if pickTab then
					pickTab(i)
				end
			end, { card = true })
		end
	end
	LobbyKit.button(child(c, "Locker") :: GuiButton, function()
		returnFromLocker = true
		Router.open("Locker")
	end)

	LobbyKit.page({
		name = MENU,
		gui = screen,
		-- lihfolk-ignore: findfirstchild-chain (a cast to an optional, never indexed; page() handles nil)
		wash = screen:FindFirstChild("Wash") :: GuiObject?,
		close = child(c, "Close") :: GuiButton,
		focus = function(): GuiObject?
			local list = gunsList
			return if list then list:FindFirstChildWhichIsA("GuiButton", true) else nil
		end,
		onOpen = function()
			isOpen = true
			-- Ask for a fresh snapshot of what's in hand (the server answers with WeaponState).
			Net.event("WeaponState"):FireServer()
			if pickTab then
				pickTab(slotIndex)
			end
			buildGuns()
			renderSlots()
			entrance()
		end,
		onClose = function()
			isOpen = false
		end,
	})

	Net.event("WeaponState").OnClientEvent:Connect(onWeaponState)
	Locker.observe(player, function()
		if isOpen then
			refreshCards()
			renderSlots()
		end
	end)
	Router.onChanged(onMenuChanged)
	-- Leaving the range with a menu open: give the mouse back to the lobby.
	PlayZone.onLocalChanged(function()
		if PlayZone.get(player) ~= "Range" then
			if Router.current() == MENU then
				Router.close()
			end
			if freedMouse then
				freedMouse = false
				player:SetAttribute(SETTINGS_SWITCH, false)
			end
		end
	end)
	hint = buildHint(pg)
	task.spawn(watchTerminals)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if not isOpen then
			if OPEN_KEYS[input.KeyCode] and nearTerminal and Router.current() == nil then
				Router.open(MENU)
			end
			return
		end
		local i = KEYS[input.KeyCode]
		if i and pickTab then
			pickTab(i)
		end
	end)
end

return LoadoutController
