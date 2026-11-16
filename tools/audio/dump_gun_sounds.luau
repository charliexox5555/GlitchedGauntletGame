--!strict
-- Prints Config/GunSounds as JSON ({ gun: { slot: { id, volume, pitch } } })
-- for tools/audio/build_pro_atlas.py, so its audition reels play exactly the
-- game's mapping. Run: lune run tools/audio/dump_gun_sounds.luau Vandal Classic ...

local process = require("@lune/process")
local serde = require("@lune/serde")

local GunSounds = require("../../src/shared/Config/GunSounds")

local out = {}
for _, gun in process.args do
	out[gun] = GunSounds.get(gun)
end
print(serde.encode("json", out, false))
