extends RefCounted
class_name UITheme
## 게임 전체에서 쓰는 판타지풍 UI 스타일(패널/버튼/라벨). 인벤토리와 톤을 통일한다.

const GOLD := Color(0.74, 0.51, 0.19)
const GOLD_BRIGHT := Color(0.95, 0.66, 0.20)
const CREAM := Color(0.96, 0.91, 0.82)
const PANEL_BG := Color(0.08, 0.07, 0.065, 0.98)
const SLOT_BG := Color(0.12, 0.11, 0.11, 0.96)

static func panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	return sb

static func _btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	return sb

static func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _btn_box(SLOT_BG, GOLD))
	b.add_theme_stylebox_override("hover", _btn_box(Color(0.18, 0.15, 0.10, 0.98), GOLD_BRIGHT))
	b.add_theme_stylebox_override("pressed", _btn_box(Color(0.22, 0.17, 0.10, 1.0), GOLD_BRIGHT))
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))

static func style_label(l: Label) -> void:
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.02))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

static func style_panel(p: Control) -> void:
	p.add_theme_stylebox_override("panel", panel_box())
