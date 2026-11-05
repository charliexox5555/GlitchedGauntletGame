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
		-- Holding the gun, blended by aim pitch (Action priority). Solved on a
		-- rig with both hands on the gun (tools/studio/MakeHoldAnimations,
		-- 2026-11-04): shouldered long-gun hold, sidearms two-handed.
		AimUp = id(123446724391415), -- looking AIM_PITCH_RANGE degrees up
		AimLevel = id(128549425661166),
		AimDown = id(136340891587951), -- looking AIM_PITCH_RANGE degrees down
		-- Sidearms' two-handed hold, the same pitch blend (MakeHoldAnimations).
		PistolAimUp = id(134387505053454),
		PistolAimLevel = id(104048644111391),
		PistolAimDown = id(76559880424473),
		PistolAdsUp = id(74201207820342),
		PistolAdsLevel = id(124447634856449),
		PistolAdsDown = id(71881501397859),
		-- Movement (Action2; Slide is Action3 so it wins over everything).
		Sprint = id(71812210775526), -- gun lowered across the body
		Crouch = id(99568083489164),
		CrouchWalk = id(120617369360340), -- one stride, looped
		-- The other crouch-walk directions (same stride length), blended by
		-- where you move like the run set (2026-11-04).
		CrouchWalkB = id(139454894380024),
		CrouchWalkL = id(104336317188168),
		CrouchWalkR = id(96202691168303),
		Slide = id(75102784945494), -- the full-body ground slide hold, with a scrape chatter (tools/studio/make_slide_poses.py)
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
		-- The slide's way in and out (one-shots, tools/studio/make_slide_poses.py).
		SlideIn = id(80692529364914),
		SlideOut = id(102780739852463),
	}),
	-- What others see you do with the gun (tools/studio/MakeCombatPoseAnimations.luau,
	-- 2026-11-04): aiming down sights (three pitch poses blended like the hip
	-- set, by the Aim input), a reload one-shot played at the gun's reload
	-- time (server player attributes ReloadAt / ReloadFor) and a flinch when
	-- hit (HitAt).
	COMBAT = table.freeze({
		AdsUp = id(139613906260905),
		AdsLevel = id(137279427153476),
		AdsDown = id(79761173585801),
		Reload = id(139915270226655),
		Flinch = id(114576995497102),
		Death = id(81024323443020), -- going down (DeathFxController, on the falling copy)
		-- The knife: a ready hold while it's out, a slash and the heavy (alt)
		-- on each swing (server player attributes SwingAt / SwingHeavy).
		-- A weapon swap: the new gun comes in low and rises (played at its
		-- equipTime; made DRAW_LENGTH long).
		Draw = id(126901374148632),
		KnifeReady = id(116692680582291), -- 2026-11-05: arms cleared of the torso (was 98422551486900)
		-- Knife swings (2026-11-05, tools/studio/make_knife_poses.py; every
		-- frame keeps the limbs within 0.015 studs of the torso on the block
		-- rig). The old single slash was 103765524428295, the old heavy
		-- 87481489934854.
		KnifeSlash = id(93885278536146), -- GG_KnifeSlash1: forehand (SwingStep 1)
		KnifeSlash2 = id(138622195195928), -- GG_KnifeSlash2: backhand (SwingStep 2)
		KnifeSlash3 = id(83936340288160), -- GG_KnifeSlash3: the overhead chop (SwingStep 3)
		KnifeHeavy = id(125552226626615), -- GG_KnifeHeavy: pull back, coil, thrust
	}),
	-- The left hand on each gun's LeftGrip (GripController IK, every visible
	-- character, 2026-11-04). Positions in studs, angles in degrees.
	GRIP = table.freeze({
		reachFraction = 0.88, -- of the arm's length: how far the left hand may reach (elbow soft)
		maxSlide = 1.5, -- how far back along the barrel the hand may slide to reach
		leftPole = Vector3.new(-1.2, -1.6, -0.3), -- the left elbow points here (UpperTorso space)
		long = table.freeze({ under = 0.14, side = 0, palm = 90 }), -- palm up under the guard
		sidearm = table.freeze({ under = 0.05, side = -0.64, palm = 0 }), -- beside the grip hand (match body, slim arms)
		fadeIn = 14, -- 1/s
		fadeOut = 20,
		regrip = 0.15, -- seconds after a reload ends before the hand goes back
		afterModUse = 0.6, -- seconds the hand stays off after a Mod use (throw, place...)
		maxDistance = 220, -- studs from the camera beyond which nobody's grip is solved
	}),
	-- What others see when someone fires (GripController, on ShotFx): the right
	-- forearm pulls back `back` studs along the barrel and the muzzle flips up
	-- `rise` degrees, reaching it in FIRE_KICK_RISE, then springing home with
	-- decay rate `recover` (1/s) and a small overshoot (FIRE_KICK_DAMPING). On top
	-- of the gun's own flip in the hand (Config/Juice WORLD_KICK).
	FIRE_KICK_RISE = 0.05,
	FIRE_KICK_DAMPING = 0.5, -- spring damping ratio of the return (0.5: ~16% overshoot)
	FIRE_KICK = table.freeze({
		Sidearm = table.freeze({ back = 0.16, rise = 9, recover = 20 }), -- ~0.12 s
		SMG = table.freeze({ back = 0.1, rise = 5, recover = 30 }), -- ~0.08 s
		Rifle = table.freeze({ back = 0.15, rise = 6, recover = 25 }), -- ~0.09 s
		MachineGun = table.freeze({ back = 0.14, rise = 5, recover = 28 }),
		Shotgun = table.freeze({ back = 0.34, rise = 15, recover = 9 }), -- ~0.26 s
		Sniper = table.freeze({ back = 0.4, rise = 16, recover = 7 }), -- ~0.33 s
	} :: { [string]: { back: number, rise: number, recover: number } }),

	-- Knife marks on the world (WeaponController / EffectsController.slashMark):
	-- centred where the aim ray meets the surface, the gouge laid along each
	-- swing's path on screen (x right, y up), matching the first-person clips
	-- (Config/Viewmodel Slash1-3 / HeavyStab).
	KNIFE_MARK = table.freeze({
		paths = table.freeze({
			Slash1 = Vector2.new(-0.9, -0.42), -- forehand: right to left, falling
			Slash2 = Vector2.new(0.9, -0.45), -- backhand: back across, falling
			Slash3 = Vector2.new(-0.1, -1), -- the downward chop
			HeavyStab = Vector2.new(0.15, -1), -- the thrust: a short upright tear
		} :: { [string]: Vector2 }),
		light = table.freeze({ size = 0.36, stretch = Vector2.new(3.2, 0.22) }),
		heavy = table.freeze({ size = 0.5, stretch = Vector2.new(1.1, 0.5) }),
		tint = Color3.fromHex("5A5550"),
	}),

	-- The knife in third person (WeaponService world model): its handle sits
	-- in the fist with the blade pointing forward out of it (the hand's -Z),
	-- a forward grip. Guns use a grip turned -90 deg about X, which ran the
	-- knife's blade straight along the forearm, hidden in the body whenever
	-- the arm crossed it. tools/studio/make_knife_poses.py keys the clips for
	-- this grip.
	KNIFE_WORLD_GRIP = CFrame.new(0, -0.15, -0.05),

	-- Knife feel (2026-11-05, lane F; LihFolk Hit-Stop and Screen Shake Tuning
	-- by Numbers, Camera Shake and Camera FX, Slash VFX Recipes). Per attack:
	-- `swipe` = the first-person streak's arc (camera space: start, bend, end;
	-- nil = none, the stab), `kick` = degrees the view is punched along the
	-- swing's screen path (KNIFE_MARK) on a whiff / on a hit, `roll` = degrees
	-- of roll on a hit, `stop` = hit-stop seconds on a body hit (66 ms is the
	-- shortest that reads on phones), `fov` = a heavy hit's FOV punch.
	-- Walls get `wallStop` and half the hit kick. All runtime: a whiff never
	-- freezes. Kicks return over `recover` seconds.
	KNIFE_FEEL = table.freeze({
		Slash1 = table.freeze({
			swipe = {
				Vector3.new(1.0, 0.5, -2.3),
				Vector3.new(0.05, 0.18, -2.9),
				Vector3.new(-1.05, -0.5, -2.3),
			},
			kick = Vector2.new(0.25, 0.7),
			roll = 1.4,
			stop = 0.066,
		}),
		Slash2 = table.freeze({
			swipe = {
				Vector3.new(-1.0, 0.45, -2.3),
				Vector3.new(-0.05, 0.15, -2.9),
				Vector3.new(1.05, -0.55, -2.3),
			},
			kick = Vector2.new(0.25, 0.7),
			roll = 1.4,
			stop = 0.066,
		}),
		Slash3 = table.freeze({
			swipe = {
				Vector3.new(0.3, 1.05, -2.3),
				Vector3.new(0.12, 0.12, -2.9),
				Vector3.new(-0.08, -1.05, -2.3),
			},
			kick = Vector2.new(0.3, 0.9),
			roll = 0.6,
			stop = 0.08,
		}),
		HeavyStab = table.freeze({
			kick = Vector2.new(0.3, 1.1),
			roll = 0.8,
			stop = 0.1,
			fov = -3,
		}),
		wallStop = 0.035,
		recover = 0.14,
		hitShake = 0.25, -- degrees, after the stop
		swipeSweep = 0.11, -- seconds for the streak's head to cross (the strike + follow)
		swipeWhiff = 0.8, -- streak strength on a whiff (a hit: 1)
		-- Seconds into the whoosh files where they peak (tools/audio/build_sfx.py
		-- cuts every take to this) and how long before contact the peak lands.
		whooshPeak = table.freeze({ light = 0.06, heavy = 0.09 }),
		whooshLead = 0.03,
		-- Seconds into the knife inspect (Config/Viewmodel InspectMelee, 2.3 s)
		-- where each flip is caught: a balisong click.
		inspectFlips = { 1.04, 1.82 },
	}),

	ADS_SMOOTHING = 12, -- 1/s: how fast the hold moves between hip and sights
	RELOAD_LENGTH = 1, -- seconds the reload clip is made at
	DRAW_LENGTH = 0.5, -- seconds the draw clip is made at
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
		-- Hold and use clips (tools/studio/MakeModAnimations.luau; pass 2,
		-- 2026-11-04: wind-ups, snaps and follow-throughs, ending on the gun hold).
		ModHold = id(115940553232675),
		Throw = id(115956567313242),
		Place = id(100402076753145),
		Heal = id(101178239488481),
		Lob = id(91952970218420), -- a held throw's underhand (Molly RMB)
		Cast = id(93574122239655), -- HeldSteer: the free hand pushes out (Firewall)
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
	SLIDE_CHATTER_SPEED = 30, -- studs/s the slide hold's chatter plays at 1x (it calms as the slide slows)
	SLIDE_CHATTER_MIN = 0.35, -- ...down to this rate

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
