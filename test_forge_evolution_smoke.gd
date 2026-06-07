extends SceneTree

func _initialize() -> void:
	GameManager.start_new_run()
	if not GameManager.is_test_mode:
		push_error("Forge should now start in free upgrade mode")
		quit(1)
		return
	GameManager.inventory.append("steel")

	if not WeaponDB.has_method("evolved_key"):
		push_error("WeaponDB must expose evolved_key(base, element)")
		quit(1)
		return

	if not GameManager.has_method("get_evolution_cost") or not GameManager.has_method("evolve_equipped"):
		push_error("GameManager must expose forge evolution API")
		quit(1)
		return

	var free_cost: int = GameManager.get_evolution_cost("lightning")
	if free_cost != 0:
		push_error("Test mode must force forge evolution cost to 0")
		quit(1)
		return

	var result: Dictionary = GameManager.evolve_equipped("lightning")
	if not bool(result.get("ok", false)):
		push_error("Equipped Wooden Sword should evolve for free in test mode")
		quit(1)
		return

	if GameManager.equipped != "wood_lightning":
		push_error("Equipped weapon must transform into the elemental evolved key")
		quit(1)
		return

	if "steel" not in GameManager.inventory:
		push_error("Forge must not mutate standby inventory weapons")
		quit(1)
		return

	if "wood_lightning" not in GameManager.inventory or "wood" in GameManager.inventory:
		push_error("Forge must replace only the equipped inventory slot")
		quit(1)
		return

	var fire_cost: int = GameManager.get_evolution_cost(WeaponDB.ELEMENT_FIRE, "wood")
	var water_cost: int = GameManager.get_evolution_cost(WeaponDB.ELEMENT_WATER, "wood")
	if fire_cost != 0 or water_cost != 0:
		push_error("All forge evolution paths should be free")
		quit(1)
		return

	var forge_scene: PackedScene = load("res://scenes/ui/ForgeUI.tscn")
	if forge_scene == null:
		push_error("ForgeUI.tscn must load")
		quit(1)
		return
	var forge: Node = forge_scene.instantiate()
	root.add_child(forge)
	await process_frame

	for node_path in [
		"Panel/Margin/Root/Header",
		"Panel/Margin/Root/EquippedPanel/EquippedName",
		"Panel/Margin/Root/PathRow/LightningButton",
		"Panel/Margin/Root/PathRow/WaterButton",
		"Panel/Margin/Root/PathRow/FireButton",
		"Panel/Margin/Root/CostLabel",
	]:
		if forge.get_node_or_null(node_path) == null:
			push_error("ForgeUI missing node: %s" % node_path)
			quit(1)
			return

	print("forge evolution smoke ok")
	quit(0)
