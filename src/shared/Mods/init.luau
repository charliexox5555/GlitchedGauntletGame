--!strict
-- Mod registry (vault/04 Tech/Mod System.md). Data comes from Config/Mods;
-- behaviour from one module per Mod in this folder, built on Blocks/.
--
--   Mods.def(id)          the Mod's config entry
--   Mods.stats(id, level) resolved stats: L1 → A2 → A3 (each level overrides
--                         the one before), cached and frozen
--   Mods.module(id)       its hooks (nil until the Mod is built)

local Config = require(script.Parent.Config.Mods)
local Types = require(script.Types)

local Mods = {}

-- Built Mods (Stage 1). The others have config but no behaviour yet.
local modules: { [string]: Types.ModModule } = {
	Blink = require(script.Blink).module,
	Packet = require(script.Packet).module,
	PatchUp = require(script.PatchUp).module,
}

local cache: { [string]: Types.Stats } = {}

function Mods.def(id: string): Types.ModDef?
	return Config.defs[id]
end

function Mods.module(id: string): Types.ModModule?
	return modules[id]
end

function Mods.isBuilt(id: string): boolean
	return modules[id] ~= nil
end

function Mods.isLevel(level: string): boolean
	return Config.CHAIN[level] ~= nil
end

function Mods.stats(id: string, level: string): Types.Stats?
	local key = id .. ":" .. level
	local cached = cache[key]
	if cached then
		return cached
	end
	local def = Config.defs[id]
	local chain = Config.CHAIN[level]
	if not def or not chain then
		return nil
	end
	local out: Types.Stats = {}
	for _, step in chain do
		local values = def.levels[step]
		if values then
			for k, v in values do
				out[k] = v
			end
		end
	end
	out.note = (def.levels[level] or def.levels.L1).note
	table.freeze(out)
	cache[key] = out
	return out
end

return Mods
