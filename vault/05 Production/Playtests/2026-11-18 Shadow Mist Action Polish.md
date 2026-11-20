# Shadow Mist action polish

2026-11-18, local Match Studio Solo, first-person Shadow Mist v05. The owner asked for more spectacle on the short action beats, continuous shard motion while firing, and a reload where the replacement forms visibly out in the support hand before it is thrown into the magwell. The idle remains a thin haze between moves.

## Video reference

Both supplied MP4s were examined locally with FFmpeg frame sheets at one-second intervals, then subsecond sampling around draw, reload and inspect beats. In the longer tier-four clip the energy gathers at 8.20–9.10 s, the open assembly holds through 14.50 s, and it comes back together around 15.20–15.80 s. Its later reload at 45.38–46.32 s makes the action visible with a deliberate exposed hold. Ruination's draw gathers energy across the back of the gun around 0.24–0.80 s. Its reload lifts the magwell into view at 5.50 s, releases at 5.75 s and shows the new magazine by 6.50 s.

The RIVALS asset pack was inspected read-only in Match. The muzzle examples separate the bright, dark and soft layers. Deflect uses an instant glint with slower fragments for readable follow-through. Shadow Mist uses original Gauntlet textures and its seafoam palette, with a tighter body orbit and an off-hand cast.
[RIVALS VFX notes](../../03%20Research/Rivals%20Reference/Body%2C%20Viewmodel%2C%20Guns%20and%20VFX.md) · [Video analysis workflow](../../04%20Tech/Video%20Analyzer.md)

## Studio checks

- Draw stages the stock, receiver and fore-end with two-layer arcs and a lock flash. The body pieces appear in separate groups while converging.
- A normal-speed burst kept all 33 body shards moving and raised receiver light from 1.81 to 4.15. The near-black and teal layers stayed attached for 50 ms. The tapered dart carried an active teal wake. The concrete range wall took a charcoal scorch and rising mist with a 1.5 s cutoff. The decal remained visible after the mist cleared.
- The forming magazine sampled 241 px to the left of the receiver seat in the 1920 px capture. The wrist follows through independently while the mag arcs inward. Verified the approach, seated pose and brief light at 1× speed. The true empty reload used the action bone and also returned the magazine.
- The 5.4 s inspect was still open at 3.03 s with six lit arc edges and 0.30 studs of spread. ADS cleared the arcs and smoke at 68 FOV. The range is running at normal speed.

StyLua, Selene and both Rojo builds passed. These checks cover the first-person Studio preview.

[Draw](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/premium/draw.jpg) · [Magazine forming in the support hand](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/premium/reload_hand.jpg) · [Extended inspect](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/premium/inspect.jpg) · [Studio measurements](../../../art-source/weapons/Skins/RuinBlighted/Vandal/v05/review/premium/studio_samples.json)

## Shot audio preview

The owner's 93 ms mix (`81557034287985`) plays at its original pitch for every first-person Shadow Mist Vandal shot in Match Studio. The regular shot bank is the fallback if the clip cannot load. Studio Solo played the clip on a single shot and on all 25 rounds of a spray. Switching to Moltframe used the regular shot bank. The session was left running with Shadow Mist equipped.

The owner then switched the preview to `128154707565378` (111 ms). Studio Solo played the replacement on a single shot and the remaining 24 rounds in a spray. The session is running with Shadow Mist equipped.

The final single-clip audition was `94301133893352` (507 ms), with the full taper. Studio Solo observed a tap play through 507 ms and all 25 rounds of a spray start the clip, with up to five simultaneous voices.

## Owner audio batch

All 30 owner WAVs uploaded under group `11116787` and loaded in the Match client. At normal speed in Studio Solo, the first tap used the dedicated opener. The remaining 24 rounds played another opener, 22 follow-ups covering all eight takes, and the empty-mag report with its own tail. The preload check covered every take. The action check exercised sampled takes from each handling group.

Draw played the gathering air and the shard lock. Tactical and empty reloads played the release, cast, grab and throw, seat and chamber action. The seat recording and lock accent fired on the same frame in both reloads. Inspect played the entry and opening sounds. ADS interrupted the opening sound cleanly. Moltframe still used the regular reports. The session was left running with Shadow Mist equipped.

StyLua, Selene and both Rojo builds passed. [Cue sheet](../../02%20Art/Skins/RuinBlighted/Sound%20Cue%20Sheet.md) · [Asset IDs](../../../src/shared/Config/ShadowMistAudio.luau)

## Inspect finish

The armor accelerates inward at the end of inspect and reseats before the rifle returns to its hold. The receiver flashes and plays a softer copy of the existing shard lock. Match Studio Solo observed all 33 body shards return to within 0.001 studs of their rest offsets on the one impact frame, from 0.30 studs at the open hold. ADS during the inward motion returned the shards to idle without firing the impact. The owner approved the sound.
