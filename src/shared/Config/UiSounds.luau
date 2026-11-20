--!strict
-- UI sounds (vault/02 Art/UI Design.md → Sound). PROVISIONAL: unauditioned
-- picks from Roblox's own UI sound pack ("Roblox_UI_*", creator Roblox) and
-- one APM Music sting (APMOfficial), all licensed for experiences, so nothing
-- is uploaded. Audition them in Studio with tools/studio/AuditionUiSounds.luau,
-- then swap any you don't like here. Played 2D through the "Ui" sound group
-- by Util/UiSound.

export type Cue = {
	id: string,
	volume: number,
	pitch: number?, -- default 1
	gap: number?, -- seconds before the same cue can play again (hover spam)
	spread: number?, -- random pitch +- this (repeated sounds don't sound stamped)
}

local function cue(n: number, volume: number, pitch: number?, gap: number?, spread: number?): Cue
	return {
		id = "rbxassetid://" .. tostring(n),
		volume = volume,
		pitch = pitch,
		gap = gap,
		spread = spread,
	}
end

-- A UI sound backed by an individual Roblox audio asset.
local function atlas(name: string, volume: number, pitch: number?, gap: number?): Cue
	return { id = "atlas:" .. name, volume = volume, pitch = pitch, gap = gap }
end

return table.freeze({
	-- Hover and select: a real recorded click (CC0, atlas UiClick; 2026-11-05).
	-- Were Roblox_UI_Small_Click 15675032796 and Roblox_UI_Bright_Click 15675059323.
	Hover = atlas("UiClick", 0.3, 1.2, 0.06),
	Select = atlas("UiClick", 0.7),
	LockIn = cue(15675043410, 0.6), -- Roblox_UI_Tonal_Stinger
	Denied = cue(15675075163, 0.45, nil, 0.25), -- Roblox_UI_Delete
	Open = cue(15675028888, 0.45), -- Roblox_UI_Whoosh_02: the draft slides in
	CardIn = cue(15674975792, 0.18, 1.2, 0.04), -- Roblox_UI_Whoosh_03, per card, very soft
	Close = cue(15675046931, 0.4), -- Roblox_UI_Sweep: the draft leaves
	Tick = cue(15675085146, 0.4, nil, 0.3), -- Roblox_UI_Indicator: last seconds of a clock
	TickFinal = cue(15675085146, 0.55, 1.35, 0.3), -- the same, higher, on the last count
	Banner = cue(15675012262, 0.45), -- Roblox_UI_Whoosh_04: a banner slams in
	Fight = cue(15675043410, 0.55, 1.25), -- the stinger, higher: the barrier drops
	RoundWon = cue(15675043410, 0.6, 1.1), -- the stinger, brighter
	RoundLost = cue(15675062723, 0.5), -- Roblox_UI_Whistle_Low
	Victory = cue(1837945707, 0.5), -- APM "Strategic Victory Stinger"
	ZoneWarn = cue(15675085146, 0.5, 0.72, 0.3), -- Roblox_UI_Indicator, low: outside the sudden-death circle
	Score = cue(15675055424, 0.4, 0.9), -- Roblox_UI_Cute_Pop, lower: a score diamond fills

	-- Lobby menus (owner 2026-11-20 brought UI sounds back: "consistent, not
	-- over the top"; vault/02 Art/UI Polish Pass.md → Sounds). Played by
	-- Shared/UiSfx. Round 2 (owner, same day): the bright click, the gun /
	-- skin switch sound and the Settings ticks were too much. Now one soft
	-- round tap for every click (Kenney CC0 drop_002, art-source/audio/ui/
	-- UiClick_Soft.wav) and a tiny tick for tabs / toggles (click_002,
	-- UiTick_Soft.wav), all quiet; no sound for switching guns or skins.
	-- round 3 (owner: the tick was high-pitched, "just fun sounds that add to
	-- the game"): the tiny tick is gone; everything is the one soft round tap,
	-- a little lower, with small pitch steps for meaning
	-- round 4 (owner picked from the F4 audition board, 2026-11-20): real
	-- recordings from Roblox's licensed Pro Sound Effects library (creator
	-- "ProSoundEffects", nothing uploaded). The round tap is gone. Round 5:
	-- hover, confirm and match found picked from Roblox's own UI pack and APM
	-- (volumes level-matched by measured loudness).
	HoverBig = cue(17208343514, 0.4, 1, 0.08, 0.03), -- Roblox "GUI - Hover 02": big items and the bottom bar (0.67 was too loud)
	Click = cue(9119717529, 0.3, 1, 0.04, 0.03), -- PSE "Toggle Button 1": any button
	Confirm = cue(17208396156, 0.29, 1, 0.1), -- Roblox "GUI - Select": queue a mode
	Back = cue(9119703221, 0.3, 1, 0.08), -- PSE "Soft swish 14": close / back
	Tab = cue(9119704482, 0.25, 1, 0.05, 0.03), -- PSE "Paddle swish 1": a tab
	ToggleOn = cue(9119717523, 0.3, 1, 0.05), -- PSE "Toggle Button 2"
	ToggleOff = cue(9119717529, 0.3, 1, 0.05), -- PSE "Toggle Button 1"
	PageOpen = cue(15674975792, 0.1, 1.1, 0.2), -- Whoosh_03, very soft: a menu page opens (owner kept)
	QueueJoin = cue(15675043410, 0.3, 1.1, 0.5), -- Tonal_Stinger: searching starts
	QueueLeave = cue(9119703221, 0.26, 0.9, 0.5), -- the close swish, lower: searching stops
	MatchFound = cue(9042542887, 0.23, 1, 1), -- APM "Universal Flip - Hit"
	-- Owner's backup for MatchFound: cue(17208361335, 0.3, 1, 1), Roblox "GUI - Notification High"
	LockerIn = cue(15675028888, 0.16, 1.1, 0.3, 0.06), -- Whoosh_02, soft: into the Locker
	LockerOut = cue(15675046931, 0.14, 0.95, 0.3, 0.06), -- Sweep, soft: back to the lobby
})
