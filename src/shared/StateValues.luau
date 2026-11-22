--!strict
-- Runtime fields travel as individual StringValues. An empty string clears a
-- field without changing Instance parenting inside BindToSimulation callbacks.
-- Authored defaults are shared ModuleScript data, identified by tags that clones inherit.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local StateValues = {}
local FOLDER = "GauntletState"
local ASSET_TAG = "GauntletAuthoredData"
local ASSET_PREFIX = "GGAsset_"
local authored: { [string]: { [string]: any } } = {}
local byInstance: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" })
local decoded: { [StringValue]: { content: string, value: any } } = setmetatable(
	{},
	{ __mode = "k" }
)

-- Every data module, in every server: since the place merge (2026-11-21) one
-- place carries the lobby and the match objects. (The old per-PlaceId lists
-- left every match object without its data in the merged place.) Tags are
-- prefixed with their module's name, so they never collide.
local assets = script.Parent.Config:WaitForChild("AssetData")
local modules = {
	"LobbyInterface",
	"LobbyLocker",
	"LobbySkins",
	"LobbyWeapons",
	"LobbyWorld",
	"MatchAbilities",
	"MatchInterface",
	"MatchMaps",
	"MatchSettings",
	"MatchSkins",
	"MatchWeapons",
}
for _, name in modules do
	for tag, fields in require(assets:WaitForChild(name) :: ModuleScript) do
		authored[tag] = fields
	end
end

local function defaults(owner: Instance): { [string]: any }?
	local saved = byInstance[owner]
	if saved then
		return saved
	end
	if CollectionService:HasTag(owner, ASSET_TAG) then
		for _, tag in CollectionService:GetTags(owner) do
			local data = authored[tag]
			if data then
				byInstance[owner] = data
				return data
			end
		end
	end
	return nil
end

local function encode(value: any): string
	local kind = typeof(value)
	if value == nil then
		return ""
	elseif kind == "string" then
		return "s" .. value
	elseif kind == "boolean" then
		return if value then "t" else "f"
	elseif kind == "number" then
		if value == math.huge then
			return "+"
		elseif value == -math.huge then
			return "-"
		end
		return "n" .. string.format("%.17g", value)
	elseif kind == "Vector3" then
		return "v" .. HttpService:JSONEncode({ value.X, value.Y, value.Z })
	elseif kind == "CFrame" then
		return "c" .. HttpService:JSONEncode({ value:GetComponents() })
	elseif kind == "Color3" then
		return "r" .. HttpService:JSONEncode({ value.R, value.G, value.B })
	elseif kind == "UDim2" then
		return "u"
			.. HttpService:JSONEncode({
				value.X.Scale,
				value.X.Offset,
				value.Y.Scale,
				value.Y.Offset,
			})
	elseif kind == "Vector2" then
		return "p" .. HttpService:JSONEncode({ value.X, value.Y })
	end
	error("Unsupported Gauntlet state value: " .. kind, 2)
end

local function decode(field: StringValue): any
	local content = field.Value
	if content == "" then
		return nil
	end
	local saved = decoded[field]
	if saved and saved.content == content then
		return saved.value
	end
	local code = string.sub(content, 1, 1)
	local body = string.sub(content, 2)
	local value: any
	if code == "s" then
		value = body
	elseif code == "t" or code == "f" then
		value = code == "t"
	elseif code == "n" then
		value = tonumber(body)
	elseif code == "+" or code == "-" then
		value = if code == "+" then math.huge else -math.huge
	else
		local data = HttpService:JSONDecode(body)
		if code == "v" then
			value = Vector3.new(data[1], data[2], data[3])
		elseif code == "c" then
			value = CFrame.new(table.unpack(data))
		elseif code == "r" then
			value = Color3.new(data[1], data[2], data[3])
		elseif code == "u" then
			value = UDim2.new(data[1], data[2], data[3], data[4])
		elseif code == "p" then
			value = Vector2.new(data[1], data[2])
		end
	end
	decoded[field] = { content = content, value = value }
	return value
end

function StateValues.get(owner: Instance, name: string): any
	local folder = owner:FindFirstChild(FOLDER)
	local field = folder and folder:FindFirstChild(name)
	if field and field:IsA("StringValue") then
		return decode(field)
	end
	local data = defaults(owner)
	return if data then data[name] else nil
end

-- Reserve simulation fields before the model is stepped. Roblox restricts
-- instance creation and parenting within BindToSimulation.
function StateValues.prepare(owner: Instance, names: { string })
	local folder = owner:FindFirstChild(FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
	end
	for _, name in names do
		if not folder:FindFirstChild(name) then
			local field = Instance.new("StringValue")
			field.Name = name
			field.Parent = folder
		end
	end
	if not folder.Parent then
		folder.Parent = owner
	end
end

function StateValues.hasFields(owner: Instance, names: { string }): boolean
	local folder = owner:FindFirstChild(FOLDER)
	if not folder then
		return false
	end
	for _, name in names do
		if not folder:FindFirstChild(name) then
			return false
		end
	end
	return true
end

function StateValues.set(owner: Instance, name: string, value: any)
	local folder = owner:FindFirstChild(FOLDER)
	local field = folder and folder:FindFirstChild(name)
	if field and field:IsA("StringValue") then
		local content = encode(value)
		if field.Value ~= content then
			field.Value = content
		end
		return
	end
	if value == nil and StateValues.get(owner, name) == nil then
		return
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
	end
	local created = Instance.new("StringValue")
	created.Name = name
	created.Value = encode(value)
	created.Parent = folder
	if not folder.Parent then
		folder.Parent = owner
	end
end

function StateValues.all(owner: Instance): { [string]: any }
	local data = defaults(owner)
	local result = if data then table.clone(data) else {}
	local folder = owner:FindFirstChild(FOLDER)
	if folder then
		for _, field in folder:GetChildren() do
			if field:IsA("StringValue") then
				result[field.Name] = decode(field)
			end
		end
	end
	return result
end

local function isAssetTag(tag: string): boolean
	return tag == ASSET_TAG or string.sub(tag, 1, #ASSET_PREFIX) == ASSET_PREFIX
end

-- A WorldModel takes over the weapon template's children and authored defaults.
function StateValues.inheritDefaults(owner: Instance, template: Instance)
	for _, tag in CollectionService:GetTags(template) do
		if isAssetTag(tag) then
			CollectionService:AddTag(owner, tag)
		end
	end
end

-- Cosmetic body copies should start without the fighter's gameplay fields.
function StateValues.clear(owner: Instance)
	local folder = owner:FindFirstChild(FOLDER)
	if folder then
		folder:Destroy()
	end
	for _, tag in CollectionService:GetTags(owner) do
		if isAssetTag(tag) then
			CollectionService:RemoveTag(owner, tag)
		end
	end
	byInstance[owner] = nil
end

type Watch = { all: BindableEvent, fields: { [string]: BindableEvent } }
local watching: { [Instance]: Watch } = {}

local function watch(owner: Instance): Watch
	local current = watching[owner]
	if current then
		return current
	end
	local watcher: Watch = { all = Instance.new("BindableEvent"), fields = {} }
	watching[owner] = watcher
	local function emit(name: string)
		watcher.all:Fire(name)
		local signal = watcher.fields[name]
		if signal then
			signal:Fire()
		end
	end
	local function attach(field: Instance, added: boolean)
		if field:IsA("StringValue") then
			field:GetPropertyChangedSignal("Value"):Connect(function()
				emit(field.Name)
			end)
			if added then
				emit(field.Name)
			end
		end
	end
	local function attachFolder(folder: Instance, added: boolean)
		folder.ChildAdded:Connect(function(field)
			attach(field, true)
		end)
		for _, field in folder:GetChildren() do
			attach(field, added)
		end
	end
	local folder = owner:FindFirstChild(FOLDER)
	if folder then
		attachFolder(folder, false)
	end
	owner.ChildAdded:Connect(function(child)
		if child.Name == FOLDER then
			attachFolder(child, true)
		end
	end)
	owner.Destroying:Once(function()
		watching[owner] = nil
		watcher.all:Destroy()
		for _, signal in watcher.fields do
			signal:Destroy()
		end
	end)
	return watcher
end

function StateValues.changed(owner: Instance, name: string): RBXScriptSignal
	local watcher = watch(owner)
	local signal = watcher.fields[name]
	if not signal then
		signal = Instance.new("BindableEvent")
		watcher.fields[name] = signal
	end
	return signal.Event
end

function StateValues.anyChanged(owner: Instance): RBXScriptSignal
	return watch(owner).all.Event
end

return StateValues
