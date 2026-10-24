# Concept 2: Oil Rush - the strike moment with an oil splash
exec(open(r"C:\Users\liter\AppData\Local\Temp\claude\C--Rblxspeel-RobloxBaseDup\774015e4-7e13-400b-8b29-60bb178a238c\scratchpad\so_kit.py").read())
fresh_scene("C2_OilRush")
random.seed(11)
sc = bpy.context.scene

world_gradient(top=(0.02, 0.08, 0.45), horizon=(1.0, 0.5, 0.2), strength=1.0)
lane_mat = mat_wood_lane()
rounded_box("Lane", (4.0, 40, 0.4), lane_mat, bevel=0.05, loc=(0, 0, -0.4))
deck = mat_glossy("Deck", (0.06, 0.05, 0.08), rough=0.35, metal=0.3)
# (no back wall: the course floats in the sky, like the game)
gut_mat = mat_glossy("Gutter", (0.05, 0.06, 0.12), rough=0.25, metal=0.8)
for x in (-4.7, 4.7):
    rounded_box("Gutter%d" % x, (0.7, 40, 0.25), gut_mat, bevel=0.2, loc=(x, 0, -0.55))
for i, (x, y, z, s) in enumerate(((-16, 30, -4, 10), (18, 34, -3, 11), (-26, 70, 1, 16), (30, 80, 2, 18), (0, 110, -3, 20))):
    make_cloud("Cloud%d" % i, (x, y, z), size=s, seed=i + 20, puffs=14)

pin_mat = mat_pin()
oil = mat_black_gold()
SP = 12 / 4.25
rows = [(0, 0)]
pins_xy = []
for r in range(4):
    for k in range(r + 1):
        pins_xy.append(((k - r / 2) * SP, 6.0 + r * SP * 0.866))

# impact: ball at the head pin; nearby pins fly, back pins topple
pins = []
for i, (x, y) in enumerate(pins_xy):
    d = Vector((x, y - 6.0, 0))
    dist = d.length
    if i == 0:
        loc, rot = (x - 1.2, y + 0.6, 2.6), (math.radians(-70), math.radians(35), math.radians(20))
    elif dist < 3.5:
        side = 1 if x >= 0 else -1
        loc = (x + side * 1.4, y + 0.8, 1.2 + random.uniform(0.4, 1.4))
        rot = (math.radians(random.uniform(-80, -40)), math.radians(side * random.uniform(30, 70)), random.uniform(-1, 1))
    elif dist < 6.0:
        side = 1 if x > 0 else -1
        loc = (x + side * 0.5, y + 0.2, 0.3)
        rot = (math.radians(random.uniform(-35, -15)), math.radians(side * random.uniform(15, 35)), 0)
    else:
        loc, rot = (x, y, 0), (0, 0, random.uniform(0, 3))
    p = make_pin("Pin%d" % i, pin_mat, loc=loc, rot=rot)
    pins.append(p)

ball_mat = mat_swirl_ball("HeroBall", (0.35, 0.02, 0.02), (1.0, 0.45, 0.05), (1.0, 0.85, 0.25), scale=1.1)
ball = make_ball("HeroBall", ball_mat, radius=1.0, loc=(0.25, 4.6, 1.0), rot=(math.radians(-60), math.radians(10), math.radians(25)))

# oil splash: a crown of droplets thrown up and out from the impact point
impact = Vector((0.2, 5.4, 0.6))
mb = bpy.data.metaballs.new("SplashCore")
mb.resolution = 0.12
mb.render_resolution = 0.05
core = link(bpy.data.objects.new("SplashCore", mb))
core.data.materials.append(oil)
for i in range(26):
    a = random.uniform(-math.pi * 0.95, math.pi * 0.95)
    up = random.uniform(0.25, 1.0)
    dirv = Vector((math.sin(a) * 1.1, math.cos(a) * 0.5 + 0.35, up)).normalized()
    for j in range(3):
        e = mb.elements.new()
        e.co = impact + dirv * (0.5 + j * 0.45) * random.uniform(1.0, 1.6)
        e.radius = 0.32 - j * 0.07
drops = []
for i in range(34):
    a = random.uniform(-math.pi, math.pi)
    up = random.uniform(0.15, 1.1)
    dirv = Vector((math.sin(a), math.cos(a) * 0.6 + 0.2, up)).normalized()
    dist = random.uniform(1.8, 5.5)
    r = random.uniform(0.05, 0.16) * (1.4 - dist / 6)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=max(0.035, r), segments=24, ring_count=12, location=impact + dirv * dist)
    d = bpy.context.active_object
    d.name = "Drop%d" % i
    d.scale = (1, 1, random.uniform(2.2, 3.6))
    d.rotation_euler = Vector((0, 0, 1)).rotation_difference(dirv).to_euler()
    smooth(d)
    d.data.materials.append(oil)
# oil slick on the lane under the impact
me = bpy.data.meshes.new("Slick")
bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=1.0)
for v in bm.verts:
    an = math.atan2(v.co.y, v.co.x)
    rr = 1 + 0.25 * math.sin(5 * an) + 0.12 * math.sin(11 * an + 1)
    v.co.x *= rr * 3.0
    v.co.y *= rr * 2.2
bm.to_mesh(me)
bm.free()
slick = link(bpy.data.objects.new("Slick", me))
slick.data.materials.append(oil)
slick.modifiers.new("s", "SOLIDIFY").thickness = 0.03
slick.modifiers.new("sub", "SUBSURF").levels = 2
smooth(slick)
slick.location = (0.0, 4.2, 0.006)

# lighting: low warm sun behind the pins (backlight through the splash), key from front-left, cyan rim
sun_light("Sun", (-80, 0, 175), 3.5, color=(1.0, 0.72, 0.4), angle=4)
area_light("Key", (-6, -2.5, 5.0), (55, 0, -60), 6, 1400, color=(1.0, 0.96, 0.92))
area_light("Rim", (6, 9, 2.5), (80, 0, 130), 4, 900, color=(0.4, 0.8, 1.0))
area_light("Fill", (2, -6, 1.5), (85, 0, 15), 5, 250, color=(0.85, 0.85, 1.0))

camera("Cam", (-4.6, -1.6, 0.7), (0.5, 6.2, 1.9), lens=22, dof_target=(0.25, 4.6, 1.0), fstop=3.2)
render_setup(samples=96, res=(960, 540))
post_fx(haze=(1.0, 0.7, 0.5), amount=0.3, start=16, depth=80)

# motion blur: pins spinning, ball driving forward
sc.frame_set(1)
for p in pins[:6] + [ball]:
    p.keyframe_insert("rotation_euler", frame=1)
    p.rotation_euler.x += math.radians(-25)
    p.keyframe_insert("rotation_euler", frame=2)
    p.rotation_euler.x -= math.radians(-25)
sc.render.use_motion_blur = True
sc.render.motion_blur_shutter = 0.5
sc.frame_set(1)
print("built C2", len(bpy.data.objects))
# splash crown around the ball's contact point (thin sheet with spiky rim + tip droplets)
me = bpy.data.meshes.new("Crown")
bm = bmesh.new()
N = 36
base, top = [], []
for i in range(N):
    a = 2 * math.pi * i / N
    h = 0.9 + (0.55 if i % 2 == 0 else 0.0) + random.uniform(-0.15, 0.25)
    rb, rt = 0.75, 1.45 + random.uniform(-0.1, 0.15)
    base.append(bm.verts.new((math.cos(a) * rb, math.sin(a) * rb * 0.8, 0.0)))
    top.append(bm.verts.new((math.cos(a) * rt, math.sin(a) * rt * 0.8, h)))
for i in range(N):
    j = (i + 1) % N
    bm.faces.new((base[i], base[j], top[j], top[i]))
bm.to_mesh(me)
bm.free()
crown = link(bpy.data.objects.new("Crown", me))
crown.data.materials.append(oil)
sol = crown.modifiers.new("s", "SOLIDIFY")
sol.thickness = 0.06
sub = crown.modifiers.new("sub", "SUBSURF")
sub.levels = 2
sub.render_levels = 3
smooth(crown)
crown.location = (0.25, 4.6, 0.0)
crown.scale = (1.25, 1.25, 1.1)
for i, v in enumerate(me.vertices):
    if v.co.z > 1.3:
        w = crown.matrix_world @ v.co
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.07, 0.12), segments=24, ring_count=12,
                                             location=w + Vector((0, 0, random.uniform(0.25, 0.6))))
        t = bpy.context.active_object
        t.name = "Tip%d" % i
        t.scale = (1, 1, 1.6)
        smooth(t)
        t.data.materials.append(oil)
core.hide_render = True
# replace the bowl-like crown with liquid jets: tapered curved strands breaking into droplets
crown.hide_render = True
for o in bpy.data.objects:
    if o.name.startswith("Tip"):
        o.hide_render = True
taper = bpy.data.curves.new("Taper", "CURVE")
taper.dimensions = "2D"
sp = taper.splines.new("BEZIER")
sp.bezier_points.add(2)
for bp, (x, y) in zip(sp.bezier_points, ((0, 0.25), (0.5, 1.0), (1.0, 0.0))):
    bp.co = (x, y, 0)
    bp.handle_left_type = bp.handle_right_type = "AUTO"
tap = link(bpy.data.objects.new("TaperObj", taper))
tap.hide_render = True
tap.hide_viewport = True
contact = Vector((0.25, 4.9, 0.05))
random.seed(5)
for i in range(22):
    a = random.uniform(-math.pi * 0.9, math.pi * 0.9)
    horiz = Vector((math.sin(a), math.cos(a) * 0.55 + 0.25, 0)).normalized()
    reach = random.uniform(1.6, 3.4)
    height = random.uniform(0.8, 2.6)
    p0 = contact + horiz * 0.7
    p2 = contact + horiz * reach + Vector((0, 0, height))
    p1 = contact + horiz * (reach * 0.35) + Vector((0, 0, height * 1.15))
    cu = bpy.data.curves.new("Jet%d" % i, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = random.uniform(0.07, 0.13)
    cu.bevel_resolution = 4
    cu.resolution_u = 24
    cu.taper_object = tap
    cu.use_fill_caps = True
    s = cu.splines.new("BEZIER")
    s.bezier_points.add(1)
    s.bezier_points[0].co = p0
    s.bezier_points[0].handle_right = p1
    s.bezier_points[0].handle_left = p0 - (p1 - p0) * 0.3
    s.bezier_points[1].co = p2
    s.bezier_points[1].handle_left = p2 - (p2 - p1) * 0.5
    s.bezier_points[1].handle_right = p2 + (p2 - p1) * 0.3
    jet = link(bpy.data.objects.new("Jet%d" % i, cu))
    jet.data.materials.append(oil)
    for k in range(random.randint(1, 3)):
        tip = p2 + (p2 - p1).normalized() * (0.35 + k * 0.4)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=cu.bevel_depth * random.uniform(0.7, 1.1), segments=24, ring_count=12, location=tip)
        t = bpy.context.active_object
        t.name = "JetDrop%d_%d" % (i, k)
        t.scale = (1, 1, 1.5)
        t.rotation_euler = Vector((0, 0, 1)).rotation_difference((p2 - p1).normalized()).to_euler()
        smooth(t)
        t.data.materials.append(oil)
# v3 splash: everything as ONE metaball liquid (jets merge at the base, break into drops at the tips)
for o in bpy.data.objects:
    if o.name.startswith(("Jet", "Drop", "Tip")):
        o.hide_render = True
liquid = mat_oil("OilLiquid")
mbl = bpy.data.metaballs.new("Splash")
mbl.resolution = 0.08
mbl.render_resolution = 0.03
mbl.threshold = 0.6
spl = link(bpy.data.objects.new("Splash", mbl))
spl.data.materials.append(liquid)


def bez(p0, p1, p2, t):
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2


random.seed(21)
for i in range(24):
    a = random.uniform(-math.pi * 0.85, math.pi * 0.85)
    horiz = Vector((math.sin(a), math.cos(a) * 0.5 + 0.3, 0)).normalized()
    reach = random.uniform(2.0, 4.4)
    height = random.uniform(1.4, 3.6)
    p0 = contact + horiz * 0.6
    p2 = contact + horiz * reach + Vector((0, 0, height))
    p1 = contact + horiz * (reach * 0.3) + Vector((0, 0, height * 1.2))
    steps = 30
    for k in range(steps):
        t = k / (steps - 1)
        tt = t
        e = mbl.elements.new()
        e.co = bez(p0, p1, p2, min(tt, 1.25))
        e.radius = 0.55 * (1 - 0.82 * t ** 0.7) + random.uniform(-0.02, 0.02)
    for tt, rr in ((1.12, 0.16), (1.3, 0.12)):
        e = mbl.elements.new()
        e.co = bez(p0, p1, p2, tt)
        e.radius = rr
for i in range(10):  # base pool around the contact
    e = mbl.elements.new()
    ang = random.uniform(0, 2 * math.pi)
    e.co = contact + Vector((math.cos(ang) * random.uniform(0.6, 1.4), math.sin(ang) * random.uniform(0.4, 1.0), 0.05))
    e.radius = random.uniform(0.5, 0.8)
for i in range(26):  # loose droplets
    a = random.uniform(-math.pi, math.pi)
    dirv = Vector((math.sin(a), math.cos(a) * 0.6 + 0.2, random.uniform(0.3, 1.2))).normalized()
    e = mbl.elements.new()
    e.type = "BALL"
    e.co = contact + dirv * random.uniform(2.0, 4.8)
    e.radius = random.uniform(0.18, 0.34)
    e.size_x = e.size_y = 0.5
    e.size_z = 1.0
    e.rotation = Vector((0, 0, 1)).rotation_difference(dirv)
logo = make_logo(sc.camera, "STRIKE OIL!", screen=(-0.42, 0.62), depth=5.0, size=0.62, tilt=4, sub=None)
