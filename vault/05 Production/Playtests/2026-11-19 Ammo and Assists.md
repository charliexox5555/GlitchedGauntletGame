# Ammo and assists playtest

Local 2v2 Studio Play with one human and three bots under Automatic authority.

- **Loadout progression.** The client chose Sheriff in round two and received no primary. Picking a primary in round three equipped Stinger and granted Classic as the backup.
- **Ammo.** A temporary two-round reserve accelerated edge-case testing. Swapping during a Bucky reload kept one inserted shell and left one in reserve. A Classic that had fired three rounds loaded only the two rounds remaining in its reserve. After firing the last Bucky shell, the desktop HUD read **NO AMMO**, and the server confirmed 0 loaded and 0 reserve after swapping. The production supply was checked for all 17 firearms.
- **Assist feedback.** The server used a player Mod hit followed by an allied bot elimination to exercise the real assist ledger. The scoreboard added one assist and the desktop client showed the popup and feed tag. A separate run forced the compact touch layout and verified that the assist tag and reserve text fit.
- **Checks.** StyLua, Selene and both Rojo builds passed. Temporary scripts and overrides were removed. The ammo budgets have yet to be measured in human-versus-human matches.

[Ammo rules](../../01%20Design/Gunplay.md#round-ammunition) · [Kill feed](../../02%20Art/UI%20Feed%20and%20Spectate.md#assist-feedback)
