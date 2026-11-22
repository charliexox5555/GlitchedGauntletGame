--!strict
-- One screen, every device (vault/04 Tech/UI Architecture.md §5, §7).
-- A Studio-built screen holds its desktop layout in its normal properties and
-- per-device overrides as attributes on any GuiObject, which the owner can
-- edit in Studio:
--   <Family>Position (UDim2), <Family>Size (UDim2), <Family>AnchorPoint (Vector2),
--   <Family>Visible (bool), <Family>Scale (number: multiplies the Size)
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
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiLayout = {}

export type Family = "Phone" | "Tablet" | "Desktop" | "Console"

UiLayout.PHONE_SHORT_SIDE = 640 -- px: same rule as client/Util/Device
UiLayout.DESIGN_HEIGHT = 1080

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
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if GuiService:IsTenFootInterface() or (ok and preferred == Enum.PreferredInput.Gamepad) then
		return "Console"
	end
	local touch = UserInputService.TouchEnabled or studioSwitch("ForceTouchUI") == "true"
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
	local boost = if family ~= "Desktop" then s:GetAttribute(family .. "Boost") else nil
	s.Scale = (height / UiLayout.DESIGN_HEIGHT) * (if typeof(boost) == "number" then boost else 1)
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
	local usable = Vector2.new(size.X, math.max(size.Y - top, 1))
	local boost = if family ~= "Desktop" then canvas:GetAttribute(family .. "Boost") else nil
	local scale = math.min(usable.X / 1920, usable.Y / UiLayout.DESIGN_HEIGHT)
		* (if typeof(boost) == "number" then boost else 1)
	fit.Scale = scale
	local share = usable.Y / size.Y -- the canvas's part of the screen height
	canvas.AnchorPoint = Vector2.new(0.5, 1)
	canvas.Position = UDim2.fromScale(0.5, 1)
	canvas.Size = UDim2.fromScale(1 / scale, share / scale)
	canvas.ClipsDescendants = false
	for _, c in canvas:GetChildren() do
		if c:IsA("GuiObject") and c:GetAttribute("FullBleed") == true then
			-- Cover the whole screen from inside the canvas.
			c.AnchorPoint = Vector2.zero
			c.Position = UDim2.fromScale(0, -(1 - share) / share)
			c.Size = UDim2.fromScale(1, 1 / share)
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
	local boost = if family ~= "Desktop" then parent:GetAttribute(family .. "Boost") else nil
	return math.min(size.X / 1920, (size.Y - top) / UiLayout.DESIGN_HEIGHT)
		* (if typeof(boost) == "number" then boost else 1)
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

local function applyTo(o: GuiObject, family: Family)
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
	local boost = if boostOwner and family ~= "Desktop"
		then boostOwner:GetAttribute(family .. "Boost")
		else nil
	return (height / UiLayout.DESIGN_HEIGHT) * (if typeof(boost) == "number" then boost else 1)
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
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(again)
	end)
end

return UiLayout
