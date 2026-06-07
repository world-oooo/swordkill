# 적 / 보스 스프라이트 넣는 곳

여기(`assets/enemies/`)에 **직접 만든(또는 CC0/라이선스 프리)** 적·보스 이미지를 넣어주세요.
(소울나이트 원본 그림은 저작권 문제로 사용 불가 — 오리지널/프리 에셋만.)

## 1) 이미지 사양
- **픽셀아트**, **배경 투명(PNG) 또는 단색 흰색**, 캐릭터는 **오른쪽 바라보게**(왼쪽은 코드가 자동으로 뒤집음)
- 같은 크기 프레임을 **가로로 N개** 나열한 한 장(권장). 아래에 숫자/라벨이 있어도 됨(자동 제거)

## 2) 가공 (흰배경 제거 + 라벨 제거 + N등분)
```
cd assets/enemies
python ../tools/process_sprite.py <입력.png> <출력.png> --frames N
# 프레임이 세로로 꽉 차 라벨이 없으면 끝에 --no-label-strip
```
예: `python ../tools/process_sprite.py goblin_src.png enemy_melee.png --frames 4`
출력에 `SAVED enemy_melee.png  cell 200x220  frames 4` 처럼 셀 크기가 찍힘.

## 3) 나에게 알려줄 것 → 내가 씬에 연결
- 어떤 대상인지: **근접 적 / 원거리 적 / 보스**
- 출력 시트 **파일명**, **frames 수**, 출력에 찍힌 **cell 크기(WxH)**

그러면 `Enemy.tscn` / `Boss.tscn`의 도형 스프라이트를 **Sprite2D(hframes=N)**로 바꾸고
프레임 순환을 코드에 연결합니다. (주인공과 동일한 방식 → `assets/player/` 참고)
