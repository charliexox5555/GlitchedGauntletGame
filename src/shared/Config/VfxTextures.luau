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
})
