extends SceneTree

func _initialize() -> void:
	var player_scene: PackedScene = load("res://scenes/player/Player.tscn")
	var inventory_scene: PackedScene = load("res://scenes/Inventory.tscn")
	if player_scene == null or inventory_scene == null:
		push_error("Player and Inventory scenes must load")
		quit(1)
		return

	var player: Node = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	if not player.y_sort_enabled:
		push_error("Player root must have y_sort_enabled for stable top-down layering")
		quit(1)
		return

	if not player.has_method("_update_weapon_draw_order"):
		push_error("Player must expose _update_weapon_draw_order")
		quit(1)
		return

	player._update_weapon_draw_order(Vector2.LEFT)
	if player.get_node("WeaponMount").z_index >= player.get_node("Body").z_index:
		push_error("Left-facing weapon must use the requested behind-parent/back z-order")
		quit(1)
		return

	player._update_weapon_draw_order(Vector2.UP)
	if player.get_node("WeaponMount").z_index >= player.get_node("Body").z_index:
		push_error("Up-facing weapon must render behind body")
		quit(1)
		return

	player._update_weapon_draw_order(Vector2.RIGHT)
	if player.get_node("WeaponMount").z_index <= player.get_node("Body").z_index:
		push_error("Right-facing weapon must render in front of body")
		quit(1)
		return

	player._update_weapon_draw_order(Vector2.DOWN)
	if player.get_node("WeaponMount").z_index <= player.get_node("Body").z_index:
		push_error("Down-facing weapon must render in front of body")
		quit(1)
		return

	var inventory: Node = inventory_scene.instantiate()
	root.add_child(inventory)
	GameManager.start_new_run()
	await process_frame

	for node_path in [
		"Panel/Margin/Root/Body/Left/EquipmentSlots",
		"Panel/Margin/Root/Body/Right/ItemGrid",
		"Panel/Margin/Root/DetailPanel/DetailBody/Icon",
		"Panel/Margin/Root/DetailPanel/DetailBody/Text/NameLabel",
		"Panel/Margin/Root/DetailPanel/DetailBody/Text/StatsLabel",
		"Panel/Margin/Root/DetailPanel/DetailBody/Text/DescriptionLabel",
	]:
		if inventory.get_node_or_null(node_path) == null:
			push_error("Inventory missing node: %s" % node_path)
			quit(1)
			return

	if not inventory.has_method("_show_item_detail"):
		push_error("Inventory must expose detail panel update method")
		quit(1)
		return

	inventory._show_item_detail("steel")
	var equipment: VBoxContainer = inventory.get_node("Panel/Margin/Root/Body/Left/EquipmentSlots")
	for slot in equipment.get_children():
		if slot.custom_minimum_size.x < 120.0 or slot.custom_minimum_size.y < 100.0:
			push_error("Equipment slots must be large, Minecraft-style armor slots")
			quit(1)
			return

	var detail_panel: Panel = inventory.get_node("Panel/Margin/Root/DetailPanel")
	if detail_panel.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("DetailPanel must span the bottom of the inventory")
		quit(1)
		return

	var name_label: Label = inventory.get_node("Panel/Margin/Root/DetailPanel/DetailBody/Text/NameLabel")
	if name_label.text.find("Lv.") == -1 or name_label.text.find(WeaponDB.display_name("steel")) == -1:
		push_error("Inventory detail panel must show sword level and name")
		quit(1)
		return

	var icon: TextureRect = inventory.get_node("Panel/Margin/Root/DetailPanel/DetailBody/Icon")
	if icon.texture == null:
		push_error("Inventory detail panel must show selected item icon")
		quit(1)
		return

	var item_grid: GridContainer = inventory.get_node("Panel/Margin/Root/Body/Right/ItemGrid")
	inventory._relayout_grid()
	var grid_size_before: Vector2 = item_grid.size
	for i in range(5):
		inventory._rebuild_items()
		await process_frame
		inventory._relayout_grid()
	if item_grid.size.distance_to(grid_size_before) > 1.0:
		push_error("Inventory grid must not grow when equipment/items are clicked repeatedly")
		quit(1)
		return

	print("ui refinement smoke ok")
	quit(0)
