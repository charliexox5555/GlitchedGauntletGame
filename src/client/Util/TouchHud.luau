--!strict
-- The touch controls' screen (UI.Match.Touch, Studio-built by
-- tools/studio/BuildTouchScreen.luau; vault/02 Art/UI Mobile Controls.md).
-- Shared by TouchController (input), ModHudController (the Mod buttons'
-- icons and cooldowns) and BottomHud (the weapon slots and ammo readout), so
-- none of them needs to require another controller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local TouchHud = {}

export type LoadoutEntry = { slot: string, id: string?, ammo: number, mag: number }

local RED = Color3.fromHex("FF4D5E")
local WHITE = Color3.fromHex("F4F6F9")
local HELD_FACE = 0.72 -- the held slot's face: a light plate
local REST_FACE = 0.45

-- Touch controls show on a touch-first device, and in Studio when the
-- Workspace attribute ForceTouchUI is ticked (to try the layout on a PC).
function TouchHud.enabled(): boolean
	if RunService:IsStudio() and StateValues.get(Workspace, "ForceTouchUI") == true then
		return true
	end
	if not UserInputService.TouchEnabled then
		return false
	end
	-- A tablet with a keyboard or gamepad plugged in prefers that instead.
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	return not ok or preferred == Enum.PreferredInput.Touch
end

function TouchHud.screen(): ScreenGui?
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = pg and pg:FindFirstChild("Touch")
	return if gui and gui:IsA("ScreenGui") then gui else nil
end

-- The screen is up (touch on and the screen mounted).
function TouchHud.active(): boolean
	local gui = TouchHud.screen()
	return gui ~= nil and gui.Enabled
end

-- A named element anywhere in the screen (buttons are unique by name).
function TouchHud.find(name: string): GuiObject?
	local gui = TouchHud.screen()
	local found = gui and gui:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found else nil
end

-- Loadout + ammo -----------------------------------------------------------------

local loadout: { LoadoutEntry } = {}
local equipped: string? = nil
local ammoNow, magNow, reserveNow = 0, 0, nil :: number?

local function face(button: GuiObject): GuiObject?
	local f = button:FindFirstChild("Face")
	return if f and f:IsA("GuiObject") then f else nil
end

local function draw()
	local present: { [string]: LoadoutEntry } = {}
	for _, e in loadout do
		present[e.slot] = e
	end
	local heldButton: GuiObject? = nil
	for _, slot in { "Primary", "Secondary", "Melee" } do
		local b = TouchHud.find(slot .. "Button")
		local f = b and face(b)
		if b and f then
			local e = present[slot]
			b.Visible = e ~= nil
			if e then
				local held = slot == equipped
				f.BackgroundColor3 = if held then WHITE else Color3.fromHex("10141B")
				f.BackgroundTransparency = if held then HELD_FACE else REST_FACE
				local gun = f:FindFirstChild("Gun")
				if gun and gun:IsA("ImageLabel") then
					gun.Image = if e.id then Theme.GUN[e.id] or "" else ""
				end
				local count = f:FindFirstChild("Count")
				if count and count:IsA("TextLabel") then
					-- The held gun's count is in the readout under it.
					count.Text = if not held and e.mag > 0 then tostring(e.ammo) else ""
					count.TextColor3 = if e.mag > 0 and e.ammo == 0 then RED else WHITE
				end
				if held then
					heldButton = b
				end
			end
		end
	end
	local chip = TouchHud.find("AmmoReadout")
	if chip then
		local show = heldButton ~= nil and magNow > 0
		chip.Visible = show
		if show and heldButton then
			chip.Position = UDim2.fromScale(heldButton.Position.X.Scale, chip.Position.Y.Scale)
			local mag = chip:FindFirstChild("Mag")
			local reserve = chip:FindFirstChild("Reserve")
			if mag and mag:IsA("TextLabel") then
				mag.Text = tostring(ammoNow)
				mag.TextColor3 = if ammoNow == 0
					then RED
					elseif ammoNow <= magNow * 0.25 then Color3.fromHex("FFC83D")
					else WHITE
			end
			if reserve and reserve:IsA("TextLabel") then
				reserve.Text = "/" .. (if reserveNow == nil then "∞" else tostring(reserveNow))
			end
			local bar = chip:FindFirstChild("MagBar")
			local fill = bar and bar:FindFirstChild("Fill")
			if fill and fill:IsA("GuiObject") then
				fill.Size = UDim2.fromScale(math.clamp(ammoNow / magNow, 0, 1), 1)
			end
		end
	end
end

function TouchHud.setLoadout(entries: { LoadoutEntry }, held: string?)
	loadout, equipped = entries, held
	if TouchHud.active() then
		draw()
	end
end

function TouchHud.setAmmo(ammo: number, magSize: number, reserve: number?)
	ammoNow, magNow, reserveNow = ammo, magSize, reserve
	if TouchHud.active() then
		draw()
	end
end

-- Health: the simple bar from the mockup, bottom-left (white fill, red when
-- low, a cyan line for shield). Called every frame; writes only on change.
local LOW = 0.35
local shownHealth = ""
function TouchHud.setHealth(health: number, max: number, shield: number)
	if not TouchHud.active() then
		return
	end
	local frac = if max > 0 then math.clamp(health / max, 0, 1) else 0
	local key = string.format("%d|%.3f|%.3f", math.ceil(health), frac, shield)
	if key == shownHealth then
		return
	end
	shownHealth = key
	local bar = TouchHud.find("Health")
	if not bar then
		return
	end
	local fill = bar:FindFirstChild("Fill")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(0.68 * frac, fill.Size.Y.Scale)
		fill.BackgroundColor3 = if frac < LOW then RED else WHITE
	end
	local shieldLine = bar:FindFirstChild("Shield")
	if shieldLine and shieldLine:IsA("GuiObject") then
		local s = if max > 0 then math.clamp(shield / max, 0, 1) else 0
		shieldLine.Visible = s > 0
		shieldLine.Size = UDim2.fromScale(0.68 * s, shieldLine.Size.Y.Scale)
	end
	local value = bar:FindFirstChild("Value")
	if value and value:IsA("TextLabel") then
		value.Text = tostring(math.max(0, math.ceil(health)))
		value.TextColor3 = if frac < LOW then RED else WHITE
	end
end

-- Redraws from the last data (the screen just turned on).
function TouchHud.refresh()
	draw()
end

return TouchHud
