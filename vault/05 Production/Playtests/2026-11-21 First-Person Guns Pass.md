# 2026-11-21 First-Person Guns Pass (overnight lane FP)

Lane FP of the [overnight animation pass](../Overnight%202026-11-20%20Animation%20Pass.md) (grades, evidence and what's not verified are in its FP section). Everything is committed locally on main, not pushed. **No Studio-owned changes**, so there's no place to save.

## What changed
1. **Sniper scope:** the scope's glass lens (`ScopeLens`, Glass material) fades out early in the aim (`VM.SCOPE_LENS`, aim 0.12 → 0.40), so its reflective eyepiece can no longer sit in the middle of the view on the way in or out. Works for every scoped gun and every skin, because they all name the part `ScopeLens`.
2. **Slide lean, one piece:** a new shared spring (`Util/SlideTilt`) drives the camera roll, the crosshair and hit-marker tilt, the sniper reticle and a new **viewmodel cant** (`VM.SLIDE_CANT`: 9° at the hip, 20° aimed). They all move on the same curve in the same frame: in with a quick snap (~70 ms, a touch past, settle), out on RIVALS' camera spring as before.
3. **ADS tilts with the crosshair:** aimed, the gun leans the full 20° about the line of sight, so the sights stay centred. Scoped, the reticle leans with it.
4. **All gun clips are smoother:** the gun clips (Fire, Reload, Draw, Inspect, shell loops) now play on a monotone cubic between their 24 fps keys instead of straight lines, so nothing changes speed in a corner every 42 ms. This also applies to the guns other players hold.
5. **Marshal hammer:** it rests cocked and stays cocked through the empty reload. It used to snap 32° down at the end of every shot and at the start of an empty reload.
6. **Reload (shared rifle track):** on its way out to the charging handle the gun no longer stops dead halfway (t 0.62) before jerking on.

## What to test
- [ ] **Scope:** aim and un-aim with the Marshal, Outlaw and Operator, slowly and quickly, in a stock skin and a couple of skins (Ruin-Blighted Operator, Prism). Nothing glassy or reflective should flash in the middle at any point. Does the lens fading as the gun comes up read OK at the hip end of the move?
- [ ] **Slide, hip:** sprint and slide with a rifle, a pistol and the knife. The crosshair, the screen roll and the gun should lean together as one piece. Is 9° of gun lean right? (`Config/Viewmodel SLIDE_CANT.hip`)
- [ ] **Slide, aimed:** slide, then aim mid-slide, with a rifle and the Marshal (scoped). The sights and the scope reticle lean 20° with the crosshair. Too much? (`SLIDE_CANT.ads`; the crosshair's own 20 is `Config/Crosshair slideTilt`)
- [ ] **Slide entry:** the crosshair now takes ~70 ms to tilt instead of one frame, so it moves together with the screen. Does it still feel like a snap? (`Juice.SLIDE rollInSpeed` 36: higher is snappier)
- [ ] **ADS in and out** on a rifle, the Sheriff and a sniper: smooth, no pop. If ADS still feels off, say where: the gun's travel, the zoom, or the scope cut.
- [ ] **Gun clips:** fire, reload (tactical and empty), inspect and draw a few guns (Vandal, Sheriff, Bucky shells, Marshal lever, Odin). Is anything mushier than before? Snaps should still snap.
- [ ] **Marshal:** the hammer stays back between shots and during reloads; it only falls on the shot.
- [ ] **Ruin-Blighted guns:** reload and inspect the Vandal and Operator. The conjured mag should never jump while you can see it.

## Round 2 (2026-11-21, after the owner played round 1)
All first person only (other players and the third-person body keep the stock motion). Local commits, not pushed; no Studio-owned changes, so no place to save.

**What changed**
1. **Ruin-Blighted Operator bolt:** the Ruin-Blighted guns have no bolt geometry, and the hand used to dive to the empty bolt joint inside the receiver. Now the hand stays on its grip when there's nothing to work (also on the Ruin-Blighted Vandal, Guardian and Spectre charging handles).
2. **Bat heavy (right-click):** on contact the bat now stands up the middle of the screen with its art toward you and the sweet spot on the crosshair. It used to point straight into the screen, edge-on.
3. **Fan inspect:** its own "fanning yourself" move. The fan stays low, gives seven relaxed waves from the "wrist" (the fist and fan turn together, the arm barely moves), and the leaf flexes behind each wave. It lasts 4.6 s, and the knife's toss is gone.

**What to test**
- [ ] **Ruin-Blighted Operator:** fire a few shots and reload. The right arm should never go into the gun. Is it fine that there's no bolt gesture at all, or do you want something there (a mist rack)?
- [ ] **Bat (PopCircuit) heavy:** right-click a few times. Does the bat read properly on contact now? Is the lean right?
- [ ] **Fan (Giltfold) inspect:** is it low enough, long enough and smooth? Do the waves read as a wrist flick? Too fast or too big (17° turn, ~2.2 waves a second)?
- [ ] **Stinger and Outlaw reloads:** the measured check found the rising Stinger mag touching the right forearm and the Outlaw's loading arm meeting the barrels, both hidden behind the gun in frozen frames. Do you see anything odd there at full speed?
