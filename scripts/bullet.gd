extends Area2D
## 직선으로 날아가는 발사체. 적(또는 벽)에 닿으면 데미지를 주고 소멸한다.

var speed: float = 700.0
var damage: int = 1
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 화면 밖으로 나가도 메모리가 새지 않도록 수명 제한
	get_tree().create_timer(2.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# 같은 편 탄환끼리 부딪혀 사라지지 않도록, 반대편 탄만 상쇄한다.
	if area == self or not area.has_method("is_bullet"):
		return
	if area.collision_layer != collision_layer:
		area.queue_free()
		queue_free()

func is_bullet() -> bool:
	return true
