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

	-- Mods (tools/studio/MakeModAnimations.luau). ModHold loops while a held
	-- Mod is up (in place of the gun hold); the others play once on a use.
	MODS = table.freeze({
		ModHold = id(72886949328296),
		Throw = id(113960439440452),
		Place = id(102573901472605),
		Heal = id(116476893527219),
		-- Dash: the torso leans into the dash (Simulation/Poses, by direction).
		DashForward = id(132740788102457),
		DashBack = id(128130101853691),
		DashLeft = id(117063604285762),
		DashRight = id(107635192627945),
		-- Updraft: knees tuck on the launch.
		Updraft = id(125684824115691),
	}),
	MOD_FADE = 0.12, -- seconds the Mod hold fades in / out

	AIM_PITCH_RANGE = 70, -- degrees baked into AimUp / AimDown
	CROUCH_WALK_SPEED = 9, -- studs/s that CrouchWalk plays at 1x (Movement.CROUCH_SPEED)
	MOVING_SPEED = 1.5, -- studs/s above which crouching counts as walking

	-- Seconds each pose takes to fade in or out (the Animator's own weight
	-- fade), so state changes blend instead of popping.
	FADE = table.freeze({
		aim = 0.15,
		sprint = 0.2,
		crouch = 0.15,
		slide = 0.12,
	}),
	-- Weights snap to steps of this size, so tiny pitch changes don't restart
	-- a fade every simulation step.
	WEIGHT_STEP = 0.05,
})
