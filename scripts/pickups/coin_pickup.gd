extends Area2D
## 코인: 플레이어가 닿으면 GameManager에 코인 추가 후 소멸.

@export var value: int = 1

@onready var _sprite: Sprite2D = $Sprite
var _anim_t: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	add_to_group("pickup")
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_anim_t += delta
	if _sprite != null:
		_sprite.frame = int(_anim_t * 8.0) % max(1, _sprite.hframes)
		_sprite.position.y = sin(_anim_t * 5.0) * 2.0

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.add_coins(value)
		queue_free()

func save_data() -> Dictionary:
	return {"kind": "coin", "pos": position, "value": value}
