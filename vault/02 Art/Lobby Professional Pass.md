# Lobby Professional Art Pass â€” 2026-11-04

Scope: Lobby place 133387545285290 only. Preserve the circular bunker structure and existing collision. No game systems. No changes to either shooting-range area, their entrance, lighting, scripts, or hooks. No global lighting changes.

## Reference findings
The ten screenshots in `01 Design/RivalsMapConcepts` show strong portal silhouettes, distinct destination graphics, large weapon sculptures and readable pad identities. Borrow the visual hierarchy and spectacle; create original geometry and graphics. Existing lobby is clean but relies on repeated rectangular signs, blank square pads and small generic displays.

## Concepts considered
- Grounded tactical arena club (confirmed user direction: between realistic/tactical, Valorant and RIVALS): premium bunker materials, sculptural gun-game identity, bold tournament graphics. Fits existing architecture with the clearest quality gain.
- Bright arcade: stronger saturation and playful clutter. Requires a wider art-direction change.
- Cinematic bunker: preserve darkness and add only restrained detail. Less immediate energy.

## Build plan
1. Baseline captures and serialized complete Lobby backup.
2. New Blender kit: layered cut-corner portal shield, sculpted portal fins, versus crest, gauntlet trophy, equipment case, collectible key/charm display. Beveled silhouettes, shared materials, origin and dimensions recorded. Render and inspect before import.
3. Import through the proven group-owned Open Cloud/kit pipeline. Store editable kit masters in ServerStorage.LobbyKit. New decor under Art.ProfessionalPass.
4. Redesign non-range world signage: compact metadata, clear large destination/mode, structured leaderboard rows, consistent Gotham typography. Keep all panels physically attached to architecture, no AlwaysOnTop.
5. Dress existing duel bays with numbered floor graphics and sculptural motifs; keep aisle open. Add trophy on the far chamber dais and passive decorative motion through the existing ambience tags.
6. Verify spawn, portal approaches, bay/player scale, range fingerprints, collision signature and Output; serialize final art and update vault.

## Constraints and budgets
No additional remote events, matchmaking, shops, prompts, queue functions or damage. Static ornament anchored and non-colliding/querying/touching. Reuse mesh templates. No new particle stacks or global post effects. Limit new animated hero props, use existing streaming-aware client ambience. Keep SurfaceGuis at 20â€“25 pixels/stud and finite draw distances.

## Sources
- User-provided RIVALS screenshots (visual analysis).
- Roblox Creator Hub: Assemble modular environments; SurfaceGui API.
- Local LihFolk: World Composition and Set Dressing; Proportion Exaggeration and Gameplay Distance; Tween and CFrame Animation of Objects; Lore Delivery Without Walls of Text.

## Build result
Built and play-reviewed. Six Blender pieces, three entrances, four leaderboard faces, sixteen duel bays, trophy and display props. 42 unique coplanar mesh repairs applied to 193 placed instances. Range and collision fingerprints unchanged. See [art review](../05%20Production/Playtests/2026-11-04%20Lobby%20Professional%20Pass.md) for checks, images and backups. Awaiting creator visual feedback.
