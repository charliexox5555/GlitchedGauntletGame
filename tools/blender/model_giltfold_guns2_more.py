"""Giltfold round two, continued: Stinger, Ghost, Classic (exec'd by
model_giltfold_guns2.py, which defines the origami helpers)."""

def gf2_stinger():
    """SMG: the magazine runs up through the grip and the bolt / charging
    handle ride the receiver, so the grip and receiver stay stock in ivory /
    ink with folded cladding; the wire stock becomes a folded paper stock with
    a wave panel and pleated butt; a paper handguard with a lower spike; a
    twisted shroud over the muzzle; a folded boat base on the magazine."""
    p = {}
    HIDE = ["Stinger_Stock", "Stinger_Handguard", "Stinger_Pins", "Stinger_Neon"]
    st, sth = paper_solid("GFS_Stock", "Stinger_Stock", crease=((-.52, .30), (-1.53, -.02)), y_half=.064)
    pattern_window(st, inset(sth, .075, clip=((-1.0, 0.0, -.78),)), .058)       # window behind x -.78 (hinge block solid)
    p["stock"] = tri(st)
    p["pleats"] = pleats("GFS_Pleats", -1.500, -1.560, [.300, .230, .160, .090, .020, -.050, -.096], .066)
    hg, hgh = paper_solid("GFS_Handguard", "Stinger_Handguard", crease=((.46, .14), (.83, .25)))
    pattern_window(hg, inset(hgh, .030, clip=((0.0, 1.0, -.150),)), .080)        # z >= .150
    p["hg"] = tri(hg)
    p["spike"] = spike("GFS_Spike", ((.78, .105), (.826, .200)), (1.06, .150), .012, .050)
    plate = [(-.50, .262), (-.08, .262), (-.08, .166), (.08, .166), (.08, .262), (.78, .262), (.80, .240), (.78, .150), (.44, .150), (.44, .192), (.38, .192), (.38, .150), (-.48, .150), (-.505, .175)]
    p["clad"] = paper_plate("GFS_ReceiverFold", plate, .080, .092, ((-.50, .16), (.80, .25)))
    gp = [(-.150, .120), (.100, .120), (.110, -.020), (.090, -.180), (-.140, -.180), (-.155, -.020)]
    gpl = paper_plate("GFS_GripFold", gp, .062, .072, ((-.15, -.18), (.11, .12)))
    p["grip"] = gpl
    p["shroud"] = shroud("GFS_Shroud", .985, 1.140, .294, .058)
    p["boat"] = boat("GFS_MagBoat", "Stinger_Mag", lambda P: min(q.z for q in P) < -.4, -.500, y_half=.056)
    mp = [(-.170, -.230), (.040, -.230), (.044, -.490), (-.176, -.490)]
    p["magfold"] = paper_plate("GFS_MagFold", mp, .048, .058, ((-.17, -.49), (.044, -.23)), bone="Mag")
    p["foil"] = [foil_on("GFS_FoilRec", p["clad"], .40, .230, length=.07), foil_on("GFS_FoilStock", st, -.66, .300, length=.06)]
    tables = {"Stinger_Receiver": IV_TABLE, "Stinger_Grip": INK_TABLE, "Stinger_Mag": INK_TABLE, "Stinger_Sights": INK_TABLE}
    tables.update({n: PEW_TABLE for n in ("Stinger_Barrel", "Stinger_Bolt", "Stinger_ChargingHandle", "Stinger_Trigger",
                                          "Stinger_FireSelector", "Stinger_CharmLoop")})
    return p, HIDE, tables

def gf2_ghost():
    """Pistol: slide moves over the internal barrel and the magazine sits in
    the grip, so slide / frame / grip stay stock in ivory / ink with folded
    paper cladding (the slide's rides the Slide bone); the suppressor becomes
    a folded paper body with a wave panel, foil bands and a twisted cap."""
    p = {}
    HIDE = ["Ghost_Pins", "Ghost_Suppressor", "Ghost_SlideNeon"]
    p["supcore"] = retain("Ghost_Suppressor", lambda P: max(q.x for q in P) < 1.14, "GFG_BarrelHardware")
    sup, suph = paper_solid("GFG_Suppressor", "Ghost_Suppressor", lambda P: min(q.x for q in P) > 1.10,
                            crease=((1.13, .24), (2.06, .36)), clip=((1.0, 0.0, -1.132),))
    pattern_window(sup, inset(suph, .045, clip=((1.0, 0.0, -1.28), (-1.0, 0.0, 1.98))), .094)   # 1.28 <= x <= 1.98
    p["sup"] = tri(sup)
    p["supcap"] = shroud("GFG_SupCap", 2.050, 2.120, .296, .074)
    p["bands"] = [foil_band("GFG_SupBand", 1.180, 1.200, "Ghost_Suppressor", .296, grow=.006)]
    sl = [(-.20, .380), (1.10, .380), (1.118, .356), (1.112, .252), (1.090, .240), (-.18, .240), (-.205, .262)]
    p["slide"] = paper_plate("GFG_SlideFold", sl, .066, .078, ((-.20, .25), (1.12, .37)), bone="Slide")
    top = [(-.10, .390), (.96, .390), (1.00, .384), (.96, .382), (-.08, .382)]
    p["slidetop"] = paper_plate("GFG_SlideBlade", [(x, z) for x, z in top], .020, .040, ((-.1, .386), (1.0, .386)), bone="Slide")
    fr = [(-.24, .228), (.32, .228), (.32, .176), (.49, .176), (.49, .228), (1.10, .228), (1.116, .210), (1.10, .110), (.70, .110), (.66, .118), (-.22, .118)]
    p["frame"] = paper_plate("GFG_FrameFold", fr, .062, .072, ((-.24, .12), (1.11, .22)))
    gp = [(-.230, .100), (.170, .100), (.170, -.020), (.240, -.100), (.200, -.360), (-.230, -.360), (-.248, -.100)]
    p["grip"] = paper_plate("GFG_GripFold", gp, .064, .074, ((-.24, -.36), (.25, .10)))
    p["boat"] = boat("GFG_MagBoat", "Ghost_Mag", lambda P: min(q.z for q in P) < -.39, -.394, y_half=.067)
    p["foil"] = [foil_on("GFG_FoilSlide", p["slide"], .80, .340, length=.07, bone="Slide"), foil_on("GFG_FoilSup", sup, 1.60, .360, length=.07)]
    tables = {"Ghost_Slide": IV_TABLE, "Ghost_Frame": INK_TABLE, "Ghost_Grip": INK_TABLE, "Ghost_Mag": INK_TABLE, "Ghost_Suppressor": PEW_TABLE}
    tables.update({n: PEW_TABLE for n in ("Ghost_Trigger", "Ghost_SlideCatch", "Ghost_MagRelease", "Ghost_CharmLoop")})
    return p, HIDE, tables

def gf2_classic():
    """Pistol: slide / frame / grip stay stock in ivory / ink with folded
    paper cladding (slide plates and a paper point ride the Slide bone)."""
    p = {}
    HIDE = ["Classic_Pins", "Classic_SlideNeon"]
    sl = [(-.25, .470), (.98, .470), (.996, .450), (.99, .300), (.96, .292), (-.24, .292), (-.262, .320)]
    p["slide"] = paper_plate("GFC_SlideFold", sl, .070, .082, ((-.25, .30), (.99, .46)), bone="Slide")
    top = [(-.12, .481), (.88, .481), (.92, .476), (.88, .474), (-.10, .474)]
    p["slidetop"] = paper_plate("GFC_SlideBlade", top, .020, .042, ((-.12, .478), (.92, .478)), bone="Slide")
    p["point"] = spike("GFC_Point", ((.97, .292), (1.000, .330)), (1.090, .300), .022, .0, bone="Slide")
    fr = [(-.27, .282), (.25, .282), (.25, .196), (.47, .196), (.47, .282), (.95, .282), (.966, .260), (.95, .172), (.70, .168), (-.25, .172)]
    p["frame"] = paper_plate("GFC_FrameFold", fr, .072, .082, ((-.27, .17), (.96, .28)))
    gp = [(-.260, .150), (.150, .150), (.150, .020), (.230, -.050), (.180, -.270), (-.250, -.270), (-.272, -.050)]
    p["grip"] = paper_plate("GFC_GripFold", gp, .066, .076, ((-.26, -.27), (.23, .15)))
    p["boat"] = boat("GFC_MagBoat", "Classic_Magazine", lambda P: min(q.z for q in P) < -.29, -.298, y_half=.070)
    p["foil"] = [foil_on("GFC_FoilSlide", p["slide"], .60, .420, length=.06, bone="Slide")]
    tables = {"Classic_Slide": IV_TABLE, "Classic_Frame": INK_TABLE, "Classic_Grip": INK_TABLE, "Classic_Magazine": INK_TABLE}
    tables.update({n: PEW_TABLE for n in ("Classic_Barrel", "Classic_Trigger", "Classic_SlideCatch", "Classic_MagRelease", "Classic_CharmLoop",
                                          "Classic_MagNeon")})
    return p, HIDE, tables

_GF2.update({"Stinger": gf2_stinger, "Ghost": gf2_ghost, "Classic": gf2_classic})
