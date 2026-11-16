# Full-length gun audio in the match range

2026-11-14 · Studio match place 133387545285290 · TestMode on · atlas v9 97238006800068

[Sound Library Pick §18](../../02%20Art/Sound%20Library%20Pick.md) has the before and after lengths, mix measurements and audition folder.

| Check | Result |
|---|---|
| Range controls with the final loudness targets | Equipped all 18 items. Fired a tap and fast sequence on every gun, reloaded every gun, and played light and heavy knife attacks. 247 gun reports and four knife swings reached their native Sound.Ended. |
| Full magazine runs earlier in the v9 test | Vandal, Phantom, Ares and Odin reached the last-round asset variant. A few automated input steps needed a second run. |
| Vandal final tail mix | First-shot region 0.093 s, isolated tail 2.532 s, last-round region 2.532 s. All eight interior takes played once during the ten-round check. Only the nine superseded tails stopped via the fade. |
| Positional overlap | Seven Judge streams at the configured fire interval. 70 of 70 shots reached Sound.Ended with up to 67 concurrent. |
| Dry fire and feedback | All 17 dry-fire slots resolved and played. Hit tick, all three metallic headshot variants, kill, damage, hard, metal/glass, wood and soft contacts played to completion. |
| Asset and local checks | v9 loaded to 255.936 s. Selene, StyLua and Rojo passed. |

The playback ledger is in the ignored file `art-source/audio/ProPack/audition/v9/Comparison/Studio QA.json`. Native playback and loudness measurements pass. The owner's listen on the Vandal and headshot revisions is still open.

## Follow-up

Rojo synced the +2.2 dB Vandal adjustment and short headshot tock. Real tap-fire on the range triggered the 0.093 s first-shot region and 2.532 s tail. Three aimed head hits each played one 0.250 s `hit_head_A` and no regular hit tick. A separate body hit played `125235091454234`. The published match place was outside this follow-up. The new cue and volume are ready for the owner's audition in the Studio copy.

## Standalone audio migration

Loaded all 368 new standalone asset IDs at their expected lengths in the Studio match. Normal range controls exercised all 17 guns and the knife using the separate clips. The roster log had 1,209 standalone cue starts and 250 native ends for the reports and knife swings. Vandal's opener, eight repeat takes, tail and last shot each used their own asset. Tested full-file harbour and wind loops in Dockyard. Results and the upload manifest are linked from [Sound Library Pick §19](../../02%20Art/Sound%20Library%20Pick.md).


## Final mix check

Measured the standalone gun reports and confirmed the existing level targets. Raised the body tick and headshot tock 3.5 dB and restored five missing headshot and kill assets. All 373 takes loaded at the expected lengths. Real range input played the body click on two body hits, used all three tocks across the head hits, and played the headshot kill pop on the lethal hit.
