--!strict
-- The darkening of the screen's edges while a gun is aimed (Config/Scope
-- AIM_VIGNETTE: 40-50% in the corners in the owner's clips, in within ~0.1 s).
-- Four black bands, one per edge, each fading to clear toward the middle;
-- they overlap in the corners. Built into the HUD by Controllers/HudController,
-- which sets it from the aim blend every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scope = require(ReplicatedStorage.Shared.Config.Scope)

local AimVignette = {}

local V = Scope.AIM_VIGNETTE

local group: Frame? = nil
local bands: { Frame } = {}
local shownAt = -1

function AimVignette.build(gui: ScreenGui)
	local g = Instance.new("Frame")
	g.Name = "AimVignette"
	g.Size = UDim2.fromScale(1, 1)
	g.BackgroundTransparency = 1
	g.Visible = false
	g.ZIndex = 0
	g.Parent = gui
	group = g
	for _, edge in
		{
			-- anchor, size, gradient rotation (solid at the screen's edge)
			{ Vector2.new(0, 0), UDim2.fromScale(1, V.depth), 90 },
			{ Vector2.new(0, 1), UDim2.fromScale(1, V.depth), -90 },
			{ Vector2.new(0, 0), UDim2.fromScale(V.depth, 1), 0 },
			{ Vector2.new(1, 0), UDim2.fromScale(V.depth, 1), 180 },
		}
	do
		local anchor = edge[1] :: Vector2
		local band = Instance.new("Frame")
		band.Name = "Band"
		band.AnchorPoint = anchor
		band.Position = UDim2.fromScale(anchor.X, anchor.Y)
		band.Size = edge[2] :: UDim2
		band.BackgroundColor3 = Scope.COLOR
		band.BackgroundTransparency = 1
		band.BorderSizePixel = 0
		band.Parent = g
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge[3] :: number
		-- Solid at 0 (the screen's edge), easing to clear at the inner side.
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.45),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = band
		table.insert(bands, band)
	end
end

-- `alpha` 0 (hip) .. 1 (aimed).
function AimVignette.set(alpha: number)
	local g = group
	if not g then
		return
	end
	alpha = math.clamp(alpha, 0, 1)
	if math.abs(alpha - shownAt) < 0.004 then
		return
	end
	shownAt = alpha
	g.Visible = alpha > 0.01
	local transparency = 1 - V.edge * alpha
	for _, band in bands do
		band.BackgroundTransparency = transparency
	end
end

return AimVignette
