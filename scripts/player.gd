extends CharacterBody2D
## 범용 플레이어: WASD 이동, 마우스 조준, 좌클릭 사격, 그리고 HP/실드/에너지 상태 보유.
## 기사 고유 로직(스탯값 설정, 양손잡이 스킬, 실드 패시브 수치)은 자식 노드 Knight(knight.gd)가 주입한다.
## HUD는 이 노드의 시그널만 구독한다(역참조 없음).

signal stats_changed(hp: int, max_hp: int, shield: float, max_shield: float, energy: float, max_energy: float)
signal skill_state_changed(active: bool, time_left: float)
signal weapon_changed(weapon_name: String)
signal died

@export var speed: float = 220.0

const BODY_DRAW_Z: int = 20
const WEAPON_FRONT_Z: int = 30   # 무기는 항상 몸(20) 앞, 바닥(0) 위. (_ready 에서 1회 설정)
const BASE_SPEED: float = 220.0
const BASE_MAX_HP: int = 7

# --- 스탯 (knight.gd가 _ready에서 덮어쓴다) ---
var max_hp: int = 7
var max_shield: float = 6.0
var max_energy: float = 200.0
var hp: int = 7
var shield: float = 6.0
var energy: float = 200.0

# --- 실드 패시브 / 재생 수치 (knight.gd가 주입) ---
var shield_break_immunity: float = 2.0
var shield_regen_delay: float = 5.0
var shield_regen_rate: float = 1.5   # 초당 회복량
var energy_regen: float = 8.0        # 초당 에너지 회복(플레이성 위해 추가, 스펙 외)

# --- 양손잡이 스킬 (knight.gd가 set_dual_wield로 제어) ---
var dual_wield_active: bool = false

var _alive: bool = true
var _controls_locked: bool = false
var _immunity_timer: float = 0.0
var _no_hit_timer: float = 0.0       # 마지막 피격 이후 경과(실드 재생 지연용)

@onready var weapon_mount: Node2D = $WeaponMount
@onready var weapon: Node2D = $WeaponMount/Weapon
@onready var weapon_sprite: Sprite2D = $WeaponMount/Weapon/Blade
@onready var body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite
@onready var _camera: Camera2D = $Camera2D

var _anim_t: float = 0.0   # 이동 홉/스쿼시 위상
var _frame_t: float = 0.0  # 스프라이트 프레임 순환 타이머
var _shake: float = 0.0    # 화면 흔들림 세기(픽셀)
var _facing: float = 1.0          # 현재 바라보는 방향(-1 왼쪽 / +1 오른쪽)
var _attack_face: float = 1.0     # 공격 대상 방향
var _attack_face_timer: float = 0.0  # 공격 방향 우선 유지 시간

## 화면 흔들림 추가(타격감). 더 큰 값이 들어오면 그 값으로.
func add_shake(amount: float) -> void:
	_shake = max(_shake, amount)

## 카메라를 방 경계에 가두기(밖의 빈 공간을 보여주지 않음). main이 방 입장 때 호출.
func set_camera_limits(b: Rect2) -> void:
	if _camera == null:
		return
	_camera.limit_left = int(b.position.x)
	_camera.limit_top = int(b.position.y)
	_camera.limit_right = int(b.position.x + b.size.x)
	_camera.limit_bottom = int(b.position.y + b.size.y)
	_camera.reset_smoothing()

func set_controls_locked(locked: bool) -> void:
	_controls_locked = locked
	if locked:
		velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if _shake > 0.05:
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, 28.0 * delta)
	else:
		_shake = 0.0
		_camera.offset = Vector2.ZERO

func _ready() -> void:
	y_sort_enabled = true
	# 바닥(Floor ColorRect)이 z=0 이므로, 몸/무기는 항상 z>=1 로 두어 바닥 뒤로 사라지지 않게 한다.
	if body != null:
		body.z_index = BODY_DRAW_Z
	if weapon_mount != null:
		weapon_mount.y_sort_enabled = true
		weapon_mount.z_index = WEAPON_FRONT_Z
		weapon_mount.show_behind_parent = false
	if weapon_sprite != null:
		weapon_sprite.z_index = 0
		weapon_sprite.show_behind_parent = false
	add_to_group("player")
	hp = max_hp
	shield = max_shield
	energy = max_energy
	GameManager.inventory_changed.connect(_on_equip_changed)
	_apply_equipment_mods()
	set_weapon(GameManager.equipped)  # 인벤토리에서 장착한 검
	call_deferred("_emit_stats")  # HUD가 초기값을 받도록 지연 방출

func _on_equip_changed() -> void:
	_apply_equipment_mods()
	set_weapon(GameManager.equipped)
	_emit_stats()

## 상점 영구 강화 적용(현재 런 동안 유지).
func apply_upgrade(kind: String) -> void:
	match kind:
		"hp":
			max_hp += 1
			hp += 1
		"shield":
			max_shield += 1.0
			shield += 1.0
		"energy":
			max_energy += 20.0
			energy = min(max_energy, energy + 20.0)
	_emit_stats()

## 무기 교체: 키가 ""이면 맨손(해제), 아니면 해당 검 장착.
func set_weapon(key: String) -> void:
	if weapon == null:
		return
	if key == "":
		weapon.clear()
		weapon_changed.emit("(없음)")
		return
	var cfg: Dictionary = WeaponDB.get_weapon(key)
	var mods: Dictionary = GameManager.get_equipment_mods()
	cfg = cfg.duplicate(true)
	cfg["damage"] = max(1, int(round(float(cfg.get("damage", 1)) * float(mods.get("damage_mult", 1.0)))))
	cfg["attack_rate"] = float(cfg.get("attack_rate", 2.6)) * float(mods.get("attack_rate_mult", 1.0))
	cfg["crit_chance"] = 0.03 + float(mods.get("crit_bonus", 0.0))
	weapon.apply_config(cfg)
	weapon_changed.emit(cfg.get("name", "검"))

func _apply_equipment_mods() -> void:
	var mods: Dictionary = GameManager.get_equipment_mods()
	var old_max_hp: int = max_hp
	max_hp = BASE_MAX_HP + int(mods.get("hp", 0))
	if max_hp > old_max_hp:
		hp += max_hp - old_max_hp
	hp = clampi(hp, 0, max_hp)
	speed = BASE_SPEED * float(mods.get("speed_mult", 1.0))

func _physics_process(delta: float) -> void:
	if not _alive:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return
	if _controls_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_timers(delta)
		return

	# 이동
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()

	_aim_and_attack()
	_resolve_facing(dir, delta)

	_animate_body(delta, dir.length() > 0.1)
	_update_timers(delta)

## 검(자동): 가장 가까운 적을 자동 조준, 사거리 안이면 자동 베기. 총: 마우스 조준 + 클릭.
## TASK 1: 무기는 '피벗(weapon_mount) 통째로 미러' 방식으로 좌우를 처리한다. (z_index/offset 조작 제거)
##  - 평소(적 없음): rotation 0 에서 왼쪽을 보면 scale.x = -1 로 통째로 좌우 반전.
##  - 조준 중: 회전이 방향을 맞춘다. 왼쪽 절반을 가리키면 칼이 위아래로 뒤집혀 보이므로 scale.y 로 미러.
##    (조준 중 scale.x 로 미러하면 회전과 충돌해 데미지 판정(global_rotation 기반)이 반대로 뒤집힌다.)
func _aim_and_attack() -> void:
	if weapon == null:
		return
	if weapon.is_auto():
		var target: Node2D = _nearest_enemy()
		if target != null:
			weapon.aim_mode()
			var d: Vector2 = target.global_position - global_position
			var desired: float = d.angle()
			weapon_mount.rotation = lerp_angle(weapon_mount.rotation, desired, 0.62)
			weapon_mount.scale = Vector2(1.0, -1.0 if cos(weapon_mount.rotation) < 0.0 else 1.0)
			if d.length() <= weapon.get_range() + 8.0:
				weapon.fire(dual_wield_active)
				# 사거리 안의 적을 칠 때는 그 적 쪽을 잠깐 바라봄
				if absf(d.x) > 4.0:
					_attack_face = signf(d.x)
					_attack_face_timer = 0.20
		else:
			# 적이 없으면 오른쪽 기준 '든 자세' + 왼쪽을 보면 통째로 좌우 반전(mirror)
			weapon_mount.rotation = 0.0
			weapon_mount.scale = Vector2(-1.0 if _facing < 0.0 else 1.0, 1.0)
			weapon.held_mode(true)
	else:
		weapon_mount.look_at(get_global_mouse_position())
		weapon_mount.scale = Vector2(1.0, -1.0 if cos(weapon_mount.rotation) < 0.0 else 1.0)
		if Input.is_action_pressed("fire"):
			weapon.fire(dual_wield_active)

func _resolve_facing(move: Vector2, delta: float) -> void:
	if _attack_face_timer > 0.0:
		_attack_face_timer -= delta
	if _attack_face_timer > 0.0:
		_facing = _attack_face
	elif absf(move.x) > 0.1:
		_facing = signf(move.x)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## 주인공 전용 절차적 이동 애니메이션: 걸을 때 홉+스쿼시, 멈추면 숨쉬기, 마우스 방향으로 좌우 전환.
func _animate_body(delta: float, moving: bool) -> void:
	# 바라보는 방향으로 스프라이트 좌우 반전(원본이 왼쪽을 보고 있어 반대로 적용)
	if _sprite != null:
		_sprite.flip_h = _facing > 0.0
	# 4프레임 순환(이동 시 조금 더 빠르게)
	_frame_t += delta * (10.0 if moving else 6.0)
	if _sprite != null and _sprite.hframes > 0:
		_sprite.frame = int(_frame_t) % _sprite.hframes
	if moving:
		_anim_t += delta * 14.0
		var s: float = sin(_anim_t)
		body.position.y = lerp(body.position.y, -absf(s) * 5.0, 0.4)
		body.scale = Vector2(1.0 + s * 0.05, 1.0 - s * 0.05)
		body.rotation = lerp(body.rotation, deg_to_rad(_facing * 3.0), 0.2)
	else:
		_anim_t += delta * 3.0
		var b: float = sin(_anim_t) * 0.03
		body.position.y = lerp(body.position.y, 0.0, 0.2)
		body.scale = Vector2(1.0 - b, 1.0 + b)
		body.rotation = lerp(body.rotation, 0.0, 0.2)

func _update_timers(delta: float) -> void:
	var changed: bool = false

	if _immunity_timer > 0.0:
		_immunity_timer -= delta

	# 실드 재생: 마지막 피격 후 지연시간이 지나면 회복
	_no_hit_timer += delta
	if shield < max_shield and _no_hit_timer >= shield_regen_delay:
		shield = min(max_shield, shield + shield_regen_rate * delta)
		changed = true

	# 에너지 재생
	if energy < max_energy:
		energy = min(max_energy, energy + energy_regen * delta)
		changed = true

	if changed:
		_emit_stats()

## 피해 처리 (스펙 3절). 적/투사체가 호출.
func take_damage(amount: int) -> void:
	if not _alive or _immunity_timer > 0.0:
		return

	add_shake(8.0)       # 피격 시 화면 흔들림(크게)
	_no_hit_timer = 0.0  # 실드 재생 지연 리셋

	if shield > 0.0:
		shield -= amount
		if shield <= 0.0:
			shield = 0.0
			# 이번 타격으로 실드가 깨짐 → 짧은 피해 면역 (기사 패시브)
			_immunity_timer = shield_break_immunity
	else:
		hp -= amount
		if hp <= 0:
			hp = 0
			_die()

	_emit_stats()

func _die() -> void:
	_alive = false
	velocity = Vector2.ZERO
	died.emit()

# --- knight.gd 용 공개 API ---
func has_energy(cost: float) -> bool:
	return energy >= cost

func spend_energy(cost: float) -> bool:
	if energy < cost:
		return false
	energy -= cost
	_emit_stats()
	return true

func set_dual_wield(active: bool) -> void:
	dual_wield_active = active

func update_skill_state(active: bool, time_left: float) -> void:
	skill_state_changed.emit(active, time_left)

func is_alive() -> bool:
	return _alive

func _emit_stats() -> void:
	stats_changed.emit(hp, max_hp, shield, max_shield, energy, max_energy)
