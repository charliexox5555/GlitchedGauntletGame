# AI 3D Prompts: Style B "Stylized Neon" Guns

Copy-paste prompts for testing AI 3D tools (Meshy, Tripo, Rodin/Hyper3D, Hunyuan3D, Roblox's mesh generator…) on our gun style, plus references to give them.

---

## 1. Workflow that gets the best results

AI 3D tools do much better from a **clean picture** than from text alone. Their docs say: a plain/white background, a tight crop, and a straight-on view rather than a perspective angle ([Meshy docs](https://docs.meshy.ai/en/webapp/image-to-3d), [Tripo guide](https://www.tripo3d.ai/blog/image-to-3d-printable-stl), [Scenario guide](https://help.scenario.com/en/articles/meshy-the-essentials/)). So:

1. **Concept image first.** Paste the *Concept image prompt* (section 3) into an image generator (ChatGPT images, Midjourney, Ideogram, Meshy's own image tool…). Attach `docs/art/style-test/b_stylized.png` as a style reference. Generate until you get a clean **side view on white**.
2. **Image → 3D.** Upload that side view to the 3D tool's **image-to-3D**. If it supports multi-view, also generate a top view and a 3/4 view with the same prompt.
3. **Or text → 3D** if you just want a quick look: use the *Short text-to-3D prompt* (section 4).
4. **Clean up in Blender:** delete floating bits, cut the triangle count to the budget (section 7), split the neon into its own material, set the size, and export FBX.
5. **Import into Roblox** with the 3D Importer and add the attachments (Muzzle, grips, AimPoint, Eject) per `GAME_PLAN.md` section 6.

**Licence check before shipping anything:** Meshy's free-tier outputs are public under CC BY 4.0, and Tripo's free tier is non-commercial ([Krea comparison](https://www.krea.ai/blog/best-ai-3d-model-generators-2026), [Cinevva guide](https://app.cinevva.com/guides/ai-3d-model-generators)). Use a paid plan for anything that goes into the real game.

---

## 2. The style in one paragraph (paste this before any gun prompt)

> **Style: "Stylized Neon" hard-surface game weapon.** Chunky, exaggerated proportions with big, clean, readable shape blocks, like a premium stylized hero shooter (think Overwatch-level readability and polish), not realistic and not blocky Lego. Soft rounded bevels on every edge. Few, purposeful details: no greebles, no tiny screws, no scratches or grime. Materials: deep midnight-navy painted metal body (#1C2030), cool slate-grey polymer panels (#56607C), dark gunmetal for the barrel and inner parts (#14161D), small warm-yellow accent details (#FFC83D). **Glowing cyan neon light strips (#00E5FF) set into recessed channels** along the body, magazine and barrel, plus one glowing magenta lens or detail (#FF3DCB). Subtle lighter edge highlights on convex edges, smooth satin finish, clean hand-painted gradients. A futuristic "digital simulation" theme with hints of circuit-trace patterns in the neon lines. Toy-like readability with a premium finish.

**Negative prompt** (if the tool has one):
> realistic, photoreal, worn, dirty, rust, scratches, grime, camouflage, wood, brand logos, text, blood, gore, tiny details, greebles, extra barrels, floating parts, melted geometry, asymmetric mess, lego, voxel, minecraft, low quality, blurry

---

## 3. Concept image prompt (for an image generator)

Fill in the `[GUN]` part from section 5.

> Professional game weapon concept art, orthographic **side view** (barrel pointing right), the full weapon centered and large in frame, **plain pure white background**, soft even studio lighting, no shadows on the background, no text, no hands.
>
> [STYLE PARAGRAPH FROM SECTION 2]
>
> The weapon: [GUN DESCRIPTION FROM SECTION 5]
>
> Strong, instantly readable silhouette. Clean and polished like a AAA stylized shooter's weapon turnaround sheet. High detail in the shapes, low noise in the surfaces.

**Multi-view version:** add *"character-sheet turnaround with 3 views on white: side view, top view, and front 3/4 view, same scale, same weapon"*.

---

## 4. Short text-to-3D prompt (for tools with a character limit)

> Stylized sci-fi game [GUN TYPE], chunky exaggerated proportions, soft bevels, clean large shapes, midnight-navy painted metal and slate-grey panels, glowing cyan neon strips in recessed channels, magenta glowing sight lens, premium hero-shooter style, low-poly game asset, clean topology, no small details, no wear.

Settings if offered:
- **Art style:** "Stylized" or "Cartoon", not "Realistic"
- **Target polycount:** "Low" or about 3–5K triangles
- **Topology:** quad
- **PBR textures:** on

---

## 5. Gun descriptions (wave 1)

Each gun must have a **different silhouette** so players can tell them apart on a phone. The size is the in-game length in Roblox studs.

| Gun | `[GUN DESCRIPTION]` to paste |
|---|---|
| **Byte** (default pistol, 1.4 studs) | compact angular sci-fi handgun, thick rectangular slide with a cyan neon line along each side, short squared barrel shroud, chunky grip with a magenta glowing base on the magazine, small notch rear sight, friendly and simple |
| **Root** (heavy revolver, 1.9 studs) | oversized futuristic revolver with a big hexagonal cylinder ringed in cyan neon, long heavy top-ribbed barrel, hammer shaped like a cooling fin, wide curved grip, feels heavy and powerful |
| **Bandwidth** (SMG, 2.3 studs) | short boxy compact SMG, stubby suppressor-like barrel shroud, vertical foregrip, long straight magazine in front of the trigger with neon segments like a signal bar, folded stub stock, fast and agile look |
| **Hard Reset** (pump shotgun, 3.2 studs) | thick chunky pump-action shotgun, wide flat-topped barrel with a large square muzzle, oversized sliding pump grip with cyan neon grooves, heavy rounded stock, shells displayed as glowing magenta cells on the side |
| **Long Poll** (light sniper, 4.2 studs) | long slim bolt-action sniper, thin extended barrel with a slotted muzzle brake, large rectangular digital scope with a glowing magenta lens, chunky bolt handle, skeleton stock with a neon strip, elegant and precise |
| **Bitrate** (assault rifle, 3.8 studs) | balanced modern assault rifle, angular receiver with a long cyan neon channel, ventilated rectangular handguard with three glowing slots, short barrel with a neon ring at the muzzle, small holographic sight with a magenta lens, slightly angled magazine, solid squared stock |
| **Flood** (heavy machine gun, 4.6 studs) | bulky heavy machine gun with a rotating triple-barrel cluster wrapped in a neon cooling coil, large boxy ammo drum on the side glowing cyan, top carry handle, front stabilizer grip, massive and intimidating |
| **Ray Trace** (railgun wildcard, 4.4 studs) | exotic futuristic railgun with two parallel rails instead of a barrel, a glowing cyan energy core visible between the rails, magenta capacitor cells along the body, open-frame stock, unlike any real gun |
| **Cutter** (melee, 1.6 studs) | short energy blade knife, chunky dark handle with a finger guard, blade made of a glowing cyan hard-light edge on a dark metal spine, angular and sleek |

---

## 6. Ready-to-paste example (Bitrate, the gun from our style test)

> Professional game weapon concept art, orthographic side view (barrel pointing right), the full weapon centered and large in frame, plain pure white background, soft even studio lighting, no shadows on the background, no text, no hands.
>
> Style: "Stylized Neon" hard-surface game weapon. Chunky, exaggerated proportions with big, clean, readable shape blocks, like a premium stylized hero shooter (Overwatch-level readability and polish), not realistic and not blocky Lego. Soft rounded bevels on every edge. Few, purposeful details: no greebles, no tiny screws, no scratches or grime. Materials: deep midnight-navy painted metal body (#1C2030), cool slate-grey polymer panels (#56607C), dark gunmetal barrel and inner parts (#14161D), small warm-yellow accent details (#FFC83D). Glowing cyan neon light strips (#00E5FF) set into recessed channels along the body, magazine and barrel, plus one glowing magenta lens (#FF3DCB). Subtle lighter edge highlights, smooth satin finish, clean hand-painted gradients. A futuristic "digital simulation" theme with hints of circuit-trace patterns in the neon lines.
>
> The weapon: balanced modern assault rifle, angular receiver with a long cyan neon channel, ventilated rectangular handguard with three glowing slots, short barrel with a neon ring at the muzzle, small holographic sight with a magenta lens, slightly angled magazine, solid squared stock.
>
> Strong, instantly readable silhouette. Clean and polished like a AAA stylized shooter's weapon turnaround sheet.

---

## 7. How to judge what it makes

| Check | Pass |
|---|---|
| Silhouette | Shrink it to the size of your thumbnail. Can you still tell what gun it is? |
| Style | Matches the palette, with chunky bevels and no grime |
| Neon | The neon sits in its own channels, so it can become a separate glowing material in Roblox |
| Geometry | No melted shapes, no floating bits, both sides make sense |
| Triangles | Under ~5K for primaries, ~3K for sidearms; cut down in Blender if higher. Roblox caps a single mesh at roughly 20K ([Nilo](https://nilo.io/articles/vibe-code-roblox-triangle-limit)) |
| Licence | Paid plan or a licence that allows commercial use |

Keep the best results in `docs/art/ai-tests/<tool>/<gun>.png` so you can compare tools side by side.

---

## 8. References to give the tools (and to look at yourself)

Use these for **shape language, proportion and finish**. Don't copy any single design.

### Style direction
| Reference | What to take from it |
|---|---|
| [80.lv: Studying Overwatch Style](https://80.lv/articles/studying-overwatch-style) | The core of style B: exaggerated forms, guns readable from their silhouette alone, big shapes instead of small details, lighter convex edges |
| [80.lv: Stylized gun painting, design and rendering](https://80.lv/articles/stylized-gun-painting-design-rendering) | How a pro stylized gun is shaped, textured and presented |
| [Polycount: Overwatch-style weapon critique](https://polycount.com/discussion/comment/2526021/) | Common mistake: too many small details for this style |
| [The Rookies: Sci-Fi Laser Gun (TayaB)](https://www.therookies.co/entries/22262) | Toon sci-fi gun with very low poly per part, close to our budget |
| [The Rookies: Justin Akiyama, assorted 3D works](https://www.therookies.co/entries/2726) | An original stylized sci-fi weapon |

### Low-poly neon examples
| Reference | What to take from it |
|---|---|
| [Sketchfab: Neon Gun](https://sketchfab.com/3d-models/neon-gun-fcbc292fa97845d6b9074f5949df9cea) | Neon lines on dark low-poly shapes, the closest match to our palette |
| [Sketchfab: Sci-Fi Pulse Rifle "Myon Caster"](https://sketchfab.com/3d-models/sci-fi-pulse-rifle-myon-caster-6b048e7a0c0c46fc90f66f9055d38cd8) | A clean sci-fi rifle at a game-ready ~5K tris (marked NoAI: look only, don't upload it to AI tools) |
| [Sketchfab: Sci-Fi Pistol (low poly)](https://sketchfab.com/3d-models/sci-fi-pistol-lowpoly-6a50440f82c449d894eccac6d70a74b9) | Sidearm proportions |
| [Sketchfab: Sci-Fi Sniper Rifle](https://sketchfab.com/3d-models/sc-fi-sniper-rifle-0c471d447d984b16bea37f6105f5d000) | Long-gun proportions for Long Poll |
| [Sketchfab: Drum Magazine Rifle](https://sketchfab.com/3d-models/drum-magazine-rifle-bc0e49cae895485988bf21d4a69c097d) | Drum-mag shapes for Crash and Flood |
| [CGTrader: Stylized Guns Pack (34 guns)](https://www.cgtrader.com/3d-models/military/gun/stylized-guns-pack-34-unique-game-ready-weapons-models) | Colourful stylized guns at 800–2,500 tris each, a good poly budget benchmark |

### Games to study (screenshots / gameplay)
| Game | Why |
|---|---|
| **RIVALS** (Roblox): [weapons guide](https://progameguides.com/roblox/all-weapons-and-how-to-get-them-in-roblox-rivals/), [Sportskeeda weapons list](https://www.sportskeeda.com/roblox-news/roblox-rivals-weapons-guide) | The bar on Roblox: chunky, clean, readable guns that work on phones |
| **Overwatch 2** | The best example of a professional stylized weapon finish |
| **Hypershot** (Roblox) | Stylized arena-shooter guns on Roblox |
| **Nerf blasters** (product photos) | Chunky toy-like shapes with bold colour blocks, the "readability" part of style B |
| **Tron: Legacy** (stills) | Neon lines on dark surfaces, the "digital simulation" part of style B |

**Avoid as references:** Valorant's "Glitchpop" skin line ([Upcomer](https://upcomer.com/riot-reveals-glitchpop-skin-line-in-valorant)). It's a neon digital weapon style, close to ours, so don't use it as an input. With a Valorant-inspired mode, copying it would make the game look like a clone.

### Our own reference
Attach **`docs/art/style-test/b_stylized.png`** to every request as "this layout and palette, but more polished and professional".
