--!strict
-- The Settings CROSSHAIR rows as a Config/Crosshair table (vault/02 Art/UI
-- Settings.md → Chunk 4). Everything the rows don't set (motion, fades,
-- outline colour) stays the tuned default. HudController applies the
-- player's own, or the watched player's while spectating.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrosshairConfig = require(ReplicatedStorage.Shared.Config.Crosshair)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)

type Crosshair = CrosshairConfig.Crosshair

local CrosshairSettings = {}

local function deepCopy<T>(t: T): T
	local out = table.clone(t :: any)
	for k, v in out do
		if typeof(v) == "table" then
			out[k] = deepCopy(v)
		end
	end
	return out :: any
end

function CrosshairSettings.fromValues(values: PlayerSettings.Values?): Crosshair
	local v = values or PlayerSettings.defaults()
	local c = deepCopy(CrosshairConfig.DEFAULT)
	local function n(id: string, fallback: number): number
		local x = v[id]
		return if typeof(x) == "number" then x else fallback
	end
	c.scale = n("chScale", c.scale)
	c.color = PlayerSettings.color(v, "chColor")
	c.bars.length = n("chLength", c.bars.length)
	c.bars.thickness = n("chThickness", c.bars.thickness)
	c.bars.spacing = n("chGap", c.bars.spacing)
	c.dot.enabled = v.chDot ~= false
	c.dot.size = c.bars.thickness
	c.outline.enabled = v.chOutline ~= false
	c.rotation = if v.chX == true then 45 else 0
	c.static = v.chStatic == true
	c.showWhileAiming = v.chShowAiming == true
	return c
end

-- Someone's published settings JSON (any Player's "Settings" value
-- replicates to every client); nil for bots and players whose save hasn't loaded.
function CrosshairSettings.rawOf(holder: Instance?): string?
	local sv = if holder and holder:IsA("Player")
		then holder:FindFirstChild(Settings.REPLICA)
		else nil
	if not (sv and sv:IsA("StringValue")) or sv.Value == "" then
		return nil
	end
	return sv.Value
end

function CrosshairSettings.decode(raw: string?): PlayerSettings.Values?
	return if raw then PlayerSettings.decode(raw) else nil
end

return CrosshairSettings
