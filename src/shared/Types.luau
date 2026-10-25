--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema, config shapes) live here so both sides agree.

export type PlayerProfile = {
	version: number,
	level: number,
	xp: number,
}

return nil
