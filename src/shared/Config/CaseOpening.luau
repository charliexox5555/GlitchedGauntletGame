--!strict
-- The in-world case opening (vault/01 Design/Case Opening.md), RIVALS-style (owner
-- 2026-11-20): the crate is tossed out in front of you, shakes, the latches flip, the
-- lid bursts open in the tier colour, the skin rises with its name card, then flies
-- into you. Everyone nearby sees it. Timings studied from RIVALS' skin case (reveal
-- 2.0 s after landing, ~4.9 s total, 7 studs out, card ~8 studs up) and rebuilt with
-- our crate (Shared/CrateLook) and effects. Numbers only; Util/CaseOpening plays it.

local function s(id: number, volume: number, pitch: number?)
	return table.freeze({
		id = "rbxassetid://" .. tostring(id),
		volume = volume,
		pitch = pitch or 1,
	})
end

return table.freeze({
	SCALE = 1.6, -- the crate model is 3.1 studs; RIVALS' skin case is ~6.4
	DISTANCE = 6.5, -- studs in front of the player it lands
	TRY_ANGLES = { 0, 35, -35, 70, -70, 110, -110, 180 }, -- degrees off the facing when blocked

	TOSS = 1.0, -- s, from the chest to the floor, ~1.5 bounces
	TOSS_HEIGHT = 3.2, -- studs of the first arc
	TOSS_SPIN = 50, -- degrees of yaw it turns while flying

	SHAKE_EVERY = 0.55, -- s between shakes while waiting / building up
	SHAKES = 2, -- at least this many before the latches
	SHAKE_ANGLES = { 4, 7, 9 }, -- degrees, growing
	WAIT_LIMIT = 10, -- s without the server's answer → it sinks away

	LATCH_GAP = 0.1, -- s between the two latches
	LATCH_TIME = 0.18,
	LATCH_ANGLE = 130,
	COIL = 0.32, -- s after the latches: the crate dips (anticipation)
	LID_AT = 0.5, -- s after the latches: the lid bursts
	LID_TIME = 0.24,
	LID_ANGLE = 105, -- positive X = open (tools/studio/BuildCrate.luau)
	LID_OVERSHOOT = 14,

	RISE_DELAY = 0.12, -- s after the lid: the skin starts rising
	RISE_TIME = 0.9,
	RISE_HEIGHT = 2.9, -- studs above the crate top (scaled)
	SKIN_LENGTH = 4.4, -- the revealed skin is fitted to this (studs)
	SPIN_SPEED = 40, -- degrees / s after the first turn
	CARD_UP = 1.9, -- studs above the skin
	CARD_SIZE = Vector2.new(6.6, 1.9), -- studs (BillboardGui); 5.6 clipped "SEALWORK VANDAL"

	HOLD = 3.2, -- s the skin and card stay
	FLY_TIME = 0.85, -- s into the player
	SINK_TIME = 0.6, -- s the crate takes to sink away

	LIGHT_RANGE = 16,
	LIGHT_PEAK = 2.2, -- 6 washed the player out white (playtest 2026-11-20)

	-- Licensed sounds (Pro Sound Effects, Roblox UI packs, APM). PROVISIONAL:
	-- auditioned by the owner next.
	SOUNDS = table.freeze({
		Toss = s(15675028888, 0.25, 1.2), -- Roblox Whoosh_02
		Land = s(9117456325, 0.6), -- PSE "Plastic Cooler Hits 3": a hollow hard case
		Shake = s(9117456325, 0.35, 1.25),
		Latch = s(9119727934, 0.9), -- PSE "Plastic Switch 14"
		Lid = s(15675028888, 0.45, 0.9),
		Swell = s(9043336050, 0.3), -- APM "SWELL 22"
		Collect = s(17208323435, 0.6), -- Roblox "GUI - Equip"
		Sink = s(15675046931, 0.2, 0.9), -- Roblox Sweep
	}),
	-- one reveal stinger per tier
	REVEAL = table.freeze({
		Common = s(17208396156, 0.45), -- Roblox "GUI - Select"
		Rare = s(17208361335, 0.4), -- Roblox "GUI - Notification High"
		Epic = s(9042542887, 0.35), -- APM "Universal Flip - Hit"
		Legendary = s(9043151109, 0.35), -- APM "Get Up And Go - Hit"
		Exclusive = s(9043151109, 0.35),
	}),
	OTHERS_VOLUME = 0.5, -- someone else's opening is quieter (RIVALS does the same)
	ROLLOFF = Vector2.new(8, 70), -- studs: full volume / silent
})
