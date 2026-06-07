"""범용 스프라이트 시트 가공기.
흰 배경 제거 + (선택) 라벨 밴드 제거 + 가로 N등분 → 동일 셀(하단중앙) 시트로 재조립.

사용법:
  python process_sprite.py <입력png> <출력png> [--frames N] [--no-label-strip] [--thresh 40]

예:
  python process_sprite.py enemy_src.png enemy_sheet.png --frames 4
  python process_sprite.py boss_src.png  boss_sheet.png  --frames 6 --no-label-strip
"""
import argparse
from PIL import Image, ImageDraw

KEY = (255, 0, 255)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--frames", type=int, default=4)
    ap.add_argument("--no-label-strip", action="store_true",
                    help="아래쪽 숫자/라벨 밴드 제거를 끔(프레임이 세로로 꽉 찬 경우)")
    ap.add_argument("--thresh", type=int, default=40, help="흰배경 flood fill 허용오차")
    args = ap.parse_args()

    im = Image.open(args.src).convert("RGB")
    W, H = im.size

    # 1) 네 모서리에서 흰 배경 flood fill → KEY 색
    for seed in [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)]:
        try:
            ImageDraw.floodfill(im, seed, KEY, thresh=args.thresh)
        except Exception:
            pass

    # 2) KEY → 투명
    rgba = im.convert("RGBA")
    rgba.putdata([(0, 0, 0, 0) if (r, g, b) == KEY else (r, g, b, 255)
                  for (r, g, b) in rgba.getdata()])
    px = rgba.load()

    # 3) (선택) 행 커버리지 gap으로 위쪽(캐릭터) 밴드만 유지 → 아래 라벨 제거
    top, bot = 0, H
    if not args.no_label_strip:
        def cov(y):
            return sum(1 for x in range(0, W, 4) if px[x, y][3] > 0)
        c = [cov(y) for y in range(H)]
        thr = max(c) * 0.04 if max(c) else 0
        filled = [y for y in range(H) if c[y] > thr]
        if filled:
            top0, bot0 = filled[0], filled[-1]
            best = (0, 0)
            y = top0
            while y <= bot0:
                if c[y] <= thr:
                    s = y
                    while y <= bot0 and c[y] <= thr:
                        y += 1
                    if (y - s) > (best[1] - best[0]):
                        best = (s, y)
                else:
                    y += 1
            top = top0
            bot = best[0] if best[1] > best[0] else bot0 + 1

    band = rgba.crop((0, top, W, bot))

    # 4) 가로 N등분 → 각 프레임 알파 bbox 트림
    N = args.frames
    cw = W // N
    frames = []
    for i in range(N):
        cell = band.crop((i * cw, 0, (i + 1) * cw, band.height))
        bb = cell.getbbox()
        if bb:
            frames.append(cell.crop(bb))
    if not frames:
        raise SystemExit("ERROR: no content found")

    # 5) 동일 셀(최대 폭/높이), 하단중앙 정렬 재조립
    cell_w = max(f.width for f in frames)
    cell_h = max(f.height for f in frames)
    sheet = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * cell_w + (cell_w - f.width) // 2, cell_h - f.height), f)
    sheet.save(args.out)
    print(f"SAVED {args.out}  cell {cell_w}x{cell_h}  frames {len(frames)}")

if __name__ == "__main__":
    main()
