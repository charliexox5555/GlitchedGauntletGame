--!strict
-- Gun review mode (Studio and test-mode servers only, GunReviewController):
-- a step-through of every gun's first-person look for the owner's per-gun
-- sign-off after the RemasterV2 import (vault/05 Production/Weapon RemasterV2.md).

return table.freeze({
	-- Review order: templates first (rifle, sidearm, melee), then by family.
	ORDER = table.freeze({
		"Vandal",
		"Classic",
		"Knife",
		"Phantom",
		"Guardian",
		"Bulldog",
		"Spectre",
		"Stinger",
		"Ghost",
		"Sheriff",
		"Shorty",
		"Bucky",
		"Judge",
		"Marshal",
		"Operator",
		"Ares",
		"Odin",
	}),
	KEYS = table.freeze({
		toggle = Enum.KeyCode.F6,
		prev = Enum.KeyCode.LeftBracket,
		next = Enum.KeyCode.RightBracket,
		draw = Enum.KeyCode.N, -- replay the draw (viewmodel only)
		reload = Enum.KeyCode.G, -- replay the tactical reload (viewmodel only)
		emptyReload = Enum.KeyCode.B, -- replay the empty reload (viewmodel only)
		slow = Enum.KeyCode.Z, -- cycle the speeds below
		freeze = Enum.KeyCode.X,
		good = Enum.KeyCode.K,
		needsWork = Enum.KeyCode.J,
	}),
	-- Workspace VfxTimeScale values Z cycles through (1 = normal speed).
	SPEEDS = table.freeze({ 1, 0.3, 0.1 }),
	-- What to look at for each gun; the game's own keys play them.
	STEPS = table.freeze({
		"Draw  (N, or swap with 1 / 2)",
		"Idle and sway (move the mouse, walk)",
		"Fire from the hip  (LMB)",
		"Aim and fire  (RMB + LMB)",
		"Reload  (G, or R with rounds spent)",
		"Empty reload  (B, or empty the mag + R)",
		"Inspect  (Y)",
		"Sprint  (Shift + W)",
		"Muzzle flash + shells  (fire with Z slow-mo)",
	}),
})
