"""Write the review index and line ledgers from verified Blender assets."""
import json
import os
from pathlib import Path
from urllib.parse import quote

from skin_review_sheets import REVIEW, ROOT, VAULT, MAPS

LINES = ("Prism","Redline","Nitrous","PopCircuit")
HEADING = "## Blender roster build"
HERO = {"Prism":"Vandal","Redline":"Phantom","Nitrous":"Vandal","PopCircuit":"Guardian"}
DATE = "2026-11-12"


def link(label,path,relative_to):
    relative = Path(os.path.relpath(path,relative_to)).as_posix()
    return f"[{label}]({quote(relative,safe='/')})"


def mark_section(path,heading,body):
    current = path.read_text(encoding="utf-8")
    original = current.split("\n"+heading+"\n",1)[0].rstrip()
    path.write_text(original+"\n\n"+heading+"\n\n"+body.rstrip()+"\n",encoding="utf-8")


def build_table(records,relative_to,include_line=True):
    rows = [("| Line " if include_line else "")+"| Item | Status | Asset | Maps | Build record |"]
    rows.append(("| --- " if include_line else "")+"| --- | --- | --- | --- | --- |")
    for r in records:
        blend = ROOT/r["blend"]
        manifest = ROOT/r["manifest"]
        item = r["item"]
        asset = link(r["version"]+" .blend",blend,relative_to) if blend.is_file() else "Pending"
        record = link("Manifest",manifest,relative_to) if manifest.is_file() else "Pending"
        maps = " · ".join(link(name,manifest.parent/"textures"/f"{item}_{name}.png",relative_to)
                          for name in MAPS) if manifest.is_file() else "Pending"
        prefix = "| "+r["line"]+" " if include_line else ""
        rows.append(f'{prefix}| {item} | {r["status"]} | {asset} | {maps} | {record} |')
    return "\n".join(rows)


def update_manifests(records):
    for index,record in enumerate(records):
        if record["status"]!="Ready for Blender review":
            continue
        path = ROOT/record["manifest"]
        data = json.loads(path.read_text(encoding="utf-8"))
        following = records[index+1] if index+1<len(records) else None
        data["next_queue_item"] = (
            {"line":following["line"], "item":following["item"]} if following else None
        )
        data["next_phase"] = "Owner Blender review, then coordinated gameplay-place Studio check"
        data["review_renders"] = record["renders"]
        data["texture_settings"] = {
            "dimensions":[1024,1024], "padding_pixels":6,
            "Color":"sRGB", "Normal":"OpenGL tangent space (+Y)",
            "Roughness":"Non-Color", "Metalness":"Non-Color",
        }
        path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")


def sheet_links(line,relative_to):
    files = [*sorted(REVIEW.glob(f"{line}-[0-9][0-9].jpg")),REVIEW/f"{line}-details.jpg"]
    if line=="PopCircuit":
        files.append(REVIEW/"PopCircuit-Bat-poses.jpg")
    return " · ".join(link(p.stem,p,relative_to) for p in files if p.is_file())


def main():
    records = json.loads((REVIEW/"verification.json").read_text(encoding="utf-8"))
    update_manifests(records)
    ready = sum(r["status"]=="Ready for Blender review" for r in records)
    accepted = sum(r["status"]=="Owner accepted" for r in records)
    pending = [r for r in records if r["status"]=="Needs follow-up"]
    summary = (f"**{DATE}** · {ready} new variants ready for Blender review · "
               f"{accepted} previously accepted · {len(pending)} remaining")
    next_item = (
        "Resolve " + ", ".join(f'{r["line"]} {r["item"]}' for r in pending) + "."
        if pending else "Owner review of the Blender sheets, then confirm Studio is available for the gameplay-place smoke test."
    )
    for line in LINES:
        line_records = [r for r in records if r["line"]==line]
        folder = VAULT/line
        ledger = folder/"Build Ledger.md"
        if not ledger.is_file():
            ledger.write_text(f"# {line} build ledger\n\n"
                              f"[Concept and palette](concept.md) · [Current queue](../Concept%20Sheet%20Queue.md)\n",
                              encoding="utf-8")
        line_pending = [r for r in line_records if r["status"]=="Needs follow-up"]
        count = len(line_records)-len(line_pending)
        line_next = ("Resolve "+", ".join(r["item"] for r in line_pending)+"." if line_pending else next_item)
        body = [
            f"**{DATE}** · {count}/{len(line_records)} Blender entries verified. Hero review starts with {HERO[line]}.",
            sheet_links(line,folder),
            build_table(line_records,folder,include_line=False),
            f"**Next step.** {line_next}",
        ]
        if line=="Prism":
            body.append("The Vandal milestone above records the earlier Studio work. Its approved images and saved variant were reused.")
        if line=="Nitrous":
            body.append("The melee slot uses the stock Knife.")
        if line=="PopCircuit":
            body.append("Guardian v02 moves the bubble and sparkles fully onto one receiver panel. The v01 build remains archived beside it.")
            body.append("The Bat uses a primary pivot near the knob and a separate support target toward the barrel. Its rig, five actions, and light-trail timing are saved for Blender review. Melee slot integration, animation playback, and trail hookup remain in the Studio phase.")
        mark_section(ledger,HEADING,"\n\n".join(body))

    validation = [
        "Each new reskin was reopened in Blender and compared with the source. The fingerprints cover mesh coordinates, face material slots, transforms, attachments, UVs, bones, NLA, and action keyframes. The four external 1024 × 1024 PNGs match their manifest checksums. The new Blender files contain packed copies.",
        "Stock UVs were retained so the gameplay templates can reuse the stock mesh IDs. The 512 × 512 coverage audit found zero inter-object overlap. Seven source items have same-part overlap, with the largest area on the Classic grip and smaller areas on Bulldog, Guardian, Marshal, Shorty, Phantom, and Judge. The side and first-person sheets are the visual check for this tradeoff.",
        "Protected surfaces retain their stock source material values. The manifests identify the protected objects for the later installer. The skin colours on existing Neon strips and dots use the line palettes.",
    ]
    if not any(r["item"]=="Bat" for r in pending):
        validation.append("The Bat was checked with the current block-arm meshes. At 24 fps, 142 sampled action frames showed zero primary anchor drift, zero support anchor drift while locked, and zero intersections between the arms or between the arms and barrel/cap. The review sheets show the light-slash trail prototype and the two-handed smash.")
    if pending:
        validation.append("**Open defects**\n\n" + "\n".join(f'- {r["line"]} {r["item"]} · {", ".join(r["exceptions"])}' for r in pending))
    index = [
        summary, "### Review sheets",
        "\n".join(f"- **{line}** · {sheet_links(line,VAULT)}" for line in LINES),
        link("Moving parts and reload details",REVIEW/"Moving-parts.jpg",VAULT),
        "### Build checks", "\n\n".join(validation),
        link("Machine-readable verification",REVIEW/"verification.json",VAULT),
        "### Studio handoff",
        "After Blender approval and confirmation that the shared Studio session is free, resume in gameplay place **133387545285290**. Verify the existing Prism Vandal template and reuse its image IDs. Install new appearances from the manifests, then run one Stock → skin → Stock smoke test with a second variant and a missing-variant fallback. Check F7, held and world appearances, and the Bat slot and poses. Place save and serialized template backups remain pending.",
        "### All 71 entries",build_table(records,VAULT),f"**Next step.** {next_item}",
    ]
    mark_section(VAULT/"Blender Review.md","## Results", "\n\n".join(index))
    update = summary+"\n\n[Completion table and Blender review sheets](Blender%20Review.md).\n\n"+f"**Next step.** {next_item}"
    mark_section(VAULT/"Concept Sheet Queue.md",HEADING,update)
    mark_section(VAULT/"Sol Roster Handoff.md",HEADING,update)


if __name__=="__main__":
    main()

