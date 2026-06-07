"""검 원본(위를 향함, 투명배경)을 게임용으로 가공.
- 알파 여백 트림 → 90도 시계방향 회전(위→오른쪽) 저장
- 룬 검은 4(1)+4(2)를 동일 셀 2프레임 시트로 합침(1,2,1,2 애니메이션용)
"""
from PIL import Image

def load_trim_rotate(path):
    im = Image.open(path).convert("RGBA")
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    # 위를 향한 검 → 오른쪽을 향하도록 90도 시계방향
    return im.transpose(Image.Transpose.ROTATE_270)

SINGLES = {
    "wood":    "2026-06-02-204403-Drawing_1.png",
    "steel":   "2026-06-02-204409-Drawing_2.png",
    "light":   "2026-06-02-225817-Drawing_1_3.gif",
    "flame":   "2026-06-02-231913-Drawing_1_5.png",
    "radiant": "2026-06-02-233458-Drawing_1_6.png",
}
for key, src in SINGLES.items():
    out = load_trim_rotate(src)
    out.save("sword_%s.png" % key)
    print("SAVED sword_%s.png" % key, out.size)

# 룬 검: 2프레임 시트
f1 = load_trim_rotate("2026-06-02-231952-Drawing_1_4(1).png")
f2 = load_trim_rotate("2026-06-02-231002-Drawing_1_4(2).png")
cw = max(f1.width, f2.width)
ch = max(f1.height, f2.height)
sheet = Image.new("RGBA", (cw * 2, ch), (0, 0, 0, 0))
for i, f in enumerate([f1, f2]):
    # 칼끝(오른쪽)·세로중앙 정렬: 왼쪽(손잡이) 맞춤 + 세로 가운데
    sheet.paste(f, (i * cw + (cw - f.width) // 2, (ch - f.height) // 2), f)
sheet.save("sword_rune.png")
print("SAVED sword_rune.png", sheet.size, "cell", cw, "x", ch, "frames 2")
