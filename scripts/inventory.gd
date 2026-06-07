extends CanvasLayer
## Fullscreen medieval inventory.
##
## Tab opens/closes this paused overlay. The right grid stores both swords and
## armor pieces. Selecting an item updates the bottom detail box, then the
## action buttons can equip, unequip, or drop it. The Wooden Sword is protected
## so the player can never lose the starting weapon.

const UI_DIR: String = "res://assets/ui/generated/"
const FANTASY_FONT: Font = preload("res://assets/fonts/oldengl.ttf")
const EQUIPMENT_SLOTS: Array[String] = ["helmet", "armor", "gloves", "boots"]
const EQUIPMENT_LABELS: Dictionary = {
	"helmet": "투구",
	"armor": "갑옷",
	"gloves": "장갑",
	"boots": "신발",
}
const SLOT_TEXTURES: Dictionary = {
	"helmet": "slot_helmet.png",
	"armor": "slot_armor.png",
	"gloves": "slot_gloves.png",
	"boots": "slot_boots.png",
}
const ITEM_COLUMNS: int = 6
const ITEM_ROWS: int = 4
const ITEM_SLOTS: int = ITEM_COLUMNS * ITEM_ROWS
const GRID_INSET_LEFT: float = 0.055
const GRID_INSET_TOP: float = 0.115
const GRID_INSET_RIGHT: float = 0.955
const GRID_INSET_BOTTOM: float = 0.930

var panel: PanelContainer
var equipment_slots: VBoxContainer
var item_grid: GridContainer
var currency_label: Label
var detail_panel: Panel
var detail_icon: TextureRect
var detail_name: Label
var detail_stats: Label
var detail_description: Label
var equip_button: Button
var unequip_button: Button
var drop_button: Button

var _selected_item_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_inventory()
	visible = false
	GameManager.inventory_changed.connect(_rebuild_items)
	GameManager.currency_changed.connect(func(_coins: int, _gems: int) -> void:
		if visible:
			_rebuild_items()
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle()
		get_viewport().set_input_as_handled()

func close() -> void:
	visible = false
	get_tree().paused = false

func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_rebuild_items()

func _build_inventory() -> void:
	for child in get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	add_child(dim)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36
	panel.offset_top = 36
	panel.offset_right = -36
	panel.offset_bottom = -36
	panel.add_theme_stylebox_override("panel", _panel_box(Color(0.045, 0.040, 0.038, 0.96), Color(0.76, 0.52, 0.20), 14))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.name = "Title"
	title.text = "인벤토리"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_font_override("font", FANTASY_FONT)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(title)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.custom_minimum_size = Vector2(180, 0)
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)

	currency_label = Label.new()
	currency_label.name = "CurrencyLabel"
	currency_label.text = "코인 0   보석 0"
	currency_label.add_theme_font_size_override("font_size", 18)
	currency_label.add_theme_font_override("font", FANTASY_FONT)
	currency_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	left.add_child(currency_label)

	equipment_slots = VBoxContainer.new()
	equipment_slots.name = "EquipmentSlots"
	equipment_slots.add_theme_constant_override("separation", 12)
	left.add_child(equipment_slots)

	var right := Control.new()
	right.name = "Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var frame := TextureRect.new()
	frame.name = "GridFrame"
	frame.texture = _tex("inventory_grid_frame.png")
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(frame)

	item_grid = GridContainer.new()
	item_grid.name = "ItemGrid"
	item_grid.columns = ITEM_COLUMNS
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	item_grid.anchor_left = 0.0
	item_grid.anchor_top = 0.0
	item_grid.anchor_right = 0.0
	item_grid.anchor_bottom = 0.0
	item_grid.custom_minimum_size = Vector2.ZERO
	right.add_child(item_grid)
	right.resized.connect(_relayout_grid)

	_build_detail_panel(root)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Tab: 닫기   클릭: 선택/장착   G: 보상 줍기"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_font_override("font", FANTASY_FONT)
	hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	root.add_child(hint)

	_rebuild_items()

func _build_detail_panel(root: VBoxContainer) -> void:
	detail_panel = Panel.new()
	detail_panel.name = "DetailPanel"
	detail_panel.custom_minimum_size = Vector2(0, 148)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _panel_box(Color(0.070, 0.060, 0.052, 0.98), Color(0.78, 0.52, 0.20), 10))
	root.add_child(detail_panel)

	var detail_body := HBoxContainer.new()
	detail_body.name = "DetailBody"
	detail_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_body.offset_left = 16
	detail_body.offset_top = 14
	detail_body.offset_right = -16
	detail_body.offset_bottom = -14
	detail_body.add_theme_constant_override("separation", 18)
	detail_panel.add_child(detail_body)

	detail_icon = TextureRect.new()
	detail_icon.name = "Icon"
	detail_icon.custom_minimum_size = Vector2(104, 104)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_body.add_child(detail_icon)

	var text := VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	detail_body.add_child(text)

	detail_name = Label.new()
	detail_name.name = "NameLabel"
	detail_name.add_theme_font_size_override("font_size", 25)
	detail_name.add_theme_font_override("font", FANTASY_FONT)
	detail_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	detail_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	detail_name.add_theme_constant_override("shadow_offset_x", 2)
	detail_name.add_theme_constant_override("shadow_offset_y", 2)
	text.add_child(detail_name)

	detail_stats = Label.new()
	detail_stats.name = "StatsLabel"
	detail_stats.add_theme_font_size_override("font_size", 17)
	detail_stats.add_theme_font_override("font", FANTASY_FONT)
	detail_stats.add_theme_color_override("font_color", Color(0.92, 0.88, 0.76))
	text.add_child(detail_stats)

	detail_description = Label.new()
	detail_description.name = "DescriptionLabel"
	detail_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.add_theme_font_size_override("font_size", 15)
	detail_description.add_theme_font_override("font", FANTASY_FONT)
	detail_description.add_theme_color_override("font_color", Color(0.76, 0.72, 0.64))
	text.add_child(detail_description)

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.custom_minimum_size = Vector2(120, 0)
	actions.add_theme_constant_override("separation", 8)
	detail_body.add_child(actions)

	equip_button = _action_button("장착")
	equip_button.pressed.connect(_on_equip_pressed)
	actions.add_child(equip_button)

	unequip_button = _action_button("해제")
	unequip_button.pressed.connect(_on_unequip_pressed)
	actions.add_child(unequip_button)

	drop_button = _action_button("버리기")
	drop_button.pressed.connect(_on_drop_pressed)
	actions.add_child(drop_button)

func _build_equipment_slots() -> void:
	for child in equipment_slots.get_children():
		child.queue_free()
	for slot_key in EQUIPMENT_SLOTS:
		var button := Button.new()
		button.name = "%sSlot" % slot_key.capitalize()
		button.custom_minimum_size = Vector2(150, 112)
		button.text = ""
		button.add_theme_stylebox_override("normal", _slot_box(false))
		button.add_theme_stylebox_override("hover", _slot_box(true))
		button.add_theme_stylebox_override("pressed", _slot_box(true))
		equipment_slots.add_child(button)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(17, 4)
		icon.size = Vector2(116, 82)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)

		var item_id: String = str(GameManager.equipment.get(slot_key, ""))
		var key: String = GameManager.armor_key_from_item(item_id)
		if item_id != "" and GameManager.ARMORS.has(key):
			icon.texture = load(str(GameManager.ARMORS[key].get("texture", "")))
			button.tooltip_text = _armor_tooltip(item_id)
			button.pressed.connect(func() -> void:
				_select_item(item_id, false)
			)
		else:
			icon.texture = _tex(str(SLOT_TEXTURES.get(slot_key, "")))
			button.disabled = false

		var label := Label.new()
		label.text = str(EQUIPMENT_LABELS.get(slot_key, slot_key))
		label.position = Vector2(12, 84)
		label.size = Vector2(126, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_font_override("font", FANTASY_FONT)
		label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)

func _rebuild_items() -> void:
	if item_grid == null:
		return
	_build_equipment_slots()
	currency_label.text = "코인 %d   보석 %d" % [GameManager.coins, GameManager.gems]
	for child in item_grid.get_children():
		child.queue_free()
	for i in range(ITEM_SLOTS):
		if i < GameManager.inventory.size():
			item_grid.add_child(_item_button(str(GameManager.inventory[i])))
		else:
			item_grid.add_child(_empty_slot())
	_relayout_grid.call_deferred()
	if _selected_item_id == "" or _selected_item_id not in GameManager.inventory:
		_selected_item_id = GameManager.equipped if GameManager.equipped != "" else "wood"
	_select_item(_selected_item_id, false)

func _item_button(item_id: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 104)
	button.text = ""
	button.clip_contents = false
	button.set_meta("item_id", item_id)

	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.texture = _item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = _item_name(item_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_font_override("font", FANTASY_FONT)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	button.add_child(name_label)

	button.mouse_entered.connect(func() -> void:
		_select_item(item_id, false)
	)
	button.pressed.connect(func() -> void:
		_select_item(item_id, true)
	)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_font_override("font", FANTASY_FONT)
	var active := _is_equipped_item(item_id)
	button.add_theme_stylebox_override("normal", _slot_box(active))
	button.add_theme_stylebox_override("hover", _slot_box(true))
	button.add_theme_stylebox_override("pressed", _slot_box(true))
	_layout_item_cell(button, button.custom_minimum_size)
	return button

func _select_item(item_id: String, auto_equip: bool) -> void:
	if item_id == "":
		return
	_selected_item_id = item_id
	if auto_equip:
		GameManager.equip_inventory_item(item_id)
	_show_item_detail(item_id)
	_update_action_buttons()

func _show_item_detail(item_id: String) -> void:
	if detail_icon == null:
		return
	detail_icon.texture = _item_icon(item_id)
	detail_icon.rotation_degrees = -90.0 if GameManager.is_weapon_item(item_id) else 0.0
	detail_icon.pivot_offset = detail_icon.custom_minimum_size * 0.5
	if GameManager.is_weapon_item(item_id):
		var cfg: Dictionary = WeaponDB.get_weapon(item_id)
		detail_name.text = "Lv.%d  %s" % [WeaponDB.tier_for(item_id), cfg.get("name", item_id)]
		detail_stats.text = "공격력 %d   속도 %.1f/s   사거리 %d   범위각 %d도" % [
			int(cfg.get("damage", 0)),
			float(cfg.get("attack_rate", 0.0)),
			int(cfg.get("range", 0.0)),
			int(cfg.get("arc", 0.0)),
		]
		detail_description.text = _sword_description(item_id)
	elif GameManager.is_armor_item(item_id):
		var key: String = GameManager.armor_key_from_item(item_id)
		var armor: Dictionary = GameManager.get_armor_stats(item_id)
		detail_name.text = "%s  [%s]" % [armor.get("name", "방어구"), armor.get("rarity", "일반")]
		detail_stats.text = "부위 %s   체력 +%d   공격 +%.0f%%   공속 +%.0f%%   이동 +%.0f%%   치명 +%.0f%%" % [
			EQUIPMENT_LABELS.get(str(armor.get("slot", "")), armor.get("slot", "")),
			int(armor.get("hp", 0)),
			(float(armor.get("damage_mult", 1.0)) - 1.0) * 100.0,
			(float(armor.get("attack_rate_mult", 1.0)) - 1.0) * 100.0,
			(float(armor.get("speed_mult", 1.0)) - 1.0) * 100.0,
			float(armor.get("crit_bonus", 0.0)) * 100.0,
		]
		detail_description.text = "선택하면 해당 부위에 장착됩니다. 같은 이름의 장비라도 개체마다 1~5% 정도 능력치가 다릅니다."
	else:
		detail_name.text = "알 수 없는 아이템"
		detail_stats.text = ""
		detail_description.text = ""

func _update_action_buttons() -> void:
	var selected := _selected_item_id
	var is_weapon := GameManager.is_weapon_item(selected)
	var is_armor := GameManager.is_armor_item(selected)
	equip_button.disabled = not (is_weapon or is_armor)
	unequip_button.disabled = not (is_armor and _is_equipped_item(selected))
	drop_button.disabled = selected == "wood" or selected == "" or selected not in GameManager.inventory

func _on_equip_pressed() -> void:
	if GameManager.equip_inventory_item(_selected_item_id):
		_rebuild_items()

func _on_unequip_pressed() -> void:
	GameManager.unequip_item(_selected_item_id)
	_rebuild_items()

func _on_drop_pressed() -> void:
	if GameManager.drop_inventory_item(_selected_item_id):
		_selected_item_id = ""
		_rebuild_items()
	else:
		_update_action_buttons()

func _is_equipped_item(item_id: String) -> bool:
	if GameManager.is_weapon_item(item_id):
		return GameManager.equipped == item_id
	if GameManager.is_armor_item(item_id):
		for slot in GameManager.equipment.keys():
			if str(GameManager.equipment[slot]) == item_id:
				return true
	return false

func _item_name(item_id: String) -> String:
	if GameManager.is_weapon_item(item_id):
		return WeaponDB.display_name(item_id)
	if GameManager.is_armor_item(item_id):
		var key: String = GameManager.armor_key_from_item(item_id)
		return str(GameManager.ARMORS.get(key, {}).get("name", "방어구"))
	return item_id

func _item_icon(item_id: String) -> Texture2D:
	if GameManager.is_weapon_item(item_id):
		var weapon_path: String = str(WeaponDB.get_weapon(item_id).get("texture", ""))
		return load(weapon_path) if weapon_path != "" else null
	if GameManager.is_armor_item(item_id):
		var key: String = GameManager.armor_key_from_item(item_id)
		var armor_path: String = str(GameManager.ARMORS.get(key, {}).get("texture", ""))
		return load(armor_path) if armor_path != "" else null
	return null

func _armor_tooltip(item_id: String) -> String:
	var cfg: Dictionary = GameManager.get_armor_stats(item_id)
	return "%s [%s]\n체력 +%d / 공격 +%.0f%% / 공속 +%.0f%% / 치명 +%.0f%%" % [
		cfg.get("name", "장비"),
		cfg.get("rarity", "일반"),
		int(cfg.get("hp", 0)),
		(float(cfg.get("damage_mult", 1.0)) - 1.0) * 100.0,
		(float(cfg.get("attack_rate_mult", 1.0)) - 1.0) * 100.0,
		float(cfg.get("crit_bonus", 0.0)) * 100.0,
	]

func _sword_description(key: String) -> String:
	var element: String = WeaponDB.element_from_key(key)
	if element == WeaponDB.ELEMENT_LIGHTNING:
		return "원소 진화: 공격 시 번개가 가까운 적에게 연쇄 피해를 줍니다."
	if element == WeaponDB.ELEMENT_WATER:
		return "원소 진화: 차가운 물결이 범위 피해를 주고 적을 느리게 만듭니다."
	if element == WeaponDB.ELEMENT_FIRE:
		return "원소 진화: 불꽃 폭발이 주변 적에게 추가 피해를 줍니다."
	match WeaponDB.base_key(key):
		"wood":
			return "초라하지만 믿음직한 시작의 검입니다. 나무검은 마지막 희망이라 절대 버릴 수 없습니다."
		"steel":
			return "보스에게서 얻은 녹슨 철검입니다. 나무검보다 묵직하고 안정적입니다."
		"light":
			return "기사단의 빛이 남아 있는 강철검입니다. 더 빠른 연속 베기에 어울립니다."
		"rune":
			return "고대 룬이 칼날에 새겨진 마검입니다. 마력이 검 끝에서 맴돕니다."
		"flame":
			return "뜨거운 불꽃이 감도는 화염검입니다. 강한 일격에 특화되어 있습니다."
		"radiant":
			return "빛의 성검 에이렌입니다. 어둠을 가르는 최종 단계의 검입니다."
		_:
			return "아직 전설이 완성되지 않은 무기입니다."

func _relayout_grid() -> void:
	if item_grid == null:
		return
	var host := item_grid.get_parent() as Control
	if host == null:
		return
	var host_size: Vector2 = host.size
	if host_size.x <= 0.0 or host_size.y <= 0.0:
		return
	var grid_pos := Vector2(host_size.x * GRID_INSET_LEFT, host_size.y * GRID_INSET_TOP)
	var gs := Vector2(
		host_size.x * (GRID_INSET_RIGHT - GRID_INSET_LEFT),
		host_size.y * (GRID_INSET_BOTTOM - GRID_INSET_TOP)
	)
	item_grid.position = grid_pos
	item_grid.size = gs
	item_grid.custom_minimum_size = Vector2.ZERO

	var hsep: float = 8.0
	var vsep: float = 8.0
	var cw: float = (gs.x - (ITEM_COLUMNS - 1) * hsep) / float(ITEM_COLUMNS)
	var ch: float = (gs.y - (ITEM_ROWS - 1) * vsep) / float(ITEM_ROWS)
	var cell := Vector2(maxf(16.0, cw), maxf(16.0, ch))
	for child in item_grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = cell
			_layout_item_cell(child as Control, cell)

func _layout_item_cell(cell_node: Control, cell_size: Vector2) -> void:
	var icon := cell_node.get_node_or_null("ItemIcon") as TextureRect
	if icon != null:
		var icon_size: float = minf(cell_size.x, cell_size.y) * 0.72
		icon.size = Vector2(icon_size, icon_size)
		icon.pivot_offset = icon.size * 0.5
		icon.position = Vector2((cell_size.x - icon.size.x) * 0.5, (cell_size.y - icon.size.y) * 0.5 - 7.0)
		var item_id: String = _item_id_from_cell(cell_node)
		icon.rotation_degrees = -90.0 if GameManager.is_weapon_item(item_id) else 0.0

	var name_label := cell_node.get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.position = Vector2(4.0, cell_size.y - 26.0)
		name_label.size = Vector2(maxf(24.0, cell_size.x - 8.0), 22.0)

func _item_id_from_cell(cell_node: Control) -> String:
	return str(cell_node.get_meta("item_id", ""))

func _empty_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(132, 104)
	slot.add_theme_stylebox_override("panel", _slot_box(false))
	return slot

func _action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(112, 34)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_font_override("font", FANTASY_FONT)
	button.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	button.add_theme_stylebox_override("normal", _button_box(Color(0.12, 0.09, 0.055), Color(0.66, 0.42, 0.14)))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.18, 0.13, 0.07), Color(0.98, 0.70, 0.24)))
	button.add_theme_stylebox_override("pressed", _button_box(Color(0.08, 0.06, 0.04), Color(0.54, 0.32, 0.10)))
	return button

func _tex(file_name: String) -> Texture2D:
	return load(UI_DIR + file_name)

func _panel_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _slot_box(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.10, 0.11, 0.96)
	box.border_color = Color(0.95, 0.66, 0.20) if active else Color(0.26, 0.24, 0.22)
	box.set_border_width_all(3)
	box.set_corner_radius_all(7)
	return box

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
