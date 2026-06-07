extends Node2D
## Reusable corridor entrance.
##
## Door has two separate collision concepts:
## - Trigger: an Area2D that detects the player when the door is open.
## - Gate: a StaticBody2D that physically blocks the player while the room is locked.

signal exit_requested(dir: String)

@export_enum("N", "S", "E", "W") var direction: String = "N"
@export var trigger_size: Vector2 = Vector2(150, 60)
@export var locked_color: Color = Color(0.85, 0.18, 0.22, 0.86)
@export var open_color: Color = Color(0.18, 0.42, 0.34, 0.72)

const LOCKED_BARRICADE_TEXTURE: Texture2D = preload("res://assets/obstacles/barricade_ai.png")

var _locked: bool = false

@onready var trigger: Area2D = $Trigger
@onready var trigger_collision: CollisionShape2D = $Trigger/TriggerCollision
@onready var gate: StaticBody2D = $Gate
@onready var gate_collision: CollisionShape2D = $Gate/GateCollision
@onready var open_visual: ColorRect = $OpenVisual
@onready var locked_visual: ColorRect = $LockedVisual
@onready var label: Label = $OpenVisual/DirectionLabel

var locked_sprite: Sprite2D = null

func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)
	_ensure_locked_sprite()
	_apply_size()
	_apply_locked_state()

func setup(dir: String, door_position: Vector2, size: Vector2) -> void:
	direction = dir
	position = door_position
	trigger_size = size
	if is_node_ready():
		_apply_size()
		_apply_locked_state()

func set_locked(locked: bool) -> void:
	_locked = locked
	if is_node_ready():
		_apply_locked_state()

func is_locked() -> bool:
	return _locked

func set_palette(open_tint: Color, locked_tint: Color) -> void:
	open_color = open_tint
	locked_color = locked_tint
	if is_node_ready():
		open_visual.color = open_color
		locked_visual.color = locked_color

func _apply_size() -> void:
	var trigger_shape := RectangleShape2D.new()
	trigger_shape.size = trigger_size
	trigger_collision.shape = trigger_shape

	var gate_shape := RectangleShape2D.new()
	gate_shape.size = trigger_size
	gate_collision.shape = gate_shape

	for visual in [open_visual, locked_visual]:
		visual.size = trigger_size
		visual.position = -trigger_size * 0.5
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_visual.color = Color(1, 1, 1, 0)
	_layout_locked_sprite()

	label.size = trigger_size
	label.text = {"N": "^", "S": "v", "E": ">", "W": "<"}.get(direction, "?")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_locked_state() -> void:
	# CollisionObject/Area monitoring changes are deferred so this is safe from
	# body_entered, physics_process, enemy death, and room transition callbacks.
	gate_collision.set_deferred("disabled", not _locked)
	trigger.set_deferred("monitoring", not _locked)
	trigger_collision.set_deferred("disabled", _locked)
	open_visual.visible = not _locked
	locked_visual.visible = _locked
	if locked_sprite != null:
		locked_sprite.visible = _locked
	open_visual.color = open_color
	locked_visual.color = Color(1, 1, 1, 0)

func _ensure_locked_sprite() -> void:
	if locked_sprite != null:
		return
	locked_sprite = Sprite2D.new()
	locked_sprite.name = "LockedBarricadeSprite"
	locked_sprite.texture = LOCKED_BARRICADE_TEXTURE
	locked_sprite.centered = true
	locked_sprite.visible = false
	locked_sprite.z_index = 4
	add_child(locked_sprite)

func _layout_locked_sprite() -> void:
	if locked_sprite == null or locked_sprite.texture == null:
		return
	var texture_size: Vector2 = locked_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	locked_sprite.rotation_degrees = 90.0 if direction in ["E", "W"] else 0.0
	var target_size: Vector2 = trigger_size * 1.22
	var rotated_size: Vector2 = Vector2(texture_size.y, texture_size.x) if direction in ["E", "W"] else texture_size
	var scale_factor: float = minf(target_size.x / rotated_size.x, target_size.y / rotated_size.y)
	locked_sprite.scale = Vector2.ONE * scale_factor

func _on_trigger_body_entered(body: Node) -> void:
	if _locked:
		return
	if body.is_in_group("player"):
		exit_requested.emit(direction)
