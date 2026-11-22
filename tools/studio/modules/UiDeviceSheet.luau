--!strict
-- Preview a Studio-built screen at a device size, with that device family's
-- overrides applied (Shared/UiLayout), drawn big in the Studio viewport for a
-- screen_capture (vault/04 Tech/UI Architecture.md §7).
-- A ModuleScript: install as ServerStorage.UiTools.UiDeviceSheet (Studio only).
--   local sheet = require(game.ServerStorage.UiTools.UiDeviceSheet:Clone())
--   sheet.show("Match", "KillFeed", 844, 390, "Phone", true)  -- true: show hidden parts
--   sheet.clear()
-- Families: "Phone" | "Tablet" | "Desktop" | "Console".

local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- a fresh copy: Studio caches required modules, and Rojo updates this one
local UiLayout = require(ReplicatedStorage.Shared.UiLayout:Clone())

local Sheet = {}

function Sheet.clear()
	local old = StarterGui:FindFirstChild("UiDeviceSheet")
	if old then
		old:Destroy()
	end
end

function Sheet.show(
	group: string,
	name: string,
	w: number,
	h: number,
	family: string,
	showAll: boolean?
): string
	Sheet.clear()
	local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
	local folder = ui and ui:FindFirstChild(group)
	local screen = (folder and folder:FindFirstChild(name)) or StarterGui:FindFirstChild(name)
	assert(screen and screen:IsA("ScreenGui"), `no ScreenGui {group}.{name}`)
	local gui = Instance.new("ScreenGui")
	gui.Name = "UiDeviceSheet"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ZIndexBehavior = screen.ZIndexBehavior
	gui.DisplayOrder = 100
	local root = Instance.new("Frame")
	root.Name = "Device"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(w, h)
	root.BackgroundTransparency = 1
	root.ClipsDescendants = true
	root.Parent = gui
	local vp = workspace.CurrentCamera.ViewportSize
	local scale = Instance.new("UIScale")
	scale.Scale = math.min(vp.X * 0.97 / w, vp.Y * 0.95 / h)
	scale.Parent = root
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Parent = root
	local copy = screen:Clone()
	for _, c in copy:GetChildren() do
		if showAll and c:IsA("GuiObject") then
			c.Visible = true
		end
		c.Parent = root
	end
	copy:Destroy()
	gui.Parent = StarterGui
	StarterGui.ShowDevelopmentGui = true
	UiLayout.applyAs(root, family :: any, h)
	return `previewing {group}.{name} at {w}x{h} as {family}`
end

return Sheet
