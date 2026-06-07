"""파란 물검(좌) + 물 검기(우)가 한 장에 든 webp를 가공.
- 흰 배경 제거
- 좌/우 분할
- 검: 주축(PCA)으로 각도 계산 → 오른쪽(→)을 향하도록 회전, 손잡이를 왼쪽으로
- 검기: 트림만
출력: sword_frost.png, slash_frost.png
"""
from PIL import Image, ImageDraw
import math

SRC = "image-1780593741337.webp"
KEY = (255, 0, 255)

base = Image.open(SRC).convert("RGB")
W, H = base.size
for x in range(0, W, 40):
    for y in (0, H - 1):
        try: ImageDraw.floodfill(base, (x, y), KEY, thresh=110)
        except Exception: pass
for y in range(0, H, 40):
    for x in (0, W - 1):
        try: ImageDraw.floodfill(base, (x, y), KEY, thresh=110)
        except Exception: pass

im = base.convert("RGBA")
im.putdata([(0, 0, 0, 0) if (c[0], c[1], c[2]) == KEY else (c[0], c[1], c[2], 255) for c in im.getdata()])
px = im.load()

# 좌/우 분할: 열 커버리지의 가장 긴 빈 구간
def colcov(x): return sum(1 for y in range(0, H, 2) if px[x, y][3] > 16)
prof = [colcov(x) for x in range(W)]
mx = max(prof); thr = max(mx * 0.03, 1)
runs = []; x = 0
while x < W:
    if prof[x] <= thr:
        s = x
        while x < W and prof[x] <= thr: x += 1
        runs.append((s, x))
    else: x += 1
# 내부(양끝 제외) 가장 긴 빈 구간을 분할점으로
inner = [r for r in runs if r[0] > W * 0.15 and r[1] < W * 0.85]
split = (inner and max(inner, key=lambda r: r[1]-r[0])) or (W//2, W//2)
sx = (split[0] + split[1]) // 2
print("split x =", sx)

left = im.crop((0, 0, sx, H))
right = im.crop((sx, 0, W, H))

def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img

# --- 검: PCA 각도로 수평화 ---
lpx = left.load(); lw, lh = left.size
xs = ys = n = 0
pts = []
for y in range(0, lh, 2):
    for x in range(0, lw, 2):
        if lpx[x, y][3] > 16:
            pts.append((x, y)); xs += x; ys += y; n += 1
mx_ = xs / n; my_ = ys / n
sxx = syy = sxy = 0.0
for (x, y) in pts:
    dx = x - mx_; dy = y - my_
    sxx += dx*dx; syy += dy*dy; sxy += dx*dy
theta = 0.5 * math.atan2(2*sxy, sxx - syy)   # 주축 각도(라디안, y-down)
deg = math.degrees(theta)
print("blade axis deg =", round(deg, 1))

# 주축을 수평으로: PIL rotate는 CCW(+). y-down이라 -deg로 회전하면 수평이 됨.
sword = left.rotate(deg, resample=Image.NEAREST, expand=True)
sword = trim(sword)
sword.save("sword_frost.png")
print("SAVED sword_frost.png", sword.size)

slash = trim(right)
slash.save("slash_frost.png")
print("SAVED slash_frost.png", slash.size)
