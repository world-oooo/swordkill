extends StaticBody2D
## 기능성 장애물: 엄폐물(총알/이동 차단), 폭발통(피격 시 광역 폭발), 보물상자형 파괴물.

@export var kind: String = "cover"       # cover / explosive / crate
@export var hp: int = 4
@export var explosion_radius: float = 118.0
@export var explosion_damage: int = 3

const COVER_TEXTURE: Texture2D = preload("res://assets/obstacles/barricade_ai.png")
const CRATE_TEXTURE: Texture2D = preload("res://assets/obstacles/crate_ai.png")
const TNT_TEXTURE: Texture2D = preload("res://assets/obstacles/tnt_ai.png")

var _dead: bool = false
var _visual: ColorRect = null
var _sprite_visual: Sprite2D = null
var _flash_tween: Tween = null

func setup(cfg: Dictionary) -> void:
	kind = cfg.get("kind", kind)
	hp = cfg.get("hp", hp)
	explosion_radius = cfg.get("radius", explosion_radius)
	explosion_damage = cfg.get("damage", explosion_damage)

func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 4
	collision_mask = 0
	_make_shape_and_visual()

func _make_shape_and_visual() -> void:
	var size: Vector2 = Vector2(42, 42)
	match kind:
		"explosive":
			size = Vector2(36, 48)
		"crate":
			size = Vector2(44, 44)
		_:
			size = Vector2(54, 38)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)

	_sprite_visual = Sprite2D.new()
	_sprite_visual.name = "%sSprite" % kind.capitalize()
	_sprite_visual.texture = _texture_for_kind()
	_sprite_visual.centered = true
	_sprite_visual.z_index = 3
	_sprite_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_sprite_to_size(size)
	add_child(_sprite_visual)
	_paint_visual(size)

func _paint_visual(size: Vector2) -> void:
	if _visual == null:
		return
	match kind:
		"explosive":
			_visual.color = Color(0.55, 0.13, 0.08)
			_add_pixel(Vector2(6, 7), Vector2(size.x - 12, 8), Color(0.18, 0.08, 0.04))
			_add_pixel(Vector2(10, 18), Vector2(size.x - 20, 6), Color(0.95, 0.58, 0.12))
			_add_pixel(Vector2(size.x * 0.5 - 5, -6), Vector2(10, 10), Color(1.0, 0.82, 0.20))
		"crate":
			_visual.color = Color(0.47, 0.25, 0.09)
			_add_pixel(Vector2(4, 4), Vector2(size.x - 8, size.y - 8), Color(0.68, 0.38, 0.13))
			_add_pixel(Vector2(6, 18), Vector2(size.x - 12, 6), Color(0.25, 0.12, 0.04))
			_add_pixel(Vector2(18, 6), Vector2(6, size.y - 12), Color(0.25, 0.12, 0.04))
		_:
			_visual.color = Color(1, 1, 1, 0)

func _texture_for_kind() -> Texture2D:
	match kind:
		"explosive":
			return TNT_TEXTURE
		"crate":
			return CRATE_TEXTURE
		_:
			return COVER_TEXTURE

func _fit_sprite_to_size(size: Vector2) -> void:
	if _sprite_visual == null or _sprite_visual.texture == null:
		return
	var texture_size: Vector2 = _sprite_visual.texture.get_size()
	var target_size: Vector2 = size
	match kind:
		"explosive":
			target_size = Vector2(size.x * 1.25, size.y * 1.42)
		"crate":
			target_size = size * 1.35
		_:
			target_size = size * 1.65
	var scale_factor: float = minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	_sprite_visual.scale = Vector2.ONE * scale_factor

func _add_pixel(pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = _visual.position + pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func take_damage(amount: int, _hit_angle: float = NAN) -> void:
	if _dead:
		return
	hp -= amount
	_flash()
	if hp <= 0:
		if kind == "explosive":
			_explode()
		else:
			_break_apart()

func _flash() -> void:
	modulate = Color(1.8, 1.5, 1.1)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func _explode() -> void:
	_dead = true
	collision_layer = 0
	var boom := ColorRect.new()
	boom.position = Vector2(-explosion_radius, -explosion_radius)
	boom.size = Vector2(explosion_radius * 2.0, explosion_radius * 2.0)
	boom.color = Color(1.0, 0.55, 0.10, 0.36)
	boom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boom)
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n) and n.global_position.distance_to(global_position) <= explosion_radius and n.has_method("take_damage"):
			n.take_damage(explosion_damage, (n.global_position - global_position).angle())
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.global_position.distance_to(global_position) <= explosion_radius and player.has_method("take_damage"):
		player.take_damage(1)
	for d in get_tree().get_nodes_in_group("destructibles"):
		if d != self and is_instance_valid(d) and d.global_position.distance_to(global_position) <= explosion_radius * 0.75 and d.has_method("take_damage"):
			d.take_damage(2)
	var t := create_tween()
	t.tween_property(boom, "modulate:a", 0.0, 0.22)
	t.tween_callback(queue_free)

func _break_apart() -> void:
	_dead = true
	collision_layer = 0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.2, 0.65), 0.12)
	t.tween_property(self, "modulate:a", 0.0, 0.16)
	t.finished.connect(queue_free)
