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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local OpeningConfig = require(ReplicatedStorage.Shared.Config.CaseOpening)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local OddsList = require(script.Parent.Parent.Util.OddsList)
local OnbHighlight = require(script.Parent.Parent.Util.OnbHighlight)
local CaseOpening = require(script.Parent.Parent.Util.CaseOpening)
local ShopRewardFx = require(script.Parent.Parent.Util.ShopRewardFx)
local LobbyHud = require(script.Parent.LobbyHud)
local Router = require(script.Parent.Parent.Util.Router)

local BackpackController = {}

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
	local sentBackpackOpen = false
	local caseCell: GuiButton? = nil

	local showItem: (def: Inventory.ItemDef, count: number) -> ()

	local function highlightGridCase()
		if
			isOpen
			and not pending
			and not itemPanel.Visible
			and not reveal.Visible
			and StateValues.get(player, "OnbCaseGift") == true
			and StateValues.get(player, "OnbCaseOpened") ~= true
			and caseCell
			and caseCell.Parent
		then
			OnbHighlight.focus(
				"Backpack",
				caseCell,
				{ tag = "OPEN!", tagPos = "insideTopRight", stroke = true, scale = 1.05 }
			)
		end
	end

	local function pop(panel: Frame)
		local sc = panel:FindFirstChild("Pop")
		if sc and sc:IsA("UIScale") then
			sc.Scale = 0.85
			UiMotion.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
	end
	local function hideItem()
		OnbHighlight.clear("Backpack")
		itemShade.Visible = false
		itemPanel.Visible = false
		contentsPanel.Visible = false
		highlightGridCase()
	end

	local function render()
		LobbyKit.clearSlots(grid)
		detail.Text = ""
		first = nil
		caseCell = nil
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
				if s.def.id == OnbConfig.FIRST_MATCH_CASE then
					caseCell = cell
				end
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
		highlightGridCase()
	end

	local function showReveal(on: boolean)
		if not on then
			OnbHighlight.clear("Backpack")
		end
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
	local function fillReveal(gun: string, line: string, tierId: string?, name: string)
		local tier = Skins.TIERS[(tierId or "Common") :: any] or Skins.TIERS.Common
		local art = child(reveal, "Art") :: ImageLabel
		local emblem = child(reveal, "Emblem") :: ImageLabel
		local pic = SkinArt.portrait(gun, line) -- the square portrait, like the case card
		art.Image = pic or ""
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
		local title = child(reveal, "Name") :: TextLabel
		title.Text = name
		title.TextColor3 = tier.color
		local plate = child(reveal, "Tier") :: Frame
		plate.BackgroundColor3 = tier.color
		for _, cap in plate:GetChildren() do
			if cap:IsA("ImageLabel") then
				cap.ImageColor3 = tier.color
			end
		end
		(child(plate, "Label") :: TextLabel).Text = tier.name
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
		if
			isCase
			and def.id == OnbConfig.FIRST_MATCH_CASE
			and StateValues.get(player, "OnbCaseGift") == true
			and StateValues.get(player, "OnbCaseOpened") ~= true
		then
			OnbHighlight.focus(
				"Backpack",
				openOne,
				{ tag = "OPEN!", tagPos = "top", stroke = false, scale = 1.07 }
			)
		else
			OnbHighlight.clear("Backpack")
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

	local function drawResult()
		local result = revealed[revealIndex]
		if not result then
			showReveal(false)
			return
		end
		fillReveal(result.gun, result.line, result.tier, result.name)
		local tier = Skins.TIERS[(result.tier or "Common") :: any] or Skins.TIERS.Common
		local kicker = reveal:FindFirstChild("Kicker")
		if kicker and kicker:IsA("TextLabel") then
			kicker.Text = if #revealed > 1
				then `NEW SKIN  ·  {revealIndex} OF {#revealed}`
				else "NEW SKIN"
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
		if
			StateValues.get(player, "OnbCaseGift") == true
			and StateValues.get(player, "OnbSkinEquipped") ~= true
		then
			OnbHighlight.focus(
				"Backpack",
				equipButton,
				{ tag = "EQUIP!", tagPos = "top", stroke = false, scale = 1.07 }
			)
		else
			OnbHighlight.clear("Backpack")
		end
	end

	local function nextResult()
		revealIndex += 1
		drawResult()
	end

	LobbyKit.button(equipButton, function()
		UiSfx.cue("Confirm")
		local wasOnbReveal = StateValues.get(player, "OnbCaseGift") == true
			and StateValues.get(player, "OnbSkinEquipped") ~= true
			and revealIndex >= #revealed
		local result = revealed[revealIndex]
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
		if wasOnbReveal then
			task.delay(0.35, function()
				if Router.current() == "Backpack" then
					Router.close()
				end
			end)
		end
	end)
	LobbyKit.button(doneButton, nextResult)

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
				if rewards and #rewards > 0 then
					player:SetAttribute("OnbNewSkinGun", rewards[1].gun)
					player:SetAttribute("OnbNewSkinLine", rewards[1].line)
				end
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
			if
				not pending
				and StateValues.get(player, "OnbCaseGift") == true
				and StateValues.get(player, "OnbCaseOpened") ~= true
			then
				if not sentBackpackOpen then
					sentBackpackOpen = true
					LobbyNet.event("OnboardingRequest"):FireServer("backpackOpened")
				end
				local count = PlayerData.items(player)[OnbConfig.FIRST_MATCH_CASE] or 0
				local def = Inventory.ITEMS[OnbConfig.FIRST_MATCH_CASE]
				if def and count > 0 then
					showItem(def, count)
				end
			end
		end,
		onClose = function()
			isOpen = false
			OnbHighlight.clear("Backpack")
			showReveal(false)
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
	StateValues.changed(player, "OnbResetSeq"):Connect(function()
		sentBackpackOpen = false
	end)
end

return BackpackController
