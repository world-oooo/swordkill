extends CanvasLayer
## Art-backed in-game HUD for The Last Light.
##
## Uses TextureProgressBar for animated gauges, generated medieval pixel-art
## textures for frames/icons, and player/GameManager signals for live updates.

@export var player_path: NodePath

const UI_DIR: String = "res://assets/ui/generated/"
const MINIMAP_SCRIPT: Script = preload("res://scripts/minimap_view.gd")
const FANTASY_FONT: Font = preload("res://assets/fonts/oldengl.ttf")

var hp_bar: TextureProgressBar
var shield_bar: TextureProgressBar
var energy_bar: TextureProgressBar
var boss_bar: TextureProgressBar
var hp_value: Label
var shield_value: Label
var energy_value: Label
var weapon_label: Label
var coin_label: Label
var gem_label: Label
var floor_label: Label
var boss_panel: Control
var combo_panel: PanelContainer
var combo_label: Label
var combo_fill: ColorRect
var skill_label: Label
var skill_icon: TextureRect
var screen_flash: ColorRect
var weapon_popup: Label
var subtitle_panel: PanelContainer
var subtitle_speaker: Label
var subtitle_line: Label
var center_message_label: Label
var boss_phase_panel: PanelContainer
var boss_phase_label: Label
var boss_marker_layer: Control
var boss_marker_labels: Array[Label] = []

var _stats_initialized: bool = false
var _last_hp: int = 0
var _last_shield: float = 0.0
var _bar_tweens: Dictionary = {}
var _phase_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_connect_signals()
	_refresh_currency(GameManager.coins, GameManager.gems)
	_refresh_map()
	_set_skill_inactive()

func _process(_delta: float) -> void:
	if GameManager.combo > 0:
		combo_panel.visible = true
		combo_label.text = "%d 콤보" % GameManager.combo
		combo_fill.scale.x = clampf(GameManager.combo_timer / GameManager.COMBO_TIMEOUT, 0.0, 1.0)
	else:
		combo_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_I:
			_show_boss_phase_info()

func _connect_signals() -> void:
	var player: Node = get_node_or_null(player_path)
	if player != null:
		player.stats_changed.connect(_on_stats_changed)
		player.skill_state_changed.connect(_on_skill_state_changed)
		player.weapon_changed.connect(_on_weapon_changed)

	GameManager.currency_changed.connect(_refresh_currency)
	GameManager.map_changed.connect(_refresh_map)
	GameManager.boss_active_changed.connect(_on_boss_active)
	GameManager.boss_health_changed.connect(_on_boss_health)
	GameManager.boss_phase_markers_changed.connect(_on_boss_phase_markers_changed)
	GameManager.subtitle_requested.connect(_on_subtitle_requested)
	GameManager.center_message_requested.connect(_on_center_message_requested)

func _build_hud() -> void:
	for child in get_children():
		child.queue_free()
	_build_top_left()
	_build_top_right()
	_build_top_center()
	_build_bottom_right()
	_build_subtitle()
	_build_center_message()
	_build_boss_phase_info()
	_build_screen_fx()
	_build_weapon_popup()

func _build_top_left() -> void:
	var root := Control.new()
	root.name = "TopLeft"
	root.position = Vector2(12, 10)
	root.size = Vector2(360, 170)
	add_child(root)

	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.add_theme_constant_override("separation", -6)
	root.add_child(stats)

	var hp_row := _make_gauge_row("HPRow", "HP", "gauge_hp_over.png", "fill_hp.png", 7, 7)
	hp_bar = hp_row["bar"]
	hp_value = hp_row["value"]
	stats.add_child(hp_row["node"])

	var shield_row := _make_gauge_row("ShieldRow", "SH", "gauge_shield_over.png", "fill_shield.png", 6, 6)
	shield_bar = shield_row["bar"]
	shield_value = shield_row["value"]
	stats.add_child(shield_row["node"])

	var energy_row := _make_gauge_row("EnergyRow", "EN", "gauge_energy_over.png", "fill_energy.png", 200, 200)
	energy_bar = energy_row["bar"]
	energy_value = energy_row["value"]
	stats.add_child(energy_row["node"])

	weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.text = WeaponDB.display_name(GameManager.equipped)
	weapon_label.custom_minimum_size = Vector2(320, 28)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 19)
	weapon_label.add_theme_font_override("font", FANTASY_FONT)
	weapon_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	weapon_label.add_theme_constant_override("shadow_offset_x", 2)
	weapon_label.add_theme_constant_override("shadow_offset_y", 2)
	stats.add_child(weapon_label)

func _build_top_right() -> void:
	var root := Control.new()
	root.name = "TopRight"
	root.anchor_left = 1.0
	root.anchor_right = 1.0
	root.offset_left = -426
	root.offset_top = 10
	root.offset_right = -12
	root.offset_bottom = 180
	add_child(root)

	var row := HBoxContainer.new()
	row.name = "ResourceRow"
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.custom_minimum_size = Vector2(410, 38)
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	coin_label = _make_icon_counter(row, "CoinBox", _atlas("coin_icons.png"), "0", Color(1.0, 0.88, 0.35))
	gem_label = _make_icon_counter(row, "GemBox", _atlas("gem_icon.png"), "0", Color(0.55, 0.92, 1.0))

	floor_label = Label.new()
	floor_label.name = "FloorLabel"
	floor_label.custom_minimum_size = Vector2(100, 36)
	floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 18)
	floor_label.add_theme_font_override("font", FANTASY_FONT)
	floor_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	floor_label.add_theme_stylebox_override("normal", _panel_box(Color(0.08, 0.07, 0.055, 0.88), Color(0.68, 0.46, 0.18), 8))
	row.add_child(floor_label)

	var map_frame := TextureRect.new()
	map_frame.name = "MinimapFrame"
	map_frame.texture = _atlas("minimap_panel_ai.png")
	map_frame.ignore_texture_size = true
	map_frame.clip_contents = true
	map_frame.anchor_left = 1.0
	map_frame.anchor_top = 0.0
	map_frame.anchor_right = 1.0
	map_frame.anchor_bottom = 0.0
	map_frame.offset_left = -154.0
	map_frame.offset_top = 42.0
	map_frame.offset_right = 0.0
	map_frame.offset_bottom = 196.0
	map_frame.custom_minimum_size = Vector2.ZERO
	map_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_frame.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(map_frame)

	var minimap := Control.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap.offset_left = 24.0
	minimap.offset_top = 26.0
	minimap.offset_right = -24.0
	minimap.offset_bottom = -24.0
	minimap.set_script(MINIMAP_SCRIPT)
	map_frame.add_child(minimap)

func _build_top_center() -> void:
	var root := VBoxContainer.new()
	root.name = "TopCenter"
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.offset_left = -280
	root.offset_top = 10
	root.offset_right = 280
	root.offset_bottom = 150
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	boss_panel = Control.new()
	boss_panel.name = "BossPanel"
	boss_panel.visible = false
	boss_panel.custom_minimum_size = Vector2(560, 82)
	root.add_child(boss_panel)

	boss_bar = _make_texture_bar("BossBar", "boss_bar_over.png", "fill_boss.png", 60, 60)
	boss_bar.position = Vector2(0, 0)
	boss_bar.size = Vector2(560, 82)
	boss_panel.add_child(boss_bar)

	boss_marker_layer = Control.new()
	boss_marker_layer.name = "BossPhaseMarkers"
	boss_marker_layer.position = Vector2.ZERO
	boss_marker_layer.size = Vector2(560, 82)
	boss_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(boss_marker_layer)

	var boss_label := Label.new()
	boss_label.name = "BossLabel"
	boss_label.text = "보스"
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 18)
	boss_label.add_theme_font_override("font", FANTASY_FONT)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.58))
	boss_label.position = Vector2(0, 4)
	boss_label.size = Vector2(560, 24)
	boss_panel.add_child(boss_label)

	combo_panel = PanelContainer.new()
	combo_panel.name = "ComboPanel"
	combo_panel.visible = false
	combo_panel.custom_minimum_size = Vector2(220, 56)
	combo_panel.add_theme_stylebox_override("panel", _panel_box(Color(0.09, 0.065, 0.035, 0.92), Color(0.95, 0.68, 0.20), 10))
	root.add_child(combo_panel)

	var combo_stack := VBoxContainer.new()
	combo_stack.name = "ComboStack"
	combo_stack.add_theme_constant_override("separation", 6)
	combo_panel.add_child(combo_stack)

	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = "0 콤보"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 24)
	combo_label.add_theme_font_override("font", FANTASY_FONT)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	combo_stack.add_child(combo_label)

	var timer_bg := ColorRect.new()
	timer_bg.name = "ComboTimer"
	timer_bg.custom_minimum_size = Vector2(210, 6)
	timer_bg.color = Color(0.16, 0.12, 0.06, 1.0)
	combo_stack.add_child(timer_bg)

	combo_fill = ColorRect.new()
	combo_fill.name = "ComboFill"
	combo_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	combo_fill.color = Color(1.0, 0.78, 0.18)
	timer_bg.add_child(combo_fill)

func _build_bottom_right() -> void:
	var root := Control.new()
	root.name = "BottomRight"
	root.anchor_left = 1.0
	root.anchor_top = 1.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -170
	root.offset_top = -170
	root.offset_right = -22
	root.offset_bottom = -22
	add_child(root)

	skill_icon = TextureRect.new()
	skill_icon.name = "SkillButton"
	skill_icon.texture = _atlas("skill_fast_slash_icon.png")
	skill_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(skill_icon)

	var key := Label.new()
	key.name = "SkillKey"
	key.text = "스페이스"
	key.position = Vector2(15, 103)
	key.size = Vector2(118, 24)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 18)
	key.add_theme_font_override("font", FANTASY_FONT)
	key.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	root.add_child(key)

	skill_label = Label.new()
	skill_label.name = "SkillLabel"
	skill_label.text = "빠르게 베기"
	skill_label.position = Vector2(0, 130)
	skill_label.size = Vector2(148, 24)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.add_theme_font_size_override("font_size", 16)
	skill_label.add_theme_font_override("font", FANTASY_FONT)
	skill_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	root.add_child(skill_label)

func _build_subtitle() -> void:
	subtitle_panel = PanelContainer.new()
	subtitle_panel.name = "BossSubtitle"
	subtitle_panel.visible = false
	subtitle_panel.anchor_left = 0.5
	subtitle_panel.anchor_top = 0.76
	subtitle_panel.anchor_right = 0.5
	subtitle_panel.anchor_bottom = 0.76
	subtitle_panel.offset_left = -500
	subtitle_panel.offset_top = -72
	subtitle_panel.offset_right = 500
	subtitle_panel.offset_bottom = 72
	subtitle_panel.add_theme_stylebox_override("panel", _panel_box(Color(0.025, 0.018, 0.014, 0.94), Color(0.95, 0.57, 0.16), 12))
	add_child(subtitle_panel)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 5)
	subtitle_panel.add_child(stack)

	subtitle_speaker = Label.new()
	subtitle_speaker.name = "Speaker"
	subtitle_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_speaker.add_theme_font_override("font", FANTASY_FONT)
	subtitle_speaker.add_theme_font_size_override("font_size", 30)
	subtitle_speaker.add_theme_color_override("font_color", Color(1.0, 0.74, 0.24))
	stack.add_child(subtitle_speaker)

	subtitle_line = Label.new()
	subtitle_line.name = "Line"
	subtitle_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_line.add_theme_font_override("font", FANTASY_FONT)
	subtitle_line.add_theme_font_size_override("font_size", 24)
	subtitle_line.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	stack.add_child(subtitle_line)

func _build_center_message() -> void:
	center_message_label = Label.new()
	center_message_label.name = "CenterMessage"
	center_message_label.visible = false
	center_message_label.anchor_left = 0.5
	center_message_label.anchor_top = 0.5
	center_message_label.anchor_right = 0.5
	center_message_label.anchor_bottom = 0.5
	center_message_label.offset_left = -360
	center_message_label.offset_top = -44
	center_message_label.offset_right = 360
	center_message_label.offset_bottom = 44
	center_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_message_label.add_theme_font_size_override("font_size", 34)
	center_message_label.add_theme_font_override("font", FANTASY_FONT)
	center_message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	center_message_label.add_theme_constant_override("shadow_offset_x", 3)
	center_message_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(center_message_label)

func _build_boss_phase_info() -> void:
	boss_phase_panel = PanelContainer.new()
	boss_phase_panel.name = "BossPhaseInfo"
	boss_phase_panel.visible = false
	boss_phase_panel.anchor_left = 0.5
	boss_phase_panel.anchor_top = 0.5
	boss_phase_panel.anchor_right = 0.5
	boss_phase_panel.anchor_bottom = 0.5
	boss_phase_panel.offset_left = -360
	boss_phase_panel.offset_top = -128
	boss_phase_panel.offset_right = 360
	boss_phase_panel.offset_bottom = 128
	boss_phase_panel.add_theme_stylebox_override("panel", _panel_box(Color(0.025, 0.018, 0.014, 0.95), Color(0.78, 0.30, 0.95), 12))
	add_child(boss_phase_panel)

	boss_phase_label = Label.new()
	boss_phase_label.name = "Text"
	boss_phase_label.text = ""
	boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_phase_label.add_theme_font_override("font", FANTASY_FONT)
	boss_phase_label.add_theme_font_size_override("font_size", 25)
	boss_phase_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	boss_phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	boss_phase_label.add_theme_constant_override("shadow_offset_x", 2)
	boss_phase_label.add_theme_constant_override("shadow_offset_y", 2)
	boss_phase_panel.add_child(boss_phase_label)

func _build_screen_fx() -> void:
	screen_flash = ColorRect.new()
	screen_flash.name = "DamageFlash"
	screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_flash.color = Color(1.0, 0.05, 0.02, 0.0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_flash)

func _build_weapon_popup() -> void:
	weapon_popup = Label.new()
	weapon_popup.name = "WeaponPopup"
	weapon_popup.anchor_left = 0.5
	weapon_popup.anchor_right = 0.5
	weapon_popup.offset_left = -220
	weapon_popup.offset_top = 86
	weapon_popup.offset_right = 220
	weapon_popup.offset_bottom = 124
	weapon_popup.visible = false
	weapon_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_popup.add_theme_font_size_override("font_size", 27)
	weapon_popup.add_theme_font_override("font", FANTASY_FONT)
	weapon_popup.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	weapon_popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	weapon_popup.add_theme_constant_override("shadow_offset_x", 2)
	weapon_popup.add_theme_constant_override("shadow_offset_y", 2)
	add_child(weapon_popup)

func _make_gauge_row(row_name: String, label_text: String, frame: String, fill: String, max_value: float, value: float) -> Dictionary:
	var row := Control.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(352, 46)
	var frame_back := NinePatchRect.new()
	frame_back.name = label_text + "NinePatchFrame"
	frame_back.texture = _atlas(frame.replace("_over", "_frame"))
	frame_back.position = Vector2(0, 0)
	frame_back.size = Vector2(352, 46)
	frame_back.patch_margin_left = 90
	frame_back.patch_margin_right = 34
	frame_back.patch_margin_top = 14
	frame_back.patch_margin_bottom = 14
	row.add_child(frame_back)
	var bar := _make_texture_bar(label_text + "Bar", frame, fill, max_value, value)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(352, 46)
	row.add_child(bar)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = "%d/%d" % [int(value), int(max_value)]
	value_label.position = Vector2(160, 9)
	value_label.size = Vector2(150, 24)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_font_override("font", FANTASY_FONT)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	value_label.add_theme_constant_override("shadow_offset_x", 2)
	value_label.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(value_label)
	return {"node": row, "bar": bar, "value": value_label}

func _make_texture_bar(node_name: String, frame: String, fill: String, max_value: float, value: float) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.name = node_name
	bar.min_value = 0.0
	bar.max_value = max_value
	bar.value = value
	bar.texture_under = _atlas("fill_dark.png")
	bar.texture_progress = _atlas(fill)
	bar.texture_over = _atlas(frame)
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 90
	bar.stretch_margin_right = 34
	bar.stretch_margin_top = 14
	bar.stretch_margin_bottom = 14
	return bar

func _make_icon_counter(parent: Node, node_name: String, texture: Texture2D, value: String, color: Color) -> Label:
	var box := HBoxContainer.new()
	box.name = node_name
	box.custom_minimum_size = Vector2(92, 36)
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)

	var label := Label.new()
	label.name = "Value"
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_font_override("font", FANTASY_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(label)
	return label

func _on_stats_changed(hp: int, max_hp: int, shield: float, max_shield: float, energy: float, max_energy: float) -> void:
	hp_bar.max_value = max_hp
	shield_bar.max_value = max_shield
	energy_bar.max_value = max_energy
	_tween_bar(hp_bar, hp)
	_tween_bar(shield_bar, shield)
	_tween_bar(energy_bar, energy)
	hp_value.text = "%d/%d" % [hp, max_hp]
	shield_value.text = "%d/%d" % [int(ceil(shield)), int(max_shield)]
	energy_value.text = "%d/%d" % [int(energy), int(max_energy)]
	if _stats_initialized and (hp < _last_hp or shield < _last_shield):
		_flash_damage()
	_last_hp = hp
	_last_shield = shield
	_stats_initialized = true

func _on_skill_state_changed(active: bool, time_left: float) -> void:
	if active:
		skill_icon.modulate = Color(1.25, 1.15, 0.78)
		skill_label.text = "빠른 베기 %.1f초" % time_left
	else:
		_set_skill_inactive()

func _set_skill_inactive() -> void:
	if skill_icon != null:
		skill_icon.modulate = Color.WHITE
	if skill_label != null:
		skill_label.text = "빠르게 베기"

func _on_weapon_changed(weapon_name: String) -> void:
	weapon_label.text = weapon_name
	weapon_popup.text = weapon_name
	weapon_popup.visible = true
	weapon_popup.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(weapon_popup, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void: weapon_popup.visible = false)

func _refresh_currency(coins: int, gems: int) -> void:
	if coin_label != null:
		coin_label.text = str(coins)
	if gem_label != null:
		gem_label.text = str(gems)

func _refresh_map() -> void:
	var room_type := "시작"
	if not GameManager.rooms.is_empty():
		room_type = _room_type_name(str(GameManager.current_room().get("type", "start")))
	if floor_label != null:
		floor_label.text = "%d장 %s" % [GameManager.floor, GameManager.stage_data().get("name", room_type)]

func _room_type_name(type_key: String) -> String:
	match type_key:
		"start":
			return "시작"
		"combat":
			return "전투"
		"elite":
			return "정예"
		"shop":
			return "상점"
		"treasure":
			return "보물"
		"boss":
			return "보스"
		"forge":
			return "대장간"
		_:
			return "방"

func _on_boss_active(active: bool) -> void:
	boss_panel.visible = active
	if active:
		_refresh_boss_phase_markers()

func _on_boss_health(cur: float, max_hp: float) -> void:
	boss_bar.max_value = max_hp
	_tween_bar(boss_bar, cur)

func _on_boss_phase_markers_changed(_markers: Array) -> void:
	_refresh_boss_phase_markers()

func _refresh_boss_phase_markers() -> void:
	if boss_marker_layer == null:
		return
	for label in boss_marker_labels:
		if is_instance_valid(label):
			label.queue_free()
	boss_marker_labels.clear()
	var markers: Array = GameManager.boss_phase_markers
	for marker in markers:
		if not (marker is Dictionary):
			continue
		var ratio: float = clampf(float(marker.get("ratio", 0.0)), 0.0, 1.0)
		var marker_label := Label.new()
		marker_label.text = str(marker.get("label", "I"))
		marker_label.position = Vector2(18.0 + 524.0 * ratio - 8.0, 29.0)
		marker_label.size = Vector2(16.0, 32.0)
		marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker_label.tooltip_text = "%s 변신 지점" % str(marker.get("name", "보스"))
		marker_label.add_theme_font_size_override("font_size", 28)
		marker_label.add_theme_font_override("font", FANTASY_FONT)
		marker_label.add_theme_color_override("font_color", Color(1.0, 0.92, 1.0))
		marker_label.add_theme_color_override("font_shadow_color", Color(0.25, 0.0, 0.36, 1.0))
		marker_label.add_theme_constant_override("shadow_offset_x", 2)
		marker_label.add_theme_constant_override("shadow_offset_y", 2)
		boss_marker_layer.add_child(marker_label)
		boss_marker_labels.append(marker_label)

func _tween_bar(bar: TextureProgressBar, target: float) -> void:
	if _bar_tweens.has(bar) and _bar_tweens[bar] is Tween:
		var old_tween: Tween = _bar_tweens[bar]
		if old_tween.is_valid():
			old_tween.kill()
	var tween := create_tween()
	_bar_tweens[bar] = tween
	tween.tween_property(bar, "value", target, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _flash_damage() -> void:
	screen_flash.color.a = 0.32
	var tween := create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, 0.28)

func _on_subtitle_requested(speaker: String, line: String) -> void:
	if subtitle_panel == null:
		return
	subtitle_speaker.text = speaker
	subtitle_line.text = line
	subtitle_panel.visible = true
	subtitle_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(subtitle_panel, "modulate:a", 1.0, 0.22)
	tween.tween_interval(2.6)
	tween.tween_property(subtitle_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		subtitle_panel.visible = false
	)

func _on_center_message_requested(message: String, color: Color) -> void:
	if center_message_label == null:
		return
	center_message_label.text = message
	center_message_label.add_theme_color_override("font_color", color)
	center_message_label.visible = true
	center_message_label.modulate.a = 1.0
	center_message_label.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(center_message_label, "scale", Vector2.ONE, 0.12)
	tween.tween_property(center_message_label, "modulate:a", 0.0, 0.75).set_delay(1.05)
	tween.chain().tween_callback(func() -> void:
		center_message_label.visible = false
	)

func _show_boss_phase_info() -> void:
	if boss_phase_panel == null or boss_phase_label == null:
		return
	var text: String = GameManager.boss_phase_hint.strip_edges()
	if text == "":
		text = "현재 변신 정보를 가진 보스가 없습니다."
	boss_phase_label.text = text
	boss_phase_panel.visible = true
	boss_phase_panel.modulate.a = 1.0
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_interval(2.7)
	_phase_tween.tween_property(boss_phase_panel, "modulate:a", 0.0, 0.35)
	_phase_tween.tween_callback(func() -> void:
		boss_phase_panel.visible = false
	)

func _atlas(file_name: String) -> Texture2D:
	return load(UI_DIR + file_name)

func _panel_box(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.42)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
