extends SceneTree

func _initialize() -> void:
	var intro_scene: PackedScene = load("res://scenes/Intro.tscn")
	if intro_scene == null:
		push_error("Intro scene must load")
		quit(1)
		return

	var intro: Node = intro_scene.instantiate()
	root.add_child(intro)
	await process_frame

	if not intro.has_method("_show_controls_screen"):
		push_error("Intro must expose controls screen flow")
		quit(1)
		return

	intro._show_controls_screen()
	await process_frame
	var story_label: Label = intro.get_node("StoryText")
	if story_label.text.find("조작법") == -1 or story_label.text.find("아무 키나 누르세요") == -1:
		push_error("Skipping intro must still show controls and press-any-key prompt")
		quit(1)
		return
	if not bool(intro.get("_waiting_for_controls_input")):
		push_error("Controls screen must wait for player input instead of auto-starting")
		quit(1)
		return

	var lines: Array = intro.get("STORY_LINES")
	if str(lines[lines.size() - 1]).ends_with("...") == false:
		push_error("Final story line must end with ellipsis")
		quit(1)
		return

	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	intro._input(event)
	if bool(intro.get("_waiting_for_controls_input")):
		push_error("Controls input should stop waiting and defer scene transition")
		quit(1)
		return

	print("intro controls smoke ok")
	quit(0)
