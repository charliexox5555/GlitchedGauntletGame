# Lobby V4 Theme: "Gauntlet Bunker" (2026-11-16)

**Owner, 2026-11-16:** "we need to create a theme like RIVALS has … make it look good and like RIVALS … new signs that look like RIVALS … really structured, the overall look and feel RIVALS gives." This **replaces** the light-grey Sunwell look for the lobby (Style Bible §7 changed the same day). Still **study, don't copy**: our own meshes, letters, words, colours and layout ([Maps and Lobby → What makes it work](../03%20Research/Rivals%20Reference/Maps%20and%20Lobby.md)). Plan: [Lobby V4 Plan](Lobby%20V4%20Plan.md).

## What "the RIVALS feel" is (from the study)
A **dark, structured bunker** ("like a cave": no colour on the walls), built from **big chunky shell pieces with soft edges**, lit by **white bar lamps**, with **colour only in the floor lines, the signs and the gameplay objects**. Signs are **glowing words in chunky frames over each doorway, tilted at you**. Floors are broken into lanes, plates and lines. Dressing is military: crates, warning plaques, floor stencils. Screens are dark-cased TVs with bright content.

## Our version
| Part | Rule |
|---|---|
| **Structure** | Graphite walls `#4E5359`, inset panels `#5A5F66`, darker wainscot `#383C41`, near-black plinth `#26292D`, ceiling `#33363A` (one step lighter than first tried: in Studio the first values read as black). **Light grey trim** `#8A8F96` (belt ledges, bezels, sign rims) is the contrast line, like RIVALS' pale trims on dark walls. Faint painted texture (the SW_* variants, ±4%), matte. |
| **Shapes** | Big chunky modules (wall bays, piers, beams, portals), stepped, layered, everything framed. **Crisp flat cuts, not rounded bevels** (owner 2026-11-16: "too round corners like before"): bevel widths 0.03-0.08, small fixtures get small cut corners, panels get asymmetric cut corners. No round curves, no blunt ends. |
| **Structure rhythm** | Piers at every corner carry a **vertical white bar lamp** and a down-light; beams from pier heads to the ceiling centre; coffers between. Every wall bay has plinth → battered wainscot → light belt ledge → big inset panels → stepped crown. |
| **Floor** | Dark slab with plates split by shadow gaps; a lighter **lane** from the spawn to each doorway, edged with **two painted gold lines** (not glowing: the first blind panel found neon lines out-shone the signs) and white chevron stencils; one **glowing** gold ring round the spawn dais. |
| **Accent** | **Gold `#FFC83D`** is the lobby's colour (lines, sign frames, small lamps). One extra accent per wing, only at its threshold, sign and lamps: Duels gold, Locker violet `#8E6CFF`, Shop pink `#FF5C8A` (coral read as team orange), Range lime `#B4E04A` (sign only: the Range is not built). Team orange / blue only on duel pads. |
| **Signs** | RIVALS-style, our own: a **dark plate with cut corners** in a **light grey rim**, **thick glowing white block letters** (stroke ≥ 0.18 × letter height, never thin tubes), a **gold glowing frame line** inside the rim and **gold chevrons** either side; mounted on brackets over the doorway, **tilted 12-15° down at the spawn**, with a real light. No pictograms. |
| **Light** | White lamp light only (`#F4F1EA`): bar-lamp lenses on the piers, hooded down-lights, a daylight shaft from the lantern over the spawn. Few lights, pools at doors and pads. |
| **Dressing** | Our own crates and cases (charcoal with gold stencil marks and straps), warning plaques, floor stencils in our words (STAND CLEAR, DUELS →, QUEUE HERE). Placed in odd-numbered groups against walls, never in the lanes. |
| **Screens** | Dark-cased TVs (bezel, hood lamp) with SurfaceGui content: leaderboards, featured items, queue counts. |

## Still rejected (from earlier rounds, still apply)
Thin neon tube letters and pictograms · neon on structure · glitch parts · mesh holograms · blue-teal steel · steampunk (brass, wood, amber, sepia) · pads of mixed sizes · overlapping or z-fighting parts · see-through walls when zoomed out · half-hidden objects · trim stubs · copying RIVALS' meshes, signs or exact layout.
