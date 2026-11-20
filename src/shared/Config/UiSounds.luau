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
	-- Shared/UiSfx. PROVISIONAL Roblox-pack picks until the owner picks from
	-- art-source/audio/ui/UiReel.wav (Kenney CC0) and those are uploaded.
	-- RIVALS' rule kept: few sounds, quiet, a click on every button, nothing
	-- loud on hover; a hover tick only on big items (owner pick).
	HoverBig = cue(15675032796, 0.1, 1.35, 0.07, 0.04), -- Small_Click, high and faint
	Click = cue(15675059323, 0.3, 1, 0.04, 0.03), -- Bright_Click: any button
	Confirm = cue(15675055424, 0.38, 1.05, 0.1), -- Cute_Pop: queue a mode, equip, claim
	Back = cue(15675032796, 0.28, 0.85, 0.08), -- Small_Click, low: close / back
	Tab = cue(15675032796, 0.26, 1.12, 0.05, 0.02), -- Small_Click: a tab or page of a list
	ToggleOn = cue(15675059323, 0.28, 1.18, 0.05),
	ToggleOff = cue(15675059323, 0.26, 0.88, 0.05),
	SliderTick = cue(15675032796, 0.08, 1.5, 0.045, 0.05), -- per step while dragging
	PageOpen = cue(15674975792, 0.16, 1.1, 0.2), -- Whoosh_03, soft: a menu page opens
	QueueJoin = cue(15675043410, 0.36, 1.1, 0.5), -- Tonal_Stinger: searching starts
	QueueLeave = cue(15675081158, 0.3, nil, 0.5), -- Cute_Goodbye: searching stops
	MatchFound = cue(15675043410, 0.5, 1.25, 1), -- the stinger, higher
	LockerIn = cue(15675028888, 0.32, 1.05, 0.3, 0.08), -- Whoosh_02: the camera rises
	LockerOut = cue(15675046931, 0.28, 0.9, 0.3, 0.08), -- Sweep: back to the lobby
	Equip = cue(15675037413, 0.32, 1, 0.08, 0.1), -- Paper_Swipe: the shown gun / skin changes
})
