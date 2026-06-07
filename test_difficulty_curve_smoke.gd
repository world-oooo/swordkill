extends SceneTree

func _initialize() -> void:
	var wood: Dictionary = WeaponDB.get_weapon("wood")
	if int(wood.get("damage", 0)) < 2:
		push_error("Wooden Sword must be forgiving enough for stage 1 enemies")
		quit(1)
		return
	if float(wood.get("range", 0.0)) < 95.0:
		push_error("Wooden Sword range must support beginner melee spacing")
		quit(1)
		return

	GameManager.start_new_run()
	var combat_room: Dictionary = {"type": "combat", "config": {}}
	GameManager._assign_config(combat_room, 3)
	var cfg: Dictionary = combat_room.get("config", {})
	if int(cfg.get("enemy_count", 99)) > 4:
		push_error("Stage 1 combat rooms should not overwhelm the Wooden Sword")
		quit(1)
		return
	if int(cfg.get("hp_bonus", 99)) != 0:
		push_error("Stage 1 combat enemies should not receive hp bonus")
		quit(1)
		return
	if float(cfg.get("ranged_ratio", 1.0)) != 0.0:
		push_error("Stage 1 combat rooms should introduce no ranged enemies")
		quit(1)
		return

	var boss_scene: PackedScene = load("res://scenes/enemies/Boss.tscn")
	var boss: Node = boss_scene.instantiate()
	root.add_child(boss)
	boss.setup(1)
	if int(boss.max_hp) > 45 or int(boss.contact_damage) > 1 or int(boss.burst_count) > 10:
		push_error("Stage 1 boss must be tuned for Wooden Sword progression")
		quit(1)
		return
	boss.setup(5)
	if int(boss.max_hp) < 130 or int(boss.burst_count) < 18:
		push_error("Late-stage boss difficulty should still scale upward")
		quit(1)
		return

	print("difficulty curve smoke ok")
	quit(0)
