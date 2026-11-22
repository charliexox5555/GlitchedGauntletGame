--!strict
-- Where the match's Studio-built screens live (place merge 2026-11-21, vault/04 Tech/Place Merge Plan.md).
-- In the merged place they sit in ReplicatedStorage.MatchScreens, not StarterGui (StarterGui would copy them to
-- every lobby player); the match client copies them into PlayerGui when it starts (client/init.client.luau).
-- The retired match place still has them in StarterGui, so lookups fall back to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local MatchScreens = {}

MatchScreens.FOLDER = "MatchScreens"

-- Screens a controller clones itself (it owns the copy); the client doesn't copy these in.
MatchScreens.SELF_COPIED = { MapVote = true }

function MatchScreens.folder(): Folder?
	local folder = ReplicatedStorage:FindFirstChild(MatchScreens.FOLDER)
	return if folder and folder:IsA("Folder") then folder else nil
end

-- The template screen named `name` (yields until it exists).
function MatchScreens.source(name: string): ScreenGui
	local folder = MatchScreens.folder()
	local found = if folder then folder:FindFirstChild(name) else StarterGui:FindFirstChild(name)
	if not found then
		found = if folder then folder:WaitForChild(name) else StarterGui:WaitForChild(name)
	end
	return found :: ScreenGui
end

-- Copies every screen (bar the self-copied ones) into `playerGui`, replacing older copies. Returns the copies.
function MatchScreens.install(playerGui: Instance): { ScreenGui }
	local folder = MatchScreens.folder()
	local made: { ScreenGui } = {}
	if not folder then
		return made
	end
	for _, source in folder:GetChildren() do
		if source:IsA("ScreenGui") and not MatchScreens.SELF_COPIED[source.Name] then
			local old = playerGui:FindFirstChild(source.Name)
			if old then
				old:Destroy()
			end
			local copy = source:Clone()
			copy.ResetOnSpawn = false
			copy.Parent = playerGui
			table.insert(made, copy)
		end
	end
	return made
end

return MatchScreens
