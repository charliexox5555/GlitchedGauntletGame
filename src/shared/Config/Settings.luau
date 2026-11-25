--!strict
-- The Settings screen's rows, as data (vault/02 Art/UI Settings.md). The
-- lobby's SettingsController draws them, Shared/PlayerSettings cleans and
-- saves them. Change a label, default or range here.
--
-- Values are stored flat by row id: booleans, numbers, choice strings, colours
-- as 6-digit hex ("FF4D5E") and keybinds as { keyboard, alt, controller }
-- Enum.KeyCode names ("" = unbound). Most rows aren't read by gameplay yet
-- (owner, 2026-11-21: "just the ability to edit them and toggle things on/off").

-- "action" = a button that opens something (not saved); "layout" = saved
-- data with no row of its own (hidden), e.g. a touch layout profile.
export type Kind = "toggle" | "slider" | "choice" | "color" | "key" | "action" | "layout"

export type Row = {
	id: string,
	label: string,
	desc: string,
	kind: Kind,
	default: any,
	-- sliders
	min: number?,
	max: number?,
	step: number?,
	unit: string?, -- shown after the number ("%", " ms")
	-- choices
	choices: { string }?,
	-- layout and rules
	sub: boolean?, -- indented under the row above
	showIf: { id: string, value: any }?, -- only shown while that row has that value
	lockIf: { id: string, value: any, why: string }?, -- greyed out while that row has that value
	phoneLock: string?, -- greyed out on touch controls (Shared/InputMode), with this note
	note: string?, -- a small line under the label ("CONTROLLER AND PHONE ONLY")
	warn: boolean?, -- the note is a warning (red)
	confirm: boolean?, -- choices: a change asks KEEP within CONFIRM_SECONDS or goes back
	locked: boolean?, -- keybinds: shown, can't be changed (Roblox's own)
	hidden: boolean?, -- saved but never drawn (touch layout profiles)
	button: string?, -- action rows: the button's text ("EDIT")
}

export type Section = { title: string, rows: { Row } }
export type Tab = { id: string, label: string, sections: { Section } }

local TouchControls = require(script.Parent.TouchControls)

local function toggle(id: string, label: string, default: boolean, desc: string): Row
	return { id = id, label = label, kind = "toggle", default = default, desc = desc }
end
local function pct(
	id: string,
	label: string,
	default: number,
	min: number,
	max: number,
	desc: string
): Row
	return {
		id = id,
		label = label,
		kind = "slider",
		default = default,
		min = min,
		max = max,
		step = 1,
		unit = "%",
		desc = desc,
	}
end
local function sub(r: Row): Row
	r.sub = true
	return r
end
local function color(id: string, label: string, default: string, desc: string): Row
	return { id = id, label = label, kind = "color", default = default, desc = desc, sub = true }
end
local function key(id: string, label: string, kb: string, alt: string, pad: string): Row
	return {
		id = id,
		label = label,
		kind = "key",
		default = { kb, alt, pad },
		desc = "Click a box, then press the key or button you want. Esc cancels, Backspace clears it.",
	}
end
local function roblox(id: string, label: string, kb: string, pad: string, desc: string): Row
	return {
		id = id,
		label = label,
		kind = "key",
		default = { kb, "", pad },
		desc = desc,
		locked = true,
	}
end

local TABS: { Tab } = {
	{
		id = "video",
		label = "VIDEO",
		sections = {
			{
				title = "PERFORMANCE",
				rows = {
					toggle(
						"optimizedLighting",
						"OPTIMIZED LIGHTING",
						false,
						"Simpler shadows and lights for a higher frame rate on slower devices."
					),
					toggle(
						"optimizedVfx",
						"OPTIMIZED VFX",
						false,
						"Fewer particles and lighter effects on shots, abilities and hits."
					),
					toggle(
						"optimizedTextures",
						"OPTIMIZED TEXTURES",
						false,
						"Plain surfaces instead of detailed textures on the maps."
					),
				},
			},
			{
				title = "CAMERA",
				rows = {
					pct(
						"sensitivity",
						"SENSITIVITY",
						50,
						1,
						100,
						"How fast the camera turns with your mouse or stick. The rows below scale it."
					),
					sub(
						pct(
							"sensAiming",
							"WHILE AIMING",
							100,
							1,
							200,
							"Sensitivity while aiming down sights, as a share of your sensitivity."
						)
					),
					sub(
						pct(
							"sensScoped",
							"WHILE SCOPED",
							45,
							1,
							200,
							"Sensitivity while looking through a sniper scope, as a share of your sensitivity."
						)
					),
					sub(
						pct(
							"sensHorizontal",
							"HORIZONTAL",
							100,
							1,
							200,
							"Left and right turning only."
						)
					),
					sub(pct("sensVertical", "VERTICAL", 100, 1, 200, "Up and down turning only.")),
					toggle("invertX", "INVERTED X", false, "Flips left and right camera turning."),
					toggle("invertY", "INVERTED Y", false, "Flips up and down camera turning."),
					{
						id = "fov",
						label = "FIELD OF VIEW",
						kind = "slider",
						default = 80,
						min = 70,
						max = 100,
						step = 1,
						desc = "How wide you see in a match. Wider shows more but makes targets smaller.",
					},
					pct(
						"viewmodelFov",
						"VIEWMODEL FOV",
						100,
						80,
						120,
						"How big your gun and arms look on screen. Lower shows more of the view."
					),
					pct(
						"cameraShake",
						"CAMERA SHAKES",
						100,
						0,
						100,
						"How much the camera shakes from shots, landings and explosions. 0 turns it off."
					),
				},
			},
			{
				title = "INTERFACE",
				rows = {
					toggle(
						"hideHud",
						"HIDE HUD",
						false,
						"Hides the match HUD: health, ammo, timers and the kill feed."
					),
					toggle(
						"hideSideTasks",
						"HIDE SIDE TASKS",
						false,
						"Hides the task list on the side of the screen."
					),
					toggle(
						"showKillFeed",
						"SHOW KILL FEED",
						true,
						"The list of recent kills in the corner of the screen."
					),
					toggle(
						"reducedMotion",
						"REDUCED MOTION",
						false,
						"Fades instead of slides, pops and shakes in every menu."
					),
				},
			},
			{
				title = "OTHER",
				rows = {
					toggle(
						"damageHighlight",
						"DAMAGE HIGHLIGHT",
						true,
						"Enemies you hit light up for a moment."
					),
					color(
						"highlightBase",
						"BASE COLOR",
						"FF3232",
						"The colour the highlight settles on."
					),
					color(
						"highlightFlash",
						"FLASH COLOR",
						"FFFFFF",
						"The colour of the quick flash on each hit."
					),
					{
						id = "colorblind",
						label = "COLORBLIND FILTER",
						kind = "choice",
						default = "Off",
						choices = { "Off", "Protanopia", "Deuteranopia", "Tritanopia" },
						desc = "Shifts enemy highlights and team colours so they stay easy to tell apart.",
					},
				},
			},
		},
	},
	{
		id = "audio",
		label = "AUDIO",
		sections = {
			{
				title = "VOLUME",
				rows = {
					pct("masterVolume", "MASTER VOLUME", 100, 0, 100, "Every sound in the game."),
					pct(
						"musicVolume",
						"MUSIC",
						70,
						0,
						100,
						"Lobby music, match music and the win song."
					),
					pct(
						"sfxVolume",
						"SOUND EFFECTS",
						100,
						0,
						100,
						"Guns, footsteps, abilities, hits and the world."
					),
					toggle(
						"uiSounds",
						"UI SOUNDS",
						true,
						"Clicks, tabs, toggles and the queue's sounds in every menu."
					),
				},
			},
		},
	},
	{
		id = "gameplay",
		label = "GAMEPLAY",
		sections = {
			{
				title = "COMBAT",
				rows = {
					toggle(
						"damageNumbers",
						"DAMAGE NUMBERS",
						true,
						"Numbers pop up over enemies you hit."
					),
					color("damageColor", "COLOR", "FFFFFF", "The colour of normal damage numbers."),
					color(
						"damageCritColor",
						"CRIT COLOR",
						"FF4D5E",
						"The colour of headshot damage numbers."
					),
					toggle(
						"hideTeammateTags",
						"HIDE TEAMMATE TAGS",
						false,
						"Hides the name tags over your teammates."
					),
					toggle(
						"aimAnimation",
						"AIMING ANIMATION",
						true,
						"The springy move and zoom when you aim down sights. Off: the gun and zoom go straight in, no bounce."
					),
				},
			},
			{
				title = "CONTROLS",
				rows = {
					{
						id = "toggleAim",
						label = "TOGGLE AIM",
						kind = "toggle",
						default = false,
						phoneLock = "ALWAYS ON FOR PHONES",
						desc = "Press once to aim, again to stop, instead of holding. Always on for phones.",
					},
					{
						id = "toggleCrouch",
						label = "TOGGLE CROUCH",
						kind = "toggle",
						default = false,
						phoneLock = "ALWAYS ON FOR PHONES",
						desc = "Press once to crouch, again to stand, instead of holding. Always on for phones.",
					},
					{
						id = "toggleSprint",
						label = "TOGGLE SPRINT",
						kind = "toggle",
						default = false,
						desc = "Press once to sprint, again to walk, instead of holding. Always on for phones.",
						phoneLock = "ALWAYS ON FOR PHONES",
						lockIf = {
							id = "autoSprint",
							value = true,
							why = "TURN OFF AUTO SPRINT FIRST",
						},
					},
					toggle(
						"autoSprint",
						"AUTO SPRINT",
						true,
						"You sprint whenever you move forward. Off: hold Sprint to run (phones get a Sprint button)."
					),
					{
						id = "scrollWeapons",
						label = "SCROLL WEAPONS",
						kind = "toggle",
						default = true,
						note = "MOUSE ONLY",
						phoneLock = "MOUSE ONLY",
						desc = "The scroll wheel switches between your weapons.",
					},
				},
			},
			{
				title = "ASSISTANCE",
				rows = {
					{
						id = "aimAssist",
						label = "AIM ASSIST",
						kind = "toggle",
						default = true,
						note = "CONTROLLER AND PHONE ONLY",
						desc = "Your aim slows and is pulled gently onto enemies near your crosshair while you aim. You can always aim away from it.",
					},
					{
						id = "aimAssistStrength",
						label = "STRENGTH",
						kind = "slider",
						default = 100,
						min = 0,
						max = 100,
						step = 1,
						unit = "%",
						sub = true,
						showIf = { id = "aimAssist", value = true },
						desc = "How strong the slowdown and pull are. 100 % is the game's tuned level.",
					},
					{
						id = "autoShoot",
						label = "AUTO SHOOT",
						kind = "choice",
						default = "Dynamic",
						choices = { "Disabled", "Custom", "Dynamic" },
						note = "CONTROLLER AND PHONE ONLY",
						desc = "Shoots for you when your crosshair is on an enemy. CUSTOM uses your reaction time below; DYNAMIC picks it for the gun.",
					},
					{
						id = "autoShootReaction",
						label = "REACTION TIME",
						kind = "slider",
						default = 25,
						min = 0,
						max = 500,
						step = 5,
						unit = " ms",
						sub = true,
						showIf = { id = "autoShoot", value = "Custom" },
						desc = "How long your crosshair has to stay on an enemy before Auto Shoot fires.",
					},
				},
			},
			{
				title = "OTHER",
				rows = {
					{
						id = "stickDeadzone",
						label = "STICK DEADZONE",
						kind = "slider",
						default = 10,
						min = 0,
						max = 50,
						step = 1,
						unit = "%",
						note = "CONTROLLER ONLY",
						phoneLock = "CONTROLLER ONLY",
						desc = "Stick drift: if your camera or character moves on its own, raise this until it stops. Keep it as low as you can.",
					},
					{
						id = "forceControls",
						label = "FORCE CONTROLS",
						kind = "choice",
						default = "Auto",
						choices = { "Auto", "Keyboard", "Controller", "Touch" },
						note = "WRONG CHOICE BREAKS YOUR CONTROLS",
						warn = true,
						confirm = true,
						desc = "Forces the controls and buttons of one device. Leave it on AUTO unless the game picks the wrong one: forcing a device you aren't using can leave you unable to play.",
					},
				},
			},
		},
	},
	{
		id = "crosshair",
		label = "CROSSHAIR",
		sections = {
			{
				title = "CROSSHAIR",
				rows = {
					{
						id = "chScale",
						label = "SIZE",
						kind = "slider",
						default = 1,
						min = 0.5,
						max = 2,
						step = 0.1,
						desc = "The whole crosshair, bigger or smaller.",
					},
					{
						id = "chColor",
						label = "COLOR",
						kind = "color",
						default = "FFFFFF",
						desc = "Pick a colour that stands out on the maps you play. The dark outline keeps any colour readable.",
					},
					{
						id = "chLength",
						label = "LENGTH",
						kind = "slider",
						default = 6,
						min = 2,
						max = 16,
						step = 1,
						desc = "How long each bar is.",
					},
					{
						id = "chThickness",
						label = "THICKNESS",
						kind = "slider",
						default = 2,
						min = 1,
						max = 6,
						step = 1,
						desc = "How thick each bar is.",
					},
					{
						id = "chGap",
						label = "GAP",
						kind = "slider",
						default = 4,
						min = 0,
						max = 16,
						step = 1,
						desc = "The space in the middle when you stand still. Moving and shooting still open it, unless it's STATIC.",
					},
					toggle("chDot", "CENTRE DOT", true, "A dot in the very middle."),
					toggle(
						"chOutline",
						"OUTLINE",
						true,
						"A dark edge around the bars and dot, so they read on bright walls and white flashes."
					),
					toggle("chX", "X SHAPE", false, "Turns the crosshair 45 degrees into an X."),
					toggle(
						"chStatic",
						"STATIC",
						false,
						"The gap stays put: moving and shooting don't open it."
					),
					toggle(
						"chShowAiming",
						"SHOW WHILE AIMING",
						false,
						"Keep the crosshair on screen while you aim down sights."
					),
				},
			},
			{
				title = "HITMARKERS",
				rows = {
					toggle(
						"hmEnabled",
						"SHOW HITMARKERS",
						true,
						"The marker that flashes on your crosshair when you hit someone."
					),
					{
						id = "hmStyle",
						label = "STYLE",
						kind = "choice",
						default = "Original",
						choices = { "Original", "Cross", "Dot" },
						desc = "ORIGINAL: the game's own marker, four blades that close in on your crosshair. CROSS: four thin lines. DOT: a small square.",
					},
					pct("hmSize", "SIZE", 100, 50, 150, "How big the hitmarker is."),
					{
						id = "hmColor",
						label = "HIT COLOR",
						kind = "color",
						default = "FFFFFF",
						desc = "The hitmarker's colour on a body shot.",
					},
					{
						id = "hmCritColor",
						label = "CRIT COLOR",
						kind = "color",
						default = "FF4D5E",
						desc = "The hitmarker's colour on a headshot or a kill.",
					},
				},
			},
		},
	},
	{
		id = "keybinds",
		label = "KEYBINDS",
		sections = {
			{
				title = "MOVEMENT",
				rows = {
					key("kForward", "WALK FORWARD", "W", "Up", "Thumbstick1"),
					key("kBack", "WALK BACKWARD", "S", "Down", "Thumbstick1"),
					key("kLeft", "STRAFE LEFT", "A", "Left", "Thumbstick1"),
					key("kRight", "STRAFE RIGHT", "D", "Right", "Thumbstick1"),
					key("kJump", "JUMP", "Space", "", "ButtonA"),
					key("kSprint", "SPRINT", "LeftShift", "", "ButtonL3"),
					key("kCrouch", "CROUCH / SLIDE", "C", "LeftControl", "ButtonB"),
				},
			},
			{
				title = "COMBAT",
				rows = {
					key("kFire", "ATTACK", "MouseLeftButton", "", "ButtonR2"),
					key("kAim", "AIM", "MouseRightButton", "", "ButtonL2"),
					key("kReload", "RELOAD", "R", "", "ButtonX"),
					key("kInspect", "INSPECT", "Y", "", "DPadDown"),
					key("kQuickMelee", "QUICK MELEE", "V", "", "ButtonR3"),
				},
			},
			{
				title = "WEAPONS",
				rows = {
					key("kPrimary", "PRIMARY", "One", "", ""),
					key("kSecondary", "SECONDARY", "Two", "", ""),
					key("kMelee", "MELEE", "Three", "", ""),
					key("kCycle", "SWITCH WEAPONS", "", "", "ButtonY"),
				},
			},
			{
				title = "MODS",
				rows = {
					key("kMod1", "MOD 1", "Q", "", "ButtonL1"),
					key("kMod2", "MOD 2", "E", "", "ButtonR1"),
					key("kMod3", "MOD 3", "T", "", "DPadUp"),
				},
			},
			{
				title = "INTERFACE",
				rows = {
					key("kScoreboard", "OPEN SCOREBOARD", "Tab", "", "ButtonSelect"),
					key("kFreeMouse", "FREE MOUSE", "M", "", ""),
				},
			},
			{
				title = "ROBLOX",
				rows = {
					roblox(
						"rMenu",
						"ROBLOX MENU",
						"Escape",
						"ButtonStart",
						"Roblox's own menu. Roblox keys can't be changed."
					),
					roblox(
						"rChat",
						"CHAT",
						"Slash",
						"",
						"Opens the chat box. Roblox keys can't be changed."
					),
					roblox(
						"rFullscreen",
						"FULLSCREEN",
						"F11",
						"",
						"Fullscreen on and off. Roblox keys can't be changed."
					),
				},
			},
		},
	},
}

-- Short key names for the keybind boxes.
local KEY_LABELS: { [string]: string } = {
	MouseLeftButton = "LMB",
	MouseRightButton = "RMB",
	MouseMiddleButton = "MMB",
	LeftShift = "L-SHIFT",
	RightShift = "R-SHIFT",
	LeftControl = "L-CTRL",
	RightControl = "R-CTRL",
	LeftAlt = "L-ALT",
	RightAlt = "R-ALT",
	Space = "SPACE",
	Escape = "ESC",
	Slash = "/",
	Return = "ENTER",
	Tab = "TAB",
	Backspace = "BKSP",
	CapsLock = "CAPS",
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Up = "UP",
	Down = "DOWN",
	Left = "LEFT",
	Right = "RIGHT",
	Thumbstick1 = "L-STICK",
	Thumbstick2 = "R-STICK",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	ButtonL1 = "L1",
	ButtonR1 = "R1",
	ButtonL2 = "L2",
	ButtonR2 = "R2",
	ButtonSelect = "VIEW",
	ButtonStart = "MENU",
	DPadUp = "D-UP",
	DPadDown = "D-DOWN",
	DPadLeft = "D-LEFT",
	DPadRight = "D-RIGHT",
}

local function keyLabel(name: string): string
	if name == "" then
		return ""
	end
	local short = KEY_LABELS[name]
	if short then
		return short
	end
	local b = string.match(name, "^Button(%u)$") -- ButtonA / ButtonX ...
	return string.upper(b or name)
end

-- TOUCH (vault/02 Art/UI Mobile Controls.md → Build plan v1): the layout,
-- then one section per touch button group (Config/TouchControls).
do
	local sections: { Section } = {
		{
			title = "LAYOUT",
			rows = {
				{
					id = "touchEditor",
					label = "LAYOUT EDITOR",
					kind = "action",
					default = nil,
					button = "EDIT",
					desc = "Move, resize and hide your touch buttons. Three layouts to switch between.",
				},
				toggle(
					"touchLeftHanded",
					"LEFT-HANDED",
					false,
					"Swaps the sides: the stick on the right, the buttons on the left."
				),
				{
					id = "touchOpacity",
					label = "BUTTON OPACITY",
					kind = "slider",
					default = 100,
					min = TouchControls.OPACITY_MIN,
					max = 100,
					step = 5,
					unit = "%",
					desc = "How solid every touch button is. A button with CUSTOM on uses its own.",
				},
				toggle(
					"touchCameraThrough",
					"CAMERA THROUGH BUTTONS",
					true,
					"A swipe that starts on a button still turns the camera."
				),
				toggle(
					"touchShowAmmo",
					"SHOW AMMO",
					true,
					"The ammo count under your weapon slots."
				),
			},
		},
		{
			title = "ATTACK",
			rows = {
				toggle(
					"touchDoubleTap",
					"DOUBLE TAP TO FIRE",
					false,
					"Tap the right side of the screen twice and hold to fire."
				),
				{
					id = "touchDoubleTapWindow",
					label = "DOUBLE TAP WINDOW",
					kind = "slider",
					default = 0.25,
					min = TouchControls.DOUBLE_TAP_MIN,
					max = TouchControls.DOUBLE_TAP_MAX,
					step = 0.05,
					unit = " s",
					sub = true,
					showIf = { id = "touchDoubleTap", value = true },
					desc = "How quickly the second tap has to follow the first.",
				},
				{
					id = "touchModCast",
					label = "ABILITY CASTING",
					kind = "choice",
					choices = { "Smart", "Equip" },
					default = "Smart",
					desc = "Smart: tap to quick-cast, hold to aim with preview and release to cast. Equip: tap to hold, then tap Fire.",
				},
			},
		},
	}
	for _, g in TouchControls.GROUPS do
		local rows: { Row } = {}
		if g.canHide then
			table.insert(
				rows,
				toggle(
					"touch" .. g.key .. "On",
					"ENABLED",
					true,
					"Shows or hides this button. " .. g.desc
				)
			)
		end
		table.insert(
			rows,
			toggle(
				"touch" .. g.key .. "Custom",
				"CUSTOM",
				false,
				"Gives this button its own opacity instead of BUTTON OPACITY."
			)
		)
		local alpha = pct(
			"touch" .. g.key .. "Alpha",
			"OPACITY",
			100,
			TouchControls.OPACITY_MIN,
			100,
			"This button's opacity."
		)
		alpha.sub = true
		alpha.step = 5
		alpha.showIf = { id = "touch" .. g.key .. "Custom", value = true }
		table.insert(rows, alpha)
		table.insert(sections, { title = g.label, rows = rows })
	end
	-- saved layouts (drawn by the editor, not as rows)
	local saved: { Row } = {
		{
			id = "touchProfile",
			label = "PROFILE",
			kind = "choice",
			default = "1",
			choices = { "1", "2", "3" },
			hidden = true,
			desc = "",
		},
	}
	for i = 1, TouchControls.PROFILES do
		table.insert(saved, {
			id = "touchLayout" .. i,
			label = "LAYOUT " .. i,
			kind = "layout",
			default = {},
			hidden = true,
			desc = "",
		})
	end
	table.insert(sections, { title = "", rows = saved })
	table.insert(TABS, { id = "touch", label = "TOUCH", sections = sections })
end

-- Row lookup by id.
local BY_ID: { [string]: Row } = {}
for _, tab in TABS do
	for _, section in tab.sections do
		for _, row in section.rows do
			assert(not BY_ID[row.id], "duplicate setting id " .. row.id)
			BY_ID[row.id] = row
		end
	end
end

return table.freeze({
	TABS = TABS,
	BY_ID = BY_ID,
	keyLabel = keyLabel,
	-- saving (Shared/PlayerSettings, Lobby SettingsService)
	MAX_BYTES = 14000, -- (3 touch layouts included) a save request's JSON may be at most this long
	CONFIRM_SECONDS = 10, -- Force Controls: time to press KEEP before it goes back
	SEND_DELAY = 1.5, -- client: seconds after the last change before it sends
	SAVE_DELAY = 6, -- server: seconds after the last save request before it writes
	SAVE_MIN_GAP = 30, -- server: seconds between two settings writes (the key is shared with purchases); leave / shutdown don't wait
	REPLICA = "Settings", -- the StringValue on the player with the saved values
})
