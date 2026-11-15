"""Inkshift round two items (exec'd by model_inkshift_guns2.py)."""

def cyan_segments(prefix, target, x, z, length=.40, bone="Root"):
    """The broken cyan accent as raised glow inlays: one long segment and two
    short offset marks (the line's signature)."""
    out = []
    for i, (a, b, dz) in enumerate(((0.0, .58, 0.0), (.64, .78, -.004), (.84, 1.0, .004))):
        ln = inlay_line(f"{prefix}_Cyan{i}", target, [(x + length * a, z + dz), (x + length * b, z + dz)], w=.010, h=.003, mat=CYAN, bone=bone)
        if ln:
            out.append(ln)
    return out

def ik_grip(prefix, src, keep=lambda P: True):
    o, hull = armour_solid(prefix + "_Grip", src, keep, top=INDG, low=BLUE)
    band = clip_poly(clip_poly(hull_xz(src, keep, -.020), 0.0, -1.0, .080), 0.0, 1.0, .180)    # -.18 <= z <= .08
    pl = layer_plate(prefix + "_GripPlate", o, band, mat=WHITE)
    return [o, pl]

def ik_mag(prefix, src, keep_body, base_z, top_z=None):
    o, hull = armour_solid(prefix + "_Mag", src, keep_body, bone="Mag", top=BLUE, low=INDG)
    zs = [p[1] for p in hull]
    tz = top_z if top_z is not None else max(zs) - (max(zs) - min(zs)) * .35
    front = clip_poly(clip_poly(hull_xz(src, keep_body, -.018), 0.0, -1.0, tz), 0.0, 1.0, -(base_z + .03))
    pl = layer_plate(prefix + "_MagPlate", o, front, mat=WHITE) if len(front) >= 3 else None
    base = clip_poly(hull_xz(src, keep_body, .004), 0.0, -1.0, base_z)
    yh = max(abs(p.y) for p in comp_points(src, keep_body)) + .004
    b = None
    if len(base) >= 3:
        b = link(prefix + "_MagBase", solid_plate(base, 0, yh, ch=.004, mat=INDG, open_inner=True), "Mag")
        mirror_apply(b, merge=True)
    xs = [p[0] for p in hull]
    strip = [(min(xs) + .03, base_z + .012), (max(xs) - .03, base_z + .012), (max(xs) - .03, base_z + .020), (min(xs) + .03, base_z + .020)]
    cy = layer_plate(prefix + "_MagCyan", o, strip, mat=CYAN, lift=.004, rim=CYAN)
    return [o, pl, b, cy]

def ik_muzzle(prefix, x0, x1, zc, r, bone="Root"):
    rings = []
    L = x1 - x0
    for f, rr in ((0, 1.0), (.25, 1.12), (.27, 1.0), (.55, 1.06), (.57, .94), (.85, .96), (1.0, .74)):
        rings.append([(x0 + L * f, r * rr * math.cos(math.radians(45 * i)), zc + r * rr * math.sin(math.radians(45 * i))) for i in range(8)])
    o = link(prefix + "_Shroud", loft3(rings, [WHITE, BLUE, BLUE, BLUE, WHITE, WHITE, WHITE, WHITE], cap_mat=CHAR), bone)
    for pp in o.data.polygons:
        xs = [o.data.vertices[i].co.x for i in pp.vertices]
        if max(xs) - min(xs) < .012:
            pp.material_index = INKL
    t = link(prefix + "_MuzzleTab", solid_plate([(x1 - .08, zc + r * .9), (x1 - .02, zc + r * .9), (x1 + .01, zc + r * 1.3), (x1 - .05, zc + r * 1.35)],
                                                -.010, .010, ch=.002, mat=VERM), bone)
    return o, t

GRA_T = [MATS[CHAR]] * 6 + [MATS[CYAN], EXTRA["Brass"]]

# ------------------------------------------------------------------ guns
def ik2_odin():
    p = {}
    HIDE = ["Odin_Grip", "Odin_Stock", "Odin_Pins", "Odin_Neon"]
    p["stock"] = frame_stock("IKD_Stock", "Odin_Stock", inset=.085, open_x=-.50)[0]
    p["grip"] = ik_grip("IKD", "Odin_Grip")
    rec = bpy.data.objects["Odin_Receiver"]
    p["lower"] = layer_plate("IKD_LowerArmour", rec, [(-.15, .290), (.70, .290), (.76, .262), (.70, .180), (-.10, .180), (-.15, .210)], mat=BLUE)
    p["lower2"] = layer_plate("IKD_LowerShadow", p["lower"], [(-.10, .232), (.66, .232), (.70, .214), (.66, .190), (-.06, .190)], mat=INDG, lift=.004)
    p["stripe"] = [layer_plate("IKD_Stripe1", rec, [(.48, .560), (.54, .560), (.58, .500), (.52, .500)], mat=VERM, lift=.004),
                   layer_plate("IKD_Stripe2", p["lower"], [(.56, .286), (.62, .286), (.66, .200), (.60, .200)], mat=VERM, lift=.004)]
    p["cyan"] = cyan_segments("IKD", rec, -.12, .520, length=.52)
    p["fins"] = fin("IKD_Fins", .74, .545, .086, .26, .060)
    p["lines"] = [panel_line("IKD_PL1", p["lower"], [(.20, .290), (.26, .180)]), panel_line("IKD_PL2", rec, [(-.15, .470), (.76, .470)])]
    box = bpy.data.objects["Odin_AmmoBox"]
    p["box"] = [layer_plate("IKD_BoxPlate", box, [(.66, .060), (1.26, .060), (1.26, -.100), (1.20, -.160), (.66, -.160)], mat=WHITE),
                layer_plate("IKD_BoxCyan", box, [(.70, -.300), (1.20, -.300), (1.20, -.290), (.70, -.290)], mat=CYAN, lift=.004, rim=CYAN)]
    for o in p["box"]:
        if o:
            pass
    p["flash"] = [flash("IKD_Flash1", rec, .10, .430, w=.12), flash("IKD_Flash2", p["stock"], -.80, .380, w=.12)]
    tables = {"Odin_Receiver": WHITE_T, "Odin_FeedCover": WHITE_T, "Odin_AmmoBox": BLUE_T, "Odin_Sights": GRA_T, "Odin_Barrel": SLATE_T,
              "Odin_Bolt": SLATE_T, "Odin_ChargingHandle": VERM_T, "Odin_Trigger": SLATE_T, "Odin_CharmLoop": SLATE_T}
    return p, HIDE, tables, ["IKD_Stock", "IKD_Grip", "IKD_LowerArmour"]

def ik2_phantom():
    p = {}
    HIDE = ["Phantom_Handguard", "Phantom_Stock", "Phantom_Grip", "Phantom_Mag", "Phantom_Suppressor", "Phantom_Neon"]
    hg, hgh = armour_solid("IKP_Handguard", "Phantom_Handguard", clip=((1.0, -1.0, -.65),))     # upper-back corner bevelled clear of the charging handle
    vents = [prism([(xa, .222), (xa + .060, .222), (xa + .075, .258), (xa + .015, .258)], .084, .3, floor=CHAR, side=WALL) for xa in (1.02, 1.12, 1.22)]
    cut(hg, vents, rim=.0018)
    p["hg"] = hg
    p["hglayer"] = layer_plate("IKP_HGArmour", hg, [(.98, .420), (1.40, .420), (1.50, .380), (1.40, .360), (1.02, .366)], mat=WHITE)
    p["hgglow"] = panel_line("IKP_HGGlow", hg, [(1.04, .300), (1.50, .300), (1.53, .292)], mat=CYAN, w=.007)
    sup, suph = armour_solid("IKP_Suppressor", "Phantom_Suppressor", top=WHITE, low=BLUE)
    p["sup"] = sup
    p["suptab"] = layer_plate("IKP_SupTab", sup, [(2.30, .420), (2.40, .420), (2.44, .400), (2.34, .400)], mat=VERM, lift=.004)
    p["supglow"] = panel_line("IKP_SupGlow", sup, [(1.80, .352), (2.40, .352)], mat=CYAN, w=.006)
    p["stock"] = frame_stock("IKP_Stock", "Phantom_Stock", inset=.070, open_x=-.42)[0]
    p["grip"] = ik_grip("IKP", "Phantom_Grip", lambda P: min(q.x for q in P) < 0)
    p["tg"] = retain("Phantom_Grip", lambda P: min(q.x for q in P) > .10, "IKP_TriggerGuard")
    p["mag"] = ik_mag("IKP", "Phantom_Mag", lambda P: min(q.z for q in P) < 0, -.228)
    p["magtop"] = retain("Phantom_Mag", lambda P: min(q.z for q in P) > .19, "IKP_MagTop", bone="Mag")
    rec = bpy.data.objects["Phantom_Receiver"]
    p["lower"] = layer_plate("IKP_LowerArmour", rec, [(.16, .300), (.46, .300), (.46, .175), (.16, .175)], mat=BLUE)
    p["cyan"] = cyan_segments("IKP", rec, .50, .290, length=.38)
    p["stripe"] = layer_plate("IKP_Stripe", hg, [(1.44, .420), (1.49, .420), (1.53, .330), (1.48, .330)], mat=VERM, lift=.004)
    p["fins"] = fin("IKP_Fins", 1.56, .425, .060, .20, .055)
    p["flash"] = [flash("IKP_Flash1", hg, 1.10, .390, w=.10), flash("IKP_Flash2", p["stock"], -.70, .360, w=.10)]
    tables = {"Phantom_Receiver": WHITE_T, "Phantom_Rail": GRA_T, "Phantom_Sights": GRA_T, "Phantom_Bolt": SLATE_T,
              "Phantom_ChargingHandle": VERM_T, "Phantom_FireSelector": SLATE_T, "Phantom_Trigger": SLATE_T, "Phantom_CharmLoop": SLATE_T}
    return p, HIDE, tables, ["IKP_Handguard", "IKP_Suppressor", "IKP_Stock", "IKP_Grip", "IKP_Mag"]

def ik2_stinger():
    p = {}
    HIDE = ["Stinger_Stock", "Stinger_Handguard", "Stinger_Pins", "Stinger_Neon"]
    p["stock"] = frame_stock("IKS_Stock", "Stinger_Stock", inset=.060, open_x=-.76)[0]
    hg, hgh = armour_solid("IKS_Handguard", "Stinger_Handguard")
    p["hg"] = hg
    p["hglayer"] = layer_plate("IKS_HGArmour", hg, [(.48, .254), (.74, .254), (.80, .226), (.74, .206), (.50, .210)], mat=WHITE)
    p["hgglow"] = panel_line("IKS_HGGlow", hg, [(.50, .160), (.78, .160)], mat=CYAN, w=.007)
    rec = bpy.data.objects["Stinger_Receiver"]
    plate = [(.10, .262), (.36, .262), (.38, .200), (.38, .150), (.10, .150)]
    p["lower"] = layer_plate("IKS_LowerArmour", rec, plate, mat=BLUE)
    p["rear"] = layer_plate("IKS_RearArmour", rec, [(-.50, .262), (-.10, .262), (-.10, .160), (-.48, .160)], mat=BLUE)
    p["cyan"] = cyan_segments("IKS", rec, .28, .372, length=.46)
    p["stripe"] = layer_plate("IKS_Stripe", rec, [(-.16, .262), (-.12, .262), (-.12, .160), (-.16, .160)], mat=VERM, lift=.004)
    grip = bpy.data.objects["Stinger_Grip"]
    gp = clip_poly(clip_poly(hull_xz("Stinger_Grip", lambda P: min(q.x for q in P) < 0, -.020), 0.0, -1.0, .100), 0.0, 1.0, .170)
    p["grip"] = layer_plate("IKS_GripPlate", grip, gp, mat=WHITE)
    mp = [(-.170, -.240), (.040, -.240), (.044, -.480), (-.176, -.480)]
    p["magplate"] = link("IKS_MagPlate", solid_plate(mp, .046, .058, ch=.003, mat=WHITE), "Mag")
    mirror_apply(p["magplate"])
    p["muzzle"] = ik_muzzle("IKS", .985, 1.150, .294, .056)
    p["fins"] = fin("IKS_Fins", .80, .262, .084, .16, .045)
    p["flash"] = [flash("IKS_Flash1", rec, .30, .300, w=.10), flash("IKS_Flash2", p["stock"], -1.10, .330, w=.12)]
    tables = {"Stinger_Receiver": WHITE_T, "Stinger_Grip": INDG_T, "Stinger_Mag": BLUE_T, "Stinger_Sights": GRA_T, "Stinger_Barrel": SLATE_T,
              "Stinger_Bolt": SLATE_T, "Stinger_ChargingHandle": VERM_T, "Stinger_FireSelector": SLATE_T, "Stinger_Trigger": SLATE_T,
              "Stinger_CharmLoop": SLATE_T}
    return p, HIDE, tables, ["IKS_Stock", "IKS_Handguard", "IKS_Shroud"]

def ik2_shorty():
    p = {}
    HIDE = ["Shorty_Barrels", "Shorty_Neon"]
    p["kept"] = retain("Shorty_Barrels", lambda P: max(q.x for q in P) < .66 or min(q.x for q in P) > .98, "IKH_BarrelHardware", bone="Barrels")
    sh, shh = armour_solid("IKH_Shroud", "Shorty_Barrels", lambda P: .63 < min(q.x for q in P) < .66 and max(q.x for q in P) > 1.0, bone="Barrels")
    p["shroud"] = sh
    p["shlayer"] = layer_plate("IKH_ShroudArmour", sh, [(.68, .310), (1.04, .310), (1.12, .270), (1.04, .246), (.70, .250)], mat=WHITE)
    p["shglow"] = panel_line("IKH_ShroudGlow", sh, [(.70, .150), (1.18, .150)], mat=CYAN, w=.007)
    p["shtab"] = layer_plate("IKH_ShroudTab", sh, [(1.16, .210), (1.24, .210), (1.24, .170), (1.18, .170)], mat=VERM, lift=.004)
    p["fins"] = fin("IKH_Fins", 1.10, .312, .070, .18, .050, bone="Barrels")
    fr = bpy.data.objects["Shorty_Frame"]
    bm = solid_plate([(-.08, .320), (.50, .320), (.52, .300), (.52, .180), (-.06, .180), (-.085, .210)], .090, .100, ch=.003, mat=BLUE)
    for f in bm.faces:
        if f.material_index == EDGE:
            f.material_index = INKL
    p["lower"] = link("IKH_FrameArmour", bm)
    mirror_apply(p["lower"])
    p["cyan"] = cyan_segments("IKH", p["lower"], -.04, .290, length=.42)
    p["stripe"] = layer_plate("IKH_Stripe", p["lower"], [(.40, .318), (.44, .318), (.48, .184), (.44, .184)], mat=VERM, lift=.004)
    grip = bpy.data.objects["Shorty_Grip"]
    gp = clip_poly(clip_poly(hull_xz("Shorty_Grip", lambda P: max(q.z for q in P) > 0, -.020), 0.0, -1.0, .060), 0.0, 1.0, .220)
    p["grip"] = layer_plate("IKH_GripPlate", grip, gp, mat=WHITE)
    p["flash"] = [flash("IKH_Flash1", sh, .76, .290, w=.10), flash("IKH_Flash2", p["lower"], .02, .200, w=.10)]
    tables = {"Shorty_Frame": WHITE_T, "Shorty_Grip": INDG_T, "Shorty_BarrelNeon": [MATS[CYAN]] * 8,
              "Shorty_BreechLatch": VERM_T, "Shorty_Trigger": SLATE_T, "Shorty_CharmLoop": SLATE_T}
    return p, HIDE, tables, ["IKH_Shroud", "IKH_FrameArmour"]

_IK2.update({"Odin": ik2_odin, "Phantom": ik2_phantom, "Stinger": ik2_stinger, "Shorty": ik2_shorty})
