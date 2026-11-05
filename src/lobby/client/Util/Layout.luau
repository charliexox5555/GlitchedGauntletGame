--!strict
-- Lobby layout family and clamped device scale (LihFolk: Responsive UI for
-- Phone Tablet Console and PC; LihFolk UI Spec; Safe Areas and Insets).
--   "desktop": designed at 1920 x 1080 (the Figma frames).
--   "phone":   short side under 640 px (phones, and small screens such as
--              1024 x 600 where the desktop menu would need taps under 44 px),
--              its own compact arrangement on an 800 x 420 canvas (fits
--              667 x 375 with the Roblox top bar).
-- Every cluster gets ONE "Fit" UIScale from here (pops use a separate child
-- UIScale, Fx "PopScale"), and a text floor keeps drawn text at 12 px or more.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Layout = {}

export type Family = "desktop" | "phone"
export type Kind = "hud" | "menu" | "found"

Layout.MIN_TEXT_PX = 12
Layout.PHONE_SHORT_SIDE = 640
Layout.PHONE_CANVAS = Vector2.new(800, 420)

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

-- The camera reports a placeholder size for the first frames, so the family
-- is decided once, from the first real viewport, and kept for the session
-- (controllers build their arrangement from it; a phone never changes family).
local decided: Family? = nil

-- Classified by size, not input: TouchEnabled doesn't mean "phone", and a tiny
-- desktop window is better served by the phone arrangement too.
function Layout.family(): Family
	if decided then
		return decided
	end
	local family: Family
	-- Studio test hook: workspace attribute LobbyForceLayout = "phone" | "desktop".
	local forced = if RunService:IsStudio() then workspace:GetAttribute("LobbyForceLayout") else nil
	if forced == "phone" or forced == "desktop" then
		family = forced :: Family
	else
		local started = os.clock()
		while viewport().X <= 2 and os.clock() - started < 5 do
			task.wait()
		end
		local v = viewport()
		family = if math.min(v.X, v.Y) < Layout.PHONE_SHORT_SIDE then "phone" else "desktop"
	end
	decided = family
	return family
end

function Layout.isPhone(): boolean
	return Layout.family() == "phone"
end

function Layout.touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- The scale for a cluster of `kind` in a gui whose safe area is `size`.
function Layout.scale(kind: Kind, size: Vector2): number
	if size.X <= 0 or size.Y <= 0 then
		size = viewport()
	end
	if Layout.isPhone() then
		if kind == "found" then
			-- The MATCH FOUND row (1920 x 520 design) only needs its middle 1300 x 560.
			return math.clamp(math.min(size.X / 1300, size.Y / 560), 0.4, 1)
		end
		local c = Layout.PHONE_CANVAS
		return math.clamp(math.min(size.X / c.X, size.Y / c.Y), 0.55, 1.2)
	end
	if kind == "menu" then
		-- Menus use about 1760 x 980 of their 1920 x 1080 canvas.
		return math.clamp(math.min(size.X / 1760, size.Y / 980), 0.55, 1.25)
	end
	-- Floor 0.76: the smallest HUD button (60 design px) still draws 44+ px.
	return math.clamp(math.min(size.X / 1920, size.Y / 1080), 0.76, 1.4)
end

-- Raise small text so it draws at MIN_TEXT_PX or more at `scale`. The authored
-- size is kept in a "BaseTextSize" attribute so rescaling can lower it again.
function Layout.floorText(root: Instance, scale: number)
	-- Nested UIScales (a team row drawn at 0.7) shrink text further, so the
	-- floor is worked out per label from every UIScale between it and `root`.
	local function nested(d: Instance): number
		local s = 1
		local cur = d.Parent
		while cur and cur ~= root do
			for _, c in cur:GetChildren() do
				if c:IsA("UIScale") and c.Name ~= "PopScale" then
					s *= c.Scale
				end
			end
			cur = cur.Parent
		end
		return s
	end
	local function apply(d: Instance)
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			local floor = math.ceil(Layout.MIN_TEXT_PX / math.max(scale * nested(d), 0.05))
			local base = d:GetAttribute("BaseTextSize")
			if typeof(base) ~= "number" then
				base = d.TextSize
				d:SetAttribute("BaseTextSize", base)
			end
			d.TextSize = math.max(base :: number, floor)
		end
	end
	apply(root)
	for _, d in root:GetDescendants() do
		apply(d)
	end
end

-- One Fit UIScale on `obj` that follows its ScreenGui's safe-area size, plus
-- the text floor. Call once the object is parented under its ScreenGui.
function Layout.fit(obj: GuiObject, kind: Kind): UIScale
	local gui = obj:FindFirstAncestorWhichIsA("LayerCollector")
	local scale = Instance.new("UIScale")
	scale.Name = "Fit"
	scale.Parent = obj
	local function update()
		local size = if gui and gui:IsA("ScreenGui") then gui.AbsoluteSize else viewport()
		scale.Scale = Layout.scale(kind, size)
		Layout.floorText(obj, scale.Scale)
	end
	update()
	-- Built content may be added after fit(); re-floor once things settle.
	task.defer(update)
	if gui then
		local conn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		scale.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	return scale
end

-- Phone arrangement or desktop value.
function Layout.pick<T>(desktop: T, phone: T): T
	return if Layout.isPhone() then phone else desktop
end

return Layout
