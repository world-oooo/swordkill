extends SceneTree

func _initialize() -> void:
	var door_scene: PackedScene = load("res://scenes/rooms/Door.tscn")
	if door_scene == null:
		push_error("Door.tscn must exist")
		quit(1)
		return

	var door: Node = door_scene.instantiate()
	root.add_child(door)
	door.setup("E", Vector2(560, 0), Vector2(60, 150))
	await process_frame

	if not door.has_method("set_locked"):
		push_error("Door must expose set_locked")
		quit(1)
		return

	door.set_locked(true)
	await process_frame
	if not door.is_locked():
		push_error("Door did not enter locked state")
		quit(1)
		return
	if not door.get_node("Gate/GateCollision").disabled == false:
		push_error("Locked door must enable StaticBody2D collision")
		quit(1)
		return

	door.set_locked(false)
	await process_frame
	if door.is_locked():
		push_error("Door did not leave locked state")
		quit(1)
		return
	if not door.get_node("Gate/GateCollision").disabled:
		push_error("Unlocked door must disable StaticBody2D collision")
		quit(1)
		return

	var moved_dir: String = ""
	door.exit_requested.connect(func(dir: String) -> void:
		moved_dir = dir
	)

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(player)
	door._on_trigger_body_entered(player)

	if moved_dir != "E":
		push_error("Unlocked door should emit exit_requested with its direction")
		quit(1)
		return

	print("room door system ok")
	quit(0)
