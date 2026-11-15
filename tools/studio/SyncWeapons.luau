--!strict
-- Copies the guns and skins from the match place to the Lobby place, exactly
-- (vault/02 Art/UI Locker.md → Weapons in the Lobby). The Lobby's Locker shows
-- the real models, so whenever guns or skins change in the match place:
--
--   1. MATCH place (Edit), command bar: run this with MODE = "push"
--   2. LOBBY place (Edit), command bar: run this with MODE = "pull", then save
--
-- Both places are in one universe, so they share DataStores: push packs
-- ReplicatedStorage.Weapons + WeaponSkins with SerializationService, base64s
-- it and stores it in the dev-only key DevWeaponSync/"blob" (about 2.5 MB of
-- the 4 MB limit in 2026-11; split it if it grows). Pull unpacks it and
-- replaces both folders, keeping the old ones in ServerStorage.WeaponSyncBackup
-- until the next pull. Needs "Enable Studio Access to API Services". (A local
-- HTTP relay was tried first: the Studio assistant's HTTP allowlist blocks
-- localhost.) Studio-owned folders, so this is a command-bar tool only.

local MODE: "push" | "pull" = "push"
local FOLDERS = { "Weapons", "WeaponSkins" }

local DataStoreService = game:GetService("DataStoreService")
local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SerializationService = game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")

local store = DataStoreService:GetDataStore("DevWeaponSync")

-- DataStore calls throw on throttling or an outage: retry with backoff.
local function retry<T>(what: string, fn: () -> T): T
	local delay = 1
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return result
		end
		warn(`[SyncWeapons] {what} failed ({attempt}/4): {result}`)
		task.wait(delay)
		delay *= 2
	end
	error(`[SyncWeapons] {what} failed 4 times; nothing changed`)
end

local function count(list: { Instance }): number
	local n = 0
	for _, i in list do
		n += 1 + #i:GetDescendants()
	end
	return n
end

if MODE == "push" then
	local list: { Instance } = {}
	for _, name in FOLDERS do
		table.insert(list, ReplicatedStorage:WaitForChild(name))
	end
	local packed = SerializationService:SerializeInstancesAsync(list)
	local text = buffer.tostring(EncodingService:Base64Encode(packed))
	assert(#text < 4_000_000, `blob is {#text} chars: split it across keys`)
	retry("SetAsync", function()
		return store:SetAsync("blob", { at = os.time(), instances = count(list), data = text })
	end)
	print(`[SyncWeapons] pushed {count(list)} instances ({#text} chars)`)
else
	local rec = retry("GetAsync", function()
		return store:GetAsync("blob")
	end)
	assert(type(rec) == "table" and type(rec.data) == "string", "nothing pushed yet")
	local packed = EncodingService:Base64Decode(buffer.fromstring(rec.data))
	local got = SerializationService:DeserializeInstancesAsync(packed)
	local backup = ServerStorage:FindFirstChild("WeaponSyncBackup")
	if backup then
		backup:Destroy()
	end
	local keep = Instance.new("Folder")
	keep.Name = "WeaponSyncBackup"
	keep.Parent = ServerStorage
	for _, folder in got do
		local old = ReplicatedStorage:FindFirstChild(folder.Name)
		if old then
			old.Parent = keep
		end
		folder.Parent = ReplicatedStorage
	end
	print(`[SyncWeapons] pulled {count(got)} instances (pushed {rec.instances}); save the place`)
end
