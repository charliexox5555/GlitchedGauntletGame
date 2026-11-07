# Codex concept brief (2026-11-05)

Paste the block below into the Codex app chat that has the GlitchedGauntletGame folder open. It makes the concept images for the maps and the UI, using the prompts the Claude sessions already wrote. When Codex is done, tell the Claude core chat. The map and UI sessions then put the images into review boards for you to pick from.

```text
You're making concept images for my Roblox shooter. Read the prompts from the vault and save the images into the repo. Don't edit any other file, and don't run git (no add, commit or push).

1. MAPS (do Rooftops first, then Dockyard)
   - Prompts: vault/01 Design/Maps/Rooftops2.md, section "Concept pass 2026-11-05", subsection "Prompts". Same for vault/01 Design/Maps/Dockyard2.md. Use the shared style block and palette exactly as written.
   - References to look at or attach:
     - Our current map: vault/02 Art/References/maps/rooftops2/r8-overview.jpg, and the files in vault/02 Art/References/maps/dockyard2/whats-wrong/.
     - Mood only: vault/02 Art/References/maps/rooftops/third-party/ and vault/02 Art/References/maps/dockyard/third-party/.
   - Order: the silhouette round, then the overview, then the hero views (each using the overview as its reference), then the kit sheet, then the material and trim sheet.
   - Save to art-source/maps/Rooftops2/concepts/ and art-source/maps/Dockyard2/concepts/, named like 01-overview.png, 02-hero-pit.png, matching the prompt numbers. If an image needs a second try, save the better one as -v2.

2. UI (after the maps)
   - Prompts: vault/01 Design/Lobby UI and Queue.md, section "10. UI concept pass", plus the Figma renders in assets/UI/concepts/figma-v3-clipped-*.png as the layout reference.
   - Make the "three directions" options image first, then lobby and match HUD screens in the direction it recommends.
   - Save to assets/UI/concepts/chatgpt/.

RULES
- Every design is original. The third-party images are for mood and quality level only. Never copy a real game's map layout, landmark, UI, logo or text.
- No readable text, logos or watermarks in the map images.
- At the end, list every file you saved, one line each with what it shows.
```

## After Codex
- The core chat checks the files, then:
  - sends the map images to the `map-redesign` session (concept boards in the map notes),
  - sends the UI images to the `lobby-ui-2` session (§10 in Lobby UI and Queue).
- The generated images get committed. The third-party folders never do.
