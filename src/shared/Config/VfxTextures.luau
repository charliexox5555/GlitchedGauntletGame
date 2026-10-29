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
	-- white, tinted per viewer (Util/WindFx, ModFeelController).
	DASH_WIND_TRAIL = "rbxassetid://93485856775142", -- wind wisps; u: head (left) -> tail
	DASH_AIR_BURST_2x2 = "rbxassetid://130185238645234", -- gust ring expanding over 4 frames
	DASH_PUFF_2x2 = "rbxassetid://86393263788167", -- soft dust puff dissipating over 4 frames
	DASH_SCREEN_STREAK = "rbxassetid://75317717584279", -- one wind streak, head on the left

	-- Molly (tools/vfx/make_molly_vfx.py → art-source/vfx/abilities/molly/).
	-- Fire keeps its own colours (Util/MollyFx).
	MOLLY_FLAME_4x4 = "rbxassetid://105580186626619", -- 16-frame looping flame cluster, base at the bottom
	MOLLY_SMOKE_2x2 = "rbxassetid://78112081932784", -- grey puff billowing and thinning (greyscale)
	MOLLY_EMBER = "rbxassetid://101128795307568", -- hot core + halo (greyscale)
	MOLLY_BURST_2x2 = "rbxassetid://132280358321008", -- the whoomp, side view, base at the bottom
	MOLLY_SCORCH = "rbxassetid://114053963453641", -- top-down burn mark; char in the middle 60%

	-- Frost (tools/vfx/make_frost_vfx.py → art-source/vfx/abilities/frost/),
	-- tinted cold blue in Util/FrostFx.
	FROST_MIST_2x2 = "rbxassetid://96058305432942", -- cold mist billowing and thinning
	FROST_BURST_2x2 = "rbxassetid://131740442911737", -- icy flash + shard front, shattering
	FROST_GROUND = "rbxassetid://79536369659364", -- top-down frost feathers (a floor decal)
	FROST_SHARD = "rbxassetid://110957978264323", -- a sharp ice glint
	FROST_CRYSTALS = "rbxassetid://71167177461946", -- a cluster of ice crystals (on bodies)
	FROST_VIGNETTE = "rbxassetid://127776803853487", -- frosted screen edges, clear centre
	FROST_VAPOR = "rbxassetid://112352390447122", -- a thin vapour wisp (u along it)

	-- Recon (tools/vfx/make_recon_vfx.py → art-source/vfx/abilities/recon/).
	RECON_SCAN_RING = "rbxassetid://71532207555430", -- crisp scan edge, glow trailing inward
	RECON_SCAN_SPHERE_2x2 = "rbxassetid://80233919811742", -- an expanding scan shell (flipbook)
	RECON_GLOW = "rbxassetid://112986690063111", -- soft glow, hot core (the dart's light)
	RECON_TRAIL = "rbxassetid://102081301769659", -- a thin light streak, head on the left
	RECON_SPARK = "rbxassetid://100198570257307", -- a spark streak (the dart destroyed)

	-- Heal Orb (tools/vfx/make_healorb_vfx.py → art-source/vfx/abilities/healorb/),
	-- tinted soft green-teal in Util/HealFx.
	HEALORB_SWIRL = "rbxassetid://125851907441357", -- swirling light, seamless (the orb's ForceField shell)
	HEALORB_MOTE = "rbxassetid://139817771058197", -- a soft glowing mote
	HEALORB_WISP_2x2 = "rbxassetid://88575531654697", -- a curling light wisp (flipbook)
	HEALORB_RIBBON = "rbxassetid://115665578237713", -- braided light, u along the beam (seamless in u)
	HEALORB_BURST_2x2 = "rbxassetid://100726640186038", -- a soft light burst (flipbook)
	HEALORB_RING = "rbxassetid://126560015232294", -- top-view soft halo ring
	HEALORB_EDGE = "rbxassetid://110803234844699", -- full-screen edge glow (centre clear)

	-- Stim (tools/vfx/make_stim_vfx.py → art-source/vfx/abilities/stim/), tinted
	-- electric yellow in Util/StimFx.
	STIM_ARC_2x2 = "rbxassetid://114482185748553", -- four crackle frames (flipbook, random frame)
	STIM_BOLT = "rbxassetid://113538195562079", -- a lightning bolt, u along it (Beam)
	STIM_RING = "rbxassetid://89495836564073", -- top-view zone edge with arcs, centre clear
	STIM_SPARK = "rbxassetid://93602845421112", -- a spark streak (VelocityParallel)
	STIM_EDGE = "rbxassetid://105967176478968", -- full-screen electric edge glow (centre clear)

	-- Recall (tools/vfx/make_recall_vfx.py → art-source/vfx/abilities/recall/),
	-- tinted violet in Util/RecallFx.
	RECALL_SHIMMER_2x2 = "rbxassetid://112883056580484", -- glints and fragments (flipbook, random frame)
	RECALL_FLASH = "rbxassetid://85958731477951", -- a soft flash with streaks (arrival / departure)
	RECALL_RING = "rbxassetid://90555324299037", -- top-view ring, centre clear (anchor halo, arrival)
	RECALL_MOTE = "rbxassetid://92235284417353", -- a soft glowing mote
	RECALL_WARP = "rbxassetid://96699089140331", -- full-screen streaks pulling inward (centre clear)
})
