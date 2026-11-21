--!strict
-- A player's saved settings (vault/02 Art/UI Settings.md). The rows and
-- defaults are Config/Settings; this turns any stored or sent value into a
-- valid table, on both sides:
--   values = { [rowId] = boolean | number | string | { string } }
-- Booleans for toggles, numbers clamped and stepped for sliders, a listed
-- string for choices, 6-digit hex for colours, { keyboard, alt, controller }
-- Enum.KeyCode names for keybinds. Unknown ids drop, bad values fall back to
-- the default.
--
-- Saved in the player's PlayerDataV1 key under `settings` (Lobby
-- SettingsService); the server publishes them as JSON in the player's
-- "Settings" StringValue for their client to read.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

export type Values = { [string]: any }

local PlayerSettings = {}

local KEY_NAMES: { [string]: boolean } = {}
for _, item in Enum.KeyCode:GetEnumItems() do
	if item.Value ~= 0 then -- not Unknown / None
		KEY_NAMES[item.Name] = true
	end
end

local function finite(n: unknown): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Snap to the row's step and range (fixes float drift: 0.1 steps stay 0.1).
function PlayerSettings.snap(row: Settings.Row, n: number): number
	local lo, hi, step = row.min or 0, row.max or 1, row.step or 1
	local v = lo + math.floor((n - lo) / step + 0.5) * step
	v = math.clamp(v, lo, hi)
	return math.floor(v * 1000 + 0.5) / 1000
end

local function cleanOne(row: Settings.Row, v: unknown): any
	local kind = row.kind
	if kind == "toggle" then
		return if typeof(v) == "boolean" then v else row.default
	elseif kind == "slider" then
		return if finite(v) then PlayerSettings.snap(row, v :: number) else row.default
	elseif kind == "choice" then
		return if typeof(v) == "string" and table.find(row.choices or {}, v) then v else row.default
	elseif kind == "color" then
		if typeof(v) == "string" and #v == 6 and string.match(v, "^%x%x%x%x%x%x$") then
			return string.upper(v)
		end
		return row.default
	elseif kind == "key" then
		local default = row.default :: { string }
		if row.locked or typeof(v) ~= "table" then
			return table.clone(default)
		end
		local t = v :: { unknown }
		local out = {}
		for i = 1, 3 do
			local k = t[i]
			out[i] = if typeof(k) == "string" and (k == "" or (#k <= 32 and KEY_NAMES[k]))
				then k
				else default[i]
		end
		return out
	end
	return row.default
end

-- Every row's default.
function PlayerSettings.defaults(): Values
	local out: Values = {}
	for id, row in Settings.BY_ID do
		out[id] = cleanOne(row, nil)
	end
	return out
end

-- Any value (nil, an old save, a client's request) to a full valid table.
function PlayerSettings.clean(raw: unknown): Values
	local out = PlayerSettings.defaults()
	if typeof(raw) ~= "table" then
		return out
	end
	for id, v in raw :: { [unknown]: unknown } do
		if typeof(id) == "string" then
			local row = Settings.BY_ID[id]
			if row then
				out[id] = cleanOne(row, v)
			end
		end
	end
	return out
end

-- One row back to its default.
function PlayerSettings.default(id: string): any
	local row = Settings.BY_ID[id]
	return if row then cleanOne(row, nil) else nil
end

-- A colour row's value as a Color3.
function PlayerSettings.color(values: Values, id: string): Color3
	local v = values[id]
	local ok, c = pcall(Color3.fromHex, if typeof(v) == "string" then v else "FFFFFF")
	return if ok then c else Color3.new(1, 1, 1)
end

function PlayerSettings.hex(c: Color3): string
	return string.upper(c:ToHex())
end

function PlayerSettings.encode(values: Values): string
	return HttpService:JSONEncode(values)
end

function PlayerSettings.decode(json: string): Values?
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok then PlayerSettings.clean(decoded) else nil
end

-- Server: publish the saved values on the player (their client reads them).
function PlayerSettings.publish(player: Player, values: Values)
	local v = player:FindFirstChild(Settings.REPLICA)
	if not (v and v:IsA("StringValue")) then
		local made = Instance.new("StringValue")
		made.Name = Settings.REPLICA
		v = made
	end
	local sv = v :: StringValue
	sv.Value = PlayerSettings.encode(values)
	sv.Parent = player
end

-- Client: the published values, waiting up to `timeout` for the server (nil
-- if the save hasn't loaded).
function PlayerSettings.read(player: Player, timeout: number?): Values?
	local v = player:WaitForChild(Settings.REPLICA, timeout or 30)
	if not (v and v:IsA("StringValue")) or v.Value == "" then
		return nil
	end
	return PlayerSettings.decode(v.Value)
end

return PlayerSettings
