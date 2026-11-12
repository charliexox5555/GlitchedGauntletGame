# Model Style Interview

How the owner's reference screenshots become a **design method** for modelling. The rules live in the `gauntlet-build-style` skill (§0 hard rules, §0.5 interview). This note holds the question bank, the answers and the resulting methods.

## Owner's brief (2026-11-12)
> Designs should look like models built with many different faces of non-curved shapes, to balance the look of a realistic model but avoid the pixelated or cubic shape of models.

Hard rules from the owner:
1. Never use round curves in Blender and never spheres. Use angled plates or shapes to replicate curves to a certain degree.
2. Avoid harsh corners and blunt cutoffs unless told otherwise. Use angled or carved shapes instead, while keeping the blocky feel.
3. Take inspiration from the owner's reference screenshots (first set: 6). Interview the owner thoroughly to understand why they like them and what they're for, then write a design method for that style.

## Status
- **Waiting on the owner:** the 6 reference screenshots. Drop them into `vault/02 Art/References/models/` (git-ignored if they're third-party; check `.gitignore`), or paste them into the chat. Then the interview below runs.

## Question bank (ask in rounds of 3-4, always with suggested options, best guess first)
**Round 1: what and why**
1. What will this style be used for first? *Weapons and skins (Recommended, the guns are the most-seen models) · Map kit (walls, cover, props) · Lobby fixtures · Characters and ability props*
2. In the screenshots, what grabs you most? *The faceted silhouette · How the edges are carved · The proportions (chunky parts) · The colour and material blocking* (multi-select)
3. How close will players see it? *First-person in hand (very close) · Mid-range cover and props · Far background · All of these*
4. Which screenshot is closest to "exactly this"? *Pick one of 1-6 · None alone; a mix*

**Round 2: shape**
5. Facet density on a "round" form (a barrel, a pipe, a dome)? *6-8 big facets, very stylised (Recommended) · 10-12 facets, closer to real · 4-5, almost geometric*
6. Corner treatment? *One clear chamfer (Recommended) · Two-step chamfer (carved look) · Mixed: big parts two-step, small parts one*
7. Proportions? *Chunky, slightly exaggerated (RIVALS-like) (Recommended) · Realistic proportions with stylised surfaces · Slim and sharp*
8. Ends of bars, barrels, rails? *Tapered or angled cut (Recommended) · Notched or stepped · A cap piece (collar, flange)*

**Round 3: surface and detail**
9. Surface detail? *Big panels with few cut lines (Recommended) · Medium: panel lines + a few bolts/vents · Busy greebles*
10. Materials? *Flat colour blocks with faint value variation (Recommended) · Light textures (wear on edges) · Painted gradients*
11. Colour approach? *Neutral base + one accent per model (Recommended) · Two-tone · Bold multi-colour*
12. Outlines or edge highlights? *Faint outline (as on guns now) · None · Painted edge highlights on chamfers*

**Round 4: limits**
13. Anything in the screenshots you *don't* want? *Free text, with my guesses listed per image*
14. Triangle budget feel? *Low (hard facets carry it) (Recommended) · Medium · Whatever looks best*
15. The one-line brief, in your words: confirm or edit the brief above.

## Answers
*(Filled in during the interview.)*

## Design methods
*(One section per style once the interview is done: facet counts, chamfer sizes, typical shapes, build order, do / don't, the reference that shows each rule, the Blender helpers to use.)*
