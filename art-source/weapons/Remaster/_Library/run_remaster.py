"""Resume-safe local orchestration. All Blender edits go through its MCP addon."""
from pathlib import Path
import json, sys, textwrap, time
from PIL import Image, ImageDraw, ImageFont
from mcp_client import execute
BASE=Path(__file__).resolve().parent.parent
ROOT=BASE.parents[2]
SCRIPT=str(BASE/'_Library/remaster.py').replace('\\','/')
ORDER=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost','Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
def font(size):
    return ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size)
def sheet(gun,concept=False):
    folder=BASE/gun
    if concept:
        im=Image.new('RGB',(1600,1150),(38,43,51)); dr=ImageDraw.Draw(im)
        dr.text((32,18),gun.upper()+' / REMASTER CONCEPT',font=font(34),fill=(231,237,242))
        for view,rect in [('hero',(24,100,1000,610)),('side',(24,690,1000,430)),('ads',(1050,100,526,329))]:
            pic=Image.open(folder/('_concept_'+view+'.png')).convert('RGB'); pic.thumbnail(rect[2:])
            im.paste(pic,(rect[0]+(rect[2]-pic.width)//2,rect[1]+(rect[3]-pic.height)//2))
            dr.text((rect[0]+10,rect[1]+10),view.upper(),font=font(20),fill=(222,228,235))
        notes=['ORIGINAL GAME ART','Clean surfaces','Shared slate / polymer / steel','One-segment edge chamfers','Readable silhouette','Compact sight picture','Skin-ready shell surfaces','','Concept source: Blender','ImageGen request rejected','Final model follows this sheet']
        for i,line in enumerate(notes): dr.text((1060,480+i*35),line,font=font(20),fill=(184,201,214))
        im.save(folder/'concept.png')
    else:
        views=['hero','side','top','ads','held','rig','reload_01','reload_02','reload_03']
        im=Image.new('RGB',(1800,1245),(38,43,51)); dr=ImageDraw.Draw(im)
        report=json.load(open(folder/'review.json'))
        dr.text((22,12),f"{gun.upper()}  /  {report['tris']:,} tris  /  {report['sight']}  /  {len(report['clips'])} actions",font=font(27),fill='white')
        for i,view in enumerate(views):
            pic=Image.open(folder/'renders'/f'{view}.png').convert('RGB'); pic.thumbnail((590,370))
            x=(i%3)*600; y=65+(i//3)*390
            im.paste(pic,(x+(600-pic.width)//2,y+20))
            dr.text((x+12,y),view.upper().replace('_',' '),font=font(18),fill=(220,230,239))
        im.save(folder/'renders/review-sheet.png')
def update_results():
    brief=ROOT/'vault/05 Production/Codex Gun Remaster Brief 2026-11-07.md'
    content=brief.read_text(encoding='utf-8-sig'); head='| Gun | Concept | Tris | Sight type | Round | Anims done | Renders | Notes |'
    start=content.index(head); end=content.index('\n## After this',start)
    rows=[head,'|---|---|---|---|---|---|---|---|']
    for gun in ORDER:
        path=BASE/gun/'review.json'
        if not path.exists(): continue
        r=json.load(open(path)); clips=', '.join(r['clips']); clearance=r['eye_clearance']
        sight={'scope35':'3.5× scope','scope25':'2.5× premium scope','notch':'low notch/post','blade':'N/A (knife)'}.get(r['sight'],r['sight'])
        auditpath=BASE/gun/'audit.json'; checked=auditpath.exists() and json.load(open(auditpath))['passed']
        exportpath=BASE/gun/'export-check.json'; exported=exportpath.exists() and json.load(open(exportpath))['passed']
        notes='Blender concept substituted after ImageGen rejection. '
        if checked: notes+='Blender audit passed. '
        if exported: notes+='FBX + animation JSON exported; FBX re-import passed. '
        notes+=f'Eye clearance {clearance:.3f} studs. Studio check pending.'
        rows.append(f"| {gun} | [Blender concept](../../art-source/weapons/Remaster/{gun}/concept.png) | {r['tris']:,} | {sight} | {r['round']} | {clips} | [{r['renders']} + sheet](../../art-source/weapons/Remaster/{gun}/renders/review-sheet.png) | {notes} |")
    brief.write_text(content[:start]+'\n'.join(rows)+'\n'+content[end:],encoding='utf-8')
def style_sheet():
    im=Image.new('RGB',(1800,1450),(38,43,51)); dr=ImageDraw.Draw(im)
    dr.text((32,20),'GLITCHED GAUNTLET / WEAPON REMASTER',font=font(35),fill='white')
    dr.text((32,75),'STYLE PILOT: VANDAL + CLASSIC',font=font(23),fill=(175,200,215))
    for gun,rect in [('Vandal',(20,135,1140,710)),('Classic',(1180,135,600,600))]:
        pic=Image.open(BASE/gun/'renders/hero.png'); pic.thumbnail(rect[2:]); im.paste(pic,(rect[0],rect[1]))
        dr.text((rect[0]+14,rect[1]+14),gun.upper(),font=font(26),fill='white')
    roles={'Body':'414C61','Panel':'73849C','Dark':'19212E','Metal':'7D8995','Grip':'29303D','Accent':'BA9157','Neon':'43C7D1'}
    for i,(role,h) in enumerate(roles.items()):
        x=30+i*250; dr.rounded_rectangle((x,855,x+210,925),10,fill='#'+h)
        dr.text((x,938),role+' / #'+h,font=font(20),fill='white')
    pic=Image.open(BASE/'_Library/_round-library.png'); pic.thumbnail((650,410)); im.paste(pic,(30,1000))
    notes=['ORIGINAL SILHOUETTES / CLEAN SURFACES','1 unit = 1 stud / +X muzzle / +Z up','Shared packed colour and roughness trim','No grime, noise, smudges or random wear','One-segment chamfers / shallow panel breaks','128 px per stud on 2048px skin UV layouts','Named material roles / independent neon geometry','Reference arms remain outside weapon collections','ImageGen rejected weapon concepts; Blender sheets used']
    for i,note in enumerate(notes): dr.text((730,1015+i*40),note,font=font(23),fill=(191,209,222))
    im.save(BASE/'_Library/style-sheet.png')
def call(expr):
    code=f"p={SCRIPT!r}\nexec(compile(open(p,encoding='utf-8').read(),p,'exec'))\nresult={expr}\n"
    result=execute(code)
    if result.get('status')!='ok': raise RuntimeError(json.dumps(result,indent=2))
    return result['result']
if __name__=='__main__':
    guns=sys.argv[1:] or ORDER
    for gun in guns:
        if gun=='library':
            print(json.dumps(call('library()')),flush=True); style_sheet(); continue
        out=BASE/gun
        if not (out/'concept.png').exists():
            print('CONCEPT '+gun,flush=True); print(json.dumps(call(f'concept({gun!r})')),flush=True); sheet(gun,True)
        print('MODEL / TEXTURE / RIG / ANIMATE / RENDER '+gun,flush=True)
        r=call(f'final({gun!r})'); sheet(gun); update_results()
        print(json.dumps({'finished':gun,'tris':r['tris'],'actions':len(r['clips']),'renders':r['renders'],'clearance':r['eye_clearance']}),flush=True)
