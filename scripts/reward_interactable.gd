extends Area2D
## Boss clear reward object.
##
## mode:
## - "chest": G opens the reward chest and stores a random armor piece.
## - "weapon": G claims the stage sword reward.
## - "portal": Q advances to the next stage or finishes the run.

signal portal_requested

var mode: String = "chest"
var reward_key: String = ""
var _player_inside: bool = false
var _used: bool = false

var _sprite: Sprite2D
var _label: Label

func setup(p_mode: String, p_key: String, texture: Texture2D, label_text: String) -> void:
	mode = p_mode
	reward_key = p_key
	_build(texture, label_text)

func _ready() -> void:
	add_to_group("room_persistent")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 44.0
		shape.shape = circle
		add_child(shape)

func _input(event: InputEvent) -> void:
	if _used or not _player_inside:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	if (mode == "portal" and key_event.keycode == KEY_Q) or (mode != "portal" and key_event.keycode == KEY_G):
		_activate()
		get_viewport().set_input_as_handled()

func _build(texture: Texture2D, label_text: String) -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 5
	if texture != null:
		var target := Vector2(72, 72) if mode != "portal" else Vector2(86, 86)
		var ts: Vector2 = texture.get_size()
		_sprite.scale = Vector2.ONE * minf(target.x / ts.x, target.y / ts.y)
	add_child(_sprite)

	_label = Label.new()
	_label.name = "Label"
	_label.text = label_text
	_label.position = Vector2(-90, -72)
	_label.size = Vector2(180, 28)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)

func _activate() -> void:
	match mode:
		"chest":
			var armor_key: String = GameManager.open_stage_chest()
			if armor_key == "":
				_label.text = "인벤토리가 가득 찼습니다"
				return
			var cfg: Dictionary = GameManager.ARMORS.get(armor_key, {})
			_label.text = "획득: %s" % cfg.get("name", "장비")
			_used = true
			_pop_and_fade()
		"weapon":
			if not GameManager.claim_weapon_reward(reward_key):
				_label.text = "인벤토리가 가득 찼습니다"
				return
			_label.text = "검 획득: %s" % WeaponDB.display_name(reward_key)
			_used = true
			_pop_and_fade()
		"portal":
			portal_requested.emit()

func save_data() -> Dictionary:
	if _used:
		return {}
	return {
		"kind": "reward",
		"mode": mode,
		"reward_key": reward_key,
		"pos": position,
	}

func _pop_and_fade() -> void:
	collision_mask = 0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.16)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.35)
	tween.chain().tween_callback(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
