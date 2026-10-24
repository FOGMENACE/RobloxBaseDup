# Concept 1: Gate Decision
exec(open(r"C:\Users\liter\AppData\Local\Temp\claude\C--Rblxspeel-RobloxBaseDup\774015e4-7e13-400b-8b29-60bb178a238c\scratchpad\so_kit.py").read())
fresh_scene("C1_GateDecision")
random.seed(7)

# sky + lane
world_gradient(top=(0.03, 0.22, 0.95), horizon=(0.72, 0.88, 1.0), strength=1.15)
lane_mat = mat_wood_lane()
rounded_box("Lane", (4.5, 90, 0.4), lane_mat, bevel=0.05, loc=(0, 40, -0.4))
gut_mat = mat_glossy("Gutter", (0.05, 0.06, 0.12), rough=0.25, metal=0.8)
for x in (-5.3, 5.3):
    rounded_box("Gutter%d" % x, (0.8, 90, 0.25), gut_mat, bevel=0.2, loc=(x, 40, -0.55))
    rounded_box("Rail%d" % x, (0.18, 90, 0.35), mat_glossy("Rail", (0.6, 0.42, 0.12), rough=0.3, metal=1.0),
                bevel=0.08, loc=(x * 1.17, 40, -0.25))
# lane arrows (the game paints chevrons on the lane)
arrow_mat = mat_glossy("Arrow", (0.08, 0.03, 0.06), rough=0.3)
for i, x in enumerate((-2.4, -1.2, 0.0, 1.2, 2.4)):
    for side in (-1, 1):
        a = rounded_box("Chev%d%d" % (i, side), (0.35, 0.06, 0.004), arrow_mat, bevel=0.02,
                        loc=(x + side * 0.25, 3.5 + abs(x) * 0.6, 0.004), rot=(0, 0, math.radians(-35 * side)))

# gates
frame_mat = mat_glossy("Frame", (0.02, 0.025, 0.05), rough=0.3, metal=0.6)
good_mat = mat_glossy("GoodPanel", (0.01, 0.55, 0.08), rough=0.2, coat=1.0, emit=(0.02, 0.9, 0.15), emit_str=0.9)
bad_mat = mat_glossy("BadPanel", (0.6, 0.01, 0.02), rough=0.2, coat=1.0, emit=(1.0, 0.03, 0.04), emit_str=0.7)
white = mat_glossy("TextWhite", (0.97, 0.97, 0.97), rough=0.3, coat=0.5)
ink = mat_glossy("TextInk", (0.01, 0.015, 0.04), rough=0.4)


def gate(y, left, right, lmat, rmat, scale=1.0):
    w, h = 4.3 * scale, 3.4 * scale
    rounded_box("GateL%d" % y, (w / 2, 0.14, h / 2), lmat, bevel=0.18, loc=(-w / 2 - 0.12, y, h / 2 + 0.25))
    rounded_box("GateR%d" % y, (w / 2, 0.14, h / 2), rmat, bevel=0.18, loc=(w / 2 + 0.12, y, h / 2 + 0.25))
    for x in (-(w + 0.3), 0, (w + 0.3)):
        rounded_box("Post%d_%s" % (y, x), (0.16, 0.2, (h + 0.8) / 2), frame_mat, bevel=0.06, loc=(x, y, (h + 0.8) / 2))
    rounded_box("Bar%d" % y, (w + 0.5, 0.22, 0.14), frame_mat, bevel=0.06, loc=(0, y, h + 0.75))
    make_text("TL%d" % y, left, white, size=1.55 * scale, loc=(-w / 2 - 0.12, y - 0.2, h / 2 + 0.3),
              outline_mat=ink, outline=0.07, extrude=0.06)
    make_text("TR%d" % y, right, white, size=1.55 * scale, loc=(w / 2 + 0.12, y - 0.2, h / 2 + 0.3),
              outline_mat=ink, outline=0.07, extrude=0.06)


gate(7, "+999", "-67", good_mat, bad_mat, scale=1.2)
gate(24, "x4", "÷2", good_mat, bad_mat)
gate(42, "+522", "GUTTER", good_mat, bad_mat)

# hero ball (rolling, heading for the green side)
ball_mat = mat_swirl_ball("HeroBall", (0.10, 0.02, 0.35), (0.85, 0.15, 0.75), (0.15, 0.75, 1.0), scale=1.3)
ball = make_ball("HeroBall", ball_mat, radius=1.35, loc=(-1.25, -1.5, 1.35), rot=(math.radians(-75), math.radians(35), math.radians(30)))

# oil trail + droplets
oil = mat_oil()
P0, P1, P2 = Vector((3.2, -12.0, 0.012)), Vector((1.4, -4.0, 0.012)), Vector((-0.6, -0.9, 0.012))
pts = [(1 - t) ** 2 * P0 + 2 * (1 - t) * t * P1 + t * t * P2 for t in [i / 40 for i in range(41)]]
me = bpy.data.meshes.new("OilTrail")
bm = bmesh.new()
pts.sort(key=lambda p: p.y)
left, right = [], []
for i, p in enumerate(pts):
    t = i / max(1, len(pts) - 1)
    width = 0.25 + 0.75 * t
    nxt = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
    side = Vector((nxt.y, -nxt.x, 0)).normalized() * width
    left.append(bm.verts.new(p + side))
    right.append(bm.verts.new(p - side))
for i in range(len(pts) - 1):
    bm.faces.new((left[i], left[i + 1], right[i + 1], right[i]))
bm.to_mesh(me)
bm.free()
trail = link(bpy.data.objects.new("OilTrail", me)); trail.hide_render = True
trail.data.materials.append(oil)
sol = trail.modifiers.new("thick", "SOLIDIFY")
sol.thickness = 0.03
trail.modifiers.new("sub", "SUBSURF").levels = 2
smooth(trail)

for i in range(7):
    r = random.uniform(0.04, 0.09)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=24, ring_count=12,
                                         location=(-0.6 + random.uniform(0.9, 2.2), -0.8 + random.uniform(-2.6, -1.0),
                                                   random.uniform(0.15, 0.9)))
    d = bpy.context.active_object
    d.name = "Drop%d" % i
    d.scale = (1, random.uniform(2.5, 4.0), 1)
    d.rotation_euler = (random.uniform(-0.2, 0.2), 0, random.uniform(-0.3, 0.3))
    smooth(d)
    d.data.materials.append(oil)

# lighting: warm back sun through the gates, cool rim, soft key from camera left
sun_light("Sun", (-58, 0, 150), 3.0, color=(1.0, 0.85, 0.65), angle=3); sun_light("SunFront", (50, 0, -30), 2.2, color=(1.0, 0.96, 0.9), angle=5)
area_light("Key", (-4.5, -6.0, 4.5), (60, 0, -35), 6, 900, color=(1.0, 0.95, 0.92))
area_light("Rim", (4.5, 4.5, 3.0), (70, 0, 145), 3, 600, color=(0.45, 0.8, 1.0))
area_light("GateGlow", (0, 11.5, 2.2), (90, 0, 180), 8, 300, color=(0.5, 1.0, 0.6), size_y=3)

camera("Cam", (3.0, -8.6, 3.3), (-0.9, 8.0, 2.3), lens=22, dof_target=(-1.25, -1.5, 1.35), fstop=4.0)
render_setup(samples=96, res=(960, 540))
for i, (x, y, z, s) in enumerate(((-18, 40, -6, 9), (16, 30, -5, 8), (-30, 90, 2, 14), (28, 100, 0, 16),
                                  (-10, 140, -2, 18), (8, -2, -7, 6), (-12, 12, -8, 7))):
    make_cloud("Cloud%d" % i, (x, y, z), size=s * 1.4, seed=i, puffs=14)
post_fx(haze=(0.75, 0.88, 1.0), amount=0.3, start=18, depth=90)
print("built C1", len(bpy.data.objects))
# motion: the ball spins fast (motion blur sells the speed)
sc = bpy.context.scene
sc.frame_set(1)
ball.keyframe_insert("rotation_euler", frame=1)
ball.rotation_euler.x += math.radians(-55)
ball.keyframe_insert("rotation_euler", frame=2)
ball.rotation_euler.x -= math.radians(-55)
sc.render.use_motion_blur = True
sc.render.motion_blur_shutter = 0.5
sc.frame_set(1)
# oil puddles on the lane: the ball's line toward the green gate
def puddle(name, loc, sx, sy, seed):
    random.seed(seed)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=48, radius=1.0)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        r = 1.0 + 0.18 * math.sin(3 * a + seed) + 0.1 * math.sin(7 * a + seed * 2)
        v.co.x *= r * sx
        v.co.y *= r * sy
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.data.materials.append(oil)
    s = o.modifiers.new("s", "SOLIDIFY")
    s.thickness = 0.025
    o.modifiers.new("sub", "SUBSURF").levels = 2
    smooth(o)
    o.location = loc
    return o

for i, (x, y, sx, sy) in enumerate(((-0.9, 1.5, 0.55, 1.6), (-1.6, 3.8, 0.4, 0.9), (-0.7, 5.0, 0.3, 0.6),
                                    (-0.4, -3.6, 0.45, 1.2), (0.1, -5.6, 0.3, 0.7))):
    puddle("Puddle%d" % i, (x, y, 0.005), sx, sy, i + 3)
