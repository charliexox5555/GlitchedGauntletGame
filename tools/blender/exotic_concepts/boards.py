"""Assemble the rendered PNG sheets and the frame-sampled offline motion previews."""

import argparse
from functools import lru_cache
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont, ImageOps

from designs import CHARMS, GUNS, HEROES, LINES, MELEES, NAMES, NOTES, QUEUE


ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art-source/weapons"
VAULT = ROOT / "vault/02 Art/Skins"
LEDGER = VAULT / "Exotic Bundle Concept Ledger.md"
FONT = Path("C:/Windows/Fonts")


def output_path(line,item,version):
    if (line,item) in HEROES + MELEES + CHARMS:
        return ART / "Skins" / line / item / "Concept" / version
    return VAULT / line / "out/pose-reference" / (item+"_"+version)


def latest(line,item):
    paths=[p for n in range(1,10) if (p:=output_path(line,item,f"v{n:02d}") / "review.json").is_file()]
    if not paths:
        raise FileNotFoundError(line+" / "+item+" / review.json")
    return paths[-1]


@lru_cache(maxsize=32)
def font(size,role="body"):
    family={"body":"segoeui.ttf","heading":"bahnschrift.ttf","mono":"consola.ttf","bold":"segoeuib.ttf"}[role]
    return ImageFont.truetype(str(FONT/family),size)


def png(path):
    with Image.open(path) as im:
        im.load()
        return im.convert("RGBA")


def words(draw,text,size,width):
    out=[]
    current=""
    f=font(size)
    for token in text.split():
        proposed=(current+" "+token).lstrip()
        if current and draw.textlength(proposed,font=f)>width:
            out.append(current)
            current=token
        else:
            current=proposed
    return out+[current]


class Board:
    def __init__(self,line,item,version,kind):
        self.width,self.height=1800,1320
        self.img=Image.new("RGB",(self.width,self.height),"#111820")
        self.draw=ImageDraw.Draw(self.img)
        self.accent="#"+LINES[line][2]
        self.draw.rectangle((48,42,128,47),fill=self.accent)
        self.text((48,61),line.upper(),24,self.accent,"mono")
        self.text((46,89),NAMES.get(item,item),65,"#F4F4EF","heading")
        self.text((1752,66),"GLITCHED GAUNTLET",22,"#F4F4EF","mono",anchor="ra")
        self.text((1752,104),kind.upper()+" / "+version.upper(),19,"#A8B5BE","mono",anchor="ra")
        self.draw.line((48,177,1752,177),fill="#34434E",width=2)

    def text(self,xy,text,size=20,color="#E2EBEF",role="body",anchor=None):
        self.draw.text(xy,text,font=font(size,role),fill=color,anchor=anchor)

    def panel(self,x,y,w,h,title,source,kind="isolated",sub=None):
        back={"isolated":"#84949C","fp":"#535F69","detail":"#74818B","guide":"#B1BABE"}[kind]
        self.draw.rectangle((x,y,x+w-1,y+h-1),fill="#19232D",outline="#35444E")
        self.text((x+15,y+9),title,18,"#E4EDEF","mono")
        ih=h-(62 if sub else 43)
        xi,yi=x+2,y+39
        self.draw.rectangle((xi,yi,x+w-3,yi+ih-1),fill=back)
        if source is not None:
            im=png(source) if isinstance(source,(str,Path)) else source.copy().convert("RGBA")
            if kind in ("isolated","guide") and im.getchannel("A").getextrema()[0]==0:
                crop=im.getbbox()
                if crop:
                    im=im.crop(crop)
            if kind=="fp":
                factor=min(w/im.width,ih/im.height)
                thumb=im.resize((int(im.width*factor),int(im.height*factor)),Image.Resampling.LANCZOS)
            else:
                thumb=ImageOps.contain(im,(w-22,ih-7),Image.Resampling.LANCZOS)
            self.img.paste(thumb,(xi+(w-4-thumb.width)//2,yi+(ih-thumb.height)//2),thumb)
        if sub:
            self.text((x+11,y+h-21),sub,14,"#AABAC5","mono")

    def note(self,label,text,x,y,width,size=20):
        self.text((x,y),label,17,self.accent,"mono")
        for i,line in enumerate(words(self.draw,text,size,width)):
            self.text((x,y+24+i*(size+5)),line,size)

    def swatches(self,line,x,y):
        labels={"Spindrift":("Basalt","Pearl alloy","Sea glass","Coral cuff","Smoked channel"),
                "Kilnlock":("Blackened iron","Firebrick","Heat core","Oxidized copper","Kiln seat"),
                "Stacklight":("Graphite","Molded ivory","Mint","Lilac","Smoked blue")}[line]
        for i,(label,hex_color) in enumerate(zip(labels,LINES[line])):
            self.draw.rectangle((x+i*153,y,x+i*153+135,y+23),fill="#"+hex_color)
            self.text((x+i*153,y+28),label,15,"#B6C3C9")


def study_crop(path):
    im=png(path)
    return im.crop((0,0,im.width,int(im.height*.62)))


def action_crop(path):
    im=png(path)
    return im.crop((round(im.width*.43),round(im.height*.14),im.width,im.height))


def gun_board(b,line,item,a,root):
    view=lambda k: root/"views"/(k+".png")
    rev=a["motion"]
    study=VAULT/line/"refs"/(item+"_finish_study_v01.png")
    b.panel(48,199,1098,457,"THREE-QUARTER / REST",view("hero"))
    b.panel(1164,199,588,218,"FIXED SIDE / STOCK PROFILE",view("side"))
    b.panel(1164,429,285,227,"PLAYER CAMERA",view("held"),"fp")
    aim_label="STOCK AIM" if item in ("Vandal","Phantom","Odin","Bulldog","Guardian","Spectre","Stinger","Ares","Sheriff") else "STOCK TOP REFERENCE"
    b.panel(1461,429,291,227,aim_label,view("aim"),"fp")
    b.panel(48,675,493,230,"ACTIVE CASSETTE / MATERIALS",view("detail"),"detail")
    b.panel(555,675,381,230,"RIGHT SIDE / UNDERSIDE",view("right"))
    if study.exists():
        b.panel(950,675,406,230,"FINISH EXPLORATION / IMAGEGEN",study_crop(study),"detail")
    elif item=="Shorty" and "empty_second" in rev:
        b.panel(950,675,406,230,f"EMPTY / SECOND SHELL / F{rev['empty_second']:03d}",view("empty_second"),"fp")
    elif view("mount").exists() and (line,item) not in HEROES:
        b.panel(950,675,406,230,"STOCK CHARMPOINT / SWING",view("mount"),"detail")
    else:
        check="inspect" if view("inspect").exists() else "cancel"
        b.panel(950,675,406,230,"INSPECT / PLAYER CAMERA" if check=="inspect" else "INTERRUPTED / RESET",view(check),"fp")
    icon=view("icon")
    if icon.exists():
        mounted=png(view("held"))
        base=Image.new("RGBA",(360,170),(0,0,0,0))
        base.alpha_composite(ImageOps.contain(mounted,(267,160)),(80,4))
        badge=png(icon)
        badge=ImageOps.contain(badge.crop(badge.getbbox()),(58,66))
        base.alpha_composite(badge,(17,51))
        b.panel(1370,675,382,230,"CHARM / ICON + MOUNT",base,"detail")
    else:
        b.panel(1370,675,382,230,"CANCEL / RETURN TO REST",view("cancel"),"fp")
    steps=[("START","start",rev["open"]),("COMMIT","commit",rev["commit"])]
    steps.extend((f"COMMIT {i}",f"commit_{i}",f) for i,f in enumerate(rev["steps"][1:],2))
    steps.append(("READY","ready",rev["ready"]))
    width=(1704-14*(len(steps)-1))//len(steps)
    for i,(label,key,frame) in enumerate(steps):
        b.panel(48+i*(width+14),927,width,236,f"{label} / F{frame:03d}",action_crop(view(key)),"detail")
    b.note("COSMETIC MOTION",GUNS[(line,item)][-1],48,1186,770)
    b.swatches(line,982,1193)


POSES=[("EQUIP","equip"),("IDLE","idle"),("CARRY","carry"),("LIGHT A","light_a"),("LIGHT B","light_b"),
       ("HEAVY","heavy"),("INSPECT","inspect"),("RECOVERY","recovery"),("CANCEL / REST","cancel")]


def melee_board(b,line,item,a,root):
    view=lambda k: root/"views"/(k+".png")
    b.panel(48,199,800,458,"THREE-QUARTER / OPEN REST SHAPE",view("hero"))
    verify=root/"reopen-check.json"
    profile=png(view("side"))
    if verify.exists():
        drawing=ImageDraw.Draw(profile)
        anchors=json.loads(verify.read_text(encoding="utf-8")).get("grip_projection",{})
        for i,(name,(u,v)) in enumerate(sorted(anchors.items())):
            x,y=profile.width*u,profile.height*v
            sx=88 if i==0 else 560
            sy=y-42 if i==0 else y+42
            color="#"+LINES[line][2]
            drawing.line(((x,y),(sx,sy)),fill=color,width=6)
            drawing.ellipse((x-10,y-10,x+10,y+10),fill=color,outline="#283139",width=3)
            text="SUPPORT" if name.startswith("Left") else "MAIN GRIP"
            drawing.text((sx,sy-25),text,font=font(25,"bold"),fill="#EEF4F5",stroke_width=3,
                         stroke_fill="#1B232B",anchor="mt")
    b.panel(861,199,433,223,"PROFILE / GRIP ANCHORS",profile)
    b.panel(1308,199,444,223,"UNDER / REVERSE",view("right"))
    b.panel(861,434,433,223,"FOLD / WINDUP",view("folded"))
    b.panel(1308,434,444,223,"INSPECT / ARTICULATED",view("detail"))
    for i,(label,key) in enumerate(POSES):
        x=48+i%3*573
        y=680+i//3*168
        b.panel(x,y,558,156,f"{label} / F{a['motion'][key]:03d}",view(key),"fp")
    b.note("GRIP AND EFFECT GUIDE",NOTES[item],48,1192,800,19)
    b.note("STOCK VISUAL CONTACT CUES", "Light A 0.168 s   •   Light B 0.231 s   •   Heavy 0.378 s   •   24 fps",970,1192,780,19)


def charm_board(b,line,item,a,root):
    view=lambda k: root/"views"/(k+".png")
    _,hero=next(k for k in HEROES if k[0]==line)
    gun=latest(line,hero).parent
    mount=gun/"views/mount.png"
    if not mount.exists():
        mount=gun/"views/held.png"
    held=png(gun/"views/held.png")
    close=png(mount)
    combined=Image.new("RGBA",(810,284),"#535F69")
    player=ImageOps.contain(held,(451,263),Image.Resampling.LANCZOS)
    close=ImageOps.contain(close,(350,258),Image.Resampling.LANCZOS)
    combined.alpha_composite(player,(0,13))
    combined.alpha_composite(close,(461,13))
    draw=ImageDraw.Draw(combined)
    draw.line((449,11,449,271),fill="#74838C",width=2)
    draw.text((14,15),"PLAYER CAMERA",font=font(16,"mono"),fill="#D9E1E4")
    draw.text((472,15),"SWING EXTREME",font=font(16,"mono"),fill="#D9E1E4")
    b.panel(48,199,859,640,"THREE-QUARTER / REST",view("hero"))
    b.panel(925,199,827,320,"MOUNTED / "+hero.upper(),combined,"fp")
    b.panel(925,534,827,305,"ACTIVE / F035",view("active"),"detail")
    small=png(view("side"))
    icon=ImageOps.contain(small.crop(small.getbbox()),(64,64),Image.Resampling.LANCZOS)
    icon_panel=Image.new("RGBA",(300,159),(0,0,0,0))
    icon_panel.alpha_composite(icon,((300-icon.width)//2,(159-icon.height)//2))
    b.panel(48,858,416,272,"REWARD ICON / 64 PX SOURCE",icon_panel,"detail")
    b.panel(478,858,605,272,"REVERSE / MOUNT LOOP",view("right"))
    study=VAULT/line/"refs"/(item+"_finish_study_v01.png")
    b.panel(1097,858,655,272,"FINISH STUDY / IMAGEGEN" if study.exists() else "SETTLE / F061",
            study if study.exists() else view("settled"),"detail" if study.exists() else "isolated")
    b.note("MOUNT AND FINISH",NOTES[item],48,1161,800)
    b.swatches(line,982,1174)


def make_video(root,a):
    frames=list(sorted((root/"frames").glob("*.png")))
    if not frames:
        return None
    line,item=a["line"],a["item"]
    title=NAMES.get(item,item).upper()
    converted=[]
    motion=a["motion"]
    if (line,item) in MELEES:
        names=[(1,"READY"),(5,"EQUIP"),(24,"IDLE"),(48,"CARRY"),(68,"LIGHT A"),(85,"LIGHT B"),
               (104,"HEAVY"),(129,"INSPECT"),(178,"RECOVERY"),(204,"CANCEL"),(219,"REST")]
    elif (line,item) in CHARMS:
        names=[(1,"REST"),(9,"ACTIVATE"),(35,"EXTREME SWING"),(50,"RECOVER"),(61,"REST")]
    else:
        names=[(1,"REST"),(motion["start"],"RELOAD"),(motion["commit"],"COMMIT"),
               (motion["ready"],"READY"),(motion["inspect"]-25,"INSPECT"),(motion["cancel"]-6,"INTERRUPT"),(motion["cancel"],"REST")]
        if motion.get("charm_extremes"):
            names.extend((f,"CHARM CLEARANCE") for f in motion["charm_extremes"])
    for path in frames:
        frame=int(path.stem)
        im=png(path)
        image=Image.new("RGB",(im.width,im.height+39),"#111820")
        plate=Image.new("RGBA",im.size,"#576570")
        plate.alpha_composite(im)
        image.paste(plate,(0,35))
        d=ImageDraw.Draw(image)
        state=next(name for f,name in reversed(names) if f<=frame)
        d.text((10,9),title,font=font(14,"mono"),fill="#D7E6ED")
        d.text((im.width-10,9),f"{state} / {frame:03d}",font=font(14,"mono"),fill="#"+LINES[line][2],anchor="ra")
        converted.append(image.quantize(colors=112))
    name=root/(item+"_motion_"+a["version"]+".gif")
    durations=[120 if i%2==0 else 130 for i in range(len(converted))]
    converted[0].save(name,save_all=True,append_images=converted[1:],duration=durations,loop=0,disposal=2)
    with Image.open(name) as result:
        assert result.n_frames>1
    return name


def ledger_link(file, label):
    import os
    from urllib.parse import quote
    return f"[{label}]({quote(Path(os.path.relpath(file,VAULT)).as_posix(),safe='/')})"


def record(line,item,version,destination,review,video):
    text=LEDGER.read_text(encoding="utf-8-sig")
    stage=f"**{line} {item} {version} — rendered.**"
    if stage in text:
        return
    if (line,item)==("Spindrift","Vandal"):
        pending="Compare v02 against v01 collar and hand-pose findings."
    else:
        pending="Visual review and fit findings pending."
    links=[ledger_link(destination,"Sheet"),ledger_link(review,"Render and timing record")]
    if video:
        links.extend([ledger_link(video,"Motion preview"),ledger_link(next(review.parent.glob("*.blend")),"Blender file")])
    text+=f"\n- {stage} {' · '.join(links)}. {pending}\n"
    text=re.sub(r"(?<=## Current checkpoint\n\n)\*\*[^\n]*\*\*\.",
                f"**{line} / {item} / {version} visual review.**",text,count=1)
    LEDGER.write_text(text,encoding="utf-8")


def make_board(line,item):
    key=(line,item)
    review=latest(line,item)
    a=json.loads(review.read_text(encoding="utf-8"))
    root=review.parent
    renderer,typ=(gun_board,"Gun concept") if key in GUNS else ((melee_board,"Melee concept") if key in MELEES else (charm_board,"Charm concept"))
    board=Board(line,item,a["version"],typ)
    renderer(board,line,item,a,root)
    folder=VAULT/line/"out"
    folder.mkdir(parents=True,exist_ok=True)
    dest=folder/(item+"_concept_"+a["version"]+".png")
    board.img.save(dest,optimize=True)
    with Image.open(dest) as reopened:
        reopened.verify()
    video=make_video(root,a)
    record(line,item,a["version"],dest,review,video)
    print(str(dest),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("line")
    parser.add_argument("item")
    args=parser.parse_args()
    make_board(args.line,args.item)
