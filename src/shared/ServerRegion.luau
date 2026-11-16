--!strict
-- Where this server is, for the top bar readout (Shared/NetStats). The server
-- looks it up once (Config/NetStats REGION_URL: sends only the server's own
-- request, no player data) and publishes it as the ReplicatedStorage
-- attribute "ServerRegion", e.g. "VIRGINIA, US". In Studio, with the lookup
-- off, or if it fails: "SERVER " and the first characters of the JobId.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config.NetStats)

local ServerRegion = {}

ServerRegion.ATTRIBUTE = "ServerRegion"

local function fallback(): string
	if RunService:IsStudio() then
		return "STUDIO"
	end
	return "SERVER " .. string.upper(string.sub(game.JobId, 1, 4))
end

local function lookup(): string?
	local ok, body = pcall(HttpService.GetAsync, HttpService, Config.REGION_URL)
	if not ok or typeof(body) ~= "string" then
		return nil
	end
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
	if not decoded or typeof(data) ~= "table" then
		return nil
	end
	local region = if typeof(data.region) == "string" then data.region else nil
	local country = if typeof(data.country) == "string" then data.country else nil
	if region and country then
		return string.upper(string.sub(region, 1, 24) .. ", " .. string.sub(country, 1, 3))
	end
	return if country then string.upper(string.sub(country, 1, 24)) else nil
end

-- Server only: publish the region (yields for the lookup in its own thread).
function ServerRegion.start()
	assert(RunService:IsServer(), "ServerRegion.start is server-only")
	ReplicatedStorage:SetAttribute(ServerRegion.ATTRIBUTE, fallback())
	if Config.REGION_LOOKUP and not RunService:IsStudio() then
		task.spawn(function()
			local found = lookup()
			if found then
				ReplicatedStorage:SetAttribute(ServerRegion.ATTRIBUTE, found)
			end
		end)
	end
end

function ServerRegion.get(): string
	local v = ReplicatedStorage:GetAttribute(ServerRegion.ATTRIBUTE)
	return if typeof(v) == "string" then v else "• • •"
end

function ServerRegion.changed(): RBXScriptSignal
	return ReplicatedStorage:GetAttributeChangedSignal(ServerRegion.ATTRIBUTE)
end

return ServerRegion
