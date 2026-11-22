--!strict
-- Turns a content-sized HUD screen's 1920 x 1080 canvas (Offset + a "Fit"
-- UIScale) into a fit canvas (Shared/UiLayout): the canvas gets FitCanvas =
-- true and a Scale size, and each of its direct children keeps its pixel size
-- but gets a Scale position (anchor kept), so it stays at its place on any
-- screen while UiLayout scales the whole design. Use it for screens whose
-- rows and strips size to their content (death screen, status tray); use
-- UiToScale for fixed layouts (menus).
-- A ModuleScript: install as ServerStorage.UiTools.UiFitCanvas (Studio only).
--   require(game.ServerStorage.UiTools.UiFitCanvas:Clone())("Match", "DeathScreen", "Canvas", 1.6, 1.2)
-- Arguments: group, screen name, canvas name, phone boost, tablet boost.

local StarterPlayer = game:GetService("StarterPlayer")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local DESIGN = Vector2.new(1920, 1080)

return function(
	group: string,
	name: string,
	canvasName: string,
	phoneBoost: number,
	tabletBoost: number
): string
	local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
	local folder = ui and ui:FindFirstChild(group)
	local screen = folder and folder:FindFirstChild(name)
	assert(screen and screen:IsA("ScreenGui"), `no ScreenGui {group}.{name}`)
	local canvas = screen:FindFirstChild(canvasName)
	assert(canvas and canvas:IsA("GuiObject"), `no canvas {canvasName}`)
	assert(canvas:GetAttribute("FitCanvas") ~= true, "already a fit canvas")
	local fit = canvas:FindFirstChild("Fit")
	assert(fit and fit:IsA("UIScale"), "the canvas has no Fit UIScale")
	local recording = ChangeHistoryService:TryBeginRecording("UiFitCanvas " .. name)
	local size = Vector2.new(
		canvas.Size.X.Offset + canvas.Size.X.Scale * DESIGN.X,
		canvas.Size.Y.Offset + canvas.Size.Y.Scale * DESIGN.Y
	)
	local moved = 0
	for _, c in canvas:GetChildren() do
		if c:IsA("GuiObject") then
			local p = c.Position
			c.Position =
				UDim2.fromScale(p.X.Scale + p.X.Offset / size.X, p.Y.Scale + p.Y.Offset / size.Y)
			moved += 1
		end
	end
	canvas:SetAttribute("FitCanvas", true)
	canvas:SetAttribute("PhoneBoost", phoneBoost)
	canvas:SetAttribute("TabletBoost", tabletBoost)
	canvas:SetAttribute("Retired", nil)
	fit:SetAttribute("Retired", nil)
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	fit.Scale = 1
	screen:SetAttribute("FitCanvas", canvasName)
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	local msg =
		`[UiFitCanvas] {group}.{name}.{canvasName}: {moved} groups on Scale positions, boosts phone {phoneBoost} / tablet {tabletBoost}`
	print(msg)
	return msg
end
