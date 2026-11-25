--!strict
-- The touch controls a player can customise (vault/02 Art/UI Mobile Controls.md
-- → Build plan v1): Settings → TOUCH draws a section per group, the layout
-- editor moves and resizes the objects. Names are the objects in the Studio
-- screen UI.Match.Touch.

export type Group = {
	key: string, -- settings ids: "touch" .. key .. "On" / "Custom" / "Alpha"
	label: string,
	buttons: { string },
	canHide: boolean, -- Fire and Jump always show
	desc: string,
}

local GROUPS: { Group } = {
	{
		key = "Fire",
		label = "FIRE",
		buttons = { "FireButton" },
		canHide = false,
		desc = "Hold to fire. Always shown.",
	},
	{
		key = "Aim",
		label = "AIM",
		buttons = { "AimButton" },
		canHide = true,
		desc = "Tap to aim down sights (a toggle on touch).",
	},
	{
		key = "Jump",
		label = "JUMP",
		buttons = { "JumpButton" },
		canHide = false,
		desc = "Jump. Always shown.",
	},
	{
		key = "Slide",
		label = "SLIDE / CROUCH",
		buttons = { "SlideButton" },
		canHide = true,
		desc = "Slide while running, crouch while standing.",
	},
	{
		key = "Reload",
		label = "RELOAD",
		buttons = { "ReloadButton" },
		canHide = true,
		desc = "Reload your gun.",
	},
	{
		key = "Sprint",
		label = "SPRINT",
		buttons = { "SprintButton" },
		canHide = true,
		desc = "Sprint toggle (hidden while Auto Sprint is on).",
	},
	{
		key = "Mods",
		label = "POWERS",
		buttons = { "Mod1Button", "Mod2Button", "Mod3Button", "ModAltButton" },
		canHide = true,
		desc = "Your drafted powers.",
	},
	{
		key = "Weapons",
		label = "WEAPON SLOTS",
		buttons = { "PrimaryButton", "SecondaryButton", "MeleeButton" },
		canHide = true,
		desc = "Switch between your primary, sidearm and melee.",
	},
	{
		key = "QuickMelee",
		label = "QUICK MELEE",
		buttons = { "QuickMeleeButton" },
		canHide = true,
		desc = "A quick knife swing without switching weapons.",
	},
	{
		key = "Scoreboard",
		label = "SCOREBOARD",
		buttons = { "ScoreboardButton" },
		canHide = true,
		desc = "Hold to see the scoreboard.",
	},
	{
		key = "Inspect",
		label = "INSPECT",
		buttons = { "InspectButton" },
		canHide = true,
		desc = "Inspect your gun.",
	},
}

-- Everything the layout editor can move: the buttons, the stick's resting
-- spot and the ammo readout.
local EXTRA = { "StickRest", "AmmoReadout" }
local MOVABLE: { [string]: boolean } = {}
local MOVABLE_LIST: { string } = {}
local GROUP_OF: { [string]: Group } = {}
for _, g in GROUPS do
	for _, b in g.buttons do
		MOVABLE[b] = true
		table.insert(MOVABLE_LIST, b)
		GROUP_OF[b] = g
	end
end
for _, b in EXTRA do
	MOVABLE[b] = true
	table.insert(MOVABLE_LIST, b)
end

return table.freeze({
	GROUPS = GROUPS,
	MOVABLE = MOVABLE,
	MOVABLE_LIST = MOVABLE_LIST,
	GROUP_OF = GROUP_OF,
	-- readable names for the editor's selection label
	EXTRA_LABELS = table.freeze({ StickRest = "MOVE STICK", AmmoReadout = "AMMO" }),
	PROFILES = 3,
	SIZE_MIN = 0.6, -- the editor's size range (× the default size)
	SIZE_MAX = 1.6,
	SIZE_STEP = 0.1,
	OPACITY_MIN = 20, -- %
	DOUBLE_TAP_MIN = 0.15, -- s
	DOUBLE_TAP_MAX = 0.5,
	-- The move stick (TouchController; vault/03 Research/Rivals Reference/
	-- Mobile Controls.md). The base stays where the thumb landed for the whole
	-- touch (like Roblox's dynamic thumbstick, which RIVALS uses): pulling past
	-- the ring is full speed in that direction, easing back slows down, and only
	-- crossing the spot you started on turns you around.
	STICK = table.freeze({
		deadZone = 0.08, -- × the ring radius: no move inside this
		fullSpeedAt = 0.55, -- × the ring radius: full speed from here out
		speedCurve = 1, -- 1 = speed rises in a straight line from the dead zone
		lockPush = 1.05, -- sprint lock: the thumb this far past the ring...
		lockAhead = -0.75, -- ...straight ahead (its direction's screen y at most this)...
		lockHold = 0.2, -- ...for this long (s) locks sprint
		unlockBack = 0.35, -- pulling back past this (screen y of the move) unlocks it
	}),
	HIT_SLOP = 12, -- px: a touch this close outside a combat button still presses it
	SLIDE_PRESS = 0.25, -- s: how long a slide tap holds Crouch
	-- Buttons a swipe may turn the camera through while CAMERA THROUGH
	-- BUTTONS is on (you aim with them held). Every other button keeps its
	-- touch, so a tap on Jump or Reload never jerks the view (RIVALS: all of
	-- its buttons keep their touch).
	CAMERA_THROUGH = table.freeze({
		FireButton = true,
		AimButton = true,
		Mod1Button = true,
		Mod2Button = true,
		Mod3Button = true,
	}),
})
