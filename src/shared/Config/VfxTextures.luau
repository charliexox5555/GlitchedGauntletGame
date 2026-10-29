--!strict
-- Image ids for the weapon VFX textures. These are the Image ids behind the
-- uploaded Decals (ParticleEmitter/Beam/ImageLabel need the Image, not the
-- Decal). `_2x2` sheets are flipbooks for FlipbookLayout.Grid2x2.
--
-- Realistic set (new direction): tools/vfx/make_real_vfx.py, sources in
-- art-source/vfx/real/. The flashes have their fire colours baked in; the
-- rest are grey and tinted in code.
-- Kept from the first set (tools/vfx/make_vfx_textures.py, art-source/vfx/):
-- the spark streak, the soft glow and the tracer gradient, all plain white.

return table.freeze({
	FLASH_FRONT_2x2 = "rbxassetid://130264884057726", -- star burst, seen down the barrel
	FLASH_SIDE_2x2 = "rbxassetid://123859178693153", -- side flame, base at the bottom
	SMOKE_2x2 = "rbxassetid://117925333534520",
	DUST_2x2 = "rbxassetid://109666546750603",
	CHIPS_2x2 = "rbxassetid://113906816207530", -- rock chips (tinted by surface colour)
	HOLE = "rbxassetid://128028546664274", -- bullet hole, neutral greys (tinted per material)
	SPARK = "rbxassetid://118834850594357", -- streak, head at the top
	GLOW = "rbxassetid://135016131754746",
	TRACER = "rbxassetid://95042043941638", -- u: tail -> head

	-- Mod set (tools/vfx/make_mod_vfx.py → art-source/vfx/mods/): stylized,
	-- all white, tinted per viewer by Util/ModVfx.
	MOD_RING = "rbxassetid://75054036625076", -- crisp ring at r = 0.9 with an inner glow
	MOD_RING_DASHED = "rbxassetid://103210899817055", -- segmented rim with ticks
	MOD_SCAN = "rbxassetid://126323500739704", -- bright edge fading inward (Ping)
	MOD_HEX = "rbxassetid://88191641918196", -- tileable hex lines, 512 x 443 (V = 0.866 U)
	MOD_CHEVRON = "rbxassetid://129448031567779", -- three stacked chevrons pointing down (= a Top face's LookVector)
	MOD_GLOW = "rbxassetid://112631243473700", -- soft round glow
	MOD_SPARKLE = "rbxassetid://131441026395130", -- four-point star
	MOD_CROSS = "rbxassetid://107533110619347", -- plus (heal motes)

	-- Dash (tools/vfx/make_dash_vfx.py → art-source/vfx/abilities/dash/), all
	-- white, tinted per viewer (Util/DashFx, ModFeelController).
	DASH_WIND_TRAIL = "rbxassetid://93485856775142", -- wind wisps; u: head (left) -> tail
	DASH_AIR_BURST_2x2 = "rbxassetid://130185238645234", -- gust ring expanding over 4 frames
	DASH_PUFF_2x2 = "rbxassetid://86393263788167", -- soft dust puff dissipating over 4 frames
	DASH_SCREEN_STREAK = "rbxassetid://75317717584279", -- one wind streak, head on the left
})
