# Codex collaboration

**User decision (2026-11-05):** Claude (Max plan) works together with the user's **Codex desktop app** (ChatGPT Plus, $20). From now on the Claude core chat opens the Codex app itself with computer use and prompts it. The user doesn't paste for us. Codex has the project folder open, and it can reach the **Roblox Studio MCP** and the **Blender MCP**.

## What Codex is for
Its job is to add capacity and a second eye, not to replace the Claude lanes.
- **Concept images:** maps, structures, kit sheets, material and trim swatches, UI screens. It reads the prompts and references from the vault and saves the files straight into the repo. This is its strongest use; Claude can't generate images.
- **References and research:** finding reference images and real-world photos, and short research notes on what a shipped game does. Third-party images go into `third-party/` folders and are never committed.
- **Models (trial):** individual props or kit pieces in Blender through its MCP, built to the [Art Direction](../02%20Art/Art%20Direction.md) model standard. Claude reviews each against the concept and the LihFolk modelling notes before it's used.
- **A second opinion:** review a concept, a score or a plan blind, when the Claude reviewers might share the same blind spot.
- **Not for:** server code, remotes, security or data. Those stay with Claude lanes (CLAUDE.md code rules).

## Budget (Plus is small, so spend it on what only Codex can do)
- Plus has a 5-hour limit and a weekly limit. Image generation uses the limit about **3–5x faster** than plain turns ([Codex pricing](https://developers.openai.com/codex/pricing/)).
- Every MCP server adds context and burns limit. Only connect Studio or Blender for a job that needs it.
- Batch the work: one well-specified prompt per job, pointing at the vault notes, beats many small turns.
- If Codex says the limit is reached, stop and note where the job got to. Don't buy credits; that's the user's call.

## How the core chat drives it
1. Write the job as a short brief in the vault (like [Codex Concept Brief 2026-11-05](../05%20Production/Archive/Codex%20Concept%20Brief%202026-11-05.md)):
   - what to read,
   - what to make,
   - where to save it,
   - the rules: no git, only the named paths, original designs, no text or logos.
2. Computer use: open the Codex app, use the chat with the GlitchedGauntletGame folder, paste a one-line pointer plus the brief, and send.
3. Don't watch it. Check back later, read its file list, and check the files on disk.
4. Hand the results to the Claude lane that owns the area. That lane reviews, commits the generated files path-limited, and writes the results into the vault.

## Rules for Codex jobs (put them in every brief)
- Vault and LihFolk first: read the notes the brief names.
- No git (no add, commit or push). Claude commits.
- Write only the paths the brief names.
- Studio or Blender: take the lock in `.claude-locks/` the same way the lanes do (`match-studio.lock`, `lobby-studio.lock`, `blender.lock`), and never touch a locked tool. Never publish a place. Never `require` server modules over MCP.
- Never type or ask for credentials.
- Third-party images are for mood and quality level only. Every design is original.
