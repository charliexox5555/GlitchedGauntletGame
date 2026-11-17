--!strict
-- What the lobby NPCs say (owner 2026-11-16: "talk to him to open up your locker ... very similar to RIVALS").
-- RIVALS' DialogLobby: a message, then reply buttons; a reply goes to another line, opens a page, or closes.
-- An NPC model carries `Talk = <id>` (Build_V4 from the lobby builder); NpcTalk shows lines[start] first.
-- Data only: replies can only move between these lines or open a lobby menu by its Router name.

export type Reply = {
	text: string,
	go: string?, -- the next line's key
	open: string?, -- a Router menu to open ("Locker", "Shop", ...)
	close: boolean?, -- ends the talk
	primary: boolean?, -- the main reply (gamepad selection starts on it)
}

export type Line = { say: string, replies: { Reply } }

export type Npc = { name: string, start: string, lines: { [string]: Line } }

local NpcTalk: { [string]: Npc } = {
	armorer = {
		name = "ARMORER",
		start = "hello",
		lines = {
			hello = {
				say = "Back again? Every gun in here is wearing the skin you picked.",
				replies = {
					{ text = "Open my Locker", open = "Locker", primary = true },
					{ text = "What's new?", go = "news" },
					{ text = "Goodbye", close = true },
				},
			},
			news = {
				say = "Fresh crates came in: Poolside and Rootglass. A skin for every gun.",
				replies = {
					{ text = "Show me", open = "Locker", primary = true },
					{ text = "Goodbye", close = true },
				},
			},
		},
	},
}

return table.freeze(NpcTalk)
