"""새 주인공 이미지(검은 배경 + 전신 4프레임)를 게임용 시트로 가공.
- 가장자리에서 검은 배경 flood fill → 투명
- 4등분 → 각 프레임 알파 트림 → 동일 셀(하단중앙 정렬) 시트로 재조립
출력: player_sheet.png (가로 4칸)
"""
from PIL import Image, ImageDraw

SRC = "49AD9F75-0BFE-4C49-80A1-52331D827E21.png"
OUT = "player_sheet.png"
KEY = (255, 0, 255)
N = 4

base = Image.open(SRC).convert("RGB")
W, H = base.size

# 1) 가장자리 여러 지점에서 검은 배경 flood fill → KEY
seeds = []
for x in range(0, W, 40):
    seeds += [(x, 0), (x, H - 1)]
for y in range(0, H, 40):
    seeds += [(0, y), (W - 1, y)]
for s in seeds:
    try:
        ImageDraw.floodfill(base, s, KEY, thresh=70)
    except Exception:
        pass

# 2) KEY → 투명
im = base.convert("RGBA")
im.putdata([(0, 0, 0, 0) if (c[0], c[1], c[2]) == KEY else (c[0], c[1], c[2], 255)
            for c in im.getdata()])

# 3) 4등분 → 각 프레임 알파 bbox 트림
cw = W // N
frames = []
for i in range(N):
    cell = im.crop((i * cw, 0, (i + 1) * cw, H))
    bb = cell.getbbox()
    if bb:
        frames.append(cell.crop(bb))
print("frames:", len(frames), "sizes:", [f.size for f in frames])

# 4) 동일 셀(최대 폭/높이), 하단중앙 정렬 재조립
cell_w = max(f.width for f in frames)
cell_h = max(f.height for f in frames)
sheet = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.paste(f, (i * cell_w + (cell_w - f.width) // 2, cell_h - f.height), f)
sheet.save(OUT)
print("SAVED", OUT, "cell", cell_w, "x", cell_h, "frames", len(frames))
