# Draft Duels · Draft Ticket in Lobby Gold

The approved title combines a gold DRAFT ticket with a larger, warm-white DUELS word. Gold `#FFD23F` is the lobby accent. The ticket depth is `#CB932C`, the DUELS face is `#FFF7E9`, the outline is `#19181D`, and the optional preview backdrop is `#26242A`.

## Art files

| File | Use |
| --- | --- |
| `draft-ticket-lobby-gold.psd` | Photoshop master, 2000 × 820. **Lobby Gold** starts visible. **White base** and **Black base** are alternate groups. The color group separates the ticket face, depth, highlight, DRAFT letters, and DUELS faces, depth, and rim. |
| `draft-ticket-lobby-gold.svg` | Editable vector master with outlined lettering. Change the shape of the ticket or letters here. |
| `draft-ticket-lobby-gold.png` | Full-color, transparent 2000 × 820 logo. |
| `base-white` and `base-black` | Flat, single-color SVGs and transparent PNGs. The ticket outline and lettering share one ink. |
| `ui/` | Transparent 1000 × 410 PNGs with a shared origin. |
| `draft-ticket-reveal.gif` | Looping animation preview on charcoal. |

## Build the title reveal

Use a centered Roblox UI container with a `1000 / 410` aspect ratio. Give each `ImageLabel` the same size and resting position within that container. The padding is part of the alignment. For the standard reveal, stack `ui/draft-ticket.png` above `ui/duels.png`. To animate the lettering as a separate stamp, stack `ui/ticket-plate.png` and `ui/draft-letters.png` in place of the combined ticket.

| Time | Action |
| --- | --- |
| 0–230 ms | Bring DRAFT in from the upper left. Fade in, ease up from 95% scale, and settle the UI rotation at 0° so the ticket keeps its drawn tilt. |
| Around 210 ms | Add a short pick-confirmation sound if the title has audio. |
| 215–500 ms | Raise DUELS from about 11% of the container height below its resting point. Fade it in, give it up to 2.5% scale punch around 360 ms, and settle at 100%. |
| From 500 ms | Hold the full title. |

For scale or rotation, center the ticket pivot near `(0.50, 0.25)` of the shared canvas and DUELS near `(0.50, 0.66)`. Keep the resting art aligned after changing pivots. Use Quint Out for the entrances. For reduced motion, fade in `ui/full.png` as a single image.

Letter outlines are based on [Bricolage Grotesque](https://fonts.google.com/specimen/Bricolage+Grotesque) and [Lilita One](https://fonts.google.com/specimen/Lilita+One). The editable SVG already contains the paths.
