# Tempest-Strike audio

First-person foley for the Tempest-Strike Vandal (2026-11-22). Real CC0 recordings from Freesound, cut, pitched and layered by `tools/audio/design_tempest_sfx.py`; nothing synthesised. Played by `Util/TempestIdle` on its action beats (`TempestIdle.cue`), from `Config/TempestAudio` (bank `tempest:`, preloaded in the match place). They layer over the stock Vandal handling sounds. **The gunshot is still the stock Vandal's**: custom shots are the one sound left (owner 2026-11-22).

Audition: `art-source/audio/tempest/_reel.wav` (cues in the order below, 0.6 s apart). Owner's audition pending; levels are in `Config/TempestAudio` → `cues`.

## Cues
| Cue | Asset | What |
|---|---|---|
| draw | 139394779927632 | rising water swish + pipe whoosh air (every equip) |
| drawLock | 137513670055806 | bright zap on a small splash (plates lock, draw 0.4) |
| inspect | 75211447319830 | water swirl + a thread of static (inspect start) |
| inspectRoll | 79439644788203 | deeper water whoosh (barrel roll, inspect 0.465) |
| inspectCatch | 72972938811283 | wet slap + spark (catch, inspect 0.61) |
| magOut | 139060144983977 | splash + static fizz (the old mag bursts into water) |
| magForm | 124844050444554 | reversed tiny splash rising (new mag forms in the hand) |
| magSeat | 89772200759443 | hard zap + splash (seat, under the stock click) |

## Sources (CC0, checked on each sound page by `tools/audio/fetch_audio.py`)
| Freesound id | Title | Author | Licence | Page |
|---|---|---|---|---|
| 321489 | Water Swish | dslrguide | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/dslrguide/sounds/321489/) |
| 855838 | Whoosh - Plastic water pipe 80cmish - OS ST 4 | Sadiquecat | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/Sadiquecat/sounds/855838/) |
| 398032 | Splash | swordofkings128 | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/swordofkings128/sounds/398032/) |
| 321490 | Tiny Splash | dslrguide | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/dslrguide/sounds/321490/) |
| 737232 | Short Water Squish | qubodup | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/qubodup/sounds/737232/) |
| 737234 | Water Splash | qubodup | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/qubodup/sounds/737234/) |
| 478722 | Water Swirl 1_4 | Joao_Janz | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/Joao_Janz/sounds/478722/) |
| 512471 | Electric zap.wav | michael_grinnell | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/michael_grinnell/sounds/512471/) |
| 136542 | ELECTRIC_ZAP_001.wav | JoelAudio | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/JoelAudio/sounds/136542/) |
| 189630 | Spark | elliott.klein | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/elliott.klein/sounds/189630/) |
| 264779 | Civilian Stun Gun 1/10s zap | AnthonyChan0 | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/AnthonyChan0/sounds/264779/) |
| 582631 | Long Crackle 04.wav | ironcross32 | CC0 1.0 (read on the sound page) | [page](https://freesound.org/people/ironcross32/sounds/582631/) |
