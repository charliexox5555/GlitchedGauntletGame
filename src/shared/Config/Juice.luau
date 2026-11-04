--!strict
-- Feel ("juice") numbers that aren't one gun's own (vault/01 Design/Gunplay.md
-- §5 Feedback, the 2026-11-04 polish pass). Competitive rule (LihFolk "Motion
-- Sensitivity and Camera Comfort"): feedback moves and rolls the camera a
-- little but never turns where you look, so it never moves your aim.

return table.freeze({
	-- Other players' guns kick in their hands on every shot (EffectsController):
	-- back along the barrel and muzzle up, then a fast spring home.
	WORLD_KICK = table.freeze({
		back = 0.09, -- studs, plus `backPerUp` x the gun's recoil.up
		backPerUp = 0.12,
		rise = 3, -- degrees muzzle up, plus `risePerUp` x recoil.up
		risePerUp = 5,
		recover = 22, -- 1/s, how fast it settles
	}),

	-- The body you hit flashes (shooter only).
	HIT_FLASH = table.freeze({
		body = { color = Color3.new(1, 1, 1), transparency = 0.55, time = 0.12 },
		head = { color = Color3.fromHex("FFD23F"), transparency = 0.5, time = 0.16 },
		kill = { color = Color3.fromHex("FF5A36"), transparency = 0.35, time = 0.3 },
		search = 1.5, -- studs around the hit point to find the body
	}),

	-- Getting hit: a flinch (camera offset + roll away from the shot, scaled by
	-- damage) and a red pulse at the screen edges. Never touches the look.
	FLINCH = table.freeze({
		offset = 0.08, -- studs at `fullDamage`
		roll = 1.2, -- degrees at `fullDamage`
		fullDamage = 40,
		pulse = 0.35, -- edge pulse peak (0..1 opacity) at `fullDamage`
		pulseTime = 0.3, -- seconds it fades over
	}),

	-- Slide: a quick FOV punch on top of the slide's FOV (the roll is
	-- Config/Movement SLIDE_CAMERA_TILT), dust at the feet that everyone sees,
	-- and a scrape. Sounds: PROVISIONAL ProSoundEffects picks (licensed), audition.
	SLIDE = table.freeze({
		fovPunch = 6, -- degrees, eases out over `punchTime`
		punchTime = 0.35,
		dustRate = 60, -- particles/s while sliding fast
		dustMinSpeed = 13, -- studs/s below which the dust stops
		-- "Baseball Runner Slide On Dirt Into Home Plate 4": its first 0.8 s.
		sound = { id = "rbxassetid://9125380604", volume = 0.5, cut = 0.8, range = 70 },
	}),

	-- Jumping: a soft cloth sound as you leave the ground.
	JUMP = table.freeze({
		minRise = 8, -- studs/s up that counts as a jump (not a step or a bump)
		-- "Cloth Flap 2" (ProSoundEffects), higher and quieter. PROVISIONAL, audition.
		sound = { id = "rbxassetid://9113819222", volume = 0.25, pitch = 1.35 },
	}),

	-- Landing: the camera dips by how fast you fell (k = fall speed / `fullFall`,
	-- dip scales with k^2), and a thud for falls past `soundFrom`.
	LAND = table.freeze({
		dip = 0.55, -- studs at k = 1
		fullFall = 70, -- studs/s
		minFall = 18, -- studs/s below which nothing happens
		soundFrom = 24, -- studs/s
		-- "Cloth Flap 2" (ProSoundEffects, a muffled whump). PROVISIONAL, audition.
		sound = { id = "rbxassetid://9113819222", volume = 0.4 },
	}),

	-- The death look (DeathFxController): the body is hidden and a still copy
	-- of it falls over, rests, then fades with a dust puff. The downed player's
	-- own screen drains of colour.
	DEATH = table.freeze({
		fall = 0.45, -- seconds to hit the floor
		tilt = 82, -- degrees it tips over
		rest = 1.4, -- seconds it lies there
		fade = 0.5, -- seconds to fade out
		dust = 18, -- particles in the puff
		saturation = -0.85, -- your screen while downed
		brightness = -0.08,
		tint = Color3.fromRGB(255, 220, 220),
		screenFade = 0.4, -- seconds
	}),
})
