extends SceneTree

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.start_new_run()

	if gm.rooms.size() != 8:
		push_error("Expected exactly 8 generated rooms")
		quit(1)
		return

	var required_types := {
		"start": false,
		"combat": false,
		"elite": false,
		"treasure": false,
		"shop": false,
		"boss": false,
	}
	for id in gm.rooms.keys():
		var room_type: String = gm.rooms[id].get("type", "")
		if required_types.has(room_type):
			required_types[room_type] = true

	for room_type in required_types.keys():
		if not required_types[room_type]:
			push_error("Missing generated room type: %s" % room_type)
			quit(1)
			return

	if WeaponDB.ORDER.size() != 6:
		push_error("Expected exactly 6 sword evolution entries")
		quit(1)
		return

	if gm.inventory != WeaponDB.ORDER:
		push_error("Player should start with all 6 prototype swords in inventory")
		quit(1)
		return

	if gm.equipped != "wood":
		push_error("Wooden Sword should be equipped at run start")
		quit(1)
		return

	print("design spec smoke ok")
	quit(0)
