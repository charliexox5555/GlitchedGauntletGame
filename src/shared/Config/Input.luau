--!strict
-- Input Action System bindings (Gunplay.md §6). The client InputController
-- builds an InputContext with one InputAction per entry. Touch buttons are
-- linked by name from the HUD.

export type Binding = {
	keys: { Enum.KeyCode },
	gamepad: { Enum.KeyCode },
	touch: string?, -- name of the HUD button that drives this action
}

local bindings: { [string]: Binding } = {
	Fire = {
		keys = { Enum.KeyCode.MouseLeftButton },
		gamepad = { Enum.KeyCode.ButtonR2 },
		touch = "FireButton",
	},
	Aim = {
		keys = { Enum.KeyCode.MouseRightButton },
		gamepad = { Enum.KeyCode.ButtonL2 },
		touch = "AimButton",
	},
	Reload = {
		keys = { Enum.KeyCode.R },
		gamepad = { Enum.KeyCode.ButtonX },
		touch = "ReloadButton",
	},
	Sprint = {
		keys = { Enum.KeyCode.LeftShift },
		gamepad = { Enum.KeyCode.ButtonL3 },
		touch = "SprintButton",
	},
	Crouch = {
		keys = { Enum.KeyCode.C, Enum.KeyCode.LeftControl },
		gamepad = { Enum.KeyCode.ButtonB },
		touch = "SlideButton",
	},
	Primary = { keys = { Enum.KeyCode.One }, gamepad = {} },
	Secondary = { keys = { Enum.KeyCode.Two }, gamepad = {} },
	Melee = { keys = { Enum.KeyCode.Three }, gamepad = {} },
	CycleWeapon = { keys = {}, gamepad = { Enum.KeyCode.ButtonY }, touch = "SwapButton" },
	QuickMelee = { keys = { Enum.KeyCode.V }, gamepad = { Enum.KeyCode.ButtonR3 } },
	-- Inspect the held gun (Valorant uses Y, but Y is the dev picker here).
	Inspect = { keys = { Enum.KeyCode.F }, gamepad = { Enum.KeyCode.DPadDown } },
	-- Studio-only dev picker: weapon menu, next primary / next secondary.
	DevMenu = { keys = { Enum.KeyCode.P }, gamepad = {} },
	DevNextPrimary = { keys = { Enum.KeyCode.T }, gamepad = {} },
	DevNextSecondary = { keys = { Enum.KeyCode.Y }, gamepad = {} },
}

return table.freeze(bindings)
