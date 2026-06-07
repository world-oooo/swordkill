extends Node
## 웹 빌드에서 한글이 □(두부)로 깨지는 문제 해결.
## 영문 전용 폰트(oldengl)에 한글 폰트(Noto Sans KR)를 폴백으로 연결하고,
## 전역 기본 폴백 폰트도 한글로 지정한다. (오토로드: 가장 먼저 실행)

func _ready() -> void:
	var korean: Font = load("res://assets/fonts/korean.ttf")
	if korean == null:
		return
	# 모든 기본 텍스트가 한글을 그릴 수 있도록 전역 폴백 지정
	ThemeDB.fallback_font = korean
	# 판타지 폰트(영문)로 표시되는 라벨도 없는 글자는 한글 폰트로 대체
	var oldengl: Font = load("res://assets/fonts/oldengl.ttf")
	if oldengl != null:
		oldengl.fallbacks = [korean]
