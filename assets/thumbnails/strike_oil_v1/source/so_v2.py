# Final v2: authentic lane direction/markings, premium ball, subtle oil, cleaner light
# Direction (verified in assets/thumbnails/source/oil_course.jpg): camera behind the ball, the ball rolls
# AWAY from the camera (+Y) toward the gates; lane arrows point down-lane and form a V whose centre
# arrow is furthest down-lane (standard targeting arrows: boards 5..35, every 5 boards, pointing at the pins).
exec(open(r"C:\Users\liter\AppData\Local\Temp\claude\C--Rblxspeel-RobloxBaseDup\774015e4-7e13-400b-8b29-60bb178a238c\scratchpad\so_final.py").read())
sc = bpy.context.scene

# ---- remove what was wrong or distracting
for o in list(bpy.data.objects):
    if o.name.startswith(("Chev", "Puddle", "Wake", "OilTrail", "Gutter", "Rail", "GateL7_rim", "GateR7_rim")) \
            or o.name in ("GateGlow", "GoodHalo"):
        bpy.data.objects.remove(o, do_unlink=True)

LANE_W = 9.0
BOARD = LANE_W / 39.0  # 39 boards across, like a real lane
lane = bpy.data.objects["Lane"]


def mat_lane_boards(name="LaneBoards"):
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tc = node(nt, "ShaderNodeTexCoord", (-1500, 0))
    sep = node(nt, "ShaderNodeSeparateXYZ", (-1300, 0))
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    div = node(nt, "ShaderNodeMath", (-1100, 100))
    div.operation = "DIVIDE"
    div.inputs[1].default_value = BOARD
    nt.links.new(sep.outputs["X"], div.inputs[0])
    flo = node(nt, "ShaderNodeMath", (-900, 200))
    flo.operation = "FLOOR"
    nt.links.new(div.outputs[0], flo.inputs[0])
    wn = nt.nodes.new("ShaderNodeTexWhiteNoise")
    wn.noise_dimensions = "1D"
    wn.location = (-700, 200)
    nt.links.new(flo.outputs[0], wn.inputs["W"])
    # per-board tone
    tone = nt.nodes.new("ShaderNodeValToRGB")
    tone.location = (-500, 200)
    tone.color_ramp.elements[0].color = (0.70, 0.47, 0.26, 1)
    tone.color_ramp.elements[1].color = (0.86, 0.63, 0.38, 1)
    nt.links.new(wn.outputs["Value"], tone.inputs["Fac"])
    # long grain streaks
    mp = node(nt, "ShaderNodeMapping", (-1100, -200))
    mp.inputs["Scale"].default_value = (6.0, 0.05, 1.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    noise = node(nt, "ShaderNodeTexNoise", (-900, -200))
    noise.inputs["Scale"].default_value = 3.0
    noise.inputs["Detail"].default_value = 6
    nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])
    grain = node(nt, "ShaderNodeMixRGB", (-300, 100))
    grain.blend_type = "MULTIPLY"
    grain.inputs[0].default_value = 0.25
    nt.links.new(tone.outputs["Color"], grain.inputs[1])
    nt.links.new(noise.outputs["Color"], grain.inputs[2])
    # thin seams between boards
    fr = node(nt, "ShaderNodeMath", (-900, 0))
    fr.operation = "FRACT"
    nt.links.new(div.outputs[0], fr.inputs[0])
    seam = node(nt, "ShaderNodeMath", (-700, 0))
    seam.operation = "LESS_THAN"
    seam.inputs[1].default_value = 0.035
    nt.links.new(fr.outputs[0], seam.inputs[0])
    seam_mix = node(nt, "ShaderNodeMixRGB", (-100, 100))
    seam_mix.inputs[2].default_value = (0.32, 0.19, 0.1, 1)
    sm = node(nt, "ShaderNodeMath", (-500, 0))
    sm.operation = "MULTIPLY"
    sm.inputs[1].default_value = 0.6
    nt.links.new(seam.outputs[0], sm.inputs[0])
    nt.links.new(sm.outputs[0], seam_mix.inputs[0])
    nt.links.new(grain.outputs[0], seam_mix.inputs[1])
    nt.links.new(seam_mix.outputs[0], b.inputs["Base Color"])
    # oil pattern: the centre of the lane is oiled (glossier), the outside boards are drier
    ab = node(nt, "ShaderNodeMath", (-900, -450))
    ab.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["X"], ab.inputs[0])
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.location = (-700, -450)
    rr.inputs["From Min"].default_value = 2.2
    rr.inputs["From Max"].default_value = 4.2
    rr.inputs["To Min"].default_value = 0.17
    rr.inputs["To Max"].default_value = 0.36
    nt.links.new(ab.outputs[0], rr.inputs["Value"])
    nt.links.new(rr.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Coat Weight"].default_value = 0.18
    b.inputs["Coat Roughness"].default_value = 0.06
    return m


lane.data.materials.clear()
lane.data.materials.append(mat_lane_boards())

# ---- targeting arrows: dark inlaid triangles pointing down-lane, V with the centre arrow furthest
inlay = mat_glossy("Inlay", (0.06, 0.03, 0.025), rough=0.3)
ARROW_Y = 4.6  # centre arrow tip (between the ball and the gate)
for k, board in enumerate((5, 10, 15, 20, 25, 30, 35)):
    x = (board - 20) * BOARD
    step = abs(board - 20) // 5
    y = ARROW_Y - step * 0.9
    me = bpy.data.meshes.new("Arrow%d" % board)
    bm = bmesh.new()
    L, W = 1.7, BOARD * 1.3
    v = [bm.verts.new((-W / 2, -L, 0)), bm.verts.new((W / 2, -L, 0)), bm.verts.new((0, 0, 0))]
    bm.faces.new(v)
    bm.to_mesh(me)
    bm.free()
    a = link(bpy.data.objects.new("Arrow%d" % board, me))
    a.data.materials.append(inlay)
    a.location = (x, y, 0.003)
# approach dots further back (closer to the camera), also standard
for board in (3, 5, 8, 11, 14, 26, 29, 32, 35, 37):
    bpy.ops.mesh.primitive_circle_add(vertices=24, radius=BOARD * 0.38, fill_type="NGON",
                                      location=((board - 20) * BOARD, -5.2, 0.003))
    d = bpy.context.active_object
    d.name = "Dot%d" % board
    d.data.materials.append(inlay)

# ---- real gutters: half-pipes either side, then low capping
gut = mat_glossy("Gutter", (0.12, 0.13, 0.17), rough=0.35, metal=0.7)
cap = mat_glossy("Capping", (0.05, 0.06, 0.1), rough=0.4)
for side in (-1, 1):
    me = bpy.data.meshes.new("Gutter%d" % side)
    bm = bmesh.new()
    R = 0.55
    ring = []
    for i in range(17):
        a = math.pi + math.pi * i / 16
        ring.append((math.cos(a) * R, math.sin(a) * R))
    prev = None
    for yy in (-20, 100):
        row = [bm.verts.new((x, yy, z)) for x, z in ring]
        if prev:
            for i in range(16):
                bm.faces.new((prev[i], prev[i + 1], row[i + 1], row[i]))
        prev = row
    bm.to_mesh(me)
    bm.free()
    g = link(bpy.data.objects.new("Gutter%d" % side, me))
    g.data.materials.append(gut)
    g.modifiers.new("s", "SOLIDIFY").thickness = 0.05
    smooth(g)
    g.location = (side * (LANE_W / 2 + R), 0, 0.0)
    rounded_box("Capping%d" % side, (0.25, 60, 0.22), cap, bevel=0.06, loc=(side * (LANE_W / 2 + 2 * R + 0.25), 40, 0.05))

# ---- premium bowling ball: deep reactive-resin pearl, two-tone swirl, fine metallic flake
def mat_premium_ball(name="ProBall"):
    m = new_mat(name)
    nt = m.node_tree
    b = principled(nt)
    tc = node(nt, "ShaderNodeTexCoord", (-1300, 0))
    noise = node(nt, "ShaderNodeTexNoise", (-1100, 0))
    noise.inputs["Scale"].default_value = 0.9
    noise.inputs["Detail"].default_value = 4
    noise.inputs["Distortion"].default_value = 1.6
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    wave = node(nt, "ShaderNodeTexWave", (-900, 0))
    wave.inputs["Scale"].default_value = 0.85
    wave.inputs["Distortion"].default_value = 6
    wave.inputs["Detail"].default_value = 3
    nt.links.new(noise.outputs["Color"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-650, 0)
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.25, (0.05, 0.005, 0.14, 1)   # deep violet-black
    el[1].position, el[1].color = 0.75, (0.42, 0.06, 0.62, 1)   # royal purple
    e = el.new(0.92)
    e.color = (0.85, 0.35, 0.9, 1)                              # pearl pink highlight
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    # pearl: a little metallic, driven by the swirl so the dark resin stays dielectric
    met = node(nt, "ShaderNodeMath", (-400, -150))
    met.operation = "MULTIPLY"
    met.inputs[1].default_value = 0.45
    nt.links.new(wave.outputs["Fac"], met.inputs[0])
    nt.links.new(met.outputs[0], b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = 0.28
    b.inputs["Coat Weight"].default_value = 0.8
    b.inputs["Coat Roughness"].default_value = 0.06
    # fine flake in the coat
    vor = node(nt, "ShaderNodeTexVoronoi", (-650, -350))
    vor.inputs["Scale"].default_value = 220
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    bump = node(nt, "ShaderNodeBump", (-400, -350))
    bump.inputs["Strength"].default_value = 0.06
    nt.links.new(vor.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m


ball = bpy.data.objects["HeroBall"]
ball.data.materials[0] = mat_premium_ball()

# ---- subtle oil: a faint darker, glossier ball track behind the ball (no black puddles)
track = new_mat("OilTrack")
tb = principled(track.node_tree)
tb.inputs["Base Color"].default_value = (0.05, 0.03, 0.02, 1)
tb.inputs["Roughness"].default_value = 0.02
ntt = track.node_tree
gtc = node(ntt, "ShaderNodeTexCoord", (-700, 0))
gsep = node(ntt, "ShaderNodeSeparateXYZ", (-500, 0))
ntt.links.new(gtc.outputs["Generated"], gsep.inputs["Vector"])
gr = ntt.nodes.new("ShaderNodeMapRange")
gr.location = (-300, 0)
gr.inputs["To Min"].default_value = 0.0
gr.inputs["To Max"].default_value = 0.6
ntt.links.new(gsep.outputs["Y"], gr.inputs["Value"])
ntt.links.new(gr.outputs["Result"], tb.inputs["Alpha"])
track.blend_method = "BLEND"
bpy.ops.mesh.primitive_plane_add(size=1, location=(ball.location.x + 0.35, ball.location.y - 3.4, 0.004))
tr = bpy.context.active_object
tr.name = "OilTrackStrip"
tr.scale = (0.9, 6.5, 1)
tr.rotation_euler = (0, 0, math.radians(-4))
tr.data.materials.append(track)

# ---- light: softer, larger sources (no hard streak reflections), contact shadow, less haze
for nm, size in (("Key", 10), ("Rim", 8)):
    if nm in bpy.data.objects:
        bpy.data.objects[nm].data.size = size
if "Rim" in bpy.data.objects:
    bpy.data.objects["Rim"].data.energy = 500
area_light("BallKey", (-4.0, -5.0, 5.0), (50, 0, -40), 4, 450, color=(1.0, 0.96, 0.9))
principled(bpy.data.materials["GoodPanel"].node_tree).inputs["Emission Strength"].default_value = 1.1
post_fx(haze=(0.72, 0.86, 1.0), amount=0.14, start=22, depth=110, glare=0.35, vignette=0.3)
print("v2 built", len(bpy.data.objects))
# clouds further away and lower so they frame the horizon instead of sitting beside the lane
for o in bpy.data.objects:
    if o.name.startswith("FCloud"):
        o.location.y += 25
        o.location.z -= 4
# pass 2: the rim light's reflection made a white streak across the lane; one cloud sat behind the gate
bpy.data.objects["Rim"].hide_render = True
bpy.data.objects.remove(bpy.data.objects["FCloud1"], do_unlink=True)
