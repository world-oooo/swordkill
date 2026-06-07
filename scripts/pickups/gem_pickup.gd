extends Area2D
## 젬: 플레이어가 닿으면 GameManager에 젬 추가 후 소멸.

@export var value: int = 1

func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.add_gems(value)
		queue_free()

func save_data() -> Dictionary:
	return {"kind": "gem", "pos": position, "value": value}
