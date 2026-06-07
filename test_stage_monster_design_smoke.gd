extends SceneTree

func _initialize() -> void:
	var expected_pools: Dictionary = {
		1: ["orc", "wolf"],
		2: ["zombie", "skeleton_soldier"],
		3: ["slime", "ghost"],
		4: ["stone_statue", "flame_imp"],
	}
	for stage in expected_pools.keys():
		var pool: Array[String] = GameManager.enemy_pool_for_stage(int(stage))
		if pool != expected_pools[stage]:
			push_error("Stage %d enemy pool mismatch: %s" % [stage, str(pool)])
			quit(1)
			return

	if "skeleton_soldier" in GameManager.enemy_pool_for_stage(4):
		push_error("Stage 4 must not spawn skeleton soldiers")
		quit(1)
		return

	var required_enemy_keys: Array[String] = [
		"orc",
		"wolf",
		"zombie",
		"skeleton_soldier",
		"slime",
		"ghost",
		"stone_statue",
		"flame_imp",
	]
	for key in required_enemy_keys:
		var enemy_cfg: Dictionary = GameManager.enemy_config_for_key(key)
		var texture_path: String = str(enemy_cfg.get("texture", ""))
		if texture_path == "" or not ResourceLoader.exists(texture_path):
			push_error("Enemy texture missing for %s: %s" % [key, texture_path])
			quit(1)
			return
		if int(enemy_cfg.get("hframes", 0)) != 4 or int(enemy_cfg.get("vframes", 0)) != 1:
			push_error("Enemy %s must use a processed 4x1 sprite sheet, got %sx%s" % [key, str(enemy_cfg.get("hframes", "")), str(enemy_cfg.get("vframes", ""))])
			quit(1)
			return

	var boss_names: Dictionary = {
		1: "오크킹",
		2: "레이븐",
		3: "늪지대 마녀",
		4: "화염룡",
		5: "어둠의 군주",
	}
	for stage in boss_names.keys():
		var cfg: Dictionary = GameManager.boss_config_for_stage(int(stage))
		if str(cfg.get("name", "")) != str(boss_names[stage]):
			push_error("Stage %d boss name mismatch: %s" % [stage, str(cfg.get("name", ""))])
			quit(1)
			return
		var boss_texture_path: String = str(cfg.get("texture", ""))
		if boss_texture_path == "" or not ResourceLoader.exists(boss_texture_path):
			push_error("Boss texture missing for stage %d: %s" % [stage, boss_texture_path])
			quit(1)
			return
		if int(cfg.get("hframes", 0)) != 4 or int(cfg.get("vframes", 0)) != 1:
			push_error("Boss stage %d must use a processed 4x1 sprite sheet, got %sx%s" % [stage, str(cfg.get("hframes", "")), str(cfg.get("vframes", ""))])
			quit(1)
			return
		var bg_path: String = GameManager.stage_background_path(int(stage))
		if bg_path == "" or not ResourceLoader.exists(bg_path):
			push_error("Stage background missing for stage %d: %s" % [stage, bg_path])
			quit(1)
			return

	GameManager.floor = 5
	GameManager._generate_map()
	if GameManager.rooms.size() != 2:
		push_error("Final stage must contain only a start room and the final boss room")
		quit(1)
		return
	if str(GameManager.rooms[0].get("type", "")) != "start" or str(GameManager.rooms[1].get("type", "")) != "boss":
		push_error("Final stage room types must be start -> boss")
		quit(1)
		return
	if int(GameManager.rooms[0]["doors"].get("E", -1)) != 1 or int(GameManager.rooms[1]["doors"].get("W", -1)) != 0:
		push_error("Final stage must connect start room to boss room in one direction")
		quit(1)
		return

	var final_cfg: Dictionary = GameManager.boss_config_for_stage(5)
	var phases: Array = final_cfg.get("phases", [])
	if phases.size() < 3:
		push_error("Final boss must have multiple phase thresholds")
		quit(1)
		return

	var boss_scene: PackedScene = load("res://scenes/enemies/Boss.tscn")
	var boss: Node = boss_scene.instantiate()
	boss.setup(5, final_cfg)
	root.add_child(boss)
	await process_frame
	if not GameManager.boss_phase_hint.contains("다음 변신"):
		push_error("Boss phase hint must explain the next transformation")
		quit(1)
		return
	boss.take_damage(int(ceil(float(boss.max_hp) * 0.31)))
	await process_frame
	if not GameManager.boss_phase_hint.contains("심연의 갑주"):
		push_error("Boss phase hint must advance after the first phase change")
		quit(1)
		return

	print("stage monster design smoke ok")
	quit(0)
