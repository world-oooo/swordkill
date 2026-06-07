extends CanvasLayer
## Centered cinematic story intro.
##
## Each Korean story beat fades in at screen center, holds briefly, then fades
## out before the next line appears. Skip jumps to the controls screen, and the
## game starts only after the player presses any key there.

@export_file("*.tscn") var main_scene_path: String = "res://scenes/Main.tscn"
@export var fade_time: float = 0.75
@export var hold_time: float = 1.65

const STORY_LINES: Array[String] = [
	"나무검의 전설",
	"천 년의 평화가 끝났다.",
	"어둠의 군주 발다크가 빛의 결계를 무너뜨리고 에이렌 왕국을 집어삼켰다.",
	"왕은 쓰러졌고 기사단은 흩어졌으며 빛의 사제들은 침묵했다.",
	"살아남은 건 단 한 사람...",
	"그의 손에 쥐어진 건 나무검 뿐...",
]
const CONTROL_TEXT: String = "조작법\n\nWASD: 이동\nTab: 인벤토리\nSpace: 빠르게 베기\nG: 상자/보상 획득\nQ: 포탈 이동\n\n아무 키나 누르세요"

@onready var background: ColorRect = $Background
@onready var story_text: Label = $StoryText
@onready var skip_button: Button = $SkipButton

var _sequence_tween: Tween = null
var _waiting_for_controls_input: bool = false

func _ready() -> void:
	get_tree().paused = false
	background.color = Color(0.012, 0.010, 0.018, 1.0)

	story_text.text = ""
	story_text.modulate.a = 0.0
	story_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_text.offset_left = 80.0
	story_text.offset_right = -80.0
	story_text.offset_top = 0.0
	story_text.offset_bottom = 0.0
	story_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_text.add_theme_font_size_override("font_size", 32)
	story_text.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	story_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	story_text.add_theme_constant_override("shadow_offset_x", 3)
	story_text.add_theme_constant_override("shadow_offset_y", 3)

	skip_button.text = "건너뛰기"
	skip_button.pressed.connect(_show_controls_screen)
	_style_skip_button()
	call_deferred("_play_story")

func _input(event: InputEvent) -> void:
	if not _waiting_for_controls_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_accept_controls_input()
	elif event is InputEventMouseButton and event.pressed:
		_accept_controls_input()

func _play_story() -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()

	_sequence_tween = create_tween()
	for line in STORY_LINES:
		_sequence_tween.tween_callback(_set_story_line.bind(line))
		_sequence_tween.tween_property(story_text, "modulate:a", 1.0, fade_time)
		_sequence_tween.tween_interval(hold_time)
		_sequence_tween.tween_property(story_text, "modulate:a", 0.0, fade_time)
		_sequence_tween.tween_interval(0.12)
	_sequence_tween.finished.connect(_show_controls_screen)

func _set_story_line(line: String) -> void:
	story_text.text = line
	story_text.modulate.a = 0.0

func _show_controls_screen() -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	_sequence_tween = null
	_waiting_for_controls_input = true
	skip_button.visible = false
	story_text.text = CONTROL_TEXT
	story_text.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(story_text, "modulate:a", 1.0, fade_time)

func _accept_controls_input() -> void:
	if not _waiting_for_controls_input:
		return
	_waiting_for_controls_input = false
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	call_deferred("_go_to_main")

func _go_to_main() -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	_waiting_for_controls_input = false
	get_tree().change_scene_to_file(main_scene_path)

func _style_skip_button() -> void:
	skip_button.add_theme_stylebox_override("normal", _button_box(Color(0.10, 0.08, 0.05), Color(0.72, 0.48, 0.18)))
	skip_button.add_theme_stylebox_override("hover", _button_box(Color(0.15, 0.12, 0.07), Color(1.0, 0.78, 0.32)))
	skip_button.add_theme_stylebox_override("pressed", _button_box(Color(0.06, 0.05, 0.04), Color(0.58, 0.36, 0.12)))
	skip_button.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	skip_button.add_theme_font_size_override("font_size", 18)

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
