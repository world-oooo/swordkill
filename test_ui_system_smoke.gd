extends SceneTree

func _initialize() -> void:
	var intro_scene: PackedScene = load("res://scenes/Intro.tscn")
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	var inventory_scene: PackedScene = load("res://scenes/Inventory.tscn")
	if intro_scene == null or hud_scene == null or inventory_scene == null:
		push_error("Intro, HUD, and Inventory scenes must all load")
		quit(1)
		return

	var intro: Node = intro_scene.instantiate()
	root.add_child(intro)
	await process_frame
	for node_path in ["Background", "StoryText", "SkipButton"]:
		if intro.get_node_or_null(node_path) == null:
			push_error("Intro missing node: %s" % node_path)
			quit(1)
			return
	var story_label: Label = intro.get_node("StoryText")
	if story_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		push_error("Intro story text must be horizontally centered")
		quit(1)
		return
	intro.queue_free()

	var hud: Node = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	for node_path in [
		"TopLeft/Stats/HPRow/HPBar",
		"TopLeft/Stats/ShieldRow/SHBar",
		"TopLeft/Stats/EnergyRow/ENBar",
		"TopLeft/Stats/WeaponLabel",
		"TopRight/ResourceRow/CoinBox/Value",
		"TopRight/ResourceRow/GemBox/Value",
		"TopRight/MinimapFrame/Minimap",
		"TopCenter/BossPanel/BossBar",
		"TopCenter/ComboPanel/ComboStack/ComboLabel",
		"BottomRight/SkillButton",
		"DamageFlash",
	]:
		if hud.get_node_or_null(node_path) == null:
			push_error("HUD missing node: %s" % node_path)
			quit(1)
			return

	if not hud.get_node("TopLeft/Stats/HPRow/HPBar") is TextureProgressBar:
		push_error("HUD HPBar must be TextureProgressBar")
		quit(1)
		return

	var map_frame: TextureRect = hud.get_node("TopRight/MinimapFrame")
	if not map_frame.ignore_texture_size:
		push_error("MinimapFrame must ignore source texture size")
		quit(1)
		return
	if map_frame.size.x > 200.0 or map_frame.size.y > 200.0:
		push_error("MinimapFrame must stay compact and not spill off-screen")
		quit(1)
		return

	var skill_icon: TextureRect = hud.get_node("BottomRight/SkillButton")
	if skill_icon.texture == null or skill_icon.texture.resource_path.find("skill_fast_slash_icon.png") == -1:
		push_error("HUD skill icon must use the fast slash AI icon")
		quit(1)
		return
	var skill_label: Label = hud.get_node("BottomRight/SkillLabel")
	if skill_label.text != "빠르게 베기":
		push_error("HUD skill label must be 빠르게 베기")
		quit(1)
		return

	GameManager.start_new_run()
	if GameManager.visited_rooms.size() != 1 or not GameManager.is_visited(GameManager.current_id):
		push_error("Minimap must initially reveal only the current start room")
		quit(1)
		return
	var first_room: Dictionary = GameManager.current_room()
	var first_dir: String = str(first_room.get("doors", {}).keys()[0])
	GameManager.move_through(first_dir)
	if GameManager.visited_rooms.size() != 2 or not GameManager.is_visited(GameManager.current_id):
		push_error("Minimap must keep entered rooms visible and hide unvisited rooms")
		quit(1)
		return
	hud.queue_free()

	var inventory: Node = inventory_scene.instantiate()
	root.add_child(inventory)
	await process_frame
	for node_path in [
		"Panel/Margin/Root/Body/Left/EquipmentSlots",
		"Panel/Margin/Root/Body/Right/ItemGrid",
	]:
		if inventory.get_node_or_null(node_path) == null:
			push_error("Inventory missing node: %s" % node_path)
			quit(1)
			return

	var item_grid: GridContainer = inventory.get_node("Panel/Margin/Root/Body/Right/ItemGrid")
	if item_grid.columns != 6:
		push_error("Inventory item grid must have 6 columns")
		quit(1)
		return

	var equipment: VBoxContainer = inventory.get_node("Panel/Margin/Root/Body/Left/EquipmentSlots")
	if equipment.get_child_count() != 4:
		push_error("Inventory must build four equipment slots")
		quit(1)
		return

	print("ui system smoke ok")
	quit(0)
