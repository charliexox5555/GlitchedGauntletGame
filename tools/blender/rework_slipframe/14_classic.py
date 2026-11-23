"""Classic's folded titanium slide, blue cap and recessed first-person inlay."""

from pathlib import Path

GUN = "Classic"
VERSION = globals().get("VERSION", "r01")
exec(Path("tools/blender/rework_slipframe/roster_lib.py").read_text(encoding="utf-8"))


def frame_openings(bm):
    for loop in list(boundary_loops(bm)):
        if len(loop) == 4:
            bm.faces.new(loop)
            continue
        assert len(loop) == 8
        center_x = sum(v.co.x for v in loop) / len(loop)
        hub = bm.verts.new((center_x, 0, 0.179))
        for first, second in zip(loop, loop[1:] + loop[:1]):
            bm.faces.new((first, second, hub))


def grip_opening(bm):
    loop, = boundary_loops(bm)
    left = [v for v in loop if v.co.y > 0]
    right = [v for v in loop if v.co.y < 0]
    assert len(left) == len(right) == 6
    across = {v: min(right, key=lambda other: (v.co.x - other.co.x) ** 2 +
              (v.co.y + other.co.y) ** 2 + (v.co.z - other.co.z) ** 2) for v in left}
    for first, second in zip(loop, loop[1:] + loop[:1]):
        if first in across and second in across:
            bm.faces.new((first, second, across[second], across[first]))


def mag_heel(point):
    if point.z > -0.282 and 0.047 < abs(point.y) < 0.052:
        point.y += math.copysign(0.0029, point.y)
    if point.z < -0.297:
        point.z += 0.0026
    if point.z < -0.31:
        point.x += (-0.31 - point.z) * 0.19


def grip_heel(point):
    if point.z < -0.255 and abs(point.y) > 0.062:
        point.y -= math.copysign((-0.255 - point.z) * 0.08, point.y)


dress("Frame", close=frame_openings, slots={"Dark": FRAME, "Metal": FRAME})
dress("Grip", shape=grip_heel, close=grip_opening, slots={"Dark": GRIP})
dress("Magazine", shape=mag_heel, slots={"Dark": FRAME, "Panel": FACE})
for name in ("Barrel", "CharmLoop", "Pins", "Trigger", "SlideCatch", "MagRelease"):
    dress(name)
dress("Slide", keep=lambda island: limits(island, 2)[0] > 0.46, slots={"Dark": FRAME},
      copy_name="SF_IronSights")
dress("SlideNeon", keep=lambda island: limits(island, 2)[0] > 0.49, slots={"Neon": SEAM},
      copy_name="SF_SightMarks")
replace("Slide", "SlideNeon", "MagNeon")

slide = folded("SF_SlideShell", (
    (-0.267, 0.295, 0.463, 0.058, 0.442, 0.318, 0.035),
    (-0.229, 0.2881, 0.479, 0.071, 0.448, 0.318, 0.043),
    (-0.015, 0.2881, 0.481, 0.072, 0.448, 0.319, 0.043),
    (0.684, 0.2881, 0.481, 0.072, 0.448, 0.319, 0.043),
    (0.894, 0.2881, 0.476, 0.072, 0.446, 0.320, 0.043),
    (0.962, 0.292, 0.471, 0.064, 0.442, 0.319, 0.041),
    (1.000, 0.307, 0.448, 0.054, 0.427, 0.328, 0.038),
    (1.000, 0.327, 0.405, 0.035, 0.395, 0.337, 0.024),
    (0.941, 0.323, 0.409, 0.036, 0.399, 0.334, 0.024),
    (0.836, 0.303, 0.4412, 0.043, 0.432, 0.313, 0.035),
    (0.344, 0.301, 0.4412, 0.043, 0.432, 0.313, 0.035),
    (-0.246, 0.309, 0.451, 0.039, 0.440, 0.319, 0.031),
    (-0.267, 0.310, 0.449, 0.041, 0.438, 0.319, 0.032),
), [FRAME, SHELL, SHELL, SHELL, SHELL, SHELL, SHELL, FRAME,
    FRAME, FRAME, FRAME, FRAME, FRAME], bone="Slide", loop=True)

# The guide hides the frame-to-slide seam in profile while the wider underside
# channel gives the slide full travel around it.
recess(slide, "SF_SlideGuideClearance", [
    (-0.295, 0.282), (1.025, 0.282), (1.025, 0.302), (-0.295, 0.302),
], -0.022, 0.022, bone="Slide")
side("SF_FrameSlideGuide", [
    (-0.267, 0.282), (-0.248, 0.296), (0.949, 0.296), (0.969, 0.282),
], -0.016, 0.016, FRAME, bevel=0.0012)

folded("SF_SlideRearSeat", (
    (-0.265, 0.307, 0.450, 0.043, 0.438, 0.319, 0.033),
    (-0.246, 0.305, 0.455, 0.047, 0.443, 0.317, 0.034),
    (-0.228, 0.311, 0.447, 0.042, 0.435, 0.321, 0.033),
), FRAME, bone="Slide")
recess(slide, "SF_EjectClearance_Right", [
    (0.368, 0.365), (0.390, 0.347), (0.583, 0.347), (0.613, 0.371),
    (0.613, 0.578), (0.368, 0.578),
], -0.16, 0.034, bone="Slide")

recess(slide, "SF_SlideCapSeat_Left", [
    (0.012, 0.363), (0.061, 0.442), (0.887, 0.442), (0.833, 0.347), (0.037, 0.336),
], 0.055, 0.15, bone="Slide")
cap = side("SF_InspectSlidingPanel_Left", [
    (0.029, 0.367), (0.068, 0.433), (0.869, 0.433), (0.828, 0.358), (0.045, 0.347),
], 0.052, 0.065, FACE, bone="Slide", bevel=0.0013)
cap["flat_group"] = "SFInspectPanel"
recess(slide, "SF_SlideCapSeat_Right", [
    (0.631, 0.340), (0.684, 0.435), (0.891, 0.435), (0.842, 0.355),
], -0.055, -0.15, bone="Slide")
side("SF_SlideCap_Right", [(0.645, 0.349), (0.691, 0.425), (0.874, 0.425), (0.836, 0.365)],
     -0.052, -0.065, FACE, bone="Slide", bevel=0.0013)

recess(slide, "SF_SeamSeat_Left", [
    (0.072, 0.324), (0.109, 0.334), (0.623, 0.335), (0.585, 0.322), (0.077, 0.321),
], 0.058, 0.14, bone="Slide")
inlay = side("SF_SeamInlay_Left", [(0.086, 0.325), (0.111, 0.331), (0.596, 0.332),
             (0.583, 0.325)], 0.056, 0.065, SEAM, bone="Slide", bevel=0.0005)
inlay["flat_group"] = "SFSeam"

for sign, label in ((1, "Left"), (-1, "Right")):
    for i, x in enumerate((-0.195, -0.146, -0.097)):
        recess(slide, f"SF_CantedSerration_{label}_{i}", [
            (x, 0.333), (x + 0.018, 0.329), (x + 0.043, 0.423), (x + 0.029, 0.435),
        ], 0.058 * sign, 0.13 * sign, bone="Slide")

result = finish_master(slide)
