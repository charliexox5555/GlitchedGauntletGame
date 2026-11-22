--!strict
-- Numbers for how the saved settings change the game on each client
-- (Shared/SettingsApply, vault/02 Art/UI Settings.md → Wiring the settings).

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local SettingsApply = {}

-- CAMERA -----------------------------------------------------------------------
-- The sensitivity slider (1-100) that leaves the camera untouched; 100 = twice
-- as fast, 1 = a fiftieth.
SettingsApply.SENS_NEUTRAL = 50
-- The camera module's pitch limit (radians): a scaled turn never passes it.
SettingsApply.PITCH_LIMIT = math.rad(80)
-- Turns smaller than this (radians) are the camera module settling, not input.
SettingsApply.TURN_EPSILON = 1e-6
-- A frame's turn bigger than this (radians) is a camera reset (a menu handed
-- the camera back), not input: left alone.
SettingsApply.TURN_RESET = 1.2
-- Studs from Camera.Focus past which the camera orbits (third person) instead
-- of turning in place (first person).
SettingsApply.ORBIT_MIN = 1
-- Viewmodel FOV: studs the gun moves along the line of sight per 100 % away
-- from 100 % (80 % = 0.35 studs back, smaller; 120 % = 0.35 closer).
SettingsApply.VIEWMODEL_DEPTH = 1.75

-- PERFORMANCE ------------------------------------------------------------------
-- Optimized VFX: decorative particle counts (dust, chips, embers, smoke) are
-- multiplied by this and rounded down, so single puffs go and bursts thin out.
-- Flashes, tracers and hit markers (gameplay cues) are never scaled.
SettingsApply.VFX_EMIT_SCALE = 0.4
-- Optimized lighting: post effects switched off on this client (Bloom and
-- ColorCorrection stay: they set the look and cost little).
SettingsApply.LOW_LIGHT_FX = {
	SunRaysEffect = true,
	DepthOfFieldEffect = true,
	BlurEffect = true,
}
SettingsApply.LIGHT_CLASSES = {
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
}

-- INTERFACE --------------------------------------------------------------------
-- Hide HUD in a match: these match screens (PlayerScripts.UI.Match) are hidden.
-- The crosshair, scope, scoreboard, the draft, map vote and death / end screens stay.
SettingsApply.MATCH_HUD_GUIS = {
	"TopBar", -- round timer and score
	"BottomHud", -- health, ammo, Mods
	"KillFeed",
	"StatusTray",
}

-- Hide HUD in the lobby: the bottom bar (PLAY, menus) and its shades. The
-- player list and the top bar (Settings, the board) stay so the player can
-- turn it back on.
SettingsApply.LOBBY_HUD_GUIS = {
	"LobbyBar",
	"LobbyHudShade",
}
-- Hide Side Tasks (and Hide HUD): the side task list. LobbyTasks is off until a
-- tasks system exists (vault/05 Production/Bugs & Ideas.md).
SettingsApply.SIDE_TASK_GUIS = {
	"LobbyTasks",
}

-- COLOURBLIND ------------------------------------------------------------------
-- Palette swaps of the semantic colours (ColorCorrectionEffect has no colour
-- matrix, so a real filter isn't possible on Roblox). Measured with the
-- Machado 2009 simulation, Oklab distance (target 0.20): the default team pair
-- passes all three; the red hit highlight fails protan / deutan against grey
-- and green (0.03-0.14), so those modes swap it for amber (0.41). Unset fields
-- keep the default colour. `hitBase` only replaces the highlight while the
-- player's own BASE COLOR is still the default.
export type Palette = { ally: Color3?, enemy: Color3?, hitBase: Color3? }
SettingsApply.PALETTES = {
	Off = {} :: Palette,
	Protanopia = { hitBase = hex("FFC400") } :: Palette,
	Deuteranopia = { ally = hex("2F8CFF"), enemy = hex("FFB000"), hitBase = hex("FFC400") } :: Palette,
	Tritanopia = {} :: Palette, -- the defaults already pass (0.45 team, 0.26 hit vs grey)
}

return SettingsApply
