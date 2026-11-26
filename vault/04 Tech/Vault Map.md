# Vault Map

How Claude reads this vault without reading every word (owner 2026-11-25: "not burning usage by reading every word … best practices before I move on").

## The tool
`tools/vault_map.py` is plain Python and makes no LLM calls. It parses every project note's headings into sections, recording each section's line range, size and word counts, plus the note's links (markdown and `[[wiki]]`). The result is cached in `tools/.cache/vault_map.json`, which is gitignored and rebuilds by itself in about 1.7 s whenever a note changes. A query takes about 0.25 s. It skips `LihFolk/` (which has its own index), `References/`, `Attachments/` and `Templates/`.

| Command | Answer |
|---|---|
| `find <words>` | The best 8 sections across all notes: `path:start-end`, lines, size, heading and the best matching line, plus the top note's links |
| `outline "<note>"` | Headings with line ranges and sizes, links out and backlinks |
| `related "<note>"` | Linked notes, the ones linked both ways first |
| `health` | Notes and single sections over 15 KB, broken links, notes nothing links to that INDEX also misses |

Then `Read vault/<path>` with offset = start and limit = the line count. The `vault-lookup` agent and the `gauntlet-vault` skill both use it first. INDEX and the Code Map are still there for finding things by name.

## Why not an LLM knowledge graph (Graphify)
[Graphify](https://github.com/safishamsi/graphify) is the usual recommendation. It is a pip package plus a skill that turns a folder into a knowledge graph and can export it to Obsidian. It extracts code with an AST parser but extracts docs with an LLM, so building the graph for our 348 notes (5.4 MB) costs tokens, and every rebuild after an edit costs tokens again. The vault changes every day. Our notes already carry the structure such a graph would extract: headings, dated sections and about 2,000 links. A section index built from that structure gives the main benefit, jumping straight to the part that answers the question, with no build cost and nothing third-party to install. Revisit Graphify only if `find` starts missing things that are worded differently from the question. That is a meaning-search problem, and the fix for it would be local embeddings, not a graph.

## Measured (2026-11-25, same two questions, Haiku)
- **Old way** (`vault-lookup`, grep INDEX → grep note → ranged reads): 16-17 tool calls, 27-30 s, about 39k tokens, answers correct. Its reading habits were already good: no whole big notes, only ranged reads.
- **Map way** (a fresh agent given the new steps): **5 tool calls, 21 s**, same answers. It also flagged the same plan-versus-config mismatch. Its token count (86k) can't be compared with the old run, because a general-purpose agent carries every tool's schema in its prompt. The real check is `vault-lookup` with the map in the next session (agent definitions load at session start).
- **Health pass:** fixed 157 broken links in `Status History.md` (relative to Home from when they were moved) and one in the Antigravity audit. Two remain: TempestStrike `Build Review.md` was never written.

## Open
- Ten single sections are over 15 KB with no heading to jump to (`health` lists them). The biggest are the Status History log (141 KB), the Blender Review entries (42 KB) and the Asset Tracker tables. They are fine to grep, but adding subheadings would make them findable by section.
- 25 notes are linked from nowhere and missing from INDEX, mostly skin prompts and ledgers and the `*2` map notes.
