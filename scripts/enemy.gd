extends CharacterBody2D
## 적: 근접(돌진) / 원거리(거리 유지하며 사격) 두 모드. 능력치는 setup()으로 주입.
## 사망 시 GameManager.report_kill로 보고(처치수 집계 + 기사 스킬 연장) + 코인 드랍.

const ENEMY_BULLET: PackedScene = preload("res://scenes/weapons/EnemyBullet.tscn")
const COIN_PICKUP: PackedScene = preload("res://scenes/pickups/CoinPickup.tscn")

@export var mode: String = "melee"     # "melee" 또는 "ranged"
@export var max_hp: int = 3
@export var speed: float = 70.0
@export var contact_damage: int = 1
@export var contact_interval: float = 1.0
@export var shoot_interval: float = 1.6
@export var keep_distance: float = 230.0
@export var coin_drop: int = 2
@export var display_name: String = "적"

var hp: int = 0
var _player: Node2D = null
var _contact_cd: float = 0.0
var _shoot_cd: float = 0.0
var _anim_t: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _slow_timer: float = 0.0
var _slow_multiplier: float = 1.0
var _visual_cfg: Dictionary = {}
var _base_modulate: Color = Color.WHITE

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")
	_apply_visuals()

## 방 생성기가 능력치를 주입할 때 사용.
func setup(cfg: Dictionary) -> void:
	_visual_cfg = cfg.duplicate(true)
	display_name = str(cfg.get("display_name", display_name))
	mode = cfg.get("mode", mode)
	max_hp = cfg.get("hp", max_hp)
	speed = cfg.get("speed", speed)
	contact_damage = cfg.get("contact_damage", contact_damage)
	contact_interval = cfg.get("contact_interval", contact_interval)
	shoot_interval = cfg.get("shoot_interval", shoot_interval)
	keep_distance = cfg.get("keep_distance", keep_distance)
	coin_drop = cfg.get("coin_drop", coin_drop)
	if is_inside_tree() and _sprite != null:
		_apply_visuals()

func _physics_process(delta: float) -> void:
	if _contact_cd > 0.0:
		_contact_cd -= delta
	if _shoot_cd > 0.0:
		_shoot_cd -= delta
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_multiplier = 1.0
	if _player == null or not is_instance_valid(_player):
		return

	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()

	if mode == "ranged":
		_ranged_behavior(to_player, dist)
	else:
		_melee_behavior(to_player, dist)

	# 스프라이트: 프레임 순환 + 플레이어 향해 좌우 전환
	if _sprite != null:
		_anim_t += delta * 8.0
		_sprite.frame = int(_anim_t) % _sprite.hframes
		_sprite.flip_h = to_player.x < 0.0

	# 피격 넉백(감쇠)
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)

	move_and_slide()

func _melee_behavior(to_player: Vector2, dist: float) -> void:
	if dist > 26.0:
		velocity = to_player.normalized() * speed * _slow_multiplier
	else:
		velocity = Vector2.ZERO
		_try_contact()

func _ranged_behavior(to_player: Vector2, dist: float) -> void:
	var dir: Vector2 = to_player.normalized()
	if dist > keep_distance + 30.0:
		velocity = dir * speed           # 너무 멀면 접근
	elif dist < keep_distance - 30.0:
		velocity = -dir * speed          # 너무 가까우면 후퇴
	else:
		velocity = Vector2.ZERO
	if _shoot_cd <= 0.0:
		_shoot_at(dir)
		_shoot_cd = shoot_interval

func _try_contact() -> void:
	if _contact_cd <= 0.0 and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)
		_contact_cd = contact_interval

func _shoot_at(dir: Vector2) -> void:
	var b: Area2D = ENEMY_BULLET.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position + dir * 18.0
	b.direction = dir
	b.damage = contact_damage
	b.rotation = dir.angle()

func take_damage(amount: int, hit_angle: float = NAN) -> void:
	hp -= amount
	_flash()
	# 넉백은 플레이어 반대 방향이 아니라 실제 검이 지나간 방향으로 밀려야 자연스럽다.
	if not is_nan(hit_angle):
		_knockback = Vector2.RIGHT.rotated(hit_angle) * 210.0
	elif _player != null and is_instance_valid(_player):
		_knockback = (global_position - _player.global_position).normalized() * 170.0
	if _player != null and is_instance_valid(_player) and _player.has_method("add_shake"):
		_player.add_shake(4.5)
	if hp <= 0:
		_die()

func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = clampf(multiplier, 0.15, 1.0)
	_slow_timer = maxf(_slow_timer, duration)
	modulate = Color(0.55, 0.85, 1.35)
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", _base_modulate, minf(duration, 0.55))

func _die() -> void:
	GameManager.report_kill(global_position)
	# Area2D 픽업은 물리 콜백 중 즉시 추가 시 에러가 날 수 있어 지연 생성
	var parent: Node = get_parent()
	for i in range(coin_drop):
		var c: Area2D = COIN_PICKUP.instantiate()
		c.position = position + Vector2(randf_range(-18, 18), randf_range(-18, 18))
		parent.add_child.call_deferred(c)
	queue_free()

func _flash() -> void:
	modulate = Color(2.2, 0.15, 0.15)  # 피격 시 확실히 빨갛게(아픈 표현)
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", _base_modulate, 0.2)

func _apply_visuals() -> void:
	if _sprite == null:
		return
	var texture_path: String = str(_visual_cfg.get("texture", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture: Texture2D = load(texture_path)
		if texture != null:
			_sprite.texture = texture
	_sprite.hframes = max(1, int(_visual_cfg.get("hframes", _sprite.hframes)))
	_sprite.vframes = max(1, int(_visual_cfg.get("vframes", _sprite.vframes)))
	_sprite.frame = 0
	var target_height: float = float(_visual_cfg.get("target_height", 0.0))
	if _sprite.texture != null and target_height > 0.0:
		var frame_height: float = float(_sprite.texture.get_height()) / float(max(1, _sprite.vframes))
		var scale_value: float = target_height / maxf(1.0, frame_height)
		_sprite.scale = Vector2(scale_value, scale_value)
	else:
		_sprite.scale = _visual_cfg.get("sprite_scale", _sprite.scale)
	_base_modulate = _visual_cfg.get("fallback_color", Color.WHITE)
	if texture_path != "" and ResourceLoader.exists(texture_path):
		_base_modulate = Color.WHITE
	modulate = _base_modulate
