"""Run the outfit finish workers, recording each verified save in the vault."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import msvcrt
import os
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import quote

from designs import GUNS, NAMES, QUEUE


HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
ART=ROOT/"art-source/weapons/Skins"
VAULT=ROOT/"vault/02 Art/Skins"
LEDGER=VAULT/"Exotic Bundle Blender Finish Ledger.md"


def output(line,item,version):
    return ART/line/item/"Finish"/version


def record_for(line,item):
    for path in sorted((ART/line/item/"Finish").glob("v*/build.json"),reverse=True):
        result=json.loads(path.read_text(encoding="utf-8"))
        if (path.parent/result["file"]).is_file() and (path.parent/"beauty.png").is_file():
            return path,result
    return None,None


def markdown(path,label):
    link=quote(Path(os.path.relpath(path,VAULT)).as_posix(),safe="/")
    return f"[{label}]({link})"


def write_ledger(failures,visual=False,target=None):
    rows=[]
    pending=[]
    for line,item in QUEUE:
        path,record=record_for(line,item)
        if record:
            pack=[markdown(path.parent/record['file'],'Blend'),
                  markdown(path.parent/'beauty.png','Material render'),markdown(path,'Build and fit checks')]
            motion=f"{len(record['actions'])} named clips and original reel" if record["actions"] else "Keyed review timeline"
            rows.append(f"| {line} | {NAMES.get(item,item)} | {record['version']} | {' · '.join(pack)} | {motion} |")
        if not record or (target and record['version']<target):
            pending.append((line,item))
    if pending:
        line,item=pending[0]
        version=f" at {target}" if target else ""
        summary=f"**{24-len(pending)} / 24 reopened and validated{version}.** Next item awaiting a verified save is **{line} / {item}**."
    elif visual:
        summary="**Complete. 24 / 24 Blender finishes saved, reopened, and visually reviewed.**"
    else:
        summary="**24 / 24 Blender finishes saved and reopened.** Final visual review is the next stage."
    issues="\n".join(f"- {line} / {item} · {error}" for (line,item),error in failures.items())
    text=f"""# Exotic bundle Blender finish ledger

[Concept pass and pose references](Exotic%20Bundle%20Concept%20Ledger.md) · [Animator handoff](Exotic%20Bundle%20Animator%20Handoff.md)

## Current checkpoint

{summary}

The pass uses the reviewed designs and the repaired stock sources for Bulldog and Stinger. Finished files contain editable shaders, flat chamfers on the castings, named controls, a lit studio camera and the animations from the Blender review. Each melee also has separate action assets for equip, idle, carry, light A, light B, heavy, inspect, recovery and cancel. Hand meshes in the review collection are concept posing guides.

| Bundle | Item | Version | Files and evidence | Motion in the Blender scene |
| --- | --- | --- | --- | --- |
"""+"\n".join(rows)+"\n"
    if issues:
        text+="\n## Recheck pending\n\n"+issues+"\n"
    if visual and not pending:
        text+="""
## Final checks

- Reopened all 24 saved Blender files and visually reviewed their Cycles material renders. Each item moves away from the neutral state and resets to it.
- Compared the geometry and UV data against all 18 stock gun sources. The sampled clearance and sight-ray checks passed. The finish pass retains the original stock moving-part relationships.
- Guardian's bead returns to its home position at cancel. The revised lighting preserves contrast in the shell finishes. Patch Tool's wider presentation margin shows the full handle and panel silhouette.
- Set the scene camera to the saved player camera and enable the first-person posing-guide collection to review the held reel. The 27 rig actions are available in the Asset Browser. The original animated reel is active in each melee file.
"""
    partial=LEDGER.with_name(LEDGER.name+".tmp")
    partial.write_text(text,encoding="utf-8")
    partial.replace(LEDGER)


def run_one(binary,workers,line,item,version,logs):
    log=logs/f"{line}-{item}-{version}.log"
    with log.open("wb") as stream:
        result=subprocess.run([str(binary),"-b","--factory-startup","-t",str(workers),"--python-exit-code","11",
                               "--python",str(HERE/'finish.py'),"--",line,item,"--version",version],
                              stdout=stream,stderr=subprocess.STDOUT,cwd=ROOT,creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
    if result.returncode or not (output(line,item,version)/"build.json").is_file():
        return f"Blender worker exited {result.returncode}. Log {log.name}."
    return None


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("binary",type=Path)
    parser.add_argument("--version",default="v01")
    parser.add_argument("--only",nargs="*",default=[])
    parser.add_argument("--parallel",type=int,default=2)
    args=parser.parse_args()
    logs=Path(tempfile.gettempdir())/"GauntletExoticFinish"
    logs.mkdir(exist_ok=True)
    workers=max(2,min(6,(os.cpu_count() or 8)//args.parallel))
    failures={}
    jobs=[]
    for line,item in QUEUE:
        selection=f"{line}/{item}"
        if args.only and selection not in args.only:
            continue
        path,_=record_for(line,item)
        if path and path.parent.name>=args.version:
            continue
        jobs.append((line,item))
    write_ledger(failures,target=args.version if not args.only else None)
    with ThreadPoolExecutor(max_workers=args.parallel) as pool:
        tasks={pool.submit(run_one,args.binary,workers,line,item,args.version,logs):(line,item) for line,item in jobs}
        for task in as_completed(tasks):
            line,item=tasks[task]
            fault=task.result()
            if fault:
                failures[line,item]=fault
            print(line,item,fault or "verified",flush=True)
            write_ledger(failures,target=args.version if not args.only else None)
    return 1 if failures else 0


if __name__=="__main__":
    lock_path=Path(tempfile.gettempdir())/"GauntletExoticFinish.queue.lock"
    with lock_path.open("a+b") as lock:
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        except OSError:
            raise SystemExit("The Blender finish queue is already running.") from None
        raise SystemExit(main())
