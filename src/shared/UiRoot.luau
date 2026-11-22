--!strict
-- The one home for the Studio-built UI (vault/04 Tech/UI Architecture.md §3-4).
--
--   StarterPlayer.StarterPlayerScripts.UI   (Studio-owned; Rojo ignores it)
--     Lobby/      the lobby's ScreenGuis
--     Match/      the match's ScreenGuis
--     Templates/  rows, cells and slots, one folder per group (Lobby, KillFeed, TopBar, ...)
--
-- Roblox copies StarterPlayerScripts into each player's PlayerScripts, so the
-- client reads it there (client-only, like RIVALS' UserInterface folder).
-- Nothing lives in StarterGui any more: each client copies its group's
-- screens into PlayerGui when it starts (`mount`).
--
-- Editing in Studio: a ScreenGui only draws in the edit viewport under
-- StarterGui, so tools/studio/UiEdit.luau "parks" a screen (or the Templates
-- folder) there and stores it back. In a Studio playtest a parked copy wins,
-- so you see your edit, and a warning says it is parked.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local UiLayout = require(script.Parent.UiLayout)

local UiRoot = {}

export type Group = "Lobby" | "Match"

UiRoot.FOLDER = "UI"
UiRoot.TEMPLATES = "Templates"
UiRoot.PARKED_ATTRIBUTE = "UiEditFrom" -- set by UiEdit on a parked screen
UiRoot.PARKED_TEMPLATES = "UiEdit_Templates" -- the ScreenGui UiEdit wraps Templates in

-- Screens a controller clones itself (it owns the copy); `mount` skips these.
UiRoot.SELF_COPIED = table.freeze({ MapVote = true })

-- Layers (§4). A screen opts in by setting its `Layer` attribute (and an
-- optional `LayerOrder` 0-9); until then `mount` leaves its settings alone.
export type Layer = { insets: Enum.ScreenInsets, order: number }
UiRoot.LAYERS = table.freeze({
	Backdrop = { insets = Enum.ScreenInsets.None, order = 0 },
	Hud = { insets = Enum.ScreenInsets.DeviceSafeInsets, order = 10 },
	Touch = { insets = Enum.ScreenInsets.DeviceSafeInsets, order = 15 },
	Menu = { insets = Enum.ScreenInsets.DeviceSafeInsets, order = 20 },
	Topbar = { insets = Enum.ScreenInsets.TopbarSafeInsets, order = 30 },
	Modal = { insets = Enum.ScreenInsets.DeviceSafeInsets, order = 40 },
	Overlay = { insets = Enum.ScreenInsets.None, order = 50 },
} :: { [string]: Layer })

local function root(): Instance
	local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	return scripts:WaitForChild(UiRoot.FOLDER)
end

-- A screen parked in StarterGui for editing (Studio only), or nil.
local function parked(name: string): ScreenGui?
	if not RunService:IsStudio() then
		return nil
	end
	local found = StarterGui:FindFirstChild(name)
	if found and found:IsA("ScreenGui") and found:GetAttribute(UiRoot.PARKED_ATTRIBUTE) ~= nil then
		return found
	end
	return nil
end

-- Applies the screen's layer, if it has one (§4).
function UiRoot.applyLayer(gui: ScreenGui)
	local name = gui:GetAttribute("Layer")
	local layer = if typeof(name) == "string" then UiRoot.LAYERS[name] else nil
	if not layer then
		return
	end
	local extra = gui:GetAttribute("LayerOrder")
	gui.ScreenInsets = layer.insets
	gui.IgnoreGuiInset = true
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = layer.order
		+ (if typeof(extra) == "number" then math.clamp(extra, 0, 9) else 0)
end

-- The template screen `name` of `group` (yields until it exists). A parked
-- copy wins in Studio.
function UiRoot.source(group: Group, name: string): ScreenGui
	local edit = parked(name)
	if edit then
		return edit
	end
	return root():WaitForChild(group):WaitForChild(name) :: ScreenGui
end

-- Copies every screen of `group` (bar the self-copied ones) into `playerGui`,
-- replacing older copies. Returns the copies.
function UiRoot.mount(group: Group, playerGui: Instance): { ScreenGui }
	local made: { ScreenGui } = {}
	local folder = root():WaitForChild(group, 10)
	if not folder then
		warn(`[UiRoot] PlayerScripts.{UiRoot.FOLDER}.{group} missing`)
		return made
	end
	for _, source in folder:GetChildren() do
		if not source:IsA("ScreenGui") or UiRoot.SELF_COPIED[source.Name] then
			continue
		end
		if parked(source.Name) then
			-- Roblox copies StarterGui into PlayerGui itself: use that copy.
			warn(
				`[UiRoot] {source.Name} is parked in StarterGui (tools/studio/UiEdit.luau); showing the parked copy`
			)
			continue
		end
		local old = playerGui:FindFirstChild(source.Name)
		if old then
			old:Destroy()
		end
		local copy = source:Clone()
		copy.ResetOnSpawn = false
		UiRoot.applyLayer(copy)
		copy.Parent = playerGui
		UiLayout.watch(copy) -- per-device overrides (Shared/UiLayout)
		table.insert(made, copy)
	end
	return made
end

-- The Templates folder (yields until it exists). In Studio, a parked
-- Templates folder wins.
function UiRoot.templates(): Instance
	local edit = UiRoot.findTemplates(0)
	if edit then
		return edit
	end
	return root():WaitForChild(UiRoot.TEMPLATES)
end

-- The Templates folder, waiting up to `timeout` seconds (0 = don't wait).
function UiRoot.findTemplates(timeout: number?): Instance?
	if RunService:IsStudio() then
		local holder = StarterGui:FindFirstChild(UiRoot.PARKED_TEMPLATES)
		local inside = holder and holder:FindFirstChild(UiRoot.TEMPLATES)
		if inside then
			return inside
		end
	end
	local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	if timeout == 0 then
		local home = scripts:FindFirstChild(UiRoot.FOLDER)
		return home and home:FindFirstChild(UiRoot.TEMPLATES)
	end
	local home = scripts:WaitForChild(UiRoot.FOLDER, timeout or 15)
	return home and home:WaitForChild(UiRoot.TEMPLATES, timeout or 15)
end

return UiRoot
