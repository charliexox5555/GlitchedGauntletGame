--!strict
-- The match HUD's phone arrangement (vault/01 Design/Match HUD.md → Phone;
-- LihFolk: HUD Design, Responsive UI for Phone Tablet Console and PC, Safe
-- Areas and Insets, Case Study - Phone UI Overhaul). On a phone (Util/Device:
-- short side under 640 px) the 1080p clusters would scale to about 0.29, so
-- here they get their own scale and places instead:
--   * status along the top: the score bar under Roblox's top bar, health at
--     the top left under it, the kill feed under health;
--   * the bottom-left quarter stays clear for the thumbstick;
--   * the bottom-right quarter is the game's touch layer (HudController: FIRE,
--     AIM, R, SLIDE, SWAP, RUN, the ability arc) and Roblox's jump button, so
--     ammo joins that combat cluster in its free strip left of SLIDE;
--   * the Q / E / T slot faces hide: the touch layer's ability buttons show
--     the same icons and cooldowns ("hide, don't shrink"); their hint stays.
-- Desktop and tablets (short side 640+) keep the 1080p layout. Nothing here
-- decides gameplay; it only moves and scales what the other controllers built.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Util.Device)
local Ui = require(script.Parent.Parent.Util.Ui)

local PhoneHudController = {}

local player = Players.LocalPlayer

-- Design numbers (px at the reference size; see the vault note).
local MARGIN = 12
local GAP = 8
-- The bar sits 4 px under Roblox's top bar and status 6 px under it, so health
-- and the kill feed end above the thumbstick's quarter on short phones.
local BAR_TOP, BAR_GAP = 4, 6
local BAR_SIZE = Device.BAR_SIZE -- MatchHudController's top bar
local HEALTH_SIZE = Vector2.new(420, 120)
local FEED_SCALE = 0.8 -- the kill feed, relative to the HUD scale
local FEED_ROWS, FEED_ROW = 3, 52 -- rows shown on a phone; Util/KillFeed row + gap
-- HudController's touch layer: 480 x 480 design px scaled by height / 760
-- (at least 0.62). Its free bottom strip runs 250-480 px from the right edge,
-- up to 110 px from the bottom (left of SLIDE, under RUN).
local AMMO_RIGHT, AMMO_LEFT, AMMO_STRIP_H = 250, 480, 110
-- On a compact screen the ammo panel keeps only its right part (the count
-- and the mag size), so it can be drawn bigger in the strip.
local AMMO_PANEL = Vector2.new(220, 120)

local function child(parent: Instance?, name: string): GuiObject?
	local c = if parent then parent:FindFirstChild(name, true) else nil
	return if c and c:IsA("GuiObject") then c else nil
end

local function topInset(): number
	local inset = GuiService.TopbarInset
	return if inset.Height > 0 then inset.Max.Y else MARGIN
end

local function arrange()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local k = Device.phoneHudScale()
	local top = topInset()

	-- Score bar (MatchHud is a core-UI safe gui: y 0 is under Roblox's bar).
	local bar = child(pg:FindFirstChild("MatchHud"), "TopBar")
	local kBar = Device.phoneBarScale()
	if bar then
		-- During the draft the cards need the height: the bar steps aside and
		-- the draft's footer shows the clock.
		local drafting = pg:FindFirstChild("Draft")
		local back = drafting and drafting:FindFirstChild("Backdrop")
		local hud = bar:FindFirstAncestorWhichIsA("ScreenGui")
		if hud then
			hud.Enabled = not (back and back:IsA("GuiObject") and back.Visible)
		end
		local left, right = Device.phoneBarSpan()
		Ui.override(bar, kBar)
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.fromOffset(math.floor((left + right) / 2), BAR_TOP)
	end
	local below = top + BAR_TOP + BAR_SIZE.Y * kBar + BAR_GAP -- device-safe y under the bar

	local combat = pg:FindFirstChild("CombatHud")
	-- Health: top left, under the bar; its HEALTH caption hides (the number and
	-- the bar say it).
	local health = child(combat, "Health")
	local healthBottom = below
	if health then
		Ui.override(health, k)
		health.AnchorPoint = Vector2.new(0, 0)
		health.Position = UDim2.fromOffset(MARGIN, below)
		healthBottom = below + HEALTH_SIZE.Y * k
		local caption = health:FindFirstChild("Caption")
		if caption and caption:IsA("GuiObject") then
			caption.Visible = false
		end
	end
	-- Kill feed: beside health, clipped to its newest 3 rows (the top right
	-- belongs to the touch layer's R / SWAP buttons and the ability arc, the
	-- left below health to the thumbstick).
	local feed = child(combat, "KillFeed")
	if feed then
		Ui.override(feed, k * FEED_SCALE)
		feed.AnchorPoint = Vector2.new(0, 0)
		feed.Position = UDim2.fromOffset(MARGIN + HEALTH_SIZE.X * k + GAP, below)
		feed.Size = UDim2.fromOffset(feed.Size.X.Offset, FEED_ROWS * FEED_ROW)
		feed.ClipsDescendants = true
	end
	local _ = healthBottom
	-- ELIMINATED: a little above the middle, out of the thumb quarters.
	local banner = child(combat, "KillBanner")
	if banner then
		Ui.override(banner, k)
		banner.Position = UDim2.fromScale(0.5, 0.5)
	end

	-- Ammo: in the touch layer's free strip when there is one.
	local ammo = child(combat, "Ammo")
	local layer = child(pg:FindFirstChild("TouchControls"), "Layer")
	if ammo then
		if layer then
			local kt = Device.touchScale()
			local width = (AMMO_LEFT - AMMO_RIGHT) * kt
			local ka = math.min(width / AMMO_PANEL.X, (AMMO_STRIP_H * kt) / AMMO_PANEL.Y)
			Ui.override(ammo, ka)
			ammo.AnchorPoint = Vector2.new(1, 1)
			ammo.Position = UDim2.new(1, -AMMO_RIGHT * kt, 1, -GAP)
		else
			Ui.override(ammo, k)
			ammo.AnchorPoint = Vector2.new(1, 1)
			ammo.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
		end
		local back = ammo:FindFirstChild("Back")
		if back and back:IsA("GuiObject") then
			back.Position = UDim2.fromOffset(420 - AMMO_PANEL.X, 80)
			back.Size = UDim2.fromOffset(AMMO_PANEL.X, AMMO_PANEL.Y)
			local shadow = ammo:FindFirstChild("BackShadow")
			if shadow and shadow:IsA("GuiObject") then
				shadow.Position = back.Position
				shadow.Size = back.Size
			end
		end
		-- Only the count and the mag size: the gun picture and name hide.
		for _, name in { "Gun", "WeaponName" } do
			local g = ammo:FindFirstChild(name)
			if g and g:IsA("GuiObject") then
				g.Visible = false
			end
		end
	end

	-- Q / E / T faces hide when the touch layer has the ability buttons.
	local slots = child(pg:FindFirstChild("ModHud"), "Slots")
	if slots and layer then
		for _, c in slots:GetChildren() do
			local body = if string.sub(c.Name, 1, 4) == "Slot"
				then c:FindFirstChild("Body")
				else nil
			if body and body:IsA("GuiObject") then
				body.Visible = false -- ModHud toggles the slot root, not its body
			end
		end
	end
end

function PhoneHudController.start()
	if not Device.compact() then
		return
	end
	-- The other controllers build their guis in their own start(); wait for them.
	local pg = player:WaitForChild("PlayerGui")
	for _, name in { "MatchHud", "CombatHud", "ModHud" } do
		pg:WaitForChild(name, 10)
	end
	task.wait(0.5)
	arrange()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(arrange)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(arrange)
	local draft = pg:FindFirstChild("Draft")
	local back = draft and draft:FindFirstChild("Backdrop")
	if back and back:IsA("GuiObject") then
		back:GetPropertyChangedSignal("Visible"):Connect(arrange)
	end
end

return PhoneHudController
