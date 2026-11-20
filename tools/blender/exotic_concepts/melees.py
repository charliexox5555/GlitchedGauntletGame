"""Three original melee silhouettes, pivot layouts, and first-person choreographies."""

import math

import bpy
from mathutils import Vector

from scene import armature, beam, bind, collection, cut, glove, locator, loft, material, marker, mesh, pose, prism


def arc_band(col,name,center,angles,radius,width,depth,mat,y=0):
    cx,cz=center
    stations=[]
    for i,a in enumerate(angles):
        a=math.radians(a)
        edge=width*(.22 if i in (0,len(angles)-1) else 1)
        stations.append([(cx+math.cos(a)*r, y+d, cz+math.sin(a)*r) for r,d in (
            (radius-edge*.5,-depth*.3),(radius-edge*.21,-depth*.5),(radius+edge*.32,-depth*.46),
            (radius+edge*.5,0),(radius+edge*.30,depth*.46),(radius-edge*.23,depth*.5))])
    faces=[tuple(range(6)),tuple(range((len(stations)-1)*6,len(stations)*6))]
    for i in range(len(stations)-1):
        a,b=i*6,(i+1)*6
        for j in range(6):
            k=(j+1)%6
            faces.append((a+j,a+k,b+k,b+j))
    return mesh(col,name,[v for ring in stations for v in ring],faces,mat)


def sounding_arc(col,p):
    dark,pale,lit,accent,smoke=p
    root,lower,upper,ribbon,bead="Grip","Lower crescent","Upper crescent","Water ribbon","Inspect bead"
    c=(.255,.466)
    low=[-116,-99,-80,-61,-42,-23,-6,9]
    high=[21,40,59,78,97,116,135,151,163]
    parts={root:[
        beam(col,"Off-center basalt grip",(-.13,0,-.36),(-.04,0,.108),.084,dark,9),
        beam(col,"Coral grip index",(-.108,0,-.27),(-.092,0,-.192),.087,accent,9),
        prism(col,"Socketed torque yoke",[(-.118,.07),(.013,.05),(.22,.185),(.202,.29),(.142,.30),(.048,.172)],-.061,.072,pale,.012)],
        lower:[arc_band(col,"Lower pearl plate",c,low,.41,.107,.13,pale),arc_band(col,"Lower basalt spine",c,low,.437,.032,.143,dark)],
        upper:[arc_band(col,"Upper pearl plate",c,high,.41,.1,.117,pale),arc_band(col,"Upper basalt spine",c,high,.432,.03,.132,dark)],
        ribbon:[arc_band(col,"Tide ribbon",c,[-118,-96,-74,-52,-30,-8,12,34,56,78,100,122,144,163],.341,.032,.04,lit,.019)],
        bead:[loft(col,"Traveling water bead",[(.255,.041,z,r,r) for z,r in [(.779,.008),(.793,.024),(.816,.018),(.83,.004)]],8,lit)]}
    layout=[(root,(-.09,0,-.13),None),(lower,(.151,0,.17),root),(upper,(.475,0,.72),root),
            (ribbon,(c[0],0,c[1]),root),(bead,(c[0],0,c[1]),ribbon)]
    return layout,parts,(-.09,0,-.19),None


def kiln_cleaver(col,p):
    dark,pale,lit,accent,smoke=p
    root,tang,leading,returning,bar="Rear grip","Slab spine","Leading ceramic jaw","Returning ceramic jaw","Heat insert"
    slab=[(-.22,.091),(.146,.112),(.277,.163),(.749,.159),(.994,.235),(.932,.632),(.746,.801),(.346,.828),(.267,.747),(-.19,.686)]
    parts={root:[beam(col,"Rear grip",(-.35,0,-.27),(-.22,0,.32),.102,dark,8),
                 beam(col,"Copper ferrule",(-.258,0,.143),(-.221,0,.306),.11,accent,8),
                 beam(col,"Separate support grip",(.08,0,-.13),(.31,0,.263),.078,dark,8),
                 prism(col,"Forged support bridge",[(-.35,-.12),(-.223,-.224),(.174,-.145),(.224,-.05),(.079,.012),(-.253,-.037)],-.05,.06,smoke,.008)],
        tang:[prism(col,"Clipped iron slab",slab,-.102,.103,dark,.025),
              prism(col,"Copper furnace seat",cut(.22,.832,.3,.65,.054),.091,.122,accent,.009),
              prism(col,"Ceramic rear face",cut(-.119,.824,.245,.688,.088),-.16,-.099,pale,.021),
              prism(col,"Iron heel",[(-.212,.565),(.071,.615),(.245,.716),(.271,.801),(.09,.795),(-.196,.714)],-.114,.118,smoke,.022)],
        leading:[prism(col,"Leading ceramic face",[(.142,.504),(.785,.505),(.897,.547),(.855,.655),(.719,.732),(.238,.711),(.142,.653)],.13,.199,pale,.017)],
        returning:[prism(col,"Returning ceramic face",[(.207,.452),(.767,.454),(.866,.413),(.808,.253),(.735,.225),(.229,.25),(.17,.327)],.128,.197,pale,.019)],
        bar:[prism(col,"Persimmon heat bar",cut(.259,.764,.37,.54,.024),.116,.145,lit,.008)]}
    layout=[(root,(-.29,0,-.12),None),(tang,(-.21,0,.23),root),
            (leading,(.212,.128,.663),tang),(returning,(.229,.127,.269),tang),(bar,(.51,.14,.46),tang)]
    return layout,parts,(-.28,0,-.12),(.157,0,.005)


def patch_tool(col,p):
    dark,pale,lit,accent,smoke=p
    root,core,tip,heel,upper,lower="Offset grip","Nested frame","Leading panel","Trailing panel","Upper handle cheek","Lower handle cheek"
    window=material("Stacklight / Glazed panel","4C7080",.18,.28,.85)
    parts={root:[beam(col,"Ivory offset handle",(-.31,0,-.34),(-.095,0,.09),.088,pale,8),
                 prism(col,"Graphite yoke",[(-.18,-.017),(.048,.014),(.202,.188),(.115,.279),(-.112,.181),(-.201,.094)],-.088,.091,dark,.016)],
        core:[],tip:[],heel:[],
        upper:[prism(col,"Ivory slider upper",cut(-.198,.072,.111,.208,.027),.067,.106,pale,.009)],
        lower:[prism(col,"Ivory slider lower",cut(-.247,.028,.006,.103,.021),.069,.108,pale,.009)]}
    panels=[(core,[(.027,.18),(.43,.224),(.733,.46),(.727,.669),(.63,.752),(.454,.687),(.044,.342)],0),
            (tip,[(.195,.273),(.528,.294),(.854,.536),(.93,.765),(.817,.897),(.635,.825),(.259,.464)],.058),
            (heel,[(-.014,.143),(.35,.138),(.67,.316),(.726,.533),(.608,.625),(.456,.557),(.041,.29)],-.055)]
    for label,outline,y in panels:
        center=sum((Vector(v) for v in outline),Vector((0,0)))/len(outline)
        inside=[Vector(v)*.83+center*.17 for v in outline]
        insert=[Vector(v)*.851+center*.149 for v in outline]
        n=len(outline)
        rings=((outline,y-.039),(outline,y+.027),(inside,y+.043),(inside,y-.031))
        verts=[(x,d,z) for ring,d in rings for x,z in ring]
        faces=[]
        for a,b in ((0,n),(n,2*n),(2*n,3*n),(3*n,0)):
            for i in range(n):
                j=(i+1)%n
                faces.append((a+i,a+j,b+j,b+i))
        parts[label].append(mesh(col,label+" graphite rim",verts,faces,dark))
        parts[label].append(prism(col,label+" smoked-blue insert",insert,y-.02,y+.026,window,.006))
        parts[label].append(prism(col,label+" polymer heel",cut(.126,.298,.21,.272,.013),y+.037,y+.056,pale,.004))
    layout=[(root,(-.22,0,-.17),None),(core,(.085,0,.197),root),(tip,(.172,0,.289),core),
            (heel,(.069,0,.181),core),(upper,(-.049,.07,.16),root),(lower,(-.117,.07,.054),root)]
    for i in range(3):
        label="Diagnostic cell "+str(i+1)
        parts[label]=[prism(col,label,cut(-.162+i*.065,-.113+i*.065,.097,.132,.006),.075,.111,lit,.002)]
        layout.append((label,(-.137+i*.065,.106,.115),root))
    return layout,parts,(-.217,0,-.17),None


def key_pose(rig,frame,delta=(0,0,0),spin=(0,0,0),channels=None):
    root=rig.pose.bones[0]
    pose(root,frame,xyz=delta,angles=spin)
    channels=channels or {}
    for b in list(rig.pose.bones)[1:]:
        xyz,rot,scale=channels.get(b.name,((0,0,0),(0,0,0),(1,1,1)))
        pose(b,frame,xyz=xyz,angles=rot,scale=scale)


def section_keys(item):
    # Each three-tuple is frame, root position in rig coordinates, then orientation in degrees.
    # Contact offsets at 24 fps follow the stock visual hit markers (4, 6 and 9 frames).
    if item=="SoundingArc":
        return [
            (5,(-.20,-.20,-.48),(-30,6,-21),"fold"),(12,(-.04,.03,-.18),(12,-18,24),"fold"),
            (18,(.04,.02,.04),(6,7,-8),"gather"),(23,(0,0,0),(0,0,0),"rest"),
            (34,(.018,-.023,.021),(-2,4,4),"drift"),(45,(0,0,0),(0,0,0),"rest"),
            (55,(-.11,-.08,-.13),(-19,8,-16),"fold"),(66,(0,0,0),(0,0,0),"rest"),
            (68,(.06,-.04,-.16),(-19,-23,14),"fold"),(72,(.18,-.37,.22),(48,16,21),"gather"),
            (76,(.06,-.57,.12),(72,34,28),"trail"),(82,(0,0,0),(0,0,0),"rest"),
            (85,(.09,-.53,.15),(54,34,18),"trail"),(91,(.22,-.18,-.045),(-36,-35,-27),"gather"),
            (94,(.19,.14,-.13),(-57,-24,-43),"trail"),(99,(0,0,0),(0,0,0),"rest"),
            (104,(-.24,.04,-.035),(-24,-20,-31),"gather"),(112,(.03,-.125,.145),(16,50,-10),"gather"),
            (113,(.46,-.18,-.075),(24,18,23),"gather"),(118,(.21,-.22,-.17),(35,-19,-25),"trail"),
            (126,(0,0,0),(0,0,0),"rest"),(139,(-.01,-.27,.064),(15,39,46),"show"),
            (150,(.02,-.37,.115),(20,58,55),"bead"),(162,(.03,-.27,.056),(10,39,42),"drain"),
            (174,(0,0,0),(0,0,0),"rest"),(182,(.07,-.22,-.12),(37,-14,17),"trail"),
            (195,(0,0,0),(0,0,0),"rest"),(204,(-.17,.021,-.16),(-13,22,32),"fold"),
            (211,(.02,-.05,-.019),(2,8,3),"drain"),(219,(0,0,0),(0,0,0),"rest")]
    if item=="KilnCleaver":
        return [
            (5,(-.22,.04,-.62),(-16,-20,-20),"rest"),(11,(-.18,.03,-.39),(-4,-18,-14),"jawA"),
            (19,(.025,-.1,.007),(11,7,20),"jawB"),(23,(0,0,0),(0,0,0),"rest"),
            (33,(-.02,.024,-.046),(-4,6,-3),"rest"),(45,(0,0,0),(0,0,0),"rest"),
            (56,(-.16,.08,-.215),(-19,-8,-41),"rest"),(66,(0,0,0),(0,0,0),"rest"),
            (68,(-.13,.037,.153),(-11,8,-13),"rest"),(72,(.19,-.35,-.07),(46,-24,40),"jawA"),
            (76,(.11,-.49,-.173),(62,-25,58),"rest"),(82,(0,0,0),(0,0,0),"rest"),
            (85,(.01,-.47,-.18),(55,-31,53),"rest"),(91,(.18,-.17,.084),(-14,42,-31),"jawB"),
            (95,(.14,.1,.24),(-38,44,-52),"rest"),(100,(0,0,0),(0,0,0),"rest"),
            (104,(-.11,-.08,.13),(-5,19,7),"rest"),(111,(-.37,-.11,.48),(24,44,-28),"rest"),
            (113,(.31,-.17,.025),(36,-47,24),"fire"),(117,(.25,-.27,-.26),(56,-32,35),"jawB"),
            (126,(0,0,0),(0,0,0),"rest"),(139,(-.04,-.31,.11),(26,33,63),"jawA"),
            (150,(-.02,-.34,.13),(23,49,73),"fire"),(164,(0,-.21,.071),(11,26,48),"jawB"),
            (174,(0,0,0),(0,0,0),"rest"),(182,(.01,-.2,-.19),(27,-23,22),"rest"),
            (195,(0,0,0),(0,0,0),"rest"),(203,(-.26,-.055,.205),(11,45,-28),"jawA"),
            (211,(.025,-.03,-.055),(4,-4,5),"rest"),(219,(0,0,0),(0,0,0),"rest")]
    return [
        (5,(-.22,.04,-.45),(-18,-29,-24),"nest"),(12,(-.02,-.126,-.14),(17,13,48),"tick1"),
        (16,(.12,-.02,.048),(10,11,21),"tick2"),(20,(.02,-.015,.026),(-5,0,6),"spread"),(23,(0,0,0),(0,0,0),"rest"),
        (34,(.024,.018,.026),(3,5,-8),"rest"),(45,(0,0,0),(0,0,0),"rest"),
        (56,(-.12,.08,-.17),(-16,-11,-34),"tick2"),(66,(0,0,0),(0,0,0),"rest"),
        (68,(-.07,.129,.04),(-36,0,-15),"tick1"),(72,(.17,-.44,-.035),(37,14,53),"spread"),
        (74,(.08,-.5,-.10),(59,-13,71),"tick2"),(82,(0,0,0),(0,0,0),"rest"),
        (85,(.07,-.48,-.03),(57,22,53),"nest"),(91,(.23,-.153,.126),(-32,-12,-22),"tick2"),
        (94,(.06,.113,.081),(-47,31,-54),"spread"),(99,(0,0,0),(0,0,0),"rest"),
        (104,(-.22,-.01,.05),(-12,-27,-41),"nest"),(111,(-.18,-.045,.27),(8,18,-35),"nest"),
        (113,(.43,-.19,-.015),(25,-38,24),"spread"),(117,(.14,-.31,-.11),(43,-14,37),"spread"),
        (126,(0,0,0),(0,0,0),"rest"),(138,(-.011,-.295,.12),(30,32,63),"diagStart"),
        (143,(.025,-.327,.141),(29,43,69),"diagFirst"),(146,(.036,-.35,.15),(29,51,72),"diagMax"),
        (149,(.042,-.35,.153),(29,51,72),"diagFinal"),(153,(.056,-.35,.154),(28,50,71),"diagOff"),
        (164,(.018,-.215,.071),(18,27,43),"diagStart"),(174,(0,0,0),(0,0,0),"rest"),
        (182,(.08,-.28,-.10),(32,-16,23),"tick2"),(195,(0,0,0),(0,0,0),"rest"),
        (204,(-.17,-.08,.19),(11,-21,44),"nest"),(212,(.038,-.035,-.027),(2,4,4),"tick2"),
        (219,(0,0,0),(0,0,0),"rest")]


def articulation(item,state):
    def move(xyz=(0,0,0),rot=(0,0,0),s=(1,1,1)):
        return xyz,rot,s
    if item=="SoundingArc":
        amount={"fold":1,"gather":.34,"trail":-.15,"drift":-.055}.get(state,0)
        active={"fold":.025,"gather":1.06,"drain":.19,"trail":1.02}.get(state,1)
        bead_angle={"show":-48,"bead":-156,"drain":-220}.get(state,0)
        return {"Lower crescent":move((-.19*amount,.04*amount,.035*amount),(0,-32*amount,8*amount)),
                "Upper crescent":move((-.28*amount,-.075*amount,-.31*amount),(0,77*amount,3*amount)),
                "Water ribbon":move(s=(active,)*3),"Inspect bead":move(rot=(0,bead_angle,0),s=(1,)*3 if bead_angle else (.002,)*3)}
    if item=="KilnCleaver":
        top={"jawA":30,"jawB":13,"fire":52}.get(state,0)
        bottom={"jawA":3,"jawB":36,"fire":48}.get(state,0)
        return {"Leading ceramic jaw":move(rot=(top,0,0)),"Returning ceramic jaw":move(rot=(-bottom,0,0)),
                "Heat insert":move(xyz=(.025 if top else 0,.047 if state=="fire" else 0,0))}
    spread={"nest":12,"tick1":5,"tick2":-8,"spread":-30}.get(state,-18)
    cheeks=.072 if state.startswith("diag") else 0
    indicators={"diagFirst":(1,.12,.12),"diagMax":(.4,1,.12),"diagFinal":(.12,.4,1),
                "diagOff":(.12,.12,.12)}.get(state,(.56,.12,.12))
    return {"Leading panel":move((.002,0,-.05 if state=="nest" else 0),(0,spread,0)),
            "Trailing panel":move((.038 if state=="nest" else 0,0,0),(0,-spread*.74,0)),
            "Upper handle cheek":move((0,.024 if cheeks else 0,cheeks)),
            "Lower handle cheek":move((0,.023 if cheeks else 0,-cheeks)),
            **{"Diagnostic cell "+str(i):move(s=(value,)*3) for i,value in enumerate(indicators,1)}}


def build_melee(sc,col,item,p):
    build={"SoundingArc":sounding_arc,"KilnCleaver":kiln_cleaver,"PatchTool":patch_tool}[item]
    layout,parts,right,left=build(col,p)
    rig=armature(col,item+" | First-person rig",layout)
    for bone,groups in parts.items():
        for obj in groups:
            bind(obj,rig,bone)
    bind(locator(col,"Right grip anchor",right),rig,layout[0][0])
    hand=collection(sc,"EXOTIC | First-person hand pose proxies")
    for ob in glove(hand,"Strong hand",right,False,(-.68,-.12,-.56),1.17):
        bind(ob,rig,layout[0][0])
    if left:
        bind(locator(col,"Left support grip anchor",left),rig,layout[0][0])
        for ob in glove(hand,"Support hand",left,True,(-.42,.25,-.48),1.15):
            bind(ob,rig,layout[0][0])
    else:
        offhand=(-.044,.55,-.18)
        stand=locator(hand,"Free-hand pose",offhand)
        for ob in glove(hand,"Free hand",offhand,True,(-.77,.76,-.57),1.03):
            bind(ob,stand)
        for f, xyz, rot in [(1,offhand,(0,0,0)),(123,offhand,(0,0,0)),
                            (138,(.055,.4,.056),(18,-25,-25)),(153,(.17,.35,.102),(25,-34,-34)),
                            (172,offhand,(0,0,0)),(219,offhand,(0,0,0))]:
            pose(stand,f,xyz,rot)
    key_pose(rig,1,channels=articulation(item,"rest"))
    for f,delta,rotation,state in section_keys(item):
        key_pose(rig,f,delta,rotation,articulation(item,state))
    rig.animation_data.action.name=item+" | Original first-person reel"
    rig.animation_data.action.use_fake_user=True
    for label,f in [("REST",1),("EQUIP",5),("EQUIP READY",23),("IDLE",24),("CARRY",48),
                    ("LIGHT A",68),("LIGHT A CONTACT",72),("LIGHT B",85),("LIGHT B CONTACT",91),
                    ("HEAVY",104),("HEAVY CONTACT",113),("INSPECT",129),("RECOVERY",178),
                    ("CANCEL",204),("CANCEL REST",219)]:
        marker(sc,label,f)
    sc.frame_start,sc.frame_end=1,220
    return rig
