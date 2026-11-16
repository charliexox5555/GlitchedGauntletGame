--!strict
-- The server / FPS / ping readout in the top bar row, lobby and match
-- (vault/02 Art/UI Match Overhaul.md; after RIVALS' "Details" chip).

return table.freeze({
	-- Where the server is: one lookup per server at start (the server's own
	-- IP only, no player data). Off, or a failed lookup: a short server id.
	REGION_LOOKUP = true,
	REGION_URL = "https://ipinfo.io/json",
	-- Ping bands (ms), like RIVALS: under `good` 3 bars, under `ok` 2, else 1.
	PING = table.freeze({ good = 60, ok = 150 }),
	REFRESH = 0.5, -- seconds between readout updates
	FPS_FRAMES = 20, -- frames averaged for the FPS
	-- Gap (design px) between the readout and the screen's right edge, per
	-- place: the lobby's top bar has its own buttons there.
	RIGHT_INSET = table.freeze({ match = 16, lobby = 208 }),
})
