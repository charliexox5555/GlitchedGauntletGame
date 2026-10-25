--!strict
-- Image ids for the weapon VFX textures (rendered by tools/vfx/make_vfx_textures.py,
-- sources in art-source/vfx/). These are the Image ids behind the uploaded
-- Decals (ParticleEmitter/Beam/ImageLabel need the Image, not the Decal).
-- `_2x2` sheets are flipbooks for FlipbookLayout.Grid2x2.

return {
	MUZZLE_FRONT_2x2 = "rbxassetid://125363848027420", -- star burst, down the barrel
	MUZZLE_SIDE_2x2 = "rbxassetid://117783563646990", -- side flame, base at the bottom
	SMOKE_2x2 = "rbxassetid://83629202114408",
	DUST_2x2 = "rbxassetid://119995119142290",
	DEBRIS_2x2 = "rbxassetid://108879615585623", -- chips (tinted by surface colour)
	PIXEL_2x2 = "rbxassetid://112931274426702", -- glitch pixels (death dissolve)
	SPARK = "rbxassetid://118834850594357", -- streak, head at the top
	IMPACT_FLASH = "rbxassetid://107193831997511",
	GLOW = "rbxassetid://135016131754746",
	RING = "rbxassetid://91371870092688",
	HOLE = "rbxassetid://95139041666013", -- baked dark, not tinted
	HOLE_RIM = "rbxassetid://83000810914679", -- matches HOLE; tinted
	TRACER = "rbxassetid://95042043941638", -- u: tail -> head
	BEAM_ENERGY = "rbxassetid://117130324011369", -- tiles along the beam
	BEAM_HELIX = "rbxassetid://114774730718855", -- tiles along the beam
	VIGNETTE = "rbxassetid://103162318305258",
	DISC = "rbxassetid://129568773625393",
}
