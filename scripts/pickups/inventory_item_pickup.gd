extends Area2D
## Dropped sword/armor pickup.
##
## Inventory "drop" creates this object on the current room floor. It stays in
## the room save data and can be picked up again with G.

var item_id: String = ""

var _player_inside: bool = false
var _sprite: Sprite2D
var _label: Label
var _bob_t: float = 0.0

func setup(p_item_id: String) -> void:
	item_id = p_item_id
	if is_inside_tree():
		_build_visual()

func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		shape.shape = circle
		add_child(shape)
	_build_visual()

func _process(delta: float) -> void:
	_bob_t += delta
	if _sprite != null:
		_sprite.position.y = sin(_bob_t * 5.0) * 2.0

func _input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if GameManager.add_inventory_item(item_id):
			queue_free()
		get_viewport().set_input_as_handled()

func save_data() -> Dictionary:
	return {"kind": "inventory_item", "pos": position, "item_id": item_id}

func _build_visual() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.z_index = 4
		add_child(_sprite)
	if _label == null:
		_label = Label.new()
		_label.name = "Prompt"
		_label.position = Vector2(-58, -56)
		_label.size = Vector2(116, 24)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.visible = false
		_label.add_theme_font_size_override("font_size", 14)
		_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		_label.add_theme_constant_override("shadow_offset_x", 2)
		_label.add_theme_constant_override("shadow_offset_y", 2)
		add_child(_label)

	_sprite.texture = _item_texture()
	_sprite.rotation_degrees = -90.0 if GameManager.is_weapon_item(item_id) else 0.0
	_sprite.scale = Vector2.ONE
	if _sprite.texture != null:
		var target_size := Vector2(54, 54) if GameManager.is_weapon_item(item_id) else Vector2(48, 48)
		var texture_size: Vector2 = _sprite.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			_sprite.scale = Vector2.ONE * minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	_label.text = "G: %s" % _item_name()

func _item_texture() -> Texture2D:
	if GameManager.is_weapon_item(item_id):
		var weapon_path: String = str(WeaponDB.get_weapon(item_id).get("texture", ""))
		return load(weapon_path) if weapon_path != "" else null
	if GameManager.is_armor_item(item_id):
		var armor_key: String = GameManager.armor_key_from_item(item_id)
		var armor_path: String = str(GameManager.ARMORS.get(armor_key, {}).get("texture", ""))
		return load(armor_path) if armor_path != "" else null
	return null

func _item_name() -> String:
	if GameManager.is_weapon_item(item_id):
		return WeaponDB.display_name(item_id)
	if GameManager.is_armor_item(item_id):
		var armor_key: String = GameManager.armor_key_from_item(item_id)
		return str(GameManager.ARMORS.get(armor_key, {}).get("name", "방어구"))
	return "아이템"

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if _label != null:
			_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if _label != null:
			_label.visible = false
