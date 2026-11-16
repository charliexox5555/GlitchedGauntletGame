--!strict
-- Writes .rbxm backups of the installed rework props, exactly as they are in
-- ReplicatedStorage.Abilities (no rebuild), to art-source/abilities/Studio/.
--
-- 1. In a terminal: python tools/studio/receive_server.py
-- 2. In Studio (match place, Edit mode), Command Bar: paste this file's body
--    and press Enter. (The Studio MCP can't do it: its HttpService calls to
--    127.0.0.1 are blocked by the Assistant allowlist.)
-- Game Settings → Security → Allow HTTP Requests must be on.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

for _, id in { "Molly", "Frost", "Recon", "ReconDart", "Stim", "Recall", "ReworkVFX" } do
	local model = game:GetService("ReplicatedStorage").Abilities:FindFirstChild(id)
	if not model then
		warn(id, "missing")
		continue
	end
	local ok, err = pcall(function()
		local buf = SerializationService:SerializeInstancesAsync({ model })
		local b64 = buffer.tostring(EncodingService:Base64Encode(buf))
		local res = HttpService:RequestAsync({
			Url = "http://127.0.0.1:34999/save?path=art-source/abilities/Studio/" .. id .. ".rbxm",
			Method = "POST",
			Body = b64,
		})
		print(id, res.Body)
	end)
	if not ok then
		warn(id, err)
	end
end
