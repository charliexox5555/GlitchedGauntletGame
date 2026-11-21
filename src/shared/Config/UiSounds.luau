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
	also: { Cue }?, -- layers played with it (a designed cue), see layered()
	delay: number?, -- a layer's start after the cue's (seconds)
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

-- A designed cue: the main sound plus layers ({ id, volume, delay?, pitch? })
-- played with it, each from its own pool.
local function layered(main: Cue, layers: { { number } }): Cue
	local also: { Cue } = {}
	for _, l in layers do
		table.insert(
			also,
			table.freeze({
				id = "rbxassetid://" .. tostring(l[1]),
				volume = l[2],
				delay = l[3],
				pitch = l[4],
			})
		)
	end
	local c = table.clone(main) :: any
	c.also = table.freeze(also)
	return table.freeze(c)
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
	-- Not enough coins / a refused purchase (owner 2026-11-20: "an error denied sound").
	-- Roblox "GUI - Negative" over a quiet low PSE buzz for weight; options on the F4
	-- board's PURCHASE DENIED row.
	PurchaseDenied = layered(cue(17208353912, 0.17, 1, 0.3), { { 9126041965, 0.07 } }),

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

	-- Match events. Owner's picks 2026-11-20 (board round 1): draft open /
	-- card in / draft close / lock in / Mod cues kept; Fight, RoundWon, RoundLost,
	-- Score and the ending song picked; the rest still on the F4 board.
	-- Round 2 picks (owner, same day): lock in, ticks, banner, ending song.
	LockIn = layered(cue(17208323435, 0.789), { { 9043336050, 0.119 } }), -- Roblox "GUI - Equip" + APM "SWELL 22" (low swell), soft
	Open = cue(15675028888, 0.32), -- Roblox_UI_Whoosh_02: the draft slides in
	CardIn = cue(15674975792, 0.13, 1.2, 0.04), -- Roblox_UI_Whoosh_03, per card, very soft
	Close = cue(15675046931, 0.28), -- Roblox_UI_Sweep: the draft leaves
	Tick = cue(9118138693, 0.405, nil, 0.3), -- PSE "Relay Clicks 15": last seconds of a clock
	TickFinal = cue(9118138693, 0.56, 1.2, 0.3), -- the same click, a little higher and louder, on the last count
	Banner = layered(cue(15675012262, 0.315), { { 17208361335, 0.076, 0.05 } }), -- Whoosh_04 + a faint Roblox "GUI - Notification High": SUDDEN DEATH / MATCH POINT / DRAW
	Fight = cue(9043151109, 0.235), -- APM "Get Up And Go - Hit": the barrier drops (owner: look for subtler)
	RoundWon = cue(9042542887, 0.284), -- APM "Universal Flip - Hit" (= match found)
	RoundLost = cue(17208214688, 0.438), -- Roblox "GUI - Call Decline" (owner: keep looking)
	-- The ending song (owner 2026-11-20: no victory / defeat noises; one short,
	-- positive song for everyone over the end cutscene that shows the winner;
	-- wants it a little longer, like RIVALS, so the cutscene can be cut to it).
	-- The VICTORY / DEFEAT toast and the match-end scene both ask for it; the
	-- gap plays it once.
	MatchEnd = cue(9042702890, 0.296, nil, 9), -- APM "Victory Slam stinger 1" (8 s); the end cutscene gets cut to it (owner's pick)
	ZoneWarn = cue(15675085146, 0.35, 0.72, 0.3), -- Roblox_UI_Indicator, low: outside the sudden-death circle
	Score = cue(17208319162, 0.672), -- Roblox "GUI - Pickup": your team's score diamond fills (owner: keep looking)
})
