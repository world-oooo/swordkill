extends SceneTree

func _initialize() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.start_new_run()
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var destructibles: Array = get_nodes_in_group("destructibles")
	if destructibles.is_empty():
		push_error("No destructible obstacles spawned")
		quit(1)
		return
	var target: Node = destructibles[0]
	if not target.has_method("take_damage"):
		push_error("Obstacle has no take_damage")
		quit(1)
		return
	target.take_damage(1, 0.0)
	await process_frame
	print("obstacle smoke ok count=", destructibles.size(), " first_kind=", target.kind)
	quit(0)
