--!strict
-- Level and device marks next to a player in the match (top bar, Tab
-- scoreboard; vault/02 Art/UI Match Overhaul.md). After RIVALS: every row
-- says how far along a player is and what they play on.
--   Level: the Player attribute "Level" (set by progression once it exists;
--   until then everyone reads LV 1, like the lobby's player list).
--   Device: the Player attribute "Device", set by the server (DeviceService)
--   from what the client reports, one of DEVICES.

return table.freeze({
	DEVICES = table.freeze({ PC = true, Mobile = true, Console = true, VR = true }),
	ICONS = table.freeze({ -- our own icons, art-source/ui/device-icons
		PC = "rbxassetid://129201745616025",
		Mobile = "rbxassetid://121370141674931",
		Console = "rbxassetid://121722165024062",
		VR = "rbxassetid://139564768973107",
	}),
	RATE = { 2, 3 }, -- Device remote: per second, burst
})
