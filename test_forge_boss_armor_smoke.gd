extends SceneTree

func _initialize() -> void:
	var fire_key: String = WeaponDB.evolved_key("wood", WeaponDB.ELEMENT_FIRE)
	var fire_cfg: Dictionary = WeaponDB.get_weapon(fire_key)
	if str(fire_cfg.get("elemental_effect", "")) != "fire_burst":
		push_error("Fire evolution must create a fire burst sword")
		quit(1)
		return

	var armor_a: Dictionary = GameManager.get_armor_stats("armor:leather_cap:100")
	var armor_b: Dictionary = GameManager.get_armor_stats("armor:leather_cap:101")
	if armor_a.is_empty() or armor_b.is_empty():
		push_error("Armor instance stats must resolve from armor item ids")
		quit(1)
		return
	if float(armor_a.get("damage_mult", 1.0)) == float(armor_b.get("damage_mult", 1.0)) and float(armor_a.get("attack_rate_mult", 1.0)) == float(armor_b.get("attack_rate_mult", 1.0)) and float(armor_a.get("speed_mult", 1.0)) == float(armor_b.get("speed_mult", 1.0)):
		push_error("Same armor type should vary slightly per item instance")
		quit(1)
		return

	GameManager.start_new_run()
	var room_scene: PackedScene = load("res://scenes/rooms/Room.tscn")
	var room: Node = room_scene.instantiate()
	root.add_child(room)
	await process_frame

	var intro_seen: bool = false
	room.boss_intro_requested.connect(func(_pos: Vector2, speaker: String, line: String) -> void:
		intro_seen = speaker != "" and line != ""
	)
	room.setup({"id": 777, "type": "boss", "doors": {}, "cleared": false, "config": {}}, GameManager.biome())
	await process_frame
	room._start_combat()
	await process_frame

	if not intro_seen:
		push_error("Boss room must request a cinematic boss intro")
		quit(1)
		return

	var boss: Node = null
	for child in room.get_node("Content").get_children():
		if child.is_in_group("enemies"):
			boss = child
			break
	if boss == null:
		push_error("Boss room must spawn a boss enemy")
		quit(1)
		return
	if boss.is_physics_processing():
		push_error("Boss must stay frozen during intro")
		quit(1)
		return
	room.finish_boss_intro()
	if not boss.is_physics_processing():
		push_error("Boss must resume after intro")
		quit(1)
		return

	print("forge boss armor smoke ok")
	quit(0)
