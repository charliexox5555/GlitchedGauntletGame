# Mod icons

The 9 Mod HUD icons, one white glyph per Mod on a transparent 256×256 PNG, so the HUD can tint and frame them (3 slots bottom-centre with a radial cooldown sweep).

- **Source:** `tools/icons/make_mod_icons.py` (hand-authored SVG geometry). Edit a glyph function there and re-run; never edit the `.svg` or `.png` by hand.
- **Rebuild:** `python tools/icons/make_mod_icons.py` writes `<ModId>.svg`, `<ModId>.png` and `contact_sheet.png` here. It renders with headless Chrome or Edge (no extra installs) and prints each glyph's bounds against the 24 px safe margin.
- **Style rules:** flat white, sharp mitred corners, no text; strokes and gaps at least 14 px on the 256 canvas (about 2.6 px at 48 px); glyphs inside the 24 px margin. Check `contact_sheet.png` at 48 px before shipping a change.
- **Ids:** `Blink`, `LaunchPad`, `Packet`, `Firewall`, `LagField`, `Ping`, `PatchUp`, `Overclock`, `Rollback` (match `Config/Mods` ids).

## Upload (only after the user approves the icons)
Open Cloud has a monthly upload limit, so upload once per approved set.

1. Upload each PNG as a Decal (needs `ROBLOX_ASSETS_KEY`; results also go to `art-source/uploads.json`):
   ```
   python tools/opencloud/upload_asset.py --group 11116787 --type Decal art-source/abilities/Icons/Blink.png "GG Mod Icon Blink"
   ```
   It prints a **Decal** id.
2. The HUD needs the **Image** id behind each Decal (same rule as VFX textures, see Art Direction → VFX). In Studio (command bar or MCP `execute_luau`):
   ```lua
   local decal = game:GetService("InsertService"):LoadAsset(DECAL_ID):FindFirstChildWhichIsA("Decal", true)
   print(decal.Texture) -- rbxassetid://<image id>
   ```
3. Write the image ids to `ids.json` here, e.g. `{ "Blink": "rbxassetid://123", … }`. The code session copies them into each Mod's `icon` field in `src/shared/Config/Mods.luau`.
