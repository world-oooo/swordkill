extends CharacterBody2D
## Medieval robot-golem boss.
##
## The boss chases the player, deals contact damage, fires radial bullet bursts,
## reports health to the HUD, flashes red when hit, shakes the camera, and drops
## gems on death.

const ENEMY_BULLET: PackedScene = preload("res://scenes/weapons/EnemyBullet.tscn")
const GEM_PICKUP: PackedScene = preload("res://scenes/pickups/GemPickup.tscn")

@export var base_hp: int = 42
@export var speed: float = 46.0
@export var contact_damage: int = 2
@export var burst_interval: float = 2.8
@export var burst_count: int = 10
@export var gem_drop: int = 3
@export var display_name: String = "보스"

var max_hp: int = 60
var hp: int = 60
var bullet_speed: float = 240.0

var _player: Node2D = null
var _contact_cd: float = 0.0
var _burst_cd: float = 1.0
var _anim_t: float = 0.0
var _slow_timer: float = 0.0
var _slow_multiplier: float = 1.0
var _visual_cfg: Dictionary = {}
var _phase_cfgs: Array[Dictionary] = []
var _phase_index: int = -1
var _base_speed: float = 46.0
var _base_burst_interval: float = 2.8
var _base_burst_count: int = 10
var _base_modulate: Color = Color.WHITE
var _frame_start: int = 0
var _frame_count: int = 1
var _dying: bool = false

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")
	hp = max_hp
	_apply_visuals()
	GameManager.set_boss_phase_markers(GameManager.phase_markers_from_config(_visual_cfg))
	GameManager.set_boss_active(true)
	GameManager.report_boss_health(hp, max_hp)
	GameManager.set_boss_phase_hint(_phase_hint_text())

func setup(floor: int, cfg: Dictionary = {}) -> void:
	_visual_cfg = cfg.duplicate(true)
	display_name = str(cfg.get("name", display_name))
	max_hp = int(round(float(base_hp + (floor - 1) * 24) * float(cfg.get("hp_mult", 1.0))))
	hp = max_hp
	speed = 46.0 + float(floor - 1) * 4.0
	contact_damage = 1 if floor <= 2 else 2
	burst_interval = maxf(1.75, 2.8 - float(floor - 1) * 0.18)
	burst_count = 8 + floor * 2 + int(cfg.get("burst_count_bonus", 0))
	bullet_speed = 220.0 + float(floor - 1) * 18.0
	_base_speed = speed
	_base_burst_interval = burst_interval
	_base_burst_count = burst_count
	_phase_cfgs.clear()
	for phase in cfg.get("phases", []):
		if phase is Dictionary:
			_phase_cfgs.append((phase as Dictionary).duplicate(true))
	_phase_index = -1
	if is_inside_tree() and _sprite != null:
		_apply_visuals()

func _physics_process(delta: float) -> void:
	if _contact_cd > 0.0:
		_contact_cd -= delta
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_slow_multiplier = 1.0
	_burst_cd -= delta

	if _player == null or not is_instance_valid(_player):
		return

	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() > 40.0:
		velocity = to_player.normalized() * speed * _slow_multiplier
	else:
		velocity = Vector2.ZERO
		if _contact_cd <= 0.0 and _player.has_method("take_damage"):
			_player.take_damage(contact_damage)
			_contact_cd = 0.8

	if _sprite != null:
		_anim_t += delta * 6.0
		_sprite.frame = _frame_start + (int(_anim_t) % max(1, _frame_count))
		_sprite.flip_h = to_player.x < 0.0

	move_and_slide()

	if _burst_cd <= 0.0:
		_radial_burst()
		_burst_cd = burst_interval

func _radial_burst() -> void:
	for i in range(burst_count):
		var angle: float = TAU * float(i) / float(burst_count)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var bullet: Area2D = ENEMY_BULLET.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + direction * 28.0
		bullet.direction = direction
		bullet.damage = 1
		bullet.speed = bullet_speed
		bullet.rotation = angle

func take_damage(amount: int, _hit_angle: float = NAN) -> void:
	if _dying:
		return
	hp -= amount
	GameManager.report_boss_health(max(0, hp), max_hp)
	if hp > 0:
		_check_phase_transition()
		GameManager.set_boss_phase_hint(_phase_hint_text())
	_flash()

	if _player != null and is_instance_valid(_player) and _player.has_method("add_shake"):
		_player.add_shake(6.0)

	if hp <= 0:
		_die()

func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = clampf(multiplier, 0.25, 1.0)
	_slow_timer = maxf(_slow_timer, duration)
	modulate = Color(0.65, 0.88, 1.25)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, minf(duration, 0.55))

func _die() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	GameManager.boss_cinematic_requested.emit(global_position, 1.7, 2.65)
	GameManager.subtitle_requested.emit(display_name, "어둠이... 빛에 삼켜진다...")
	GameManager.set_boss_phase_hint("")

	if _sprite != null:
		_sprite.frame = _frame_start + max(0, _frame_count - 1)
		var death_tween := create_tween().set_parallel(true)
		death_tween.tween_property(_sprite, "scale", _sprite.scale * 1.35, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(self, "modulate", Color(1.65, 0.65, 2.6, 0.0), 1.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		death_tween.tween_property(self, "rotation_degrees", 5.0, 1.0)
		await death_tween.finished
	else:
		await get_tree().create_timer(1.35).timeout

	GameManager.set_boss_active(false)
	GameManager.report_kill(global_position)

	var parent: Node = get_parent()
	for i in range(gem_drop):
		var gem: Area2D = GEM_PICKUP.instantiate()
		gem.position = position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		parent.add_child.call_deferred(gem)

	queue_free()

func _flash() -> void:
	modulate = Color(2.2, 0.15, 0.15)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, 0.18)

func _check_phase_transition() -> void:
	if _phase_cfgs.is_empty() or max_hp <= 0:
		return
	var hp_ratio: float = float(max(hp, 0)) / float(max_hp)
	var next_index: int = _phase_index + 1
	while next_index < _phase_cfgs.size():
		var phase: Dictionary = _phase_cfgs[next_index]
		var threshold: float = float(phase.get("ratio", 0.0))
		if hp_ratio > threshold:
			return
		_phase_index = next_index
		_apply_phase(phase)
		next_index += 1

func _apply_phase(phase: Dictionary) -> void:
	speed = _base_speed * float(phase.get("speed_mult", 1.0))
	burst_interval = maxf(0.65, _base_burst_interval * float(phase.get("burst_interval_mult", 1.0)))
	burst_count = _base_burst_count + int(phase.get("burst_count_bonus", 0))
	_burst_cd = minf(_burst_cd, 0.35)
	_apply_phase_visuals(phase)
	GameManager.boss_cinematic_requested.emit(global_position, 0.85, 2.45)
	GameManager.subtitle_requested.emit("%s - %s" % [display_name, str(phase.get("name", "변신"))], str(phase.get("line", "")))
	var tween := create_tween()
	modulate = Color(1.4, 0.45, 2.0)
	tween.tween_property(self, "modulate", _base_modulate, 0.45)

func _apply_phase_visuals(phase: Dictionary) -> void:
	if _sprite == null:
		return
	_base_modulate = phase.get("fallback_color", _base_modulate)
	var target_height: float = float(phase.get("target_height", 0.0))
	if _sprite.texture != null and target_height > 0.0:
		var frame_height: float = float(_sprite.texture.get_height()) / float(max(1, _sprite.vframes))
		var scale_value: float = target_height / maxf(1.0, frame_height)
		_sprite.scale = Vector2(scale_value, scale_value)
	_frame_start = int(phase.get("frame_start", _frame_start))
	_frame_count = max(1, int(phase.get("frame_count", _frame_count)))

func _phase_hint_text() -> String:
	if hp <= 0:
		return ""
	if _phase_cfgs.is_empty():
		return "%s\n변신 페이즈 없음" % display_name
	var next_index: int = _phase_index + 1
	if next_index >= _phase_cfgs.size():
		return "%s\n현재 최종 페이즈입니다.\n남은 체력: %d/%d" % [display_name, max(hp, 0), max_hp]
	var phase: Dictionary = _phase_cfgs[next_index]
	var threshold_ratio: float = float(phase.get("ratio", 0.0))
	var target_hp: int = int(ceil(float(max_hp) * threshold_ratio))
	var damage_left: int = max(0, hp - target_hp)
	return "%s\n체력바의 I 마커에서 변신합니다.\n다음 변신: %s (%d%% 이하)\n변신까지 남은 피해: %d\n현재 체력: %d/%d" % [
		display_name,
		str(phase.get("name", "변신")),
		int(round(threshold_ratio * 100.0)),
		damage_left,
		max(hp, 0),
		max_hp,
	]

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
	_frame_start = int(_visual_cfg.get("frame_start", 0))
	_frame_count = max(1, int(_visual_cfg.get("frame_count", _sprite.hframes)))
	_sprite.frame = _frame_start
	var target_height: float = float(_visual_cfg.get("target_height", 0.0))
	if _sprite.texture != null and target_height > 0.0:
		var frame_height: float = float(_sprite.texture.get_height()) / float(max(1, _sprite.vframes))
		var scale_value: float = target_height / maxf(1.0, frame_height)
		_sprite.scale = Vector2(scale_value, scale_value)
	else:
		_sprite.scale = _visual_cfg.get("scale", _sprite.scale)
	_base_modulate = _visual_cfg.get("fallback_color", Color.WHITE)
	if texture_path != "" and ResourceLoader.exists(texture_path):
		_base_modulate = Color.WHITE
	modulate = _base_modulate
