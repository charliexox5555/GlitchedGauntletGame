--!strict
-- Every lobby button sounds the same way, without each screen wiring it
-- (owner 2026-11-20: consistent UI sounds, not over the top; vault/02 Art/UI
-- Polish Pass.md → Sounds). Watches PlayerGui for GuiButtons:
--   * a click on Activated: "Click", or "Back" for buttons named Close / Back,
--     or the cue named by the button's UiSound attribute ("none" = silent);
--     skipped when the screen's own code just played a specific cue
--     (UiSfx.cue: Confirm, Denied, Tab, toggles ...);
--   * a faint hover tick only on big items (tiles, gun cards, shop cells:
--     at least 1% of the screen and not a full-screen catcher), or any button
--     with UiHover = true.
-- RIVALS keeps UI sound to a click, an error and a few transitions; so do we.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiSfx = require(ReplicatedStorage.Shared.UiSfx)

local UiSoundController = {}

local BIG = 0.01 -- of the screen's area: a hover tick from here
local HUGE = 0.3 -- full-screen click catchers stay silent
local hooked: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function screenArea(b: GuiButton): number
	local cam = workspace.CurrentCamera
	local v = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	return (b.AbsoluteSize.X * b.AbsoluteSize.Y) / math.max(v.X * v.Y, 1)
end

local function clickCue(b: GuiButton): string?
	local named = b:GetAttribute("UiSound")
	if type(named) == "string" then
		return if named == "none" or named == "" then nil else named
	end
	if b.Name == "Close" or b.Name == "Back" or b.Name == "BackButton" then
		return "Back"
	end
	return "Click"
end

local function hook(b: GuiButton)
	if hooked[b] then
		return
	end
	hooked[b] = true
	b.Activated:Connect(function()
		-- let the screen's own handler run first; if it played a cue, stay quiet
		task.defer(function()
			if UiSfx.claimed() then
				return
			end
			local c = clickCue(b)
			if c then
				UiSfx.play(c)
			end
		end)
	end)
	b.MouseEnter:Connect(function()
		local forced = b:GetAttribute("UiHover")
		if forced == false or b:GetAttribute("UiSound") == "none" then
			return
		end
		local a = screenArea(b)
		if forced == true or (a >= BIG and a <= HUGE) then
			UiSfx.play("HoverBig")
		end
	end)
end

function UiSoundController.init()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in pg:GetDescendants() do
		if d:IsA("GuiButton") then
			hook(d)
		end
	end
	pg.DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") then
			hook(d)
		end
	end)
	UiSfx.preload()
end

return UiSoundController
