--!strict
-- Build a map from data and keep the data (MapTools.Data.<id>, JSON) so a tweak can rebuild without a re-paste.
-- Always builds with a fresh copy of MapTools.Build (require caches the module across edits).
-- Installed as ServerStorage.MapTools.Run. Usage: require(MapTools.Run)(data) or require(MapTools.Run)("Bunker3", true).
local HttpService = game:GetService("HttpService")
return function(D: any, fromStore: boolean?): string
	local T = script.Parent
	if fromStore then
		D = HttpService:JSONDecode((T :: any).Data[D].Value)
	end
	local f = T:FindFirstChild("Data") or Instance.new("Folder")
	f.Name = "Data"
	f.Parent = T
	local v = f:FindFirstChild(D.id) :: StringValue? or Instance.new("StringValue")
	v.Name = D.id
	v.Value = HttpService:JSONEncode(D)
	v.Parent = f
	local c = T.Build:Clone()
	c.Name = "BuildFresh"
	c.Parent = T
	local ok, r = pcall(function()
		return require(c)(D)
	end)
	c:Destroy()
	if not ok then
		error(r)
	end
	return r
end
