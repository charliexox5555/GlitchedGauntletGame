# Setup Guide: your computer, Rojo, Obsidian and Claude

**The big idea:** one folder, the GitHub repo, holds everything: code (`src/`), models (`assets/`, `art-source/`) and all your notes (`vault/`).
- **Obsidian** opens `vault/` (just the notes).
- **Claude** opens the **repo root**, so it sees code *and* notes, and reads `CLAUDE.md` automatically.
- **Rojo** syncs `src/` and `assets/` into Roblox Studio.
- **Git** saves and backs up all of it.

```
GameDev/
└── GlitchedGauntletGame/   ← Claude works here (repo root)
    ├── CLAUDE.md
    ├── src/  assets/  art-source/  tools/
    └── vault/              ← Obsidian opens this
```

---

## Part A: Install (once, ~30 min)

| # | Install | Notes |
|---|---|---|
| 1 | **Git** (git-scm.com) | Default options are fine |
| 2 | **Roblox Studio** | Sign in |
| 3 | **Obsidian** (obsidian.md) | Free |
| 4 | **VS Code** (optional but handy) | Extensions: *Luau Language Server* (JohnnyMorganz), *StyLua*, *Selene* |
| 5 | **Claude Code** | Use the Claude desktop app's Code tab or the CLI (install steps at code.claude.com/docs). Claude Code is needed because it can run terminal commands (git, rojo) |
| 6 | **Rokit** (github.com/rojo-rbx/rokit) | Installs Rojo, Wally, Selene and StyLua at the versions pinned in the repo. Follow its README; on Windows it's the PowerShell one-liner or running the downloaded `rokit.exe self-install` |
| 7 | **Blender** | You already have it for the guns |

Restart your terminal after installing Rokit.

---

## Part B: Get the project

Open a terminal (PowerShell on Windows) and run:

```bash
mkdir GameDev
cd GameDev
git clone https://github.com/charliexox5555/GlitchedGauntletGame.git
cd GlitchedGauntletGame
rokit install              # installs rojo, wally, selene, stylua
rojo plugin install        # installs the Rojo plugin into Roblox Studio
```

> The repo currently has one branch (`claude/dazzling-carson-5yp2jd`), so the clone checks it out automatically. Prompt 1 below has Claude set up a proper `main` branch.

Check it worked:
```bash
rojo --version     # Rojo 7.7.1
stylua --version
selene --version
```

---

## Part C: Connect Roblox Studio with Rojo

1. Open **Roblox Studio** → **New** → **Baseplate**.
2. **File → Publish to Roblox As…** → a new experience (name it anything for now). Then **File → Save** a local copy *outside* the repo, or anywhere (`.rbxl` files are git-ignored).
3. In the terminal (inside the repo): `rojo serve`
4. In Studio: **Plugins tab → Rojo → Connect**.
5. Check: **ReplicatedStorage → Shared** and **Assets** appear, and **ServerScriptService → Server** appears.
6. Press **Play**. The Output window should show `[GlitchedGauntletGame] server started` and `client started`. ✅

Every work session: open Studio → `rojo serve` → Connect.

---

## Part D: Set up Obsidian

1. Open Obsidian → **Open folder as vault** → pick `GameDev/GlitchedGauntletGame/vault`.
2. Open **00 Home**. That's your dashboard.
3. **Settings → Core plugins:** turn on **Templates** and **Daily notes**. Their folders are already configured: templates in `Templates/`, daily notes in `05 Production/Daily Log` using the Daily Log template.
4. Optional community plugins (Settings → Community plugins → Browse):
   - **Excalidraw**: sketch map layouts right in the vault (great for the arena sketch step).
   - **Dataview**: fancy tables later; not needed now.
   - Skip auto-commit git plugins. Claude handles git, and two things committing at once causes conflicts.
5. Tip: pin **00 Home** and the **Asset Tracker** in the sidebar.

---

## Part E: Connect Claude

1. Open Claude Code **in the repo root** (`GameDev/GlitchedGauntletGame`), not in `vault/`. In the desktop app, choose that folder; in a terminal, `cd` there and run `claude`.
2. It reads `CLAUDE.md` automatically, which tells it where everything is and how to keep the vault updated.
3. **Roblox Studio MCP** (lets Claude build and inspect inside Studio): use **Prompt 2** below. Claude finds Roblox's current official setup steps and walks you through them.
4. Optional: **Blender MCP** if you want Claude to tweak guns live in Blender.

---

## Part F: Prompts (copy-paste in order)

### Prompt 1: Check the setup and organise git
```
Read CLAUDE.md and vault/00 Home.md. Then:
1. Run rojo --version, stylua --check src, selene src and rojo build -o build.rbxl, and tell me if anything fails (selene may need to download the Roblox standard library on first run).
2. Set up git properly: create a `main` branch from the current branch, push it, and tell me how to make `main` the default branch on GitHub. From now on, work on `main` unless I say otherwise.
3. Add a .gitattributes so line endings stay LF (StyLua expects Unix line endings) if it isn't there already.
4. Give me a short summary of the project structure so I know you understand it.
```

### Prompt 2: Connect Claude to Roblox Studio (MCP)
```
I want you to work directly inside Roblox Studio. Find Roblox's official Studio MCP server documentation (Roblox updated it in Feb 2026) and walk me through connecting it to Claude Code on my computer step by step. Wait for me at each step. When it's connected, prove it works: list the children of ReplicatedStorage in my open Studio place (Rojo should be connected, so Shared and Assets should be there).
```

### Prompt 3: Studio settings for our game
```
Using the Studio MCP, set up my place for our game per vault/04 Tech/Architecture.md and vault/01 Design/Gunplay.md:
- Turn on Server Authority and its required settings, and StreamingEnabled (check Roblox's current docs for the exact properties).
- Create ServerStorage.ImportStaging (a folder for importing models; Rojo doesn't manage it).
- Set the player to first person with FOV 80.
Tell me anything you can't set through the MCP so I can click it myself, then update the Status in vault/00 Home.md.
```

### Prompt 4: Import the guns
```
I'm importing my gun models. Read vault/02 Art/Art Direction.md (model standard + import pipeline) and vault/06 Assets/Asset Tracker.md.
1. Tell me where to put my .blend/.fbx files (art-source/weapons/<Gun>/) and commit them.
2. I'll import each FBX into ServerStorage.ImportStaging with File → Import 3D. Start with Bitrate.
3. For each imported gun, use the Studio MCP to bring it up to the model standard: Handle as PrimaryPart at the grip, attachments (Muzzle, RightGrip, LeftGrip, AimPoint, Eject, CharmPoint), part names, Neon material on neon parts, welds, the collision/query flags, the right scale (Bitrate = 3.8 studs) and the right orientation. Show me a screenshot and ask me to check the attachment positions.
4. When I approve, save it as assets/Weapons/<Id>.rbxm (IDs without spaces, e.g. HardReset) and tick the Asset Tracker.
5. Also write a small validator script I can run anytime that checks every gun in ReplicatedStorage.Assets.Weapons against the standard and prints what's missing.
```

### Prompt 5: Start building the gun system
```
Read vault/01 Design/Gunplay.md and vault/01 Design/Weapons.md. Let's build the gun system following the build order in Gunplay.md, one step at a time:
Step 1: movement (walk, sprint, crouch, slide, slide-jump) with the Input Action System, and Config/Weapons.luau with all wave 1 guns as data.
Use the roblox-dev skills (new-system, roblox-security) if you have them. Run stylua and selene, then tell me exactly what to test in Studio. Wait for my feedback before step 2.
```

### Every day: start
```
Read CLAUDE.md, vault/00 Home.md and the latest note in vault/05 Production/Daily Log/. Today we're working on: [task]. Yesterday's notes: [paste or "see log"]. Start with [first thing] and stop when it's ready for me to test.
```

### Every day: end
```
End of day. Write today's Daily Log from the template (what we did, what I tested, problems, 3 notes for tomorrow, commits), update Status in 00 Home and the Asset Tracker, run stylua and selene, commit everything with a clear message and push.
```

### Anytime: playtest notes
```
I just playtested. Here's what happened: [brain-dump]. Turn this into a Playtest note from the template in vault/05 Production/Playtests/, add bugs to Bugs & Ideas, and propose the top 3 fixes.
```

---

## Troubleshooting
| Problem | Fix |
|---|---|
| `rokit` not found | Restart the terminal; rerun the Rokit installer |
| Rojo plugin won't connect | `rojo serve` must be running in the repo folder; same port (34872) in the plugin |
| Plugin error `attempt to index number with 'protocolVersion'` | The Studio plugin and `rojo serve` are different Rojo versions. In the repo folder run `rokit install`, then `rojo plugin install`, restart Studio, `rojo serve`, Connect. Remove any other Rojo plugin (Creator Store copy) under Plugins → Manage Plugins |
| My Studio edits disappeared | You edited something Rojo owns (Shared, Assets, Server, Client). Edit files instead, or work in staging/Workspace |
| `stylua --check` fails on Windows | Line endings: make sure `.gitattributes` exists (Prompt 1), then run `stylua src` |
| `selene` std library error | Run `selene generate-roblox-std` once with internet access |
| Obsidian shows broken links | Make sure you opened the `vault` folder, not the repo root |
