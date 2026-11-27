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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local UiLayout = require(script.Parent.UiLayout)
local InputGlyphs = require(script.Parent.InputGlyphs)
local ServerRole = require(script.Parent.ServerRole)

local UiRoot = {}

export type Group = "Lobby" | "Match"

UiRoot.FOLDER = "UI"
UiRoot.TEMPLATES = "Templates"
UiRoot.PARKED_ATTRIBUTE = "UiEditFrom" -- set by UiEdit on a parked screen
UiRoot.PARKED_TEMPLATES = "UiEdit_Templates" -- the ScreenGui UiEdit wraps Templates in

-- Screens a controller clones itself (it owns the copy); `mount` skips these.
UiRoot.SELF_COPIED = table.freeze({ MapVote = true })

-- Lobby-only screens (loading pass 2026-11-27): Studio keeps them in ServerStorage.LobbyUI, and only a lobby
-- server parents that folder into ReplicatedStorage (LobbyServer init), so reserved match servers never send
-- them. UI.Lobby in PlayerScripts keeps what a match client also uses (Settings, LobbyTasks).
UiRoot.LOBBY_ONLY = "LobbyUI" -- also the ReplicatedStorage attribute: "ready" | "none"
local LOBBY_WAIT = 15 -- s
-- Heavy pages their controller mounts on first open (`mount(group, playerGui, name)`), not at join.
UiRoot.LAZY = table.freeze({ Shop = true, BattlePass = true })

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

-- The lobby-only screens folder (ReplicatedStorage.LobbyUI) on a lobby server, else nil.
local function lobbyOnly(): Instance?
	if not ServerRole.isLobby() then
		return nil
	end
	local here = ReplicatedStorage:FindFirstChild(UiRoot.LOBBY_ONLY)
	if here then
		return here
	end
	-- The lobby server says whether the folder is coming ("ready") or not ("none": an older place keeps
	-- everything in UI.Lobby), so a client never stalls on a folder that won't come.
	local t0 = os.clock()
	while
		ReplicatedStorage:GetAttribute(UiRoot.LOBBY_ONLY) == nil
		and os.clock() - t0 < LOBBY_WAIT
	do
		task.wait(0.1)
	end
	if ReplicatedStorage:GetAttribute(UiRoot.LOBBY_ONLY) ~= "ready" then
		return nil
	end
	local found = ReplicatedStorage:WaitForChild(UiRoot.LOBBY_ONLY, LOBBY_WAIT)
	if not found then
		warn(
			`[UiRoot] ReplicatedStorage.{UiRoot.LOBBY_ONLY} missing (LobbyServer parents it from ServerStorage)`
		)
	end
	return found
end

-- The folders that hold `group`'s screens.
local function folders(group: Group): { Instance }
	local list: { Instance } = {}
	local own = root():WaitForChild(group, 10)
	if own then
		table.insert(list, own)
	else
		warn(`[UiRoot] PlayerScripts.{UiRoot.FOLDER}.{group} missing`)
	end
	if group == "Lobby" then
		local extra = lobbyOnly()
		if extra then
			table.insert(list, extra)
		end
	end
	return list
end

-- The template screen `name` of `group` (yields until it exists). A parked
-- copy wins in Studio.
function UiRoot.source(group: Group, name: string): ScreenGui
	local edit = parked(name)
	if edit then
		return edit
	end
	local own = root():WaitForChild(group)
	local here = own:FindFirstChild(name)
	if here then
		return here :: ScreenGui
	end
	local extra = if group == "Lobby" then lobbyOnly() else nil
	if extra then
		local found = extra:FindFirstChild(name)
		if found then
			return found :: ScreenGui
		end
	end
	return own:WaitForChild(name) :: ScreenGui
end

-- Copies every screen of `group` (bar the self-copied and lazy ones) into
-- `playerGui`, replacing older copies. `only` copies just that screen (a lazy
-- page's first open). Returns the copies.
function UiRoot.mount(group: Group, playerGui: Instance, only: string?): { ScreenGui }
	local made: { ScreenGui } = {}
	local sources: { Instance } = {}
	for _, folder in folders(group) do
		for _, s in folder:GetChildren() do
			table.insert(sources, s)
		end
	end
	for _, source in sources do
		if
			not source:IsA("ScreenGui")
			or UiRoot.SELF_COPIED[source.Name]
			or (only and source.Name ~= only)
			or (not only and UiRoot.LAZY[source.Name])
		then
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
		if group == "Lobby" then
			-- the match client's armed-zone cleanup never clears lobby screens (a player who arrives in a
			-- hosted server goes straight into their match, before these are mounted)
			copy:SetAttribute("LobbyGui", true)
		end
		UiRoot.applyLayer(copy)
		copy.Parent = playerGui
		UiLayout.watch(copy) -- per-device overrides (Shared/UiLayout)
		InputGlyphs.watch(copy) -- key hints follow the input (Shared/InputGlyphs)
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
