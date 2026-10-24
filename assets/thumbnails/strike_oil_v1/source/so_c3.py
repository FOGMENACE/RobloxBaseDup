# Concept 3: Progression - balls and multipliers climbing tier by tier (x2 -> x1000, like the game's XP generators)
exec(open(r"C:\Users\liter\AppData\Local\Temp\claude\C--Rblxspeel-RobloxBaseDup\774015e4-7e13-400b-8b29-60bb178a238c\scratchpad\so_kit.py").read())
fresh_scene("C3_Progression")
random.seed(3)
sc = bpy.context.scene

world_gradient(top=(0.02, 0.2, 0.95), horizon=(0.65, 0.85, 1.0), strength=1.15)
for i, (x, y, z, s) in enumerate(((-24, 40, -8, 12), (24, 36, -9, 12), (-36, 80, -2, 18), (38, 90, 0, 20),
                                  (2, 110, -6, 22), (-10, 18, -12, 9), (14, 16, -12, 9))):
    make_cloud("Cloud%d" % i, (x, y, z), size=s * 1.3, seed=i + 40, puffs=14)


def cylinder(name, r, h, mat, loc, bevel=0.15):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=64, radius1=r, radius2=r, depth=h)
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    bv = o.modifiers.new("b", "BEVEL")
    bv.width = bevel
    bv.segments = 5
    bv.limit_method = "ANGLE"
    o.modifiers.new("wn", "WEIGHTED_NORMAL")
    smooth(o)
    o.data.materials.append(mat)
    o.location = loc
    return o


tiers = [  # label, ball palette (dark, mid, light), rarity colour, ball radius
    ("x2", ((0.25, 0.27, 0.32), (0.6, 0.63, 0.7), (0.92, 0.93, 0.96)), (0.7, 0.75, 0.85), 0.75),
    ("x10", ((0.0, 0.08, 0.4), (0.05, 0.45, 1.0), (0.5, 0.9, 1.0)), (0.1, 0.55, 1.0), 0.95),
    ("x100", ((0.15, 0.0, 0.35), (0.7, 0.1, 0.95), (1.0, 0.55, 0.95)), (0.7, 0.15, 1.0), 1.2),
    ("x1000", ((0.45, 0.12, 0.0), (1.0, 0.62, 0.05), (1.0, 0.95, 0.6)), (1.0, 0.72, 0.08), 1.65),
]
white_stone = mat_glossy("PodiumWhite", (0.95, 0.95, 0.98), rough=0.22, coat=1.0)
ink = mat_glossy("Ink", (0.01, 0.015, 0.05), rough=0.4)
gold_txt = mat_logo_gold("NumGold")
balls = []
for i, (label, pal, rc, rad) in enumerate(tiers):
    x = 3.6 - (3 - i) * 3.3
    y = -0.5 + (3 - i) * 3.6
    h = 0.6 + i * 1.35
    cylinder("Podium%d" % i, 1.25 + i * 0.18, h, white_stone, (x, y, h / 2 - 0.6))
    ring = mat_glossy("Ring%d" % i, rc, rough=0.15, metal=0.4, emit=rc, emit_str=3.0)
    cylinder("Band%d" % i, 1.29 + i * 0.18, 0.16, ring, (x, y, h - 0.6 - 0.22), bevel=0.05)
    bm_ = mat_swirl_ball("Ball%d" % i, *pal, scale=1.2)
    if i == 3:
        principled(bm_.node_tree).inputs["Metallic"].default_value = 0.55
    b = make_ball("Ball%d" % i, bm_, radius=rad, loc=(x, y, h - 0.6 + rad),
                  rot=(math.radians(-35), math.radians(10 + i * 15), math.radians(-35 + i * 20)))
    balls.append(b)
    t = make_text("Num%d" % i, label, gold_txt if i == 3 else mat_glossy("NumW%d" % i, (0.98, 0.98, 1.0), rough=0.3),
                  size=0.75 + i * 0.32, extrude=0.1, bevel=0.02, loc=(x, y - 0.3, h - 0.6 + 2 * rad + 0.75 + i * 0.12),
                  rot=(math.radians(82), 0, math.radians(-8)), outline_mat=ink, outline=0.06 + i * 0.012)

# the player: an original blocky avatar cheering beside the top ball
face = ASSETS + r"\thumbnails\source\face_man.png"
top_h = 0.6 + 3 * 1.35 - 0.6
av, parts = make_avatar("Hero", shirt=(0.95, 0.25, 0.1), pants=(0.1, 0.15, 0.35), face_img=face, hair=(0.08, 0.06, 0.05),
                        loc=(3.6 + 1.55, -0.5 - 0.9, top_h), rot_z=-30, scale=0.55,
                        pose={"armL": (0, 150, 0), "armR": (0, -140, 0), "head": (8, 0, 12), "legL": (0, 6, 0), "legR": (0, -6, 0)})

# lighting: warm key sun, big soft key, cool rim from behind
sun_light("Sun", (50, 0, -40), 3.0, color=(1.0, 0.92, 0.8), angle=3)
area_light("Key", (-9, -9, 8), (55, 0, -40), 10, 1600, color=(1.0, 0.97, 0.95))
area_light("Rim", (8, 12, 7), (60, 0, 150), 8, 1800, color=(0.5, 0.8, 1.0))

camera("Cam", (-4.5, -13.6, 4.4), (-0.3, 4.5, 4.1), lens=24, dof_target=(3.6, -0.5, 4.5), fstop=6)
render_setup(samples=96, res=(960, 540))
post_fx(haze=(0.7, 0.85, 1.0), amount=0.15, start=30, depth=110)
print("built C3", len(bpy.data.objects))
