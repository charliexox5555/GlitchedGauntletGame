--!strict
-- Development helpers. Everything here only runs inside Studio
-- (RunService:IsStudio()), never in a live server.

return table.freeze({
	-- Studio playtests run the test range (Config/TestRange) when the place
	-- has no Workspace "TestMode" attribute. The attribute always wins; it's
	-- the switch for published servers (shared/TestMode).
	TEST_RANGE = true,
	-- Studio players start with the Mod dev panel's "Test mode: unlimited
	-- charges" on (casting spends nothing; there are no rounds to refill
	-- charges yet). The panel (F8) turns it off to test the real charges.
	UNLIMITED_CHARGES = true,
	-- Studio matches: every level-1 ability's upgrade cards include its glitch
	-- path (to see and test glitches without waiting on the ~8% roll).
	ALWAYS_GLITCH_CARDS = false,
	-- Seconds before a test-panel dummy (F8) stands up again after going down.
	DUMMY_RESPAWN = 3,
})
