--!strict
-- The Backpack (vault/01 Design/Inventory and Crates.md → Backpack): every stack the player
-- holds, from the server-published inventory (Shared/PlayerData). Studio-built
-- StarterGui.Backpack + UiTemplates.Lobby.BackpackCell (tools/studio/BuildBackpack.luau),
-- opened from the bottom bar's BACKPACK (it replaced the Battle Pass for the first release).
-- Read only: nothing here talks to the server. Opening cases comes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
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
	local first: GuiObject? = nil
	local isOpen = false

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
				cell.MouseEnter:Connect(function()
					detail.Text = name
				end)
				cell.SelectionGained:Connect(function()
					detail.Text = name
				end)
				LobbyKit.button(cell, function()
					detail.Text = name
				end)
			end
		end
		empty.Visible = #list == 0
		grid.Visible = true
	end

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
