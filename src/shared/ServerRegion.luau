--!strict
-- Where this server is, for the top bar readout (Shared/NetStats). The server
-- looks it up once (Config/NetStats REGION_URL: sends only the server's own
-- request, no player data) and publishes it as the ReplicatedStorage
-- attribute "ServerRegion", e.g. "France" (US: the state, "Virginia"). In
-- Studio "Studio"; with the lookup off or failed, "Server" and the JobId's
-- first characters.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config.NetStats)

local ServerRegion = {}

ServerRegion.ATTRIBUTE = "ServerRegion"

local function fallback(): string
	if RunService:IsStudio() then
		return "Studio"
	end
	return "Server " .. string.upper(string.sub(game.JobId, 1, 4))
end

-- Country names for the codes Roblox servers usually sit in (anything else
-- shows its code). US servers show their state, like RIVALS' "France" / state.
local COUNTRIES: { [string]: string } = {
	GB = "United Kingdom",
	DE = "Germany",
	FR = "France",
	NL = "Netherlands",
	PL = "Poland",
	ES = "Spain",
	IT = "Italy",
	SE = "Sweden",
	FI = "Finland",
	IE = "Ireland",
	JP = "Japan",
	SG = "Singapore",
	HK = "Hong Kong",
	KR = "South Korea",
	IN = "India",
	AU = "Australia",
	BR = "Brazil",
	CA = "Canada",
	MX = "Mexico",
	AE = "UAE",
	ZA = "South Africa",
	CL = "Chile",
	AR = "Argentina",
	TR = "Turkey",
}

local function lookup(): string?
	local ok, body = pcall(HttpService.GetAsync, HttpService, Config.REGION_URL)
	if not ok or typeof(body) ~= "string" then
		return nil
	end
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
	if not decoded or typeof(data) ~= "table" then
		return nil
	end
	local region = if typeof(data.region) == "string" then string.sub(data.region, 1, 24) else nil
	local country = if typeof(data.country) == "string" then string.sub(data.country, 1, 3) else nil
	if country == "US" and region then
		return region
	end
	return if country then COUNTRIES[country] or country else region
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
