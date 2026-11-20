"""Review scenes for standalone melees and their companion charms."""

import bpy
from mathutils import Vector

from charms import build_charm, charm_pose
from designs import LINES
from melees import build_melee
from scene import camera, collection, framed_camera, material, marker, points


def object_design(line,item):
    sc=bpy.context.scene
    for obj in list(sc.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    col=collection(sc,"EXOTIC | Model and controls")
    cams=collection(sc,"EXOTIC | Review cameras")
    palette=[material(line+" / "+label,swatch,metal,rough,emission=em)
             for label,swatch,metal,rough,em in zip(("Shell","Face plates","Active insert","Accent","Smoked seat"),
             LINES[line],(.37,.48,.13,.48,.28),(.57,.44,.24,.42,.37),(0,0,.4,0,0))]
    is_melee=item in ("SoundingArc","KilnCleaver","PatchTool")
    if is_melee:
        rig=build_melee(sc,col,item,palette)
        sc.frame_set(1)
        coords=points(col.objects)
        held=camera(cams,"First person | 80 degree vertical FOV",(.60,.17,.21),(-1,.39,.1),
                    distance=1.65,lens=14.3,clip=.1)
        hero=framed_camera(cams,"Three-quarter",coords,(.34,1,.24),1.5,1.12)
        side=framed_camera(cams,"Side | grip and pivots",coords,(0,1,0),1.47,1.14)
        under=framed_camera(cams,"Under / reverse",coords,(-.19,-1,-.43),1.48,1.11)
        inspect={"SoundingArc":150,"KilnCleaver":150,"PatchTool":146}[item]
        motion={"equip":18,"idle":34,"carry":55,"light_a":72,"light_b":91,"heavy":113,
                "inspect":inspect,"recovery":182,"cancel":219,"gameplay_range_studs":7,
                "light_contact_seconds":[.168,.231],"heavy_contact_seconds":.378}
        pose_stills={name:("held",frame,(500,282)) for name,frame in motion.items()
                     if name in ("equip","idle","carry","light_a","light_b","heavy","inspect","recovery","cancel")}
        stills={"hero":("hero",1,(860,570)),"side":("side",1,(650,440)),"right":("right",1,(600,405)),
                "folded":("side",111 if item=="PatchTool" else (12 if item=="SoundingArc" else 139),(625,422)),
                "detail":("side",inspect,(625,422)),**pose_stills}
        return sc,rig,None,{"hero":hero,"held":held,"side":side,"right":under},motion,stills,{
            "rig_bones":len(rig.data.bones),"hands":"concept posing proxies","timing":"current stock visual impact cues"}
    assembly=build_charm(col,line,item,palette)
    swing,_=assembly
    for frame,act,angle in ((1,0,0),(9,0,0),(22,.52,-13),(35,1,15),(42,.85,-8),(50,.39,4),(61,0,0),(69,0,0)):
        charm_pose(assembly,frame,act,angle)
    for label,f in (("REST",1),("REVEAL START",9),("ACTIVE + SWING EXTREME",35),("RECOVER",50),("REST RESET",61)):
        marker(sc,label,f)
    sc.frame_start,sc.frame_end=1,69
    sc.frame_set(1)
    coords=points(col.objects)
    views={"hero":framed_camera(cams,"Charm | three-quarter",coords,(.32,1,.19),1.5,1.15),
           "side":framed_camera(cams,"Charm | reward icon",coords,(0,1,0),1.5,1.08),
           "right":framed_camera(cams,"Charm | underside and reverse",coords,(-.35,-1,-.34),1.5,1.19)}
    stills={"hero":("hero",1,(810,540)),"side":("side",1,(540,360)),"right":("right",1,(540,360)),
            "active":("hero",35,(700,466)),"settled":("hero",61,(640,426))}
    return sc,swing,None,views,{"start":9,"active":35,"reset":61,"swing_max_degrees":15},stills,{"separate_mount_pivot":True}
