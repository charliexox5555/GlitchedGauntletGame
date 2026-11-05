--!strict
-- The match avatar (vault/01 Design/Match Avatar.md): one standard body for
-- every combatant in the match place, so holds land and hitboxes are equal.
-- The Lobby keeps players' own avatars.

return table.freeze({
	-- Width and depth of every arm part (upper arm, forearm, hand), studs.
	-- The default blocky R15 arm is 1.0; the first-person arm block is 0.5
	-- (Config/Viewmodel ARM_WIDTH). The hand gets the forearm's cross-section,
	-- so forearm and hand read as one block.
	ARM_WIDTH = 0.6,

	-- Body scales written on the standard description (Humanoid NumberValues).
	SCALES = table.freeze({
		height = 1,
		width = 1,
		depth = 1,
		head = 1,
		bodyType = 0,
		proportion = 0,
	}),

	-- Accessories kept from the player's own avatar: "hair" (hair only),
	-- "all" or "none". Bullets ignore accessories either way
	-- (CharacterService). Pending the user's decision; hair only until then.
	ACCESSORIES = "hair" :: "hair" | "all" | "none",

	-- What else is kept from the player's own avatar.
	KEEP_CLOTHING = true, -- classic Shirt, Pants, T-shirt
	KEEP_FACE = true,
	KEEP_SKIN = true, -- the six body colours

	-- How long to wait for a player's own description before falling back to
	-- the plain standard body (seconds), and how often to retry.
	FETCH_TIMEOUT = 6,
})
