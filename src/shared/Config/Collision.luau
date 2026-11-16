--!strict
-- Physics collision groups. Every combatant (player characters, bots, range and
-- dev dummies) is in BODIES: it does not collide with itself, so nobody
-- body-blocks anybody, but it still collides with the Default group (walls,
-- floors) and still answers raycasts and spatial queries (those run in Default
-- unless a RaycastParams / OverlapParams sets another group). Set on the server
-- by CharacterService.

return table.freeze({
	BODIES = "Bodies",
	DEFAULT = "Default",
})
