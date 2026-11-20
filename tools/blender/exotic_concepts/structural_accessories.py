"""Original buddy mechanisms and melee variants for the measured structural pass."""

from mathutils import Vector
import bpy

from melees import arc_band,articulation,key_pose,section_keys
from scene import armature,beam,bind,camera,collection,cut,framed_camera,glove,locator,loft,marker,mesh,pivot,points,pose,prism,profile_ring


def buddy(col,line,name,palette,origin=(0,0,0),parent=None,bone=None,small=1):
    dark,edge,glow,index,shade=palette
    x,y,z=origin
    def plate(label,outline,near,far,mat,bevel=.002):
        return prism(col,name+" | "+label,[(x+a,z+b) for a,b in outline],y+near,y+far,mat,bevel)
    def rect(label,x0,x1,z0,z1,near,far,mat):
        return plate(label,cut(x0,x1,z0,z1,.009),near,far,mat)
    if line=="Spindrift":
        ring=profile_ring(col,name+" | closed mount",(x,y,z-.015),(.022,.027),.006,.014,dark,10)
    else:
        profile=[(-.027,-.037),(-.028,-.026),(-.009,.009),(.008,.009),(.03,-.028),(.028,-.039)] if line=="Kilnlock" else cut(-.021,.021,-.045,.008,.010)
        center=sum((Vector(p) for p in profile),Vector((0,0)))/len(profile)
        inner=[Vector(p)*.62+center*.38 for p in profile]
        n=len(profile)
        verts=[(x+a,y+dy,z+b) for outline,dy in ((profile,-.009),(profile,.009),(inner,.009),(inner,-.009)) for a,b in outline]
        faces=[(j+i,j+(i+1)%n,k+(i+1)%n,k+i) for j,k in ((0,n),(n,2*n),(2*n,3*n),(3*n,0)) for i in range(n)]
        ring=mesh(col,name+" | closed mount",verts,faces,dark)
    neck=rect("mount seat",-.013,.013,-.069,-.035,-.006,.024,index)
    root=pivot(col,name+" | attachment pivot",origin,[ring,neck],parent,bone)
    root.scale=(small,)*3
    controls=[]
    if line=="Spindrift":
        wings=[[(.008,-.061),(.051,-.079),(.067,-.119),(.043,-.161),(.019,-.182),(.031,-.13),(.022,-.106),(-.016,-.103)],
               [(-.021,-.078),(-.065,-.118),(-.053,-.168),(-.019,-.206),(.006,-.186),(-.027,-.155),(-.042,-.125)]]
        for i,form in enumerate(wings):
            ob=plate("split basalt gimbal jaw "+str(i+1),form,.012,.054,dark,.004)
            bind(ob,root)
        drop=loft(col,name+" | faceted tidal droplet",[(x,y+.026,z+h,u,u*.72) for h,u in [
              (-.169,.012),(-.157,.025),(-.133,.023),(-.097,.004)]],9,shade)
        bind(drop,root)
        frame=profile_ring(col,name+" | pearl gimbal",(x,y+.045,z-.137),(.036,.041),.005,.009,edge,10)
        bind(frame,root)
        bead=rect("single air bead",-.009,.009,-.152,-.135,.046,.057,glow)
        controls.append((pivot(col,name+" | air bead travel",(x,y+.050,z-.144),[bead],root),(0,0,.033),(0,0,0)))
    elif line=="Kilnlock":
        bind(rect("Dark reactor medallion",-.065,.065,-.188,-.055,.001,.034,dark),root)
        bind(rect("Amber reactor seat",-.035,.035,-.151,-.093,.030,.045,index),root)
        bind(rect("Violet enamel core",-.025,.025,-.146,-.097,.042,.051,glow),root)
        for side in (-1,1):
            outline=[(side*.007,-.126),(side*.028,-.143),(side*.025,-.169),
                     (side*.057,-.168),(side*.064,-.129),(side*.047,-.075),(side*.014,-.084)]
            jaw=plate("diagonal reactor petal "+str(side),outline,.043,.069,edge,.004)
            controls.append((pivot(col,name+" | petal pivot "+str(side),(x+side*.046,y+.051,z-.124),[jaw],root),(0,0,0),(0,0,side*55)))
    else:
        bind(rect("Top crossmember tied to the mount seat",-.048,.048,-.085,-.062,.012,.045,dark),root)
        for side in (-1,1):
            ob=plate("open graphite rails "+str(side),[(side*.033,-.071),(side*.059,-.059),(side*.068,-.087),
                (side*.068,-.155),(side*.045,-.18),(side*.036,-.164)],.001,.052,dark,.004)
            bind(ob,root)
        bind(rect("Smoked glass bridge",-.052,.052,-.176,-.144,.02,.049,shade),root)
        bind(rect("Bottom indicator",-.03,.03,-.164,-.151,.047,.056,glow),root)
        cap=rect("Ivory cap",-.047,.047,-.151,-.066,.043,.075,edge)
        bars=[rect("Glyph bar "+str(i),-w,w,z0,z0+.010,.073,.080,dark)
              for i,(w,z0) in enumerate(zip((.029,.021,.013),(-.136,-.115,-.094)),1)]
        controls.append((pivot(col,name+" | cap press",(x,y+.061,z-.109),[cap,*bars],root),(0,-.016,0),(0,0,0)))
    return root,controls


def buddy_key(assembly,frame,amount,twist):
    root,controls=assembly
    pose(root,frame,angles=(root.get("Outboard rest cant",0)+abs(twist)*.25,twist,0))
    for obj,delta,turn in controls:
        if "Rest" not in obj:
            obj["Rest"]=tuple(obj.location)
        pose(obj,frame,Vector(obj["Rest"])+Vector(delta)*amount,tuple(a*amount for a in turn))


def new_melee(col,name,palette):
    dark,edge,glow,index,shade=palette
    if name=="SoundingArc":
        root,lower,upper,flow,bead="Grip","Lower crescent","Upper crescent","Water ribbon","Inspect bead"
        grip=(-.145,0,-.13)
        layout=[(root,grip,None),(lower,(.073,0,.106),root),(upper,(.387,0,.182),root),
                (flow,(.35,0,.154),root),(bead,(.38,0,.16),flow)]
        part={root:[beam(col,"Basalt palm saddle",(-.393,0,-.273),(-.017,0,.091),.074,dark,8),
                    beam(col,"Scarlet grip collar",(-.093,0,.017),(-.034,0,.076),.078,index,8),
                    prism(col,"Pearl saddle fork",[(-.084,-.036),(.068,.038),(.211,.093),(.285,.249),(.173,.22),(.068,.116),(-.028,.12)],-.072,.081,edge,.013)],
              lower:[prism(col,"Lower swept tidal fang",[(.011,.053),(.192,.108),(.572,.04),(1.15,-.156),(.861,.039),(.594,.173),(.509,.246),(.192,.191)],-.04,.048,edge,.014)],
              upper:[prism(col,"Long hooked pearl fang",[(.015,.139),(.322,.28),(.77,.228),(1.281,-.033),(1.025,.248),(.958,.365),(.986,.382),(.84,.362),(.737,.276),(.48,.36),(.236,.329),(.072,.25)],-.071,.067,edge,.018),
                     prism(col,"Stepped basalt spine",[(.059,.161),(.295,.231),(.655,.214),(.812,.15),(.676,.287),(.504,.322),(.244,.301)],-.074,.076,dark,.012)],
              flow:[prism(col,"Tidal guide in the negative slot",[(.13,.123),(.389,.146),(.861,.015),(.902,.033),(.496,.186),(.249,.179)],.015,.09,glow,.003)],
              bead:[loft(col,"Water bead",[(.628,.063,z,r,r*.7) for z,r in [(.094,.004),(.113,.018),(.139,.014),(.149,.003)]],8,glow)]}
        return layout,part,grip,None
    if name=="KilnCleaver":
        root,body,upper,lower,core="Rear grip","Slab spine","Leading ceramic jaw","Returning ceramic jaw","Heat insert"
        grip=(-.27,0,-.09)
        off=(.09,0,.02)
        layout=[(root,grip,None),(body,(-.11,0,.12),root),(upper,(.33,.073,.397),body),
                (lower,(.29,.077,.18),body),(core,(.46,.08,.275),body)]
        part={root:[beam(col,"Ribbed rear grip",(-.45,0,-.255),(-.12,0,.21),.080,dark,8),
                    beam(col,"Forehand saddle",(-.02,0,-.134),(.223,0,.179),.067,dark,8),
                    beam(col,"Amber socket heel",(-.147,0,.118),(-.099,0,.203),.086,index,8)],
              body:[prism(col,"Long clipped upper rail",[(-.17,.16),(.279,.321),(.668,.522),(1.008,.605),(1.19,.54),(.929,.736),(.66,.669),(.384,.52),(-.105,.27)],-.095,.091,dark,.016),
                    prism(col,"Beveled chisel lower rail",[(-.157,.142),(.276,.149),(.634,.09),(1.063,.15),(1.277,.462),(1.192,.556),(.986,.292),(.624,.202),(.316,.228),(-.098,.247)],-.087,.085,edge,.02)],
              upper:[prism(col,"Diagonal reactor upper jaw",[(.36,.35),(.551,.337),(.704,.378),(.771,.48),(.612,.515),(.489,.429)],.084,.137,edge,.014)],
              lower:[prism(col,"Diagonal reactor lower jaw",[(.303,.21),(.474,.157),(.656,.19),(.765,.314),(.626,.305),(.548,.248),(.409,.23)],.078,.134,edge,.014)],
              core:[prism(col,"Violet faceted reactor bar",[(.421,.265),(.591,.204),(.729,.31),(.621,.409),(.478,.388)],-.043,.081,glow,.008)]}
        return layout,part,grip,off
    root,core,lead,trail,upper,lower="Offset grip","Nested frame","Leading panel","Trailing panel","Upper handle cheek","Lower handle cheek"
    grip=(-.246,0,-.134)
    layout=[(root,grip,None),(core,(.075,0,.172),root),(lead,(.195,0,.212),core),(trail,(.118,0,.169),core),
            (upper,(-.04,.06,.154),root),(lower,(-.09,.06,.065),root)]
    part={root:[beam(col,"Ivory main grip",(-.428,0,-.304),(-.107,0,.042),.068,edge,8),
                prism(col,"Graphite yoke",[(-.196,-.03),(.083,.085),(.269,.233),(.207,.298),(.046,.25),(-.127,.141)],-.070,.081,dark,.012)],
          upper:[prism(col,"Upper insulating cheek",cut(-.091,.127,.11,.183,.017),.065,.116,edge,.007)],
          lower:[prism(col,"Lower insulating cheek",cut(-.131,.098,.028,.1,.019),.065,.116,edge,.007)],
          core:[],lead:[],trail:[]}
    for label,shift,y in ((trail,-.06,-.061),(core,0,0),(lead,.052,.063)):
        profile=[(.161,.153),(.63,.221),(.955,.372),(1.328,.591),(1.161,.614),(.859,.538),(.549,.456),(.249,.276)]
        outside=[(x+shift,z+shift*.76) for x,z in profile]
        center=sum((Vector(v) for v in outside),Vector((0,0)))/len(outside)
        inside=[Vector(v)*.79+center*.21 for v in outside]
        vertices=[(x,d,z) for ring,d in ((outside,y-.027),(outside,y+.026),(inside,y+.033),(inside,y-.017)) for x,z in ring]
        n=len(outside)
        faces=[]
        for a,b in ((0,n),(n,2*n),(2*n,3*n),(3*n,0)):
            faces.extend((a+i,a+(i+1)%n,b+(i+1)%n,b+i) for i in range(n))
        part[label].append(mesh(col,label+" | graphite edge",vertices,faces,dark))
        glass=[Vector(v)*.816+center*.184 for v in outside]
        part[label].append(prism(col,label+" | smoked blade pan",glass,y-.014,y+.024,shade,.003))
    for i in range(3):
        label="Diagnostic cell "+str(i+1)
        pt=(-.105+i*.062,.087,.113)
        layout.append((label,pt,root))
        part[label]=[prism(col,label,cut(pt[0]-.019,pt[0]+.023,.102,.129,.008),.077,.108,glow,.002)]
    return layout,part,grip,None


def animate_melee(sc,col,item,palette):
    layout,pieces,right,left=new_melee(col,item,palette)
    rig=armature(col,item+" | structural melee rig",layout)
    for name,parts in pieces.items():
        for ob in parts:
            bind(ob,rig,name)
    hands=collection(sc,"Review | first-person grip proxies")
    anchors=(right,left) if left else (right,)
    for i,grip in enumerate(anchors):
        bind(locator(col,"Support grip" if i else "Main grip",grip),rig,layout[0][0])
        for ob in glove(hands,"Support" if i else "Main",grip,bool(i),(grip[0]-.51,.18 if i else -.1,grip[2]-.43),.93):
            bind(ob,rig,layout[0][0])
    hands.hide_render=True
    def channels(form):
        values=articulation(item,form)
        if item=="PatchTool" and form in ("rest","diagStart","diagFirst","diagMax","diagFinal","diagOff"):
            for bone,rot in (("Leading panel",-7),("Trailing panel",5)):
                loc,_,scale=values[bone]
                values[bone]=(loc,(0,rot,0),scale)
        return values
    key_pose(rig,1,channels=channels("rest"))
    for frame,delta,rotation,form in section_keys(item):
        # Longer structural silhouettes use a tighter presentation arc while retaining cue timing.
        key_pose(rig,frame,tuple(value*.86 for value in delta),rotation,channels(form))
    rig.animation_data.action.name=item+" | structural first-person reel"
    rig.animation_data.action.use_fake_user=True
    for text,frame in (("REST",1),("EQUIP",5),("IDLE",24),("CARRY",48),("LIGHT A",68),("A CONTACT",72),
                       ("LIGHT B",85),("B CONTACT",91),("HEAVY",104),("HEAVY CONTACT",113),
                       ("INSPECT",129),("RECOVER",178),("CANCEL",204),("RESET",219)):
        marker(sc,text,frame)
    sc.frame_start,sc.frame_end=1,220
    return rig
