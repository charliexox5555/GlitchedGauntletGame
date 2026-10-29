--!strict
-- Input Action System bindings (Gunplay.md §6). The client InputController
-- builds an InputContext with one InputAction per entry. Touch buttons are
-- linked by name from the HUD.

export type Binding = {
	keys: { Enum.KeyCode },
	gamepad: { Enum.KeyCode },
	touch: string?, -- name of the HUD button that drives this action
	-- Value actions are fed by code, not keys (default: a Bool button).
	kind: ("Bool" | "Direction1D")?,
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
	-- Inspect the held gun (Y like Valorant).
	Inspect = { keys = { Enum.KeyCode.Y }, gamepad = { Enum.KeyCode.DPadDown } },
	-- Mod slots (Mods.md → Controls). Simulation input: Dash and Rollback
	-- are predicted from these (shared/Simulation/Abilities); held Mods are
	-- equipped by ModController. Crouch stays on C / Left Ctrl.
	Mod1 = { keys = { Enum.KeyCode.Q }, gamepad = { Enum.KeyCode.ButtonL1 }, touch = "Mod1Button" },
	Mod2 = { keys = { Enum.KeyCode.E }, gamepad = { Enum.KeyCode.ButtonR1 }, touch = "Mod2Button" },
	Mod3 = { keys = { Enum.KeyCode.T }, gamepad = { Enum.KeyCode.DPadUp }, touch = "Mod3Button" },
	-- Camera pitch / 90 degrees, fed every frame by PoseController. It's
	-- simulation input, so the server and the predicting client pose the
	-- character with the same pitch (shared/Simulation/Poses).
	AimPitch = { keys = {}, gamepad = {}, kind = "Direction1D" },
	-- Studio / test mode only: the weapon picker (every installed gun).
	WeaponPicker = {
		keys = { Enum.KeyCode.P },
		gamepad = { Enum.KeyCode.DPadLeft }, -- D-pad up is Mod 3
		touch = "PickerButton",
	},
}

return table.freeze(bindings)
