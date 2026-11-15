"""Assemble Blender renders and cross-check the versioned skin delivery.

Run with the workspace's regular Python and Pillow after the Blender builds.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SKINS = ROOT / "art-source/weapons/Skins"
VAULT = ROOT / "vault/02 Art/Skins"
REVIEW = SKINS / "Review"
COLORS = {"Prism":"#F486C1","Redline":"#F18C91","Nitrous":"#75A9FF","PopCircuit":"#AFA5FF"}
MAPS = ("Color","Normal","Roughness","Metalness")
VIEWS = (("Left","PLAYER-FACING"),("Right","OPPOSITE SIDE"),("FirstPerson","FIRST-PERSON"))
FONTS = {}


def font(size, bold=False):
    key = (size,bold)
    if key not in FONTS:
        FONTS[key] = ImageFont.truetype("arialbd.ttf" if bold else "arial.ttf",size)
    return FONTS[key]


def current_items():
    result = defaultdict(list)
    for row in (VAULT/"Concept Sheet Queue.md").read_text(encoding="utf-8").splitlines():
        group = re.fullmatch(r"## (Prism|Redline|Nitrous|PopCircuit)",row)
        if group:
            name = group[1]
        m = re.match(r"\| (\w+) \| \[.*?\]\(((?:Prism|Redline|Nitrous|PopCircuit)/out/[^)]+)\)",row)
        if m:
            result[name].append((m[1],VAULT/m[2]))
    assert sum(map(len,result.values()))==71
    return dict(result)


def short(path):
    return path.relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entry(line,item,concept):
    accepted = (line,item)==("Prism","Vandal")
    version = "v01"
    base = SKINS/line/item
    available = sorted(p.parent.name for p in base.glob("v[0-9][0-9]/manifest.json"))
    if available and not accepted:
        version = available[-1]
    dest = base/version
    blend = dest/f"{item}_{line}_{version}.blend"
    manifest = dest/"manifest.json"
    out = REVIEW/"renders"/line/item/version
    record = {
        "line":line,"item":item,"version":version,"concept":short(concept),
        "blend":short(blend),"manifest":short(manifest),"renders":short(out),
        "status":"Owner accepted" if accepted else "Ready for Blender review",
        "exceptions":[],
    }
    try:
        assert concept.is_file(),"Current concept PNG missing"
        assert blend.is_file() and blend.stat().st_size>10000,"Versioned Blender file missing"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for name in MAPS:
            path = dest/"textures"/f"{item}_{name}.png"
            with Image.open(path) as img:
                img.load()
                assert img.size==(1024,1024) and img.mode in ("RGB","RGBA"), f"{name} has an invalid size or mode"
                assert any(lo!=hi for lo,hi in img.convert("RGB").getextrema()), f"{name} is flat"
            if not accepted:
                assert sha(path)==data["texture_sha256"][name], f"{name} checksum differs"
        if not accepted:
            assert data["saved_file_verified"], "Saved .blend verification missing"
        if not accepted and item!="Bat":
            source = ROOT/data["source"]
            assert sha(source)==data["source_file_sha256"], "Stock source changed after the bake"
            assert data["stock_uv_preserved"], "Variant UVs differ from stock"
            uv = data["uv"]
            assert uv["cross_object_overlap_pixels"]==0, "Inter-object UV overlap"
            if uv["same_object_overlap_pixels"]:
                affected = ", ".join(n.split("_",1)[-1] for n in uv["conflicting_parts"])
                note = f'{uv["same_object_overlap_pixels"]} stock same-part UV overlap pixels at 512²'
                if affected:
                    note += f" ({affected})"
                record["exceptions"].append(note)
            required = {item+"_"+clip for clip in ("Draw","Fire","Inspect","Reload","ReloadEmpty")}
            if item=="Knife":
                required = {item+"_"+clip for clip in ("Draw","Fire","Inspect","Slash1","Slash2","Slash3","HeavyStab")}
            assert required.issubset(data["actions"]), "Expected stock actions missing"
        labels = [label for label,_ in VIEWS]
        if item=="Bat":
            labels += ["Grip","SmashSet","Smash","SlashLeft","SlashRight","Inspect"]
            for name,pose in data["pose_checks"].items():
                for f,checks in pose.get("mesh_intersections",pose.get("key_pose_checks",{})).items():
                    if any(checks.values()):
                        record["exceptions"].append(f"{name} f{f} mesh intersection")
            if record["exceptions"]:
                record["status"] = "Needs follow-up"
        for label in labels:
            with Image.open(out/(label+".png")) as img:
                img.load()
                assert img.mode=="RGBA" and img.getchannel("A").getbbox(), f"{label} contains no subject"
    except (AssertionError,OSError,KeyError,json.JSONDecodeError) as exc:
        record["status"] = "Needs follow-up"
        record["exceptions"].append(str(exc))
    return record


def canvas(title,subtitle,accent,w,h):
    im = Image.new("RGB",(w,h),"#111722")
    draw = ImageDraw.Draw(im)
    draw.rectangle((34,26,40,77),fill=accent)
    draw.text((53,23),title,fill="#F1F5FC",font=font(35,True))
    draw.text((55,69),subtitle,fill="#AAB7C9",font=font(17))
    draw.line((34,106,w-34,106),fill="#334052",width=1)
    return im,draw


def picture(im, draw, path, rect, label):
    x,y,w,h = rect
    draw.rounded_rectangle((x,y,x+w,y+h),radius=7,fill="#293241",outline="#354258",width=1)
    if not path.is_file():
        draw.text((x+15,y+37),"Pending",font=font(15),fill="#CDD7E5")
    else:
        with Image.open(path) as source:
            src = source.convert("RGBA")
            src.thumbnail((w-8,h-25),Image.Resampling.LANCZOS)
            im.paste(src,(x+(w-src.width)//2,y+21+(h-23-src.height)//2),src)
    draw.text((x+11,y+7),label,fill="#C6D2E2",font=font(11,True))


def grouped(line,records):
    written = []
    for start in range(0,len(records),6):
        group = records[start:start+6]
        width,row = 1500,190
        im,draw = canvas(line,f"Blender baked materials  /  {start+1}–{start+len(group)} of {len(records)}",
                         COLORS[line],width,140+row*len(group))
        for i,record in enumerate(group):
            y = 123+i*row
            accent = COLORS[line]
            draw.text((35,y+15),record["item"],fill="#F2F5FA",font=font(23,True))
            draw.text((36,y+46),record["version"],fill=accent,font=font(15,True))
            if record["status"]=="Owner accepted":
                draw.text((36,y+75),"Owner accepted",fill="#D3DDEA",font=font(13))
            for col,(filename,label) in enumerate(VIEWS):
                picture(im,draw,ROOT/record["renders"]/(filename+".png"),(174+col*433,y,422,172),label)
        path = REVIEW/f"{line}-{start//6+1:02}.jpg"
        im.save(path,quality=92,subsampling=0,optimize=True)
        written.append(path)
    return written


def detail(line,records):
    items = [r for r in records if r["item"]!="Bat" and (ROOT/r["renders"]/"Detail.png").exists()]
    if not items:
        return None
    w=1500
    im,draw=canvas(f"{line} detail","Receiver, seam, and surface finish under the Blender review lights",
                   COLORS[line],w,138+330*((len(items)+1)//2))
    for i,r in enumerate(items):
        picture(im,draw,ROOT/r["renders"]/"Detail.png",(35+730*(i%2),124+330*(i//2),705,307),
                f'{r["item"].upper()}  /  {r["version"]}')
    path=REVIEW/f"{line}-details.jpg"
    im.save(path,quality=92,subsampling=0,optimize=True)
    return path


def bat_sheet(record):
    root = ROOT/record["renders"]
    im,draw = canvas("PopCircuit Bat","Blender rig and first-person review  /  24 fps",COLORS["PopCircuit"],1500,1090)
    rows = (
        ("Detail","PLAYER-FACING BARREL"),("Right","OPPOSITE SIDE"),("Grip","WRAP AND GRIP SPACING"),
        ("FirstPerson","IDLE"),("SlashLeft","LEFT LIGHT SLASH"),("SlashRight","RIGHT LIGHT SLASH"),
        ("SmashSet","HEAVY WINDUP  /  SUPPORT LOCKED"),("Smash","HEAVY CONTACT"),("Inspect","RAISE AND TURN"),
    )
    for i,(name,label) in enumerate(rows):
        picture(im,draw,root/(name+".png"),(35+(i%3)*482,123+(i//3)*319,467,301),label)
    path=REVIEW/"PopCircuit-Bat-poses.jpg"
    im.save(path,quality=92,subsampling=0,optimize=True)
    return path


def motion_sheet(records):
    clips = [("Prism","Phantom","Reload","PHANTOM  /  MAGAZINE OUT"),
             ("Redline","Classic","Inspect","CLASSIC  /  INSPECT"),
             ("Nitrous","Outlaw","ReloadEmpty","OUTLAW  /  ACTION OPEN"),
             ("PopCircuit","Shorty","ReloadEmpty","SHORTY  /  ACTION OPEN")]
    im,draw = canvas("Moving parts","Stock actions sampled at the selected part's maximum travel",
                     "#AFA5FF",1500,790)
    for i,(line,item,clip,label) in enumerate(clips):
        record = next(r for r in records if r["line"]==line and r["item"]==item)
        path = next(iter(sorted((ROOT/record["renders"]).glob(f"{clip}-*.png"))),None)
        if path:
            label += "  /  FRAME " + path.stem.rsplit("-",1)[1]
            picture(im,draw,path,(35+730*(i%2),124+330*(i//2),705,307),label)
    path = REVIEW/"Moving-parts.jpg"
    im.save(path,quality=92,subsampling=0,optimize=True)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--line",choices=COLORS)
    opts=parser.parse_args()
    REVIEW.mkdir(parents=True,exist_ok=True)
    entries = current_items()
    lines = [opts.line] if opts.line else list(entries)
    all_records=[]
    for line in lines:
        records=[entry(line,item,concept) for item,concept in entries[line]]
        all_records += records
        files = grouped(line,records)
        closeup = detail(line,records)
        if closeup:
            files.append(closeup)
        if line=="PopCircuit":
            files.append(bat_sheet(next(r for r in records if r["item"]=="Bat")))
        print(line,[(r["item"],r["status"],r["exceptions"]) for r in records if r["exceptions"]])
        print("Review sheets",*[p.name for p in files])
    if not opts.line:
        (REVIEW/"verification.json").write_text(json.dumps(all_records,indent=2)+"\n",encoding="utf-8")
        motion_sheet(all_records)
    print(f"Verified {sum(r['status']!='Needs follow-up' for r in all_records)} of {len(all_records)} entries")


if __name__=="__main__":
    main()

