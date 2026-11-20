# Overtime zone playtest

- **Visual review.** Checked the new meshes and curtain material at player height in Whitebox and in a second view of the 4-stud circle. The bright edge stayed readable against the white ground and in shadow. The curtain remained transparent over cover.
- **Studio run.** Local 2v2 Play with one human and three bots on Whitebox under Automatic authority. A temporary damage guard let the normal round clock reach sudden death. The zone shrank from 111.83 studs to 4 over 20 seconds.
- **Boundary and cleanup.** The client saw all three imported meshes, confirmed that they have no collision, touch or query, and compared their size with the server radius across 163 samples. Crossing outside showed the warning tint and reduced HP from 100 to 92.44. Returning inside stopped the damage. Clearing the zone removed its visual folder and tint. Removed the temporary Studio test script and map override.
- **Checks.** StyLua, Selene and both Rojo builds passed. The new art is staged in the open Match place. The place version was neither saved nor published in this task.

## Sky curtain and preview

- Checked the 320-stud curtain from Whitebox against the sky. The new upper texture is visible above cover.
- In local Match Play with TestMode off, the Client Command Bar triggered a preview at 68 studs in diameter using the uploaded curtain texture. It reached 8 studs in diameter and cleared automatically at 20 seconds. A second run cleared early with `false`. No server zone or warning tint appeared during the preview. Use the Client command context for this workflow.
- StyLua, Selene and both Rojo builds passed. The new texture and scripts are staged in the open Match place.

[Source art, preview command and Studio setup](../../02%20Art/Overtime%20Zone.md)
