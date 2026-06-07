extends Control
## 로비(캐릭터 선택). 현재는 기본 캐릭터 기사만 선택 가능. 시작 시 새 런 시작.

@onready var start_button: Button = $Center/Panel/VBox/StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	_apply_theme()

func _apply_theme() -> void:
	UITheme.style_panel($Center/Panel)
	UITheme.style_button(start_button)
	for l in [$Center/Panel/VBox/Title, $Center/Panel/VBox/CharName, $Center/Panel/VBox/Info]:
		UITheme.style_label(l)
	$Background.color = Color(0.09, 0.08, 0.10, 1.0)

func _on_start() -> void:
	GameManager.selected_character = "knight"
	GameManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
