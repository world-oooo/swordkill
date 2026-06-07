extends CanvasLayer
## Forge panel for equipped-only elemental sword evolution.
##
## Press F to open/close. The Forge never edits standby weapons directly: it asks
## GameManager to transform the currently equipped inventory slot into an
## elemental evolved key such as "wood_lightning" or "steel_water".

const FANTASY_FONT: Font = preload("res://assets/fonts/oldengl.ttf")
const UI_DIR: String = "res://assets/ui/generated/"
## 대장간 업그레이드 화면 전체 배경 이미지. 다른 이미지를 쓰려면 이 경로만 바꾸면 된다.
const BACKGROUND_PATH: String = "res://scenes/rooms/QR+R2i.png"

var panel: PanelContainer
var equipped_name: Label
var equipped_stats: Label
var lightning_button: Button
var water_button: Button
var fire_button: Button
var cost_label: Label
var message_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	GameManager.inventory_changed.connect(_refresh)
	GameManager.currency_changed.connect(func(_coins: int, _gems: int) -> void:
		_refresh()
	)
	GameManager.forge_message_changed.connect(_set_message)

## 대장간 UI 는 이제 대장간 방의 모루에서만 열린다(전역 F 팝업 제거).
## 열려 있을 때만 F/Esc 로 닫는다.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh()

func show_forge() -> void:
	open()

func close() -> void:
	visible = false
	get_tree().paused = false

func hide_forge() -> void:
	close()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# 전체 화면 배경 이미지: 가장 먼저 추가 = 가장 아래 레이어(가장 먼저 그려짐) → 버튼/텍스트를 가리지 않는다.
	var background := TextureRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 비율 유지하며 화면 가득 채움(잘림 허용)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE              # 클릭이 통과되도록(버튼 보호)
	background.texture = _load_background()
	add_child(background)

	# 가독성용 약한 어둠막(이미지 위, 패널 아래). 배경이 잘 보이도록 알파를 낮춤.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -220
	panel.offset_right = 360
	panel.offset_bottom = 220
	panel.add_theme_stylebox_override("panel", _panel_box(Color(0.055, 0.045, 0.038, 0.98), Color(0.82, 0.53, 0.18), 14))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := Label.new()
	header.name = "Header"
	header.text = "원소 대장간"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", FANTASY_FONT)
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	header.add_theme_constant_override("shadow_offset_x", 2)
	header.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(header)

	var equipped_panel := PanelContainer.new()
	equipped_panel.name = "EquippedPanel"
	equipped_panel.add_theme_stylebox_override("panel", _panel_box(Color(0.095, 0.083, 0.070, 0.94), Color(0.47, 0.32, 0.14), 9))
	root.add_child(equipped_panel)

	var equipped_stack := VBoxContainer.new()
	equipped_stack.name = "EquippedStack"
	equipped_stack.add_theme_constant_override("separation", 5)
	equipped_panel.add_child(equipped_stack)

	equipped_name = Label.new()
	equipped_name.name = "EquippedName"
	equipped_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipped_name.add_theme_font_override("font", FANTASY_FONT)
	equipped_name.add_theme_font_size_override("font_size", 24)
	equipped_name.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	equipped_stack.add_child(equipped_name)

	equipped_stats = Label.new()
	equipped_stats.name = "EquippedStats"
	equipped_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipped_stats.add_theme_font_override("font", FANTASY_FONT)
	equipped_stats.add_theme_font_size_override("font_size", 16)
	equipped_stats.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	equipped_stack.add_child(equipped_stats)

	var path_row := HBoxContainer.new()
	path_row.name = "PathRow"
	path_row.add_theme_constant_override("separation", 18)
	root.add_child(path_row)

	lightning_button = _path_button("LightningButton", "번개", "공격이 가까운 적에게 연쇄 번개로 튑니다.")
	lightning_button.pressed.connect(func() -> void: _select_path(WeaponDB.ELEMENT_LIGHTNING))
	path_row.add_child(lightning_button)

	water_button = _path_button("WaterButton", "물", "차가운 물결이 범위 피해를 주고 적을 느리게 만듭니다.")
	water_button.pressed.connect(func() -> void: _select_path(WeaponDB.ELEMENT_WATER))
	path_row.add_child(water_button)

	fire_button = _path_button("FireButton", "불", "화염 폭발이 주변 적에게 추가 피해를 줍니다.")
	fire_button.pressed.connect(func() -> void: _select_path(WeaponDB.ELEMENT_FIRE))
	path_row.add_child(fire_button)

	cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_override("font", FANTASY_FONT)
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	root.add_child(cost_label)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_override("font", FANTASY_FONT)
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color(0.76, 0.90, 1.0))
	root.add_child(message_label)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "F 또는 Esc 키로 닫기"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FANTASY_FONT)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.50))
	root.add_child(hint)

func _path_button(node_name: String, title: String, description: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(210, 126)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s\n%s" % [title, description]
	button.add_theme_font_override("font", FANTASY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _slot_box(false))
	button.add_theme_stylebox_override("hover", _slot_box(true))
	button.add_theme_stylebox_override("pressed", _slot_box(true))
	return button

func _refresh() -> void:
	if equipped_name == null:
		return
	var key: String = GameManager.equipped
	if key == "":
		equipped_name.text = "장착한 무기가 없습니다"
		equipped_stats.text = "검을 장착한 뒤 대장간을 이용하세요."
		cost_label.text = "비용: --"
		lightning_button.disabled = true
		water_button.disabled = true
		fire_button.disabled = true
		return

	var cfg: Dictionary = WeaponDB.get_weapon(key)
	equipped_name.text = "장착 중: %s" % cfg.get("name", key)
	equipped_stats.text = "레벨 %d  공격력 %d  속도 %.1f/s  사거리 %d" % [
		WeaponDB.tier_for(key),
		cfg.get("damage", 0),
		cfg.get("attack_rate", 0.0),
		int(cfg.get("range", 0.0)),
	]

	var lightning_cost: int = GameManager.get_evolution_cost(WeaponDB.ELEMENT_LIGHTNING)
	var water_cost: int = GameManager.get_evolution_cost(WeaponDB.ELEMENT_WATER)
	var fire_cost: int = GameManager.get_evolution_cost(WeaponDB.ELEMENT_FIRE)
	cost_label.text = "대장간 진화 비용: 무료 | 번개 %d | 물 %d | 불 %d 코인" % [lightning_cost, water_cost, fire_cost]
	lightning_button.disabled = lightning_cost < 0
	water_button.disabled = water_cost < 0
	fire_button.disabled = fire_cost < 0

func _select_path(element: String) -> void:
	var result: Dictionary = GameManager.evolve_equipped(element)
	_set_message(str(result.get("message", "")))
	_refresh()

func _set_message(message: String) -> void:
	if message_label != null:
		message_label.text = message

## 배경 텍스처를 안전하게 로드. 파일이 없거나 아직 임포트 전이면 null 을 반환(크래시 방지).
func _load_background() -> Texture2D:
	if ResourceLoader.exists(BACKGROUND_PATH):
		return load(BACKGROUND_PATH) as Texture2D
	push_warning("Forge background image not found (import it in the editor first): %s" % BACKGROUND_PATH)
	return null

func _panel_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.48)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 5)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _slot_box(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.12, 0.12, 0.97)
	box.border_color = Color(0.95, 0.68, 0.22) if active else Color(0.38, 0.28, 0.16)
	box.set_border_width_all(3)
	box.set_corner_radius_all(9)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
