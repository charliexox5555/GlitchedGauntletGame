--!strict
-- Camera pixels to GUI pixels (owner 2026-11-22: the crosshair sat left of
-- centre on a phone). Camera:WorldToViewportPoint and Camera.ViewportSize use
-- the camera's viewport, whose origin is where GUI AbsolutePosition starts
-- plus Roblox's top-bar inset. On a phone the viewport is the safe area, so
-- full-bleed screens (ScreenInsets.None) start left of and above it, and
-- "ViewportSize / 2" drawn in them lands a notch's width off the aim point.
-- Always convert through here before drawing a camera point in a GUI.
-- Client only.

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local ScreenPoint = {}

-- A viewport point (WorldToViewportPoint X / Y) in `space`'s own pixels.
function ScreenPoint.toLocal(space: GuiBase2d, viewportPoint: Vector2): Vector2
	local inset = GuiService:GetGuiInset()
	return viewportPoint - inset - space.AbsolutePosition
end

-- The camera's aim point (where its look direction lands) in `space`'s
-- pixels. Not ViewportSize / 2: the 3D view is centred on the whole screen,
-- and a phone's safe area is uneven (measured in the emulator: 10 px off).
function ScreenPoint.centre(space: GuiBase2d): Vector2
	local cam = Workspace.CurrentCamera
	if not cam then
		return space.AbsoluteSize / 2
	end
	local cf = cam.CFrame
	local p = cam:WorldToViewportPoint(cf.Position + cf.LookVector * 100)
	-- Snapped to 0.01 px: the projection carries ~1e-4 px of float noise that
	-- changes as the camera turns, and a centre on a pixel edge then floored
	-- to alternating pixels (owner 2026-11-22: the crosshair shook on a phone).
	local x = math.floor(p.X * 100 + 0.5) / 100
	local y = math.floor(p.Y * 100 + 0.5) / 100
	return ScreenPoint.toLocal(space, Vector2.new(x, y))
end

-- A viewport point as a fraction of `space` (for Scale positions).
function ScreenPoint.toScale(space: GuiBase2d, viewportPoint: Vector2): Vector2
	local size = space.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return Vector2.new(0.5, 0.5)
	end
	return ScreenPoint.toLocal(space, viewportPoint) / size
end

return ScreenPoint
