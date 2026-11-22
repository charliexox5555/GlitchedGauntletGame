--!strict
-- Where the touch buttons go (vault/02 Art/UI Mobile Controls.md → Build plan
-- v1). Used by the match HUD (client/Controllers/TouchController) and the
-- layout editor (lobby/client/Util/TouchEditor), so both draw the same.
--
--   TouchLayout.refresh(root, values, editing?)
--     1. base: cluster sizes for the device, the row under Roblox's top bar
--     2. the saved layout on top (Settings → TOUCH, Shared/PlayerSettings):
--        left-handed mirror, each object's spot and size from the active
--        profile, hidden groups, opacity.
--
-- A saved spot is { x, y, s }: the object's centre as a fraction of the touch
-- root in the right-handed frame, and a size multiplier. No entry = the spot
-- built in Studio, so a reset just clears the profile. Client only.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TouchControls = require(ReplicatedStorage.Shared.Config.TouchControls)
local UiLayout = require(script.Parent.UiLayout)

local TouchLayout = {}

export type Entry = { number } -- { x, y, s }
export type Layout = { [string]: Entry }

TouchLayout.TABLET = 0.78 -- tablets: every cluster × this (mockup measure)
local GAP = 8 -- px between Roblox's buttons and ours
local ROW_TUCK = 4 -- px the row under Roblox's buttons tucks into the top bar's margin
local STICK_SIDE = 0.27 -- the floating stick's size (× the screen height)
-- mirrored for left-handed play (their own spot, and their children's x)
local MIRROR_GROUPS = { "StickZone", "LeftCluster", "RightCluster", "Health" } -- the health bar swaps with the buttons
local MIRROR_INNER = { "Mods" } -- full-size frames inside a cluster: mirror their children too

-- The objects a layout can move, found once per root.
local function objects(root: Instance): { [string]: GuiObject }
	local out = {}
	for name in TouchControls.MOVABLE do
		local o = root:FindFirstChild(name, true)
		if o and o:IsA("GuiObject") then
			out[name] = o
		end
	end
	return out
end

-- Studio's values, kept the first time so a change can go back to them.
local function stash(o: GuiObject)
	if o:GetAttribute("TLPos") == nil then
		o:SetAttribute("TLPos", o.Position)
		o:SetAttribute("TLAnchor", o.AnchorPoint)
		o:SetAttribute("TLSize", o.Size)
	end
end

local function restore(o: GuiObject, keepPosition: boolean?)
	stash(o)
	if not keepPosition then
		o.Position = o:GetAttribute("TLPos") :: UDim2
		o.AnchorPoint = o:GetAttribute("TLAnchor") :: Vector2
	end
	o.Size = o:GetAttribute("TLSize") :: UDim2
end

local function mirrorX(o: GuiObject)
	local p = o.Position
	o.Position = UDim2.new(1 - p.X.Scale, -p.X.Offset, p.Y.Scale, p.Y.Offset)
	o.AnchorPoint = Vector2.new(1 - o.AnchorPoint.X, o.AnchorPoint.Y)
end

-- 1. The device layout (was TouchController.layout).
function TouchLayout.base(root: Frame)
	local scale = if UiLayout.family() == "Phone" then 1 else TouchLayout.TABLET
	for _, c in root:GetChildren() do
		local side = c:GetAttribute("PhoneSide")
		if c:IsA("Frame") and typeof(side) == "number" then
			c.Size = UDim2.fromScale(side * scale, side * scale)
		end
	end
	local stick = root:FindFirstChild("Stick")
	if stick and stick:IsA("Frame") then
		stick.Size = UDim2.fromScale(STICK_SIDE * scale, STICK_SIDE * scale)
	end
	local inset = GuiService.TopbarInset
	local topLeft = root:FindFirstChild("TopLeft")
	if inset.Height <= 0 or not topLeft or not topLeft:IsA("Frame") then
		return
	end
	local box = topLeft.AbsoluteSize
	if box.X <= 0 then
		return
	end
	-- TopbarInset is in screen pixels, AbsolutePosition is measured from below
	-- Roblox's top bar (GetGuiInset): convert, or the row lands a bar lower.
	local guiTop = GuiService:GetGuiInset()
	local function place(name: string, centre: Vector2)
		local b = topLeft:FindFirstChild(name)
		if b and b:IsA("GuiObject") then
			local p = (centre - guiTop - topLeft.AbsolutePosition) / box
			b.Position = UDim2.fromScale(p.X, p.Y)
		end
	end
	local settings = topLeft:FindFirstChild("SettingsButton")
	local d = if settings and settings:IsA("GuiObject")
		then settings.AbsoluteSize.X
		else box.X * 0.16
	-- TopbarInset is the free space between Roblox's left and right buttons:
	-- Min.X is the right edge of Roblox's left buttons.
	place("SettingsButton", Vector2.new(inset.Min.X + GAP + d / 2, inset.Min.Y + inset.Height / 2))
	-- the row under Roblox's buttons, from the safe area's left edge
	local rowY = inset.Max.Y + d / 2 - ROW_TUCK
	local x = root.AbsolutePosition.X + GAP * 1.5 + d / 2
	for _, name in { "ScoreboardButton", "InspectButton" } do
		local b = topLeft:FindFirstChild(name)
		if b and b:IsA("GuiObject") and b.Visible then
			place(name, Vector2.new(x, rowY))
			x += d + GAP
		end
	end
end

-- The active profile's layout in `values` (Settings), or an empty one.
function TouchLayout.active(values: { [string]: any }?): (Layout, number)
	local p = tonumber(values and values.touchProfile) or 1
	p = math.clamp(math.floor(p), 1, TouchControls.PROFILES)
	local layout = values and values["touchLayout" .. p]
	return (if typeof(layout) == "table" then layout else {}) :: Layout, p
end

-- Puts one object's centre at a root fraction (right-handed frame) and sizes it.
function TouchLayout.place(root: Frame, o: GuiObject, entry: Entry, leftHanded: boolean)
	local parent = o.Parent
	if not parent or not parent:IsA("GuiObject") then
		return
	end
	local rs, ps = root.AbsoluteSize, parent.AbsoluteSize
	if rs.X <= 0 or ps.X <= 0 or ps.Y <= 0 then
		return
	end
	local fx = if leftHanded then 1 - entry[1] else entry[1]
	local at = root.AbsolutePosition + Vector2.new(fx * rs.X, entry[2] * rs.Y)
	local p = (at - parent.AbsolutePosition) / ps
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(p.X, p.Y)
	local base = o:GetAttribute("TLSize")
	local size = if typeof(base) == "UDim2" then base else o.Size
	local s = entry[3] or 1
	o.Size = UDim2.new(size.X.Scale * s, size.X.Offset * s, size.Y.Scale * s, size.Y.Offset * s)
end

-- An object's current spot as an entry (right-handed frame), for the editor.
function TouchLayout.entryOf(root: Frame, o: GuiObject, leftHanded: boolean, size: number): Entry
	local rs = root.AbsoluteSize
	local c = o.AbsolutePosition + o.AbsoluteSize / 2 - root.AbsolutePosition
	local fx = if rs.X > 0 then c.X / rs.X else 0.5
	local fy = if rs.Y > 0 then c.Y / rs.Y else 0.5
	if leftHanded then
		fx = 1 - fx
	end
	return { math.clamp(fx, 0, 1), math.clamp(fy, 0, 1), size }
end

-- Per-object opacity (0-1, used by TouchController's paint) and hidden state.
local alphaOf: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local hiddenOf: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local guarded: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function TouchLayout.alpha(o: Instance?): number
	return if o then alphaOf[o] or 1 else 1
end

function TouchLayout.hidden(o: Instance?): boolean
	return o ~= nil and hiddenOf[o] == true
end

-- How solid a group is: its own OPACITY with CUSTOM on, else BUTTON OPACITY.
function TouchLayout.groupAlpha(values: { [string]: any }?, key: string?): number
	local v = values or {}
	local pct = v.touchOpacity
	if key and v["touch" .. key .. "Custom"] == true then
		pct = v["touch" .. key .. "Alpha"]
	end
	return math.clamp((tonumber(pct) or 100) / 100, 0.05, 1)
end

-- Fades an object's visuals to `a` of their built look (the Face plate too:
-- TouchController's paint keeps multiplying by TouchLayout.alpha).
local function fade(o: GuiObject, a: number)
	for _, d in o:GetDescendants() do
		if d:IsA("GuiObject") then
			if d:GetAttribute("TLBg") == nil then
				d:SetAttribute("TLBg", d.BackgroundTransparency)
			end
			d.BackgroundTransparency = 1 - (1 - (d:GetAttribute("TLBg") :: number)) * a
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				if d:GetAttribute("TLImg") == nil then
					d:SetAttribute("TLImg", d.ImageTransparency)
				end
				d.ImageTransparency = 1 - (1 - (d:GetAttribute("TLImg") :: number)) * a
			elseif d:IsA("TextLabel") then
				if d:GetAttribute("TLTxt") == nil then
					d:SetAttribute("TLTxt", d.TextTransparency)
				end
				d.TextTransparency = 1 - (1 - (d:GetAttribute("TLTxt") :: number)) * a
			end
		elseif d:IsA("UIStroke") then
			if d:GetAttribute("TLStroke") == nil then
				d:SetAttribute("TLStroke", d.Transparency)
			end
			d.Transparency = 1 - (1 - (d:GetAttribute("TLStroke") :: number)) * a
		end
	end
end

-- Keeps a hidden object hidden when HUD code shows it (loadout, mods).
local function guard(o: GuiObject)
	if guarded[o] then
		return
	end
	guarded[o] = true
	o:GetPropertyChangedSignal("Visible"):Connect(function()
		if hiddenOf[o] and o.Visible then
			o.Visible = false
		end
	end)
end

-- 2. The saved layout on top of the base. `editing` (the editor): hidden
-- objects stay visible but faint, so they can still be picked.
function TouchLayout.apply(root: Frame, values: { [string]: any }?, editing: boolean?)
	local v = values or {}
	local left = v.touchLeftHanded == true
	local layout = TouchLayout.active(values)
	local objs = objects(root)
	-- Studio spots first (the top-left row keeps the spot base() gave it)
	for _, o in objs do
		restore(o, o.Parent and o.Parent.Name == "TopLeft")
	end
	for _, name in MIRROR_GROUPS do
		local g = root:FindFirstChild(name)
		if g and g:IsA("GuiObject") then
			stash(g)
			g.Position = g:GetAttribute("TLPos") :: UDim2
			g.AnchorPoint = g:GetAttribute("TLAnchor") :: Vector2
		end
	end
	-- left-handed: the stick side and the button side swap
	if left then
		for _, name in MIRROR_GROUPS do
			local g = root:FindFirstChild(name)
			if g and g:IsA("GuiObject") then
				mirrorX(g)
				for _, c in g:GetChildren() do
					if
						c:IsA("GuiObject") and (objs[c.Name] or table.find(MIRROR_INNER, c.Name))
					then
						if table.find(MIRROR_INNER, c.Name) then
							for _, cc in c:GetChildren() do
								if cc:IsA("GuiObject") and objs[cc.Name] then
									mirrorX(cc)
								end
							end
						else
							mirrorX(c)
						end
					end
				end
			end
		end
	end
	-- custom spots and sizes
	for name, entry in layout do
		local o = objs[name]
		if o and typeof(entry) == "table" and #entry >= 3 then
			TouchLayout.place(root, o, entry, left)
		end
	end
	-- shown / hidden and opacity per group
	local showAmmo = v.touchShowAmmo ~= false
	for name, o in objs do
		local g = TouchControls.GROUP_OF[name]
		local hide = (g ~= nil and g.canHide and v["touch" .. g.key .. "On"] == false)
			or (name == "AmmoReadout" and not showAmmo)
		local a = TouchLayout.groupAlpha(v, if g then g.key else nil)
		if editing then
			hiddenOf[o] = nil
			o:SetAttribute("TLHidden", hide)
			alphaOf[o] = if hide then 0.25 else a
		else
			local was = hiddenOf[o] == true
			hiddenOf[o] = hide or nil
			alphaOf[o] = a
			if hide then
				guard(o)
				o.Visible = false
			elseif was then
				-- shown again: the HUD's own rules (Auto Sprint, no-ADS guns,
				-- empty slots) hide it again if they need to (TouchController)
				o.Visible = true
			end
		end
		fade(o, alphaOf[o])
	end
end

-- Both, in order.
function TouchLayout.refresh(root: Frame, values: { [string]: any }?, editing: boolean?)
	TouchLayout.base(root)
	TouchLayout.apply(root, values, editing)
end

return TouchLayout
