"""Build, validate, save (.blend), and render all 12 Strike Pack charms on Blender port 9100."""

import importlib
import math
import os
import sys
import traceback

import bmesh
from mathutils import Euler, Matrix, Vector

HERE = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\tools\blender\charms"
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import charm_kit as K  # noqa: E402
importlib.reload(K)

STRIKE_ORDER = [
    "DraftTicket",
    "BrassBullet",
    "DogTags",
    "FragPin",
    "MiniHelmet",
    "TargetPlate",
    "FragGrenade",
    "MicroBlade",
    "MoltenCore",
    "GlitchDie",
    "CrownTrophy",
    "AceSkull",
]


def build_DraftTicket(coll):
    mat_gold = K.make_material("Ticket_Gold", "#F2BE38", "Metal", roughness=0.26, metallic=0.88)
    mat_dark = K.make_material("Ticket_Dark", "#2E3545", "SmoothPlastic", roughness=0.42)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    K.add_chain(coll, "DraftTicket", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    # Notched ticket stub hanging vertically/slightly diagonal (0.21 wide x 0.145 tall)
    z_top, z_bot = -0.145, -0.310
    zm = (z_top + z_bot) * 0.5
    notch = [
        (-0.105, z_top), (0.105, z_top),
        (0.105, zm + 0.025), (0.086, zm + 0.012), (0.086, zm - 0.012), (0.105, zm - 0.025),
        (0.105, z_bot), (-0.105, z_bot),
        (-0.105, zm - 0.025), (-0.086, zm - 0.012), (-0.086, zm + 0.012), (-0.105, zm + 0.025),
    ]
    K.add_layered_prism_y(bm, notch, y_half=0.019, cham_y=0.004, cham_in=0.04, mat_idx=0)
    # Recessed charcoal ticket center plate
    panel = [
        (-0.080, z_top - 0.016), (0.080, z_top - 0.016),
        (0.080, z_bot + 0.016), (-0.080, z_bot + 0.016),
    ]
    K.add_prism_y(bm, panel, -0.022, 0.022, mat_idx=1)
    # Raised gold Draft Duels double-slash mark on front & back
    for sx in (-0.026, 0.012):
        slash = [
            (sx - 0.014, z_bot + 0.036), (sx + 0.004, z_bot + 0.036),
            (sx + 0.030, z_top - 0.036), (sx + 0.012, z_top - 0.036),
        ]
        K.add_prism_y(bm, slash, -0.026, 0.026, mat_idx=0)

    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.022, 0.016, 0.005), -0.155, K.cham_rect_pts(0, 0, 0.017, 0.013, 0.004), -0.124, mat_idx=2)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("DraftTicket_Body", bm, [mat_gold, mat_dark, mat_chain], coll, union=True)


def build_BrassBullet(coll):
    mat_brass = K.make_material("Bullet_Brass", "#EBB844", "Metal", roughness=0.25, metallic=0.90)
    mat_copper = K.make_material("Bullet_Copper", "#D46E3A", "Metal", roughness=0.26, metallic=0.88)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    K.add_chain(coll, "BrassBullet", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    # 8-sided rifle cartridge hanging tip-down (-Z)
    # Extractor rim at top -> groove -> straight case -> neck shoulder -> copper ogive -> sharp point
    segs = 8
    rot = math.pi / 8
    # Build as single closed multi-ring loft in bmesh (zero internal boolean splits!)
    profile = [
        (-0.142, 0.030, 2),   # cap top bevel
        (-0.146, 0.041, 0),   # extractor rim top
        (-0.160, 0.041, 0),   # extractor rim bottom
        (-0.166, 0.032, 0),   # extractor groove
        (-0.174, 0.040, 0),   # case head
        (-0.268, 0.039, 0),   # case body
        (-0.292, 0.028, 0),   # shoulder taper
        (-0.310, 0.028, 0),   # case neck
        (-0.312, 0.026, 1),   # copper bullet base
        (-0.358, 0.022, 1),   # copper mid ogive
        (-0.394, 0.006, 1),   # pointed tip facet
    ]
    rings = []
    for pz, pr, _ in profile:
        rings.append([bm.verts.new((px, py, pz)) for px, py in K.ngon_pts(0, 0, pr, segs, rot)])
    bm.faces.new(rings[0]).material_index = 2
    bm.faces.new(list(reversed(rings[-1]))).material_index = 1
    for r_i in range(len(rings) - 1):
        rA, rB = rings[r_i], rings[r_i + 1]
        m_idx = profile[r_i + 1][2]
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new([rA[i], rB[i], rB[j], rA[j]])
            f.material_index = m_idx
            f.smooth = False
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.020, 0.015, 0.005), -0.148, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.125, mat_idx=2)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("BrassBullet_Body", bm, [mat_brass, mat_copper, mat_chain], coll, union=True)


def build_DogTags(coll):
    mat_steel = K.make_material("Tag_Steel", "#B4BECE", "Metal", roughness=0.28, metallic=0.88)
    mat_dark = K.make_material("Tag_Dark", "#323A4A", "SmoothPlastic", roughness=0.44)
    mat_gold = K.make_material("Tag_Gold", "#EBB838", "Metal", roughness=0.26, metallic=0.90)
    K.add_chain(coll, "DogTags", mat_steel, bottom_z=-0.106)

    bm = bmesh.new()
    # Two splayed chamfered steel tags fanning from a central top swivel shackle
    tag_pts = K.cham_rect_pts(0, 0, 0.055, 0.086, 0.017)
    for ang_deg, y_off, z_off, accent_mat in ((-13, -0.012, -0.244, 2), (14, 0.012, -0.254, 1)):
        xf = Matrix.Translation((0.0, y_off, z_off)) @ Matrix.Rotation(math.radians(ang_deg), 4, "Y") @ Matrix.Rotation(math.pi / 2, 4, "X")
        K.add_prism_z(bm, tag_pts, -0.008, 0.008, mat_idx=0, xform=xf)
        # Seated dark/gold inner badge stripe
        stripe = K.cham_rect_pts(0, -0.018, 0.035, 0.042, 0.008)
        K.add_prism_z(bm, stripe, -0.010, 0.010, mat_idx=accent_mat, xform=xf)
        # Top reinforced eyelet tab on each tag feeding into the shared swivel clip
        tab = K.cham_rect_pts(0, 0.072, 0.018, 0.024, 0.005)
        K.add_prism_z(bm, tab, -0.010, 0.010, mat_idx=0, xform=xf)

    # Machined split-ring swivel clamp hugging both tag top tabs cleanly
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.025, 0.022, 0.007), -0.174, -0.146, mat_idx=0)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.022, 0.018, 0.006), -0.148, K.cham_rect_pts(0, 0, 0.016, 0.013, 0.004), -0.123, mat_idx=0)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)
    K.bm_to_object("DogTags_Body", bm, [mat_steel, mat_dark, mat_gold], coll, union=True)


def build_FragPin(coll):
    mat_steel = K.make_material("Pin_Steel", "#4E586B", "Metal", roughness=0.34, metallic=0.84)
    mat_brass = K.make_material("Pin_Brass", "#F0BC3A", "Metal", roughness=0.25, metallic=0.90)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    K.add_chain(coll, "FragPin", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    # Chunky 8-sided brass pull ring on top + angled grenade spoon lever hanging below
    ring_cz = -0.194
    K.add_ring_y(bm, 0.0, ring_cz, r_in=0.035, r_out=0.055, n=8, y_half=0.012, cham=0.004, rot=math.pi / 8, mat_idx=1)
    # Flush steel swivel clamp hugging top flat of the brass ring
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.021, 0.016, 0.005), -0.160, -0.138, mat_idx=2)
    # Angled tactical grenade spoon lever hanging from the ring pin hinge
    spoon = [
        (-0.022, -0.198), (0.022, -0.198),
        (0.034, -0.278), (0.026, -0.358),
        (0.006, -0.375), (-0.014, -0.355),
        (-0.010, -0.273),
    ]
    K.add_layered_prism_y(bm, spoon, y_half=0.018, cham_y=0.004, cham_in=0.08, mat_idx=0)
    # Brass pin hinge collar locking spoon cleanly to pull-ring bottom
    K.add_prism_y(bm, K.ngon_pts(0.0, -0.236, 0.019, 6), -0.024, 0.024, mat_idx=1)

    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.020, 0.015, 0.005), -0.144, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.122, mat_idx=2)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("FragPin_Body", bm, [mat_steel, mat_brass, mat_chain], coll, union=True)


def build_MiniHelmet(coll):
    mat_slate = K.make_material("Helm_Slate", "#465066", "SmoothPlastic", roughness=0.40)
    mat_gold = K.make_material("Helm_Gold", "#EBB838", "Metal", roughness=0.26, metallic=0.88)
    mat_neon = K.make_material("Helm_Neon", "#3FE0F2", "Neon", roughness=0.2, emission_strength=3.2)
    K.add_chain(coll, "MiniHelmet", mat_gold, bottom_z=-0.106)

    bm = bmesh.new()
    cz = -0.252
    rot = math.pi / 8
    # Faceted octagonal crown dome (3 stepped tapers)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.096, 8, rot), cz - 0.025, K.ngon_pts(0, 0, 0.094, 8, rot), cz + 0.032, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.094, 8, rot), cz + 0.028, K.ngon_pts(0, 0, 0.068, 8, rot), cz + 0.078, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.068, 8, rot), cz + 0.074, K.ngon_pts(0, 0, 0.034, 8, rot), cz + 0.096, mat_idx=0)

    # Swept angular ear-to-cheek armor wings tapering down into chin guard (replaces boxy slabs)
    cheek_poly = [
        (0.062, cz + 0.020), (-0.062, cz + 0.020),
        (-0.088, cz - 0.028), (-0.056, cz - 0.085),
        (0.042, cz - 0.074), (0.072, cz - 0.020),
    ]
    # Extrude swept left/right cheek-ear plates along X
    for sx in (-1, 1):
        x_in, x_out = (0.050, 0.096) if sx > 0 else (-0.096, -0.050)
        v_in = [bm.verts.new((x_in, py, pz)) for py, pz in cheek_poly]
        v_out = [bm.verts.new((x_out * 0.92, py * 0.88, pz + 0.005)) for py, pz in cheek_poly]
        if sx < 0:
            v_in.reverse()
            v_out.reverse()
        bm.faces.new(list(reversed(v_in))).material_index = 0
        bm.faces.new(v_out).material_index = 0
        for i in range(len(v_in)):
            j = (i + 1) % len(v_in)
            f = bm.faces.new([v_in[i], v_in[j], v_out[j], v_out[i]])
            f.material_index = 0
            f.smooth = False

    # Tapered front chin mandible bar connecting both cheek wings cleanly
    K.add_frustum_z(bm, K.cham_rect_pts(0, -0.058, 0.052, 0.032, 0.012), cz - 0.084, K.cham_rect_pts(0, -0.064, 0.066, 0.026, 0.010), cz - 0.038, mat_idx=0)
    # Contoured octagonal wrap-around brow visor hood (no square corners sticking out!)
    brow_arc = [
        (-0.088, -0.048), (-0.046, -0.102), (0.046, -0.102), (0.088, -0.048),
        (0.064, -0.028), (0.030, -0.066), (-0.030, -0.066), (-0.064, -0.028),
    ]
    K.add_frustum_z(bm, brow_arc, cz + 0.018, [(x * 0.90, y * 0.92) for x, y in brow_arc], cz + 0.044, mat_idx=0)
    # Recessed slate backing behind visor so neon wraps cleanly with zero gaps
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.086, 8, rot), cz - 0.045, K.ngon_pts(0, 0, 0.088, 8, rot), cz + 0.025, mat_idx=0)

    # Gold tactical NVG bridge mount crowning forehead up into the ferrule
    K.add_frustum_z(bm, K.cham_rect_pts(0, -0.016, 0.026, 0.038, 0.008), cz + 0.072, K.cham_rect_pts(0, -0.008, 0.019, 0.020, 0.005), -0.125, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("MiniHelmet_Body", bm, [mat_slate, mat_gold], coll, union=True)

    # Contoured wrap-around glowing cyan visor seated flush under the brow hood
    bm_vis = bmesh.new()
    ang_pts = [
        (-0.074, -0.066), (-0.036, -0.098), (0.036, -0.098), (0.074, -0.066),
        (0.056, -0.052), (0.026, -0.078), (-0.026, -0.078), (-0.056, -0.052),
    ]
    K.add_frustum_z(bm_vis, ang_pts, cz - 0.038, [(x * 1.03, y * 1.02) for x, y in ang_pts], cz + 0.024, mat_idx=0)
    K.bm_to_object("MiniHelmet_Neon", bm_vis, [mat_neon], coll, union=False)


def build_TargetPlate(coll):
    mat_white = K.make_material("Target_White", "#E2E8F2", "SmoothPlastic", roughness=0.35)
    mat_red = K.make_material("Target_Red", "#ED3244", "SmoothPlastic", roughness=0.34)
    mat_metal = K.make_material("Chain_Metal", "#8D97A8", "Metal", roughness=0.30, metallic=0.86)
    K.add_chain(coll, "TargetPlate", mat_metal, bottom_z=-0.106)

    bm = bmesh.new()
    cz = -0.252
    # Keep top horizontal facet intact (pts[1]..pts[2]) so mount sits flush; place battle V-chip notch on lower-right rim (pts[7])!
    pts = K.ngon_pts(0, cz, 0.108, 8, math.pi / 8)
    x7, z7 = pts[7]
    pts[7] = (x7 * 0.72, cz + (z7 - cz) * 0.72)
    K.add_layered_prism_y(bm, pts, y_half=0.019, cham_y=0.004, cham_in=0.05, mat_idx=0, center_xz=(0.0, cz))

    K.add_ring_y(bm, 0.0, cz, r_in=0.048, r_out=0.072, n=8, y_half=0.024, cham=0.0, rot=math.pi / 8, mat_idx=1)
    K.add_prism_y(bm, K.ngon_pts(0, cz, 0.027, 8, math.pi / 8), -0.026, 0.026, mat_idx=1)

    # Wide steel mounting saddle straddling the intact top edge of the target disc (zero gap!)
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.025, 0.022, 0.006), -0.162, -0.138, mat_idx=2)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.022, 0.017, 0.005), -0.142, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.122, mat_idx=2)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("TargetPlate_Body", bm, [mat_white, mat_red, mat_metal], coll, union=True)


def build_FragGrenade(coll):
    mat_olive = K.make_material("Grenade_Olive", "#4E6856", "SmoothPlastic", roughness=0.42)
    mat_brass = K.make_material("Grenade_Brass", "#EEBA3A", "Metal", roughness=0.25, metallic=0.90)
    mat_steel = K.make_material("Chain_Metal", "#8D97A8", "Metal", roughness=0.30, metallic=0.86)
    K.add_chain(coll, "FragGrenade", mat_steel, bottom_z=-0.106)

    bm = bmesh.new()
    segs = 8
    rot = math.pi / 8
    profile = [
        (-0.162, 0.032, 1),   # brass fuze collar top
        (-0.190, 0.038, 1),   # fuze base
        (-0.200, 0.068, 0),   # upper shoulder
        (-0.225, 0.082, 0),   # upper rib
        (-0.235, 0.070, 0),   # upper groove
        (-0.245, 0.085, 0),   # equator rib
        (-0.268, 0.085, 0),   # equator rib bot
        (-0.278, 0.070, 0),   # lower groove
        (-0.288, 0.080, 0),   # lower rib
        (-0.315, 0.064, 0),   # base taper
        (-0.342, 0.028, 0),   # bottom cap
    ]
    rings = [[bm.verts.new((px, py, pz)) for px, py in K.ngon_pts(0, 0, pr, segs, rot)] for pz, pr, _ in profile]
    bm.faces.new(rings[0]).material_index = 1
    bm.faces.new(list(reversed(rings[-1]))).material_index = 0
    for r_i in range(len(rings) - 1):
        rA, rB = rings[r_i], rings[r_i + 1]
        m_idx = profile[r_i + 1][2]
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new([rA[i], rB[i], rB[j], rA[j]])
            f.material_index = m_idx
            f.smooth = False

    # Sculpted steel striker bridge clamping top of fuze & seamlessly launching the spoon lever
    spoon = [(0.012, -0.156), (0.062, -0.174), (0.095, -0.255), (0.082, -0.312), (0.068, -0.305), (0.078, -0.255), (0.050, -0.188), (0.012, -0.174)]
    K.add_prism_y(bm, spoon, -0.015, 0.015, mat_idx=2)
    K.add_prism_z(bm, K.cham_rect_pts(0.008, 0, 0.026, 0.018, 0.005), -0.172, -0.150, mat_idx=2)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.024, 0.019, 0.006), -0.168, K.cham_rect_pts(0, 0, 0.017, 0.013, 0.004), -0.123, mat_idx=2)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("FragGrenade_Body", bm, [mat_olive, mat_brass, mat_steel], coll, union=True)


def build_MicroBlade(coll):
    mat_steel = K.make_material("Blade_Steel", "#CBD5E6", "Metal", roughness=0.22, metallic=0.92)
    mat_grip = K.make_material("Blade_Grip", "#2E3545", "SmoothPlastic", roughness=0.45)
    mat_gold = K.make_material("Blade_Gold", "#EEBA3A", "Metal", roughness=0.26, metallic=0.88)
    K.add_chain(coll, "MicroBlade", mat_gold, bottom_z=-0.106)

    bm = bmesh.new()
    # Gold pommel cap at top -> faceted wrapped grip -> angled gold tsuba guard -> beveled tanto blade
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.020, 0.015, 0.005), -0.152, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.124, mat_idx=2)
    # Wrapped dark grip
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.018, 0.013, 0.005), -0.220, -0.148, mat_idx=1)
    # Gold crossguard collar
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.038, 0.020, 0.008), -0.236, -0.214, mat_idx=2)
    # Sharp faceted tanto blade with double bevel edge and chisel point
    blade = [
        (-0.022, -0.232), (0.022, -0.232),
        (0.022, -0.355), (0.002, -0.398),
        (-0.022, -0.375),
    ]
    K.add_layered_prism_y(bm, blade, y_half=0.010, cham_y=0.006, cham_in=0.35, mat_idx=0, center_xz=(0.0, -0.310))
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("MicroBlade_Body", bm, [mat_steel, mat_grip, mat_gold], coll, union=True)


def build_MoltenCore(coll):
    mat_dark = K.make_material("Forge_Dark", "#2E3442", "Metal", roughness=0.36, metallic=0.82)
    mat_steel = K.make_material("Forge_Steel", "#9AA4B6", "Metal", roughness=0.28, metallic=0.88)
    mat_neon = K.make_material("Magma_Neon", "#FF6424", "Neon", roughness=0.2, emission_strength=3.8)
    K.add_chain(coll, "MoltenCore", mat_steel, bottom_z=-0.106)

    cz = -0.252
    bm_core = bmesh.new()
    K.add_faceted_gem(bm_core, Vector((0, 0, cz)), 0.056, 0.056, 0.072, n_sides=6, mat_idx=0)
    K.bm_to_object("MoltenCore_Neon", bm_core, [mat_neon], coll, union=False)

    bm = bmesh.new()
    # Forged 3-ribbed angular cage (120 deg spacing, front open wide toward -Y!)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.052, 6, math.pi / 6), -0.168, K.ngon_pts(0, 0, 0.032, 6, math.pi / 6), -0.128, mat_idx=1)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.008, 6, math.pi / 6), -0.388, K.ngon_pts(0, 0, 0.050, 6, math.pi / 6), -0.338, mat_idx=1)
    for k in range(3):
        ang = math.pi / 6 + k * 2 * math.pi / 3
        rot = Matrix.Rotation(ang, 4, "Z")
        rib = [(0.032, -0.155), (0.048, -0.155), (0.104, cz + 0.025), (0.104, cz - 0.025),
               (0.048, -0.352), (0.032, -0.352), (0.084, cz - 0.020), (0.084, cz + 0.020)]
        K.add_prism_y(bm, rib, -0.012, 0.012, mat_idx=0, xform=rot)
        K.add_box(bm, 0.080, 0.112, -0.016, 0.016, cz - 0.012, cz + 0.012, mat_idx=1, xform=rot)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("MoltenCore_Body", bm, [mat_dark, mat_steel], coll, union=True)


def build_GlitchDie(coll):
    mat_die = K.make_material("Die_Dark", "#343B4D", "SmoothPlastic", roughness=0.40)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    mat_neon = K.make_material("Glitch_Neon", "#FF3DCB", "Neon", roughness=0.2, emission_strength=3.4)
    K.add_chain(coll, "GlitchDie", mat_chain, bottom_z=-0.106)

    bm_cube = bmesh.new()
    bmesh.ops.create_cube(bm_cube, size=0.156)
    bmesh.ops.bevel(bm_cube, geom=bm_cube.edges[:], offset=0.011, segments=1, affect="EDGES", clamp_overlap=True)

    # Align corner (1,1,1) straight up +Z, then rotate so 2 faces present cleanly forward!
    align_up = (
        Matrix.Rotation(math.radians(22), 4, "Z")
        @ Matrix.Rotation(-math.acos(1.0 / math.sqrt(3.0)), 4, "Y")
        @ Matrix.Rotation(-math.pi / 4.0, 4, "Z")
    )
    bmesh.ops.transform(bm_cube, matrix=align_up, verts=bm_cube.verts)
    peak_z = max(v.co.z for v in bm_cube.verts)
    shift = Vector((0.0, 0.0, -0.142 - peak_z))
    bmesh.ops.translate(bm_cube, vec=shift, verts=bm_cube.verts)

    bm_body = bm_cube.copy()
    for f in bm_body.faces:
        f.material_index = 0
        f.smooth = False
    K.bm_to_object("GlitchDie_Body", bm_body, [mat_die], coll, union=False)

    K.build_flush_corner_clasp(bm_cube, cut_z=-0.172, mat_chain=mat_chain, coll=coll, name="GlitchDie_Clasp")
    bm_cube.free()

    # Magenta Neon square pips seated directly onto the cube's local faces before transform!
    bm_pip = bmesh.new()
    face_xf = Matrix.Translation(shift) @ align_up
    half = 0.078
    # Face -Y (front-left visible): 3 diagonal pips
    for u, v in ((-0.036, -0.036), (0.0, 0.0), (0.036, 0.036)):
        K.add_box(bm_pip, u - 0.013, u + 0.013, -half - 0.006, -half + 0.004, v - 0.013, v + 0.013, mat_idx=0, xform=face_xf)
    # Face +X (front-right visible): 2 pips
    for u, v in ((-0.032, 0.032), (0.032, -0.032)):
        K.add_box(bm_pip, half - 0.004, half + 0.006, u - 0.013, u + 0.013, v - 0.013, v + 0.013, mat_idx=0, xform=face_xf)
    # Face -Z (bottom visible from low angle): 1 center pip
    K.add_box(bm_pip, -0.016, 0.016, -0.016, 0.016, -half - 0.006, -half + 0.004, mat_idx=0, xform=face_xf)
    K.bm_to_object("GlitchDie_Neon", bm_pip, [mat_neon], coll, union=False)


def build_CrownTrophy(coll):
    mat_gold = K.make_material("Crown_Gold", "#F5C036", "Metal", roughness=0.24, metallic=0.92)
    mat_dark = K.make_material("Crown_Dark", "#2A2F3D", "SmoothPlastic", roughness=0.42)
    mat_neon = K.make_material("Crown_Neon", "#FFD24A", "Neon", roughness=0.2, emission_strength=3.2)
    K.add_chain(coll, "CrownTrophy", mat_gold, bottom_z=-0.106)

    bm = bmesh.new()
    # Chamfered octagonal lower crown circlet + flared upper band
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.080, 8, math.pi / 8), -0.342, K.ngon_pts(0, 0, 0.092, 8, math.pi / 8), -0.328, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.092, 8, math.pi / 8), -0.330, K.ngon_pts(0, 0, 0.098, 8, math.pi / 8), -0.278, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.098, 8, math.pi / 8), -0.280, K.ngon_pts(0, 0, 0.088, 8, math.pi / 8), -0.270, mat_idx=0)

    # Recessed dark velvet royal dome seated cleanly inside the circlet (visible beneath hollow arches!)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.064, 8, math.pi / 8), -0.305, K.ngon_pts(0, 0, 0.060, 8, math.pi / 8), -0.258, mat_idx=1)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.060, 8, math.pi / 8), -0.260, K.ngon_pts(0, 0, 0.032, 8, math.pi / 8), -0.232, mat_idx=1)

    # 4 main flared royal crown points at cardinal directions + 4 smaller diagonal points around outer rim
    for k in range(4):
        ang = -math.pi / 2 + k * math.pi / 2
        xf = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0.092, 0.0, -0.285)) @ Matrix.Rotation(math.radians(12), 4, "Y")
        K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.009, 0.020, 0.002), 0.0, K.cham_rect_pts(0, 0, 0.004, 0.005, 0.001), 0.068, mat_idx=0, xform=xf)

        ang_sub = ang + math.pi / 4
        xf_s = Matrix.Rotation(ang_sub, 4, "Z") @ Matrix.Translation((0.090, 0.0, -0.285)) @ Matrix.Rotation(math.radians(10), 4, "Y")
        K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.008, 0.012, 0.002), 0.0, K.cham_rect_pts(0, 0, 0.003, 0.004, 0.001), 0.038, mat_idx=0, xform=xf_s)

    # 4 slender hollow curved royal arches rising strictly from inside the rim (clear of outer spikes -> clean mesh!)
    arch_profile = [
        (0.072, -0.282, 0.008, 0.012),
        (0.076, -0.222, 0.008, 0.011),
        (0.048, -0.178, 0.007, 0.010),
        (0.014, -0.158, 0.007, 0.009),
    ]
    for k in range(4):
        rot_z = Matrix.Rotation(k * math.pi / 2, 4, "Z")
        rings = []
        for r_pos, z_pos, hw_rad, hw_side in arch_profile:
            pts = [
                (r_pos - hw_rad, -hw_side, z_pos),
                (r_pos + hw_rad, -hw_side, z_pos),
                (r_pos + hw_rad, hw_side, z_pos),
                (r_pos - hw_rad, hw_side, z_pos),
            ]
            rings.append([bm.verts.new(rot_z @ Vector(p)) for p in pts])
        bm.faces.new(list(reversed(rings[0]))).material_index = 0
        bm.faces.new(rings[-1]).material_index = 0
        for s_i in range(len(rings) - 1):
            rA, rB = rings[s_i], rings[s_i + 1]
            for i in range(4):
                j = (i + 1) % 4
                f = bm.faces.new([rA[i], rA[j], rB[j], rB[i]])
                f.material_index = 0
                f.smooth = False

    # Proud front diamond bezel collar on circlet + top finial orb & chain ferrule
    K.add_prism_y(bm, K.ngon_pts(0.0, -0.304, 0.022, 4), -0.098, -0.072, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.024, 6), -0.168, K.ngon_pts(0, 0, 0.024, 6), -0.152, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.024, 6), -0.152, K.ngon_pts(0, 0, 0.015, 6), -0.123, mat_idx=0)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)
    K.bm_to_object("CrownTrophy_Body", bm, [mat_gold, mat_dark], coll, union=False)

    # Flush glowing gem seated inside the front gold diamond bezel
    bm_gem = bmesh.new()
    K.add_faceted_gem(bm_gem, Vector((0.0, -0.096, -0.304)), 0.014, 0.008, 0.016, n_sides=4, mat_idx=0)
    K.bm_to_object("CrownTrophy_Neon", bm_gem, [mat_neon], coll, union=False)


def build_AceSkull(coll):
    mat_bone = K.make_material("Skull_Bone", "#DCE4F0", "SmoothPlastic", roughness=0.36)
    mat_dark = K.make_material("Skull_Dark", "#3E475B", "Metal", roughness=0.34, metallic=0.72)
    mat_neon = K.make_material("Skull_Neon", "#FF3E52", "Neon", roughness=0.2, emission_strength=3.6)
    K.add_chain(coll, "AceSkull", mat_dark, bottom_z=-0.106)

    def skull_ring(rx, ry_f, ry_b, bridge_y):
        return [
            (0.0, -ry_f + bridge_y),
            (rx * 0.62, -ry_f),
            (rx, -0.008),
            (rx * 0.78, ry_b * 0.74),
            (0.0, ry_b),
            (-rx * 0.78, ry_b * 0.74),
            (-rx, -0.008),
            (-rx * 0.62, -ry_f),
        ]

    bm = bmesh.new()
    # Sculpted 5-tier faceted cranium loft (cheekbones -> brow -> forehead -> crown -> top flat)
    loft = [
        (-0.268, 0.070, 0.082, 0.068, 0.004),
        (-0.244, 0.086, 0.092, 0.080, 0.000),
        (-0.214, 0.088, 0.094, 0.084, -0.003),
        (-0.178, 0.074, 0.080, 0.074, -0.002),
        (-0.152, 0.044, 0.050, 0.048, 0.000),
    ]
    rings = [[bm.verts.new((px, py, pz)) for px, py in skull_ring(rx, ry_f, ry_b, by)] for pz, rx, ry_f, ry_b, by in loft]
    bm.faces.new(list(reversed(rings[0]))).material_index = 0
    bm.faces.new(rings[-1]).material_index = 0
    for r_i in range(len(rings) - 1):
        rA, rB = rings[r_i], rings[r_i + 1]
        for i in range(8):
            j = (i + 1) % 8
            f = bm.faces.new([rA[i], rA[j], rB[j], rB[i]])
            f.material_index = 0
            f.smooth = False

    # Tapered faceted jaw/mandible nested seamlessly beneath cheekbones
    K.add_frustum_z(bm, K.cham_rect_pts(0, -0.022, 0.036, 0.050, 0.011), -0.342, K.cham_rect_pts(0, -0.014, 0.056, 0.062, 0.015), -0.256, mat_idx=0)
    # Recessed dark eye sockets & inverted-V nasal cavity hugging the sculpted cheek/brow plane
    for sx in (-1, 1):
        sock = [(sx * 0.016, -0.248), (sx * 0.054, -0.240), (sx * 0.050, -0.214), (sx * 0.016, -0.222)]
        if sx < 0:
            sock = list(reversed(sock))
        K.add_prism_y(bm, sock, -0.095, -0.058, mat_idx=1)
    K.add_prism_y(bm, [(0.0, -0.246), (0.013, -0.270), (-0.013, -0.270)], -0.094, -0.064, mat_idx=1)
    # Clean flush mouth grille recess with 3 integrated bone teeth dividers
    K.add_prism_y(bm, K.cham_rect_pts(0, -0.306, 0.032, 0.016, 0.004), -0.078, -0.052, mat_idx=1)
    for tx in (-0.018, 0.0, 0.018):
        K.add_prism_y(bm, K.cham_rect_pts(tx, -0.306, 0.0045, 0.014, 0.001), -0.080, -0.052, mat_idx=0)

    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.022, 0.017, 0.005), -0.158, K.cham_rect_pts(0, 0, 0.017, 0.013, 0.004), -0.123, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("AceSkull_Body", bm, [mat_bone, mat_dark], coll, union=True)

    bm_eyes = bmesh.new()
    for sx in (-1, 1):
        eye = [(sx * 0.020, -0.241), (sx * 0.049, -0.234), (sx * 0.045, -0.221), (sx * 0.020, -0.228)]
        if sx < 0:
            eye = list(reversed(eye))
        K.add_prism_y(bm_eyes, eye, -0.098, -0.072, mat_idx=0)
    K.bm_to_object("AceSkull_Neon", bm_eyes, [mat_neon], coll, union=False)


STRIKE_BUILDERS = {
    "DraftTicket": build_DraftTicket,
    "BrassBullet": build_BrassBullet,
    "DogTags": build_DogTags,
    "FragPin": build_FragPin,
    "MiniHelmet": build_MiniHelmet,
    "TargetPlate": build_TargetPlate,
    "FragGrenade": build_FragGrenade,
    "MicroBlade": build_MicroBlade,
    "MoltenCore": build_MoltenCore,
    "GlitchDie": build_GlitchDie,
    "CrownTrophy": build_CrownTrophy,
    "AceSkull": build_AceSkull,
}

try:
    result = {"ok": True, "report": K.build_and_render_set(STRIKE_BUILDERS, STRIKE_ORDER)}
except Exception as e:
    result = {"ok": False, "error": str(e), "traceback": traceback.format_exc()}
