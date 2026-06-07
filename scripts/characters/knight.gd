extends Node
## 기사(Knight) 고유 로직. Player.tscn의 자식 노드로 부착된다.
## - _ready에서 부모(Player)에 기사 스탯/패시브 수치를 주입
## - 빠르게 베기 액티브 스킬 입력/지속/연장 처리
##   (Space로 발동 → 일정 시간 공격 속도 증가 → 활성 중 적 처치 시 지속 연장)

# 기사 수치 (설계 문서 4절)
const MAX_HP: int = 7
const MAX_SHIELD: float = 6.0
const MAX_ENERGY: float = 200.0
const SHIELD_BREAK_IMMUNITY: float = 2.0
const SHIELD_REGEN_DELAY: float = 4.0
const SHIELD_REGEN_RATE: float = 2.0
const ENERGY_REGEN: float = 10.0          # 플레이성 위해 추가(스펙 외) — 반복 스킬 테스트 가능하도록

const SKILL_DURATION: float = 6.0
const SKILL_KILL_BONUS: float = 1.0
const SKILL_DURATION_MAX: float = 12.0
const SKILL_ENERGY_COST: float = 50.0

var _player: Node = null
var _skill_active: bool = false
var _skill_time_left: float = 0.0

func _ready() -> void:
	_player = get_parent()
	# 기사 스탯/패시브 수치를 플레이어에 주입
	_player.max_hp = MAX_HP
	_player.max_shield = MAX_SHIELD
	_player.max_energy = MAX_ENERGY
	_player.shield_break_immunity = SHIELD_BREAK_IMMUNITY
	_player.shield_regen_delay = SHIELD_REGEN_DELAY
	_player.shield_regen_rate = SHIELD_REGEN_RATE
	_player.energy_regen = ENERGY_REGEN

	# 처치 시 스킬 연장: GameManager가 중계하는 전역 enemy_died 구독
	# (방마다 적이 새로 생성되므로 개별 연결 대신 허브를 구독)
	GameManager.enemy_died.connect(_on_enemy_died)

func _process(delta: float) -> void:
	if _player == null or not _player.is_alive():
		return

	# 발동
	if Input.is_action_just_pressed("skill") and not _skill_active:
		if _player.spend_energy(SKILL_ENERGY_COST):
			_activate_skill()

	# 지속 관리
	if _skill_active:
		_skill_time_left -= delta
		if _skill_time_left <= 0.0:
			_deactivate_skill()
		else:
			_player.update_skill_state(true, _skill_time_left)

func _activate_skill() -> void:
	_skill_active = true
	_skill_time_left = SKILL_DURATION
	_player.set_dual_wield(true)
	_player.update_skill_state(true, _skill_time_left)

func _deactivate_skill() -> void:
	_skill_active = false
	_skill_time_left = 0.0
	_player.set_dual_wield(false)
	_player.update_skill_state(false, 0.0)

## 빠르게 베기 활성 중 적 처치 → 지속시간 연장(공통 규칙), 상한까지.
func _on_enemy_died(_pos: Vector2) -> void:
	if _skill_active:
		_skill_time_left = min(SKILL_DURATION_MAX, _skill_time_left + SKILL_KILL_BONUS)
