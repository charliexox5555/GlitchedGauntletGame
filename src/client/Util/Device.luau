--!strict
-- Layout family for the match UI (vault/01 Design/Match HUD.md → Phone; LihFolk:
-- Responsive UI for Phone Tablet Console and PC). Same rule as the Lobby:
--   "phone":   the screen's short side is under 640 px (iPhone SE 667 x 375,
--              tall phones 844 x 390 / 932 x 430);
--   "desktop": everything else, tablets in landscape included (1024 x 768).
-- Classified by size, not input (TouchEnabled doesn't mean phone). Decided
-- once from the first real viewport (the camera reports a placeholder at
-- first). Studio test hook: Workspace attribute ForceLayout = "phone" | "desktop".

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Device = {}

export type Family = "desktop" | "phone"

Device.PHONE_SHORT_SIDE = 640

local decided: Family? = nil

function Device.viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

function Device.family(): Family
	if decided then
		return decided
	end
	local family: Family
	local forced = if RunService:IsStudio() then Workspace:GetAttribute("ForceLayout") else nil
	if forced == "phone" or forced == "desktop" then
		family = forced :: Family
	else
		local started = os.clock()
		while Device.viewport().X <= 2 and os.clock() - started < 5 do
			task.wait()
		end
		local v = Device.viewport()
		family = if math.min(v.X, v.Y) < Device.PHONE_SHORT_SIDE then "phone" else "desktop"
	end
	decided = family
	return family
end

function Device.isPhone(): boolean
	return Device.family() == "phone"
end

-- The phone HUD scale (viewport height / 720, 0.48-0.7) and the score bar's
-- (also no wider than the screen less 12 px margins). Shared by the phone
-- HUD and the phone draft so the draft starts right under the bar.
Device.BAR_SIZE = Vector2.new(1100, 110)

function Device.phoneHudScale(): number
	return math.clamp(Device.viewport().Y / 720, 0.48, 0.7)
end

-- HudController's touch layer (480 x 480 design px, bottom right) scales by
-- height / 760, at least 0.62; it exists on touch devices (and in Studio with
-- ForceTouchUI). Its ability arc reaches 216 design px in from the right edge.
Device.TOUCH_DESIGN_HEIGHT = 760
Device.TOUCH_MIN = 0.62
Device.ARC_REACH = 216

function Device.hasTouchLayer(): boolean
	return UserInputService.TouchEnabled
		or (RunService:IsStudio() and Workspace:GetAttribute("ForceTouchUI") == true)
end

function Device.touchScale(): number
	return math.clamp(Device.viewport().Y / Device.TOUCH_DESIGN_HEIGHT, Device.TOUCH_MIN, 1)
end

-- The free span for the score bar on a compact screen: left of the touch
-- layer's ability arc (which reaches up beside the bar on short phones).
function Device.phoneBarSpan(): (number, number)
	local right = Device.viewport().X - 12
	if Device.hasTouchLayer() then
		right = Device.viewport().X - (Device.ARC_REACH * Device.touchScale() + 8)
	end
	return 12, right
end

function Device.phoneBarScale(): number
	local left, right = Device.phoneBarSpan()
	return math.min(Device.phoneHudScale(), (right - left) / Device.BAR_SIZE.X)
end

function Device.touch(): boolean
	return UserInputService.TouchEnabled
end

-- The touch arrangement (Controllers/PhoneHudController, the draft's scroller
-- and footer): phones, and touch-only tablets, whose bottom corners are thumb
-- zones too. Studio: Workspace ForceLayout = "phone" or ForceTouchUI.
function Device.compact(): boolean
	if Device.isPhone() then
		return true
	end
	if RunService:IsStudio() and Workspace:GetAttribute("ForceTouchUI") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Device
