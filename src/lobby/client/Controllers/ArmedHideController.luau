--!strict
-- Hides the lobby's screens while the player is armed (shared/PlayZone: the range or a pad duel) so the match HUD
-- has the screen, and brings back exactly the ones it hid on the way back to the lobby (place merge 2026-11-21,
-- vault/04 Tech/Place Merge Plan.md). The match client starts on the same zone change, so the screens up at that
-- moment are the lobby's (and Roblox's own); a lobby screen that turns itself on while armed is turned off again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local Router = require(script.Parent.Parent.Util.Router)

local ArmedHideController = {}

local player = Players.LocalPlayer
local hidden: { [LayerCollector]: RBXScriptConnection } = {}

local function hide()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, gui in playerGui:GetChildren() do
		-- lobby screens only (marked LobbyGui; 2026-11-23: a player arriving in a hosted server is in their match
		-- before every lobby screen is up, so "whatever is up now" missed the coins top bar)
		if
			gui:IsA("ScreenGui")
			and gui:GetAttribute("LobbyGui") == true
			and gui.Name ~= "Settings"
			and gui.Enabled
			and not hidden[gui]
		then
			gui.Enabled = false
			hidden[gui] = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if gui.Enabled and PlayZone.isArmed(player) then
					gui.Enabled = false
				end
			end)
		end
	end
end

local function show()
	for gui, connection in hidden do
		connection:Disconnect()
		if gui.Parent then
			gui.Enabled = true
		end
	end
	table.clear(hidden)
end

function ArmedHideController.start()
	PlayZone.onLocalChanged(function(zone)
		if zone == "Lobby" then
			show()
		else
			-- Close any open lobby menu first: the Locker holds a Scriptable camera while it's open, and a pad
			-- duel that started with it open left that player's camera stuck over the pad (tester, 2026-11-26).
			if Router.current() ~= nil then
				Router.close()
			end
			hide()
		end
	end)
	if PlayZone.isArmed(player) then
		hide()
	end
	-- a lobby screen mounted or turned on while armed goes away too
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(gui)
		if gui:IsA("ScreenGui") and PlayZone.isArmed(player) then
			task.defer(hide)
		end
	end)
end

return ArmedHideController
