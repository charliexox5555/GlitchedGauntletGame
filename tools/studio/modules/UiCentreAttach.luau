--!strict
-- Studio tool (install as ServerStorage.UiTools.UiCentreAttach, like the other
-- modules here). Re-attaches the groups of a fit canvas (Shared/UiLayout
-- FitCanvas) so they stay centred on any screen shape (owner 2026-11-22: the
-- draft and killed-by sat off centre on a phone).
--
-- A fit canvas is 1920 x 1080 design px on a 16:9 screen but wider and
-- shorter on a phone. Groups placed at a Scale position with a 0,0 anchor
-- spread apart there and drift right. This keeps each group's design offset
-- from what it belongs to instead:
--   near the middle  -> AnchorPoint 0.5, Position (0.5, centre - 960)
--   near an edge     -> AnchorPoint 0 / 1, Position (0, left) / (1, right - 1920)
-- per axis (EDGE px decides "near an edge"). On a 1920 x 1080 canvas nothing
-- moves. Phone/Tablet/Console Position overrides on those groups are cleared
-- (they were patches for the spreading); re-add one only for a real
-- per-device layout change.
--
--   require(game.ServerStorage.UiTools.UiCentreAttach).run(canvas, { "Gun1", ... })

local UiCentreAttach = {}

local DESIGN = Vector2.new(1920, 1080)
local EDGE = 260 -- design px: a group this close to an edge stays on that edge

local function axis(
	scale: number,
	offset: number,
	anchor: number,
	size: number,
	full: number
): (number, number, number)
	if size <= 0 then
		-- an auto-sized group (unknown size here): keep its anchor, attach the
		-- anchor point to the middle
		return 0.5, scale * full + offset - full / 2, anchor
	end
	local start = scale * full + offset - anchor * size
	local centre = start + size / 2
	if start < EDGE and centre < full / 2 then
		return 0, start, 0 -- left / top edge
	elseif start + size > full - EDGE and centre > full / 2 then
		return 1, start + size - full, 1 -- right / bottom edge
	end
	return 0.5, centre - full / 2, 0.5
end

function UiCentreAttach.run(canvas: GuiObject, names: { string }?): string
	local out = {}
	for _, c in canvas:GetChildren() do
		if
			c:IsA("GuiObject")
			and c:GetAttribute("FullBleed") ~= true
			and (names == nil or table.find(names, c.Name) ~= nil)
		then
			local base = c:GetAttribute("BasePosition")
			local pos = if typeof(base) == "UDim2" then base else c.Position
			local baseAnchor = c:GetAttribute("BaseAnchorPoint")
			local anchor = if typeof(baseAnchor) == "Vector2" then baseAnchor else c.AnchorPoint
			-- design size (offset sizes; AutomaticSize groups use their drawn size)
			local size = Vector2.new(
				c.Size.X.Scale * DESIGN.X + c.Size.X.Offset,
				c.Size.Y.Scale * DESIGN.Y + c.Size.Y.Offset
			)
			if c.AutomaticSize ~= Enum.AutomaticSize.None then
				local k = canvas.AbsoluteSize.X / DESIGN.X
				if k > 0 then
					size = Vector2.new(
						math.max(size.X, c.AbsoluteSize.X / k),
						math.max(size.Y, c.AbsoluteSize.Y / k)
					)
				end
			end
			local sx, ox, ax = axis(pos.X.Scale, pos.X.Offset, anchor.X, size.X, DESIGN.X)
			local sy, oy, ay = axis(pos.Y.Scale, pos.Y.Offset, anchor.Y, size.Y, DESIGN.Y)
			c.AnchorPoint = Vector2.new(ax, ay)
			c.Position = UDim2.new(sx, math.floor(ox + 0.5), sy, math.floor(oy + 0.5))
			for _, family in { "Phone", "Tablet", "Console" } do
				c:SetAttribute(family .. "Position", nil)
			end
			c:SetAttribute("BasePosition", nil)
			c:SetAttribute("BaseAnchorPoint", nil)
			table.insert(out, `{c.Name}: {pos} ap {anchor} -> {c.Position} ap {c.AnchorPoint}`)
		end
	end
	return table.concat(out, "\n")
end

return UiCentreAttach
