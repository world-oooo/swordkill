extends Node2D
## 검기 효과: 기본은 부채꼴 Polygon2D, 특수 검은 픽셀 스프라이트 시트로 검기를 재생한다.

@onready var _poly: Polygon2D = $Poly

var _sprite: Sprite2D = null
var _frames: int = 1
var _anim_fps: float = 12.0
var _frame_t: float = 0.0

func _process(delta: float) -> void:
	if _sprite != null and _frames > 1:
		_frame_t += delta * _anim_fps
		_sprite.frame = mini(int(_frame_t), _frames - 1)

## facing: 베기 방향(rad), rng: 사거리, arc_deg: 부채꼴 각도, color: 검기 색
func setup(facing: float, rng: float, arc_deg: float, color: Color) -> void:
	add_to_group("vfx")
	_poly.visible = true
	_poly.polygon = _build(arc_deg, rng * 0.5, rng * 1.0)
	_poly.color = Color(color.r, color.g, color.b, 0.9)
	rotation = facing - deg_to_rad(40.0)
	scale = Vector2(0.8, 0.8)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "rotation", facing + deg_to_rad(40.0), 0.16).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.finished.connect(queue_free)

## 픽셀 검기: 번개 검처럼 전용 스프라이트가 있을 때 사용한다.
func setup_pixel(facing: float, rng: float, color: Color, texture_path: String, frames: int = 1, anim_fps: float = 12.0, pixel_snap: bool = true) -> void:
	add_to_group("vfx")
	_poly.visible = false
	_frames = maxi(frames, 1)
	_anim_fps = anim_fps
	_frame_t = 0.0

	_sprite = Sprite2D.new()
	add_child(_sprite)
	var tex: Texture2D = load(texture_path)
	_sprite.texture = tex
	_sprite.hframes = _frames
	_sprite.frame = 0
	_sprite.centered = true
	_sprite.modulate = Color(color.r, color.g, color.b, 0.96)
	if tex != null:
		var fw: float = float(tex.get_width()) / float(_frames)
		_sprite.scale = Vector2(rng / fw, rng / fw)
		_sprite.position = Vector2(rng * 0.52, 0.0)
	if pixel_snap:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	rotation = facing - deg_to_rad(34.0)
	scale = Vector2(0.82, 0.82)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "rotation", facing + deg_to_rad(34.0), 0.18).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "scale", Vector2(1.10, 1.10), 0.18)
	t.tween_property(self, "modulate:a", 0.0, 0.20)
	t.finished.connect(queue_free)

func _build(arc_deg: float, r_in: float, r_out: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var seg := 16
	var a0 := -deg_to_rad(arc_deg * 0.5)
	var a1 := deg_to_rad(arc_deg * 0.5)
	for i in range(seg + 1):
		var t: float = a0 + (a1 - a0) * float(i) / seg
		pts.append(Vector2(cos(t), sin(t)) * r_out)
	for i in range(seg + 1):
		var t: float = a1 + (a0 - a1) * float(i) / seg
		pts.append(Vector2(cos(t), sin(t)) * r_in)
	return pts
