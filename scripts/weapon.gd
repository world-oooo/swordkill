extends Node2D
## 근접 검 무기. 가장 가까운 적 방향으로 자동 베기(부채꼴 범위 데미지).
## Blade(Sprite2D)에 검 스프라이트를 입히고, 베기 시 손잡이를 축으로 휘두른다.
## 룬 검 등 2프레임 무기는 프레임을 순환해 룬이 튀어나오는 애니메이션을 만든다.

const BLADE_LEN_RATIO: float = 0.58   # 시각적 칼날 길이 = 사거리 * 비율(과대 스케일 방지)
const HIT_PAUSE: float = 0.045        # 타격 순간 짧은 정지감
const SLASH: PackedScene = preload("res://scenes/weapons/SlashEffect.tscn")
const DMG_NUMBER: PackedScene = preload("res://scenes/DamageNumber.tscn")
const CRIT_CHANCE: float = 0.03       # 크리티컬 확률 3%
const CRIT_MULT: float = 1.5          # 크리티컬 1.5배
const HELD_TILT: float = 0.72         # 평소 검을 위로 비스듬히 든 각도(rad ≈ 41°)

@export var damage: int = 2

var weapon_name: String = "검"
var auto: bool = true
var equipped: bool = false
var melee_range: float = 96.0
var melee_arc: float = 110.0
var attack_rate: float = 2.6
var aura: Color = Color(0.85, 0.95, 1.0)
var elemental_effect: String = ""
var crit_chance: float = CRIT_CHANCE

var _slash_texture_path: String = ""
var _slash_frames: int = 1
var _slash_anim_fps: float = 12.0
var _slash_pixel: bool = false
var _frames: int = 1
var _anim_fps: float = 6.0
var _frame_t: float = 0.0
var _cooldown: float = 0.0
var _swing: Tween = null
var _blade_base_scale: Vector2 = Vector2.ONE
var _base_pos: Vector2 = Vector2(10, -6)
var _chain_damage: int = 1
var _chain_range: float = 150.0
var _chain_targets: int = 2
var _aoe_damage: int = 1
var _aoe_radius: float = 96.0
var _slow_duration: float = 1.6
var _fire_damage: int = 1
var _fire_radius: float = 82.0

@onready var _blade: Sprite2D = $Blade

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	# 다중 프레임(룬 검) 애니메이션
	if equipped and _frames > 1 and _blade != null:
		_frame_t += delta * _anim_fps
		_blade.frame = int(_frame_t) % _frames

func is_auto() -> bool:
	return auto and equipped

func get_range() -> float:
	return melee_range

## 검 장착(데이터 적용). 비주얼/스탯 세팅.
func apply_config(cfg: Dictionary) -> void:
	weapon_name = cfg.get("name", "검")
	auto = cfg.get("auto", true)
	damage = cfg.get("damage", 2)
	attack_rate = cfg.get("attack_rate", 2.6)
	crit_chance = cfg.get("crit_chance", CRIT_CHANCE)
	melee_range = cfg.get("range", 96.0)
	melee_arc = cfg.get("arc", 110.0)
	elemental_effect = cfg.get("elemental_effect", "")
	_chain_damage = cfg.get("chain_damage", 1)
	_chain_range = cfg.get("chain_range", 150.0)
	_chain_targets = cfg.get("chain_targets", 2)
	_aoe_damage = cfg.get("aoe_damage", 1)
	_aoe_radius = cfg.get("aoe_radius", 96.0)
	_slow_duration = cfg.get("slow_duration", 1.6)
	_fire_damage = cfg.get("fire_damage", 1)
	_fire_radius = cfg.get("fire_radius", 82.0)
	_frames = cfg.get("frames", 1)
	_anim_fps = cfg.get("anim_fps", 6.0)
	aura = cfg.get("aura", Color(0.85, 0.95, 1.0))
	_slash_texture_path = cfg.get("slash_texture", "")
	_slash_frames = cfg.get("slash_frames", 1)
	_slash_anim_fps = cfg.get("slash_anim_fps", 12.0)
	_slash_pixel = cfg.get("slash_pixel", false)
	_frame_t = 0.0
	equipped = true
	if _blade != null and cfg.has("texture"):
		var tex: Texture2D = load(cfg["texture"])
		_blade.texture = tex
		_blade.hframes = _frames
		_blade.frame = 0
		var fw: float = float(tex.get_width()) / float(_frames)
		_blade.offset = Vector2(fw * 0.44, 0.0)        # 손잡이가 몸에서 살짝 앞으로 나오게 회전축 보정
		var s: float = (melee_range * BLADE_LEN_RATIO) / fw
		_blade_base_scale = Vector2(s, s)
		_blade.scale = _blade_base_scale
		_base_pos = Vector2(10.0, -6.0)                # 손 위치
		_blade.position = _base_pos
		_blade.rotation = 0.0
		_blade.visible = true

## 적을 겨눌 때(전투): 검을 조준 방향으로 똑바로.
func aim_mode() -> void:
	if _blade == null:
		return
	_blade.flip_h = false
	_blade.position = _base_pos

## 평소(적 없음): 검을 위로 비스듬히 든 자세. facing_right=바라보는 방향.
func held_mode(facing_right: bool) -> void:
	if _blade == null or not equipped:
		return
	_blade.flip_h = not facing_right
	_blade.rotation = -HELD_TILT if facing_right else HELD_TILT
	_blade.position = Vector2(_base_pos.x if facing_right else -_base_pos.x, _base_pos.y)

## 무기 해제(맨손).
func clear() -> void:
	equipped = false
	if _blade != null:
		_blade.visible = false

func can_fire() -> bool:
	return _cooldown <= 0.0

func fire(dual_wield: bool) -> void:
	if not equipped or not can_fire():
		return
	_cooldown = (1.0 / attack_rate) * (0.5 if dual_wield else 1.0)  # 양손잡이 시 2배 빠르게
	var origin: Vector2 = global_position
	var facing: float = global_rotation
	var half_arc: float = deg_to_rad(melee_arc * 0.5)
	var hit_any: bool = false
	var hit_enemies: Array[Node2D] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to: Vector2 = e.global_position - origin
		if to.length() <= melee_range and absf(wrapf(to.angle() - facing, -PI, PI)) <= half_arc:
			if e.has_method("take_damage"):
				var crit: bool = randf() < crit_chance
				var dmg: int = int(round(damage * CRIT_MULT)) if crit else damage
				e.take_damage(dmg, facing)
				GameManager.register_hit()              # 콤보 누적
				_spawn_damage_number(e.global_position, dmg, crit)
				hit_enemies.append(e)
				hit_any = true
	# 엄폐물/폭발통도 검으로 부술 수 있게 한다. 단, 콤보/데미지 숫자는 적에게만 적용.
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		var to_obj: Vector2 = d.global_position - origin
		if to_obj.length() <= melee_range and absf(wrapf(to_obj.angle() - facing, -PI, PI)) <= half_arc:
			if d.has_method("take_damage"):
				d.take_damage(damage, facing)
				hit_any = true
	if not hit_enemies.is_empty():
		_trigger_elemental_effects(hit_enemies, facing)
	_swing_anim(hit_any)

func _trigger_elemental_effects(hit_enemies: Array[Node2D], facing: float) -> void:
	match elemental_effect:
		"chain_lightning":
			_chain_lightning(hit_enemies)
		"water_freeze":
			_water_freeze_burst(hit_enemies[0].global_position, facing, hit_enemies)
		"fire_burst":
			_fire_burst(hit_enemies[0].global_position, facing, hit_enemies)

func _chain_lightning(hit_enemies: Array[Node2D]) -> void:
	var chained: Array[Node2D] = hit_enemies.duplicate()
	var source: Node2D = hit_enemies[0]
	for _i in range(_chain_targets):
		var next_target: Node2D = _nearest_chain_target(source.global_position, chained)
		if next_target == null:
			return
		var angle: float = (next_target.global_position - source.global_position).angle()
		next_target.take_damage(_chain_damage, angle)
		GameManager.register_hit()
		_spawn_damage_number(next_target.global_position, _chain_damage, false)
		_spawn_lightning_bolt(source.global_position, next_target.global_position)
		chained.append(next_target)
		source = next_target

func _nearest_chain_target(from_pos: Vector2, excluded: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_d: float = _chain_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in excluded:
			continue
		var d: float = from_pos.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best

func _water_freeze_burst(center: Vector2, facing: float, primary_hits: Array[Node2D]) -> void:
	_spawn_water_ring(center)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(center) > _aoe_radius:
			continue
		if e not in primary_hits and e.has_method("take_damage"):
			e.take_damage(_aoe_damage, facing)
			_spawn_damage_number(e.global_position, _aoe_damage, false)
		if e.has_method("apply_slow"):
			e.apply_slow(0.45, _slow_duration)

func _fire_burst(center: Vector2, facing: float, primary_hits: Array[Node2D]) -> void:
	_spawn_fire_ring(center)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e in primary_hits:
			continue
		if e.global_position.distance_to(center) <= _fire_radius and e.has_method("take_damage"):
			e.take_damage(_fire_damage, facing)
			GameManager.register_hit()
			_spawn_damage_number(e.global_position, _fire_damage, false)

func _spawn_lightning_bolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color(0.62, 0.92, 1.0, 0.92)
	line.points = PackedVector2Array([
		from_pos,
		(from_pos + to_pos) * 0.5 + Vector2(randf_range(-10, 10), randf_range(-10, 10)),
		to_pos,
	])
	_vfx_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)

func _spawn_water_ring(center: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.35, 0.78, 1.0, 0.78)
	var points := PackedVector2Array()
	var segments: int = 28
	for i in range(segments + 1):
		var a: float = TAU * float(i) / float(segments)
		points.append(center + Vector2.RIGHT.rotated(a) * _aoe_radius)
	ring.points = points
	_vfx_parent().add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.12, 1.12), 0.20)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ring.queue_free)

func _spawn_fire_ring(center: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(1.0, 0.34, 0.04, 0.86)
	var points := PackedVector2Array()
	var segments: int = 24
	for i in range(segments + 1):
		var a: float = TAU * float(i) / float(segments)
		var wobble: float = 1.0 + sin(float(i) * 1.7) * 0.08
		points.append(center + Vector2.RIGHT.rotated(a) * _fire_radius * wobble)
	ring.points = points
	_vfx_parent().add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.18, 1.18), 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)

func _spawn_damage_number(pos: Vector2, amount: int, crit: bool) -> void:
	var n: Node2D = DMG_NUMBER.instantiate()
	_vfx_parent().add_child(n)
	n.global_position = pos + Vector2(randf_range(-10, 10), -22)
	n.setup(amount, crit)

func _vfx_parent() -> Node:
	var scene: Node = get_tree().current_scene
	return scene if scene != null else get_tree().root

func _swing_anim(hit_any: bool) -> void:
	# 검기 생성(월드 공간, 베기 방향). 플레이어 손보다 약간 앞에서 시작해야 자연스럽다.
	var fx: Node2D = SLASH.instantiate()
	_vfx_parent().add_child(fx)
	fx.global_position = global_position + Vector2.RIGHT.rotated(global_rotation) * 22.0
	if _slash_texture_path != "" and fx.has_method("setup_pixel"):
		fx.setup_pixel(global_rotation, melee_range, aura, _slash_texture_path, _slash_frames, _slash_anim_fps, _slash_pixel)
	else:
		fx.setup(global_rotation, melee_range, melee_arc, aura)

	if hit_any:
		Engine.time_scale = 0.55
		get_tree().create_timer(HIT_PAUSE, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

	if _blade == null:
		return
	if _swing != null and _swing.is_valid():
		_swing.kill()
	_blade.visible = true
	_blade.rotation = deg_to_rad(-56)
	_blade.position = _base_pos + Vector2(-5.0, -5.0)
	_blade.scale = _blade_base_scale * 1.16
	_blade.modulate = Color(1.35, 1.25, 1.0, 1.0)

	_swing = create_tween().set_parallel(true)
	_swing.tween_property(_blade, "rotation", deg_to_rad(64), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_blade, "position", _base_pos + Vector2(10.0, 1.0), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_blade, "scale", _blade_base_scale * 1.22, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swing.chain().tween_property(_blade, "rotation", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_blade, "position", _base_pos, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_blade, "scale", _blade_base_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing.tween_property(_blade, "modulate", Color.WHITE, 0.10)
