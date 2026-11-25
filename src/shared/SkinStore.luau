--!strict
-- Gun skins on demand (vault/05 Production/Handoff - Onboarding and Bots.md → gun skins on demand). The skin
-- models no longer ship to every client on join:
--   server  every skin in ServerStorage.WeaponSkins/<Line>/<Gun> (Studio-owned); Services/SkinStoreService
--           publishes the manifest and copies asked-for models into the asking player's PlayerGui.SkinDelivery
--   client  SkinStore.model finds a delivered copy; a missing one is asked for (batched) and nil is returned
--           meanwhile, so callers show the stock gun; SkinStore.arrived fires (line, gun) when it lands
--   both    SkinStore.has(line, gun) answers "does this skin exist and is it ready" from the models (server)
--           or the manifest (client), for Locker lists, cases and the shop
-- Before the Studio move (or in a place without it) the old ReplicatedStorage.WeaponSkins still works.
-- The `_Casing` shell templates stay in ReplicatedStorage.WeaponSkins (Util/ShellFx).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StateValues = require(script.Parent.StateValues)

local SkinStore = {}

SkinStore.FOLDER = "WeaponSkins"
SkinStore.MANIFEST = "SkinManifest" -- ReplicatedStorage StringValue: JSON { [line] = { gun, ... } }
SkinStore.DELIVERY = "SkinDelivery" -- PlayerGui Folder: <Line>/<Gun> copies for that player
SkinStore.REMOTE = "SkinRequest" -- LobbyRemotes: ({ { line, gun } }) client -> server
SkinStore.MAX_PER_REQUEST = 64
SkinStore.CASING = "_Casing"

local IS_SERVER = RunService:IsServer()

local arrivedEvent = Instance.new("BindableEvent")
-- Client: (line, gun) when a requested skin has landed.
SkinStore.arrived = arrivedEvent.Event

-- The old replicated folder, if it still holds skin lines (not just _Casing).
local function legacyRoot(): Instance?
	local f = ReplicatedStorage:FindFirstChild(SkinStore.FOLDER)
	if not f then
		return nil
	end
	for _, c in f:GetChildren() do
		if c.Name ~= SkinStore.CASING then
			return f
		end
	end
	return nil
end

local function serverRoot(): Instance?
	local ss = game:GetService("ServerStorage")
	return ss:FindFirstChild(SkinStore.FOLDER) or legacyRoot()
end

local deliveryFolder: Instance? = nil
local function deliveryRoot(): Instance?
	if deliveryFolder and deliveryFolder.Parent then
		return deliveryFolder
	end
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local f = gui and gui:FindFirstChild(SkinStore.DELIVERY)
	deliveryFolder = f
	return f
end

local function ready(m: Instance?): Model?
	if m and m:IsA("Model") and StateValues.get(m, "SkinReady") == true then
		return m
	end
	return nil
end

local function findModel(root: Instance?, line: string, name: string): Model?
	local folder = root and root:FindFirstChild(line)
	return ready(folder and folder:FindFirstChild(name))
end

local function clientModel(line: string, name: string): Model?
	return findModel(deliveryRoot(), line, name) or findModel(legacyRoot(), line, name)
end

-- Manifest ---------------------------------------------------------------------

local manifest: { [string]: { [string]: boolean } }? = nil
local manifestText = ""

local function readManifest(): { [string]: { [string]: boolean } }
	local v = ReplicatedStorage:FindFirstChild(SkinStore.MANIFEST)
	local text = if v and v:IsA("StringValue") then v.Value else ""
	if manifest and text == manifestText then
		return manifest
	end
	local out: { [string]: { [string]: boolean } } = {}
	local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
	if ok and typeof(data) == "table" then
		for line, guns in data :: { [unknown]: unknown } do
			if typeof(line) == "string" and typeof(guns) == "table" then
				local set: { [string]: boolean } = {}
				for _, g in guns :: { unknown } do
					if typeof(g) == "string" then
						set[g] = true
					end
				end
				out[line] = set
			end
		end
	end
	manifest, manifestText = out, text
	return out
end

-- Server: builds and publishes the manifest from the stored models.
function SkinStore.publishManifest(): number
	local root = serverRoot()
	local data: { [string]: { string } } = {}
	local count = 0
	if root then
		for _, lineFolder in root:GetChildren() do
			if lineFolder.Name == SkinStore.CASING then
				continue
			end
			local list: { string } = {}
			for _, m in lineFolder:GetChildren() do
				if ready(m) then
					table.insert(list, m.Name)
					count += 1
				end
			end
			if #list > 0 then
				data[lineFolder.Name] = list
			end
		end
	end
	local v = ReplicatedStorage:FindFirstChild(SkinStore.MANIFEST)
	if not (v and v:IsA("StringValue")) then
		v = Instance.new("StringValue")
		v.Name = SkinStore.MANIFEST
		v.Parent = ReplicatedStorage
	end
	(v :: StringValue).Value = HttpService:JSONEncode(data)
	return count
end

-- The stored model's name for a gun on a line (the PopCircuit knife is the Bat).
function SkinStore.modelName(gun: string, line: string): string
	return if gun == "Knife" and line == "PopCircuit" then "Bat" else gun
end

-- Does this skin exist and is it ready (`name` = the stored model's name, SkinStore.modelName)?
function SkinStore.has(line: string, name: string): boolean
	if IS_SERVER then
		return findModel(serverRoot(), line, name) ~= nil
	end
	local set = readManifest()[line]
	if manifestText ~= "" then
		return set ~= nil and set[name] == true
	end
	return clientModel(line, name) ~= nil
end

-- Client requests ------------------------------------------------------------------

local requested: { [string]: number } = {} -- "line/name" -> os.clock() of last request
local REQUEST_RETRY = 3
local queue: { { string } } = {}
local flushing = false

local function key(line: string, name: string): string
	return line .. "/" .. name
end

local function flush()
	flushing = false
	if #queue == 0 then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	local remote = folder and folder:FindFirstChild(SkinStore.REMOTE)
	if not (remote and remote:IsA("RemoteEvent")) then
		-- remotes not here yet: try again shortly
		flushing = true
		task.delay(1, flush)
		return
	end
	while #queue > 0 do
		local batch: { { string } } = {}
		while #queue > 0 and #batch < SkinStore.MAX_PER_REQUEST do
			table.insert(batch, table.remove(queue, 1) :: { string })
		end
		remote:FireServer(batch)
	end
end

-- Client: ask for skins (line, model name) that aren't here yet. Batched; retries if missing.
function SkinStore.want(pairs: { { string } })
	if IS_SERVER then
		return
	end
	local listed = readManifest()
	local now = os.clock()
	for _, p in pairs do
		local line, name = p[1], p[2]
		local k = if typeof(line) == "string" and typeof(name) == "string"
			then key(line, name)
			else ""
		local last = requested[k]
		if
			typeof(line) == "string"
			and typeof(name) == "string"
			and line ~= "Stock"
			and (not last or now - last >= REQUEST_RETRY)
			and listed[line]
			and listed[line][name]
			and not clientModel(line, name)
		then
			requested[k] = now
			table.insert(queue, { line, name })
		end
	end
	if #queue > 0 and not flushing then
		flushing = true
		task.defer(flush)
	end
end

-- The skin model (stored name) on `line`, or nil. On a client a missing one is asked for.
function SkinStore.model(line: string, name: string): Model?
	if IS_SERVER then
		return findModel(serverRoot(), line, name)
	end
	local found = clientModel(line, name)
	if not found then
		SkinStore.want({ { line, name } })
	end
	return found
end

-- Client: waits up to `timeout` seconds for a skin; returns it or nil.
function SkinStore.await(line: string, name: string, timeout: number): Model?
	local found = SkinStore.model(line, name)
	local deadline = os.clock() + timeout
	while not found and os.clock() < deadline do
		task.wait(0.1)
		found = SkinStore.model(line, name)
	end
	return found
end

-- Client: fire `arrived` for each model as it lands in the delivery container
-- (watches ChildAdded on PlayerGui too so a recreated container is always hooked).
if not IS_SERVER then
	task.spawn(function()
		local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local hooked: { [Instance]: boolean } = {}
		local function watchLine(lineFolder: Instance)
			if hooked[lineFolder] then
				return
			end
			hooked[lineFolder] = true
			local function landed(m: Instance)
				if m:IsA("Model") then
					-- a model arrives with its parts; give them a frame to finish replicating
					task.defer(function()
						arrivedEvent:Fire(lineFolder.Name, m.Name)
					end)
				end
			end
			for _, m in lineFolder:GetChildren() do
				landed(m)
			end
			lineFolder.ChildAdded:Connect(landed)
		end
		local function watchContainer(folder: Instance)
			if folder.Name ~= SkinStore.DELIVERY or hooked[folder] then
				return
			end
			hooked[folder] = true
			deliveryFolder = folder
			for _, l in folder:GetChildren() do
				watchLine(l)
			end
			folder.ChildAdded:Connect(watchLine)
		end
		local existing = gui:FindFirstChild(SkinStore.DELIVERY)
		if existing then
			watchContainer(existing)
		end
		gui.ChildAdded:Connect(watchContainer)
	end)
end

return SkinStore
