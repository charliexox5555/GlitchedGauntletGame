--!strict
-- Things that pop (hover lift, press dip, pop-in) must scale from their own
-- centre (owner rule, memory "UI scale pivot"; vault/02 Art/UI Lobby HUD.md).
-- A UIScale grows a GuiObject about its AnchorPoint, and an item placed by a
-- UIListLayout / UIGridLayout grows from its top-left whatever its anchor.
--
-- centre(obj): a free-standing object gets AnchorPoint (0.5, 0.5) and its
--   Position moved so it doesn't shift (fixed-size objects).
-- wrap(obj): a layout item gets a transparent holder in its place (same name,
--   size, LayoutOrder, visibility) and sits centred inside it, so the layout
--   moves the holder and the scale grows from the item's centre. Returns the
--   holder. Keep your own reference to `obj` for its events; a lookup by name
--   now finds the holder (hide / show the holder to hide / show the item).
-- fix(root): every UIScale under `root` (except "Fit") gets its object
--   centred or wrapped. Objects with the attribute PivotOk = true are left
--   as designed (e.g. a hover that rises from the base).

local Pivot = {}

local function layoutManaged(obj: GuiObject): boolean
	local p = obj.Parent
	return p ~= nil
		and (
			p:FindFirstChildOfClass("UIListLayout") ~= nil
			or p:FindFirstChildOfClass("UIGridLayout") ~= nil
		)
end

local function centred(obj: GuiObject): boolean
	local a = obj.AnchorPoint
	return math.abs(a.X - 0.5) < 0.001 and math.abs(a.Y - 0.5) < 0.001
end

function Pivot.centre(obj: GuiObject)
	if centred(obj) or obj.AutomaticSize ~= Enum.AutomaticSize.None then
		return -- auto-sized things are placed by their owners
	end
	local a, s = obj.AnchorPoint, obj.Size
	local dx, dy = 0.5 - a.X, 0.5 - a.Y
	obj.AnchorPoint = Vector2.new(0.5, 0.5)
	obj.Position = obj.Position
		+ UDim2.new(dx * s.X.Scale, dx * s.X.Offset, dy * s.Y.Scale, dy * s.Y.Offset)
end

function Pivot.wrap(obj: GuiObject): Frame
	local parent = obj.Parent
	if parent and parent:GetAttribute("PivotHolder") == true then
		return parent :: Frame
	end
	local holder = Instance.new("Frame")
	holder.Name = obj.Name
	holder.Size = obj.Size
	holder.AutomaticSize = obj.AutomaticSize
	holder.LayoutOrder = obj.LayoutOrder
	holder.Visible = obj.Visible
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ZIndex = obj.ZIndex
	holder:SetAttribute("PivotHolder", true)
	holder.Parent = parent
	-- a grid sizes its cells (the holder now); the item fills its holder
	if parent and parent:FindFirstChildOfClass("UIGridLayout") then
		obj.Size = UDim2.fromScale(1, 1)
	end
	obj.AnchorPoint = Vector2.new(0.5, 0.5)
	obj.Position = UDim2.fromScale(0.5, 0.5)
	obj.Visible = true
	obj.Parent = holder
	return holder
end

-- Centres or wraps one object, whichever it needs.
function Pivot.prepare(obj: GuiObject)
	if layoutManaged(obj) then
		Pivot.wrap(obj)
	else
		Pivot.centre(obj)
	end
end

function Pivot.fix(root: Instance)
	local targets: { GuiObject } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("UIScale") and d.Name ~= "Fit" then
			local g = d.Parent
			if g and g:IsA("GuiObject") and g:GetAttribute("PivotOk") ~= true then
				table.insert(targets, g)
			end
		end
	end
	for _, g in targets do
		if layoutManaged(g) then
			Pivot.wrap(g)
		elseif not centred(g) then
			Pivot.centre(g)
		end
	end
end

-- The item itself, given what a lookup by name found (its holder, if wrapped).
function Pivot.item(found: Instance): Instance
	if found:GetAttribute("PivotHolder") == true then
		local inner = found:FindFirstChild(found.Name)
		if inner then
			return inner
		end
	end
	return found
end

return Pivot
