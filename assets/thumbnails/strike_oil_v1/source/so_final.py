# Final: Gate Decision refined (concept 1 framing) + oil spray, reward-gate glow, richer sky, logo
exec(open(r"C:\Users\liter\AppData\Local\Temp\claude\C--Rblxspeel-RobloxBaseDup\774015e4-7e13-400b-8b29-60bb178a238c\scratchpad\so_c1.py").read())
for o in bpy.data.objects:
    if o.name.startswith(("Drop", "Cloud")):
        bpy.data.objects.remove(o, do_unlink=True)
sc = bpy.context.scene
random.seed(8)

w = sc.world
ramp = next(n for n in w.node_tree.nodes if n.type == "VALTORGB")
ramp.color_ramp.elements[0].color = (0.62, 0.84, 1.0, 1)
ramp.color_ramp.elements[-1].color = (0.01, 0.16, 0.85, 1)
for i, (x, y, z, s) in enumerate(((-17, 26, -5, 12), (19, 34, -4, 13), (-28, 70, 1, 18), (32, 80, 2, 20), (-6, 120, -1, 22))):
    make_cloud("FCloud%d" % i, (x, y, z), size=s, seed=i + 60, puffs=16)

ball = bpy.data.objects["HeroBall"]
# oil: a glossy pool where the ball meets the lane + a low fan of spray behind it (no long streams)
liquid = mat_oil("OilWake")
mbl = bpy.data.metaballs.new("Wake")
mbl.resolution = 0.06
mbl.render_resolution = 0.025
mbl.threshold = 0.6
wake = link(bpy.data.objects.new("Wake", mbl))
wake.data.materials.append(liquid)
c = Vector((ball.location.x, ball.location.y, 0.03))
for i in range(14):
    e = mbl.elements.new()
    a = random.uniform(0, 2 * math.pi)
    e.co = c + Vector((math.cos(a) * random.uniform(0.4, 1.6), math.sin(a) * random.uniform(0.3, 1.2) - 1.4, -0.12))
    e.radius = random.uniform(0.45, 0.7)
for i in range(0):
    side = random.choice((-1, 1))
    t = random.random()
    e = mbl.elements.new()
    e.co = c + Vector((side * (0.9 + t * 2.4), -0.6 - t * 2.8 + random.uniform(-0.3, 0.3), 0.15 + t * random.uniform(0.3, 1.6)))
    e.radius = (0.2 - 0.12 * t) * random.uniform(0.7, 1.2)

principled(bpy.data.materials["GoodPanel"].node_tree).inputs["Emission Strength"].default_value = 1.5
principled(bpy.data.materials["BadPanel"].node_tree).inputs["Emission Strength"].default_value = 0.45
area_light("GoodHalo", (-2.6, 5.6, 2.5), (90, 0, 180), 5, 700, color=(0.3, 1.0, 0.45), size_y=4)

cam = sc.camera
logo = make_logo(cam, "STRIKE OIL!", screen=(-0.45, 0.7), depth=5.0, size=0.58, tilt=3)
post_fx(haze=(0.7, 0.85, 1.0), amount=0.28, start=18, depth=90)
print("final built", len(bpy.data.objects))
# the pool is squashed flat into a slick on the lane surface
wake.scale = (1.0, 1.0, 0.18)
wake.location.z = 0.02
# holes visible (reads as a bowling ball, not a marble); gentler spin blur
ball.animation_data_clear()
ball.rotation_euler = (math.radians(-40), 0, math.radians(38))
sc.frame_set(1)
ball.keyframe_insert("rotation_euler", frame=1)
ball.rotation_euler.x += math.radians(-12)
ball.keyframe_insert("rotation_euler", frame=2)
ball.rotation_euler.x -= math.radians(-12)
sc.frame_set(1)
# crisp white borders around the first gate's panels (pop at small sizes)
rim = mat_glossy("PanelRim", (0.97, 0.97, 1.0), rough=0.25, coat=1.0)
for nm in ("GateL7", "GateR7"):
    p = bpy.data.objects[nm]
    r = rounded_box(nm + "_rim", (2.58 * 1.0 + 0.0, 0.1, 2.04 + 0.0), rim, bevel=0.22,
                    loc=(p.location.x, p.location.y + 0.12, p.location.z))
    r.dimensions = (p.dimensions.x + 0.32, 0.2, p.dimensions.z + 0.32)
