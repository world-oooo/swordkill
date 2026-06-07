"""원본(불투명 체커보드 배경 + 두 줄 캐릭터 + 한글 제목)에서
배경 제거 → 줄/제목 분리 → 각 줄 6프레임 시트로 추출.
출력: boss_sheet.png(위=로봇 보스), enemy_sheet.png(아래=스카프 일반적)
"""
from PIL import Image, ImageDraw

SRC = "Gemini_Generated_Image_i9io14i9io14i9io.png"
KEY = (255, 0, 255)

base = Image.open(SRC).convert("RGB")
W, H = base.size

# 1) 가장자리 여러 지점에서 체커보드 배경 flood fill(회색197~흰255 모두 포함) → KEY
seeds = []
for x in range(0, W, 120):
    seeds += [(x, 0), (x, H - 1)]
for y in range(0, H, 120):
    seeds += [(0, y), (W - 1, y)]
for s in seeds:
    try:
        ImageDraw.floodfill(base, s, KEY, thresh=200)
    except Exception:
        pass

# 2) KEY → 투명
im = base.convert("RGBA")
im.putdata([(0, 0, 0, 0) if (px4[0], px4[1], px4[2]) == KEY else (px4[0], px4[1], px4[2], 255)
            for px4 in im.getdata()])
px = im.load()

def cov(y):
    return sum(1 for x in range(0, W, 4) if px[x, y][3] > 16)

def pick_char_band(y0, y1):
    """[y0,y1) content run 중 높이가 가장 큰 run(=캐릭터 행)."""
    EMPTY = 18
    c = [cov(y) for y in range(y0, y1)]
    runs = []
    y = 0
    while y < len(c):
        if c[y] >= EMPTY:
            s = y
            while y < len(c) and c[y] >= EMPTY:
                y += 1
            runs.append((y0 + s, y0 + y))
        else:
            y += 1
    print("  runs:", runs)
    if not runs:
        return (y0, y1)
    runs.sort(key=lambda r: r[1] - r[0], reverse=True)
    return runs[0]

def slice_sheet(top, bot, n, out):
    band = im.crop((0, top, W, bot))
    cw = W // n
    frames = []
    for i in range(n):
        cell = band.crop((i * cw, 0, (i + 1) * cw, band.height))
        bb = cell.getbbox()
        if bb:
            frames.append(cell.crop(bb))
    cw2 = max(f.width for f in frames)
    ch2 = max(f.height for f in frames)
    sheet = Image.new("RGBA", (cw2 * len(frames), ch2), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * cw2 + (cw2 - f.width) // 2, ch2 - f.height), f)
    sheet.save(out)
    print(f"SAVED {out}  cell {cw2}x{ch2}  frames {len(frames)}")

mid = H // 2
bt, bb = pick_char_band(0, mid)
print("boss band", bt, bb)
slice_sheet(bt, bb, 6, "boss_sheet.png")
et, eb = pick_char_band(mid, H)
print("enemy band", et, eb)
slice_sheet(et, eb, 6, "enemy_sheet.png")
