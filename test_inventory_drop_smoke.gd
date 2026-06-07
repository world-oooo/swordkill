extends SceneTree

func _initialize() -> void:
	GameManager.start_new_run()
	var room_scene: PackedScene = load("res://scenes/rooms/Room.tscn")
	if room_scene == null:
		push_error("Room scene must load")
		quit(1)
		return

	var room: Node = room_scene.instantiate()
	root.add_child(room)
	await process_frame
	room.setup({"id": 999, "type": "start", "doors": {}, "cleared": true, "config": {}}, GameManager.biome())
	await process_frame

	room.drop_inventory_item_on_floor("steel", Vector2.ZERO)
	room.drop_inventory_item_on_floor(GameManager.armor_item_id("leather_cap"), Vector2.ZERO)
	await process_frame

	var drops: Array[Dictionary] = []
	for child in room.get_node("Content").get_children():
		if child.has_method("save_data"):
			var data: Dictionary = child.save_data()
			if str(data.get("kind", "")) == "inventory_item":
				drops.append(data)

	if drops.size() != 2:
		push_error("Dropping two inventory items must create two floor pickups")
		quit(1)
		return
	if str(drops[0].get("item_id", "")) != "steel" or str(drops[1].get("item_id", "")) != GameManager.armor_item_id("leather_cap"):
		push_error("Dropped floor pickups must preserve item ids")
		quit(1)
		return

	var first_pos: Vector2 = drops[0].get("pos", Vector2.ZERO)
	var second_pos: Vector2 = drops[1].get("pos", Vector2.ZERO)
	if absf(first_pos.x - second_pos.x) < 24.0:
		push_error("Multiple dropped items must be laid out next to each other")
		quit(1)
		return

	print("inventory drop smoke ok")
	quit(0)
