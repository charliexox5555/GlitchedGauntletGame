# PopCircuit

**One line:** An anime-pop finish with bright blue, pink and purple metallic colour blocks and original vinyl stickers.  
**Mood words:** playful, bright, bouncy, electric, glossy  
**Status:** idea

## Guns in the line

Guardian is the proposed hero gun. Its long left-side shell gives the colour blocks and main sticker a clear face. The melee slot has a separate baseball-bat concept.

| Gun | In the line | Hero | Approved sheet |
|---|---|---|---|
| Vandal | yes | no | |
| Phantom | yes | no | |
| Bulldog | yes | no | |
| Guardian | yes | yes | |
| Spectre | yes | no | |
| Stinger | yes | no | |
| Ares | yes | no | |
| Odin | yes | no | |
| Sheriff | yes | no | |
| Classic | yes | no | |
| Ghost | yes | no | |
| Shorty | yes | no | |
| Bucky | yes | no | |
| Judge | yes | no | |
| Marshal | yes | no | |
| Outlaw | yes | no | |
| Operator | yes | no | |
| Knife (PopCircuit Bat replacement) | yes | no | |

## Colour per role

The hex values and finishes are proposed starting points.

| Role | Stock | This line | Finish |
|---|---|---|---|
| Body | `#383D48` | `#539BFF` (satin electric-blue coated metal) | metal |
| Panel | `#555C69` | `#FF9DD8` (pearl pink with select violet blocks) | metal |
| Dark | `#1C1E23` | `#231B45` (deep indigo polymer) | matte |
| Grip | `#25272D` | `#29203C` (dark plum rubber with the stock grip texture) | textured |
| Metal | `#62676F` | `#6554C9` (satin violet anodised metal) | metal |
| Accent | `#AEB4BC` | `#FF6ECA` (polished candy pink) | metal |
| Neon | `#2A6BFF` | `#61F2FF` (cyan on existing small strips and dots) | gloss |
| Brass | `#A8844E` | `#A8844E` (stock brass) | metal |
| Glass | `#16202C` | `#16202C` (stock scope glass) | gloss |

## Pattern and details

- **Pattern or motif:** Carry broad blue, pink and violet colour blocks along the full length of the gun, with glossy vinyl clusters on the widest Body and Panel faces. Use bubble rings, sparkles, halftone dots and comic speed marks for the anime-pop feel. Keep grips and other Dark parts in deep plum or indigo. Confine actual glow to small cyan strips and dots.
- **Signature detail (proposed):** A pink bubble bursting into three cyan sparkles, backed by a violet speed ring and finished with a pale die-cut border, sits on the player-facing left side.
- **Decal and colour alignment:** Use flat or gently curved faces for the main decals and keep their proportions consistent in every view. Align colour breaks across fixed seams and end stickers cleanly before moving or removable parts. Give the main sticker breathing room and use smaller decals to support it.
- **Shape:** For the guns, preserve stock silhouettes, proportions and part positions. Keep the stylised low-poly look and clean colour boundaries.
- **Add-on pieces:** None for the guns.
- **Matching charm:** None.

## Melee replacement

The Knife slot gets an original stylised baseball bat with a rounded capped barrel, a tapered neck and a dark wrapped handle. Use the line's blue, pink and purple metallic finish, the bubble-burst sticker on the camera-facing barrel and a small cyan accent at the cap. Keep the grip clear of decals.

### First-person grip

The current melee viewmodel is right-hand-led and positions the model from its grip. Propose a bat-specific primary grip pivot on the wrap near the knob, with a separate support-hand target on the same wrap toward the barrel. In first-person idle and light slashes the right hand stays anchored and the left rests low in frame. For the heavy pose, blend the left hand onto the support target before the downward animation, keep both hands attached through the motion, then return it to idle. Check wrist angles, hand spacing, clipping and centre-screen visibility with the actual rig.

The bat reference shows the prop without hands. The grip placement above is proposed for our viewmodel and needs an in-engine pose check.

### Animations and trail

| Beat | Direction |
|---|---|
| Primary (left click) | Simple one-handed leftward and rightward slash clips, alternating on successive light inputs. Return to the same idle pose after each clip. |
| Heavy (right click) | Two-handed overhead-to-downward smash animation. The support hand joins before the downswing and releases during recovery. |
| Inspect | A normal one-handed raise and turn to show the barrel and stickers, then settle back to idle. |
| Light slash trail | A short blue, pink and violet ribbon follows the bat barrel during each light slash and fades by recovery. |

## Do not

- Avoid anime characters or faces, warped or stretched stickers, drifting colour boundaries, mismatched seams, repetitive sticker clutter, tiny text, brand logos and copied graphics.
- Keep the guns in the simple reskin pass. The bat has its own model, animations and light-slash trail.

## References

| File | Take from it | Ignore |
|---|---|---|
| `refs/style/01_pastel-metal-rifle.png` | Long blocks of pink, blue and violet with open space around a focal graphic. | The character, lettering, exact sticker placement and promotional background. |
| `refs/style/02_neon-baseball-bat.png` | The clear separation between a decorated barrel and dark wrapped handle, plus the small luminous accents. | The exact cap and collar shapes, lettering, sticker artwork and full-length glow. The image shows the bat by itself. |
| `refs/style/03_full-coverage-rifle.png` | How larger and smaller colour blocks carry the palette from front to rear. | The character, brand graphics, exact artwork and pattern placement on the magazine and grip. |
| `refs/texture/04_vinyl-on-metal-closeup.png` | The contrast between glossy die-cut vinyl, clean sticker edges and tinted metal on compact faces. | The portrait, lettering, barcodes and exact graphic shapes. |

## Parked ideas

- Custom gun reloads, gun inspects and gun effects remain ideas for future lines.

## Log

- 2026-11-12 — folder set up.
