"""Frost canister (thrown ice grenade), ability rework v03. The tall, pale partner of Molly.

Runs ONLY inside the live Blender MCP session, after rw_core and the Molly module (shared helpers):
    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_MollyFrost")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/Molly/molly_build.py").read())
    exec(open(r"<repo>/art-source/abilities/Rework/v03/Frost/frost_build.py").read())
    result = frost_build(S)

Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. Origin = bounding-box centre (thrown prop).
Shape: a tall pale octagonal cage with full-height slots on every facet but the back; a cold core shows
through them. Same family as Molly: dark flared foot, charcoal lid with a shadow lip, long slotted latch
down the back hinged at a heel and pinned at the fuse head, faceted pull ring, framed thumb pad.
"""

FXB, FXF, FYH, FC = -0.1, 0.1, 0.108, 0.042   # back plane (vertical), front, half width, corner cuts
FZ0, FZW, FZL, FZS = -0.2, 0.15, 0.138, 0.18      # casing bottom, wall top, lid lip underside, deck
FTAP, FSH, FWALL = 0.008, 0.025, 0.014            # front/side taper, shoulder inset, casing wall
F_HX, F_HZ = FXB - 0.024, -0.17                   # latch hinge axis (along Y)
F_PX, F_PZ = F_HX + 0.006, 0.205                  # pull-pin axis (along Y)
F_LX, F_FZ = -0.06, 0.242                        # fuse light x, fuse-head top
F_DX, F_DY = 0.035, 0.055                         # arming pad centre (front-left of the deck)
F_VX, F_VY = 0.033, 0.0                        # relief valve (front-right of the deck)


def fx_at(z):
    return FXF - (z - FZ0) * FTAP / (FZW - FZ0)


def fy_at(z):
    return FYH - (z - FZ0) * FTAP / (FZW - FZ0)


def fring(z, t=0.0):
    c = FC + t * SQ
    yh = fy_at(z) + t
    return ring4(FXB - t, fx_at(z) + t, -yh, yh, (c, c, c, c))


def floft(name, t, z_lo=-0.4, z_hi=0.4):
    return m_loft(name, [(z_lo, fring(z_lo, t)), (z_hi, fring(z_hi, t))])


def facet_slot(name, i0, i1, z0, z1, hw, depth=0.03):
    """Cutter for a full-height slot with pointed ends, centred on facet (i0, i1) of fring(0)."""
    rg = fring(0.0)
    p, q = Vector(rg[i0]), Vector(rg[i1])
    m, u = (p + q) / 2, (q - p).normalized()
    n = Vector((u.y, -u.x))
    if n.dot(m) < 0:
        n = -n
    prof = [(0, z0), (hw, z0 + hw), (hw, z1 - hw), (0, z1), (-hw, z1 - hw), (-hw, z0 + hw)]
    mp = lambda a, zz, w: (m.x + u.x * a + n.x * w, m.y + u.y * a + n.y * w, zz)
    return m_loft(name, [(-depth, prof), (depth, prof)], mp)


def frost_build(S):
    rw_clear("Frost_")
    for e in [o for o in bpy.data.objects if o.name.startswith("Frost")]:
        bpy.data.objects.remove(e, do_unlink=True)
    C = rw_col(S, "Frost")

    def T(name, mesh, loc=(0, 0, 0)):
        return rw_obj(C, "Frost_tmp_" + name, mesh, None, loc)

    # 1 CASING: tall pale octagonal tube (back vertical, front and sides taper in), slots on 7 facets
    body = rw_obj(C, "Frost_Body", m_loft("Frost_Body", [(FZ0, fring(FZ0)), (FZL + 0.002, fring(FZL + 0.002))]), "Pale")
    rw_bool(body, T("cav", floft("Frost_tmp_cav", -FWALL)), "DIFFERENCE")
    for (i0, i1, hw) in ((1, 2, 0.027), (3, 4, 0.027), (7, 0, 0.027), (0, 1, 0.014), (2, 3, 0.014), (4, 5, 0.014), (6, 7, 0.014)):
        rw_bool(body, T("slot", facet_slot("Frost_tmp_slot", i0, i1, -0.165, 0.112, hw)), "DIFFERENCE")

    # 1b CLAMP BAND: charcoal strap round the cage below mid-height, open at the back where the latch runs
    band = rw_obj(C, "Frost_Band", m_loft("Frost_Band", [
        (-0.07, fring(-0.07, 0.002)), (-0.065, fring(-0.065, 0.009)), (-0.035, fring(-0.035, 0.009)),
        (-0.03, fring(-0.03, 0.002))]), "Body")
    rw_bool(band, T("bcav", floft("Frost_tmp_bcav", -0.006)), "DIFFERENCE")
    rw_bool(band, T("bcut", rw_hull("Frost_tmp_bcut", [(x, y, z) for x in (-0.4, FXB + 0.02) for y in (-0.4, 0.4)
                                                        for z in (-0.2, 0.1)])), "DIFFERENCE")
    rr = 1 / math.sqrt(2)
    for (i0, i1, ny) in ((5, 4, rr), (6, 7, -rr)):   # chamfer the band's two open ends on the back corner facets
        pts = [seg_at_x(fring(z, 0.009)[i0], fring(z, 0.009)[i1], FXB + 0.02) + (z,) for z in (-0.06, -0.04)]
        edge_cham(band.data, pts[0], pts[1], (-rr, ny, 0), (-1, 0, 0), 0.0035)

    # 2 CORE: the cold cell inside the cage, seen through the slots; stands in the foot
    rw_obj(C, "Frost_Core", m_loft("Frost_Core", [(FZ0 - 0.006, fring(FZ0 - 0.006, -FWALL - 0.008)),
                                                  (0.13, fring(0.13, -FWALL - 0.008))]), "Cold")

    # 3 FOOT: battered, flared dark collar; back heel carrying the hinge ears
    foot = rw_obj(C, "Frost_Foot", m_loft("Frost_Foot", [
        (-0.25, fring(-0.25, 0.013)), (-0.243, fring(-0.243, 0.02)),
        (-0.201, fring(-0.201, 0.006)), (-0.192, fring(-0.192, -0.004))]), "Dark")
    rw_bool(foot, T("heel", m_slab("Frost_tmp_heel", [(FXB + 0.006, -0.25), (FXB + 0.006, -0.195), (F_HX - 0.008, -0.195),
                                                       (F_HX - 0.022, -0.209), (F_HX - 0.022, -0.236), (F_HX - 0.012, -0.25)],
                                   -0.046, 0.046, 0.004, XZ_Y)), "UNION")
    ear_p = hull2d(oct2(F_HX, F_HZ, 0.017) + [(F_HX - 0.017, -0.2), (FXB + 0.006, -0.2), (FXB + 0.006, -0.157)])
    for y0, y1 in ((0.028, 0.046), (-0.046, -0.028)):
        rw_bool(foot, T("ear", m_slab("Frost_tmp_ear", ear_p, y0, y1, 0.003, XZ_Y)), "UNION")

    # 4 LID: charcoal cap whose lip overhangs the casing by 0.006; flat deck
    lid = rw_obj(C, "Frost_Lid", m_loft("Frost_Lid", [
        (FZL, fring(FZL, 0.006)), (FZL + 0.01, fring(FZL + 0.01, 0.006)), (FZS, fring(FZW, -FSH))]), "Body")

    # 5 ARMING HEAD: stepped two-tier block (Molly's is a single raked block). It overhangs the back shoulder;
    # a fork slot in its back takes the latch tongue and the pull pin runs through both cheeks. Light set low.
    fh = rw_obj(C, "Frost_FuseHead", m_slab("Frost_FuseHead", [
        (0.0, 0.176), (0.0, 0.214), (-0.008, 0.222), (-0.14, 0.222), (-0.148, 0.214), (-0.148, 0.196), (-0.075, 0.176)],
        -0.045, 0.045, 0.005, XZ_Y), "Panel")
    t2 = ring4(-0.095, -0.025, -0.032, 0.032, (0.008, 0.008, 0.008, 0.008))
    rw_bool(fh, T("tier", m_loft("Frost_tmp_tier", [(0.218, t2), (F_FZ - 0.006, t2), (F_FZ, poly_offset(t2, 0.005))])), "UNION")
    rw_bool(fh, T("fork", rw_hull("Frost_tmp_fork", [(x, y, z) for x in (-0.3, -0.103) for y in (-0.025, 0.025)
                                                      for z in (0.0, 0.4)])), "DIFFERENCE")
    bez = rw_obj(C, "Frost_FuseBezel", m_loft("Frost_FuseBezel", [
        (F_FZ - 0.003, oct2(F_LX, 0, 0.022)), (F_FZ + 0.004, oct2(F_LX, 0, 0.022)), (F_FZ + 0.007, oct2(F_LX, 0, 0.019))]), "Dark")
    rw_bool(bez, T("hole", m_loft("Frost_tmp_hole", [(0.1, oct2(F_LX, 0, 0.0155)), (0.4, oct2(F_LX, 0, 0.0155))])), "DIFFERENCE")
    rw_obj(C, "Frost_Fuse_Energy", m_loft("Frost_Fuse_Energy", [
        (F_FZ - 0.005, oct2(F_LX, 0, 0.014)), (F_FZ + 0.007, oct2(F_LX, 0, 0.014)), (F_FZ + 0.01, oct2(F_LX, 0, 0.011))]), "Energy")

    # 6 LATCH: long slotted lever down the back; knuckle on the heel hinge, tongue pinned between the ears
    L = (F_HX, 0, F_HZ)
    lat = rw_obj(C, "Frost_Latch", m_loft("Frost_Latch", [
        (-0.025, rw_ngon(0.011, 8)), (-0.021, rw_ngon(0.015, 8)), (0.021, rw_ngon(0.015, 8)), (0.025, rw_ngon(0.011, 8))],
        XZ_Y), "Metal", L)
    TZ = F_PZ - F_HZ
    a0, a1 = -0.003, 0.015    # the arm sits forward of the hinge axis, close over the back face
    rw_bool(lat, T("arm", m_slab("Frost_tmp_arm", [(0.025, 0.0), (0.025, 0.026), (0.04, 0.07), (0.04, TZ - 0.08), (0.026, TZ - 0.025),
                                                    (-0.026, TZ - 0.025), (-0.04, TZ - 0.08), (-0.04, 0.07), (-0.025, 0.026), (-0.025, 0.0)],
                                   a0 - 0.002, a1 - 0.002, 0.0045, YZ_X), L), "UNION")
    rw_bool(lat, T("tng", m_slab("Frost_tmp_tng", [(0.021, TZ - 0.04), (0.021, TZ - 0.002), (0.013, TZ + 0.006), (-0.013, TZ + 0.006),
                                                    (-0.021, TZ - 0.002), (-0.021, TZ - 0.04)], a0 - 0.002, a1 - 0.002, 0.0045, YZ_X), L), "UNION")
    sl = [(0, 0.09), (0.012, 0.106), (0.012, 0.27), (0, 0.286), (-0.012, 0.27), (-0.012, 0.106)]
    rw_bool(lat, T("lslot", m_loft("Frost_tmp_lslot", [(-0.05, sl), (0.05, sl)], YZ_X), L), "DIFFERENCE")
    rw_obj(C, "Frost_HingePin", m_loft("Frost_HingePin", [
        (-0.051, rw_ngon(0.007, 8)), (-0.048, rw_ngon(0.010, 8)), (-0.045, rw_ngon(0.010, 8)), (-0.045, rw_ngon(0.0062, 8, 0)),
        (0.045, rw_ngon(0.0062, 8, 0)), (0.045, rw_ngon(0.010, 8)), (0.048, rw_ngon(0.010, 8)), (0.051, rw_ngon(0.007, 8))],
        XZ_Y), "Metal", L)

    # 7 PULL PIN: shaft through ears + tongue, collar on the right, faceted ring swept out to the back-left
    P0 = (F_PX, 0, F_PZ)
    pin = rw_obj(C, "Frost_Pin", m_loft("Frost_Pin", [
        (-0.057, rw_ngon(0.0075, 8)), (-0.054, rw_ngon(0.0095, 8)), (-0.044, rw_ngon(0.0095, 8)),
        (-0.044, rw_ngon(0.0062, 8, 0)), (0.065, rw_ngon(0.0062, 8, 0))], XZ_Y), "Accent", P0)
    bm = bmesh.new()
    N, M, RC, RB, YA = 10, 6, 0.033, 0.0065, 0.059
    rows = []
    for i in range(N):
        ph = 2 * math.pi * i / N
        rad = Vector((0, math.cos(ph), math.sin(ph)))
        ctr = Vector((0, YA + RC, 0)) + rad * RC
        rows.append([bm.verts.new(ctr + (rad * math.cos(2 * math.pi * k / M + math.pi / M) + Vector((1, 0, 0))
                                         * math.sin(2 * math.pi * k / M + math.pi / M)) * RB) for k in range(M)])
    for i in range(N):
        a, b = rows[i], rows[(i + 1) % N]
        for k in range(M):
            bm.faces.new((a[k], a[(k + 1) % M], b[(k + 1) % M], b[k]))
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, YA, 0)) @ Matrix.Rotation(math.radians(-40), 4, "X")
                        @ Matrix.Translation((0, -YA, 0)), verts=bm.verts)
    rw_bool(pin, T("ring", _rw_finish(bm, "Frost_tmp_ring"), P0), "UNION")

    # 9 RELIEF VALVE: octagonal diffuser on the front-right of the deck, four vent windows under its cap
    vz = FZS - 0.003
    val = rw_obj(C, "Frost_Valve", m_loft("Frost_Valve", [
        (vz, oct2(F_VX, F_VY, 0.027)), (vz + 0.012, oct2(F_VX, F_VY, 0.027)), (vz + 0.016, oct2(F_VX, F_VY, 0.021)),
        (vz + 0.036, oct2(F_VX, F_VY, 0.021)), (vz + 0.036, oct2(F_VX, F_VY, 0.025)), (vz + 0.043, oct2(F_VX, F_VY, 0.025)),
        (vz + 0.048, oct2(F_VX, F_VY, 0.019))]), "Metal")
    for rot in (0, 90):
        vc = T("vent", rw_cham_box("Frost_tmp_vent", 0.08, 0.009, 0.014, 0.001), (F_VX, F_VY, vz + 0.026))
        vc.rotation_euler = (0, 0, math.radians(rot))
        rw_bool(val, vc, "DIFFERENCE")

    for o in [o for o in bpy.data.objects if o.name.startswith("Frost_tmp_")]:
        m = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if m and m.users == 0:
            bpy.data.meshes.remove(m)

    # one material per part, no slivers
    for o in [o for o in C.objects if o.type == "MESH"]:
        me = o.data
        mat = next(m for m in me.materials if m)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        me.materials.append(mat)
        for p in me.polygons:
            p.material_index = 0
            p.use_smooth = False
        me.update()

    # centre on the bounding box
    bpy.context.view_layer.update()
    lo, hi = rw_bounds("Frost_")
    c = (lo + hi) / 2
    moving = {"Frost_Latch", "Frost_HingePin", "Frost_Pin"}
    for o in [o for o in C.objects if o.type == "MESH"]:
        if o.name in moving or o.location.length > 0 or any(o.rotation_euler):
            o.location -= c
        else:
            o.data.transform(Matrix.Translation(-c))
    rw_empty(C, "Frost_Handle", (0, 0, 0), size=0.04)
    rw_empty(C, "Frost_Fuse", Vector((F_LX, 0, F_FZ + 0.01)) - c, size=0.03, kind="SINGLE_ARROW")
    rw_empty(C, "Frost_LatchPivot", Vector(L) - c, rot=(0, 0, 180), size=0.04)
    rw_empty(C, "Frost_PinOut", Vector((F_PX, 0.14, F_PZ)) - c, size=0.03)
    scale_col(C, MOLLY_SCALE)   # same scale family as Molly
    bpy.context.view_layer.update()
    lo, hi = rw_bounds("Frost_")
    return {"shift": [round(v, 4) for v in c], "size": [round(v, 4) for v in (hi - lo)]}


FROST_SEATS = [("Frost_Body", "Frost_Foot"), ("Frost_Core", "Frost_Foot"), ("Frost_Lid", "Frost_Body"),
               ("Frost_FuseHead", "Frost_Lid"), 
               ("Frost_HingePin", "Frost_Foot"), ("Frost_HingePin", "Frost_Latch"), ("Frost_Pin", "Frost_FuseHead"),
               ("Frost_Pin", "Frost_Latch"), ("Frost_Fuse_Energy", "Frost_FuseHead"), ("Frost_FuseBezel", "Frost_FuseHead"),
               ("Frost_Valve", "Frost_Lid"), ("Frost_Band", "Frost_Body")]
