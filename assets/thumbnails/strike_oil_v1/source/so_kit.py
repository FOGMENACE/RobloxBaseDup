# Strike Oil! thumbnail kit: shared builders (exec'd inside Blender)
import bpy, bmesh, math, random
from mathutils import Vector, Euler

ASSETS = r"C:\Rblxspeel\RobloxBaseDup\assets"
OUT = ASSETS + r"\thumbnails\strike_oil_v1"
FONT_BLACK = r"C:\Windows\Fonts\ariblk.ttf"
FONT_HEAVY = r"C:\Windows\Fonts\seguibl.ttf"


def node(nt, kind, loc=(0, 0), **inputs):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def principled(nt):
    return next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")


def new_mat(name):
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m


def mat_glossy(name, color, rough=0.2, coat=0.0, metal=0.0, emit=None, emit_str=0.0, alpha=1.0, transmission=0.0):
    m = new_mat(name)
    b = principled(m.node_tree)
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.03
    b.inputs["Transmission Weight"].default_value = transmission
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = emit_str
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m


def mat_image_ball(name, image_path, rough=0.12, hue_tint=None):
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image_path, check_existing=True)
    tex.location = (-500, 200)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.02
    return m


def mat_swirl_ball(name, c1, c2, c3, scale=1.6):
    """Procedural pearl-swirl urethane: wave+noise into a 3-stop ramp, clear coat."""
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tc = node(nt, "ShaderNodeTexCoord", (-1100, 0))
    noise = node(nt, "ShaderNodeTexNoise", (-900, 0))
    noise.inputs["Scale"].default_value = 1.2
    noise.inputs["Detail"].default_value = 6
    noise.inputs["Distortion"].default_value = 2.5
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    wave = node(nt, "ShaderNodeTexWave", (-700, 0))
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 9
    wave.inputs["Detail"].default_value = 4
    nt.links.new(noise.outputs["Color"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-450, 0)
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.15, (*c1, 1)
    el[1].position, el[1].color = 0.85, (*c3, 1)
    mid = el.new(0.5)
    mid.color = (*c2, 1)
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.18
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.02
    b.inputs["Sheen Weight"].default_value = 0.3
    return m


def mat_oil(name="Oil"):
    """Glossy black oil with an iridescent fresnel sheen."""
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    lw = node(nt, "ShaderNodeLayerWeight", (-800, 100))
    lw.inputs["Blend"].default_value = 0.35
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-550, 100)
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (0.004, 0.004, 0.01, 1)
    el[1].position, el[1].color = 1.0, (0.02, 0.35, 0.45, 1)
    for p, c in ((0.55, (0.006, 0.005, 0.02)), (0.75, (0.25, 0.05, 0.35)), (0.9, (0.6, 0.35, 0.05))):
        e = el.new(p)
        e.color = (*c, 1)
    nt.links.new(lw.outputs["Facing"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.03
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.0
    b.inputs["IOR"].default_value = 1.5
    return m


def mat_black_gold(name="BlackGold"):
    """Crude-oil liquid: glassy surface, amber where thin, near-black where thick."""
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    b.inputs["Base Color"].default_value = (1.0, 0.6, 0.15, 1)
    b.inputs["Transmission Weight"].default_value = 1.0
    b.inputs["Roughness"].default_value = 0.02
    b.inputs["IOR"].default_value = 1.47
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    vol = nt.nodes.new("ShaderNodeVolumeAbsorption")
    vol.inputs["Color"].default_value = (1.0, 0.62, 0.12, 1)
    vol.inputs["Density"].default_value = 22.0
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    return m


def mat_wood_lane(name="LaneWood"):
    """Glossy oiled maple boards running along +Y."""
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tc = node(nt, "ShaderNodeTexCoord", (-1300, 0))
    mp = node(nt, "ShaderNodeMapping", (-1100, 0))
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    mp.inputs["Scale"].default_value = (1.0, 0.08, 1.0)
    grain = node(nt, "ShaderNodeTexWave", (-850, 150))
    grain.wave_type = "BANDS"
    grain.bands_direction = "X"
    grain.inputs["Scale"].default_value = 0.9
    grain.inputs["Distortion"].default_value = 3.0
    grain.inputs["Detail"].default_value = 3
    nt.links.new(mp.outputs["Vector"], grain.inputs["Vector"])
    noise = node(nt, "ShaderNodeTexNoise", (-850, -150))
    noise.inputs["Scale"].default_value = 18
    noise.inputs["Detail"].default_value = 8
    nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])
    mix = node(nt, "ShaderNodeMath", (-600, 0))
    mix.operation = "MULTIPLY_ADD"
    mix.inputs[1].default_value = 0.6
    nt.links.new(grain.outputs["Fac"], mix.inputs[0])
    nt.links.new(noise.outputs["Fac"], mix.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-400, 0)
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.3, (0.52, 0.30, 0.13, 1)
    el[1].position, el[1].color = 1.0, (0.93, 0.70, 0.42, 1)
    nt.links.new(mix.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.22
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.015
    return m


def mat_pin(name="Pin"):
    """White lacquered pin with two red neck stripes (object Z)."""
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tc = node(nt, "ShaderNodeTexCoord", (-900, 0))
    sep = node(nt, "ShaderNodeSeparateXYZ", (-700, 0))
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-450, 0)
    ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    white, red = (0.92, 0.92, 0.9, 1), (0.75, 0.02, 0.03, 1)
    el[0].position, el[0].color = 0.0, white
    el[1].position, el[1].color = 0.62, red
    for p, c in ((0.655, white), (0.685, red), (0.72, white)):
        e = el.new(p)
        e.color = c
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.25
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.03
    b.inputs["Subsurface Weight"].default_value = 0.05
    return m


def smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


def link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj)
    return obj


def make_ball(name, mat, radius=1.0, loc=(0, 0, 1), holes=True, rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=96, v_segments=48, radius=radius, calc_uvs=True)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    smooth(ob)
    ob.data.materials.append(mat)
    if holes:
        hole_mat = mat_glossy(name + "_hole", (0.01, 0.01, 0.012), rough=0.5)
        ob.data.materials.append(hole_mat)
        for i, (x, z, r) in enumerate(((-0.22, 0.48, 0.11), (0.22, 0.48, 0.11), (0.0, 0.05, 0.13))):
            hm = bpy.data.meshes.new(name + "_h%d" % i)
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=r * radius, radius2=r * radius, depth=0.9 * radius)
            bm.to_mesh(hm)
            bm.free()
            h = link(bpy.data.objects.new(name + "_h%d" % i, hm))
            h.data.materials.append(hole_mat)
            h.rotation_euler = (math.radians(90), 0, 0)
            h.location = (x * radius, -0.85 * radius, z * radius)
            h.parent = ob
            h.hide_render = True
            h.hide_viewport = True
            mod = ob.modifiers.new("hole%d" % i, "BOOLEAN")
            mod.object = h
            mod.operation = "DIFFERENCE"
            mod.solver = "EXACT"
            mod.material_mode = "TRANSFER"
    ob.location = loc
    ob.rotation_euler = rot
    return ob


PIN_PROFILE = [(0, 0), (0, 1.0), (0.4, 1.3), (1.2, 1.8), (2.4, 2.25), (3.75, 2.383), (5.2, 2.28), (6.8, 1.85),
               (8.2, 1.3), (9.3, 0.95), (10.1, 0.9), (11.0, 1.02), (12.2, 1.24), (13.3, 1.28), (14.0, 1.15),
               (14.5, 0.9), (14.85, 0.5), (15.0, 0.0)]


def make_pin(name, mat, scale=1.0 / 4.25, loc=(0, 0, 0), rot=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((r * scale, 0, z * scale)) for z, r in PIN_PROFILE]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    scr = ob.modifiers.new("lathe", "SCREW")
    scr.axis = "Z"
    scr.steps = 64
    scr.render_steps = 64
    scr.use_merge_vertices = True
    scr.use_smooth_shade = True
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    ob.data.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def rounded_box(name, size, mat, bevel=0.08, loc=(0, 0, 0), rot=(0, 0, 0), seg=4):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] * 2, v.co.y * size[1] * 2, v.co.z * size[2] * 2))  # size = half extents
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = bevel
    bv.segments = seg
    bv.limit_method = "NONE"
    ob.modifiers.new("wn", "WEIGHTED_NORMAL")
    smooth(ob)
    ob.data.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def make_text(name, body, mat, size=1.0, extrude=0.08, bevel=0.02, font=FONT_BLACK, loc=(0, 0, 0),
              rot=(math.radians(90), 0, 0), outline_mat=None, outline=0.06, outline_depth=0.04, align="CENTER"):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.font = bpy.data.fonts.load(font, check_existing=True)
    cu.size = size
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    cu.align_x = align
    cu.align_y = "CENTER"
    ob = link(bpy.data.objects.new(name, cu))
    ob.data.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = rot
    if outline_mat:
        cu2 = cu.copy()
        cu2.offset = outline
        cu2.extrude = extrude + outline_depth
        cu2.bevel_depth = 0.0
        cu2.materials.clear()
        cu2.materials.append(outline_mat)
        o2 = link(bpy.data.objects.new(name + "_outline", cu2))
        o2.parent = ob
        o2.location = (0, 0, -outline_depth)
    return ob


def make_avatar(name, shirt, pants, skin=(0.98, 0.78, 0.55), face_img=None, hair=None, loc=(0, 0, 0), rot_z=0.0,
                pose=None, scale=1.0):
    """Original blocky avatar (R6 proportions, soft bevels). pose: dict of limb -> (x,y,z) degrees."""
    pose = pose or {}
    root = link(bpy.data.objects.new(name, None))
    m_shirt = mat_glossy(name + "_shirt", shirt, rough=0.55)
    m_pants = mat_glossy(name + "_pants", pants, rough=0.6)
    m_skin = mat_glossy(name + "_skin", skin, rough=0.45)
    torso = rounded_box(name + "_torso", (1.0, 0.5, 1.0), m_shirt, bevel=0.12, loc=(0, 0, 3.0))
    torso.parent = root
    parts = {}
    for side, x in (("L", -1.5), ("R", 1.5)):
        piv = link(bpy.data.objects.new(f"{name}_arm{side}_piv", None))
        piv.parent = torso
        piv.location = (x, 0, 0.85)
        arm = rounded_box(f"{name}_arm{side}", (0.5, 0.5, 1.0), m_skin, bevel=0.12, loc=(0, 0, -0.85))
        sleeve = rounded_box(f"{name}_sleeve{side}", (0.53, 0.53, 0.42), m_shirt, bevel=0.1, loc=(0, 0, -0.27))
        arm.parent = piv
        sleeve.parent = piv
        parts["arm" + side] = piv
        lpiv = link(bpy.data.objects.new(f"{name}_leg{side}_piv", None))
        lpiv.parent = torso
        lpiv.location = (x / 3.0, 0, -1.0)
        leg = rounded_box(f"{name}_leg{side}", (0.49, 0.5, 1.0), m_pants, bevel=0.12, loc=(0, 0, -1.0))
        leg.parent = lpiv
        parts["leg" + side] = lpiv
    hpiv = link(bpy.data.objects.new(name + "_head_piv", None))
    hpiv.parent = torso
    hpiv.location = (0, 0, 1.0)
    me = bpy.data.meshes.new(name + "_head")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.62, radius2=0.62, depth=1.15)
    bm.to_mesh(me)
    bm.free()
    head = link(bpy.data.objects.new(name + "_head", me))
    bv = head.modifiers.new("bevel", "BEVEL")
    bv.width = 0.22
    bv.segments = 6
    bv.limit_method = "ANGLE"
    smooth(head)
    head.data.materials.append(m_skin)
    head.parent = hpiv
    head.location = (0, 0, 0.62)
    parts["head"] = hpiv
    if face_img:
        fm = new_mat(name + "_face")
        nt = fm.node_tree
        b = principled(nt)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(face_img, check_existing=True)
        nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
        b.inputs["Roughness"].default_value = 0.5
        fm.blend_method = "HASHED"
        bpy.ops.mesh.primitive_plane_add(size=1.0)
        face = bpy.context.active_object
        face.name = name + "_face"
        face.data.materials.append(fm)
        face.parent = hpiv
        face.rotation_euler = (math.radians(90), 0, 0)
        face.location = (0, -0.635, 0.62)
        face.scale = (0.95, 0.95, 1)
    if hair:
        hm = mat_glossy(name + "_hair", hair, rough=0.5)
        cap = rounded_box(name + "_hair", (0.68, 0.68, 0.22), hm, bevel=0.18, loc=(0, 0.04, 1.18))
        cap.parent = hpiv
        brim = rounded_box(name + "_brim", (0.6, 0.35, 0.05), hm, bevel=0.04, loc=(0, -0.75, 1.02))
        brim.parent = hpiv
    for k, v in pose.items():
        parts[k].rotation_euler = Euler([math.radians(a) for a in v])
    root.location = loc
    root.rotation_euler = (0, 0, math.radians(rot_z))
    root.scale = (scale, scale, scale)
    return root, parts


def world_gradient(top, horizon, strength=1.0, sun_glow=None):
    w = bpy.data.worlds.new("Sky")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    tc = node(nt, "ShaderNodeTexCoord", (-900, 0))
    sep = node(nt, "ShaderNodeSeparateXYZ", (-700, 0))
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-450, 0)
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (*horizon, 1)
    el[1].position, el[1].color = 0.22, (*top, 1)
    mid = el.new(0.07)
    mid.color = (*[(a + b) / 2 for a, b in zip(top, horizon)], 1)
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    return w


def area_light(name, loc, rot, size, power, color=(1, 1, 1), shape="RECTANGLE", size_y=None):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = power
    ld.color = color
    ld.shape = shape
    ld.size = size
    if size_y:
        ld.size_y = size_y
    ob = link(bpy.data.objects.new(name, ld))
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def sun_light(name, rot, power, color=(1, 0.95, 0.85), angle=2.0):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy = power
    ld.color = color
    ld.angle = math.radians(angle)
    ob = link(bpy.data.objects.new(name, ld))
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def camera(name, loc, target, lens=35, dof_target=None, fstop=2.8):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cam = link(bpy.data.objects.new(name, cd))
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if dof_target is not None:
        cd.dof.use_dof = True
        cd.dof.focus_distance = (Vector(dof_target) - Vector(loc)).length
        cd.dof.aperture_fstop = fstop
    bpy.context.scene.camera = cam
    return cam


def render_setup(samples=256, res=(1920, 1080), look="AgX - Punchy", exposure=0.0):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "GPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.denoiser = "OPENIMAGEDENOISE"
    sc.cycles.max_bounces = 8
    sc.cycles.glossy_bounces = 6
    sc.cycles.transparent_max_bounces = 16
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = look
    except TypeError:
        pass
    sc.view_settings.exposure = exposure
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"


def render_to(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def post_fx(haze=(0.95, 0.65, 0.7), amount=0.45, start=12, depth=60, glare=0.6, vignette=0.35):
    """Compositor: distance haze on geometry only (sky untouched), soft highlight glow, vignette."""
    sc = bpy.context.scene
    sc.view_layers[0].use_pass_mist = True
    sc.world.mist_settings.start = start
    sc.world.mist_settings.depth = depth
    sc.world.mist_settings.falloff = "QUADRATIC"
    sc.use_nodes = True
    nt = sc.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    rl = nt.nodes.new("CompositorNodeRLayers")
    notsky = nt.nodes.new("CompositorNodeMath")
    notsky.operation = "LESS_THAN"
    notsky.inputs[1].default_value = 0.999
    nt.links.new(rl.outputs["Mist"], notsky.inputs[0])
    fac = nt.nodes.new("CompositorNodeMath")
    fac.operation = "MULTIPLY"
    nt.links.new(rl.outputs["Mist"], fac.inputs[0])
    nt.links.new(notsky.outputs[0], fac.inputs[1])
    fac2 = nt.nodes.new("CompositorNodeMath")
    fac2.operation = "MULTIPLY"
    fac2.inputs[1].default_value = amount
    nt.links.new(fac.outputs[0], fac2.inputs[0])
    mix = nt.nodes.new("CompositorNodeMixRGB")
    mix.inputs[2].default_value = (*haze, 1)
    nt.links.new(fac2.outputs[0], mix.inputs[0])
    nt.links.new(rl.outputs["Image"], mix.inputs[1])
    last = mix.outputs[0]
    if glare:
        g = nt.nodes.new("CompositorNodeGlare")
        g.glare_type = "FOG_GLOW"
        g.quality = "HIGH"
        g.threshold = 1.2
        g.size = 8
        g.mix = -1 + glare * 0.5
        nt.links.new(last, g.inputs["Image"])
        last = g.outputs[0]
    if vignette:
        mask = nt.nodes.new("CompositorNodeEllipseMask")
        mask.width, mask.height = 1.05, 1.0
        blur = nt.nodes.new("CompositorNodeBlur")
        blur.filter_type = "FAST_GAUSS"
        blur.use_relative = True
        blur.factor_x = blur.factor_y = 30
        nt.links.new(mask.outputs[0], blur.inputs[0])
        inv = nt.nodes.new("CompositorNodeMath")
        inv.operation = "MULTIPLY_ADD"
        inv.inputs[1].default_value = vignette
        inv.inputs[2].default_value = 1 - vignette
        nt.links.new(blur.outputs[0], inv.inputs[0])
        vm = nt.nodes.new("CompositorNodeMixRGB")
        vm.blend_type = "MULTIPLY"
        vm.inputs[0].default_value = 1.0
        nt.links.new(last, vm.inputs[1])
        nt.links.new(inv.outputs[0], vm.inputs[2])
        last = vm.outputs[0]
    hs = nt.nodes.new("CompositorNodeHueSat")
    hs.inputs["Saturation"].default_value = 1.22
    nt.links.new(last, hs.inputs["Image"])
    bc = nt.nodes.new("CompositorNodeBrightContrast")
    bc.inputs["Contrast"].default_value = 9
    nt.links.new(hs.outputs[0], bc.inputs["Image"])
    comp = nt.nodes.new("CompositorNodeComposite")
    nt.links.new(bc.outputs[0], comp.inputs["Image"])


def mat_logo_gold(name="LogoGold"):
    """Yellow-to-orange vertical gradient, glossy, like a premium game logo."""
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tc = node(nt, "ShaderNodeTexCoord", (-900, 0))
    sep = node(nt, "ShaderNodeSeparateXYZ", (-700, 0))
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-450, 0)
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.2, (1.0, 0.45, 0.0, 1)
    el[1].position, el[1].color = 0.8, (1.0, 0.95, 0.1, 1)
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.25
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Emission Color"].default_value = (1.0, 0.6, 0.1, 1)
    b.inputs["Emission Strength"].default_value = 0.6
    nt.links.new(ramp.outputs["Color"], b.inputs["Emission Color"])
    return m


def make_logo(cam, text="STRIKE OIL!", screen=(-0.0, 0.3), depth=6.0, size=1.0, tilt=-6, sub=None):
    """3D logo parented to the camera: gold face, thick navy outline, deep shadow layer."""
    gold = mat_logo_gold()
    navy = mat_glossy("LogoNavy", (0.01, 0.015, 0.06), rough=0.35)
    t = make_text("Logo", text, gold, size=size, extrude=0.12, bevel=0.025, font=FONT_BLACK,
                  rot=(0, 0, 0), outline_mat=navy, outline=0.075 * size, outline_depth=0.15)
    t.parent = cam
    # place in camera space: x,y in "screen units" at the given depth
    fov_h = 2 * math.tan(cam.data.angle / 2) * depth
    t.location = (screen[0] * fov_h / 2, screen[1] * fov_h / 2 * 9 / 16, -depth)
    face = Vector((-t.location.x, -t.location.y, depth)).normalized()
    t.rotation_euler = Vector((0, 0, 1)).rotation_difference(face).to_euler()
    t.rotation_euler.z += math.radians(tilt)
    if sub:
        w = mat_glossy("LogoWhite", (0.98, 0.98, 1.0), rough=0.3)
        s = make_text("LogoSub", sub, w, size=size * 0.36, extrude=0.06, bevel=0.01, font=FONT_BLACK, rot=(0, 0, 0),
                      outline_mat=navy, outline=0.05 * size, outline_depth=0.1)
        s.parent = t
        s.location = (0, -size * 0.78, 0.05)
    return t


def make_cloud(name, loc, size=6.0, seed=0, puffs=9):
    """Stylised puffy cloud: metaball cluster, soft white with subsurface."""
    random.seed(seed)
    mb = bpy.data.metaballs.new(name)
    mb.resolution = 0.4
    mb.render_resolution = 0.08
    ob = link(bpy.data.objects.new(name, mb))
    for i in range(puffs):
        e = mb.elements.new()
        e.co = (random.uniform(-1, 1) * size * 0.55, random.uniform(-0.3, 0.3) * size * 0.4,
                random.uniform(0, 0.35) * size * 0.4)
        e.radius = size * random.uniform(0.22, 0.38)
    m = bpy.data.materials.get("Cloud")
    if not m:
        m = new_mat("Cloud")
        b = principled(m.node_tree)
        b.inputs["Base Color"].default_value = (1, 1, 1, 1)
        b.inputs["Roughness"].default_value = 0.9
        b.inputs["Subsurface Weight"].default_value = 0.35
        b.inputs["Subsurface Radius"].default_value = (1.0, 0.9, 1.0)
        b.inputs["Subsurface Scale"].default_value = 0.6
    mb.materials.append(m)
    ob.location = loc
    return ob


def fresh_scene(name):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.lights, bpy.data.cameras, bpy.data.materials):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)
    bpy.context.scene.name = name
