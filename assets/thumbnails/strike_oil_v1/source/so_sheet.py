# Contact sheet: each concept at 640x360 (top row) and at a real small Roblox-card size 256x144 (bottom row)
import bpy, numpy as np
O = r"C:\Rblxspeel\RobloxBaseDup\assets\thumbnails\strike_oil_v1"
NAMES = SHEET_NAMES if "SHEET_NAMES" in globals() else ["concept1_gate_decision.png", "concept2_oil_rush.png", "concept3_progression.png"]
OUTNAME = SHEET_OUT if "SHEET_OUT" in globals() else "contact_sheet_concepts.png"
W, H = 1960, 600
canvas = np.zeros((H, W, 4), dtype=np.float32)
canvas[..., :3] = (0.06, 0.07, 0.12)
canvas[..., 3] = 1


def load_scaled(path, w, h):
    img = bpy.data.images.load(path, check_existing=False)
    img.scale(w, h)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return px


for i, n in enumerate(NAMES):
    big = load_scaled(O + "\\" + n, 640, 360)
    x = 10 + i * 650
    y0 = H - 10 - 360
    canvas[y0:y0 + 360, x:x + 640] = big
    small = load_scaled(O + "\\" + n, 256, 144)
    xs = x + (640 - 256) // 2
    ys = 30
    canvas[ys:ys + 144, xs:xs + 256] = small
out = bpy.data.images.new("Sheet", W, H, alpha=False)
out.pixels = canvas.ravel()
out.filepath_raw = O + "\\" + OUTNAME
out.file_format = "PNG"
out.save()
bpy.data.images.remove(out)
print("sheet saved", OUTNAME)
