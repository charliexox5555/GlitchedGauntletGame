--!strict
-- UI and event sounds for the lobby AND the match (vault/02 Art/UI Polish
-- Pass.md → Sounds and Game-wide sound board). Every cue plays 2D through
-- Shared/UiSfx (one "UiSfx" SoundGroup at volume 1, pooled, gap + pitch
-- spread); the match's Util/UiSound is a thin wrapper over it, so the same
-- cue sounds the same in both places. Hit / kill / damage sounds are combat
-- feedback and live in Config/Sounds + Config/Audio instead.
--
-- THEME: the owner's picks (F4 audition board, 2026-11-20), shared by both
-- places. A change to a theme entry changes the lobby and the match. Sources
-- are licensed for experiences, nothing uploaded: Roblox's Pro Sound Effects
-- library (creator "ProSoundEffects", PSE), Roblox's own UI packs, APM Music.
--
-- Audition: Shared/SoundAudition (Studio only, F4 in a play test of either
-- place). Its candidate volumes are level-matched to the cues below.

export type Cue = {
	id: string,
	volume: number,
	pitch: number?, -- default 1
	gap: number?, -- seconds before the same cue can play again (hover spam)
	spread: number?, -- random pitch +- this (repeated sounds don't sound stamped)
}

local function cue(n: number, volume: number, pitch: number?, gap: number?, spread: number?): Cue
	return table.freeze({
		id = "rbxassetid://" .. tostring(n),
		volume = volume,
		pitch = pitch,
		gap = gap,
		spread = spread,
	})
end

-- The shared theme. History (lobby, 2026-11-20): Kenney round taps and ticks
-- were turned down ("a bubble, sci-fi cartoony", "high-pitched"); these real
-- recordings were picked from the F4 board in rounds 4-5.
local Theme = {
	Click = cue(9119717529, 0.3, 1, 0.04, 0.03), -- PSE "Toggle Button 1": any button / pick
	Hover = cue(17208343514, 0.4, 1, 0.08, 0.03), -- Roblox "GUI - Hover 02": big items only (0.67 was too loud)
	Confirm = cue(17208396156, 0.29, 1, 0.1), -- Roblox "GUI - Select": queue a mode
	Back = cue(9119703221, 0.3, 1, 0.08), -- PSE "Soft swish 14": close / back
	Tab = cue(9119704482, 0.25, 1, 0.05, 0.03), -- PSE "Paddle swish 1"
	ToggleOn = cue(9119717523, 0.3, 1, 0.05), -- PSE "Toggle Button 2"
	ToggleOff = cue(9119717529, 0.3, 1, 0.05), -- PSE "Toggle Button 1"
	Error = cue(15675075163, 0.32, nil, 0.25), -- Roblox_UI_Delete: refused / not ready / SOON
	PageOpen = cue(15674975792, 0.1, 1.1, 0.2), -- Roblox_UI_Whoosh_03, very soft: a menu page opens
}

-- The match cues below were played through the combat mix's "Ui" group at
-- 0.7 until 2026-11-20; their volumes were scaled by 0.7 when they moved to
-- UiSfx, so they sound as loud as before.
return table.freeze({
	-- Shared theme, lobby names
	Click = Theme.Click,
	HoverBig = Theme.Hover,
	Confirm = Theme.Confirm,
	Back = Theme.Back,
	Tab = Theme.Tab,
	ToggleOn = Theme.ToggleOn,
	ToggleOff = Theme.ToggleOff,
	PageOpen = Theme.PageOpen,
	Denied = Theme.Error,

	-- Shared theme, match names (draft and match-end). Hover and Select were
	-- "atlas:UiClick", which nothing plays any more (silent since the atlas
	-- prefix was dropped from AudioController); now the theme's.
	Hover = Theme.Hover,
	Select = Theme.Click,

	-- Lobby events
	QueueJoin = cue(15675043410, 0.3, 1.1, 0.5), -- Tonal_Stinger: searching starts
	QueueLeave = cue(9119703221, 0.26, 0.9, 0.5), -- the close swish, lower: searching stops
	MatchFound = cue(9042542887, 0.23, 1, 1), -- APM "Universal Flip - Hit"
	-- Owner's backup for MatchFound: cue(17208361335, 0.3, 1, 1), Roblox "GUI - Notification High"
	LockerIn = cue(15675028888, 0.16, 1.1, 0.3, 0.06), -- Whoosh_02, soft: into the Locker
	LockerOut = cue(15675046931, 0.14, 0.95, 0.3, 0.06), -- Sweep, soft: back to the lobby

	-- Match events (provisional: on the F4 board's MATCH tab)
	LockIn = cue(15675043410, 0.42), -- Roblox_UI_Tonal_Stinger
	Open = cue(15675028888, 0.32), -- Roblox_UI_Whoosh_02: the draft slides in
	CardIn = cue(15674975792, 0.13, 1.2, 0.04), -- Roblox_UI_Whoosh_03, per card, very soft
	Close = cue(15675046931, 0.28), -- Roblox_UI_Sweep: the draft leaves
	Tick = cue(15675085146, 0.28, nil, 0.3), -- Roblox_UI_Indicator: last seconds of a clock
	TickFinal = cue(15675085146, 0.39, 1.35, 0.3), -- the same, higher, on the last count
	Banner = cue(15675012262, 0.32), -- Roblox_UI_Whoosh_04: SUDDEN DEATH / MATCH POINT / DRAW
	Fight = cue(15675043410, 0.39, 1.25), -- the stinger, higher: the barrier drops
	RoundWon = cue(15675043410, 0.42, 1.1), -- the stinger, brighter
	RoundLost = cue(15675062723, 0.35), -- Roblox_UI_Whistle_Low
	-- Victory / Defeat: the toast and the match-end scene both ask for them
	-- at match end; the gap keeps it to one play (they used to stack).
	Victory = cue(1837945707, 0.35, nil, 4), -- APM "Strategic Victory Stinger"
	Defeat = cue(15675062723, 0.35, nil, 4), -- Roblox_UI_Whistle_Low (was the RoundLost cue)
	ZoneWarn = cue(15675085146, 0.35, 0.72, 0.3), -- Roblox_UI_Indicator, low: outside the sudden-death circle
	Score = cue(15675055424, 0.28, 0.9), -- Roblox_UI_Cute_Pop, lower: your team's score diamond fills
})
