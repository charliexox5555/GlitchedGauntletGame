--!strict
-- Input Action System bindings (Gunplay.md §6). The client InputController
-- builds an InputContext with one InputAction per entry. Touch buttons are
-- linked by name from the Touch screen (UI.Match.Touch, TouchController).
-- Aim, Sprint and Crouch have no touch name on purpose: on touch they are
-- toggles, driven by TouchController (owner: mobile ADS and sprint always
-- toggle; one Slide button: slide while running, else crouch toggle).

export type Binding = {
	keys: { Enum.KeyCode },
	gamepad: { Enum.KeyCode },
	touch: string?, -- name of the HUD button that drives this action
	-- the Settings KEYBINDS row (Config/Settings) whose saved keys replace
	-- `keys` / `gamepad` (server/Services/InputContextService)
	setting: string?,
	-- Value actions are fed by code, not keys (default: a Bool button).
	kind: ("Bool" | "Direction1D")?,
}

local bindings: { [string]: Binding } = {
	Fire = {
		setting = "kFire",
		keys = { Enum.KeyCode.MouseLeftButton },
		gamepad = { Enum.KeyCode.ButtonR2 },
		touch = "FireButton",
	},
	Aim = {
		setting = "kAim",
		keys = { Enum.KeyCode.MouseRightButton },
		gamepad = { Enum.KeyCode.ButtonL2 },
	},
	Reload = {
		setting = "kReload",
		keys = { Enum.KeyCode.R },
		gamepad = { Enum.KeyCode.ButtonX },
		touch = "ReloadButton",
	},
	Sprint = {
		setting = "kSprint",
		keys = { Enum.KeyCode.LeftShift },
		gamepad = { Enum.KeyCode.ButtonL3 },
	},
	Crouch = {
		setting = "kCrouch",
		keys = { Enum.KeyCode.C, Enum.KeyCode.LeftControl },
		gamepad = { Enum.KeyCode.ButtonB },
	},
	Primary = {
		keys = { Enum.KeyCode.One },
		gamepad = {},
		touch = "PrimaryButton",
		setting = "kPrimary",
	},
	Secondary = {
		keys = { Enum.KeyCode.Two },
		gamepad = {},
		touch = "SecondaryButton",
		setting = "kSecondary",
	},
	Melee = {
		keys = { Enum.KeyCode.Three },
		gamepad = {},
		touch = "MeleeButton",
		setting = "kMelee",
	},
	CycleWeapon = { keys = {}, gamepad = { Enum.KeyCode.ButtonY }, setting = "kCycle" },
	QuickMelee = {
		setting = "kQuickMelee",
		keys = { Enum.KeyCode.V },
		gamepad = { Enum.KeyCode.ButtonR3 },
		touch = "QuickMeleeButton",
	},
	-- Frees or re-locks the mouse (CameraController.freeMouse), owner 2026-11-16.
	FreeMouse = { keys = { Enum.KeyCode.M }, gamepad = {}, setting = "kFreeMouse" },
	-- Inspect the held gun (Y like Valorant).
	Inspect = {
		setting = "kInspect",
		keys = { Enum.KeyCode.Y },
		gamepad = { Enum.KeyCode.DPadDown },
		touch = "InspectButton",
	},
	-- Mod slots (Mods.md → Controls). Simulation input: Dash and Updraft
	-- are predicted from these (shared/Simulation/Abilities); held Mods are
	-- equipped by ModController. Crouch stays on C / Left Ctrl.
	Mod1 = {
		keys = { Enum.KeyCode.Q },
		gamepad = { Enum.KeyCode.ButtonL1 },
		touch = "Mod1Button",
		setting = "kMod1",
	},
	Mod2 = {
		keys = { Enum.KeyCode.E },
		gamepad = { Enum.KeyCode.ButtonR1 },
		touch = "Mod2Button",
		setting = "kMod2",
	},
	Mod3 = {
		keys = { Enum.KeyCode.T },
		gamepad = { Enum.KeyCode.DPadUp },
		touch = "Mod3Button",
		setting = "kMod3",
	},
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
	-- Studio / test mode / owner only: the Mod dev test panel (DevModController).
	DevPanel = {
		keys = { Enum.KeyCode.F8 },
		-- View / Select: the D-pad moves between the panel's buttons.
		gamepad = { Enum.KeyCode.ButtonSelect },
		touch = "DevPanelButton",
	},
}

return table.freeze(bindings)
