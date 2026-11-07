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
}

local function cue(n: number, volume: number, pitch: number?, gap: number?): Cue
	return { id = "rbxassetid://" .. tostring(n), volume = volume, pitch = pitch, gap = gap }
end

-- A slice of the game's sound atlas (Config/SoundAtlas).
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
})
