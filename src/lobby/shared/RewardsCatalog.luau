--!strict
-- The Rewards screen's rows (Controllers/RewardsController; vault/02 Art/UI
-- Lobby Overhaul.md → Missing screens). The coin amounts are placeholders
-- for the economy, which will grant them (server-checked) later; today a
-- row's button either opens Roblox's own prompt ("prompt") or is SOON.

export type Action = "favorite" | "invite" | "notify" | "soon"
export type Reward = { id: string, title: string, sub: string, coins: number, action: Action }

return table.freeze({
	{
		id = "favorite",
		title = "FAVOURITE THE GAME",
		sub = "Add it to your favourites so it's one tap away.",
		coins = 50,
		action = "favorite",
	},
	{
		id = "invite",
		title = "INVITE A FRIEND",
		sub = "Send a friend an invite to play with you.",
		coins = 100,
		action = "invite",
	},
	{
		id = "notify",
		title = "TURN ON NOTIFICATIONS",
		sub = "Hear about new seasons, skins and events.",
		coins = 50,
		action = "notify",
	},
	{
		id = "group",
		title = "JOIN THE GROUP",
		sub = "Join our Roblox group for drops and news.",
		coins = 100,
		action = "soon",
	},
	{
		id = "like",
		title = "LIKE THE GAME",
		sub = "Give it a thumbs up on its page.",
		coins = 50,
		action = "soon",
	},
	{
		id = "codes",
		title = "CODES",
		sub = "Redeem codes from our socials.",
		coins = 0,
		action = "soon",
	},
}) :: { Reward }
