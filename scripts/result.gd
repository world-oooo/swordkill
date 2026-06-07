extends Control
## Result screen with run statistics.

@onready var title: Label = $Center/Panel/VBox/Title
@onready var summary: Label = $Center/Panel/VBox/Summary
@onready var lobby_button: Button = $Center/Panel/VBox/LobbyButton

func _ready() -> void:
	lobby_button.pressed.connect(_on_lobby)
	UITheme.style_panel($Center/Panel)
	UITheme.style_button(lobby_button)
	UITheme.style_label(title)
	UITheme.style_label(summary)
	$Background.color = Color(0.07, 0.06, 0.07, 1.0)

	title.text = GameManager.ending_line() if GameManager.victory else "빛은 아직 깨어나지 못했다"
	lobby_button.text = "로비로"

	var cleared: int = 0
	for id in GameManager.rooms.keys():
		if GameManager.rooms[id].get("cleared", false):
			cleared += 1

	var weapon_name: String = WeaponDB.display_name(GameManager.equipped)
	summary.text = "통계\n도달 스테이지: %d / %d\n현재 지역: %s\n탐험한 방: %d / %d\n생존 시간: %.0f초\n처치 수: %d\n최종 무기: %s\n코인: %d   보석: %d" % [
		GameManager.reached_stage,
		GameManager.MAX_STAGE,
		GameManager.stage_data().get("name", "알 수 없음"),
		cleared,
		GameManager.rooms.size(),
		GameManager.run_time,
		GameManager.kills,
		weapon_name,
		GameManager.coins,
		GameManager.gems,
	]

func _on_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
