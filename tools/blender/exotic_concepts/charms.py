"""Standalone rigid charm assemblies, also used on the hero mount locators."""

import math

from scene import bind, cut, loft, material, pivot, pose, prism, profile_ring


def build_charm(col, line, name, palette, mount=(0,0,0), parent=None, bone=None):
    dark, pale, lit, accent, smoke = palette
    prefix = name + " / "
    x, y, z = mount
    # Charm fronts face outboard (+Y). Keep the ring centered on the stock locator.
    def profile(label, shape, near, far, mat, bevel=.002):
        return prism(col, prefix+label, [(x+a,z+b) for a,b in shape], y+near,y+far,mat,bevel)

    def plate(label, x0, x1, z0, z1, near, far, mat, corner=.008):
        return profile(label, cut(x0,x1,z0,z1,corner),near,far,mat)

    mount_ring = profile_ring(col, prefix+"Oval mount", (x,y,z-.014),(.021,.029),.006,.013,pale)
    # The y-offset lets the lower body swing outward without grazing the host frame.
    neck = plate("Closed eyelet",-.013,.013,-.055,-.024,-.008,.016,accent)
    swing = pivot(col, prefix+"Swing pivot", mount, [mount_ring, neck],parent,bone)
    driven = []
    if line == "Spindrift":
        body = loft(col,prefix+"Faceted float",[(x,y+.021,z+h,rx,ry) for h,rx,ry in [
            (-.198,.025,.016), (-.18,.046,.028),(-.15,.061,.036),(-.081,.056,.035),(-.059,.036,.027)]],10,dark)
        cap = loft(col,prefix+"Coral cap",[(x,y+.021,z+h,rx,ry) for h,rx,ry in [
            (-.086,.055,.034),(-.065,.048,.032),(-.053,.033,.023)]],10,accent)
        surround = plate("Pearl glass bezel",-.025,.025,-.177,-.088,.044,.061,pale,.011)
        insert = plate("Sea glass",-.018,.018,-.168,-.096,.058,.067,smoke,.009)
        bubble = loft(col,prefix+"Single air bead",[(x,y+.069,z+h,r,r*.45) for h,r in [
            (-.159,.003),(-.155,.008),(-.147,.008),(-.143,.002)]],8,lit)
        driven.append((pivot(col,prefix+"Bubble guide",(x,y,z),[bubble],swing),"bubble"))
        pieces = [body,cap,surround,insert]
    elif line == "Kilnlock":
        body = plate("Ceramic seal",-.064,.064,-.177,-.055,-.007,.045,pale,.014)
        backing = plate("Iron back",-.057,.057,-.169,-.064,-.014,-.004,dark,.014)
        recess = plate("Heat recess",-.033,.033,-.147,-.087,.04,.054,dark,.005)
        core = plate("Enamel core",-.022,.022,-.139,-.095,.051,.057,lit,.004)
        pieces = [body, backing, recess, core]
        for side in (-1,1):
            a,b = sorted((side*.006,side*.057))
            jaw = plate("Copper jaw " + str(side),a,b,-.154,-.077,.057,.075,accent,.009)
            end = x+side*.047
            pin = profile_ring(col,prefix+"Hinge boss "+str(side),(end,y+.077,z-.112),(.009,.009),.003,.009,dark,8)
            pieces.append(pin)
            driven.append((pivot(col,prefix+"Jaw hinge "+str(side),(end,y+.059,z-.112),[jaw],swing),side))
    else:
        chassis_material=material("Keycap Tester / Smoked acrylic frame","344656",.14,.32,.86)
        chassis = plate("Smoke-blue switch frame",-.063,.063,-.174,-.052,-.009,.045,chassis_material,.017)
        ring_mat=lit.copy()
        ring_mat.name="Keycap Tester / Animated status ring"
        plate_under = plate("Mint status ring",-.051,.051,-.158,-.069,.04,.056,ring_mat,.012)
        cap = plate("Ivory keycap",-.044,.044,-.15,-.077,.058,.081,pale,.012)
        bars = [plate("Glyph bar "+str(i+1),-.025+i*.019,-.016+i*.019,-.133,-.103+i*.006,.079,.084,dark,.003)
                for i in range(3)]
        driven.append((pivot(col,prefix+"Key travel",(x,y+.065,z-.112),[cap,*bars],swing),"key"))
        driven.append((plate_under,"glow"))
        pieces = [chassis, plate_under]
    for ob in pieces:
        bind(ob,swing)
    return swing, driven


def charm_pose(assembly, frame, amount, swing=0):
    root, driven = assembly
    pose(root,frame,angles=(root.get("outboard_cant",0)+abs(swing)*.24,swing,0))
    for ob,control in driven:
        rest = ob.get("anchor")
        if rest is None:
            rest = tuple(ob.location)
            ob["anchor"] = rest
        if control == "bubble":
            pose(ob,frame,xyz=(rest[0],rest[1],rest[2]+amount*.046))
        elif control == "key":
            pose(ob,frame,xyz=(rest[0],rest[1]-.018*amount,rest[2]))
        elif control == "glow":
            shader=ob.data.materials[0].node_tree.nodes.get("Principled BSDF")
            glow=shader.inputs["Emission Strength"]
            glow.default_value=.10+amount*.66
            glow.keyframe_insert("default_value",frame=frame)
        else:
            pose(ob,frame,angles=(0,0,control*amount*64))
