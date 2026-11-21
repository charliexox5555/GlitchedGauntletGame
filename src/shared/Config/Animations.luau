--!strict
-- Third-person pose animations and how they blend. Since 2026-11-12 the
-- holds, locomotion, crouch, slide, air, reload, draw and knife clips are
-- keyed in tools/anim/tp_clips.py on the block match body (the gun, hips and
-- feet are placed; arms and legs follow by IK), exported to
-- art-source/animations/ and uploaded (group-owned) with
-- tools/opencloud/upload_asset.py. The Mod, dash, flinch and death clips are
-- still the older ones (tools/studio/Make*Animations.luau).
--
-- shared/Simulation/Poses plays them: each client poses its own character
-- (the tracks replicate), the server poses its bots (under Server Authority
-- the server poses everyone and clients predict themselves).

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

return table.freeze({
	POSES = table.freeze({
		-- Holding the gun, blended by aim pitch (Action priority). Solved on a
		-- rig with both hands on the gun (tools/studio/MakeHoldAnimations,
		-- 2026-11-04): shouldered long-gun hold, sidearms two-handed.
		AimUp = id(88731037976156), -- o2 2026-11-20: breathing hold (was 137847543596504) -- looking AIM_PITCH_UP degrees up
		AimLevel = id(105637585256231), -- o2 2026-11-20: breathing hold (was 133205732621181)
		AimDown = id(118568564589362), -- r2 2026-11-21: breathing hold, the head looks down with the aim (o2 118137664448884; was 86939677186257) -- looking AIM_PITCH_DOWN degrees down (v7 2026-11-15: the gun goes out as it drops, the right forearm was inside the chest; was 111694202793931)
		-- Sidearms' two-handed hold, the same pitch blend (MakeHoldAnimations).
		PistolAimUp = id(104552117240290), -- o2 2026-11-20: breathing hold (was 95901417628746)
		PistolAimLevel = id(134408200055475), -- o2 2026-11-20: breathing hold (was 91403700231911)
		PistolAimDown = id(88754165814506), -- r2 2026-11-21: breathing hold, head looks down (o2 111015808504046; was 70510113818516)
		PistolAdsUp = id(123908701376846), -- o2 2026-11-20: breathing hold (was 115421178439718)
		PistolAdsLevel = id(93700559415008), -- o2 2026-11-20: breathing hold (was 77191013164054)
		PistolAdsDown = id(100517179779054), -- r2 2026-11-21: breathing hold, head looks down (o2 73233869134802; was 80580729310516)
		-- Movement (Action2; Slide is Action3 so it wins over everything).
		-- The run's upper body, in step with SprintRun (a loop the same length):
		-- a low ready that swings with the stride; sidearms and the knife have their own.
		Sprint = id(135280483179256),
		SprintPistol = id(127136320549965),
		SprintKnife = id(123727434361000),
		Crouch = id(79991946157030),
		CrouchWalk = id(117039700985521), -- one stride, looped (pass 4 2026-11-13: foot-locked, 0.3 s)
		-- The other crouch-walk directions (same stride length), blended by
		-- where you move like the run set (2026-11-04).
		CrouchWalkB = id(82235519011694),
		CrouchWalkL = id(135096973393141), -- r3 2026-11-21: no knee in the floor (lanes ahead, knees out) (was 78069980558194)
		CrouchWalkR = id(72907308049134), -- r3 2026-11-21: no knee in the floor (lanes ahead, knees out) (was 84497263575143)
		-- ...and the diagonals (2026-11-13: eight directions, Simulation/Poses
		-- blends the two either side of the move).
		CrouchWalkFR = id(137679623333500), -- r3 2026-11-21: no knee in the floor (lanes ahead, knees out) (was 140110042704887)
		CrouchWalkBR = id(77348337720648), -- r3 2026-11-21: no knee in the floor (lanes ahead, knees out) (was 129306109767897)
		CrouchWalkBL = id(131407720415435), -- r3 2026-11-21: no knee in the floor (lanes ahead, knees out) (was 95758423303446)
		CrouchWalkFL = id(100723533854221), -- r3 2026-11-21: no knee in the floor (lanes ahead, knees out) (was 91208655342459)
		Slide = id(103527653788997), -- the full-body ground slide hold, with a scrape chatter (tools/anim/tp_clips.py)
		-- ...with a sidearm or the knife (2026-11-13: their own arms on the fist).
		SlidePistol = id(123494865248021),
		SlideKnife = id(107595824469218),
	}),

	-- Legs and hips by move direction, blended in Simulation/Poses by where you
	-- move relative to where you face. Pass 4 (2026-11-13, tools/anim/tp_clips.py,
	-- vault Third Person Overhaul §18): foot-locked gaits whose planted feet
	-- roll on their edges, side shuffles for the strafes, and a walk set for
	-- slow (aimed) movement. Land plays once on touching down.
	LOCOMOTION = table.freeze({
		RunF = id(134990246201069),
		RunB = id(93806441016839),
		RunL = id(114966760138568),
		RunR = id(98090231712481),
		-- The diagonals: real clips with their own foot paths (a forward clip
		-- blended with a strafe measured 53% lock in the engine).
		RunFR = id(119114552228570),
		RunBR = id(98895949935688),
		RunBL = id(86554426697561),
		RunFL = id(99898123613921),
		SprintRun = id(118361992368136),
		-- The walk set (made for WALK_CLIP_SPEED), cross-faded with the run
		-- set by speed (WALK_RUN).
		WalkF = id(107342133831860),
		WalkB = id(86945287609346),
		WalkL = id(75856907068096),
		WalkR = id(107142626991120),
		WalkFR = id(108041601441541),
		WalkBR = id(91920468560649),
		WalkBL = id(100608079004581),
		WalkFL = id(93351123775758),
		Land = id(97529375997799),
		-- The slide's way in and out (one-shots; SlideOut ends in the run's right
		-- footfall, which Simulation/Poses lines up with it).
		SlideIn = id(101242607281195), -- o1 2026-11-20 overnight TP pass, splines (was 132143568389295)
		SlideOut = id(74616650786228), -- o1 2026-11-20 overnight TP pass, splines (was 108310232385404)
		SlideInPistol = id(104079399198035), -- o1 2026-11-20 overnight TP pass, splines (was 79156910221465)
		SlideOutPistol = id(105578957053278), -- o1 2026-11-20 overnight TP pass, splines (was 79155087791028)
		SlideInKnife = id(89987757226261), -- o1 2026-11-20 overnight TP pass, splines (was 81899005096253)
		SlideOutKnife = id(140321397952166), -- o1 2026-11-20 overnight TP pass, splines (was 109072548908167)
	}),
	-- What others see you do with the gun (tools/studio/MakeCombatPoseAnimations.luau,
	-- 2026-11-04): aiming down sights (three pitch poses blended like the hip
	-- set, by the Aim input), a reload one-shot played at the gun's reload
	-- time (server player attributes ReloadAt / ReloadFor) and a flinch when
	-- hit (HitAt).
	COMBAT = table.freeze({
		AdsUp = id(87449585195829), -- o2 2026-11-20: breathing hold (was 88665317482255)
		AdsLevel = id(86480588512249), -- o2 2026-11-20: breathing hold (was 95863412039587)
		AdsDown = id(86597667703377), -- r2 2026-11-21: breathing hold, head looks down (o2 77870476375092; was 139601720262674)
		Reload = id(110565531734561), -- o1 2026-11-20 overnight TP pass, splines (was 102765870602957) -- v7 2026-11-15: a low-ready swap, the face stays clear (v6 112777133763655 stood the rifle up over the head)
		PistolReload = id(99293327658491), -- o1 2026-11-20 overnight TP pass, splines (was 120367219025692) -- sidearms
		Flinch = id(82256896150427), -- r2 2026-11-21: on splines, the hit lands as an impact (was 134800149922990)
		Death = id(88289196924695), -- o1 2026-11-20 overnight TP pass, splines (was 120072987587692) -- going down (DeathFxController, on the falling copy)
		Victory = id(71447089078892), -- the old match-end winners (fist pumps, tools/anim 2026-11-12); unused since the win cutscene (WIN below, 2026-11-20)
		-- The knife: a ready hold while it's out, a slash and the heavy (alt)
		-- on each swing (server player attributes SwingAt / SwingHeavy).
		-- A weapon swap: the new gun comes in low and rises (played at its
		-- equipTime; made DRAW_LENGTH long).
		Draw = id(137689336920879), -- o1 2026-11-20 overnight TP pass, splines (was 116807890408322)
		KnifeReady = id(84124615647002), -- o2 2026-11-20: breathing hold (was 84503652869545; 2026-11-05: arms cleared of the torso)
		-- Knife swings (2026-11-05, tools/studio/make_knife_poses.py; every
		-- frame keeps the limbs within 0.015 studs of the torso on the block
		-- rig). The old single slash was 103765524428295, the old heavy
		-- 87481489934854.
		KnifeSlash = id(77623478703999), -- GG_KnifeSlash1: forehand (SwingStep 1)
		KnifeSlash2 = id(108779916506580), -- GG_KnifeSlash2: backhand (SwingStep 2)
		KnifeSlash3 = id(126637574050244), -- GG_KnifeSlash3: the overhead chop (SwingStep 3)
		KnifeHeavy = id(88566487693718), -- o1 2026-11-20 overnight TP pass, splines (was 103333794439708) -- GG_KnifeHeavy: pull back, coil, thrust
	}),
	-- The recoil pose of each hold above, by the hold's name (2026-11-15,
	-- tools/anim/tp_clips.py Kick* clips, v1): the gun pulled into the
	-- shoulder, muzzle up, chest rocked back, head still. Util/BodyRecoil
	-- blends a share of it over the hold on every shot (Config/Juice BODY_KICK).
	RECOIL = table.freeze({
		AimUp = id(95144292931563),
		AimLevel = id(76597005020546),
		AimDown = id(109221910357149), -- r2: head as the hold (was 89250731384338)
		AdsUp = id(136021206805401),
		AdsLevel = id(73969040108481),
		AdsDown = id(131076841934336), -- r2 (was 132640996566965)
		PistolAimUp = id(71397627439679),
		PistolAimLevel = id(89288747742889),
		PistolAimDown = id(128468054309219), -- r2 (was 90306962924727)
		PistolAdsUp = id(117128552950066),
		PistolAdsLevel = id(93859139822565),
		PistolAdsDown = id(97409435633700), -- r2 (was 100422843394946)
	}),
	-- The left hand on each gun's LeftGrip (GripController IK, every visible
	-- character). The target rides on the gun itself, so the hand follows the
	-- gun through its kick with no lag. Positions in studs.
	GRIP = table.freeze({
		reachFraction = 0.96, -- of the arm's length to the block's end: how far the left hand may reach
		maxSlide = 1.5, -- how far back along the barrel the hand may slide to reach
		slideSmoothing = 18, -- 1/s: how fast that slide follows (so it never pops)
		-- The left elbow points here (UpperTorso space): out to the left side
		-- and down, so the support arm comes round the chest instead of
		-- through it (was (-1.2, -2.2, -0.6): the upper arm crossed into the
		-- chest, owner 2026-11-12).
		leftPole = Vector3.new(-2.6, -1.7, -0.1),
		-- The forearm block runs on past the hand part to the fingertips: this
		-- far below the hand's centre is the block's end, the point that goes
		-- to the grip.
		tip = 0.15,
		long = table.freeze({ under = 0.55, side = 0 }), -- the fist under the handguard, the gun on top of it
		sidearm = table.freeze({ under = 0.42, side = -0.62 }), -- beside the grip hand, under the pistol
		fadeIn = 14, -- 1/s
		fadeOut = 20,
		regrip = 0.15, -- seconds after a reload ends before the hand goes back
		afterModUse = 0.6, -- seconds the hand stays off after a Mod use (throw, place...)
		maxDistance = 220, -- studs from the camera beyond which nobody's grip is solved
	}),
	-- Knife marks on the world (WeaponController / EffectsController.slashMark):
	-- centred where the aim ray meets the surface, the gouge laid along each
	-- swing's path on screen (x right, y up), matching the first-person clips
	-- (Config/Viewmodel Slash1-3 / HeavyStab).
	KNIFE_MARK = table.freeze({
		paths = table.freeze({
			-- 2026-11-14 (owner's knife clip): forehand / backhand / a flatter
			-- forehand; the heavy's point dips into the target.
			Slash1 = Vector2.new(-0.85, -0.52), -- forehand: down-left from high right
			Slash2 = Vector2.new(0.97, 0.22), -- backhand: left to right, rising
			Slash3 = Vector2.new(-0.95, -0.3), -- forehand, flatter, across the chest
			HeavyStab = Vector2.new(-0.25, -1), -- the thrust: a short downward tear
		} :: { [string]: Vector2 }),
		light = table.freeze({ size = 0.36, stretch = Vector2.new(3.2, 0.22) }),
		heavy = table.freeze({ size = 0.5, stretch = Vector2.new(1.1, 0.5) }),
		tint = Color3.fromHex("5A5550"),
	}),

	-- A gun in third person (WeaponService world model): the grip joint from
	-- the right hand to the gun's handle. The visible fist is rigid on the
	-- forearm (shared/MatchBody: no wrist bend, no forearm twist), so the gun
	-- sits on the fist at one fixed angle per kind and the clips pose the arm
	-- to suit it (tools/anim/tp_rig.py rigid-fist solve; `python -I
	-- tools/anim/tp_rig.py grips` prints these two, which must match).
	-- Long guns: the pistol grip goes down into the fist's end, the barrel off
	-- its front, the forearm running out, down and back from the grip (the
	-- rifle stance). Sidearms: the barrel along the forearm, on the fist's
	-- front face (arms out). Until 2026-11-12 one grip served both and the
	-- clips bent the hand part up to 65 degrees and twisted the forearm up to
	-- 67, which the rigid fist doesn't show, so guns sat off the visible fist.
	GUN_WORLD_GRIP = CFrame.new(
		0.00000,
		-0.25000,
		-0.05000,
		-0.80640,
		-0.59136,
		0.00000,
		0.52087,
		-0.71027,
		0.47351,
		-0.28002,
		0.38184,
		0.88079
	),
	GUN_WORLD_GRIP_SIDEARM = CFrame.new(0, -0.15, -0.5) * CFrame.Angles(-math.pi / 2, 0, 0),

	-- The knife in third person (WeaponService world model): its handle sits
	-- in the fist with the blade pointing forward out of it (the hand's -Z),
	-- a forward grip. Guns use a grip turned -90 deg about X, which ran the
	-- knife's blade straight along the forearm, hidden in the body whenever
	-- the arm crossed it. tools/anim/tp_clips.py keys the clips for this grip
	-- on the rigid fist (`kfist`: fist, elbow pole, blade direction; §17).
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
		-- Swipes redrawn 2026-11-14 along the new slashes' tip paths (Config/
		-- Viewmodel Slash1-3, owner's knife clip): a thin streak that lives
		-- for the sweep only.
		Slash1 = table.freeze({
			swipe = {
				Vector3.new(1.05, 0.75, -2.3),
				Vector3.new(0.05, 0.2, -2.9),
				Vector3.new(-1.0, -0.6, -2.3),
			},
			kick = Vector2.new(0.55, 0.8),
			roll = 1.4,
			stop = 0.066,
		}),
		Slash2 = table.freeze({
			swipe = {
				Vector3.new(-1.1, -0.15, -2.3),
				Vector3.new(-0.05, 0.22, -2.9),
				Vector3.new(1.05, 0.05, -2.3),
			},
			kick = Vector2.new(0.55, 0.8),
			roll = 1.4,
			stop = 0.066,
		}),
		Slash3 = table.freeze({
			swipe = {
				Vector3.new(1.1, 0.35, -2.3),
				Vector3.new(0.05, 0.05, -2.9),
				Vector3.new(-1.05, -0.45, -2.3),
			},
			kick = Vector2.new(0.55, 0.85),
			roll = 1.2,
			stop = 0.08,
		}),
		HeavyStab = table.freeze({
			kick = Vector2.new(0.7, 1.2),
			roll = 0.8,
			stop = 0.1,
			fov = -3,
		}),
		-- 2026-11-14 (owner: "no oomph... add character"; research: the camera
		-- leads into the strike like a boxer's head, Destiny GDC): every swing,
		-- hit or miss, rolls the view `leadRoll` degrees along its path, starting
		-- `leadEarly` s before contact and easing back over `leadTime`. The miss
		-- punch (kick.X) went from 0.25-0.3 to 0.55-0.7 degrees.
		leadRoll = 1.6,
		leadEarly = 0.064, -- 0.05 until 2026-11-21: CameraController.rollKick rises over 20% of leadTime, so the roll peaked 14 ms after contact; now on it
		leadTime = 0.32,
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
		inspectFlips = { 1.6, 3.0 }, -- 2026-11-14 inspect (3.2 s): laid over pointing left, dropped out -- the turn-over and the return in InspectMelee (2.4 s) -- the two catches in InspectMelee (2.6 s since 2026-11-12; were 1.04, 1.82 of 2.3 s)
	}),

	ADS_SMOOTHING = 12, -- 1/s: how fast the hold moves between hip and sights
	RELOAD_LENGTH = 1, -- seconds the reload clip is made at
	DRAW_LENGTH = 0.5, -- seconds the draw clip is made at
	FLINCH_WEIGHT = 0.8, -- the flinch plays over the rest at this weight

	-- Roblox's Animate plays these instead of its stock clips (CharacterService).
	-- Its walk and run are an empty clip: the LOCOMOTION set carries the legs.
	ANIMATE = table.freeze({
		idle = id(114709237157503),
		walk = id(86109711469782),
		run = id(86109711469782),
		jump = id(117724474892981),
		fall = id(91199093837077),
	} :: { [string]: string }),
	RUN_SPEED = 16, -- studs/s the run clips are made for (rate = speed / this)
	SPRINT_RUN_SPEED = 22,
	WALK_CLIP_SPEED = 10, -- studs/s the walk clips are made for
	-- Ground speeds where the walk set hands over to the run set (aimed
	-- movement is 6.4 to 12.8 studs/s, Config/Weapons adsMoveMultiplier).
	WALK_RUN = table.freeze({ from = 12.5, to = 15 }),
	-- Leg clips come in eight directions, 45 degrees apart; within this share
	-- of a step from one of them, that one plays alone (fewer tracks: an
	-- Animator plays at most 16).
	DIRECTION_SNAP = 0.15,
	-- Leg clip speed clamp. Every leg clip plays at one cycle rate (speed over
	-- the blended stride), so this only guards the ends (was 0.6 to 1.5 for the
	-- run alone, which slid the feet under 10 studs/s).
	RUN_RATE = table.freeze({ min = 0.25, max = 1.8 }),
	RUN_FROM = 1, -- studs/s where the legs start to move...
	RUN_FULL = 4, -- ...and where they fully do
	-- The landing squash: full weight landing at or under fullBelow studs/s,
	-- none from noneAbove (the run's bounce carries a running landing), and
	-- only after minAir seconds off the ground.
	LAND = table.freeze({ fullBelow = 6, noneAbove = 12, minAir = 0.2 }),
	SLIDE_OUT_LENGTH = 0.3, -- seconds: SlideOut's length (it ends in the run's footfall)

	-- Mods (tools/anim/tp_clips.py since 2026-11-12, on the block body; were
	-- tools/studio/MakeModAnimations.luau). ModHold loops while a held
	-- Mod is up (in place of the gun hold); the others play once on a use.
	MODS = table.freeze({
		-- Hold and use clips (keyed as controls and solved per frame; the old
		-- Studio set: MakeModAnimations.luau pass 2,
		-- 2026-11-04: wind-ups, snaps and follow-throughs, ending on the gun hold).
		ModHold = id(134481823269919), -- r3 2026-11-21: sways, weighs the item, head follows (was 79414521552493)
		Throw = id(119484404341094), -- r2 2026-11-21: the wind-up reads (item above and behind the head, free arm pointing at the target) (was 129085261001652) -- o1 2026-11-20 overnight TP pass, splines (was 80403547544782)
		Place = id(105011555120942), -- r2 2026-11-21: down on the crouch stance, bent over (the kneel buried the knee 0.39) (was 83199924746572) -- o1 2026-11-20 overnight TP pass, splines (was 92359767222451)
		Heal = id(81673360357171), -- r3 2026-11-21: cocked low by the right hip, sweeps up to front-right beside the face with the chest swinging behind it (was 120933430967429) -- r2 2026-11-21: device out front-right at shoulder height, free arm out to the side, no arms through the chest (was 77351510963020) -- o1 2026-11-20 overnight TP pass, splines (was 99974559870040)
		Lob = id(123753817056953), -- r2 2026-11-21: free arm reaches out front, the swing goes wide of the hip (was 85103387011074) -- o1 2026-11-20 overnight TP pass, splines (was 86298417428874) -- a held throw's underhand (Molly RMB)
		Cast = id(78257120931478), -- r3 2026-11-21: drawn low by the left hip, shoves up and out front-left with a 30-degree chest swing (was 78340199527777) -- r2 2026-11-21: leans harder into the shove (was 110417908522750) -- o2 2026-11-20 overnight TP pass, splines, no chest clipping (was 91161079508050) -- HeldSteer: the free hand pushes out (Firewall)
		-- Dash: the torso leans into the dash (Simulation/Poses, by direction).
		DashForward = id(93439510581896), -- r2 2026-11-21: on splines, no dead hold, half the hip tilt (the gun stays near level) (was 76094407168365)
		DashBack = id(120793622302960), -- r2 2026-11-21 (was 75006063877431)
		DashLeft = id(132861580697947), -- r2 2026-11-21 (was 93347970953423)
		DashRight = id(79475213572359), -- r2 2026-11-21 (was 110331158301717)
		-- Updraft: knees tuck on the launch.
		Updraft = id(134947951901387), -- r2 2026-11-21: the tuck keeps rising, half the hip tilt (the gun stays level) (was 122572879619635)
		-- Updraft Crash Down (tools/anim; was MakeSlamAnimations.luau): the dive
		-- (looped while UpdraftSlam = "Down") and the knee-and-fist landing
		-- (once). Uploaded 2026-11-03.
		UpdraftSlam = id(91174387556328),
		UpdraftSlamLand = id(112038871870364), -- r2 2026-11-21: a three-point landing on both feet (the knee-down one buried the knee 0.73 under the floor) (was 137908275018781) -- o1 2026-11-20 overnight TP pass, splines (was 131769446021191)
	}),
	MOD_FADE = 0.12, -- seconds the Mod hold fades in / out
	-- Seconds into a use clip that other players' bodies start it at
	-- (Simulation/Poses). ModUseAt lands when the first-person hand lets go
	-- (Config/Mods THROW_RELEASE), so a throw that played its whole coil from
	-- there trailed the canister already in the air. Joined mid-coil instead,
	-- the hand lets go about 60 ms after ModUseAt (Throw snaps at 0.17-0.23 s,
	-- Lob swings up through 0.2-0.38 s; tools/anim/tp_clips.py). Round 3.
	MOD_USE_START = table.freeze({
		Throw = 0.14,
		Lob = 0.2,
	}) :: { [string]: number },
	MOD_USE_FADE = 0.06, -- seconds a use clip fades in over the hold (from its start)
	SLAM_FADE = 0.08, -- seconds the Crash Down dive pose fades in / out

	-- Degrees baked into the Up / Down hold poses (tools/studio/MakeHoldAnimations).
	-- The extended hold (2026-11-05) keeps the forearms off the chest only up to
	-- these angles on the match body; past them the pose holds (aim beyond
	-- ~45 deg up / 30 deg down is rare in a duel).
	AIM_PITCH_UP = 45,
	AIM_PITCH_DOWN = 30,
	CROUCH_WALK_SPEED = 9, -- studs/s that CrouchWalk plays at 1x (Movement.CROUCH_SPEED)
	CROUCH_WALK_LENGTH = 0.3, -- seconds: one crouch-walk cycle (tools/anim/tp_clips.py CROUCH_LENGTH)
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
	-- The end-of-match winner cutscene (Config/WinCutscene, Util/WinCutscene):
	-- Win<team size>_<slot> is keyed to the ending song and ends on the final
	-- pose, its Hold loops that pose with a breath (tools/anim/win_clips.py).
	WIN = table.freeze({
		-- v10 2026-11-20 (round 3): every key cleared of clipping and big wrist
		-- twists (tools/anim/win_fix.py); earlier Win1_1 v1-v9 up to 138336403992094,
		-- hold up to 110107132585954 (vault Win Cutscene → Review rounds)
		Win1_1 = id(106929085431227), -- slot 1, the best player: the solo performance
		Win1_1Hold = id(104387787932719),
		-- slots 2-5 in the 2-5 player scenes (tools/anim/win_group.py)
		WinS2 = id(72681296384469), -- the showman: arms wide, fist pumps, beckons, a hop, down on one knee
		WinS2Hold = id(123751947911029),
		WinS3 = id(114906106837218), -- the cool one: finger gun, the gun to the sky, down on one knee
		WinS3Hold = id(122667225125155),
		WinS4 = id(113819442314250), -- the hype one: both arms up, a sideways aim, a big hop, a V
		WinS4Hold = id(110977103612982),
		WinS5 = id(100674335372888), -- the chill one: a salute, a lazy shrug, points at the sky
		WinS5Hold = id(135062579610102),
	} :: { [string]: string }),
})
