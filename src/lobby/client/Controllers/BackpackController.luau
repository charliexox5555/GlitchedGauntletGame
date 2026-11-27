--!strict
-- The Backpack (vault/01 Design/Inventory and Crates.md → Backpack): every stack the player
-- holds, from the server-published inventory (Shared/PlayerData). Studio-built
-- StarterGui.Backpack + UiTemplates.Lobby.BackpackCell (tools/studio/BuildBackpack.luau),
-- opened from the bottom bar's BACKPACK (it replaced the Battle Pass for the first release).
-- Opening (2026-11-20): click a stack → the item popup (after RIVALS' Backpack):
-- its picture and ×count, CONTENTS (the grouped odds, Util/OddsList) and OPEN, which
-- sends ShopRequest("openCase")
-- (Services/ShopService rolls and grants a skin you don't own); the reveal panel
-- shows it with its tier, EQUIP puts it on through the Locker's LockerRequest.
-- The in-world animation starts as soon as the player selects OPEN 1 or OPEN 3.
-- Several skins at once (a batch, or a bought bundle: presentOpening, owner 2026-11-25 "a menu with
-- every gun to equip"): a strip under the reveal shows them all (click one to see it), and
-- EQUIP ALL puts every one on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local OpeningConfig = require(ReplicatedStorage.Shared.Config.CaseOpening)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local PowerCardFace = require(script.Parent.Parent.Util.PowerCardFace)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local OddsList = require(script.Parent.Parent.Util.OddsList)
local CaseOpening = require(script.Parent.Parent.Util.CaseOpening)
local ShopRewardFx = require(script.Parent.Parent.Util.ShopRewardFx)
local LobbyHud = require(script.Parent.LobbyHud)
local Router = require(script.Parent.Parent.Util.Router)

local BackpackController = {}

local present: ((crateTier: number, results: { LobbyNet.CaseReward }) -> boolean)? = nil

-- A bought bundle's opening (Controllers/ShopController): its crates thrown at once, then the
-- reveal with every skin and EQUIP ALL. false = not ready or an opening is still playing.
function BackpackController.presentOpening(
	crateTier: number,
	results: { LobbyNet.CaseReward }
): boolean
	local run = present
	return run ~= nil and #results > 0 and run(crateTier, results)
end

local player = Players.LocalPlayer
local COLS = 6
local MIN_ROWS = 3 -- empty slots fill the grid like the reference
local EMPTY = Color3.fromHex("121215")

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

type Stack = { def: Inventory.ItemDef, count: number }

-- known items with a count, by kind, then tier, then name
local function stacks(): { Stack }
	local out: { Stack } = {}
	for id, n in PlayerData.items(player) do
		local def = Inventory.ITEMS[id]
		if def and n > 0 then
			table.insert(out, { def = def, count = n })
		end
	end
	table.sort(out, function(a, b)
		if a.def.kind ~= b.def.kind then
			return a.def.kind < b.def.kind
		end
		if a.def.tier ~= b.def.tier then
			return a.def.tier < b.def.tier
		end
		return a.def.name < b.def.name
	end)
	return out
end

function BackpackController.init()
	local g = player:WaitForChild("PlayerGui"):WaitForChild("Backpack", 15)
	local folder = UiRoot.findTemplates(15)
	local lobby = folder and folder:WaitForChild("Lobby", 15)
	local tpl = lobby and lobby:WaitForChild("BackpackCell", 15)
	if not (g and g:IsA("ScreenGui") and tpl and tpl:IsA("GuiButton")) then
		warn(
			"[Backpack] StarterGui.Backpack or its cell template missing (tools/studio/BuildBackpack.luau)"
		)
		return
	end
	local gui = g
	local template = tpl
	gui.Enabled = false
	local canvas = child(gui, "Canvas") :: Frame
	local grid = child(canvas, "Grid") :: ScrollingFrame
	local detail = child(canvas, "Detail") :: TextLabel
	local empty = child(canvas, "Empty") :: Frame
	local openShop = child(empty, "OpenShop") :: GuiButton
	local itemShade = child(canvas, "ItemShade") :: Frame
	local itemPanel = child(canvas, "ItemPanel") :: Frame
	local contentsPanel = child(canvas, "ContentsPanel") :: Frame
	local shade = child(canvas, "RevealShade") :: Frame
	local reveal = child(canvas, "Reveal") :: Frame
	local revealPop = child(reveal, "Pop") :: UIScale
	local first: GuiObject? = nil
	local isOpen = false
	local picked: string? = nil -- the item the popup shows
	local serial = 0
	local pending: number? = nil
	local revealed: { LobbyNet.CaseReward } = {}
	local revealIndex = 1
	local contentsButton = child(itemPanel, "Contents") :: GuiButton
	local openOne = child(itemPanel, "Open") :: GuiButton
	local openBatch = openOne:Clone() -- same plate and hover treatment as the Studio button
	openBatch.Name = "OpenBatch"
	openBatch.Visible = false
	openBatch.Parent = itemPanel
	local contentsPosition, contentsSize = contentsButton.Position, contentsButton.Size
	local openPosition, openSize = openOne.Position, openOne.Size
	local openOneLabel = child(openOne, "Label") :: TextLabel
	local equipButton = child(reveal, "Equip") :: GuiButton
	local doneButton = child(reveal, "Done") :: GuiButton
	local doneLabel = child(doneButton, "Label") :: TextLabel
	local doneText = doneLabel.Text
	local batchLabel = child(openBatch, "Label") :: TextLabel
	batchLabel.Text = `OPEN {Inventory.BATCH_OPEN_COUNT}`
	openOneLabel.Text = "OPEN 1"
	local crate: CaseOpening.Handle? = nil -- the in-world opening in progress
	local fromBundle = false -- the reveal shows a bought bundle (EQUIP ALL closes the Backpack)
	local DARK_PLATE = doneButton.BackgroundColor3
	local GOLD_PLATE = equipButton.BackgroundColor3
	local DARK_INK = doneLabel.TextColor3 -- words on a dark plate
	local GOLD_INK = (child(equipButton, "Label") :: TextLabel).TextColor3
	local equipHome, doneHome, buttonSize =
		equipButton.Position, doneButton.Position, equipButton.Size
	local equipAll = equipButton:Clone()
	equipAll.Name = "EquipAll"
	equipAll.Visible = false
	equipAll.Parent = reveal;
	(child(equipAll, "Label") :: TextLabel).Text = "EQUIP ALL"
	-- the haul strip: one cell per skin, under the reveal panel
	local HAUL = OpeningConfig.HAUL
	local haul = Instance.new("Frame")
	haul.Name = "Haul"
	haul.BackgroundTransparency = 1
	haul.AnchorPoint = Vector2.new(0.5, 0)
	haul.Position = reveal.Position + UDim2.fromOffset(0, reveal.Size.Y.Offset / 2 + HAUL.gap)
	haul.Size = UDim2.fromOffset(reveal.Size.X.Offset + 200, HAUL.cell.Y + 12)
	haul.ZIndex = reveal.ZIndex
	haul.Visible = false
	local haulList = Instance.new("UIListLayout")
	haulList.FillDirection = Enum.FillDirection.Horizontal
	haulList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	haulList.VerticalAlignment = Enum.VerticalAlignment.Center
	haulList.SortOrder = Enum.SortOrder.LayoutOrder
	haulList.Padding = UDim.new(0, HAUL.padding)
	haulList.Parent = haul
	haul.Parent = canvas

	local showItem: (def: Inventory.ItemDef, count: number) -> ()

	local function pop(panel: Frame)
		local sc = panel:FindFirstChild("Pop")
		if sc and sc:IsA("UIScale") then
			sc.Scale = 0.85
			UiMotion.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
	end
	local function hideItem()
		itemShade.Visible = false
		itemPanel.Visible = false
		contentsPanel.Visible = false
	end

	local function render()
		LobbyKit.clearSlots(grid)
		detail.Text = ""
		first = nil
		local list = stacks()
		local cells = math.max(MIN_ROWS * COLS, math.ceil(#list / COLS) * COLS)
		for i = 1, cells do
			local s = list[i]
			local cell = LobbyKit.slot(template, grid, function(c: GuiButton)
				c.Name = if s then "Item_" .. s.def.id else "Empty_" .. i
				c.LayoutOrder = i
				StateValues.set(c, "Slot", true)
				local art = child(c, "Art") :: ImageLabel
				local count = child(c, "Count") :: TextLabel
				local shadow = child(c, "CountShadow") :: TextLabel
				art.Image = if s then s.def.icon or "" else ""
				art.Visible = s ~= nil
				local word = if s then "×" .. tostring(s.count) else ""
				count.Text, shadow.Text = word, word
				-- empty slots are darker and quieter than a stack (the reference's dark slots)
				if not s then
					c.BackgroundColor3 = EMPTY
					c.BackgroundTransparency = 0.3
				end
				c.Selectable = s ~= nil
				c.Active = s ~= nil
			end)
			LobbyKit.cell(cell)
			if s then
				first = first or cell
				local name = string.format("%s  ×%d", s.def.name, s.count)
				local def = s.def
				local held = s.count
				cell.MouseEnter:Connect(function()
					detail.Text = name
				end)
				cell.SelectionGained:Connect(function()
					detail.Text = name
				end)
				LobbyKit.button(cell, function()
					showItem(def, held)
				end)
			end
		end
		empty.Visible = #list == 0
		grid.Visible = true
	end

	local function showReveal(on: boolean)
		player:SetAttribute("CaseRevealOpen", on)
		shade.Visible = on
		reveal.Visible = on
		if on then
			revealPop.Scale = if UiMotion.reduced() then 1 else 0.9
			UiMotion.tween(
				revealPop,
				0.36,
				{ Scale = 1 },
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			)
		end
	end

	-- the result of an opening: picture (else the line's emblem), name in the tier colour
	local function fillReveal(
		gun: string,
		line: string,
		tierId: string?,
		name: string,
		power: string?
	)
		local tier = Skins.TIERS[(tierId or "Common") :: any] or Skins.TIERS.Common
		local art = child(reveal, "Art") :: ImageLabel
		local emblem = child(reveal, "Emblem") :: ImageLabel
		-- the square portrait, like the case card; a power shows its card art, cropped
		local pic = if power then Theme.CARD_ART[power] else SkinArt.portrait(gun, line)
		art.Image = pic or ""
		PowerCardFace.thumb(art, power)
		art.Visible = pic ~= nil
		emblem.Image = Locker.EMBLEMS[line] or ""
		emblem.ImageColor3 = Locker.COLORS[line] or tier.color
		emblem.Visible = pic == nil
		-- no picture and no emblem yet: the line's initial in its colour
		local letter = reveal:FindFirstChild("Letter")
		if not letter then
			local l = Instance.new("TextLabel")
			l.Name = "Letter"
			l.BackgroundTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = emblem.Position
			l.Size = emblem.Size
			l.FontFace = (child(reveal, "Name") :: TextLabel).FontFace
			l.TextScaled = true
			l.ZIndex = emblem.ZIndex
			l.Parent = reveal
			letter = l
		end
		if letter and letter:IsA("TextLabel") then
			letter.Text = string.sub(string.upper(line), 1, 1)
			letter.TextColor3 = Locker.COLORS[line] or tier.color
			letter.Visible = pic == nil and Locker.EMBLEMS[line] == nil
		end
		-- a power: its role colour and role word instead of a skin tier
		local color = tier.color -- a power is ranked in the same tiers (Config/PowerCases)
		local title = child(reveal, "Name") :: TextLabel
		title.Text = name
		title.TextColor3 = color
		local plate = child(reveal, "Tier") :: Frame
		plate.BackgroundColor3 = color
		for _, cap in plate:GetChildren() do
			if cap:IsA("ImageLabel") then
				cap.ImageColor3 = color
			end
		end
		(child(plate, "Label") :: TextLabel).Text = if power
			then tier.name .. " POWER"
			else tier.name
	end

	-- the item popup: a case shows CONTENTS and OPEN
	showItem = function(def: Inventory.ItemDef, count: number)
		local wasVisible = itemPanel.Visible
		picked = def.id
		local case = if def.case then ShopCatalog.case(def.case) else nil;
		(child(itemPanel, "Title") :: TextLabel).Text = def.name
		local art = child(itemPanel, "Art") :: ImageLabel
		art.Image = (if case then case.art else nil) or def.icon or ""
		local word = "×" .. tostring(count);
		(child(itemPanel, "Count") :: TextLabel).Text = word;
		(child(itemPanel, "CountShadow") :: TextLabel).Text = word
		local isCase = def.kind == "Case" and case ~= nil
		contentsButton.Visible = isCase
		openOne.Visible = isCase
		local canBatch = isCase and count >= Inventory.BATCH_OPEN_COUNT
		openBatch.Visible = canBatch
		local offset = UDim2.fromOffset(OpeningConfig.BATCH_BUTTON_STEP, 0)
		local middle = openPosition - UDim2.fromOffset(openPosition.X.Offset, 0)
		local size =
			UDim2.new(0, OpeningConfig.BATCH_BUTTON_WIDTH, openSize.Y.Scale, openSize.Y.Offset)
		contentsButton.Position = if canBatch then middle - offset else contentsPosition
		contentsButton.Size = if canBatch then size else contentsSize
		openOne.Position = if canBatch then middle else openPosition
		openOne.Size = if canBatch then size else openSize
		openBatch.Position = middle + offset
		openBatch.Size = size
		contentsPanel.Visible = false
		itemShade.Visible = true
		itemPanel.Visible = true
		if not wasVisible then
			pop(itemPanel)
		end
	end
	LobbyKit.button(child(itemPanel, "Close") :: GuiButton, hideItem)
	LobbyKit.button(child(contentsPanel, "Close") :: GuiButton, function()
		contentsPanel.Visible = false
		itemPanel.Visible = true
	end)
	LobbyKit.button(contentsButton, function()
		local def = if picked then Inventory.ITEMS[picked] else nil
		local case = if def and def.case then ShopCatalog.case(def.case) else nil
		if not (def and case) then
			return
		end
		(child(contentsPanel, "Sub") :: TextLabel).Text = def.name
		OddsList.fill(
			child(contentsPanel, "List") :: ScrollingFrame,
			case,
			child(contentsPanel, "Note") :: TextLabel
		)
		itemPanel.Visible = false
		contentsPanel.Visible = true
		pop(contentsPanel)
	end)

	local function requestOpening(amount: number)
		local selected = picked
		if pending or not selected then
			return
		end
		if (PlayerData.items(player)[selected] or 0) < amount then
			LobbyHud.toast(
				if amount == 1
					then "That case is no longer in your Backpack"
					else `You need {amount} of that case`,
				"info"
			)
			return
		end
		local busy = crate
		if busy and not busy:isDead() then
			UiSfx.cue("PurchaseDenied")
			LobbyHud.toast("Wait for the opening to finish", "info")
			return
		end
		hideItem()
		serial += 1
		local id = serial
		pending = id
		local def = Inventory.ITEMS[selected]
		player:SetAttribute("CaseOpeningActive", true)
		Router.close()
		crate = CaseOpening.start(player, if def then def.tier else 1, true, amount)
		LobbyNet.event("ShopRequest"):FireServer("openCase", selected, amount, id)
		task.delay(OpeningConfig.ANSWER_TIMEOUT, function()
			if pending == id then
				pending = nil
				player:SetAttribute("CaseOpeningActive", false)
				local active = crate
				crate = nil
				if active then
					active:abort()
				end
				LobbyHud.toast(
					"Couldn't confirm the opening. Check your Backpack and Locker.",
					"info"
				)
			end
		end)
	end
	LobbyKit.button(openOne, function()
		requestOpening(1)
	end)

	LobbyKit.button(openBatch, function()
		requestOpening(Inventory.BATCH_OPEN_COUNT)
	end)

	local function paintPlate(button: GuiButton, gold: boolean)
		local color = if gold then GOLD_PLATE else DARK_PLATE
		button.BackgroundColor3 = color
		for _, cap in button:GetChildren() do
			if cap:IsA("ImageLabel") then
				cap.ImageColor3 = color
			end
		end
		(child(button, "Label") :: TextLabel).TextColor3 = if gold then GOLD_INK else DARK_INK
	end

	local function isOn(r: LobbyNet.CaseReward): boolean
		return Locker.equipped(player)[r.gun] == r.line
	end

	local drawResult: () -> ()

	-- every result in a row: the current one lifted in its tier colour, equipped ones marked
	local function drawHaul()
		for _, c in haul:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local many = #revealed > 1 and reveal.Visible
		haul.Visible = many
		detail.Visible = not reveal.Visible
		local hint = canvas:FindFirstChild("Note") -- "click a case to see…", under the strip
		if hint and hint:IsA("GuiObject") then
			hint.Visible = not reveal.Visible
		end
		local anySkin = false
		for _, r in revealed do
			anySkin = anySkin or r.power == nil
		end
		equipAll.Visible = many and anySkin
		equipButton.Size, equipAll.Size, doneButton.Size = buttonSize, buttonSize, buttonSize
		equipButton.Visible = true
		paintPlate(doneButton, false)
		if not many then
			equipButton.Position, doneButton.Position = equipHome, doneHome
			paintPlate(equipButton, true)
			return
		end
		-- EQUIP · EQUIP ALL (gold: the one act-now thing) · NEXT
		local narrow =
			UDim2.new(buttonSize.X.Scale, HAUL.buttonWidth, buttonSize.Y.Scale, buttonSize.Y.Offset)
		equipButton.Size, equipAll.Size, doneButton.Size = narrow, narrow, narrow
		local y = equipHome.Y
		equipButton.Position = UDim2.new(0.5, -HAUL.buttonStep, y.Scale, y.Offset)
		equipAll.Position = UDim2.new(0.5, 0, y.Scale, y.Offset)
		doneButton.Position = UDim2.new(0.5, HAUL.buttonStep, y.Scale, y.Offset)
		paintPlate(equipButton, false)
		paintPlate(equipAll, true)
		for i, r in revealed do
			local tier = Skins.TIERS[(r.tier or "Common") :: any] or Skins.TIERS.Common
			local current = i == revealIndex
			local holder = Instance.new("Frame")
			holder.Name = "Haul_" .. i
			holder.BackgroundTransparency = 1
			holder.LayoutOrder = i
			holder.Size = UDim2.fromOffset(HAUL.cell.X, HAUL.cell.Y)
			local cell = template:Clone()
			cell.Name = "Cell"
			cell.AnchorPoint = Vector2.new(0.5, 0.5)
			cell.Position = UDim2.fromScale(0.5, 0.5)
			local fit = Instance.new("UIScale")
			fit.Scale = HAUL.cell.X
				/ cell.Size.X.Offset
				* (if current then HAUL.currentScale else 1)
			fit.Parent = cell
			cell.BackgroundColor3 = if current
				then DARK_PLATE:Lerp(tier.color, 0.45)
				else DARK_PLATE
			local art = child(cell, "Art") :: ImageLabel
			art.Image = SkinArt.portrait(r.gun, r.line) or ""
			PowerCardFace.thumb(art, r.power)
			art.ImageTransparency = if current then 0 else 0.25
			local word = if isOn(r) then "EQUIPPED" else ""
			for _, name in { "Count", "CountShadow" } do
				local label = child(cell, name) :: TextLabel
				label.Text = word
				label.TextScaled = false
				label.TextSize = HAUL.textSize
			end
			cell.Parent = holder
			holder.Parent = haul
			local index = i
			LobbyKit.button(cell, function()
				if revealIndex ~= index then
					revealIndex = index
					drawResult()
				end
			end)
		end
	end

	drawResult = function()
		local result = revealed[revealIndex]
		if not result then
			showReveal(false)
			drawHaul()
			return
		end
		fillReveal(result.gun, result.line, result.tier, result.name, result.power)
		local tier = Skins.TIERS[(result.tier or "Common") :: any] or Skins.TIERS.Common
		local word = if result.power then "NEW POWER" else "NEW SKIN"
		local kicker = reveal:FindFirstChild("Kicker")
		if kicker and kicker:IsA("TextLabel") then
			kicker.Text = if #revealed > 1 then `{word}  ·  {revealIndex} OF {#revealed}` else word
		end
		-- a power is already in your collection (and your deck when it has room): the button goes to it
		local equipLabel = equipButton:FindFirstChild("Label")
		if equipLabel and equipLabel:IsA("TextLabel") then
			equipLabel.Text = if result.power then "SEE IN LOCKER" else "EQUIP"
		end
		local edge = reveal:FindFirstChild("RevealEdge")
		if not (edge and edge:IsA("UIStroke")) then
			local st = Instance.new("UIStroke")
			st.Name = "RevealEdge"
			st.Parent = reveal
			edge = st
		end
		if edge and edge:IsA("UIStroke") then
			edge.Color = tier.color
			edge.Thickness = if tier.order >= 4 then 3 else 2
			edge.Transparency = if tier.order >= 3 then 0.15 else 0.45
		end
		local art = child(reveal, "Art") :: ImageLabel
		ShopRewardFx.accent(reveal, art, tier.color, tier.order)
		if not UiMotion.reduced() then
			local artPop = art:FindFirstChild("Pop") or Instance.new("UIScale")
			artPop.Name = "Pop"
			artPop.Parent = art
			if artPop:IsA("UIScale") then
				artPop.Scale = 0.82
				UiMotion.tween(
					artPop,
					0.34,
					{ Scale = 1 },
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				)
			end
			local plate = child(reveal, "Tier") :: Frame
			local platePop = plate:FindFirstChild("Pop") or Instance.new("UIScale")
			platePop.Name = "Pop"
			platePop.Parent = plate
			if platePop:IsA("UIScale") then
				platePop.Scale = 1.24
				UiMotion.tween(
					platePop,
					0.28,
					{ Scale = 1 },
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				)
			end
		end
		if tier.order >= 4 then
			UiSfx.cue("RewardFinalHit")
		elseif tier.order >= 2 then
			UiSfx.cue("RewardItemTick")
		else
			UiSfx.cue("Confirm")
		end
		doneLabel.Text = if revealIndex < #revealed
			then `NEXT {revealIndex}/{#revealed}`
			else doneText
		showReveal(true)
		drawHaul()
	end

	local function nextResult()
		revealIndex += 1
		drawResult()
	end

	LobbyKit.button(equipButton, function()
		UiSfx.cue("Confirm")
		local result = revealed[revealIndex]
		if result and result.power then
			Router.open("Locker", "powers")
			return
		end
		if result then
			LobbyNet.event("LockerRequest"):FireServer("equip", result.gun, result.line)
			task.spawn(function()
				local t = os.clock()
				while os.clock() - t < 4 do
					if Locker.equipped(player)[result.gun] == result.line then
						LobbyHud.toast("Equipped in your Locker", "success")
						return
					end
					task.wait(0.2)
				end
				LobbyHud.toast("Couldn't equip it, try in the Locker", "error")
			end)
		end
		nextResult()
	end)
	LobbyKit.button(doneButton, nextResult)

	-- EQUIP ALL: every skin of the opening on (one per gun; the last wins), then close.
	LobbyKit.button(equipAll, function()
		UiSfx.cue("RewardFinalHit")
		local byGun: { [string]: LobbyNet.CaseReward } = {}
		local guns = 0
		for _, r in revealed do
			if r.power then
				continue -- powers have nothing to equip
			end
			if not byGun[r.gun] then
				guns += 1
			end
			byGun[r.gun] = r
		end
		local wanted: { LobbyNet.CaseReward } = {}
		for _, r in byGun do
			if not isOn(r) then
				table.insert(wanted, r)
				LobbyNet.event("LockerRequest"):FireServer("equip", r.gun, r.line)
			end
		end
		local closeAfter = fromBundle
		revealIndex = #revealed + 1
		drawResult()
		if closeAfter and Router.current() == "Backpack" then
			Router.close()
		end
		task.spawn(function()
			local t = os.clock()
			while os.clock() - t < 4 do
				local done = true
				for _, r in wanted do
					if not isOn(r) then
						done = false
					end
				end
				if done then
					LobbyHud.toast(`{guns} SKINS EQUIPPED`, "success")
					return
				end
				task.wait(0.2)
			end
			LobbyHud.toast("Some didn't equip, try in the Locker", "error")
		end)
	end)

	present = function(crateTier: number, results: { LobbyNet.CaseReward }): boolean
		local busy = crate
		if pending or (busy and not busy:isDead()) then
			return false
		end
		serial += 1
		local id = serial
		hideItem()
		Router.close()
		player:SetAttribute("CaseOpeningActive", true)
		local h = CaseOpening.start(player, crateTier, true, #results)
		crate = h
		local function finish()
			if serial ~= id then
				return
			end
			crate = nil
			player:SetAttribute("CaseOpeningActive", false)
			Router.open("Backpack")
			if Router.current() == "Backpack" then
				fromBundle = true
				revealed = results
				revealIndex = 1
				drawResult()
			end
		end
		if not h then
			finish()
			return true
		end
		local handle: CaseOpening.Handle = h
		task.delay(OpeningConfig.BUNDLE_ANSWER, function()
			if serial == id and not handle:reveal(results, finish) then
				finish()
			end
		end)
		return true
	end

	LobbyNet.event("ShopEvent").OnClientEvent:Connect(function(p: LobbyNet.ShopEventPayload)
		if typeof(p) ~= "table" or not pending or p.openRequest ~= pending then
			return
		end
		local id = pending
		pending = nil
		local h = crate
		local rewards = p.results
		if p.kind == "opened" and rewards and #rewards > 0 then
			local function finish(showResults: boolean)
				if serial ~= id then
					return
				end
				crate = nil
				player:SetAttribute("CaseOpeningActive", false)
				if not showResults then
					return
				end
				local back = p.ticketsBack or 0
				if back > 0 then
					LobbyHud.toast(
						`{back} Ticket{if back == 1 then "" else "s"} returned for duplicate-only cases`,
						"success"
					)
				end
				local current = Router.current()
				if current and current ~= "Backpack" then
					LobbyHud.toast(
						`{#rewards} new skin{if #rewards == 1 then "" else "s"} in your Locker`,
						"success"
					)
					return
				end
				Router.open("Backpack")
				if Router.current() == "Backpack" then
					fromBundle = false
					revealed = rewards
					revealIndex = 1
					drawResult()
				end
			end
			if h then
				local started = h:reveal(rewards, function()
					finish(true)
				end)
				if started then
					return
				end
			end
			finish(true)
		else
			if h then
				h:abort()
			end
			crate = nil
			player:SetAttribute("CaseOpeningActive", false)
			local refund = p.kind == "refunded"
			UiSfx.cue(if refund then "Confirm" else "PurchaseDenied")
			LobbyHud.toast(p.text or "Couldn't open it", if refund then "success" else "error")
		end
	end)

	LobbyKit.button(openShop, function()
		Router.open("Shop")
	end)

	LobbyKit.page({
		name = "Backpack",
		gui = gui,
		wash = child(gui, "Wash") :: Frame,
		close = child(canvas, "Close") :: GuiButton,
		focus = function()
			return first or openShop
		end,
		onOpen = function()
			isOpen = true
			render()
		end,
		onClose = function()
			isOpen = false
			showReveal(false)
			drawHaul()
			hideItem()
		end,
	})

	-- live updates while it's open (a purchase in the Shop lands here)
	task.spawn(function()
		local value = PlayerData.replica(player)
		if value then
			value.Changed:Connect(function()
				if isOpen then
					render()
					if haul.Visible then
						drawHaul()
					end
					local id = picked
					local def = id and Inventory.ITEMS[id]
					if id and def and itemPanel.Visible then
						local count = PlayerData.items(player)[id] or 0
						if count > 0 then
							showItem(def, count)
						else
							hideItem()
						end
					end
				end
			end)
		end
	end)
end

return BackpackController
