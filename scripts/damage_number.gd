extends Node2D
## Floating damage number with a quick pop, upward drift, and fade.
##
## Critical hits are larger, yellow, and include an exclamation mark.

@onready var _label: Label = $Label

func setup(amount: int, crit: bool) -> void:
	add_to_group("dmgnum")
	scale = Vector2(0.55, 0.55)

	if crit:
		_label.text = "%d!" % amount
		_label.add_theme_font_size_override("font_size", 34)
		_label.modulate = Color(1.0, 0.84, 0.18)
	else:
		_label.text = str(amount)
		_label.add_theme_font_size_override("font_size", 22)
		_label.modulate = Color(1.0, 1.0, 1.0)

	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 46.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.08)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.10)
	tween.finished.connect(queue_free)
