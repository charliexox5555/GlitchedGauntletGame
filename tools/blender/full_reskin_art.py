"""Rest-space placement and artwork for Oilwake, Misprint, and Faultline."""

from dataclasses import dataclass
import math

import numpy as np

from skin_graphics import Artwork


@dataclass(frozen=True)
class Placement:
    parts: dict
    bounds: tuple
    style: tuple


def on(parts, bounds, *style):
    """Parse the stock object suffix and the surface roles eligible for the print."""
    hosts = {}
    for spec in parts.split():
        part, _, roles = spec.partition(":")
        hosts[part] = set(roles.split(",")) if roles else {"Body", "Panel"}
    return Placement(hosts, bounds, style)


# Oilwake: inset outline chamfer, taper, and grazing-amber placement.
OIL = {
    "Vandal": on("Receiver:Panel", (.158,.731,.182,.271), .07,.08,.25),
    "Phantom": on("Handguard", (.909,1.617,.199,.429), .055,.012,.30),
    "Bulldog": on("Stock:Dark", (-1.057,-.514,.274,.418), .065,.08,.28),
    "Guardian": on("Receiver Handguard", (.17,1.95,.231,.377), .092,.12,.25),
    "Spectre": on("Receiver", (.06,.58,.18,.316), .13,.09,.32),
    "Stinger": on("Receiver", (.31,.724,.254,.315), .15,.10,.22),
    "Ares": on("Receiver", (.21,1.047,.233,.414), .083,.15,.28),
    "Odin": on("Receiver", (.065,.99,.282,.474), .115,.11,.32),
    "Sheriff": on("Frame", (.599,.776,.175,.284), .16,.12,.28),
    "Classic": on("Slide", (.20,.891,.349,.422), .12,.10,.23),
    "Ghost": on("Slide", (.14,.995,.284,.350), .12,.12,.21),
    "Shorty": on("Frame:Panel", (.05,.414,.092,.198), .14,.06,.34),
    "Bucky": on("Receiver", (.37,.887,.252,.357), .13,.14,.26),
    "Judge": on("Receiver:Panel", (-.062,1.022,.381,.586), .09,.11,.24),
    "Marshal": on("ForeEnd:Grip", (1.006,1.656,.034,.165), .10,.07,.27),
    "Outlaw": on("Receiver:Panel", (.308,.887,.278,.413), .12,.08,.27),
    "Operator": on("Receiver", (.172,.999,.206,.344), .13,.12,.22),
}

# Misprint: pitch, cobalt length, vermilion offset, dot columns, forward wrap.
PRINT = {
    "Vandal": on("Receiver Handguard", (.014,1.48,.177,.412), .19,.98,.075,9,.097),
    "Phantom": on("Receiver Handguard", (-.049,1.539,.157,.414), .08,.96,.079,8,.010),
    "Guardian": on("Receiver Handguard", (.167,2.135,.192,.431), .18,.97,.069,10,.103),
    "Spectre": on("Receiver", (-.182,.648,.162,.421), .16,.84,.068,7,.019),
    "Stinger": on("Receiver", (-.289,.735,.224,.383), -.12,.90,.094,6,.013),
    "Ares": on("Receiver Handguard", (-.07,1.923,.191,.476), .12,.96,.080,10,.022),
    "Odin": on("Receiver", (-.062,1.119,.192,.518), -.12,.98,.083,7,.015),
    "Sheriff": on("Frame Barrel", (.616,1.386,.145,.344), .19,.93,.095,5,.076),
    "Classic": on("Slide", (-.159,.875,.301,.477), -.13,.94,.087,5,.011),
    "Ghost": on("Slide", (-.095,1.067,.247,.376), .10,.96,.063,6,.007),
    "Shorty": on("Frame", (-.054,.52,.116,.315), -.14,.88,.09,4,.009),
    "Bucky": on("Receiver", (-.029,.938,.173,.405), .19,.96,.08,7,.019),
    "Judge": on("Receiver Handguard", (-.037,1.604,.306,.581), -.18,.94,.101,9,.024),
    "Marshal": on("ForeEnd:Grip", (1.009,1.651,.030,.166), .12,.99,.067,7,.018),
    "Outlaw": on("Receiver", (.208,.989,.163,.455), .17,.93,.085,6,.012),
    "Operator": on("Receiver Handguard", (.136,2.129,.163,.403), -.13,.98,.096,9,.008),
}

# Faultline: fill stays within the host and the chosen path always has one main branch.
# The ordinate list is sampled at fixed irregular intervals for a faceted fracture.
FAULT = {
    "Vandal": on("Receiver", (-.016,1.034,.112,.398), (.71,.65,.69,.51,.48,.41,.49), 3,-.23),
    "Phantom": on("Receiver Handguard", (-.075,1.567,.129,.371), (.55,.48,.53,.38,.43,.34,.37), 4,-.21),
    "Bulldog": on("Stock Receiver", (-1.134,.659,.156,.413), (.42,.44,.47,.69,.56,.42,.45), 3,-.18),
    "Guardian": on("Receiver Handguard", (-.003,2.184,.213,.400), (.61,.67,.50,.54,.38,.42,.34), 2,-.20),
    "Spectre": on("Receiver Handguard", (-.154,1.092,.198,.411), (.49,.61,.60,.44,.48,.58,.52), 3,-.27),
    "Stinger": on("Receiver", (-.322,.494,.216,.365), (.70,.58,.61,.47,.49,.34,.39), 4,-.20),
    "Ares": on("Receiver", (-.031,1.161,.154,.499), (.59,.68,.57,.62,.41,.46,.31), 3,-.35),
    "Odin": on("Receiver", (-.099,1.031,.208,.485), (.38,.50,.45,.63,.58,.53,.61), 3,-.30),
    "Sheriff": on("Frame Barrel", (.34,1.43,.093,.36), "approved Sheriff v02"),
    "Classic": on("Slide", (-.164,.928,.303,.468), (.67,.61,.65,.48,.50,.36,.41), 4,-.17),
    "Ghost": on("Slide", (-.128,1.084,.244,.383), (.54,.62,.52,.59,.51,.38,.45), 3,-.18),
    "Shorty": on("Frame", (-.052,.521,.111,.312), (.64,.73,.58,.67,.52,.45,.48), 3,-.25),
    "Bucky": on("Receiver", (-.040,.936,.171,.390), (.55,.64,.54,.60,.49,.38,.41), 2,-.21),
    "Judge": on("Receiver", (-.028,1.192,.329,.582), (.62,.68,.56,.59,.45,.49,.37), 4,-.31),
    "Marshal": on("Receiver ForeEnd:Dark,Grip", (.235,1.78,.044,.183), (.64,.61,.69,.60,.44,.53,.42), 4,-.17),
    "Outlaw": on("Receiver", (.186,.985,.165,.437), (.52,.64,.59,.47,.52,.44,.35), 3,-.25),
    "Operator": on("Receiver Handguard", (.153,2.148,.155,.435), (.64,.68,.59,.53,.55,.39,.45), 4,-.22),
}

EXTRAS = {
    "Ares": on("Drum:Panel", (.616,1.011,-.308,-.156), -.24,.88,.073,0,0),
    "Odin": on("AmmoBox:Panel,Dark", (.362,.791,-.282,-.115), .15,.86,.090,0,0),
    "Judge": on("Mag:Dark", (.643,1.065,-.237,-.075), .17,.86,.092,0,0),
    "Ghost": on("Suppressor:Dark", (1.236,1.493,.271,.359), .07,.86,.085,0,0),
}

PALETTES = {
    "Oilwake": {
        "Body": ("142633", .36, .59), "Panel": ("255B57", .34, .49),
        "Dark": ("121A22", .68, .10), "Grip": ("232A31", .78, .03),
        "Metal": ("506875", .39, .82), "Accent": ("A77538", .31, .76),
        "Neon": ("68CBB8", .24, 0),
    },
    "Misprint": {
        "Body": ("ECE3D2", .31, .04), "Panel": ("D7CABA", .35, .04),
        "Dark": ("232632", .69, .04), "Grip": ("2B303B", .78, .04),
        "Metal": ("8996A8", .41, .68), "Accent": ("2447B9", .35, .68),
        "Neon": ("8198F7", .25, 0),
    },
    "Faultline": {
        "Body": ("171B21", .44, .04), "Panel": ("31363F", .47, .07),
        "Dark": ("101216", .63, .07), "Grip": ("25262C", .77, .03),
        "Metal": ("555C69", .40, .70), "Accent": ("C07D57", .28, .78),
        "Neon": ("DEA987", .26, 0),
    },
}


def layers(line, item):
    if line == "Oilwake":
        yield OIL[item], oilwake
        if item == "Phantom":
            yield on("Receiver:Panel", (-.16,.37,.19,.32), .13,.08,.18), oilwake
    elif line == "Misprint":
        yield PRINT[item], misprint
        if item in EXTRAS:
            yield EXTRAS[item], misprint
    else:
        yield FAULT[item], sheriff if item == "Sheriff" else faultline


def stroke(art, points, radius, aspect=1):
    mask = np.zeros(art.x.shape, dtype=bool)
    for (x0,z0),(x1,z1) in zip(points,points[1:]):
        dx,dz = (x1-x0)*aspect,z1-z0
        x,z = (art.x-x0)*aspect,art.z-z0
        part = np.clip((x*dx+z*dz)/(dx*dx+dz*dz),0,1)
        mask |= (x-dx*part)**2+(z-dz*part)**2 < radius**2
    return mask


def oilwake(art, p, item):
    chamfer, slope, warm = p.style
    outline = [(0,.18),(chamfer,.08),(.94,.09+slope),(.997,.23+slope),
               (.98,.815),(1-chamfer,.92),(.072,.914),(0,.78)]
    rim = art.poly(outline)
    center = art.poly([(.5+(x-.5)*.976,.5+(z-.5)*.87) for x,z in outline])
    art.paint(rim,"51616A",.41,.75)
    art.paint(center,"255B57",.27,.32)
    # A narrow amber return gives the static PBR maps the same colour travel at
    # the edge of the coating while its Blender preview uses an angle ramp.
    warm_edge = center & ((art.z < .19+warm*art.x*.24) | (art.x > .958))
    teal_edge = center & ((art.z > .78) | ((art.x < .10) & (art.z > .46)))
    art.paint(teal_edge,"408B72",.28,.34)
    art.paint(warm_edge,"9B8954",.30,.40)
    art.finish[center,2] = 1.0


def misprint(art,p,item):
    pitch, reach, offset, columns, _ = p.style
    def tilt(points):
        return [(x,.5+(z-.5)+pitch*(x-.5)) for x,z in points]
    blue=art.poly(tilt([(.024,.36),(.15,.27),(.71,.44),(reach,.69),(reach-.12,.865),(.40,.69),(.11,.57)]))
    red=art.poly(tilt([(.079+offset,.13),(.409,.10),(.839,.33),(.986,.55),(.78,.59),(.53,.38),(.19,.27)]))
    art.paint(blue,"2447B9",.322,.04)
    art.paint(red,"E5533E",.342,.04)
    art.paint(blue & red,"874077",.335,.04)
    if columns:
        dx = (.50 if reach>.90 else .44) / max(columns-1,1)
        for row in range(3):
            for i in range(columns):
                u = .21+i*dx+row*.012
                z = .50+.145*(u-.21)+row*.055+pitch*(u-.5)
                dot = art.oval(u,z,.009+row*.001,.013+row*.002,.22)
                art.paint(dot & blue & ~red,"252849",.37,.03)


def faultline(art,p,item):
    heights,node,branch_drop=p.style
    width=p.bounds[1]-p.bounds[0]
    height=p.bounds[3]-p.bounds[2]
    aspect=width/height
    xs=(.034,.153,.287,.443,.592,.778,.962)
    main=list(zip(xs,heights))
    bottom=[(.970,.105),(.777,.07),(.58,.145),(.41,.102),(.24,.20),(.102,.24)]
    ash=art.poly(main+bottom)
    art.paint(ash,"59616B",.49,.08)
    a,b,c,d=(main[i] for i in (1,2,3,5))
    art.paint(art.poly([a,b,c,(.428,.159),(.306,.261),(.164,.233)])&ash,"8D9298",.46,.06)
    art.paint(art.poly([b,c,(.414,.376),(.37,.243),(.305,.277)])&ash,"AEB2B7",.41,.04)
    art.paint(art.poly([c,main[4],d,(.718,.175),(.55,.127),(.428,.159)])&ash,"727983",.51,.05)
    art.paint(art.poly([d,main[6],(.894,.09),(.777,.07),(.718,.175)])&ash,"474C56",.54,.05)
    x,z=main[node]
    dx=.108 if node<4 else -.1
    branch=[(x,z),(x+dx*.3,z+branch_drop*.28),(x+dx*.57,z+branch_drop*.39),
            (x+dx*.67,z+branch_drop*.68),(x+dx,z+branch_drop)]
    copper=max(.012,min(.026,.0039/height))
    art.paint(stroke(art,branch,copper*1.05,aspect),"2D2526",.56,.06)
    art.paint(stroke(art,branch,copper*.54,aspect),"B67658",.31,.65)
    art.paint(stroke(art,main,copper*1.58,aspect),"2D2526",.57,.06)
    art.paint(stroke(art,main,copper,aspect),"C07D57",.29,.76)
    art.paint(stroke(art,main[1:6],copper*.34,aspect),"EDAF82",.26,.70)


def sheriff(art,p,item):
    # Approved Sheriff v02 artwork coordinates.
    main=[(.035,.69),(.13,.64),(.18,.68),(.24,.57),(.34,.61),(.39,.51),(.44,.55),
          (.51,.40),(.58,.44),(.66,.33),(.73,.38),(.82,.29),(.95,.35)]
    art.paint(art.poly(main+[(.95,.07),(.78,.08),(.70,.13),(.58,.09),(.38,.22),(.26,.15),(.08,.26)]),
              "59616B",.47,.06)
    facets=[
        ([(0,.69),(.14,.64),(.18,.68),(.24,.57),(.34,.61),(.39,.51),(.44,.55),(.51,.40),(.45,.19),(.31,.30),(.25,.27),(.13,.41),(0,.38)],"8D9298",.45),
        ([(.19,.67),(.24,.57),(.34,.61),(.39,.51),(.44,.55),(.51,.40),(.45,.19),(.32,.30),(.32,.43)],"AEB2B7",.42),
        ([(.41,.50),(.44,.55),(.51,.40),(.58,.44),(.66,.33),(.73,.38),(.70,.13),(.60,.09),(.55,.22),(.45,.19)],"727983",.48),
        ([(.64,.34),(.73,.38),(.82,.29),(.95,.35),(.87,.13),(.78,.08),(.70,.13)],"474C56",.51),
        ([(.255,.53),(.29,.51),(.32,.43),(.315,.28),(.28,.30),(.26,.38)],"30343D",.51),
        ([(.49,.37),(.54,.33),(.58,.26),(.59,.12),(.55,.15),(.51,.28)],"333943",.51),
    ]
    for points,color,rough in facets:
        art.paint(art.poly(points),color,rough,.05)
    branch=[main[7],(.49,.34),(.43,.32),(.42,.24),(.37,.17),(.36,.095)]
    asp=2048/768
    for points,pixels,color,rough,metal in (
        (branch,23,"252228",.52,.03),(branch,12,"B67658",.33,.66),
        (main,38,"2D2526",.51,.03),(main,23,"C27B4C",.29,.71),
        (main,8,"EDAF82",.26,.63),(main[3:8],6,"F7C79A",.27,.64),
    ):
        art.paint(stroke(art,points,pixels/1536,asp),color,rough,metal)
    for points in (
        [(.14,.56),(.17,.60),(.21,.57)],[(.25,.49),(.28,.45),(.30,.46)],
        [(.64,.25),(.66,.19),(.69,.18)],[(.8,.21),(.84,.18)],
    ):
        art.paint(stroke(art,points,3/1536,asp),"A5A7A8",.45,.10)


def raster(placement, draw, item):
    x,z=np.meshgrid((np.arange(1280)+.5)/1280,(np.arange(480)+.5)/480)
    art=Artwork(x,z)
    draw(art,placement,item)
    return art
