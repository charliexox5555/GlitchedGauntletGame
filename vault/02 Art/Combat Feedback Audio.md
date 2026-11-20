# Combat Feedback Audio

## November 20, 2026 audition

The owner wants a short, satisfying slash for a headshot and a distinct, layered confirmation for a standard elimination. The headshot has a dry, stylized impact. The elimination uses a low strike followed by a pitched release, with room for a future Ruin-Blighted accent.

Match Studio place `133387545285290` currently has `gun:hit_head_F` on headshots and `gun:kill_F` on both standard and headshot eliminations. `WeaponController` owns the headshot cue. `KillFeed` plays the elimination cue and steps through five playback speeds per round. A headshot elimination can play both cues, so the audition includes that combination.

| Take | Layers | Length |
| --- | --- | --- |
| [Headshot A · Dry Slash](../06%20Assets/Combat%20Feedback/2026-11-20/Headshot%20A%20-%20Dry%20Slash.wav) | Fast Pro Pack swish, wood-block edge and short drum impact | 113 ms |
| [Headshot B · Heavy Slash](../06%20Assets/Combat%20Feedback/2026-11-20/Headshot%20B%20-%20Heavy%20Slash.wav) | Rod sweep and rope whip with more drum weight and a softer wood-block edge | 113 ms |
| [Kill A · Low Strike](../06%20Assets/Combat%20Feedback/2026-11-20/Kill%20A%20-%20Low%20Strike.wav) | Drum impact and a quiet wood-block click, with a subdued 584–864 Hz rise | 308 ms |
| [Kill B · Rising Ring](../06%20Assets/Combat%20Feedback/2026-11-20/Kill%20B%20-%20Rising%20Ring.wav) | The same impact family with a more forward 754–1007 Hz rise | 283 ms |

Start with Headshot A and Kill A. The alternate headshot has more weight, and the alternate kill has a more audible pitched finish. The mixes use the existing Pro Pack and Sonniss GDC 2016 library recordings. The rod and whip are from SoundBits, the drum is from Bottle Rocket FX, and the pitched release comes from George Karagioules's struck glass. [Project audio sources](Sound%20Library%20Pick.md) · [RIVALS reference](../03%20Research/Rivals%20Reference/00%20Rivals%20Reference.md)

- [Headshot comparison](../06%20Assets/Combat%20Feedback/2026-11-20/Headshot%20comparison.wav) and [kill comparison](../06%20Assets/Combat%20Feedback/2026-11-20/Kill%20comparison.wav) play the current cue, A, then B after the standard Vandal report.
- [Headshot elimination](../06%20Assets/Combat%20Feedback/2026-11-20/Headshot%20elimination.wav) plays the current pair, A/A, then B/B. The offline mix places headshot feedback at 50 ms and kill feedback at an illustrative 85 ms. Live kill timing follows server confirmation.
- [Kill A ladder](../06%20Assets/Combat%20Feedback/2026-11-20/Kill%20A%20ladder.wav) uses the five current playback speeds from 1× to 1.498×.

The four masters and four audition reels are 48 kHz, 24-bit stereo WAVs. Audio checks verified duration, encoding and true-peak headroom. Status is offline audition. Select the takes before uploading them as individual private assets and checking the stock Vandal and a quieter weapon in Match.
