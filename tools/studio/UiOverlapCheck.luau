--!strict
-- Measured UI check for a live playtest (vault/02 Art/UI Device Check 2026-11-27.md).
-- Paste into the Studio MCP execute_luau on the **Client** datamodel (or the command bar while a client
-- runs), at each Device Emulator size. Prints:
--   * the viewport, GuiService.TopbarInset and the layout family;
--   * every overlap between visible buttons of different ScreenGuis, the match scorebug and Roblox's own
--     top-bar buttons (full-screen backdrop buttons are skipped);
--   * clipped text (TextFits false on a label that isn't scaled or truncated) and text drawn under 12 px.
-- Read-only: it changes nothing.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
local offset = GuiService:GetGuiInset()
-- dev and test screens
local IGNORE: { [string]: boolean } = {
	NetStats = true,
	AdminPanelGui = true,
	ModDevPanel = true,
	Freecam = true,
	MouseFree = true,
	WeaponPicker = true,
	SkinPreview = true,
	UiDeviceSheet = true,
}
local MIN_TEXT = 11.5 -- px (the floor is 12; rounding)

local out: { string } = {}
local camera = workspace.CurrentCamera
local vp = camera.ViewportSize
local family = "?"
pcall(function()
	family = (require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiLayout") :: ModuleScript) :: any).family()
end)
table.insert(out, `vp={vp.X}x{vp.Y} topbar={GuiService.TopbarInset} family={family}`)

type Box = { number }
type Item = { o: GuiObject?, g: string, b: Box }

local function shown(o: Instance): boolean
	local x: Instance? = o
	while x and not x:IsA("ScreenGui") do
		if x:IsA("GuiObject") and not x.Visible then
			return false
		end
		if x:IsA("CanvasGroup") and x.GroupTransparency > 0.95 then
			return false
		end
		x = x.Parent
	end
	return x ~= nil and (x :: ScreenGui).Enabled
end

local function box(o: GuiObject): Box
	local p = o.AbsolutePosition + offset
	local s = o.AbsoluteSize
	return { p.X, p.Y, p.X + s.X, p.Y + s.Y }
end

local function overlap(a: Box, b: Box): (boolean, number, number)
	local w = math.min(a[3], b[3]) - math.max(a[1], b[1])
	local h = math.min(a[4], b[4]) - math.max(a[2], b[2])
	return w > 2 and h > 2, w, h
end

local items: { Item } = {}
for _, sg in playerGui:GetChildren() do
	if sg:IsA("ScreenGui") and sg.Enabled and not IGNORE[sg.Name] then
		for _, o in sg:GetDescendants() do
			if
				o:IsA("GuiButton")
				and o.AbsoluteSize.X > 4
				and o.AbsoluteSize.X * o.AbsoluteSize.Y < vp.X * vp.Y * 0.4 -- not a full-screen backdrop
				and shown(o)
			then
				table.insert(items, { o = o, g = sg.Name, b = box(o) })
			end
		end
	end
end
local topBar = playerGui:FindFirstChild("TopBar")
local root = topBar and topBar:FindFirstChild("Root")
local bar = root and root:FindFirstChild("Bar")
if bar and bar:IsA("GuiObject") and shown(bar) then
	table.insert(items, { o = bar, g = "TopBar", b = box(bar) })
	local b = box(bar)
	table.insert(out, string.format("scorebug x %d-%d y %d-%d", b[1], b[3], b[2], b[4]))
end
local inset = GuiService.TopbarInset
if inset.Height > 0 then
	table.insert(items, { g = "ROBLOX", b = { 0, inset.Min.Y, inset.Min.X, inset.Max.Y } })
	if inset.Max.X < vp.X - 1 then
		table.insert(items, { g = "ROBLOX-R", b = { inset.Max.X, inset.Min.Y, vp.X, inset.Max.Y } })
	end
end

local overlaps = 0
for i = 1, #items do
	for j = i + 1, #items do
		local a, b = items[i], items[j]
		if a.g ~= b.g then
			local hit, w, h = overlap(a.b, b.b)
			if hit then
				overlaps += 1
				if overlaps <= 30 then
					local an = if a.o then a.o.Name else "-"
					local bn = if b.o then b.o.Name else "-"
					table.insert(out, `OVERLAP {a.g}:{an} x {b.g}:{bn} ({math.round(w)}x{math.round(h)})`)
				end
			end
		end
	end
end
table.insert(out, `overlaps={overlaps}`)

local clipped, small = 0, 0
for _, sg in playerGui:GetChildren() do
	if sg:IsA("ScreenGui") and sg.Enabled and not IGNORE[sg.Name] then
		for _, o in sg:GetDescendants() do
			if
				(o:IsA("TextLabel") or o:IsA("TextButton"))
				and o.Text ~= ""
				and o.TextTransparency < 0.9
				and o.AbsoluteSize.X > 2
				and shown(o)
			then
				local parentName = if o.Parent then o.Parent.Name else "?"
				if not o.TextFits and not o.TextScaled and o.TextTruncate == Enum.TextTruncate.None then
					clipped += 1
					if clipped <= 15 then
						table.insert(out, `CLIP {sg.Name}:{parentName}.{o.Name} '{string.sub(o.ContentText, 1, 24)}'`)
					end
				end
				local lines = math.max(1, #string.split(o.ContentText, "\n"))
				local px = o.TextBounds.Y / lines
				if px > 0 and px < MIN_TEXT then
					small += 1
					if small <= 15 then
						table.insert(
							out,
							string.format(
								"SMALL %.1fpx %s:%s.%s '%s'",
								px,
								sg.Name,
								parentName,
								o.Name,
								string.sub(o.ContentText, 1, 20)
							)
						)
					end
				end
			end
		end
	end
end
table.insert(out, `clipped={clipped} small={small}`)
local report = table.concat(out, "\n")
print(report)
return report
