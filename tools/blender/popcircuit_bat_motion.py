"""Author the PopCircuit Bat's first-person motion in Blender camera space.

+X forward, +Y player left, +Z up. Held keys describe the center of the palm.
The inspect switches to a barrel-weighted pivot while the Bat is airborne.
"""
from math import radians, tau
from mathutils import Euler, Quaternion, Vector

FPS = 48
GRIP = Vector((.27, 0, 0))
SUPPORT = Vector((.80, .27, -.14))
CENTER = Vector((1.53, 0, 0))
REST = ((1.74,-.74,-.75), (9,55,23))
FREE = Vector((1.10,.86,-.86))
CONTACT = {"SlashLeft":15, "SlashRight":15, "Smash":27}
TRAIL = (12,23)
RELEASE, CATCH = 43, 79

KEYS = {
    "Idle": {
        1: REST, 34: ((1.76,-.735,-.735),(10,55.8,23.7)), 65: REST,
    },
    "SlashLeft": {
        1: REST, 5: ((1.69,-.80,-.68),(10,60,7)),
        10: ((1.57,-.94,-.55),(1,55,-62)),
        12: ((1.69,-.78,-.41),(3,53,-43)),
        15: ((2.02,-.20,-.38),(15,30,16)),
        18: ((1.93,.12,-.53),(25,14,53)),
        23: ((1.78,.13,-.62),(30,12,66)),
        29: ((1.69,-.36,-.72),(20,26,40)), 38: REST,
    },
    "SlashRight": {
        1: REST, 5: ((1.62,-.56,-.60),(15,62,39)),
        10: ((1.60,-.11,-.49),(27,59,49)),
        12: ((1.75,-.21,-.36),(22,48,34)),
        15: ((1.99,-.29,-.37),(13,29,-7)),
        18: ((1.87,-.72,-.60),(-8,12,-56)),
        23: ((1.74,-.92,-.71),(-18,10,-68)),
        29: ((1.68,-.82,-.81),(-2,32,-28)), 38: REST,
    },
    "Smash": {
        1: REST, 8: ((1.64,-.64,-.50),(11,66,31)),
        16: ((1.66,-.86,-.13),(12,65,55)),
        21: ((1.83,-.87,.04),(12,60,59)),
        24: ((2.02,-.74,.12),(8,42,65)),
        27: ((2.16,-.75,-.10),(5,2,53)),
        31: ((2.05,-.72,-.25),(4,-11,52)),
        37: ((1.90,-.68,-.35),(7,-6,51)),
        44: ((1.77,-.62,-.65),(7,27,42)), 58: REST,
    },
    "Inspect": {
        1: REST, 12: ((1.86,-.70,-.41),(6,43,37)),
        23: ((1.97,-.58,-.35),(-18,39,45)),
        30: ((1.98,-.55,-.37),(21,39,45)),
        37: ((1.85,-.59,-.60),(15,39,43)),
        RELEASE: ((2.10,-.68,-.36),(11,24,40)),
        CATCH: ((2.26,-.52,-.40),(11,24,40)),
        83: ((2.16,-.37,-.54),(18,28,45)),
        90: ((2.01,-.46,-.49),(15,44,38)),
        103: REST,
    },
}


def smooth(t):
    t = max(0,min(1,t))
    return t*t*(3-2*t)


def curve(keys, frame):
    """Cubic Hermite interpolation with time-weighted tangents at each key."""
    times = sorted(keys)
    if frame <= times[0]:
        return Vector(keys[times[0]])
    if frame >= times[-1]:
        return Vector(keys[times[-1]])
    for index,(a,b) in enumerate(zip(times,times[1:])):
        if frame > b:
            continue
        p,q = Vector(keys[a]),Vector(keys[b])
        t = (frame-a)/(b-a)
        prev = times[index-1] if index else a
        following = times[index+2] if index+2<len(times) else b
        m = (q-Vector(keys[prev]))*((b-a)/(b-prev)) if prev!=a else p*0
        n = (Vector(keys[following])-p)*((b-a)/(following-a)) if following!=b else q*0
        return (2*t**3-3*t**2+1)*p+(t**3-2*t*t+t)*m+(-2*t**3+3*t*t)*q+(t**3-t*t)*n
    raise ValueError(frame)


def held(name, frame):
    keys = KEYS[name]
    palm = curve({f:p for f,(p,_) in keys.items()},frame)
    roll,elevation,yaw = curve({f:r for f,(_,r) in keys.items()},frame)
    rotation = Euler(tuple(map(radians,(roll,-elevation,yaw))),"XYZ").to_quaternion()
    return palm, rotation


def pose(name, frame):
    palm, rot = held(name,frame)
    origin = palm - rot @ GRIP
    left = FREE.copy()
    support = 0
    if name == "Smash":
        support = smooth((frame-11)/9) * (1-smooth((frame-35)/12))
        left += Vector((-.30,.38,-.26))*smooth((frame-7)/7)*(1-smooth((frame-19)/6))
        left = left.lerp(origin + rot @ SUPPORT, support)
    if name == "SlashLeft":
        left += curve({1:(0,0,0),14:(-.16,.28,-.26),23:(-.31,.51,-.44),38:(0,0,0)},frame)
    if name == "SlashRight":
        left += curve({1:(0,0,0),12:(-.38,.69,-.68),23:(-.12,.19,-.20),38:(0,0,0)},frame)
    if name == "Inspect" and RELEASE < frame < CATCH:
        release, spin_base = held(name,RELEASE)
        catch, _ = held(name,CATCH)
        t = (frame-RELEASE)/(CATCH-RELEASE)
        center0 = release+spin_base @ (CENTER-GRIP)
        center1 = catch+spin_base @ (CENTER-GRIP)
        center = center0.lerp(center1,t)+Vector((.90, .07, .41))*(4*t*(1-t))
        rot = Quaternion((1,0,0), -tau*t) @ spin_base
        origin = center-rot @ CENTER
        palm = curve({
            RELEASE:tuple(release),50:(1.83,-.74,-.73),61:(1.76,-.79,-.85),
            70:(2.00,-.59,-.61),CATCH:tuple(catch),
        },frame)
    if name == "Inspect":
        left += Vector((-.39,.65,-.63))*smooth((frame-3)/8)*(1-smooth((frame-93)/10))
    attached = name!="Inspect" or frame<=RELEASE or frame>=CATCH
    return origin,rot,palm,left,attached,support

