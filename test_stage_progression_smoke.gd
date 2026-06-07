extends SceneTree

func _initialize() -> void:
	GameManager.start_new_run()
	if GameManager.floor != 1 or GameManager.reached_stage != 1:
		push_error("Run must start at stage 1")
		quit(1)
		return
	if GameManager.inventory != ["wood"] or GameManager.equipped != "wood":
		push_error("Run must start with only the wooden sword")
		quit(1)
		return
	if GameManager.rooms.size() < 4 or GameManager.rooms.size() > 7:
		push_error("Stage room count must be randomized between 4 and 7")
		quit(1)
		return

	var reward: String = GameManager.boss_reward_weapon()
	if not GameManager.claim_weapon_reward(reward):
		push_error("Boss reward sword must be claimable")
		quit(1)
		return
	if reward not in GameManager.inventory or GameManager.equipped != reward:
		push_error("Boss reward sword must be claimable and equipped")
		quit(1)
		return

	var armor_key: String = GameManager.open_stage_chest()
	if armor_key == "" or not GameManager.ARMORS.has(armor_key):
		push_error("Stage chest must grant armor")
		quit(1)
		return
	var found_armor: bool = false
	for item in GameManager.inventory:
		if GameManager.is_armor_item(str(item)) and GameManager.armor_key_from_item(str(item)) == armor_key:
			found_armor = true
			break
	if not found_armor:
		push_error("Stage chest armor must be stored in inventory")
		quit(1)
		return

	if GameManager.drop_inventory_item("wood"):
		push_error("Wooden Sword must never be droppable")
		quit(1)
		return

	if not GameManager.advance_stage():
		push_error("Stage 1 portal must advance to stage 2")
		quit(1)
		return
	if GameManager.floor != 2 or GameManager.reached_stage != 2:
		push_error("Stage progression did not update floor/reached stage")
		quit(1)
		return
	if GameManager.rooms.size() < 4 or GameManager.rooms.size() > 7:
		push_error("Next stage room count must also be 4-7")
		quit(1)
		return

	print("stage progression smoke ok")
	quit(0)
