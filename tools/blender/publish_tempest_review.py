"""Compose the clean-model review boards and encode the offline action rehearsal."""
import argparse
from pathlib import Path
import json
import math
import re
import subprocess

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art-source/weapons/Skins/TempestStrike/Vandal"
VAULT = ROOT / "vault/02 Art/Skins/TempestStrike"
OUT = VAULT / "out"
FONTS = Path("C:/Windows/Fonts")
INK = (232, 239, 246)
MUTED = (162, 179, 195)
TEAL = (151, 202, 207)
LINE = (58, 79, 95)


def font(size, family="bahnschrift"):
    return ImageFont.truetype(str(FONTS / (family + ".ttf")), size)


def backdrop(size, center=(.47, .38), brighter=False):
    w, h = size
    small = (144, 144)
    canvas = Image.new("RGB", small)
    data = []
    bright = (62, 79, 94) if brighter else (40, 57, 72)
    base = (17, 25, 34) if brighter else (13, 21, 31)
    for y in range(small[1]):
        for x in range(small[0]):
            distance = math.hypot((x/small[0]-center[0])*.92, (y/small[1]-center[1])*1.33)
            light = max(0, 1-distance*1.55)**1.22
            data.append(tuple(round(a+(b-a)*light) for a,b in zip(base,bright)))
    canvas.putdata(data)
    return canvas.resize((w,h),Image.Resampling.BICUBIC)


def load_png(folder,name):
    with Image.open(folder/(name+".png")) as image:
        return image.convert("RGBA")


def place(canvas, asset, rect, crop=True):
    x,y,w,h = rect
    if crop:
        box=asset.getbbox()
        if box:
            asset=asset.crop(box)
    asset=ImageOps.contain(asset,(w,h),method=Image.Resampling.LANCZOS)
    canvas.paste(asset,(x+(w-asset.width)//2,y+(h-asset.height)//2),asset)


def heading(canvas, title, subtitle, right):
    draw=ImageDraw.Draw(canvas)
    draw.text((72,52),title,font=font(74),fill=INK)
    draw.text((76,141),subtitle,font=font(23,"segoeui"),fill=MUTED)
    draw.text((canvas.width-75,72),right,font=font(21),fill=TEAL,anchor="ra")
    draw.line((74,184,canvas.width-74,184),fill=LINE,width=1)


def tile(canvas, folder, name, label, rect, crop=True):
    x,y,w,h=rect
    panel=backdrop((w,h),center=(.5,.49),brighter=True)
    draw=ImageDraw.Draw(panel)
    draw.rectangle((0,0,w-1,h-1),outline=LINE,width=1)
    draw.text((22,16),label,font=font(20),fill=INK)
    place(panel,load_png(folder,name),(18,49,w-36,h-67),crop=crop)
    canvas.paste(panel,(x,y))


def sheets(version):
    folder = ART/version/"review"
    OUT.mkdir(exist_ok=True)
    measures=json.loads((folder/"geometry_and_rig.json").read_text(encoding="utf-8"))
    span=measures["dimensions"]["storm_shadow"]
    length=span[1][0]-span[0][0]
    tris=measures["geometry"]["opaque_triangles"]

    hero=backdrop((1800,900),center=(.44,.44),brighter=True)
    heading(hero,"TEMPEST-STRIKE","Vandal  /  Storm Shadow",f"GLITCHED GAUNTLET   ·   {version.upper()}")
    place(hero,load_png(folder,"hero"),(75,206,1650,564))
    draw=ImageDraw.Draw(hero)
    draw.line((74,802,1726,802),fill=LINE,width=1)
    draw.text((76,826),"CLEAN MODEL",font=font(21),fill=TEAL)
    draw.text((1724,826),f"{length:.3f} STUDS   /   {tris:,} EVALUATED TRIANGLES",
              font=font(21),fill=MUTED,anchor="ra")
    hero.save(OUT/"Storm_Shadow.png",optimize=True)

    board=backdrop((1920,2520))
    heading(board,"TEMPEST-STRIKE","Vandal  /  Storm Shadow  /  Blender model review",
            f"GLITCHED GAUNTLET   ·   {version.upper()}")
    place(board,load_png(folder,"hero"),(82,219,1756,508))
    draw=ImageDraw.Draw(board)
    draw.text((76,754),"FORM AND FINISH",font=font(25),fill=TEAL)
    for item in [
        ("side","Player side",(74,809,874,264)),
        ("opposite","Far side",(972,809,874,264)),
        ("top","Top",(74,1093,874,245)),
        ("underside","Underside",(972,1093,874,245)),
        ("rearquarter","Rear three-quarter",(74,1358,874,346)),
        ("hip","Stock held camera",(972,1358,437,346),False),
        ("ads","Stock aim camera",(1425,1358,421,346),False),
        ("muzzle","Ported muzzle",(74,1755,430,304)),
        ("grip","Wrapped grip",(521,1755,430,304)),
        ("mag","Magazine and heel",(969,1755,430,304)),
        ("sight","Open crescent sight",(1416,1755,430,304)),
        ("front","Muzzle axis",(74,2079,430,294)),
        ("stock","Stock cheek and strut",(521,2079,430,294)),
        ("back","Butt and sight alignment",(969,2079,430,294)),
        ("charm","Stock buddy mount",(1416,2079,430,294)),
    ]:
        tile(board,folder,*item)
    draw.text((76,1713),"DETAILS AND CONTACT SURFACES",font=font(25),fill=TEAL)
    draw.line((74,2410,1846,2410),fill=LINE,width=1)
    draw.text((76,2438),f"{length:.3f} STUDS   /   {tris:,} EVALUATED TRIANGLES   /   NO VFX GEOMETRY",
              font=font(20),fill=MUTED)
    board.save(OUT/"Vandal_v01.png",optimize=True)

    compare=backdrop((1920,1900))
    heading(compare,"FORM COMPARISON","Stock alignment, aiming aperture and original Tempest-Strike brief",version.upper())
    tile(compare,folder,"stock_side","Remaster V2 stock side",(74,220,1772,360),False)
    tile(compare,folder,"side","Storm Shadow side",(74,599,1772,360),False)
    stock_mask=load_png(folder,"stock_side").getchannel("A")
    skin_mask=load_png(folder,"side").getchannel("A")
    overlay=Image.new("RGBA",stock_mask.size)
    common=ImageChops.multiply(stock_mask,skin_mask)
    stock_only=ImageChops.subtract(stock_mask,skin_mask)
    skin_only=ImageChops.subtract(skin_mask,stock_mask)
    for mask,color in [(common,(119,142,160)),(stock_only,(238,188,140)),(skin_only,(157,230,230))]:
        overlay.paste(color+(255,),(0,0),mask)
    panel=backdrop((1772,307),brighter=True)
    line=ImageDraw.Draw(panel)
    line.text((22,15),"Profile overlay",font=font(20),fill=INK)
    line.text((1748,15),"Stock only  /  warm     Storm Shadow only  /  cool",font=font(19),fill=MUTED,anchor="ra")
    place(panel,overlay,(16,50,1740,247))
    compare.paste(panel,(74,978))
    tile(compare,folder,"stock_ads","Stock ADS",(74,1305,563,394),False)
    tile(compare,folder,"ads","Storm Shadow ADS",(652,1305,563,394),False)
    ref=VAULT/"refs/style/Tempest-Strike Vandal Reference.png"
    with Image.open(ref) as original:
        thumb=original.convert("RGBA")
    frame=backdrop((616,394),brighter=True)
    text=ImageDraw.Draw(frame)
    text.text((21,16),"Owner concept",font=font(20),fill=INK)
    place(frame,thumb,(16,52,584,319),crop=False)
    compare.paste(frame,(1230,1305))
    draw=ImageDraw.Draw(compare)
    draw.line((74,1742,1846,1742),fill=LINE,width=1)
    draw.text((76,1771),"Matched profile uses the same scale, origin and camera. Warm and cool edges show the shape changes.",
              font=font(22,"segoeui"),fill=MUTED)
    draw.text((76,1812),"The exposed barrel, rear stock opening and buddy mount follow the Remaster V2 fixture.",
              font=font(22,"segoeui"),fill=MUTED)
    compare.save(OUT/"Stock_and_concept_comparison.png",optimize=True)


def overlay_style(version, source):
    """Align the supplied style reference in one plane by muzzle and length."""
    folder=ART/version/"review"
    OUT.mkdir(exist_ok=True)
    with Image.open(source) as raw:
        reference=raw.convert("RGB").resize((1920,1080),Image.Resampling.LANCZOS)
    plate=Image.blend(reference,Image.new("RGB",reference.size,(16,28,41)),.30)
    for name,ink in [("stock_side",(253,186,118)),("side",(123,232,229))]:
        mask=load_png(folder,name).getchannel("A")
        left,_,right,_=mask.getbbox()
        scale=(1831-80)/(right-left)
        muzzle_z=.285
        axis_px=mask.height*.5+(.104-muzzle_z)*mask.width/4.25
        x0=round(80-left*scale)
        y0=round(384-axis_px*scale)
        resized=mask.resize((round(mask.width*scale),round(mask.height*scale)),
                             Image.Resampling.LANCZOS)
        projected=Image.new("L",plate.size)
        projected.paste(resized,(x0,y0))
        contour=ImageChops.subtract(projected.filter(ImageFilter.MaxFilter(5)),
                                    projected.filter(ImageFilter.MinFilter(5)))
        plate.paste(ink,(0,0,*plate.size),contour)
    canvas=backdrop((1920,1220),brighter=True)
    heading(canvas,"PROFILE STUDY","Owner-supplied Kuronami reference with stock and Storm Shadow outlines",version.upper())
    canvas.paste(plate.crop((0,159,1920,1034)),(0,195))
    footer=ImageDraw.Draw(canvas)
    footer.text((75,1103),"STOCK VANDAL",font=font(21),fill=(253,186,118))
    footer.text((315,1103),"STORM SHADOW",font=font(21),fill=(123,232,229))
    footer.text((76,1148),"Normalized to total length and muzzle height. The Blender stock mesh governs the installation fit.",
                font=font(21,"segoeui"),fill=MUTED)
    canvas.save(OUT/"Kuronami_profile_overlay.png",optimize=True)


def motion(version):
    import imageio_ffmpeg

    review=ART/version/"review"
    folder=review/"motion_frames"
    timeline=json.loads((review/"action_timeline.json").read_text(encoding="utf-8"))
    first=timeline["frames"]["Draw"]
    last=timeline["frames"]["End"]
    fps=timeline["fps"]
    ready=review/"motion_composited"
    ready.mkdir(exist_ok=True)
    title=font(24)
    secondary=font(13)
    canvas=backdrop((864,486),center=(.49,.31),brighter=True)
    sections=[(9,"DRAW"),(39,"READY"),(63,"FIRE RESPONSE"),(83,"TACTICAL RELOAD"),
              (175,"EMPTY RELOAD"),(275,"360° INSPECT"),(429,"INSPECT INTERRUPT"),(468,"ADS RETURN")]
    for i in range(first,last+1):
        file=folder/f"frame_{i:04}.png"
        with Image.open(file) as image:
            image.verify()
        frame=load_png(folder,f"frame_{i:04}")
        if frame.size!=(864,486):
            raise ValueError(f"Unexpected dimensions in {file}")
        proof=canvas.copy()
        proof.paste(frame,(0,0),frame)
        draw=ImageDraw.Draw(proof)
        label=next(name for t,name in reversed(sections) if t<=i)
        draw.text((19,15),label,font=title,fill=INK)
        draw.text((846,18),"TEMPEST-STRIKE   /   MECHANICAL REHEARSAL",font=secondary,fill=TEAL,anchor="ra")
        draw.line((19,462,845,462),fill=LINE,width=2)
        draw.line((19,462,19+826*(i-first)/(last-first),462),fill=TEAL,width=2)
        proof.save(ready/f"frame_{i:04}.png",compress_level=3)

    exe=imageio_ffmpeg.get_ffmpeg_exe()
    target=OUT/"Storm_Shadow_actions.mp4"
    cmd=[exe,"-y","-hide_banner","-loglevel","error","-framerate",str(fps),"-start_number",str(first),
         "-i",str(ready/"frame_%04d.png"),"-frames:v",str(last-first+1),"-c:v","libx264",
         "-preset","medium","-crf","18","-pix_fmt","yuv420p","-color_primaries","bt709",
         "-color_trc","bt709","-colorspace","bt709","-movflags","+faststart",str(target)]
    subprocess.run(cmd,check=True)
    decoded=subprocess.run([exe,"-hide_banner","-i",str(target),"-map","0:v:0","-f","null","-"],
                           capture_output=True,text=True,check=True)
    line=next(line for line in decoded.stderr.splitlines() if "Video: h264" in line)
    counts=re.findall(r"frame=\s*(\d+)",decoded.stderr)
    if not counts or int(counts[-1])!=last-first+1:
        raise ValueError("Decoded frame count differs from the expected timeline")
    (review/"motion_decode.txt").write_text(line.strip()+f"\n{counts[-1]} native frames decoded.\n",
                                          encoding="utf-8")


parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("stage",choices=["sheets","motion","overlay"])
parser.add_argument("version")
parser.add_argument("--reference",type=Path)
args=parser.parse_args()
if args.stage=="overlay":
    if not args.reference:
        parser.error("--reference is required for the overlay")
    overlay_style(args.version,args.reference)
else:
    (sheets if args.stage=="sheets" else motion)(args.version)
