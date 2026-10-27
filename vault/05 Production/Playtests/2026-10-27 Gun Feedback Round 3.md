# Gun feedback, round 3 (user playtest, 2026-10-27)

The user's notes after playing round 2, verbatim in quotes. Same two sessions: **Studio** (`guns-studio`) owns the ADS camera and hand-follow logic; **Blender** (`guns-blender`) owns sight geometry and clips. Tick items off with the commit hash.

- [ ] **Bucky reload**: "Bucky Reload animation still looks glitched. tilt outwards to reload." Find the glitch (clip vs camera track vs hand follow), then make the gun tilt **outward** (rolling its loading port toward the player) while shells feed from the bottom, cleanly in and out of the shell loop.
- [ ] **Bulldog ADS + sights**: "Bulldog sights are messed up. and looks weird ads still." Check the open-iron geometry on the bullpup (rear ring / front post placement and size) and the ADS sight picture.
- [ ] **Spectre ADS**: "Same ADS issue as bulldog where the gun is kind of glitched."
- [ ] **Odin ADS**: "same ads issue as bulldog."
  - Bulldog, Spectre and Odin share it, so look for one shared cause first: near-plane clipping at `OPEN_IRONS_ADS` 0.3 behind the rear ring, the eye-ray `adsHide` hiding the wrong parts, AimPoint vs sight-line mismatch, or the hip-offset compensation. Fix the cause, then check all 8 open-iron guns.
- [ ] **Marshal reload**: "Marshall reload looks bad. Should be reloading with right hand." Rounds go into the loading gate with the **right** hand (the left hand keeps the gun steady), so the clip and the hand-follow need to change.
