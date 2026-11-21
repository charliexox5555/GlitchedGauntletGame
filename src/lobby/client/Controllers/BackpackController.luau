--!strict
-- The Backpack (vault/01 Design/Inventory and Crates.md → Backpack): every stack the player
-- holds, from the server-published inventory (Shared/PlayerData). Studio-built
-- StarterGui.Backpack + UiTemplates.Lobby.BackpackCell (tools/studio/BuildBackpack.luau),
-- opened from the bottom bar's BACKPACK (it replaced the Battle Pass for the first release).
-- Opening (2026-11-20): pick a case stack, OPEN CASE sends ShopRequest("openCase")
-- (Services/ShopService rolls and grants a skin you don't own); the reveal panel
-- shows it with its tier, EQUIP puts it on through the Locker's LockerRequest.
-- The cinematic crate opening replaces the reveal's entrance later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local ItemIcons = require(ReplicatedStorage.Shared.ItemIcons)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
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
	local folder = ReplicatedStorage:WaitForChild("UiTemplates", 15)
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
	local openBtn = child(canvas, "OpenCase") :: GuiButton
	local shade = child(canvas, "RevealShade") :: Frame
	local reveal = child(canvas, "Reveal") :: Frame
	local revealPop = child(reveal, "Pop") :: UIScale
	local first: GuiObject? = nil
	local isOpen = false
	local picked: string? = nil -- the case item id OPEN CASE will open
	local opening = false -- one request at a time (cleared on its answer, or after 8 s)
	local lastOpen = -math.huge -- answers within LATE_OK of an opening are ours, even slow ones
	local LATE_OK = 30
	local got: { gun: string, line: string }? = nil

	local function render()
		LobbyKit.clearSlots(grid)
		detail.Text = ""
		first = nil
		local list = stacks()
		-- keep the pick while that case is still held
		local still = false
		for _, s in list do
			if s.def.id == picked then
				still = true
			end
		end
		if not still then
			picked = nil
		end
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
				local id = s.def.id
				local function pick()
					detail.Text = name
					if s.def.kind == "Case" then
						picked = id
					end
					openBtn.Visible = picked ~= nil
				end
				cell.MouseEnter:Connect(function()
					detail.Text = name
				end)
				cell.SelectionGained:Connect(function()
					detail.Text = name
				end)
				LobbyKit.button(cell, pick)
				if id == picked then
					detail.Text = name
				end
			end
		end
		empty.Visible = #list == 0
		grid.Visible = true
		openBtn.Visible = picked ~= nil
	end

	local function showReveal(on: boolean)
		shade.Visible = on
		reveal.Visible = on
		if on then
			revealPop.Scale = 0.8
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
		local pic = ItemIcons.get(gun, line)
		art.Image = pic or ""
		art.Visible = pic ~= nil
		emblem.Image = Locker.EMBLEMS[line] or ""
		emblem.ImageColor3 = Locker.COLORS[line] or tier.color
		emblem.Visible = pic == nil
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

	LobbyKit.button(openBtn, function()
		if opening or not picked then
			return
		end
		opening = true
		lastOpen = os.clock()
		LobbyNet.event("ShopRequest"):FireServer("openCase", picked)
		task.delay(8, function() -- no answer: let them try again
			opening = false
		end)
	end)
	LobbyKit.button(child(reveal, "Equip") :: GuiButton, function()
		local g2 = got
		if g2 then
			LobbyNet.event("LockerRequest"):FireServer("equip", g2.gun, g2.line)
			-- say so only once the server's equipped list shows it
			task.spawn(function()
				local t = os.clock()
				while os.clock() - t < 4 do
					if Locker.equipped(player)[g2.gun] == g2.line then
						LobbyHud.toast("Equipped in your Locker", "success")
						return
					end
					task.wait(0.2)
				end
				LobbyHud.toast("Couldn't equip it, try in the Locker", "error")
			end)
		end
		showReveal(false)
	end)
	LobbyKit.button(child(reveal, "Done") :: GuiButton, function()
		showReveal(false)
	end)
	LobbyNet.event("ShopEvent").OnClientEvent:Connect(function(p: LobbyNet.ShopEventPayload)
		if typeof(p) ~= "table" then
			return
		end
		local ours = os.clock() - lastOpen < LATE_OK
		if not ours then
			return -- not an opening started here
		end
		if p.kind == "opened" then
			opening = false
			lastOpen = -math.huge
			if typeof(p.gun) == "string" and typeof(p.line) == "string" then
				got = { gun = p.gun, line = p.line }
				fillReveal(p.gun, p.line, p.tier, p.text or "")
			else
				got = nil
			end
			UiSfx.cue("MatchFound")
			showReveal(true)
		elseif p.kind == "refunded" then
			opening = false
			lastOpen = -math.huge
			UiSfx.cue("Confirm")
			LobbyHud.toast(p.text or "Coins back", "success")
		elseif p.kind == "failed" then
			opening = false
			lastOpen = -math.huge
			UiSfx.cue("PurchaseDenied")
			LobbyHud.toast(p.text or "Couldn't open it", "error")
		end
	end)

	LobbyKit.button(openShop, function()
		Router.open("Shop")
	end)

	LobbyKit.page({
		name = "Backpack",
		gui = gui,
		canvas = canvas,
		design = Vector2.new(1920, 1080),
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
		end,
		-- phones: the header and the grid fill the screen
		phone = { region = Rect.new(440, 100, 1480, 960) },
	})

	-- live updates while it's open (a purchase in the Shop lands here)
	task.spawn(function()
		local value = PlayerData.replica(player)
		if value then
			value.Changed:Connect(function()
				if isOpen then
					render()
				end
			end)
		end
	end)
end

return BackpackController
