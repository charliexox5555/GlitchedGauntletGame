--!strict
-- The Locker's saved choices, shared by the Lobby (where you equip) and the
-- Match (where your guns wear them). vault/02 Art/UI Locker.md.
--
-- One equipped skin line per gun, saved in DataStore STORE under key(userId)
-- as { v = 1, skins = { [gunId] = line } }. The Lobby's LockerService writes
-- it; the Match's SkinPreviewService reads it on join. Both set the server-
-- owned Player attribute attr(gunId) = line, which clients only read.
-- Lines are Config/SkinPreview.LINES ("Stock" = the base model); a line is
-- valid for a gun only if WeaponSkins/<Line>/<Gun> exists and is SkinReady.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinConfig = require(script.Parent.Config.SkinPreview)
local Weapons = require(script.Parent.Config.Weapons)

local Locker = {}

Locker.STORE = "LockerV1"
Locker.VERSION = 1

function Locker.key(userId: number): string
	return "u_" .. tostring(userId)
end

function Locker.attr(gunId: string): string
	return "Skin_" .. gunId
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
}) :: { [string]: Color3 }

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
	if m and m:IsA("Model") and m:GetAttribute("SkinReady") == true then
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
