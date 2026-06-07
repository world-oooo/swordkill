extends Node2D
## Main runtime scene.
##
## Player and HUD persist while the active room scene is swapped under World
## whenever the player walks through a cleared door.

const ROOM: PackedScene = preload("res://scenes/rooms/Room.tscn")
const FORGE_ROOM: PackedScene = preload("res://scenes/rooms/ForgeRoom.tscn")

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var _fade_rect: ColorRect = $Fade/Black
@onready var _inventory: CanvasLayer = $Inventory
@onready var forge_ui: CanvasLayer = $ForgeUI

var _room: Node2D = null
var _transitioning: bool = false
var _boss_intro_running: bool = false
var _boss_cinematic_running: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	if GameManager.rooms.is_empty():
		GameManager.start_new_run()
	if not GameManager.inventory_item_dropped.is_connected(_on_inventory_item_dropped):
		GameManager.inventory_item_dropped.connect(_on_inventory_item_dropped)
	if not GameManager.boss_cinematic_requested.is_connected(_on_boss_cinematic_requested):
		GameManager.boss_cinematic_requested.connect(_on_boss_cinematic_requested)
	player.died.connect(_on_player_died)
	_load_room.call_deferred("")

func _load_room(entry_dir: String) -> void:
	if is_instance_valid(_room):
		_room.queue_free()

	var room_data: Dictionary = GameManager.current_room()
	# 대장간 방은 배경 이미지를 넣을 수 있는 전용 씬(ForgeRoom.tscn)을 사용한다.
	var room_scene: PackedScene = FORGE_ROOM if room_data.get("type", "") == "forge" else ROOM
	_room = room_scene.instantiate()
	world.add_child(_room)
	player.global_position = _room.entry_position(entry_dir)
	_room.setup(room_data, GameManager.biome())
	if _room.has_method("update_camera_limits"):
		_room.update_camera_limits(player)
	_room.move_requested.connect(_on_move_requested)
	_room.victory_requested.connect(_on_victory_requested)
	_room.forge_requested.connect(_on_forge_requested)
	if _room.has_signal("stage_portal_requested"):
		_room.stage_portal_requested.connect(_on_stage_portal_requested)
	if _room.has_signal("boss_intro_requested"):
		_room.boss_intro_requested.connect(_on_boss_intro_requested)
	GameManager.map_changed.emit()

func _on_forge_requested() -> void:
	if forge_ui != null and forge_ui.has_method("open"):
		forge_ui.open()

func _on_move_requested(dir: String) -> void:
	_do_move.call_deferred(dir)

func _do_move(dir: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade(1.0)

	if is_instance_valid(_room) and _room.has_method("get_items_data"):
		GameManager.rooms[GameManager.current_id]["items"] = _room.get_items_data()

	var entry: String = GameManager.move_through(dir)
	if entry != "":
		_load_room(entry)

	await get_tree().process_frame
	await _fade(0.0)
	_transitioning = false

func _fade(target_a: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", target_a, 0.18)
	await tween.finished

func _close_inventory_if_open() -> void:
	if _inventory != null and _inventory.has_method("close"):
		_inventory.close()
	if forge_ui != null and forge_ui.has_method("close"):
		forge_ui.close()

func _on_stage_portal_requested() -> void:
	_do_stage_portal.call_deferred()

func _do_stage_portal() -> void:
	if _transitioning:
		return
	_transitioning = true
	_close_inventory_if_open()
	await _fade(1.0)
	if GameManager.advance_stage():
		_load_room("")
		await get_tree().process_frame
		await _fade(0.0)
		_transitioning = false
	else:
		await _play_final_ending_story()
		get_tree().change_scene_to_file("res://scenes/Result.tscn")

func _on_victory_requested() -> void:
	_close_inventory_if_open()
	GameManager.finalize_victory()
	get_tree().change_scene_to_file("res://scenes/Result.tscn")

func _on_player_died() -> void:
	_close_inventory_if_open()
	GameManager.finalize_run()
	get_tree().change_scene_to_file("res://scenes/Result.tscn")

func _on_inventory_item_dropped(item_id: String) -> void:
	if is_instance_valid(_room) and _room.has_method("drop_inventory_item_on_floor"):
		_room.drop_inventory_item_on_floor(item_id, player.global_position)

func _on_boss_intro_requested(boss_position: Vector2, speaker: String, line: String) -> void:
	_play_boss_intro.call_deferred(boss_position, speaker, line)

func _on_boss_cinematic_requested(target_position: Vector2, hold_time: float, zoom: float) -> void:
	_play_boss_cinematic.call_deferred(target_position, hold_time, zoom)

func _play_boss_intro(boss_position: Vector2, speaker: String, line: String) -> void:
	if _boss_intro_running:
		return
	_boss_intro_running = true
	_close_inventory_if_open()
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var original_zoom := Vector2(1.6, 1.6)
	var original_position := Vector2.ZERO
	var original_smoothing := true
	if camera != null:
		original_zoom = camera.zoom
		original_position = camera.position
		original_smoothing = camera.position_smoothing_enabled
		camera.position_smoothing_enabled = false
		var target_local: Vector2 = player.to_local(boss_position)
		var tween := create_tween()
		tween.tween_property(camera, "position", target_local, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(camera, "zoom", Vector2(2.35, 2.35), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tween.finished

	GameManager.subtitle_requested.emit(speaker, line)
	await get_tree().create_timer(2.35).timeout

	if camera != null:
		var restore := create_tween()
		restore.tween_property(camera, "position", original_position, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		restore.parallel().tween_property(camera, "zoom", original_zoom, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await restore.finished
		camera.position_smoothing_enabled = original_smoothing

	if is_instance_valid(_room) and _room.has_method("finish_boss_intro"):
		_room.finish_boss_intro()
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_boss_intro_running = false

func _play_boss_cinematic(target_position: Vector2, hold_time: float, zoom: float) -> void:
	if _boss_cinematic_running:
		return
	_boss_cinematic_running = true
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var original_zoom := Vector2(1.6, 1.6)
	var original_position := Vector2.ZERO
	var original_smoothing := true
	if camera != null:
		original_zoom = camera.zoom
		original_position = camera.position
		original_smoothing = camera.position_smoothing_enabled
		camera.position_smoothing_enabled = false
		var target_local: Vector2 = player.to_local(target_position)
		var tween := create_tween()
		tween.tween_property(camera, "position", target_local, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(camera, "zoom", Vector2(zoom, zoom), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tween.finished

	await get_tree().create_timer(maxf(0.15, hold_time)).timeout

	if camera != null:
		var restore := create_tween()
		restore.tween_property(camera, "position", original_position, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		restore.parallel().tween_property(camera, "zoom", original_zoom, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await restore.finished
		camera.position_smoothing_enabled = original_smoothing

	if player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_boss_cinematic_running = false

func _play_final_ending_story() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 80
	add_child(overlay)

	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.add_child(black)

	var label := Label.new()
	label.text = GameManager.ending_line()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 80.0
	label.offset_right = -80.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.0
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	overlay.add_child(label)

	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.45)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.75).set_delay(0.20)
	tween.tween_interval(1.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	await tween.finished
	overlay.queue_free()
