extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/rooms/Room.tscn")

func _initialize() -> void:
	GameManager.floor = 1
	GameManager.rooms = {
		0: {
			"id": 0,
			"type": "boss",
			"cell": Vector2i.ZERO,
			"doors": {"W": 1},
			"cleared": false,
			"config": {},
		}
	}
	GameManager.current_id = 0

	var room: Node = ROOM_SCENE.instantiate()
	root.add_child(room)
	room.setup(GameManager.rooms[0], GameManager.biome())
	await process_frame
	room.force_clear()
	await process_frame

	var saved_items: Array = room.get_items_data()
	if saved_items.size() != 3:
		push_error("Boss reward room must save chest, sword, and portal. Saved: %s" % str(saved_items))
		quit(1)
		return

	var modes: Array[String] = []
	for item in saved_items:
		modes.append(str(item.get("mode", "")))
	modes.sort()
	if modes != ["chest", "portal", "weapon"]:
		push_error("Saved reward modes mismatch: %s" % str(modes))
		quit(1)
		return

	GameManager.rooms[0]["items"] = saved_items
	room.queue_free()
	await process_frame

	var restored: Node = ROOM_SCENE.instantiate()
	root.add_child(restored)
	restored.setup(GameManager.rooms[0], GameManager.biome())
	await process_frame

	var restored_items: Array = restored.get_items_data()
	if restored_items.size() != 3:
		push_error("Restored room lost rewards. Restored: %s" % str(restored_items))
		quit(1)
		return

	print("room reward persistence smoke ok")
	quit(0)
