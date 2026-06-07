extends SceneTree

func _initialize() -> void:
	GameManager.start_new_run()
	GameManager.floor = GameManager.MAX_STAGE
	GameManager.reached_stage = GameManager.MAX_STAGE
	GameManager.inventory = ["wood", "steel", GameManager.armor_item_id("leather_cap")]
	GameManager.equipped = "wood"
	GameManager._generate_map()

	if not GameManager.has_method("prepare_final_boss_weapon"):
		push_error("GameManager must expose prepare_final_boss_weapon()")
		quit(1)
		return

	if not GameManager.prepare_final_boss_weapon():
		push_error("Final boss ritual must transform the wooden sword")
		quit(1)
		return

	if GameManager.equipped != "radiant":
		push_error("Final boss weapon must be the sacred/radiant sword")
		quit(1)
		return

	if "wood" in GameManager.inventory or "steel" in GameManager.inventory:
		push_error("Final boss fight must remove standby weapons")
		quit(1)
		return

	if "radiant" not in GameManager.inventory:
		push_error("Final boss fight must keep the sacred sword in inventory")
		quit(1)
		return

	if not GameManager.is_final_weapon_locked():
		push_error("Sacred sword must be locked during the final boss fight")
		quit(1)
		return

	if GameManager.drop_inventory_item("radiant"):
		push_error("Sacred sword must not be droppable during the final boss fight")
		quit(1)
		return

	var final_cfg: Dictionary = GameManager.boss_config_for_stage(GameManager.MAX_STAGE)
	if not bool(final_cfg.get("final_boss", false)):
		push_error("Stage 5 boss config must be marked as final_boss")
		quit(1)
		return

	var phases: Array = final_cfg.get("phases", [])
	if phases.size() != 3:
		push_error("Final boss must expose exactly three transformation thresholds")
		quit(1)
		return

	var expected: Array[float] = [0.70, 0.40, 0.15]
	for i in range(expected.size()):
		if not is_equal_approx(float(phases[i].get("ratio", -1.0)), expected[i]):
			push_error("Final boss phase %d threshold mismatch" % i)
			quit(1)
			return

	var markers: Array = GameManager.phase_markers_from_config(final_cfg)
	if markers.size() != 3:
		push_error("Final boss health bar must expose I markers for each transformation")
		quit(1)
		return

	if str(markers[0].get("label", "")) != "I" or not is_equal_approx(float(markers[0].get("ratio", 0.0)), 0.70):
		push_error("First phase marker must be an I marker at 70%")
		quit(1)
		return

	GameManager.finalize_victory()
	if GameManager.ending_line() != "그렇게 세계를 구했다...":
		push_error("Victory ending line must match the requested story text")
		quit(1)
		return

	print("final boss scenario smoke ok")
	quit(0)
