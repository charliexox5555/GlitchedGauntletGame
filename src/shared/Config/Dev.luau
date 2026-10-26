--!strict
-- Development helpers. Everything here only runs inside Studio
-- (RunService:IsStudio()), never in a live server.

return table.freeze({
	-- Studio playtests run the test range (Config/TestRange) when the place
	-- has no Workspace "TestMode" attribute. The attribute always wins; it's
	-- the switch for published servers (shared/TestMode).
	TEST_RANGE = true,
	-- P opens the weapon menu (every gun); T / Y cycle the primary / secondary.
	WEAPON_PICKER = true,
})
