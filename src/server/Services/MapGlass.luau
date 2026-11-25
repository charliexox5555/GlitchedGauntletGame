--!strict

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BallisticGlass = require(Shared.Util.BallisticGlass)
local Net = require(Shared.Net)

local MapGlass = {}
local RESTORE_TRANSPARENCY = "GlassRestoreTransparency"

function MapGlass.shatter(pane: BasePart, position: Vector3, normal: Vector3)
	if pane:GetAttribute(RESTORE_TRANSPARENCY) ~= nil then
		return
	end
	pane:SetAttribute(RESTORE_TRANSPARENCY, pane.Transparency)
	pane.Transparency = 1
	pane.CanCollide = false
	pane.CanQuery = false
	Net.unreliable("GlassShatter")
		:FireAllClients(position, normal, pane.CFrame, pane.Size, pane.Color)
end

function MapGlass.reset(map: Model)
	for _, pane in CollectionService:GetTagged(BallisticGlass.TAG) do
		if pane:IsA("BasePart") and pane:IsDescendantOf(map) then
			local transparency = pane:GetAttribute(RESTORE_TRANSPARENCY)
			if typeof(transparency) == "number" then
				pane.Transparency = transparency
				pane.CanQuery = true
				pane.CanCollide = true
				pane:SetAttribute(RESTORE_TRANSPARENCY, nil)
			end
		end
	end
end

return MapGlass
