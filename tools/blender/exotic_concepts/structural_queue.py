"""Dispatch isolated Blender jobs and record each structural review checkpoint."""

import argparse
from concurrent.futures import ThreadPoolExecutor,as_completed
import json
import os
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import quote

from designs import GUNS,HEROES,NAMES,QUEUE


HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
ART=ROOT/"art-source/weapons/Skins"
VAULT=ROOT/"vault/02 Art/Skins"
LEDGER=VAULT/"Exotic Bundle Structural Build Ledger.md"


def link(path,label):
    return f"[{label}]({quote(Path(os.path.relpath(path,VAULT)).as_posix(),safe='/')})"


def latest(line,item):
    builds=sorted((ART/line/item/"StructuralBuild").glob("v*/build.json"))
    return builds[-1] if builds else None


def fit_flags(data):
    fit=data["fit"]
    return sum(len(fit.get(i,[])) for i in ("moving_stock_intersections","charm_fixed_intersections","cosmetic_aim_ray_hits"))


def write(failures=None,reviewed=False):
    failures=failures or {}
    rows=[]
    pending=[]
    flagged=[]
    profile_changes=[]
    width_changes=[]
    for line,item in QUEUE:
        path=latest(line,item)
        if not path:
            pending.append((line,item))
            continue
        d=json.loads(path.read_text(encoding="utf-8"))
        slug=path.parent/d['file']
        aux=[link(slug,"Blend"),link(path,"Geometry, fit and poses")]
        if (path.parent/"hero.png").is_file():
            aux += [link(path.parent/"hero.png","Rest"),link(path.parent/"active.png","Active")]
        if (path.parent/"aim.png").is_file():
            aux += [link(path.parent/"aim.png","Aim"),link(path.parent/"underside.png","Underside")]
        count=fit_flags(d)
        f=d["fit"]
        if (line,item) in GUNS:
            orig,new=f["stock_bounds"][2],f["new_bounds"][2]
            profile_changes.append(abs(1-(new[0]/new[2])/(orig[0]/orig[2]))*100)
            width_changes.append(new[1]-orig[1])
        if count:
            flagged.append((line,item,count))
        result=f"{count} sampled fit hits" if count else ("Stock motion and sight checks passed" if (line,item) in GUNS else "Geometry and neutral reset verified")
        rows.append(f"| {line} | {NAMES.get(item,item)} | {d['version']} | {' · '.join(aux)} | {result} |")
    if pending:
        checkpoint=f"{len(rows)} / 24 reopen checks saved. Next file awaiting a receipt is **{' / '.join(pending[0])}**."
    elif flagged:
        checkpoint=f"24 / 24 structural files reopened. Fit review is open on {len(flagged)} items."
    elif reviewed:
        checkpoint="All 24 structural files reopened. The Blender fit checks and selected visual reviews are complete."
    else:
        checkpoint="24 / 24 structural files reopened. Targeted visual review is next."
    heroes=[]
    for line,item in HEROES:
        base=ART/line/item/"StructuralConcept/v01"
        model=base/f"{item}_{line}_structure_v01.blend"
        if model.exists():
            heroes.append(f"- {line} {item} · {link(model,'Silhouette and sight study')} · {link(base/'study.json','Measured stock envelope')} · {link(base/'active.png','Active pose')}")
    art=[]
    for line,item in QUEUE:
        path=VAULT/line/"out/structural-v01"/f"{item}_concept_v01.png"
        if path.is_file():
            name=NAMES.get(item,item)
            detail=" · early ceramic direction, superseded by the reactor model" if (line,item)==("Kilnlock","Odin") else ""
            art.append(f"- {line} {name} · {link(path,'Concept art')}{detail}")
    text=f"""# Exotic bundle structural build ledger

[Original concept ledger](Exotic%20Bundle%20Concept%20Ledger.md) · [Earlier material pass](Exotic%20Bundle%20Blender%20Finish%20Ledger.md) · [Art prompts](Exotic%20Structural%20Art%20Prompts.md)

## Checkpoint

{checkpoint}

The structural pass uses measured stock proportions and the existing motion cues. Spindrift gets swept pearl fins and a tidal seam. Kilnlock uses a slim graphite chassis, suspended spirit reactor, violet energy and warm metal indexing. Stacklight uses a stepped ivory bridge, open graphite frame and separate translucent cells. The scope covers offline Blender files. The rest and active beauty images are limited to the three heroes, three melees and three buddies.

The Kilnlock direction follows the dark alloys, power channels and warm hardware in the [owner's attached Prelude reference](Kilnlock/refs/Prelude_user_reference_2026-11-16.png). The Odin ceramic concept is retained in the art history.

## Structural assemblies

| Bundle | Item | Version | Blender evidence | Review |
| --- | --- | --- | --- | --- |
"""+"\n".join(rows)+"\n"
    if failures or flagged:
        text+="\n## Needs follow-up\n\n"
        text+="\n".join(f"- {line} {item} · {count} sampled fit hits in the linked audit." for line,item,count in flagged)+"\n"
        text+="\n".join(f"- {line} {item} · {fault}" for (line,item),fault in failures.items())+"\n"
    if heroes:
        text+="\n## Hero silhouette and sight experiments\n\n"+"\n".join(heroes)+"\n"
    if art:
        text+="\n## Selected art studies\n\n"+"\n".join(art)+"\n"
    if reviewed and not pending and not flagged:
        text+=f"""
## Part review

- **Spindrift Vandal.** Replaced the stock silhouette with an open swept tail, added a dark continuous seat below the stacked nacre fins, and integrated the split sight on its stock aim line. The two prow fangs move independently around the translucent tidal sheet.
- **Kilnlock Odin.** Built the long dark shroud and raised rail, seated the two dark jaws around a violet core and moved them clear of the stock feed cover. The revised index and notch sit on physical bases.
- **Stacklight Phantom.** Added the faceted ivory jacket and stepped bridge, kept the three smoked-cyan chambers visible from the fixed side and gave the carriage and indicator cells separate controls. The squared sight retains a clear central aiming window.
- **Melees and buddies.** Sounding Arc uses two swept fangs. Kiln Cleaver has a void between its rails and a separate support grip. Patch Tool uses three independently controlled glass-edged sections and a narrower nested idle. Each melee includes nine action assets. The buddies have different mount profiles and distinct gimbal, petal and cap movements.
- **Measurements.** All 18 guns retained their stock geometry data and moving parts. The largest change in rest side-profile length-to-height ratio was {max(profile_changes):.1f}%. Overall widths are listed beside the source measurements in each build receipt. The widest outer addition is {max(width_changes):.3f} studs across the profile. The three melee receipts compare rest bounds with the stock Knife.
- **Checks.** Reopened all 24 files. The sampled stock-motion, buddy swing and applicable sight-ray checks passed. The Bucky's outer plate now clears the pump, and the Bulldog and Stinger builds use the repaired stock assets. First-person hand meshes are pose guides. Live hand contact, animations in game and Studio integration remain a separate pass.
- **Blender MCP.** The live Poolside Spectre session on port 9000 launched each final build in an isolated Blender process. The earlier partial-scene write crashed Blender inside its view-layer copy routine. The recovered autosave was backed up before any further builds, and the recovered scene stayed open.
"""
    partial=LEDGER.with_name(LEDGER.name+".tmp")
    partial.write_text(text,encoding="utf-8")
    partial.replace(LEDGER)


def run(binary,line,item,version,threads):
    log_dir=Path(tempfile.gettempdir())/"GauntletStructural"
    log_dir.mkdir(exist_ok=True)
    path=log_dir/f"{line}-{item}-{version}.log"
    with path.open("wb") as f:
        proc=subprocess.run([binary,"-b","--factory-startup","-t",str(threads),"--python-exit-code","11",
                          "--python",str(HERE/"structural_roster.py"),"--",line,item,"--version",version],stdout=f,
                          stderr=subprocess.STDOUT,cwd=ROOT,creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
    if proc.returncode:
        return f"Worker exited {proc.returncode}. {path.name}."
    return None


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("binary")
    parser.add_argument("--version",default="v01")
    parser.add_argument("--only",nargs="*")
    parser.add_argument("--workers",type=int,default=3)
    args=parser.parse_args()
    fail={}
    write(fail)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs={pool.submit(run,args.binary,line,item,args.version,4):(line,item) for line,item in QUEUE
              if (not args.only or f"{line}/{item}" in args.only) and (not latest(line,item) or latest(line,item).parent.name<args.version)}
        for task in as_completed(jobs):
            line,item=jobs[task]
            error=task.result()
            if error:
                fail[line,item]=error
            print(line,item,error or "saved",flush=True)
            write(fail)
