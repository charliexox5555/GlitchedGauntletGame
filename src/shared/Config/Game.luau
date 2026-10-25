--!strict
-- Global gameplay constants. Replicated to clients: nothing secret here, and
-- the server never trusts a client-reported value from this file.

return table.freeze({
	MAX_HEALTH = 100,
	ROUNDS_TO_WIN = 5,
	ROUND_LENGTH = 50,
	OVERTIME_LENGTH = 15,
	DRAFT_TIME = 12,
	OPENING_DRAFT_TIME = 20,
})
