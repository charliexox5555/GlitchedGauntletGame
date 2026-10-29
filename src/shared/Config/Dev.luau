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
})
