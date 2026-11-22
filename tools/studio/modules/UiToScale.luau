--!strict
-- Converts a Studio-built screen from 1080p pixels (Offset + a "Fit" UIScale)
-- to Scale, keeping its 1920 x 1080 look (vault/04 Tech/UI Architecture.md §5-6;
-- owner 2026-11-22: "use scale for sizing and position mainly, not offset").
--
--   * Children of a full-screen frame (or of the ScreenGui) keep their shape
--     with a FitWithinMaxSize UIAspectRatioConstraint, shrinking on narrow
--     screens like the old Fit. Everything deeper is Scale of its parent.
--   * Positions become Scale of the parent (anchor points kept), so a cluster
--     anchored to a corner stays in that corner.
--   * UIListLayout / UIGridLayout spacing, UIPadding, UICorner and
--     ScrollingFrame canvases become Scale. UIStroke stays in pixels.
--   * Text: TextScaled + UITextSizeConstraint (Max = the design TextSize, so
--     1080p looks the same; Min = MIN_TEXT). AutomaticSize is replaced by the
--     measured size.
--   * 9-slice images keep a DesignSliceScale attribute; Shared/UiLayout scales
--     SliceScale with the screen.
--   * "Fit" UIScales are set to 1 and tagged Retired (their controllers skip them).
--
-- A ModuleScript: install it once as ServerStorage.UiTools.UiToScale (Studio
-- only, never shipped), then convert one screen at a time from the Command Bar:
--   require(game.ServerStorage.UiTools.UiToScale:Clone())("Match", "KillFeed")
-- GROUP = "Match" | "Lobby" | "Mockups", NAME = the ScreenGui's name. It
-- measures a clone at 1920 x 1080 and writes the result onto the screen.
-- Check the screen at 1920 x 1080 and at phone sizes afterwards. Undo with
-- Studio's undo if needed.

local MIN_TEXT = 11
local DESIGN = Vector2.new(1920, 1080)

return function(GROUP: string, NAME: string): string
	local StarterGui = game:GetService("StarterGui")
	local StarterPlayer = game:GetService("StarterPlayer")
	local ChangeHistoryService = game:GetService("ChangeHistoryService")

	local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
	local folder = ui and ui:FindFirstChild(GROUP)
	local screen = folder and folder:FindFirstChild(NAME)
	if not screen then
		screen = StarterGui:FindFirstChild(NAME) -- parked for editing
	end
	assert(screen and screen:IsA("ScreenGui"), `no ScreenGui {GROUP}.{NAME}`)
	assert(screen:GetAttribute("Scaled") ~= true, `{NAME} is already converted`)

	local recording = ChangeHistoryService:TryBeginRecording("UiToScale " .. NAME)

	-- 1. Tag every descendant so the measured clone maps back onto the original.
	local originals: { [number]: Instance } = {}
	for i, d in screen:GetDescendants() do
		d:SetAttribute("UiToScaleId", i)
		originals[i] = d
	end

	-- 2. Measure a clone drawn at exactly 1920 x 1080, every UIScale at 1.
	local holder = Instance.new("ScreenGui")
	holder.Name = "UiToScale_Measure"
	holder.IgnoreGuiInset = true
	holder.ScreenInsets = Enum.ScreenInsets.None
	holder.ZIndexBehavior = screen.ZIndexBehavior
	local ref = Instance.new("Frame")
	ref.Name = "Ref"
	ref.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	ref.BackgroundTransparency = 1
	ref.Parent = holder
	local clone = screen:Clone()
	for _, c in clone:GetChildren() do
		c.Parent = ref
	end
	clone:Destroy()
	for _, d in ref:GetDescendants() do
		if d:IsA("UIScale") then
			d.Scale = 1
		elseif d:IsA("GuiObject") then
			d.Visible = true -- hidden panels still need measuring
		end
	end
	holder.Parent = StarterGui
	task.wait()
	task.wait()

	type Measure = { size: Vector2, pos: Vector2, canvas: Vector2?, window: Vector2? }
	local measured: { [number]: Measure } = {}
	local function idOf(o: Instance): number?
		local id = o:GetAttribute("UiToScaleId")
		return if typeof(id) == "number" then id else nil
	end
	for _, d in ref:GetDescendants() do
		local id = idOf(d)
		if id and d:IsA("GuiObject") then
			measured[id] = {
				size = d.AbsoluteSize,
				pos = d.AbsolutePosition,
				canvas = if d:IsA("ScrollingFrame") then d.AbsoluteCanvasSize else nil,
				window = if d:IsA("ScrollingFrame") then d.AbsoluteWindowSize else nil,
			}
		end
	end
	local refSize, refPos = ref.AbsoluteSize, ref.AbsolutePosition

	-- The measured box of an original's GuiObject parent (the 1080p screen for top level).
	local function parentBox(o: Instance): (Vector2, Vector2, boolean)
		local p = o.Parent
		while p and not p:IsA("GuiObject") and not p:IsA("LayerCollector") do
			p = p.Parent
		end
		if p and p:IsA("GuiObject") then
			local m = measured[idOf(p) or -1]
			if m then
				local full = math.abs(m.size.X - refSize.X) < 2
					and math.abs(m.size.Y - refSize.Y) < 2
				return m.size, m.pos, full
			end
		end
		return refSize, refPos, true
	end

	local function layoutParent(o: Instance): boolean
		local p = o.Parent
		return p ~= nil
			and (
				p:FindFirstChildOfClass("UIListLayout") ~= nil
				or p:FindFirstChildOfClass("UIGridLayout") ~= nil
			)
	end

	local counts =
		{ sizes = 0, texts = 0, layouts = 0, corners = 0, autos = 0, slices = 0, fits = 0 }
	local notes: { string } = {}
	local function safe(n: number): number
		return if n ~= n or n == math.huge or n == -math.huge then 0 else n
	end

	-- 3. Write Scale values onto the originals.
	for id, m in measured do
		local o = originals[id]
		if not o or not o:IsA("GuiObject") then
			continue
		end
		local pSize, pPos, parentFull = parentBox(o)
		if o.AutomaticSize ~= Enum.AutomaticSize.None then
			o.AutomaticSize = Enum.AutomaticSize.None
			counts.autos += 1
		end
		-- Size: Scale of the parent. A group on the full screen also gets a
		-- FitWithinMaxSize aspect constraint ("Shape"): it keeps its shape and,
		-- like the old Fit (min of width and height), shrinks on narrow 4:3
		-- screens. Bars spanning the screen's width or height just stretch.
		o.SizeConstraint = Enum.SizeConstraint.RelativeXY
		o.Size = UDim2.fromScale(safe(m.size.X / pSize.X), safe(m.size.Y / pSize.Y))
		local spans = m.size.X >= pSize.X * 0.95 or m.size.Y >= pSize.Y * 0.95
		if parentFull and not layoutParent(o) and not spans and m.size.Y > 0 then
			if not o:FindFirstChildOfClass("UIAspectRatioConstraint") then
				local shape = Instance.new("UIAspectRatioConstraint")
				shape.Name = "Shape"
				shape.AspectRatio = m.size.X / m.size.Y
				shape.AspectType = Enum.AspectType.FitWithinMaxSize
				shape.Parent = o
			end
		end
		counts.sizes += 1
		-- Position (layouts place their children themselves)
		if not layoutParent(o) then
			local at = m.pos + m.size * o.AnchorPoint - pPos
			o.Position = UDim2.fromScale(safe(at.X / pSize.X), safe(at.Y / pSize.Y))
		end
		-- Text
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			local t = o :: any
			if not t.TextScaled then
				local design = t.TextSize
				t.TextScaled = true
				local c = o:FindFirstChildOfClass("UITextSizeConstraint")
				if not c then
					c = Instance.new("UITextSizeConstraint")
					c.Parent = o
				end
				c.MaxTextSize = math.max(design, 1)
				c.MinTextSize = math.min(MIN_TEXT, design)
				counts.texts += 1
			end
		end
		-- 9-slice images: keep the design slice scale for Shared/UiLayout
		if
			(o:IsA("ImageLabel") or o:IsA("ImageButton"))
			and (o :: any).ScaleType == Enum.ScaleType.Slice
		then
			o:SetAttribute("DesignSliceScale", (o :: any).SliceScale)
			counts.slices += 1
		end
		-- Scrolling canvases
		if o:IsA("ScrollingFrame") and m.canvas and m.window then
			if o.AutomaticCanvasSize == Enum.AutomaticSize.None and m.canvas.X > 0 then
				o.CanvasSize = UDim2.fromScale(
					safe(m.canvas.X / math.max(m.window.X, 1)),
					safe(m.canvas.Y / math.max(m.window.Y, 1))
				)
			end
		end
	end

	-- 4. Layout objects, padding, corners.
	for _, o in screen:GetDescendants() do
		local parent = o.Parent
		local pm = parent and measured[idOf(parent) or -1]
		local box = if pm then pm.size else refSize
		if o:IsA("UIListLayout") then
			local along = if o.FillDirection == Enum.FillDirection.Horizontal then box.X else box.Y
			local px = o.Padding.Offset + o.Padding.Scale * along
			o.Padding = UDim.new(safe(px / along), 0)
			counts.layouts += 1
		elseif o:IsA("UIGridLayout") then
			local cell = Vector2.new(
				o.CellSize.X.Offset + o.CellSize.X.Scale * box.X,
				o.CellSize.Y.Offset + o.CellSize.Y.Scale * box.Y
			)
			local pad = Vector2.new(
				o.CellPadding.X.Offset + o.CellPadding.X.Scale * box.X,
				o.CellPadding.Y.Offset + o.CellPadding.Y.Scale * box.Y
			)
			o.CellSize = UDim2.fromScale(safe(cell.X / box.X), safe(cell.Y / box.Y))
			o.CellPadding = UDim2.fromScale(safe(pad.X / box.X), safe(pad.Y / box.Y))
			counts.layouts += 1
		elseif o:IsA("UIPadding") then
			local function conv(u: UDim, along: number): UDim
				return UDim.new(safe((u.Offset + u.Scale * along) / along), 0)
			end
			o.PaddingLeft = conv(o.PaddingLeft, box.X)
			o.PaddingRight = conv(o.PaddingRight, box.X)
			o.PaddingTop = conv(o.PaddingTop, box.Y)
			o.PaddingBottom = conv(o.PaddingBottom, box.Y)
			counts.layouts += 1
		elseif o:IsA("UICorner") then
			local short = math.min(box.X, box.Y)
			if o.CornerRadius.Offset ~= 0 and short > 0 then
				o.CornerRadius = UDim.new(
					safe((o.CornerRadius.Offset + o.CornerRadius.Scale * short) / short),
					0
				)
				counts.corners += 1
			end
		elseif o:IsA("UIScale") and o.Name == "Fit" then
			o.Scale = 1
			o:SetAttribute("Retired", true)
			counts.fits += 1
		elseif o:IsA("UISizeConstraint") then
			table.insert(notes, `UISizeConstraint kept (pixels) at {o:GetFullName()}`)
		end
	end

	-- 5. Clean up.
	holder:Destroy()
	for _, d in screen:GetDescendants() do
		d:SetAttribute("UiToScaleId", nil)
	end
	screen:SetAttribute("Scaled", true)
	screen:SetAttribute("DesignSize", DESIGN)
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	local summary = string.format(
		"[UiToScale] %s.%s: %d sizes, %d texts, %d layout objects, %d corners, %d AutomaticSize removed, %d 9-slices, %d Fit retired",
		GROUP,
		NAME,
		counts.sizes,
		counts.texts,
		counts.layouts,
		counts.corners,
		counts.autos,
		counts.slices,
		counts.fits
	)
	print(summary)
	for _, n in notes do
		print("  " .. n)
	end
	return summary
end
