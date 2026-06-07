extends Node2D
## Base room controller for a top-down roguelike room.
##
## Responsibilities:
## - Builds the four optional corridor/door entrances from map data.
## - Runs the room state machine: UNVISITED -> LOCKED -> CLEARED.
## - Spawns enemies when the player enters an unvisited combat room.
## - Opens all physical door gates once combat is cleared.
## - Exposes camera bounds so Player.Camera2D can be clamped to this room.

signal move_requested(dir: String)
signal victory_requested
signal stage_portal_requested
signal boss_intro_requested(boss_position: Vector2, speaker: String, line: String)
signal state_changed(new_state: int)
signal room_cleared(room_id: int)
signal forge_requested   # 대장간 방에서 플레이어가 모루 앞에서 F 를 눌렀을 때

enum RoomState { UNVISITED, LOCKED, CLEARED }

const DOOR: PackedScene = preload("res://scenes/rooms/Door.tscn")
const ENEMY: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
const BOSS: PackedScene = preload("res://scenes/enemies/Boss.tscn")
const COIN_PICKUP: PackedScene = preload("res://scenes/pickups/CoinPickup.tscn")
const GEM_PICKUP: PackedScene = preload("res://scenes/pickups/GemPickup.tscn")
const SHOP_ITEM: PackedScene = preload("res://scenes/ShopItem.tscn")
const OBSTACLE_SCRIPT: Script = preload("res://scripts/obstacle.gd")
const REWARD_SCRIPT: Script = preload("res://scripts/reward_interactable.gd")
const INVENTORY_ITEM_PICKUP_SCRIPT: Script = preload("res://scripts/pickups/inventory_item_pickup.gd")
const STAGE_CHEST_TEXTURE: Texture2D = preload("res://assets/reward/stage_chest.png")
const PORTAL_TEXTURE: Texture2D = preload("res://assets/ui/generated/minimap_panel_ai.png")
const COMBAT_CHEST_CHANCE: float = 0.75
const DROPPED_ITEM_SPACING: float = 62.0

const DOOR_POS: Dictionary = {
	"N": Vector2(0, -330),
	"S": Vector2(0, 330),
	"E": Vector2(560, 0),
	"W": Vector2(-560, 0),
}
const DOOR_SIZE: Dictionary = {
	"N": Vector2(150, 60),
	"S": Vector2(150, 60),
	"E": Vector2(60, 150),
	"W": Vector2(60, 150),
}
const ENTRY_POS: Dictionary = {
	"N": Vector2(0, -280),
	"S": Vector2(0, 280),
	"E": Vector2(480, 0),
	"W": Vector2(-480, 0),
}

@export var room_bounds: Rect2 = Rect2(Vector2(-610, -380), Vector2(1220, 760))

var state: int = RoomState.UNVISITED

var _room_id: int = 0
var _room_type: String = "combat"
var _room_config: Dictionary = {}
var _is_boss: bool = false
var _doors: Dictionary = {} # dir -> Door node
var _active_enemies: Array[Node] = []
var _armed_for_exit: bool = false
var _player_in_forge: bool = false
var _forge_prompt: Label = null
var _stage_rewards_spawned: bool = false
var _clear_chest_spawned: bool = false
var _has_drop_origin: bool = false
var _drop_origin_local: Vector2 = Vector2.ZERO
var _drop_line_count: int = 0
var _boss_intro_enemy: Node = null
var _background_sprite: Sprite2D = null

@onready var _floor: ColorRect = $Floor
@onready var _floor_details: Node2D = $FloorDetails
@onready var _walls_visual: Node2D = $WallVisuals
@onready var _content: Node2D = $Content
@onready var _entry_detector: Area2D = $EntryDetector

func _ready() -> void:
	_entry_detector.body_entered.connect(_on_entry_body_entered)

func setup(room: Dictionary, biome: Dictionary) -> void:
	_room_id = room.get("id", 0)
	_room_type = room.get("type", "combat")
	_room_config = room.get("config", {})
	_is_boss = _room_type == "boss"
	_active_enemies.clear()
	_armed_for_exit = false
	_stage_rewards_spawned = false
	_clear_chest_spawned = false
	_has_drop_origin = false
	_drop_origin_local = Vector2.ZERO
	_drop_line_count = 0
	_boss_intro_enemy = null

	for dir in room.get("doors", {}).keys():
		_make_door(dir)

	_apply_biome(biome)
	_spawn_obstacles(_room_type)
	_restore_or_create_items(room)
	if _room_type == "forge":
		_build_forge()

	if room.get("cleared", false) or not _room_has_combat():
		_set_state(RoomState.CLEARED)
		if _room_type == "treasure" or _room_type == "shop" or _room_type == "start" or _room_type == "forge":
			GameManager.mark_cleared(_room_id)
	else:
		_set_state(RoomState.UNVISITED)

	# Prevent instant room transitions while the player is being placed at an
	# entrance, then activate combat if the player is already inside the room.
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		_armed_for_exit = true
	)
	call_deferred("_activate_if_player_inside")

func entry_position(entry_dir: String) -> Vector2:
	if entry_dir != "" and ENTRY_POS.has(entry_dir):
		return ENTRY_POS[entry_dir]
	return Vector2.ZERO

func get_room_bounds_global() -> Rect2:
	var tile_source: Node = get_node_or_null("TileMapLayer")
	if tile_source == null:
		tile_source = get_node_or_null("TileMap")

	if tile_source != null and tile_source.has_method("get_used_rect"):
		var used: Rect2i = tile_source.get_used_rect()
		var tile_set: TileSet = tile_source.get("tile_set") as TileSet
		if tile_set != null and used.size != Vector2i.ZERO:
			var tile_size: Vector2 = Vector2(tile_set.tile_size)
			var top_left: Vector2 = tile_source.to_global(Vector2(used.position) * tile_size)
			var bottom_right: Vector2 = tile_source.to_global(Vector2(used.position + used.size) * tile_size)
			return Rect2(top_left, bottom_right - top_left).abs()

	return Rect2(to_global(room_bounds.position), room_bounds.size)

func update_camera_limits(player: Node) -> void:
	if player != null and player.has_method("set_camera_limits"):
		player.set_camera_limits(get_room_bounds_global())

func drop_inventory_item_on_floor(item_id: String, player_global_position: Vector2) -> void:
	if item_id == "":
		return
	var desired_origin := to_local(player_global_position) + Vector2(0, 54)
	desired_origin.x = clampf(desired_origin.x, room_bounds.position.x + 90.0, room_bounds.end.x - 90.0)
	desired_origin.y = clampf(desired_origin.y, room_bounds.position.y + 90.0, room_bounds.end.y - 90.0)

	if not _has_drop_origin or _drop_origin_local.distance_to(desired_origin) > 96.0:
		_has_drop_origin = true
		_drop_origin_local = desired_origin
		_drop_line_count = _nearby_dropped_item_count(_drop_origin_local)

	var offset_index: int = _drop_line_count
	var side: int = -1 if offset_index % 2 == 0 else 1
	var step: int = int(ceil(float(offset_index) / 2.0))
	var drop_pos := _drop_origin_local + Vector2(float(side * step) * DROPPED_ITEM_SPACING, 0.0)
	drop_pos.x = clampf(drop_pos.x, room_bounds.position.x + 70.0, room_bounds.end.x - 70.0)
	_drop_line_count += 1

	_spawn_inventory_item_pickup(item_id, drop_pos)

func get_active_enemy_count() -> int:
	_prune_enemy_list()
	return _active_enemies.size()

func force_clear() -> void:
	# Handy for debug rooms, scripted events, or tests.
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_on_cleared()

func finish_boss_intro() -> void:
	if is_instance_valid(_boss_intro_enemy):
		_boss_intro_enemy.set_physics_process(true)
		_boss_intro_enemy.set_process(true)
	_boss_intro_enemy = null

func _make_door(dir: String) -> void:
	if not DOOR_POS.has(dir):
		return

	var door: Node2D = DOOR.instantiate()
	door.setup(dir, DOOR_POS[dir], DOOR_SIZE[dir])
	door.exit_requested.connect(_on_door_exit_requested)
	_content.add_child(door)
	_doors[dir] = door

func _set_doors_locked(locked: bool) -> void:
	for dir in _doors.keys():
		var door: Node = _doors[dir]
		if door.has_method("set_locked"):
			door.set_locked(locked)

func _on_door_exit_requested(dir: String) -> void:
	if _armed_for_exit and state == RoomState.CLEARED:
		move_requested.emit(dir)

func _on_entry_body_entered(body: Node) -> void:
	if body.is_in_group("player") and state == RoomState.UNVISITED:
		_start_combat()

func _activate_if_player_inside() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or state != RoomState.UNVISITED:
		return
	if get_room_bounds_global().has_point(player.global_position):
		_start_combat()

func _start_combat() -> void:
	if state != RoomState.UNVISITED:
		return
	_set_state(RoomState.LOCKED)
	_spawn_enemies_for_room()
	_prune_enemy_list()
	if _active_enemies.is_empty():
		_on_cleared()

func _spawn_enemies_for_room() -> void:
	if _room_type == "boss":
		_spawn_boss(GameManager.floor)
	elif _room_type == "combat" or _room_type == "elite":
		_spawn_wave(_room_config)

func _track_enemy(enemy: Node) -> void:
	_active_enemies.append(enemy)
	enemy.tree_exiting.connect(func() -> void:
		_on_enemy_tree_exiting(enemy)
	)

func _on_enemy_tree_exiting(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	call_deferred("_check_clear_condition")

func _check_clear_condition() -> void:
	if state != RoomState.LOCKED:
		return
	_prune_enemy_list()
	if _active_enemies.is_empty():
		_on_cleared()

func _prune_enemy_list() -> void:
	for i in range(_active_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_active_enemies[i]):
			_active_enemies.remove_at(i)

func _set_state(next_state: int) -> void:
	if state == next_state:
		return
	state = next_state
	_set_doors_locked(state == RoomState.LOCKED)
	state_changed.emit(state)

func _room_has_combat() -> bool:
	return _room_type == "combat" or _room_type == "elite" or _room_type == "boss"

func _on_cleared() -> void:
	_set_state(RoomState.CLEARED)
	GameManager.mark_cleared(_room_id)
	room_cleared.emit(_room_id)
	if _is_boss:
		_spawn_stage_clear_rewards()
	elif (_room_type == "combat" or _room_type == "elite") and randf() < COMBAT_CHEST_CHANCE:
		_spawn_combat_clear_chest()

func _spawn_combat_clear_chest() -> void:
	if _clear_chest_spawned:
		return
	_clear_chest_spawned = true
	var chest := Area2D.new()
	chest.set_script(REWARD_SCRIPT)
	chest.position = Vector2(0, 0)
	_content.add_child(chest)
	chest.call("setup", "chest", "", STAGE_CHEST_TEXTURE, "G: 보상 상자")

func _spawn_stage_clear_rewards() -> void:
	if _stage_rewards_spawned:
		return
	_stage_rewards_spawned = true

	if GameManager.floor >= GameManager.MAX_STAGE:
		var final_portal := Area2D.new()
		final_portal.set_script(REWARD_SCRIPT)
		final_portal.position = Vector2(0, 0)
		_content.add_child(final_portal)
		final_portal.call("setup", "portal", "", PORTAL_TEXTURE, "Q: 엔딩으로")
		final_portal.portal_requested.connect(func() -> void:
			stage_portal_requested.emit()
		)
		return

	var chest := Area2D.new()
	chest.set_script(REWARD_SCRIPT)
	chest.position = Vector2(0, 0)
	_content.add_child(chest)
	chest.call("setup", "chest", "", STAGE_CHEST_TEXTURE, "G: 보상 상자")

	var reward_key: String = GameManager.boss_reward_weapon()
	var weapon_texture: Texture2D = load(WeaponDB.get_weapon(reward_key).get("texture", ""))
	var sword := Area2D.new()
	sword.set_script(REWARD_SCRIPT)
	sword.position = Vector2(-135, 0)
	_content.add_child(sword)
	sword.call("setup", "weapon", reward_key, weapon_texture, "G: %s" % WeaponDB.display_name(reward_key))

	var portal := Area2D.new()
	portal.set_script(REWARD_SCRIPT)
	portal.position = Vector2(135, 0)
	_content.add_child(portal)
	var portal_text: String = "Q: 엔딩으로" if GameManager.floor >= GameManager.MAX_STAGE else "Q: 다음 스테이지"
	portal.call("setup", "portal", "", PORTAL_TEXTURE, portal_text)
	portal.portal_requested.connect(func() -> void:
		stage_portal_requested.emit()
	)

func _spawn_wave(config: Dictionary) -> void:
	var count: int = config.get("enemy_count", 4)
	var floor_n: int = GameManager.floor
	var hp_bonus: int = config.get("hp_bonus", 0)
	var coin_drop: int = config.get("coin_drop", 2)
	var full_pool: Array[String] = GameManager.enemy_pool_for_stage(floor_n)
	if full_pool.is_empty():
		full_pool = ["orc"]
	var encounter_pool: Array[String] = full_pool.duplicate()
	if full_pool.size() > 1 and randf() < 0.42:
		encounter_pool = [full_pool[randi() % full_pool.size()]]

	for i in range(count):
		var enemy: CharacterBody2D = ENEMY.instantiate()
		var enemy_key: String = encounter_pool[randi() % encounter_pool.size()]
		var archetype: Dictionary = GameManager.enemy_archetype(enemy_key)
		var mode_name: String = str(archetype.get("mode", "melee"))
		var base_hp: int = 1 + floor_n + hp_bonus + (1 if mode_name == "ranged" else 0)
		var base_speed: float = (50.0 if mode_name == "ranged" else 58.0) + floor_n * 3.0
		enemy.setup({
			"enemy_key": enemy_key,
			"display_name": str(archetype.get("name", "적")),
			"mode": mode_name,
			"hp": int(ceil(float(base_hp) * float(archetype.get("hp_mult", 1.0)))),
			"speed": base_speed * float(archetype.get("speed_mult", 1.0)),
			"contact_damage": 1,
			"contact_interval": 1.20 if floor_n <= 2 else 1.0,
			"shoot_interval": maxf(1.15, 2.10 - float(floor_n) * 0.12),
			"keep_distance": float(archetype.get("keep_distance", 210.0)),
			"coin_drop": coin_drop,
			"texture": str(archetype.get("texture", "")),
			"hframes": int(archetype.get("hframes", 4)),
			"vframes": int(archetype.get("vframes", 1)),
			"target_height": float(archetype.get("target_height", 48.0)),
			"sprite_scale": archetype.get("scale", Vector2(0.18, 0.18)),
			"fallback_color": archetype.get("fallback_color", Color.WHITE),
		})
		_content.add_child(enemy)
		enemy.global_position = to_global(_random_spawn_pos())
		_track_enemy(enemy)

func _spawn_boss(floor_n: int) -> void:
	if floor_n >= GameManager.MAX_STAGE:
		GameManager.prepare_final_boss_weapon()

	var boss: CharacterBody2D = BOSS.instantiate()
	var boss_cfg: Dictionary = GameManager.boss_config_for_stage(floor_n)
	boss.setup(floor_n, boss_cfg)
	_content.add_child(boss)
	boss.global_position = to_global(Vector2(0, -40))
	boss.set_physics_process(false)
	boss.set_process(false)
	_boss_intro_enemy = boss
	_track_enemy(boss)
	boss_intro_requested.emit(boss.global_position, str(boss_cfg.get("name", "보스")), str(boss_cfg.get("intro_line", "")))

func _random_spawn_pos() -> Vector2:
	for attempt in range(20):
		var point := Vector2(randf_range(-460, 460), randf_range(-280, 280))
		if point.length() > 160.0:
			return point
	return Vector2(250, 0)

func _restore_or_create_items(room: Dictionary) -> void:
	if room.has("items"):
		for item_data in room["items"]:
			_spawn_item(item_data)
	else:
		var items := _initial_items(_room_type)
		room["items"] = items
		for item_data in items:
			_spawn_item(item_data)

func _initial_items(type: String) -> Array:
	var items: Array = []
	match type:
		"treasure":
			for i in range(5):
				items.append({"kind": "coin", "pos": Vector2(randf_range(-130, 130), randf_range(-110, 110)), "value": 1})
			for i in range(2):
				items.append({"kind": "gem", "pos": Vector2(randf_range(-90, 90), randf_range(-70, 70)), "value": 1})
		"shop":
			var defs: Array = [
				{"kind": "hp", "currency": "gem", "cost": 2, "label": "최대 체력 +1"},
				{"kind": "shield", "currency": "gem", "cost": 2, "label": "최대 보호막 +1"},
				{"kind": "energy", "currency": "coin", "cost": 25, "label": "최대 에너지 +20"},
			]
			var xs: Array = [-150, 0, 150]
			for i in range(defs.size()):
				items.append({"kind": "shop", "pos": Vector2(xs[i], -40), "item": defs[i]})
	return items

func _spawn_item(data: Dictionary) -> void:
	var kind: String = data.get("kind", "")
	var node: Area2D = null
	match kind:
		"coin":
			node = COIN_PICKUP.instantiate()
			node.value = data.get("value", 1)
		"gem":
			node = GEM_PICKUP.instantiate()
			node.value = data.get("value", 1)
		"shop":
			node = SHOP_ITEM.instantiate()
		"inventory_item":
			_spawn_inventory_item_pickup(str(data.get("item_id", "")), data.get("pos", Vector2.ZERO))
			return
		"reward":
			_spawn_reward_interactable(data)
			return
		_:
			return

	node.position = data.get("pos", Vector2.ZERO)
	_content.add_child(node)
	if kind == "shop":
		node.configure(data.get("item", {}))

func _spawn_reward_interactable(data: Dictionary) -> void:
	var mode: String = str(data.get("mode", "chest"))
	var reward_key: String = str(data.get("reward_key", ""))
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var texture: Texture2D = null
	var label_text: String = ""

	match mode:
		"weapon":
			texture = load(WeaponDB.get_weapon(reward_key).get("texture", ""))
			label_text = "G: %s" % WeaponDB.display_name(reward_key)
		"portal":
			texture = PORTAL_TEXTURE
			label_text = "Q: 엔딩으로" if GameManager.floor >= GameManager.MAX_STAGE else "Q: 다음 스테이지"
		_:
			mode = "chest"
			texture = STAGE_CHEST_TEXTURE
			label_text = "G: 보상 상자"

	var reward := Area2D.new()
	reward.set_script(REWARD_SCRIPT)
	reward.position = pos
	_content.add_child(reward)
	reward.call("setup", mode, reward_key, texture, label_text)
	if mode == "portal":
		reward.portal_requested.connect(func() -> void:
			stage_portal_requested.emit()
		)

func _spawn_inventory_item_pickup(item_id: String, local_pos: Vector2) -> void:
	if item_id == "":
		return
	var node := Area2D.new()
	node.set_script(INVENTORY_ITEM_PICKUP_SCRIPT)
	node.position = local_pos
	_content.add_child(node)
	node.call("setup", item_id)

func _nearby_dropped_item_count(origin: Vector2) -> int:
	var count: int = 0
	for child in _content.get_children():
		if child.is_in_group("pickup") and child.has_method("save_data"):
			var data: Dictionary = child.save_data()
			if str(data.get("kind", "")) == "inventory_item" and child.position.distance_to(origin) < 220.0:
				count += 1
	return count

func get_items_data() -> Array:
	var items: Array = []
	for pickup in _content.get_children():
		if pickup.has_method("save_data"):
			var data: Dictionary = pickup.save_data()
			if not data.is_empty():
				items.append(data)
	return items

func _spawn_obstacles(type: String) -> void:
	var variant: int = abs(_room_id + GameManager.floor * 3) % 4
	var defs: Array = []
	match type:
		"boss":
			defs = [
				{"kind": "cover", "pos": Vector2(-210, 110), "hp": 7},
				{"kind": "cover", "pos": Vector2(210, 110), "hp": 7},
				{"kind": "explosive", "pos": Vector2(-320, -150), "hp": 2},
				{"kind": "explosive", "pos": Vector2(320, -150), "hp": 2},
			]
		"shop":
			defs = [
				{"kind": "crate", "pos": Vector2(-320, 150), "hp": 4},
				{"kind": "cover", "pos": Vector2(310, 160), "hp": 7},
			]
		"treasure":
			defs = [
				{"kind": "crate", "pos": Vector2(-210, 150), "hp": 3},
				{"kind": "crate", "pos": Vector2(210, 150), "hp": 3},
			]
		"forge":
			defs = []   # 대장간 방은 전투 장애물 없음(모루만 배치)
		_:
			var layouts: Array = [
				[
					{"kind": "cover", "pos": Vector2(-240, -60), "hp": 6},
					{"kind": "cover", "pos": Vector2(240, 70), "hp": 6},
					{"kind": "explosive", "pos": Vector2(0, 135), "hp": 2},
				],
				[
					{"kind": "crate", "pos": Vector2(-330, 120), "hp": 4},
					{"kind": "cover", "pos": Vector2(0, -115), "hp": 6},
					{"kind": "explosive", "pos": Vector2(310, -105), "hp": 2},
				],
				[
					{"kind": "cover", "pos": Vector2(-150, 85), "hp": 6},
					{"kind": "cover", "pos": Vector2(150, 85), "hp": 6},
					{"kind": "explosive", "pos": Vector2(-360, -160), "hp": 2},
					{"kind": "crate", "pos": Vector2(360, 160), "hp": 4},
				],
				[
					{"kind": "cover", "pos": Vector2(-390, 0), "hp": 6},
					{"kind": "cover", "pos": Vector2(390, 0), "hp": 6},
					{"kind": "explosive", "pos": Vector2(0, -190), "hp": 2},
				],
			]
			defs = layouts[variant]

	for data in defs:
		var obstacle := StaticBody2D.new()
		obstacle.set_script(OBSTACLE_SCRIPT)
		obstacle.position = data.get("pos", Vector2.ZERO)
		obstacle.call("setup", data)
		_content.add_child(obstacle)

func _apply_biome(biome: Dictionary) -> void:
	if _floor != null and biome.has("floor"):
		_floor.color = biome["floor"]
	if biome.has("wall"):
		for wall in _walls_visual.get_children():
			if wall is ColorRect:
				wall.color = biome["wall"]

	var trim: Color = biome.get("trim", Color(0.55, 0.38, 0.18))
	var torch: Color = biome.get("torch", Color(1.0, 0.55, 0.18))
	for dir in _doors.keys():
		var door: Node = _doors[dir]
		if door.has_method("set_palette"):
			door.set_palette(
				Color(trim.r, trim.g, trim.b, 0.62),
				Color(torch.r, torch.g * 0.35, torch.b * 0.25, 0.86)
			)

	_paint_simple_floor_details(biome)
	_apply_stage_background()

func _apply_stage_background() -> void:
	var path: String = GameManager.stage_background_path()
	if path == "" or not ResourceLoader.exists(path):
		if is_instance_valid(_background_sprite):
			_background_sprite.queue_free()
			_background_sprite = null
		return

	var texture: Texture2D = load(path)
	if texture == null:
		return
	if not is_instance_valid(_background_sprite):
		_background_sprite = Sprite2D.new()
		_background_sprite.name = "StageBackground"
		_background_sprite.centered = true
		_background_sprite.z_index = -20
		_floor_details.add_child(_background_sprite)
		_floor_details.move_child(_background_sprite, 0)

	_background_sprite.texture = texture
	_background_sprite.position = room_bounds.get_center()
	_background_sprite.scale = Vector2(
		room_bounds.size.x / maxf(1.0, float(texture.get_width())),
		room_bounds.size.y / maxf(1.0, float(texture.get_height()))
	)
	# 배경이 깔리면 불투명한 어두운 Floor가 배경을 가리지 않도록 투명화(검은 바닥 버그 해결)
	if _floor != null:
		_floor.color = Color(_floor.color.r, _floor.color.g, _floor.color.b, 0.0)

func _paint_simple_floor_details(biome: Dictionary) -> void:
	for child in _floor_details.get_children():
		if child != _background_sprite:
			child.queue_free()

	var base: Color = biome.get("floor_alt", Color(0.2, 0.2, 0.2))
	for x in range(-560, 561, 80):
		_add_rect(_floor_details, Vector2(x, -330), Vector2(3, 660), Color(base.r, base.g, base.b, 0.45))
	for y in range(-320, 321, 80):
		_add_rect(_floor_details, Vector2(-560, y), Vector2(1120, 3), Color(base.r, base.g, base.b, 0.45))

func _add_rect(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

# --- 대장간 방(스테이지) -------------------------------------------------------

## 방 중앙에 모루 + 상호작용 존을 배치한다.
## NOTE: 비주얼은 단순 도형 플레이스홀더다. 실제 대장간 스프라이트가 생기면
## _build_forge() 안의 Polygon2D/ColorRect 를 Sprite2D 로 교체하면 된다.
func _build_forge() -> void:
	var zone := Area2D.new()
	zone.name = "AnvilZone"
	zone.position = Vector2(0, -10)
	zone.collision_layer = 0
	zone.collision_mask = 1   # 플레이어(layer 1) 만 감지
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 90.0
	shape.shape = circle
	zone.add_child(shape)

	# 따뜻한 화로 글로우
	var glow := Polygon2D.new()
	glow.polygon = _circle_points(130.0, 28)
	glow.color = Color(1.0, 0.5, 0.15, 0.16)
	zone.add_child(glow)

	# 모루 받침
	_add_rect(zone, Vector2(-36, 18), Vector2(72, 16), Color(0.12, 0.12, 0.14, 1.0))

	# 모루 본체
	var anvil := Polygon2D.new()
	anvil.polygon = PackedVector2Array([
		Vector2(-46, -18), Vector2(46, -18), Vector2(46, -6), Vector2(16, -4),
		Vector2(12, 8), Vector2(22, 20), Vector2(-22, 20), Vector2(-12, 8),
		Vector2(-16, -4), Vector2(-46, -6),
	])
	anvil.color = Color(0.26, 0.27, 0.30, 1.0)
	zone.add_child(anvil)

	# 모루 상단 하이라이트
	_add_rect(zone, Vector2(-46, -18), Vector2(92, 5), Color(0.40, 0.41, 0.45, 1.0))

	# "Press F to Forge" 안내(평소 숨김)
	_forge_prompt = Label.new()
	_forge_prompt.name = "ForgePrompt"
	_forge_prompt.text = "F: 대장간 열기"
	_forge_prompt.position = Vector2(-95, -78)
	_forge_prompt.size = Vector2(190, 26)
	_forge_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forge_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forge_prompt.visible = false
	_forge_prompt.add_theme_font_size_override("font_size", 18)
	_forge_prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	_forge_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_forge_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_forge_prompt.add_theme_constant_override("shadow_offset_y", 2)
	zone.add_child(_forge_prompt)

	zone.body_entered.connect(_on_forge_zone_entered)
	zone.body_exited.connect(_on_forge_zone_exited)
	_content.add_child(zone)

func _on_forge_zone_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_forge = true
		if _forge_prompt != null:
			_forge_prompt.visible = true

func _on_forge_zone_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_forge = false
		if _forge_prompt != null:
			_forge_prompt.visible = false

## 모루 존 안에서 F 를 누르면 대장간 UI 요청. (UI 가 열려 트리가 멈추면 이 입력은 동작하지 않음)
func _input(event: InputEvent) -> void:
	if not _player_in_forge:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		forge_requested.emit()
		get_viewport().set_input_as_handled()

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
