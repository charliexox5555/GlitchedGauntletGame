# AI setup prompt

Paste the block below into an AI assistant when you want help setting up the folder for a new skin line. It explains the structure and tells the assistant what to ask you and what to write. It works with an assistant that can create files on this computer (Claude Code, Codex) and with one that can't (ChatGPT in the browser, which gives you the file contents to save yourself).

```
You are helping me set up the folder for a new weapon skin line for my own first-person shooter. Set it up exactly as described here. Do not design the skin yet and do not generate images in this step.

WHERE IT LIVES
Every skin line gets one folder inside:
  vault/02 Art/Skins/
A "skin line" is one look carried across several guns (like a bundle). The folder is named after the line, in one word with capitals and no spaces (Sunforge, NightMarket).

WHAT GOES IN THE FOLDER
  <SkinLine>/
    concept.md        the brief (described below)
    prompt.md         the prompts I will paste into ChatGPT to make the concept sheets
    refs/style/       reference pictures for the overall look (other games' skins, product photos, concept art)
    refs/texture/     reference pictures for surfaces (materials, patterns, paint finishes)
    out/              the concept sheets ChatGPT returns, saved as <Gun>_v01.png, <Gun>_v02.png ...

There is a ready-made starting point at vault/02 Art/Skins/_Template/ with a blank concept.md and prompt.md. If you can read and write files, copy that folder and rename the copy. If you can't, ask me to paste the two template files, or write them from the descriptions below.

Reference pictures are other people's images. They stay in refs/ only (that folder is ignored by git) and each one is named for what it shows, numbered: 01_matte-white-armour.png, 02_orange-anodised-metal.png.

THE GUNS AND THEIR BASE SHEETS
The guns are: Vandal, Phantom, Bulldog, Guardian, Spectre, Stinger, Ares, Odin, Sheriff, Classic, Ghost, Shorty, Bucky, Judge, Marshal, Outlaw, Operator, Knife.
Each has a base model sheet at art-source/weapons/ModelSheets/<Gun>_model_sheet.png showing every angle, the magazine, the round, the sights, the charm mount and the colour roles. Those sheets are what gets attached to ChatGPT later. Do not move or copy them.

THE NINE COLOUR ROLES
A skin is colour, material and pattern applied to these nine roles. The stock colours are:
  Body   #383D48  main shell
  Panel  #555C69  inset panels and plates
  Dark   #1C1E23  magazine, stock pad, guards
  Grip   #25272D  textured grip areas
  Metal  #62676F  barrel, bolt, pins
  Accent #AEB4BC  charging handle, selector, releases (bright nickel)
  Neon   #2A6BFF  thin glow strips and sight dots
  Brass  #A8844E  rounds and shell heads
  Glass  #16202C  scope lenses

RULES EVERY SKIN FOLLOWS (keep them in mind when you fill the files)
- The gun's shape does not change: same silhouette, proportions and part positions as its base sheet.
- Patterns go on Body and Panel. Grip and Dark stay dark enough to read as grip and polymer.
- Small add-on pieces only (a plate, a fin, a wrap, a badge): nothing in the rear sight window or on the line to the front post, nothing on the magazine or trigger, outline changed by no more than about a tenth.
- Stylised low-poly with flat colour areas. No photoreal wear, no small text, no real brand logos.
- The left side is the side the player sees, so the signature detail goes there.
- Neon stays small: thin strips and dots.
- Original designs only. References set the mood and level of finish; never copy a named skin from another game.

WHAT TO DO, IN ORDER
1. Ask me these questions, all at once, and wait for my answers:
   a. The skin line's name.
   b. What it is, in one sentence, and three to five mood words.
   c. Which guns are in the line, and which one is the hero gun (designed first).
   d. For each of the nine roles: the colour or a description, and the finish (matte, satin, gloss, metal, textured). I can answer "base" to keep the stock colour, or "you suggest" for any of them.
   e. The pattern or motif: what it is, how big, and which roles it sits on.
   f. The one signature detail people should remember.
   g. Any small add-on pieces, and whether I want a matching charm.
   h. Things to avoid for this line.
   i. The reference pictures I have: for each, the file name, whether it is a style or a texture reference, what to take from it and what to ignore.
2. Where I answered "you suggest", propose values and tell me which ones are yours.
3. Create the folder with its refs/style, refs/texture and out subfolders.
4. Write concept.md with these sections, filled from my answers:
   - title (the line's name), the one-line description, the mood words, and Status: idea
   - "Guns in the line": a table with columns Gun, In the line, Hero, Approved sheet
   - "Colour per role": a table with columns Role, Stock, This line, Finish, one row per role, all nine
   - "Pattern and details": pattern, signature detail, add-on pieces, matching charm
   - "Do not": my list of things to avoid
   - "References": a table with columns File, Take from it, Ignore, one row per picture
   - "Parked ideas": anything I mentioned that is not for the concept sheet (effects, sounds, variants)
   - "Log": today's date and "folder set up"
5. Write prompt.md by taking the three prompts from the template (direction check, hero gun sheet, every other gun) and filling every <...> from concept.md. Leave the direction number and the "changes" line blank, because I choose those later.
6. Tell me exactly which reference pictures to save into which refs folder and under what file name, so the names match the References table.
7. Finish with a short checklist of what is done and what I still have to do by hand.

If you cannot create files or folders yourself, do steps 1 and 2, then give me the folder tree to make by hand and the full contents of concept.md and prompt.md in two separate code blocks.
```
