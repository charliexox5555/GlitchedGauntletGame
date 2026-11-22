--!strict
-- Fits a copy of ReplicatedFirst.DuelsLoading to a screen (the loading screen v2; vault/05 Production/Handoff -
-- Stability, Loading and Preload.md → Phase 2). Used by src/first/LoadingScreen.client.luau (the join), the lobby's
-- MatchFoundController (the teleport copy) and DuelLoadingController (pad duels). Lives in ReplicatedFirst so the
-- join screen can use it before Shared replicates; its numbers come from Config/Loading (`cfg`).
--  * PC / console: the 1920 × 1080 design canvas scaled to fit.
--  * Phones in landscape (height under cfg.phoneHeight): the canvas cfg.phoneBoost bigger, so the words stay
--    readable, and the rows pulled closer (cfg.phoneY, design px) so nothing leaves the screen.

local LoadingLayout = {}

local DESIGN = Vector2.new(1920, 1080)

export type Cfg = {
	phoneHeight: number,
	phoneBoost: number,
	phoneY: { [string]: number }?,
}

-- The design y of each row as built (tools/studio/BuildDuelsLoading.luau), kept so a copy can switch back.
local ORIGINAL = "DesignY"

function LoadingLayout.fit(gui: ScreenGui, cfg: Cfg, size: Vector2?)
	local screen = size or gui.AbsoluteSize
	local canvas = gui:FindFirstChild("Canvas")
	local fit = canvas and canvas:FindFirstChild("Fit")
	if not (canvas and fit and fit:IsA("UIScale")) or screen.X <= 0 or screen.Y <= 0 then
		return
	end
	local phone = screen.Y < cfg.phoneHeight
	local s = math.min(screen.X / DESIGN.X, screen.Y / DESIGN.Y)
	fit.Scale = if phone then s * cfg.phoneBoost else s
	for _, item in canvas:GetChildren() do
		if not item:IsA("GuiObject") then
			continue
		end
		local designY = item:GetAttribute(ORIGINAL)
		if typeof(designY) ~= "number" then
			designY = item.Position.Y.Offset
			item:SetAttribute(ORIGINAL, designY)
		end
		local phoneY = cfg.phoneY and cfg.phoneY[item.Name]
		local y = if phone and phoneY then phoneY else designY :: number
		if item.Position.Y.Offset ~= y then
			item.Position = UDim2.new(item.Position.X, UDim.new(item.Position.Y.Scale, y))
		end
	end
end

return LoadingLayout
