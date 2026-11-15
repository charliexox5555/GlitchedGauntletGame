"""Original skin graphics in the stock weapon's rest-space X/Z plane."""
import math

import numpy as np


# Measured on the v05 paintable side faces, with muzzle pointing toward +X.
# span, clear vinyl/burst center, half-height, drafting/Prism seam, and eligible panels
LAYOUT = {
    "Vandal": ((-.08, 1.59), (.82, .314), .095, 1.055, "Receiver Handguard"),
    "Phantom": ((-.15, 1.59), (.66, .300), .090, .931, "Receiver Handguard"),
    "Bulldog": ((-.43, 1.025), (.23, .330), .108, .591, "Receiver Handguard"),
    "Guardian": ((.02, 2.34), (.89, .312), .095, 1.125, "Receiver Handguard"),
    "Spectre": ((-.27, 1.13), (.45, .337), .091, .698, "Receiver Handguard"),
    "Stinger": ((-.45, .90), (.35, .274), .087, .465, "Receiver Handguard"),
    "Ares": ((-.12, 2.115), (1.027, .348), .105, 1.191, "Receiver Handguard"),
    "Odin": ((-.15, 2.26), (1.45, .389), .120, 1.052, "Receiver"),
    "Sheriff": ((.68, 1.48), (.988, .240), .080, .773, "Frame Barrel"),
    "Classic": ((-.10, .985), (.41, .389), .082, .703, "Slide"),
    "Ghost": ((-.07, 1.115), (.475, .310), .070, .928, "Slide"),
    "Shorty": ((-.075, 1.025), (.251, .270), .070, .546, "Frame Barrels"),
    "Bucky": ((-.075, .954), (.49, .301), .093, .245, "Receiver"),
    "Judge": ((-.135, 1.905), (.77, .478), .120, 1.260, "Receiver Handguard"),
    "Marshal": ((.115, .875), (.573, .130), .080, .886, "Receiver"),
    "Outlaw": ((.155, 2.46), (.61, .363), .105, 1.028, "Receiver Barrels"),
    "Operator": ((.07, 2.25), (.811, .291), .087, 1.088, "Receiver Handguard"),
    "Knife": ((.42, 1.242), (.79, .002), .038, .901, "Blade"),
    "Bat": ((.48, 2.42), (1.67, .016), .17, 1.13, "Barrel"),
}
# Apply a separately bounded motif on hinged front assemblies.
HINGES = {"Outlaw": (1.09, 2.47), "Shorty": (.589, 1.03)}


def linear(hexcode):
    values = [int(hexcode[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in values)


class Artwork:
    def __init__(self, x, z):
        self.x = x
        self.z = z
        self.rgba = np.zeros((*x.shape, 4), dtype=np.float32)
        self.finish = np.zeros((*x.shape, 4), dtype=np.float32)

    def poly(self, points):
        mask = np.zeros(self.x.shape, dtype=bool)
        for (x0, z0), (x1, z1) in zip(points, points[1:] + points[:1]):
            if z0 != z1:
                mask ^= ((z0 > self.z) != (z1 > self.z)) & (
                    self.x < (x1 - x0) * (self.z - z0) / (z1 - z0) + x0
                )
        return mask

    def rect(self, x0, x1, z0, z1):
        return (self.x >= x0) & (self.x <= x1) & (self.z >= z0) & (self.z <= z1)

    def oval(self, x, z, w, h, angle=0):
        u, v = self.x - x, self.z - z
        ca, sa = math.cos(angle), math.sin(angle)
        return (((u * ca + v * sa) / w) ** 2 + ((v * ca - u * sa) / h) ** 2) < 1

    def star(self, x, z, w, h):
        points = [(0, 1), (.22, .22), (1, 0), (.22, -.22), (0, -1),
                  (-.22, -.22), (-1, 0), (-.22, .22)]
        return self.poly([(x + a * w, z + b * h) for a, b in points])

    def paint(self, mask, color, rough=.38, metal=0, opacity=1):
        self.rgba[mask, :3] = linear(color)
        self.rgba[mask, 3] = opacity
        self.finish[mask, 0] = rough
        self.finish[mask, 1] = metal
        self.finish[mask, 3] = opacity

    def clip(self, allowed):
        self.rgba[~allowed] = 0
        self.finish[~allowed] = 0


def prism(art, item, span, z, half, seam):
    lo, hi = span
    thin = max(.008, half * .12)
    band = art.poly([(lo, z - thin * .12), (lo + .07, z - thin / 2),
                     (hi - .10, z - thin / 2), (hi, z), (hi - .08, z + thin / 2),
                     (lo + .07, z + thin / 2)])
    if item not in {"Knife", "Marshal", "Ghost", "Sheriff"}:
        band &= abs(art.x - seam) > max(.014, thin * 1.1)
    if item in HINGES:
        band &= abs(art.x - HINGES[item][0]) > .028
    art.paint(band, "FFB6DB", .16, opacity=.18)


def redline(art, item, span, x, z, h, seam):
    lo, hi = span
    left, right = x - .28 * (hi - lo), x + .29 * (hi - lo)
    corner = seam if left + .06 < seam < right - .06 else x + .03
    z0, z1 = z - .13 * h, z + .24 * h
    width = max(.005, h * .084)
    line = art.rect(left, corner + width / 2, z0 - width / 2, z0 + width / 2)
    line |= art.rect(corner - width / 2, corner + width / 2, z0, z1)
    line |= art.rect(corner, right, z1 - width / 2, z1 + width / 2)
    for tick in (right - 2.8 * width, right - 7 * width):
        line |= art.rect(tick - width / 2, tick + width / 2, z1, z1 + width * 2.8)
    if item in HINGES:
        line &= art.x < HINGES[item][0] - .03
    art.paint(line, "B95762", .70, opacity=.88)
    echo = art.rect(left + .03, left + (right - left) * .27, z0 - width * 3.2, z0 - width * 2.6)
    art.paint(echo, "A24A58", .72, opacity=.42)


def nitrous(art, item, span, x, z, h, left):
    lo, hi = span
    w = hi - lo
    art.paint(art.poly([(lo + .03*w, z - h), (x - .18*w, z - h),
                        (hi + .05*w, z + .20*h), (hi + .03*w, z + .92*h),
                        (hi - .16*w, z + .66*h)]), "2367F2", .31, .08)
    art.paint(art.poly([(x + .03*w, z - .44*h), (hi, z + .04*h),
                        (hi + .03*w, z + .26*h), (x + .17*w, z + .18*h)]),
              "93ACC9", .38, .91)
    art.paint(art.poly([(lo + .02*w, z + .73*h), (x - .02*w, z + .46*h),
                        (x - .19*w, z + .91*h), (lo + .08*w, z + 1.48*h)]),
              "2453B2", .33, .08)
    art.paint(art.poly([(lo + .10*w, z + .61*h), (x - .12*w, z + .45*h),
                        (lo + .22*w, z + .83*h), (lo + .12*w, z + 1.10*h)]),
              "A8B5C4", .39, .91)
    if left:
        profile = [(-1.35, -.38), (-.47, -.18), (-.72, -.91), (-.13, -.42),
                   (.32, -.67), (.31, -.24), (1.35, .08), (.37, .17),
                   (.68, .82), (.02, .38), (-.37, .73), (-.38, .30)]
        art.paint(art.poly([(x + u*h*1.3, z + v*h*.77) for u, v in profile]),
                  "FF631F", .34, .04)
        for u, v, r in ((1.56, .46, .18), (1.98, .28, .12), (-1.10, .62, .15)):
            a, b = x + u*h, z + v*h
            art.paint(art.poly([(a-r*h,b), (a+r*h,b+r*h*.42),
                                (a+r*h*.6,b-r*h*.66)]), "FF631F", .34, .04)


def popcircuit(art, item, span, x, z, h, left):
    lo, hi = span
    w = hi - lo
    art.paint(art.poly([(lo-.12*w, z-2*h), (lo+.08*w, z-2*h), (lo+.35*w, z+h),
                        (lo+.30*w, z+2*h), (lo-.14*w, z+2*h)]), "FF9DD8", .33, .22)
    art.paint(art.poly([(lo-.05*w, z-2*h), (lo+.17*w, z-2*h), (lo+.25*w, z-.56*h),
                        (lo+.21*w, z-.45*h), (lo+.055*w, z-.72*h)]), "6554C9", .37, .33)
    art.paint(art.poly([(hi+.09*w, z-2*h), (hi-.28*w, z-2*h), (hi-.15*w, z-.40*h),
                        (hi+.11*w, z+.14*h)]), "6554C9", .35, .30)
    art.paint(art.poly([(hi+.14*w, z+.20*h), (hi-.14*w, z-.38*h), (hi-.28*w, z+.08*h),
                        (hi-.12*w, z+2*h), (hi+.13*w, z+2*h)]), "FF9DD8", .33, .20)
    if not left:
        return
    # The sticker lives in one clear patch. The paint blocks can cross fixed seams.
    if item == "Guardian":
        x,h = .993,.064
    if item in {"Ares", "Phantom", "Classic", "Ghost", "Spectre", "Shorty", "Operator"}:
        h *= .77
    if item in {"Bucky", "Marshal", "Sheriff", "Stinger"}:
        h *= .85
    angle = .21
    for i in range(4):
        for j in range(3):
            r = h * (.044 + (i+j) * .007)
            art.paint(art.oval(x + h*(1.34+i*.20), z-h*(.55-j*.16), r*1.12, r),
                      "BEB3F8", .31, .14, .65)
    for i in range(3):
        a = x + h * (-1.89-i*.16)
        b = z + h * (.03+i*.14)
        art.paint(art.poly([(a,b), (a+.48*h,b+.12*h), (a+.46*h,b+.17*h),
                            (a+.08*h,b+.09*h)]), "C8ECFF", .31, .1)
    art.paint(art.oval(x,z,1.40*h,.40*h,angle), "F7E6FF", .28, .03)
    art.paint(art.oval(x,z,1.29*h,.30*h,angle), "794BCB", .27, .08)
    art.paint(art.oval(x,z,.724*h,.673*h,.08), "FFF1FF", .25, .05)
    art.paint(art.oval(x,z,.652*h,.60*h,.08), "E76BBB", .26, .08)
    art.paint(art.oval(x-.045*h,z+.052*h,.571*h,.511*h,.08), "FF9DD8", .25, .06)
    art.paint(art.oval(x-.215*h,z+.27*h,.22*h,.083*h,.44), "FFF1FA", .23, .02)
    ring = art.oval(x,z,1.29*h,.30*h,angle) & ~art.oval(x,z,1.17*h,.215*h,angle)
    art.paint(ring & (art.z < z - .03*h), "9E57DA", .23, .10)
    for u,v,s in ((.86,.48,.29),(1.31,.77,.22),(1.65,.39,.15)):
        a,b = x+h*u,z+h*v
        art.paint(art.star(a,b,h*(s+.075),h*(s+.11)), "F3F7FF", .25, .02)
        art.paint(art.star(a,b,h*s,h*(s+.026)), "61F2FF", .24, .04)


def project(line, item, side, hinged=False):
    span, (x,z), h, seam, _ = LAYOUT[item]
    lo, hi = span
    width, height = 1024, 512
    bounds = (lo - .07, hi + .07, z - h*2.3, z + h*2.3)
    a,b,c,d = bounds
    xx,zz = np.meshgrid(a+(np.arange(width)+.5)*(b-a)/width,
                        c+(np.arange(height)+.5)*(d-c)/height)
    art = Artwork(xx,zz)
    left = side == "Left"
    if line == "Prism" and left:
        prism(art,item,span,z,h,seam)
    if line == "Redline" and left:
        redline(art,item,span,x,z,h,seam)
    if line == "Nitrous":
        nitrous(art,item,span,x,z,h,left and not hinged)
    if line == "PopCircuit":
        popcircuit(art,item,span,x,z,h,left and not hinged)
    if item in HINGES:
        limit,end = HINGES[item]
        if hinged:
            art.clip((art.x > limit+.018) & (art.x < end-.018))
        else:
            art.clip(art.x < limit-.026)
    return bounds, art.rgba, art.finish

