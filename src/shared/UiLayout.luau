--!strict
-- One screen, every device (vault/04 Tech/UI Architecture.md §5, §7).
-- A Studio-built screen holds its desktop layout in its normal properties and
-- per-device overrides as attributes on any GuiObject, which the owner can
-- edit in Studio:
--   <Family>Position (UDim2), <Family>Size (UDim2), <Family>AnchorPoint (Vector2),
--   <Family>Visible (bool), <Family>Scale (number: multiplies the Size),
--   <Family>Aspect (number, on a UIAspectRatioConstraint)
-- with Family = Phone | Tablet | Console. The desktop values are kept in
-- Base* attributes the first time an override is applied, so a device change
-- (a tablet docking a keyboard) can switch back.
-- Also: 9-slice art (DesignSliceScale, from tools/studio/modules/UiToScale)
-- scales with the screen, and retired "Fit" UIScales stay at 1.
-- Content-sized parts that keep a pixel design (list rows that size to the
-- names in them) carry a UIScale named "ScreenScale": its Scale = screen
-- height / 1080 × its <Family>Boost attribute (default 1), also on rows
-- cloned in later.
-- A content-sized HUD screen (rows and strips that size to names) keeps its
-- 1080p pixel design on a "fit canvas": a frame with FitCanvas = true and a
-- UIScale named "Fit". The Fit scale = min(W / 1920, H / 1080) × the
-- canvas's <Family>Boost, and the canvas is sized 1 / that scale, so it always
-- covers the screen exactly and its groups (positioned in Scale by
-- tools/studio/modules/UiFitCanvas) stay where they belong on any screen.
-- Client only.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local InputMode = require(script.Parent:WaitForChild("InputMode") :: ModuleScript)

local UiLayout = {}

export type Family = "Phone" | "Tablet" | "Desktop" | "Console"

UiLayout.PHONE_SHORT_SIDE = 640 -- px: same rule as client/Util/Device
UiLayout.DESIGN_HEIGHT = 1080
-- Console (a gamepad or a TV): important UI stays out of the outer 5% of each
-- edge, which some TVs crop (LihFolk: Gamepad and Console UX, "Ten-foot UI";
-- RIVALS pads its HUD corners on a controller). Fit canvases and Fit scales
-- shrink into that box; a GuiObject with SafePad = true gets the margin as
-- padding; anything else uses Console* attributes. Backdrops still bleed.
UiLayout.CONSOLE_SAFE = 0.05
-- and reads from a couch: without its own ConsoleBoost, a fit screen is this
-- much bigger on a console (inside the safe box).
UiLayout.CONSOLE_BOOST = 1.15

-- `owner`'s <Family>Boost attribute (console default CONSOLE_BOOST), or 1.
local function boostOf(owner: Instance, family: Family): number
	if family == "Desktop" then
		return 1
	end
	local v = owner:GetAttribute(family .. "Boost")
	if typeof(v) == "number" then
		return v
	end
	return if family == "Console" then UiLayout.CONSOLE_BOOST else 1
end

local PROPS = { "Position", "Size", "AnchorPoint", "Visible" }

-- Studio test switches (Workspace.GauntletState StringValues, like StateValues):
-- ForceLayout = "phone" | "tablet" | "desktop" | "console", ForceTouchUI = true.
local function studioSwitch(name: string): string?
	if not RunService:IsStudio() then
		return nil
	end
	local folder = Workspace:FindFirstChild("GauntletState")
	local v = folder and folder:FindFirstChild(name)
	if v and v:IsA("StringValue") and #v.Value > 1 then
		return string.sub(v.Value, 2) -- StateValues encodes strings as "s..." and true as "t"
	end
	return if v and v:IsA("StringValue") and v.Value == "t" then "true" else nil
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

function UiLayout.family(): Family
	local forced = studioSwitch("ForceLayout")
	if forced == "phone" then
		return "Phone"
	elseif forced == "tablet" then
		return "Tablet"
	elseif forced == "desktop" then
		return "Desktop"
	elseif forced == "console" then
		return "Console"
	end
	-- (Shared/InputMode: Settings FORCE CONTROLS wins over the real input)
	local ok, preferred = true, InputMode.preferred()
	if
		(GuiService:IsTenFootInterface() and not InputMode.isForced())
		or (ok and preferred == Enum.PreferredInput.Gamepad)
	then
		return "Console"
	end
	local touch = InputMode.touchCapable() or studioSwitch("ForceTouchUI") == "true"
	local v = viewport()
	if touch and math.min(v.X, v.Y) < UiLayout.PHONE_SHORT_SIDE then
		return "Phone"
	end
	if touch and (not ok or preferred == Enum.PreferredInput.Touch) then
		return "Tablet"
	end
	return "Desktop"
end

local function screenScale(s: UIScale, family: Family, height: number)
	s.Scale = (height / UiLayout.DESIGN_HEIGHT) * boostOf(s, family)
end

local function fitCanvas(canvas: GuiObject, family: Family, size: Vector2)
	local fit = canvas:FindFirstChild("Fit")
	if not fit or not fit:IsA("UIScale") or size.X <= 0 or size.Y <= 0 then
		return
	end
	-- AvoidTopbar: menus keep their content under Roblox's top-bar buttons
	-- (owner 2026-11-22); their FullBleed backdrops still cover the screen.
	local top = 0
	if canvas:GetAttribute("AvoidTopbar") == true then
		local inset = GuiService.TopbarInset
		top = if inset.Height > 0 then inset.Max.Y else 0
	end
	-- On a console the canvas keeps out of the TV-safe margin on every side.
	local m = if family == "Console" then UiLayout.CONSOLE_SAFE else 0
	local side, bottom = size.X * m, size.Y * m
	top = math.max(top, size.Y * m)
	local usable = Vector2.new(math.max(size.X - 2 * side, 1), math.max(size.Y - top - bottom, 1))
	local scale = math.min(usable.X / 1920, usable.Y / UiLayout.DESIGN_HEIGHT)
		* boostOf(canvas, family)
	fit.Scale = scale
	local wide = usable.X / size.X -- the canvas's part of the screen width
	local share = usable.Y / size.Y -- and of its height
	canvas.AnchorPoint = Vector2.new(0.5, 1)
	canvas.Position = UDim2.fromScale(0.5, 1 - m)
	canvas.Size = UDim2.fromScale(wide / scale, share / scale)
	canvas.ClipsDescendants = false
	for _, c in canvas:GetChildren() do
		if c:IsA("GuiObject") and c:GetAttribute("FullBleed") == true then
			-- Cover the whole screen from inside the canvas.
			c.AnchorPoint = Vector2.zero
			c.Position = UDim2.fromScale(-m / wide, -(top / size.Y) / share)
			c.Size = UDim2.fromScale(1 / wide, 1 / share)
		end
	end
end

-- Any other UIScale named "Fit" (a 1080p pixel design: a menu's 1920 x 1080
-- canvas or a HUD cluster) is owned here: Scale = min(W / 1920, (H - top) /
-- 1080) × its parent's <Family>Boost, with no floor (owner 2026-11-22: menus
-- went off phone screens because the old controllers clamped it at 0.5-0.6).
-- A parent with AvoidTopbar stays centred in the space under Roblox's
-- top-bar buttons. Old controller code that still writes Fit is overridden.
local function fitValue(fit: UIScale, family: Family, size: Vector2): number?
	local parent = fit.Parent
	if not parent or not parent:IsA("GuiObject") or size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local top = 0
	if parent:GetAttribute("AvoidTopbar") == true then
		local inset = GuiService.TopbarInset
		top = if inset.Height > 0 then inset.Max.Y else 0
	end
	local keep = if family == "Console" then 1 - 2 * UiLayout.CONSOLE_SAFE else 1
	return math.min(size.X * keep / 1920, (size.Y - top) * keep / UiLayout.DESIGN_HEIGHT)
		* boostOf(parent, family)
end

local function ownedFit(d: Instance): boolean
	local parent = d.Parent
	return d:IsA("UIScale")
		and d.Name == "Fit"
		and d:GetAttribute("Retired") ~= true
		and parent ~= nil
		and parent:GetAttribute("FitCanvas") ~= true
end

local function generalFit(fit: UIScale, family: Family, size: Vector2)
	local scale = fitValue(fit, family, size)
	if not scale then
		return
	end
	if math.abs(fit.Scale - scale) > 1e-4 then
		fit.Scale = scale
	end
	local parent = fit.Parent :: GuiObject
	if parent:GetAttribute("AvoidTopbar") == true then
		local inset = GuiService.TopbarInset
		local top = if inset.Height > 0 then inset.Max.Y else 0
		parent.AnchorPoint = Vector2.new(0.5, 0.5)
		parent.Position = UDim2.new(0.5, 0, 0, top + (size.Y - top) / 2)
	end
end

-- SafePad = true: the console margin as padding (kept on top of any padding
-- the frame already has, whose values are stashed in BasePad* attributes).
local PAD_SIDES = { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }
local function safePad(o: GuiObject, family: Family)
	local pad = o:FindFirstChildOfClass("UIPadding")
	local m = if family == "Console" then UiLayout.CONSOLE_SAFE else 0
	if not pad then
		if m == 0 then
			return
		end
		local made = Instance.new("UIPadding")
		made.Name = "SafePad"
		made.Parent = o
		pad = made
	end
	local p = pad :: UIPadding
	for _, sideName in PAD_SIDES do
		local key = "BasePad" .. sideName
		local base = p:GetAttribute(key)
		if typeof(base) ~= "UDim" then
			base = (p :: any)[sideName]
			p:SetAttribute(key, base)
		end
		local b = base :: UDim;
		(p :: any)[sideName] = UDim.new(b.Scale + m, b.Offset)
	end
end

-- <Family>Aspect on a UIAspectRatioConstraint: its AspectRatio on that
-- device (a banner narrower and taller on a phone); BaseAspect keeps the
-- authored one.
local function aspectTo(c: UIAspectRatioConstraint, family: Family)
	local v = if family ~= "Desktop" then c:GetAttribute(family .. "Aspect") else nil
	local base = c:GetAttribute("BaseAspect")
	if typeof(v) == "number" and v > 0 then
		if typeof(base) ~= "number" then
			c:SetAttribute("BaseAspect", c.AspectRatio)
		end
		c.AspectRatio = v
	elseif typeof(base) == "number" then
		c.AspectRatio = base
	end
end

local function applyTo(o: GuiObject, family: Family)
	if o:GetAttribute("SafePad") == true then
		safePad(o, family)
	end
	for _, prop in PROPS do
		local override = if family ~= "Desktop" then o:GetAttribute(family .. prop) else nil
		local base = o:GetAttribute("Base" .. prop)
		if override ~= nil then
			if base == nil then
				o:SetAttribute("Base" .. prop, (o :: any)[prop])
			end
			pcall(function()
				(o :: any)[prop] = override
			end)
		elseif base ~= nil then
			pcall(function()
				(o :: any)[prop] = base
			end)
		end
	end
	-- <Family>Scale multiplies the (base or overridden) size.
	local scale = if family ~= "Desktop" then o:GetAttribute(family .. "Scale") else nil
	local unscaled = o:GetAttribute("UnscaledSize")
	if typeof(scale) == "number" then
		local size = if o:GetAttribute(family .. "Size") ~= nil
			then o.Size
			elseif typeof(unscaled) == "UDim2" then unscaled
			else o.Size
		if typeof(unscaled) ~= "UDim2" then
			o:SetAttribute("UnscaledSize", size)
		end
		o.Size = UDim2.new(
			size.X.Scale * scale,
			size.X.Offset * scale,
			size.Y.Scale * scale,
			size.Y.Offset * scale
		)
	elseif typeof(unscaled) == "UDim2" and o:GetAttribute(family .. "Size") == nil then
		o.Size = unscaled
		o:SetAttribute("UnscaledSize", nil)
	end
end

-- The Scale for a ScreenScale UIScale in `gui` now.
function UiLayout.screenScaleFor(gui: Instance, boostOwner: Instance?): number
	local family = UiLayout.family()
	local height = if gui:IsA("ScreenGui") then gui.AbsoluteSize.Y else viewport().Y
	return (height / UiLayout.DESIGN_HEIGHT)
		* (if boostOwner then boostOf(boostOwner, family) else 1)
end

-- Applies `family`'s overrides to every GuiObject under `root`, as if the
-- screen were `height` px tall (tools/studio/modules/UiDeviceSheet previews).
function UiLayout.applyAs(root: Instance, family: Family, height: number)
	local sliceK = math.clamp(height / UiLayout.DESIGN_HEIGHT, 0.3, 2)
	local viewSize = if root:IsA("GuiObject")
		then root.AbsoluteSize
		else Vector2.new(height * 16 / 9, height)
	if root:IsA("GuiObject") then
		local uiScale = root:FindFirstChildOfClass("UIScale")
		if uiScale and uiScale.Scale > 0 then
			viewSize /= uiScale.Scale -- the preview's own zoom
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			applyTo(d, family)
			if d:GetAttribute("FitCanvas") == true then
				fitCanvas(d, family, viewSize)
			end
			local design = d:GetAttribute("DesignSliceScale")
			if typeof(design) == "number" and (d:IsA("ImageLabel") or d:IsA("ImageButton")) then
				d.SliceScale = design * sliceK
			end
		elseif d:IsA("UIAspectRatioConstraint") then
			aspectTo(d, family)
		elseif d:IsA("UIScale") and d:GetAttribute("Retired") == true then
			d.Scale = 1
		elseif d:IsA("UIScale") and d.Name == "ScreenScale" then
			screenScale(d, family, height)
		elseif ownedFit(d) then
			generalFit(d :: UIScale, family, viewSize)
		end
	end
end

-- Applies the current family's overrides to every GuiObject in `gui`.
function UiLayout.apply(gui: Instance)
	local family = UiLayout.family()
	local height = if gui:IsA("LayerCollector") and gui:IsA("ScreenGui")
		then gui.AbsoluteSize.Y
		else viewport().Y
	local sliceK = math.clamp(height / UiLayout.DESIGN_HEIGHT, 0.3, 2)
	local viewSize = if gui:IsA("ScreenGui") then gui.AbsoluteSize else viewport()
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			applyTo(d, family)
			if d:GetAttribute("FitCanvas") == true then
				fitCanvas(d, family, viewSize)
			end
			local design = d:GetAttribute("DesignSliceScale")
			if typeof(design) == "number" and (d:IsA("ImageLabel") or d:IsA("ImageButton")) then
				d.SliceScale = design * sliceK
			end
		elseif d:IsA("UIAspectRatioConstraint") then
			aspectTo(d, family)
		elseif d:IsA("UIScale") and d:GetAttribute("Retired") == true then
			d.Scale = 1
		elseif d:IsA("UIScale") and d.Name == "ScreenScale" then
			screenScale(d, family, height)
		elseif ownedFit(d) then
			generalFit(d :: UIScale, family, viewSize)
		end
	end
	gui:SetAttribute("LayoutFamily", family)
end

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Applies now and again when the screen size or the preferred input changes.
-- Retired Fit scales are held at 1 even if an old controller writes them.
function UiLayout.watch(gui: ScreenGui)
	UiLayout.apply(gui)
	if watched[gui] then
		return
	end
	watched[gui] = true
	for _, d in gui:GetDescendants() do
		if d:IsA("UIScale") and d:GetAttribute("Retired") == true then
			d:GetPropertyChangedSignal("Scale"):Connect(function()
				if d.Scale ~= 1 then
					d.Scale = 1
				end
			end)
		elseif ownedFit(d) then
			local fit = d :: UIScale
			fit:GetPropertyChangedSignal("Scale"):Connect(function()
				if gui.Parent then
					generalFit(fit, UiLayout.family(), gui.AbsoluteSize)
				end
			end)
		end
	end
	local pending = false
	local function again()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			if gui.Parent then
				UiLayout.apply(gui)
			end
		end)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(again)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(again)
	-- Rows cloned in later (a ScreenScale inside them) get the current scale.
	gui.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("UIScale") and d.Name == "ScreenScale" then
			screenScale(d, UiLayout.family(), gui.AbsoluteSize.Y)
		end
	end)
	InputMode.changed:Connect(again)
end

return UiLayout
