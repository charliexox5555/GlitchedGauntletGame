---
name: gauntlet-ui-style
description: Design, implement or review Glitched Gauntlet HUD, menus, mobile UI, SurfaceGui boards and Figma direction using the current Roblox screens and vault specs.
---

# Gauntlet UI

Read [Style Bible](../../../vault/02%20Art/Style%20Bible.md) and the current [Lobby](../../../vault/02%20Art/UI%20Lobby%20Overhaul.md) or [Match](../../../vault/02%20Art/UI%20Match%20Overhaul.md) overhaul note. [Soft Edge](../../../vault/02%20Art/UI%20Theme%20v4%20Soft%20Edge.md) describes the earlier direction, including plates with a cut corner, fades under HUD text and rings for touch or timed controls. Current implementation uses Rubik and neutral charcoal via `src/shared/Config/Theme.luau` and `UiStyle.luau`. Check the specific screen's newer notes and template before making visual changes.

- Desktop screens typically start as Studio-owned `StarterGui` layouts plus `ReplicatedStorage.UiTemplates`. Controllers fill, route and animate them. Find the matching `tools/studio/Build*.luau` source before editing a template, so the rebuild preserves the edit.
- Preserve the screen's UI hierarchy and template names that controllers bind. Check actual desktop and phone layouts, including safe insets, minimum tap sizes, long text and reduced motion. The Lobby and Match have separate mobile paths in places.
- Figma boards are design references. Use the appropriate Figma skill when editing them and treat Studio import as a separate requested task. The old Claude skill holds the historical board key and motion/layout measurements.
