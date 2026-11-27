--!strict
-- Edit a Studio-built screen (vault/04 Tech/UI Architecture.md §3).
--
-- The UI lives in StarterPlayer.StarterPlayerScripts.UI (Lobby / Match / Templates), and the lobby-only screens
-- (Shop, Locker, Battle Pass, ...) in ServerStorage.LobbyUI, which only a lobby server hands to its clients
-- (Shared/UiRoot LOBBY_ONLY, 2026-11-27). Old and design screens are in ServerStorage.UiArchive (Mockups, LockerV2).
-- Studio doesn't draw any of these. This parks a screen in StarterGui
-- so it shows in the edit viewport, and stores it back when you're done.
-- While a screen is parked, a Studio playtest shows the parked copy
-- (Shared/UiRoot) and warns. Store everything back before you save the place.
--
-- Use: set ACTION and NAME below, paste the whole file into the Command Bar.
--   ACTION = "park",  NAME = "Shop"       -- show one screen (from any of the homes below)
--   ACTION = "park",  NAME = "Templates"  -- show the row/cell templates
--   ACTION = "store", NAME = "*"          -- put everything parked back
--   ACTION = "list",  NAME = ""           -- what is where

local ACTION = "list"
local NAME = ""

local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local PARKED = "UiEditFrom" -- same as UiRoot.PARKED_ATTRIBUTE
local TEMPLATE_HOLDER = "UiEdit_Templates" -- same as UiRoot.PARKED_TEMPLATES

local ui = StarterPlayer.StarterPlayerScripts:FindFirstChild("UI")
if not ui then
	warn("[UiEdit] StarterPlayer.StarterPlayerScripts.UI is missing")
	return "missing UI folder"
end

-- Where each group's screens live (the name is stored on a parked screen, so `store` puts it back).
local GROUPS = { "Lobby", "LobbyOnly", "Match", "Archive/Mockups" }
local function home(group: string, make: boolean?): Instance?
	if group == "LobbyOnly" then
		local f = ServerStorage:FindFirstChild("LobbyUI")
		if not f and make then
			f = Instance.new("Folder")
			f.Name = "LobbyUI"
			f.Parent = ServerStorage
		end
		return f
	elseif group == "Archive/Mockups" then
		local archive = ServerStorage:FindFirstChild("UiArchive")
		return archive and archive:FindFirstChild("Mockups")
	end
	local f = ui:FindFirstChild(group)
	if not f and make then
		f = Instance.new("Folder")
		f.Name = group
		f.Parent = ui
	end
	return f
end

local function park(name: string): string
	if name == "Templates" then
		local templates = ui:FindFirstChild("Templates")
		if not templates then
			return "no Templates folder (already parked?)"
		end
		local holder = Instance.new("ScreenGui")
		holder.Name = TEMPLATE_HOLDER
		holder.ResetOnSpawn = false
		holder.Enabled = true
		holder:SetAttribute(PARKED, "Templates")
		templates.Parent = holder
		holder.Parent = StarterGui
		return "parked Templates (StarterGui." .. TEMPLATE_HOLDER .. ")"
	end
	for _, group in GROUPS do
		local folder = home(group)
		local gui = folder and folder:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			gui:SetAttribute(PARKED, group)
			gui:SetAttribute("UiEditWasEnabled", gui.Enabled)
			gui.Enabled = true
			gui.Parent = StarterGui
			return `parked {group}.{name}`
		end
	end
	return `no screen named {name} in UI.Lobby, ServerStorage.LobbyUI, UI.Match or UiArchive.Mockups`
end

local function store(name: string): { string }
	local done = {}
	for _, gui in StarterGui:GetChildren() do
		local from = gui:GetAttribute(PARKED)
		if
			typeof(from) ~= "string"
			or not (
				name == "*"
				or gui.Name == name
				or (name == "Templates" and gui.Name == TEMPLATE_HOLDER)
			)
		then
			continue
		end
		if gui.Name == TEMPLATE_HOLDER then
			local templates = gui:FindFirstChild("Templates")
			if templates then
				templates.Parent = ui
			end
			gui:Destroy()
			table.insert(done, "Templates")
		else
			local was = gui:GetAttribute("UiEditWasEnabled")
			if typeof(was) == "boolean" then
				(gui :: ScreenGui).Enabled = was
			end
			gui:SetAttribute(PARKED, nil)
			gui:SetAttribute("UiEditWasEnabled", nil)
			gui.Parent = home(from, true) or ui
			table.insert(done, `{from}.{gui.Name}`)
		end
	end
	return done
end

if ACTION == "park" then
	local r = park(NAME)
	print("[UiEdit] " .. r)
	return r
elseif ACTION == "store" then
	local done = store(NAME)
	print("[UiEdit] stored: " .. (if #done > 0 then table.concat(done, ", ") else "nothing parked"))
	return #done
end

local lines = {}
for _, group in GROUPS do
	local folder = home(group)
	local names = {}
	for _, c in (if folder then folder:GetChildren() else {}) do
		table.insert(names, c.Name)
	end
	table.sort(names)
	table.insert(lines, `{group}: {table.concat(names, ", ")}`)
end
local parkedNames = {}
for _, gui in StarterGui:GetChildren() do
	if gui:GetAttribute(PARKED) ~= nil then
		table.insert(parkedNames, gui.Name)
	end
end
table.insert(
	lines,
	"Parked in StarterGui: "
		.. (if #parkedNames > 0 then table.concat(parkedNames, ", ") else "none")
)
print("[UiEdit]\n" .. table.concat(lines, "\n"))
return table.concat(lines, "\n")
