--!strict
-- The Locker v3's own room (vault/01 Design/Loadout and Power Deck.md → step 2 follow-up; owner 2026-11-26:
-- "I can walk around and see myself in the locker ... maybe a separate area"). A copy of the lobby's Locker room
-- (Workspace.LobbyV5.Shell.Locker) 3,000 studs away (OFFSET), with nothing anyone can walk into: no plinth circle,
-- no Armorer NPC, no LockerZone trigger, no hallway floor link. Its LobbyGunDisplay anchors are copied too, so the
-- wall shows the player's own skins (Controllers/LobbyGunDisplays fills every tagged anchor).
-- Controllers/LockerV3Controller points its camera here (ROOM_OFFSET must match OFFSET).
-- Run in Edit mode (command bar or MCP execute_luau); re-running rebuilds it from the current lobby room.

local OFFSET = Vector3.new(0, 0, -3000)
local DROP = { "GunCircle", "Armorer", "LockerZone", "Line_N", "Line_S", "FloorLink" }

local lobby = workspace:FindFirstChild("LobbyV5")
local shell = lobby and lobby:FindFirstChild("Shell")
local source = shell and shell:FindFirstChild("Locker")
assert(source and source:IsA("Model"), "Workspace.LobbyV5.Shell.Locker missing")

local old = workspace:FindFirstChild("LockerV3Room")
if old then
	old:Destroy()
end
local room = source:Clone()
room.Name = "LockerV3Room"
for _, name in DROP do
	for _, d in room:GetDescendants() do
		if d.Name == name and d.Parent then
			d:Destroy()
		end
	end
end
for _, d in room:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") then
		d:Destroy()
	end
end
room:PivotTo(room:GetPivot() + OFFSET)
room.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always on every client: no wait when the Locker opens
room:SetAttribute(
	"Note",
	"Locker v3 stage (tools/studio/BuildLockerRoom.luau); not reachable on foot"
)
room.Parent = workspace
local parts = 0
for _, d in room:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return "LockerV3Room built: " .. parts .. " parts at " .. tostring(room:GetPivot().Position)
