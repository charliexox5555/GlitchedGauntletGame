--!strict
-- The Locker's saved choices, shared by the Lobby (where you equip) and the
-- Match (where your guns wear them). vault/02 Art/UI Locker.md.
--
-- One equipped skin line per gun, saved in DataStore STORE under key(userId)
-- as { v = 1, skins = { [gunId] = line } }. The Lobby's LockerService writes
-- it and both places mirror the equipped lines in a JSON StringValue.
-- Lines are Config/SkinPreview.LINES ("Stock" = the base model); a line is
-- valid for a gun only if WeaponSkins/<Line>/<Gun> exists and is SkinReady.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local HttpService = game:GetService("HttpService")

local SkinConfig = require(script.Parent.Config.SkinPreview)
local Weapons = require(script.Parent.Config.Weapons)

local Locker = {}

Locker.STORE = "LockerV1"
Locker.VERSION = 1
Locker.REPLICA = "LockerSkins"
local cache: { [StringValue]: { encoded: string, skins: { [string]: string } } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any

function Locker.key(userId: number): string
	return "u_" .. tostring(userId)
end

function Locker.publish(owner: Instance, skins: { [string]: string }, name: string?)
	local key = name or Locker.REPLICA
	local encoded = HttpService:JSONEncode(skins)
	local value = owner:FindFirstChild(key)
	if value and value:IsA("StringValue") then
		value.Value = encoded
		return
	end
	local replica = Instance.new("StringValue")
	replica.Name = key
	replica.Value = encoded
	replica.Parent = owner
end

function Locker.equipped(owner: Instance, name: string?): { [string]: string }
	local value = owner:FindFirstChild(name or Locker.REPLICA)
	if not value or not value:IsA("StringValue") or value.Value == "" then
		return {}
	end
	local encoded = value.Value
	local entry = cache[value]
	if entry and entry.encoded == encoded then
		return entry.skins
	end
	local skins = HttpService:JSONDecode(encoded)
	table.freeze(skins)
	cache[value] = { encoded = encoded, skins = skins }
	return skins
end

function Locker.observe(owner: Instance, onChange: () -> ()): () -> ()
	local changed: RBXScriptConnection? = nil
	local function attach(value: Instance)
		if value.Name == Locker.REPLICA and value:IsA("StringValue") then
			if changed then
				changed:Disconnect()
			end
			changed = value:GetPropertyChangedSignal("Value"):Connect(onChange)
		end
	end
	local existing = owner:FindFirstChild(Locker.REPLICA)
	if existing then
		attach(existing)
	end
	local added = owner.ChildAdded:Connect(function(value)
		if value.Name == Locker.REPLICA and value:IsA("StringValue") then
			attach(value)
			onChange()
		end
	end)
	return function()
		added:Disconnect()
		if changed then
			changed:Disconnect()
		end
	end
end

-- Swatch colours for the UI (a line's identity on cards and tags).
Locker.COLORS = table.freeze({
	Stock = Color3.fromHex("8E98A8"),
	Prism = Color3.fromHex("B58CFF"),
	Redline = Color3.fromHex("FF4D5E"),
	Nitrous = Color3.fromHex("3FE0F2"),
	PopCircuit = Color3.fromHex("FF7AD9"),
	Moltframe = Color3.fromHex("FF7A3D"),
	Giltfold = Color3.fromHex("E8C46A"),
	Sealwork = Color3.fromHex("2BD9A8"),
	Payload = Color3.fromHex("9AA36B"),
	Inkshift = Color3.fromHex("E9ECF2"),
	Oilwake = Color3.fromHex("408B72"),
	Misprint = Color3.fromHex("2447B9"),
	Faultline = Color3.fromHex("C07D57"),
	Playback = Color3.fromHex("746079"),
	Breakwater = Color3.fromHex("327C80"),
	Sundial = Color3.fromHex("B89A57"),
	Poolside = Color3.fromHex("4DB6E4"),
	Rootglass = Color3.fromHex("26745E"),
}) :: { [string]: Color3 }

-- Each line's emblem (owner 2026-11-15: skins need an identity besides
-- colour): a single-colour image asset, tinted with the line's colour in the
-- UI. Empty = no art; the Locker draws a lettered diamond instead.
-- ChatGPT set from the prompt in vault/02 Art/UI Locker.md -> v5; sources in
-- art-source/ui/collection-emblems/ (uploaded 2026-11-15).
Locker.EMBLEMS = table.freeze({
	Stock = "rbxassetid://89295875546813",
	Prism = "rbxassetid://122467699745583",
	Redline = "rbxassetid://71004506302641",
	Nitrous = "rbxassetid://113536349803482",
	PopCircuit = "rbxassetid://129293303801424",
	Moltframe = "rbxassetid://130609703264142",
	Giltfold = "rbxassetid://137880589089631",
	Sealwork = "rbxassetid://90587660646204",
	Payload = "rbxassetid://74808720750414",
	Inkshift = "rbxassetid://92911837408821",
}) :: { [string]: string }

-- The gun's model in ReplicatedStorage.Weapons (Studio-owned; the Lobby gets
-- a copy with tools/studio/SyncWeapons.luau), if the gun is in the game.
function Locker.gunModel(gunId: string): Model?
	if not Weapons.get(gunId) then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	local m = folder and folder:FindFirstChild(gunId)
	return if m and m:IsA("Model") then m else nil
end

-- The model for `line` on `gunId` ("Stock" = the base gun), or nil.
function Locker.skinModel(gunId: string, line: string): Model?
	if line == "Stock" then
		return Locker.gunModel(gunId)
	end
	local skins = ReplicatedStorage:FindFirstChild("WeaponSkins")
	local folder = skins and skins:FindFirstChild(line)
	-- the PopCircuit knife is the Bat (same rule as Shared/SkinPreview.resolve)
	local name = if gunId == "Knife" and line == "PopCircuit" then "Bat" else gunId
	local m = folder and folder:FindFirstChild(name)
	if m and m:IsA("Model") and StateValues.get(m, "SkinReady") == true then
		return m
	end
	return nil
end

function Locker.valid(gunId: unknown, line: unknown): boolean
	if typeof(gunId) ~= "string" or typeof(line) ~= "string" then
		return false
	end
	if #gunId > 24 or #line > 32 or not table.find(SkinConfig.LINES, line) then
		return false
	end
	return Locker.gunModel(gunId) ~= nil and Locker.skinModel(gunId, line) ~= nil
end

-- Every line a gun can wear, Stock first, in Config order.
function Locker.linesFor(gunId: string): { string }
	local out: { string } = {}
	for _, line in SkinConfig.LINES do
		if Locker.skinModel(gunId, line) then
			table.insert(out, line)
		end
	end
	return out
end

-- A saved record cleaned up: only valid pairs survive (guns or skins removed
-- since it was saved simply drop out).
function Locker.clean(data: unknown): { [string]: string }
	local out: { [string]: string } = {}
	if typeof(data) ~= "table" then
		return out
	end
	local skins = (data :: any).skins
	if typeof(skins) ~= "table" then
		return out
	end
	for gunId, line in skins :: { [unknown]: unknown } do
		if Locker.valid(gunId, line) then
			out[gunId :: string] = line :: string
		end
	end
	return out
end

return Locker
