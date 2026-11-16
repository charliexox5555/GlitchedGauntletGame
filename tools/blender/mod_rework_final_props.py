"""The final ability prop pass. Mechanical joints use shared profiles or cut seats."""

import math

import bpy
from mathutils import Matrix, Vector

from mod_rework_kit import Parts, angles, material


def palette():
    return {
        "receiver": material("Receiver charcoal", "343942", metal=.28),
        "plate": material("Slate panels", "545C6A", metal=.26),
        "light": material("Ceramic panels", "B2C1CE"),
        "grip": material("Rubber seats", "222831"),
        "steel": material("Machined fasteners", "747F8C", metal=.46),
        "dark_steel": material("Limb spring steel", "454E5F", metal=.38),
        "molly": material("Heat pack oxide", "C3592C"),
        "amber": material("Warm indicator", "F4B053", emission=.35),
        "yellow": material("Stim diffuser", "EDC85B", emission=.22),
        "hazard": material("Safety amber paint", "C69439"),
        "ice": material("Frost diffuser", "74B6D5", emission=.28),
        "scan": material("Recon indicator", "4AA7DD", emission=.26),
        "phase": material("Recall optic glass", "72C7BF", emission=.21),
    }


def prop_scene(name, kind):
    scene = bpy.data.scenes.new(name)
    parts = Parts(name)
    parts.collection["kind"] = kind
    scene.collection.children.link(parts.collection)
    bpy.context.window.scene = scene
    return parts


def scaled(profile, amount):
    cx = sum(x for x, _ in profile) / len(profile)
    cy = sum(y for _, y in profile) / len(profile)
    return [(cx+(x-cx)*amount, cy+(y-cy)*amount) for x,y in profile]


def plate(p, name, profile, near, far, mat, *, edge=.004, pivot=(0,0,0)):
    """Single flat edge break on the cut profile. Keep the silhouette planar."""
    if edge <= 0:
        return p.silhouette(name, profile, near, far, mat, pivot=pivot)
    span = max(max(x for x,_ in profile)-min(x for x,_ in profile),
               max(z for _,z in profile)-min(z for _,z in profile))
    inner = scaled(profile,1-2*edge/span)
    d = min(edge, (far-near)*.24)
    sections = [(near,inner),(near+d,profile),(far-d,profile),(far,inner)]
    return p.loft(name,[[(x,y,z) for x,z in ring] for y,ring in sections],
                  mat,pivot=pivot)


def base(p, name, profile, levels, mat):
    """XY footprint with angled feet and a shared deck plane."""
    return p.loft(name,[[(x*size,y*size,z) for x,y in profile]
                        for z,size in levels],mat)


def apply_boolean(obj, tool, operation):
    mod=obj.modifiers.new("Machined opening","BOOLEAN")
    mod.operation=operation
    mod.solver="EXACT"
    mod.object=tool
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mesh=tool.data
    bpy.data.objects.remove(tool,do_unlink=True)
    if not mesh.users:
        bpy.data.meshes.remove(mesh)


def cut(p, obj, profile, near, far):
    """Subtract a window or seat and discard the local construction mesh."""
    cutter=p.silhouette("cut",profile,near,far,obj.data.materials[0])
    apply_boolean(obj,cutter,"DIFFERENCE")


def pocket(p, body, name, outline, y, depth, mat, *, fill=.93):
    """Put a part below an outer face. Leave a small clearance around the insert."""
    sign=1 if y>0 else -1
    wall=abs(y)-depth
    cut(p,body,outline,*sorted((sign*wall,sign*(abs(y)+.035))))
    lower,upper=sorted((sign*(wall+.001),sign*(abs(y)-.004)))
    return plate(p,name,scaled(outline,fill),lower,upper,mat,edge=.0019)


def angular_fastener(p, name, pos, radius, length, mat):
    x,y,z=pos
    section=[(x+radius*math.cos(a),z+radius*math.sin(a)) for a in angles(6,math.pi/6)]
    return plate(p,name,section,y-length,y,mat,edge=radius*.13,pivot=pos)


def canister_hardware(p, m, *, hinge, lever_outline, opening, y, pad_outline=None):
    lever=plate(p,"Lever",lever_outline,-y,y,m["dark_steel"],edge=.003,pivot=hinge)
    cut(p,lever,opening,-y-.02,y+.02)
    x,_,z=hinge
    tab=[
        (x-.036,z+.016),(x-.040,z+.038),(x-.023,z+.053),
        (x+.014,z+.049),(x+.024,z+.033),(x+.017,z+.012),(x+.009,z-.005),(x-.011,z-.006)
    ]
    pin_pivot=(x,-y-.009,z)
    pin=plate(p,"Pin",tab,-y-.019,-y+.001,m["steel"],edge=.002,pivot=pin_pivot)
    cut(p,pin,[(x-.023,z+.024),(x-.024,z+.035),(x-.015,z+.041),
                (x+.005,z+.038),(x+.009,z+.028),(x+.003,z+.021)],
        -y-.030,-y+.013)
    p.point("LeverPivot",hinge)
    p.point("PinPivot",pin_pivot)
    p.point("PinPull",(x,-y-.119,z))
    if pad_outline:
        profile, pivot = pad_outline
        plate(p,"PrimePad",profile,-.053,.045,m["molly"],edge=.001,pivot=pivot)
        p.point("PrimePadPivot",pivot)
        p.point("PrimePadPressed",(pivot[0],pivot[1],pivot[2]-.008))
    p.point("Handle",(0,0,0))


def molly(m):
    p=prop_scene("Molly","thrown")
    profile=[
        (-.158,-.231),(.110,-.231),(.174,-.182),(.172,-.069),(.137,-.034),
        (.146,.095),(.105,.146),(-.055,.174),(-.125,.148),(-.158,.088),(-.180,-.164)
    ]
    body=plate(p,"Body",profile,-.109,.109,m["receiver"],edge=.010)
    # Large quiet panel. The taper and clamping lip follow the top seam of the case.
    cassette=[(-.137,-.164),(-.106,.073),(-.066,.113),(.058,.092),(.109,.046),
              (.094,-.046),(.130,-.108),(.128,-.154),(.083,-.191),(-.098,-.190)]
    for y,suffix in [(-.109,"Front"),(.109,"Rear")]:
        pocket(p,body,"HeatCassette_"+suffix,cassette,y,.014,m["molly"],fill=.93)
        sign=1 if y>0 else -1
        for i in range(2):
            x=-.083+i*.026
            mark=[(x,-.152),(x+.014,-.152),(x+.028,-.129),(x+.014,-.129)]
            plate(p,f"HeatStamp{suffix}{i+1}",mark,*sorted((sign*.1049,sign*.106)),
                  m["amber"],edge=0)
    shoe_outline=[(-.157,-.230),(.110,-.230),(.169,-.179),(.175,-.209),(.118,-.255),(-.146,-.255),
                  (-.167,-.242)]
    plate(p,"FootShoe",shoe_outline,-.104,.104,m["grip"],edge=.0035)
    # The cap meets the body at a keyed diagonal foot, with a real slot for its pad.
    yoke_outline=[(-.090,.157),(-.066,.195),(-.023,.208),(.115,.205),(.136,.179),
                  (.112,.149),(.105,.147),(-.055,.175)]
    yoke=plate(p,"FuseHead",yoke_outline,-.079,.079,m["plate"],edge=.003)
    pad_cut=[(-.058,.200),(-.045,.220),(.046,.218),(.062,.201),(.048,.194),(-.043,.195)]
    cut(p,yoke,pad_cut,-.058,.051)
    lamp=[(-.038,.187),(.025,.186),(.034,.176),(.029,.171),(-.033,.172)]
    pocket(p,yoke,"Fuse_Energy",lamp,-.079,.010,m["amber"],fill=.90)
    lever=[(.097,.213),(.135,.218),(.164,.194),(.198,.140),(.222,.058),
           (.216,.016),(.202,.010),(.182,.043),(.167,.112),(.125,.168),(.091,.176)]
    slit=[(.129,.194),(.144,.196),(.181,.140),(.200,.073),(.193,.065),
          (.179,.114),(.150,.161),(.122,.180)]
    pad=([(-.054,.201),(-.043,.215),(.044,.213),(.055,.201),(.044,.197),(-.042,.198)],
         (.000,-.004,.203))
    canister_hardware(p,m,hinge=(.112,0,.188),lever_outline=lever,opening=slit,y=.062,
                      pad_outline=pad)
    p.point("Fuse",(-.003,-.080,.178))
    return p


def frost(m):
    p=prop_scene("Frost","thrown")
    outline=[(-.097,-.254),(.076,-.252),(.118,-.205),(.104,-.052),
             (.088,.009),(.092,.134),(.051,.242),(-.043,.258),
             (-.092,.219),(-.120,.099),(-.129,-.160)]
    shell=plate(p,"Body",outline,-.092,.092,m["light"],edge=.006)
    vent=[(-.071,.177),(-.094,-.132),(-.064,-.196),(.041,-.182),(.064,-.126),
          (.051,-.078),(.058,.131),(.020,.171)]
    slots=[
        [(-.073,.093),(.047,.127),(.039,.100),(-.073,.067)],
        [(-.075,.035),(.040,.070),(.033,.044),(-.078,.008)],
        [(-.078,-.023),(.034,.011),(.026,-.015),(-.080,-.050)],
        [(-.082,-.080),(.027,-.046),(.021,-.072),(-.081,-.105)],
    ]
    for y,suffix in [(-.092,"Front"),(.092,"Rear")]:
        sign=-1 if y<0 else 1
        cut(p,shell,vent,*sorted((sign*.066,sign*.124)))
        shutter=plate(p,"VentPanel_"+suffix,scaled(vent,.94),
                      *sorted((sign*.070,sign*.086)),m["grip"],edge=.002)
        for slot in slots:
            cut(p,shutter,slot,*sorted((sign*.066,sign*.095)))
        lens=[(-.066,-.129),(.028,-.111),(.043,.109),(.031,.147),(-.054,.143)]
        plate(p,"CoolingGrille_"+suffix,lens,*sorted((sign*.067,sign*.0715)),m["ice"],edge=.001)
    shoe=[(-.099,-.253),(.076,-.251),(.117,-.205),(.111,-.246),
          (.074,-.275),(-.086,-.275),(-.111,-.257)]
    plate(p,"FootShoe",shoe,-.088,.088,m["receiver"],edge=.003)
    crown_outline=[(-.060,.254),(-.007,.285),(.047,.271),(.074,.236),
                   (.056,.215),(.046,.237),(-.042,.259)]
    crown=plate(p,"FuseHead",crown_outline,-.069,.069,m["receiver"],edge=.0025)
    status=[(-.018,.264),(.034,.254),(.040,.246),(.032,.242),(-.014,.253)]
    pocket(p,crown,"Fuse_Energy",status,-.069,.008,m["ice"],fill=.90)
    lever=[(.046,.251),(.073,.255),(.112,.203),(.152,.092),(.155,.050),(.140,.027),
           (.127,.051),(.111,.136),(.086,.198),(.051,.221)]
    opening=[(.071,.231),(.081,.231),(.110,.181),(.135,.100),(.132,.085),(.122,.112),
             (.100,.170),(.066,.219)]
    canister_hardware(p,m,hinge=(.062,0,.230),lever_outline=lever,opening=opening,y=.050)
    p.point("Fuse",(.006,-.069,.251))
    return p


def bow_and_bolt(m):
    p=prop_scene("Recon","handheld")
    # A straight, machined riser with open areas around the grip and the arrow shelf.
    profile=[(-.091,-.249),(.144,-.245),(.206,-.204),(.196,-.145),(.136,-.115),
             (.110,-.072),(.110,.073),(.153,.135),(.200,.180),(.199,.226),
             (.169,.252),(-.091,.257),(-.131,.218),(-.115,.167),(-.050,.131),
             (-.016,.111),(-.043,.058),(-.083,-.093),(-.140,-.163),(-.132,-.209)]
    receiver=plate(p,"Receiver",profile,-.069,.069,m["receiver"],edge=.008)
    lower=[(.015,-.221),(.122,-.217),(.154,-.199),(.123,-.175),(.022,-.170),(-.007,-.190)]
    upper=[(.019,.171),(.133,.170),(.163,.198),(.148,.222),(-.005,.222),(-.024,.199)]
    for side,y in [("Left",.069),("Right",-.069)]:
        pocket(p,receiver,"LowerInsert_"+side,lower,y,.011,m["plate"])
        pocket(p,receiver,"UpperInsert_"+side,upper,y,.013,m["plate"])
    indicator=[(.005,.197),(.073,.197),(.088,.207),(.072,.212),(.005,.212),(-.007,.206)]
    plate(p,"Charge_Energy",indicator,-.068,-.063,m["scan"],edge=.001)
    for i in range(2):
        h=-.198
        x=.054+i*.052
        pip=[(x-.016,h-.008),(x+.010,h-.008),(x+.016,h+.004),(x+.010,h+.010),(x-.016,h+.010)]
        plate(p,f"Bounce{i+1}_Energy",pip,-.068,-.063,m["scan"],edge=.0012)
    hand=[(-.073,-.133),(.054,-.124),(.084,-.066),(.075,.083),(.042,.111),
          (-.030,.107),(-.062,.018),(-.090,-.092)]
    handle=plate(p,"Grip",hand,-.084,.084,m["grip"],edge=.005)
    for i in range(4):
        z=-.091+i*.039
        cut(p,handle,[(-.065,z-.007),(.043,z+.010),(.056,z+.015),(.046,z+.019),(-.068,z+.002)],
            -.096,-.079)
    # Each limb is a closed structural arm with an actual open truss and matching seats.
    for name,sign in [("Upper",1),("Lower",-1)]:
        amount=1 if sign==1 else .96
        joint=(.132,0,sign*.213)
        def shape(points):
            return [(x,z*sign*amount) for x,z in points]
        outline=shape([(.077,.218),(.197,.218),(.216,.273),(.177,.409),(.083,.492),
            (-.092,.570),(-.184,.592),(-.202,.560),(-.143,.526),(.008,.436),
            (.067,.361),(.098,.292),(.062,.253)])
        limb=plate(p,name+"Limb",outline,-.034,.034,m["dark_steel"],edge=.004,pivot=joint)
        truss=shape([(.135,.285),(.169,.286),(.163,.378),(.091,.459),(-.075,.546),
                     (-.011,.477),(.072,.402),(.104,.363)])
        cut(p,limb,truss,-.075,.075)
        tip=(-.173,-.073,.568*sign*amount)
        hardware=shape([(-.190,.580),(-.148,.583),(-.119,.559),(-.143,.535),
                        (-.185,.539),(-.206,.560)])
        plate(p,name+"StringTip",hardware,-.079,.023,m["steel"],edge=.003,pivot=tip)
        strap=shape([(.111,.230),(.177,.232),(.188,.260),(.171,.287),(.113,.283),(.094,.257)])
        plate(p,name+"LimbPlate",strap,-.043,-.034,m["plate"],edge=.0025,pivot=joint)
        angular_fastener(p,name+"PivotPin",(joint[0],-.044,sign*.243),.014,.006,m["grip"])
        p.point("Limb"+name+"Pivot",joint)
        p.point("String"+name,tip)
        nock=(-.178,-.111,.094)
        p.beam("String"+name+"Segment",nock,tip,[(0,.0032,.0032),(1,.0032,.0032)],
               m["steel"],pivot=nock)
    rest=[(.096,.063),(.172,.062),(.190,.071),(.182,.083),(.113,.082)]
    plate(p,"BoltRest",rest,-.132,-.062,m["steel"],edge=.0028)
    p.point("Handle",(0,0,0))
    p.point("LeftGrip",(-.006,0,-.017))
    p.point("StringNock",(-.178,-.111,.094))
    p.point("StringNockDrawn",(-.467,-.111,.094))
    p.point("BoltTipHeld",(.662,-.111,.094))
    p.point("Muzzle",(.198,-.111,.094))

    bolt=prop_scene("ReconDart","thrown")
    bolt.beam("Body",(-.839,0,0),(-.091,0,0),[(0,.010,.010),(.05,.014,.014),
        (.86,.014,.014),(1,.023,.019)],m["grip"],cut=.22)
    bolt.beam("Tip",(-.139,0,0),(0,0,0),[(0,.024,.025),(.20,.035,.029),
        (.74,.032,.027),(1,.009,.012)],m["plate"],cut=.24)
    for i,a in enumerate(angles(3)):
        rotation=Matrix.Rotation(a,4,"X")
        fin=[(-.835,.010),(-.816,.049),(-.764,.050),(-.703,.019),(-.693,.012)]
        bolt.loft(f"Fin{i+1}",[[rotation@Vector((x,y,z)) for x,z in fin]
                              for y in (-.004,.004)],m["dark_steel"])
    bolt.silhouette("Light_Energy",[(-.108,-.010),(-.082,-.015),(-.042,-.010),
                     (-.035,.003),(-.066,.011),(-.102,.009)],-.034,-.026,m["scan"])
    bolt.point("Handle",(0,0,0))
    bolt.point("Trail",(-.837,0,0))


def stim(m):
    p=prop_scene("Stim","placed")
    footprint=[(-.418,-.308),(.258,-.338),(.427,-.243),(.406,.132),(.289,.274),
               (-.307,.298),(-.477,.172),(-.466,-.205)]
    base(p,"Skid",footprint,[(0,.87),(.040,1),(.088,.99),(.131,.92)],m["dark_steel"])
    base(p,"Seat",footprint,[(.131,.76),(.153,.83),(.166,.78)],m["grip"])
    casing_outline=[(-.355,.166),(.319,.166),(.374,.202),(.329,.349),(.247,.461),
        (.149,.489),(-.255,.459),(-.389,.369),(-.405,.247)]
    case=plate(p,"Base",casing_outline,-.248,.238,m["receiver"],edge=.017)
    port=[(-.278,.237),(.198,.237),(.283,.293),(.222,.350),(-.229,.354),(-.300,.303)]
    pocket(p,case,"Coil_Yellow",port,-.248,.029,m["yellow"],fill=.88)
    rear=[(-.272,.240),(.246,.239),(.281,.282),(.221,.320),(-.250,.328),(-.292,.286)]
    pocket(p,case,"ServicePanel",rear,.238,.019,m["plate"],fill=.91)
    # The carry grip belongs to the case. Union it and cut one through opening.
    carry=[(-.291,.403),(-.282,.510),(-.208,.590),(.039,.602),(.146,.567),
           (.188,.479),(.158,.443),(-.233,.420)]
    handle=plate(p,"CarryHandle",carry,-.120,.120,m["dark_steel"],edge=.009)
    apply_boolean(case,handle,"UNION")
    cut(p,case,[(-.213,.486),(-.179,.540),(.028,.550),(.083,.531),(.105,.503),
                (.062,.490)],-.160,.160)
    for i,x in enumerate((-.309,.280),1):
        angular_fastener(p,f"FlushFastener{i}",(x,-.251,.218),.013,.005,m["steel"])
    lamp=[(.199,.400),(.250,.390),(.266,.365),(.230,.361),(.196,.379)]
    pocket(p,case,"Light_Energy",lamp,-.248,.012,m["ice"],fill=.93)
    p.point("Floor",(0,0,0))
    p.point("Top",(.014,0,.593))
    p.point("CoilPivot",(-.030,-.229,.296))
    return p


def recall(m):
    p=prop_scene("Recall","placed")
    footprint=[(-.360,-.326),(.265,-.344),(.395,-.217),(.348,.154),(.244,.254),
               (-.299,.275),(-.415,.103),(-.423,-.192)]
    base(p,"Skid",footprint,[(0,.87),(.032,1),(.095,.98),(.144,.88)],m["receiver"])
    base(p,"BaseSeat",footprint,[(.144,.71),(.159,.79),(.193,.73)],m["grip"])
    # One structural fork. Both emitters share a machined saddle and a continuous foot.
    frame=[(-.278,.191),(.254,.191),(.292,.242),(.348,.544),(.282,.643),
           (.216,.667),(.158,.610),(.152,.388),(.088,.315),(-.082,.317),
           (-.129,.383),(-.163,.610),(-.214,.653),(-.278,.594),
           (-.330,.510),(-.310,.289)]
    frame_obj=plate(p,"Crown",frame,-.185,.177,m["dark_steel"],edge=.012)
    for side,y in [("Front",-.185),("Rear",.177)]:
        for name, s in [("Left",-1),("Right",1)]:
            panel=[(x*s,z) for x,z in [(.199,.373),(.268,.392),(.302,.527),
                                       (.261,.576),(.216,.586),(.181,.530)]]
            pocket(p,frame_obj,"Bank_"+name+side,panel,y,.016,m["plate"],fill=.86)
    case=[(-.134,.312),(.124,.312),(.147,.359),(.120,.416),(-.113,.416),(-.153,.360)]
    # Socket the emitter into the saddle. The lens and bezel occupy alternating bands.
    plate(p,"CoreBase",case,-.119,.128,m["receiver"],edge=.005)
    p.ring("PhaseRing",[(.080,.417),(.109,.419),(.125,.434),(.112,.446),(.080,.439)],
           m["plate"],sides=6,phase=math.pi/6,pivot=(0,0,.430))
    p.radial("Core",[(.415,0,0,.073),(.444,0,0,.077),(.488,0,0,.064),
                     (.519,0,0,.033)],m["phase"],sides=6,pivot=(0,0,.440))
    rail=[(-.073,.266),(.064,.266),(.092,.285),(.071,.307),(-.073,.307),(-.092,.286)]
    pocket(p,frame_obj,"Light_Energy",rail,-.185,.013,m["phase"],fill=.92)
    liner=[(.157,.436),(.177,.437),(.209,.546),(.200,.574),(.180,.552)]
    plate(p,"PhaseInset",liner,-.062,.105,m["phase"],edge=.003,pivot=(0,0,.430))
    p.point("Floor",(0,0,0))
    p.point("CorePivot",(0,0,.440))
    p.point("PhasePivot",(0,0,.430))
    p.point("Top",(0,0,.519))
    return p


def build_props():
    m=palette()
    hero=molly(m)
    frost(m)
    bow_and_bolt(m)
    stim(m)
    recall(m)
    return hero
