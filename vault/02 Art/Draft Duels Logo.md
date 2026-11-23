# Draft Duels Logo

The owner chose **Draft Duels** on November 22, 2026. The brief calls for a playful arcade title for the lobby and animated title screen, with one palette from the current UI and one new palette. Both palettes are ready for review.

## Approved title

The owner chose **Draft Ticket in Lobby Gold**. The [approved source pack](../../art-source/ui/draft-duels/draft-ticket-lobby-gold/README.md) includes the layered PSD, editable SVG, full transparent PNG, black and white bases, aligned title sprites, and the [two-beat reveal](../../art-source/ui/draft-duels/draft-ticket-lobby-gold/draft-ticket-reveal.gif). DRAFT snaps in on its ticket before DUELS rises and settles. The selected mark uses the lobby accent `#FFD23F`, with a warm-white DUELS face `#FFF7E9`.

## Round two

The owner found the first letterforms too sharp and sporty and liked the original composition and the ticket idea. The [comparison sheet](../../art-source/ui/draft-duels/round-2/logo-studies.png) shows both full marks. The original composition keeps the fanned cards and lock-in line, with rounded, nearly upright lettering. Draft Ticket puts the first word on one slightly tilted selection ticket above DUELS.

Both marks are shown in Sky Blue `#87C1FF`, Grape `#CBB3FF`, Tangerine `#FFAA76`, Lime `#DAEF91`, Bubblegum `#FFADC9`, and Lobby Gold `#FFD23F`. The larger previews compare both marks in Sky Blue.

The owner requested complete logo previews for this round. Study lettering is based on [Lilita One](https://fonts.google.com/specimen/Lilita+One) and [Bricolage Grotesque](https://fonts.google.com/specimen/Bricolage+Grotesque).

## First pass

## Lettering and references

DRAFT sits above the heavier DUELS. Both use custom letter outlines with a forward lean, clipped corners and wide counters. The fanned selection cards represent the draft. The line below DRAFT lights up when the card locks in. The logo reads **DRAFT DUELS**, with **Draft Duels** used in prose.

- **RIVALS** uses thick letter faces and hard contrast for a strong arcade read. The supplied image shows how a dark outline keeps the lettering clear against saturated color. [RIVALS](https://www.roblox.com/games/17625359962/RIVALS)
- **Murder Duels** uses a stacked name with a bigger second line. That hierarchy works here because the first line introduces the draft and the second delivers the fight. [Murder Duels](https://www.roblox.com/games/120851538706364/Murder-Duels)
- **THE FINALS** is a reference for carrying a bold wordmark and angular graphic across title cards. [Official branding kit](https://www.reachthefinals.com/content-creators)

## Palettes

| Palette | Draft and selected card | Duels | Lock-in line | Outline | Backdrop |
| --- | --- | --- | --- | --- | --- |
| Lobby Gold | `#FFD23F` | `#F5F7FA` | `#FFD23F` | `#121218` | `#151518` |
| Arcade Mint | `#6EF1BD` | `#FFF3DB` | `#FF9E77` | `#15192A` | `#181B2D` |

Lobby Gold takes its main colors from [Theme.luau](../../src/shared/Config/Theme.luau), with outline and depth colors made for the wordmark. Arcade Mint is an alternate title treatment. Rubik is the companion font for regular lobby copy. The logo lettering is drawn as paths.

## Editable art and exports

- [Palette preview](../../art-source/ui/draft-duels/palette-preview.png) and [title animation](../../art-source/ui/draft-duels/title-animation.gif)
- [Layered Photoshop master](../../art-source/ui/draft-duels/draft-duels.psd). Toggle the top-level groups to switch between Lobby Gold, Arcade Mint and Monochrome. Each theme breaks out the words, the rear and selected cards, and the selection line. The color groups separate the face, bevel, highlight, depth and outline for each word.
- Editable vector artwork in [Lobby Gold](../../art-source/ui/draft-duels/lobby-gold.svg), [Arcade Mint](../../art-source/ui/draft-duels/arcade-mint.svg), [white base](../../art-source/ui/draft-duels/base-white.svg) and [black base](../../art-source/ui/draft-duels/base-black.svg). Use the SVGs to edit letter shapes and the raster layers in the PSD to recolor or composite.
- Root PNGs are transparent 2000 × 820 composites. Each color folder has a 1000 × 410 composite and aligned transparent part sprites. Use either the combined `cards.png` or the individual card PNGs. `card-icon.png` is the crop for separate placement.
- [Export source](../../tools/build_draft_duels_logo.py) reproduces the files with Python, Pillow, skia-python and psd-tools.

## Title motion

| Time | Beat |
| --- | --- |
| 0–220 ms | DRAFT glides in from the left. The rear card rises in at 45 ms, then the chosen card slides in diagonally at 105 ms. |
| 170–365 ms | The line wipes across to signal lock-in. A short glint at about 240 ms marks the confirmation. |
| 265–505 ms | DUELS rises in from below with a brief 2.4% size punch in the preview, then settles. |
| 505 ms onward | Hold the full title. The GIF loops for review. |

Use a centered container with aspect ratio `1000 / 410` and give each part the same size and resting position. Keep the selection-line image full size inside a clipping frame and tween the frame's width for the wipe. Use the shared Quint Out motion for the title. If adding audio, put the lock-in cue at about 240 ms and the round-start cue at about 350 ms. For reduced motion, fade in `full.png`. [Current lobby motion](UI%20Lobby%20Overhaul.md)

The two palettes and motion proof are for review. In-game placement and playback still need Studio verification when the title is integrated.
