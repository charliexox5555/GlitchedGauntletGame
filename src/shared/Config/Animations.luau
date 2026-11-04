--!strict
-- Third-person pose animations and how they blend. The clips are built by
-- tools/studio/MakePoseAnimations.luau, saved in art-source/animations/ and
-- uploaded (group-owned) with tools/opencloud/upload_asset.py.
--
-- shared/Simulation/Poses plays them inside the Server Authority simulation
-- (the server poses every player, each client predicts its own character),
-- so everyone sees the same pose and server hitboxes crouch and slide too.

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

return table.freeze({
	POSES = table.freeze({
		-- Holding the gun, blended by aim pitch (Action priority).
		AimUp = id(106670838845808), -- looking AIM_PITCH_RANGE degrees up
		AimLevel = id(107890457643267),
		AimDown = id(102741853097868), -- looking AIM_PITCH_RANGE degrees down
		-- Movement (Action2; Slide is Action3 so it wins over everything).
		Sprint = id(97534488837117), -- gun lowered across the body
		Crouch = id(99568083489164),
		CrouchWalk = id(120617369360340), -- one stride, looped
		Slide = id(88674421205618),
	}),

	-- Legs and hips by move direction (tools/studio/MakeLocomotionAnimations.luau,
	-- Movement priority, 2026-11-04), blended in Simulation/Poses by where you
	-- move relative to where you face. Land plays once on touching down.
	LOCOMOTION = table.freeze({
		RunF = id(115636402441240),
		RunB = id(81677261253829),
		RunL = id(126639525655633),
		RunR = id(103693381646071),
		SprintRun = id(81006580789818),
		Land = id(88050773886302),
	}),
	-- What others see you do with the gun (tools/studio/MakeCombatPoseAnimations.luau,
	-- 2026-11-04): aiming down sights (three pitch poses blended like the hip
	-- set, by the Aim input), a reload one-shot played at the gun's reload
	-- time (server player attributes ReloadAt / ReloadFor) and a flinch when
	-- hit (HitAt).
	COMBAT = table.freeze({
		AdsUp = id(130705905330180),
		AdsLevel = id(95555774738385),
		AdsDown = id(97664620704166),
		Reload = id(123720437640794),
		Flinch = id(114576995497102),
	}),
	ADS_SMOOTHING = 12, -- 1/s: how fast the hold moves between hip and sights
	RELOAD_LENGTH = 1, -- seconds the reload clip is made at
	FLINCH_WEIGHT = 0.8, -- the flinch plays over the rest at this weight

	-- Roblox's Animate plays these instead of its stock clips (CharacterService).
	-- Its walk and run are an empty clip: the LOCOMOTION set carries the legs.
	ANIMATE = table.freeze({
		idle = id(91664102456591),
		walk = id(86109711469782),
		run = id(86109711469782),
		jump = id(104715456957101),
		fall = id(125318466462876),
	} :: { [string]: string }),
	RUN_SPEED = 16, -- studs/s the run clips are made for (rate = speed / this)
	SPRINT_RUN_SPEED = 22,
	RUN_RATE = table.freeze({ min = 0.6, max = 1.5 }), -- clip speed clamp
	RUN_FROM = 1, -- studs/s where the legs start to run...
	RUN_FULL = 4, -- ...and where they're fully running

	-- Mods (tools/studio/MakeModAnimations.luau). ModHold loops while a held
	-- Mod is up (in place of the gun hold); the others play once on a use.
	MODS = table.freeze({
		ModHold = id(72886949328296),
		Throw = id(113960439440452),
		Place = id(102573901472605),
		Heal = id(116476893527219),
		Lob = id(91729570520010), -- a held throw's underhand (Molly RMB)
		Cast = id(131757439176866), -- HeldSteer: the free hand pushes out (Firewall)
		-- Dash: the torso leans into the dash (Simulation/Poses, by direction).
		DashForward = id(132740788102457),
		DashBack = id(128130101853691),
		DashLeft = id(117063604285762),
		DashRight = id(107635192627945),
		-- Updraft: knees tuck on the launch.
		Updraft = id(125684824115691),
		-- Updraft Crash Down (tools/studio/MakeSlamAnimations.luau): the dive
		-- (looped while UpdraftSlam = "Down") and the knee-and-fist landing
		-- (once). Uploaded 2026-11-03.
		UpdraftSlam = id(81823689314585),
		UpdraftSlamLand = id(139188293218588),
	}),
	MOD_FADE = 0.12, -- seconds the Mod hold fades in / out
	SLAM_FADE = 0.08, -- seconds the Crash Down dive pose fades in / out

	AIM_PITCH_RANGE = 70, -- degrees baked into AimUp / AimDown
	CROUCH_WALK_SPEED = 9, -- studs/s that CrouchWalk plays at 1x (Movement.CROUCH_SPEED)
	MOVING_SPEED = 1.5, -- studs/s above which crouching counts as walking

	-- Seconds each pose takes to fade in or out (the Animator's own weight
	-- fade), so state changes blend instead of popping.
	-- (gait changes 0.15-0.25 s: LihFolk "Playback, Priorities and Blending").
	FADE = table.freeze({
		aim = 0.1, -- short: the pitch itself is already smoothed (AIM_SMOOTHING)
		sprint = 0.25,
		crouch = 0.2,
		slide = 0.15,
		run = 0.15, -- direction changes in the run set
	}),
	-- Weights snap to steps of this size, so tiny pitch changes don't restart
	-- a fade every simulation step (0.05 made the aim move in ~3.5 deg steps).
	WEIGHT_STEP = 0.02,
	-- How fast the posed pitch follows the camera pitch (1/s, exponential), so
	-- other players' aim glides instead of stepping with each input update.
	AIM_SMOOTHING = 14,
})
