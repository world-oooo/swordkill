extends Area2D
## 포탈. 방 클리어 후 등장. 밟으면 entered(config) 방출 → 다음 방 선택/승리.
## config는 다음 방 데이터(Dictionary). 승리 포탈은 빈 Dictionary를 전달한다.

signal entered(config: Dictionary)

var _config: Dictionary = {}
var _used: bool = false

@onready var _ring: ColorRect = $Ring
@onready var _inner: ColorRect = $Inner
@onready var _label: Label = $Label

func _ready() -> void:
	add_to_group("portal")
	body_entered.connect(_on_body_entered)
	var t: Tween = create_tween().set_loops()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2(0.95, 0.95), 0.7).set_trans(Tween.TRANS_SINE)

## cfg: 다음 방 데이터(빈 값이면 승리 포탈), text: 라벨, col: 색
func configure(cfg: Dictionary, text: String, col: Color) -> void:
	_config = cfg
	if _label != null:
		_label.text = text
	if _ring != null:
		_ring.color = Color(col.r, col.g, col.b, 0.85)
	if _inner != null:
		_inner.color = col.lightened(0.4)

func _on_body_entered(body: Node) -> void:
	if _used:
		return
	if body.is_in_group("player"):
		_used = true
		entered.emit(_config)
