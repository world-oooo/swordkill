extends Node
## Run state, random room graph generation, stage progression, inventory,
## equipment, combo, currencies, and global UI events.

signal currency_changed(coins: int, gems: int)
signal stats_meta_changed(kills: int)
signal enemy_died(pos: Vector2)
signal boss_health_changed(cur: float, max_hp: float)
signal boss_active_changed(active: bool)
signal map_changed
signal inventory_changed
signal inventory_item_dropped(item_id: String)
signal forge_message_changed(message: String)
signal subtitle_requested(speaker: String, line: String)
signal center_message_requested(message: String, color: Color)
signal boss_phase_hint_changed(text: String)
signal boss_phase_markers_changed(markers: Array)
signal boss_cinematic_requested(target_position: Vector2, hold_time: float, zoom: float)

const DIRS: Dictionary = {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}
const OPP: Dictionary = {"N": "S", "S": "N", "E": "W", "W": "E"}
const MIN_ROOMS_PER_STAGE: int = 4
const MAX_ROOMS_PER_STAGE: int = 7
const MAX_STAGE: int = 5
const COMBO_TIMEOUT: float = 3.0
const INVENTORY_CAPACITY: int = 24
const ENDING_LINE: String = "그렇게 세계를 구했다..."

const STAGES: Array[Dictionary] = [
	{"name": "변경의 숲", "boss": "오크킹", "line": "숲을 넘으려는 자여, 나무검 하나로 왕의 문턱을 넘을 수 있겠느냐!", "reward": "steel"},
	{"name": "폐허의 마을", "boss": "레이븐", "line": "무너진 왕국의 울음은 아직 끝나지 않았다. 네 빛도 이 폐허에 묻어주마.", "reward": "light"},
	{"name": "저주받은 늪", "boss": "늪지대 마녀", "line": "빛의 결계가 썩어 문드러지는 냄새가 나는구나. 네 검도 늪 아래로 가라앉으리라.", "reward": "rune"},
	{"name": "화산 지대", "boss": "화염룡", "line": "마지막 불길이 네 숨을 삼킬 것이다. 타오르는 심장 앞에 무릎 꿇어라!", "reward": "flame"},
	{"name": "마왕성", "boss": "어둠의 군주", "line": "천 년의 빛은 이미 꺼졌다. 나무검의 전설도 오늘 이 자리에서 끝난다.", "reward": "radiant"},
]

const STAGE_ENEMY_POOLS: Dictionary = {
	1: ["orc", "wolf"],
	2: ["zombie", "skeleton_soldier"],
	3: ["slime", "ghost"],
	4: ["stone_statue", "flame_imp"],
}

const ENEMY_ARCHETYPES: Dictionary = {
	"orc": {"name": "오크", "mode": "melee", "hp_mult": 1.05, "speed_mult": 0.95, "texture": "res://assets/enemies/orc.png", "hframes": 4, "vframes": 1, "target_height": 54.0, "fallback_color": Color(0.45, 0.85, 0.28)},
	"wolf": {"name": "늑대", "mode": "melee", "hp_mult": 0.85, "speed_mult": 1.35, "texture": "res://assets/enemies/wolf.png", "hframes": 4, "vframes": 1, "target_height": 36.0, "fallback_color": Color(0.72, 0.74, 0.72)},
	"zombie": {"name": "좀비", "mode": "melee", "hp_mult": 1.15, "speed_mult": 0.72, "texture": "res://assets/enemies/zombie.png", "hframes": 4, "vframes": 1, "target_height": 44.0, "fallback_color": Color(0.58, 0.72, 0.36)},
	"skeleton_soldier": {"name": "스켈레톤 병사", "mode": "melee", "hp_mult": 0.95, "speed_mult": 1.02, "texture": "res://assets/enemies/skeleton_soldier.png", "hframes": 4, "vframes": 1, "target_height": 48.0, "fallback_color": Color(0.95, 0.90, 0.72)},
	"slime": {"name": "슬라임", "mode": "melee", "hp_mult": 1.10, "speed_mult": 0.75, "texture": "res://assets/enemies/slime.png", "hframes": 4, "vframes": 1, "target_height": 36.0, "fallback_color": Color(0.35, 1.0, 0.16)},
	"ghost": {"name": "유령", "mode": "ranged", "hp_mult": 0.85, "speed_mult": 1.08, "texture": "res://assets/enemies/ghost.png", "hframes": 4, "vframes": 1, "target_height": 42.0, "fallback_color": Color(0.70, 1.0, 0.62), "keep_distance": 245.0},
	"stone_statue": {"name": "석상", "mode": "melee", "hp_mult": 1.55, "speed_mult": 0.60, "texture": "res://assets/enemies/stone_statue.png", "hframes": 4, "vframes": 1, "target_height": 50.0, "fallback_color": Color(0.58, 0.58, 0.56)},
	"flame_imp": {"name": "불꽃 임프", "mode": "ranged", "hp_mult": 0.90, "speed_mult": 1.18, "texture": "res://assets/enemies/flame_imp.png", "hframes": 4, "vframes": 1, "target_height": 42.0, "fallback_color": Color(1.0, 0.38, 0.08), "keep_distance": 235.0},
}

const BOSS_ARCHETYPES: Dictionary = {
	1: {"key": "orc_king", "name": "오크킹", "texture": "res://assets/enemies/boss_orc_king.png", "hframes": 4, "vframes": 1, "target_height": 86.0, "fallback_color": Color(0.45, 0.78, 0.24), "hp_mult": 0.95, "burst_count_bonus": 0},
	2: {"key": "raven", "name": "레이븐", "texture": "res://assets/enemies/boss_raven.png", "hframes": 4, "vframes": 1, "target_height": 92.0, "fallback_color": Color(0.25, 0.22, 0.36), "hp_mult": 1.00, "burst_count_bonus": 2},
	3: {"key": "swamp_witch", "name": "늪지대 마녀", "texture": "res://assets/enemies/boss_swamp_witch.png", "hframes": 4, "vframes": 1, "target_height": 92.0, "fallback_color": Color(0.42, 0.60, 0.22), "hp_mult": 1.05, "burst_count_bonus": 3},
	4: {"key": "flame_dragon", "name": "화염룡", "texture": "res://assets/enemies/boss_flame_dragon.png", "hframes": 4, "vframes": 1, "target_height": 112.0, "fallback_color": Color(1.0, 0.32, 0.08), "hp_mult": 1.10, "burst_count_bonus": 4},
	5: {"key": "dark_lord", "name": "어둠의 군주", "texture": "res://assets/enemies/boss_dark_lord.png", "hframes": 4, "vframes": 1, "target_height": 100.0, "fallback_color": Color.WHITE, "hp_mult": 1.18, "burst_count_bonus": 6, "final_boss": true,
		"phases": [
			{"ratio": 0.70, "name": "그림자 각성", "line": "빛을 들고 왔느냐. 그렇다면 어둠도 갑옷을 벗겠다.", "speed_mult": 1.12, "burst_interval_mult": 0.88, "burst_count_bonus": 3, "target_height": 108.0, "fallback_color": Color(1.15, 0.80, 1.45)},
			{"ratio": 0.40, "name": "심연의 갑주", "line": "그 성검의 빛이 거슬리는구나. 심연이 너를 짓누를 것이다.", "speed_mult": 1.20, "burst_interval_mult": 0.78, "burst_count_bonus": 5, "target_height": 116.0, "fallback_color": Color(1.35, 0.55, 2.10)},
			{"ratio": 0.15, "name": "최후의 어둠", "line": "천 년의 어둠을 모두 태워도 마지막 밤은 남는다.", "speed_mult": 1.30, "burst_interval_mult": 0.68, "burst_count_bonus": 7, "target_height": 126.0, "fallback_color": Color(0.85, 0.35, 2.40)},
		]
	},
}

const STAGE_BACKGROUNDS: Dictionary = {
	1: "res://assets/backgrounds/stage1_forest.png",
	2: "res://assets/backgrounds/stage2_ruins.png",
	3: "res://assets/backgrounds/stage3_swamp.png",
	4: "res://assets/backgrounds/stage4_volcano.png",
	5: "res://assets/backgrounds/stage5_castle.png",
}

const ARMORS: Dictionary = {
	"leather_cap": {"slot": "helmet", "name": "가죽 모자", "rarity": "일반", "texture": "res://assets/equipment/leather_cap.png", "hp": 0, "damage_mult": 1.00, "attack_rate_mult": 1.00, "speed_mult": 1.00, "crit_bonus": 0.01},
	"knight_helmet": {"slot": "helmet", "name": "기사 투구", "rarity": "고급", "texture": "res://assets/equipment/knight_helmet.png", "hp": 1, "damage_mult": 1.04, "attack_rate_mult": 1.00, "speed_mult": 1.00, "crit_bonus": 0.02},
	"cloth_armor": {"slot": "armor", "name": "천 갑옷", "rarity": "일반", "texture": "res://assets/equipment/cloth_armor.png", "hp": 1, "damage_mult": 1.00, "attack_rate_mult": 1.00, "speed_mult": 1.00, "crit_bonus": 0.00},
	"mithril_armor": {"slot": "armor", "name": "미스릴 흉갑", "rarity": "고급", "texture": "res://assets/equipment/mithril_armor.png", "hp": 2, "damage_mult": 1.05, "attack_rate_mult": 1.00, "speed_mult": 1.00, "crit_bonus": 0.00},
	"training_gloves": {"slot": "gloves", "name": "무명 장갑", "rarity": "일반", "texture": "res://assets/equipment/training_gloves.png", "hp": 0, "damage_mult": 1.00, "attack_rate_mult": 1.08, "speed_mult": 1.00, "crit_bonus": 0.00},
	"berserker_gauntlets": {"slot": "gloves", "name": "광전사의 건틀릿", "rarity": "영웅", "texture": "res://assets/equipment/berserker_gauntlets.png", "hp": 0, "damage_mult": 1.12, "attack_rate_mult": 1.10, "speed_mult": 1.00, "crit_bonus": 0.01},
	"leather_boots": {"slot": "boots", "name": "가죽 부츠", "rarity": "일반", "texture": "res://assets/equipment/leather_boots.png", "hp": 0, "damage_mult": 1.00, "attack_rate_mult": 1.00, "speed_mult": 1.08, "crit_bonus": 0.00},
	"wind_boots": {"slot": "boots", "name": "질풍의 장화", "rarity": "고급", "texture": "res://assets/equipment/wind_boots.png", "hp": 0, "damage_mult": 1.00, "attack_rate_mult": 1.04, "speed_mult": 1.16, "crit_bonus": 0.00},
}

var selected_character: String = "knight"
var coins: int = 0
var gems: int = 0
var kills: int = 0
var floor: int = 1
var reached_stage: int = 1
var run_time: float = 0.0
var run_active: bool = false
var victory: bool = false
var is_test_mode: bool = true

var combo: int = 0
var combo_timer: float = 0.0

var rooms: Dictionary = {}
var current_id: int = 0
var start_id: int = 0
var visited_rooms: Dictionary = {}

var inventory: Array[String] = []
var equipped: String = ""
var equipment: Dictionary = {"helmet": "", "armor": "", "gloves": "", "boots": ""}
var boss_phase_hint: String = ""
var boss_phase_markers: Array = []
var _final_weapon_locked: bool = false

func start_new_run() -> void:
	coins = 0
	gems = 0
	kills = 0
	floor = 1
	reached_stage = 1
	run_time = 0.0
	run_active = true
	victory = false
	is_test_mode = true
	combo = 0
	combo_timer = 0.0
	inventory = ["wood"]
	equipped = "wood"
	equipment = {"helmet": "", "armor": "", "gloves": "", "boots": ""}
	_final_weapon_locked = false
	set_boss_phase_hint("")
	set_boss_phase_markers([])
	_generate_map()
	current_id = start_id
	visited_rooms.clear()
	visited_rooms[current_id] = true
	inventory_changed.emit()
	map_changed.emit()
	currency_changed.emit(coins, gems)

func _process(delta: float) -> void:
	if run_active:
		run_time += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_timer = 0.0
			combo = 0

func register_hit() -> void:
	combo += 1
	combo_timer = COMBO_TIMEOUT

func _generate_map() -> void:
	rooms.clear()
	if floor >= MAX_STAGE:
		_generate_final_boss_map()
		return

	var occupied: Dictionary = {}
	var next_id: int = 0
	var target_count: int = randi_range(MIN_ROOMS_PER_STAGE, MAX_ROOMS_PER_STAGE)

	var start_cell := Vector2i.ZERO
	rooms[next_id] = _new_room(next_id, "start", start_cell)
	occupied[start_cell] = next_id
	start_id = next_id
	next_id += 1

	var guard: int = 0
	while rooms.size() < target_count and guard < 500:
		guard += 1
		var base_id: int = int(rooms.keys()[randi() % rooms.size()])
		var base_cell: Vector2i = rooms[base_id].get("cell", Vector2i.ZERO)
		var dir: String = str(DIRS.keys()[randi() % DIRS.size()])
		var next_cell: Vector2i = base_cell + DIRS[dir]
		if occupied.has(next_cell):
			continue
		var new_id: int = next_id
		rooms[new_id] = _new_room(new_id, "combat", next_cell)
		occupied[next_cell] = new_id
		next_id += 1
		rooms[base_id]["doors"][dir] = new_id
		rooms[new_id]["doors"][OPP[dir]] = base_id

	for id in rooms.keys():
		var cell: Vector2i = rooms[id].get("cell", Vector2i.ZERO)
		for dir in DIRS.keys():
			var neighbor_cell: Vector2i = cell + DIRS[dir]
			if occupied.has(neighbor_cell) and not rooms[id]["doors"].has(dir) and randf() < 0.18:
				var neighbor_id: int = int(occupied[neighbor_cell])
				rooms[id]["doors"][dir] = neighbor_id
				rooms[neighbor_id]["doors"][OPP[dir]] = id

	var dist: Dictionary = _bfs_dist(start_id)
	var far_id: int = start_id
	for id in dist.keys():
		if int(dist[id]) > int(dist[far_id]):
			far_id = int(id)
	rooms[far_id]["type"] = "boss"

	var candidates: Array = []
	for id in rooms.keys():
		if id != start_id and id != far_id:
			candidates.append(id)
	candidates.shuffle()
	var special_types: Array[String] = ["elite", "treasure", "shop", "forge"]
	for i in range(min(candidates.size(), special_types.size())):
		var chance: float = 0.65 if special_types[i] != "forge" else 0.55
		if randf() < chance:
			rooms[candidates[i]]["type"] = special_types[i]

	for id in rooms.keys():
		_assign_config(rooms[id], dist.get(id, 1))

func _generate_final_boss_map() -> void:
	start_id = 0
	rooms[0] = _new_room(0, "start", Vector2i.ZERO)
	rooms[1] = _new_room(1, "boss", Vector2i(1, 0))
	rooms[0]["doors"]["E"] = 1
	rooms[1]["doors"]["W"] = 0
	_assign_config(rooms[0], 0)
	_assign_config(rooms[1], 1)

func _new_room(id: int, type: String, cell: Vector2i) -> Dictionary:
	return {"id": id, "type": type, "cell": cell, "doors": {}, "cleared": type == "start", "config": {}}

func _assign_config(room: Dictionary, depth: int) -> void:
	match room["type"]:
		"combat":
			room["config"] = {
				"enemy_count": 2 + floor + int(float(depth) * 0.45),
				"hp_bonus": max(0, floor - 2),
				"ranged_ratio": 0.0 if floor <= 1 else minf(0.28, 0.08 * float(floor - 1)),
			}
		"elite":
			room["config"] = {
				"enemy_count": 3 + floor + int(ceil(float(depth) * 0.45)),
				"hp_bonus": max(1, floor),
				"ranged_ratio": 0.0 if floor <= 1 else minf(0.34, 0.10 * float(floor - 1)),
				"coin_drop": 3,
			}
		_:
			room["config"] = {}

func _bfs_dist(src: int) -> Dictionary:
	var dist: Dictionary = {src: 0}
	var queue: Array[int] = [src]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for dir in rooms[cur]["doors"].keys():
			var neighbor: int = int(rooms[cur]["doors"][dir])
			if not dist.has(neighbor):
				dist[neighbor] = int(dist[cur]) + 1
				queue.append(neighbor)
	return dist

func current_room() -> Dictionary:
	return rooms[current_id]

func move_through(dir: String) -> String:
	var room: Dictionary = rooms[current_id]
	if room["doors"].has(dir):
		current_id = int(room["doors"][dir])
		mark_visited(current_id)
		map_changed.emit()
		return OPP[dir]
	return ""

func mark_visited(id: int) -> void:
	if rooms.has(id):
		visited_rooms[id] = true

func is_visited(id: int) -> bool:
	return visited_rooms.has(id)

func stage_data() -> Dictionary:
	return STAGES[clampi(floor - 1, 0, STAGES.size() - 1)]

func enemy_pool_for_stage(stage: int = -1) -> Array[String]:
	var stage_index: int = floor if stage <= 0 else stage
	var raw_pool: Array = STAGE_ENEMY_POOLS.get(stage_index, STAGE_ENEMY_POOLS.get(1, []))
	var pool: Array[String] = []
	for key in raw_pool:
		pool.append(str(key))
	return pool

func enemy_archetype(key: String) -> Dictionary:
	return ENEMY_ARCHETYPES.get(key, ENEMY_ARCHETYPES["orc"]).duplicate(true)

func enemy_config_for_key(key: String) -> Dictionary:
	return enemy_archetype(key)

func boss_config_for_stage(stage: int = -1) -> Dictionary:
	var stage_index: int = floor if stage <= 0 else stage
	var cfg: Dictionary = BOSS_ARCHETYPES.get(stage_index, BOSS_ARCHETYPES[1]).duplicate(true)
	var data: Dictionary = STAGES[clampi(stage_index - 1, 0, STAGES.size() - 1)]
	cfg["stage"] = stage_index
	cfg["name"] = str(data.get("boss", cfg.get("name", "보스")))
	cfg["intro_line"] = str(data.get("line", ""))
	return cfg

func phase_markers_from_config(cfg: Dictionary) -> Array:
	var markers: Array = []
	for phase in cfg.get("phases", []):
		if phase is Dictionary:
			markers.append({
				"ratio": float(phase.get("ratio", 0.0)),
				"label": "I",
				"name": str(phase.get("name", "")),
			})
	return markers

func stage_background_path(stage: int = -1) -> String:
	var stage_index: int = floor if stage <= 0 else stage
	return str(STAGE_BACKGROUNDS.get(stage_index, ""))

func set_boss_phase_hint(text: String) -> void:
	boss_phase_hint = text
	boss_phase_hint_changed.emit(text)

func set_boss_phase_markers(markers: Array) -> void:
	boss_phase_markers = markers.duplicate(true)
	boss_phase_markers_changed.emit(boss_phase_markers)

func prepare_final_boss_weapon() -> bool:
	if floor < MAX_STAGE:
		return false
	var sacred_key := "radiant"
	var kept: Array[String] = []
	for item_id in inventory:
		var item_text := str(item_id)
		if is_armor_item(item_text):
			kept.append(item_text)
	if sacred_key not in kept:
		kept.insert(0, sacred_key)
	inventory = kept
	equipped = sacred_key
	_final_weapon_locked = true
	inventory_changed.emit()
	show_center_message("나무검이 성검으로 변했다", Color(1.0, 0.92, 0.42))
	subtitle_requested.emit("성검", "나무검이 빛으로 다시 벼려졌다. 이제 성검 하나만으로 어둠을 베어라.")
	return true

func is_final_weapon_locked() -> bool:
	return _final_weapon_locked

func ending_line() -> String:
	return ENDING_LINE

func announce_boss() -> void:
	var data: Dictionary = stage_data()
	subtitle_requested.emit(str(data.get("boss", "보스")), str(data.get("line", "")))

func boss_reward_weapon() -> String:
	return str(stage_data().get("reward", "steel"))

func claim_weapon_reward(key: String) -> bool:
	if key == "":
		return false
	if add_inventory_item(key):
		equipped = key
		inventory_changed.emit()
		return true
	return false

func open_stage_chest() -> String:
	var keys: Array = ARMORS.keys()
	var key: String = str(keys[randi() % keys.size()])
	if pickup_armor(key):
		return key
	return ""

func is_weapon_item(item_id: String) -> bool:
	return item_id != "" and not item_id.begins_with("armor:") and WeaponDB.WEAPONS.has(WeaponDB.base_key(item_id))

func is_armor_item(item_id: String) -> bool:
	return item_id.begins_with("armor:") and ARMORS.has(armor_key_from_item(item_id))

func armor_item_id(key: String) -> String:
	return "armor:%s" % key

func create_armor_item_id(key: String) -> String:
	return "armor:%s:%d" % [key, randi()]

func armor_key_from_item(item_id: String) -> String:
	if item_id.begins_with("armor:"):
		var parts: PackedStringArray = item_id.split(":")
		if parts.size() >= 2:
			return parts[1]
	return item_id

func add_inventory_item(item_id: String) -> bool:
	if item_id == "":
		return false
	if is_weapon_item(item_id) and item_id in inventory:
		equipped = item_id
		inventory_changed.emit()
		return true
	if inventory.size() >= INVENTORY_CAPACITY:
		show_center_message("인벤토리가 꽉 찼습니다!", Color(1.0, 0.12, 0.08))
		return false
	inventory.append(item_id)
	inventory_changed.emit()
	return true

func pickup_armor(key: String) -> bool:
	if not ARMORS.has(key):
		return false
	return add_inventory_item(create_armor_item_id(key))

func equip_inventory_item(item_id: String) -> bool:
	if is_weapon_item(item_id):
		if item_id not in inventory:
			return false
		equipped = item_id
		inventory_changed.emit()
		return true
	if is_armor_item(item_id):
		equip_armor_item(item_id)
		return true
	return false

func unequip_armor_slot(slot: String) -> void:
	if equipment.has(slot):
		equipment[slot] = ""
		inventory_changed.emit()

func unequip_item(item_id: String) -> void:
	if not is_armor_item(item_id):
		return
	var key: String = armor_key_from_item(item_id)
	var cfg: Dictionary = ARMORS.get(key, {})
	var slot: String = str(cfg.get("slot", ""))
	if slot != "" and str(equipment.get(slot, "")) == item_id:
		unequip_armor_slot(slot)

func drop_inventory_item(item_id: String) -> bool:
	if _final_weapon_locked and item_id == equipped:
		show_center_message("성검은 최종전 동안 내려놓을 수 없습니다.", Color(1.0, 0.78, 0.30))
		return false
	if item_id == "wood":
		show_center_message("나무검은 버릴 수 없습니다!", Color(1.0, 0.12, 0.08))
		return false
	var index: int = inventory.find(item_id)
	if index == -1:
		return false
	inventory.remove_at(index)
	if item_id == equipped:
		equipped = "wood" if "wood" in inventory else ""
	if is_armor_item(item_id) and item_id not in inventory:
		unequip_item(item_id)
	inventory_changed.emit()
	inventory_item_dropped.emit(item_id)
	return true

func show_center_message(message: String, color: Color = Color.WHITE) -> void:
	center_message_requested.emit(message, color)

func equip_armor(key: String) -> void:
	equip_armor_item(armor_item_id(key))

func equip_armor_item(item_id: String) -> void:
	var key: String = armor_key_from_item(item_id)
	if not ARMORS.has(key):
		return
	var cfg: Dictionary = ARMORS[key]
	var slot: String = str(cfg.get("slot", ""))
	if slot == "":
		return
	equipment[slot] = item_id
	inventory_changed.emit()

func get_armor_stats(item_id: String) -> Dictionary:
	var key: String = armor_key_from_item(item_id)
	if not ARMORS.has(key):
		return {}
	var cfg: Dictionary = ARMORS[key].duplicate(true)
	var quality: float = _armor_quality_factor(item_id)
	cfg["damage_mult"] = float(cfg.get("damage_mult", 1.0)) * quality
	cfg["attack_rate_mult"] = float(cfg.get("attack_rate_mult", 1.0)) * _armor_quality_factor(item_id + ":atk")
	cfg["speed_mult"] = float(cfg.get("speed_mult", 1.0)) * _armor_quality_factor(item_id + ":spd")
	cfg["crit_bonus"] = float(cfg.get("crit_bonus", 0.0)) + (_armor_quality_factor(item_id + ":crit") - 1.0) * 0.18
	cfg["quality_percent"] = int(round((quality - 1.0) * 100.0))
	return cfg

func get_equipment_mods() -> Dictionary:
	var mods: Dictionary = {"hp": 0, "damage_mult": 1.0, "attack_rate_mult": 1.0, "speed_mult": 1.0, "crit_bonus": 0.0}
	for slot in equipment.keys():
		var item_id: String = str(equipment[slot])
		var key: String = armor_key_from_item(item_id)
		if item_id == "" or not ARMORS.has(key):
			continue
		var cfg: Dictionary = get_armor_stats(item_id)
		mods["hp"] = int(mods["hp"]) + int(cfg.get("hp", 0))
		mods["damage_mult"] = float(mods["damage_mult"]) * float(cfg.get("damage_mult", 1.0))
		mods["attack_rate_mult"] = float(mods["attack_rate_mult"]) * float(cfg.get("attack_rate_mult", 1.0))
		mods["speed_mult"] = float(mods["speed_mult"]) * float(cfg.get("speed_mult", 1.0))
		mods["crit_bonus"] = float(mods["crit_bonus"]) + float(cfg.get("crit_bonus", 0.0))
	return mods

func advance_stage() -> bool:
	if floor >= MAX_STAGE:
		finalize_victory()
		return false
	floor += 1
	reached_stage = max(reached_stage, floor)
	_final_weapon_locked = false
	set_boss_phase_hint("")
	set_boss_phase_markers([])
	_generate_map()
	current_id = start_id
	visited_rooms.clear()
	visited_rooms[current_id] = true
	map_changed.emit()
	return true

func equip(key: String) -> void:
	equip_inventory_item(key)

func get_evolution_cost(element: String, weapon_key: String = "") -> int:
	if element not in WeaponDB.ELEMENTS:
		return -1
	var key: String = equipped if weapon_key == "" else weapon_key
	if key == "":
		return -1
	return 0

func evolve_equipped(element: String) -> Dictionary:
	if equipped == "":
		return _forge_result(false, "장착한 무기가 없습니다.", "", 0)
	if element not in WeaponDB.ELEMENTS:
		return _forge_result(false, "알 수 없는 원소입니다.", equipped, 0)
	var slot_index: int = inventory.find(equipped)
	if slot_index == -1:
		return _forge_result(false, "장착 무기가 현재 인벤토리에 없습니다.", equipped, 0)
	var new_key: String = WeaponDB.evolved_key(equipped, element)
	if new_key == "":
		return _forge_result(false, "이 무기는 진화할 수 없습니다.", equipped, 0)
	var cost: int = get_evolution_cost(element, equipped)
	if cost < 0:
		return _forge_result(false, "대장간 비용이 올바르지 않습니다.", equipped, cost)
	if cost > 0 and coins < cost:
		return _forge_result(false, "코인이 부족합니다.", equipped, cost)
	if cost > 0:
		coins -= cost
		currency_changed.emit(coins, gems)
	inventory[slot_index] = new_key
	equipped = new_key
	var message: String = "제작 완료: %s" % WeaponDB.display_name(new_key)
	inventory_changed.emit()
	forge_message_changed.emit(message)
	return _forge_result(true, message, new_key, cost)

func _forge_result(ok: bool, message: String, key: String, cost: int) -> Dictionary:
	return {"ok": ok, "message": message, "key": key, "cost": cost}

func mark_cleared(id: int) -> void:
	if rooms.has(id):
		rooms[id]["cleared"] = true
	map_changed.emit()

func is_boss_room(id: int) -> bool:
	return rooms.has(id) and rooms[id]["type"] == "boss"

func report_kill(pos: Vector2) -> void:
	kills += 1
	enemy_died.emit(pos)
	stats_meta_changed.emit(kills)

func add_coins(n: int) -> void:
	coins += n
	currency_changed.emit(coins, gems)

func add_gems(n: int) -> void:
	gems += n
	currency_changed.emit(coins, gems)

func spend_coins(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	currency_changed.emit(coins, gems)
	return true

func spend_gems(n: int) -> bool:
	if gems < n:
		return false
	gems -= n
	currency_changed.emit(coins, gems)
	return true

func set_boss_active(active: bool) -> void:
	boss_active_changed.emit(active)
	if not active:
		set_boss_phase_markers([])

func report_boss_health(cur: float, max_hp: float) -> void:
	boss_health_changed.emit(cur, max_hp)

func finalize_run() -> void:
	run_active = false

func finalize_victory() -> void:
	victory = true
	run_active = false

func biome() -> Dictionary:
	var biomes: Array[Dictionary] = [
		{"floor": Color.BLACK, "floor_alt": Color.BLACK, "wall": Color(0.25, 0.25, 0.25), "trim": Color(0.50, 0.47, 0.40), "moss": Color(0.10, 0.32, 0.11), "torch": Color(1.0, 0.58, 0.16)},
		{"floor": Color.BLACK, "floor_alt": Color.BLACK, "wall": Color(0.22, 0.24, 0.25), "trim": Color(0.45, 0.44, 0.39), "moss": Color(0.08, 0.28, 0.16), "torch": Color(0.95, 0.52, 0.18)},
		{"floor": Color.BLACK, "floor_alt": Color.BLACK, "wall": Color(0.13, 0.16, 0.13), "trim": Color(0.31, 0.42, 0.29), "moss": Color(0.08, 0.30, 0.18), "torch": Color(0.55, 0.90, 0.35)},
		{"floor": Color.BLACK, "floor_alt": Color.BLACK, "wall": Color(0.32, 0.23, 0.18), "trim": Color(0.62, 0.34, 0.18), "moss": Color(0.20, 0.09, 0.04), "torch": Color(1.0, 0.35, 0.08)},
		{"floor": Color.BLACK, "floor_alt": Color.BLACK, "wall": Color(0.18, 0.16, 0.22), "trim": Color(0.47, 0.43, 0.52), "moss": Color(0.04, 0.04, 0.08), "torch": Color(0.72, 0.52, 1.0)},
	]
	return biomes[(floor - 1) % biomes.size()]

func _rarity_score(rarity: String) -> int:
	match rarity:
		"고급":
			return 2
		"영웅":
			return 3
		"전설":
			return 4
		_:
			return 1

func _armor_quality_factor(item_id: String) -> float:
	if item_id.split(":").size() < 3:
		return 1.0
	var hash_value: int = abs(hash(item_id))
	var percent: int = 1 + (hash_value % 5)
	return 1.0 + float(percent) / 100.0
