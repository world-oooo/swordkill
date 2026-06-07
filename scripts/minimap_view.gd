extends Control
## 미니맵 패널 안에 방문한 방만 표시한다.
##
## GameManager.rooms에는 전체 맵 그래프가 들어 있지만, 이 UI는
## GameManager.visited_rooms에 기록된 방만 그린다. 아직 들어가지 않은 방은
## 표시하지 않아서 탐험 정보가 미리 노출되지 않는다.

var _minx: int = 0
var _miny: int = 0
var _maxx: int = 0
var _maxy: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.map_changed.connect(queue_redraw)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rooms: Dictionary = GameManager.rooms
	if rooms.is_empty() or not rooms.has(GameManager.current_id):
		_draw_current_marker(size * 0.5)
		return

	_calculate_bounds(rooms)
	_draw_visited_connections(rooms)
	_draw_visited_rooms(rooms)

func _calculate_bounds(rooms: Dictionary) -> void:
	_minx = 9999
	_miny = 9999
	_maxx = -9999
	_maxy = -9999
	for id in rooms.keys():
		var c: Vector2i = rooms[id].get("cell", Vector2i.ZERO)
		_minx = mini(_minx, c.x)
		_miny = mini(_miny, c.y)
		_maxx = maxi(_maxx, c.x)
		_maxy = maxi(_maxy, c.y)

func _draw_visited_connections(rooms: Dictionary) -> void:
	for id in rooms.keys():
		if not GameManager.is_visited(int(id)):
			continue
		var room: Dictionary = rooms[id]
		var from_pos: Vector2 = _cell_to_panel_pos(room.get("cell", Vector2i.ZERO))
		for dir in room.get("doors", {}).keys():
			var neighbor_id: int = int(room["doors"][dir])
			if neighbor_id <= int(id) or not GameManager.is_visited(neighbor_id):
				continue
			var neighbor_room: Dictionary = rooms[neighbor_id]
			var to_pos: Vector2 = _cell_to_panel_pos(neighbor_room.get("cell", Vector2i.ZERO))
			draw_line(from_pos, to_pos, Color(0.74, 0.54, 0.22, 0.62), 2.0)

func _draw_visited_rooms(rooms: Dictionary) -> void:
	for id in rooms.keys():
		if not GameManager.is_visited(int(id)):
			continue
		var room: Dictionary = rooms[id]
		var pos: Vector2 = _cell_to_panel_pos(room.get("cell", Vector2i.ZERO))
		if int(id) == GameManager.current_id:
			_draw_current_marker(pos)
		else:
			_draw_visited_marker(pos, str(room.get("type", "combat")))

func _cell_to_panel_pos(cell: Vector2i) -> Vector2:
	var cols: int = maxi(1, _maxx - _minx + 1)
	var rows: int = maxi(1, _maxy - _miny + 1)
	var pad: float = 18.0
	var usable := Vector2(maxf(1.0, size.x - pad * 2.0), maxf(1.0, size.y - pad * 2.0))
	var x_ratio: float = 0.5 if cols == 1 else float(cell.x - _minx) / float(cols - 1)
	var y_ratio: float = 0.5 if rows == 1 else float(cell.y - _miny) / float(rows - 1)
	return Vector2(pad + usable.x * x_ratio, pad + usable.y * y_ratio)

func _draw_visited_marker(pos: Vector2, room_type: String) -> void:
	var fill: Color = _visited_color(room_type)
	draw_circle(pos, 6.0, Color(0.08, 0.07, 0.05, 0.86))
	draw_circle(pos, 4.5, fill)
	draw_arc(pos, 7.5, 0.0, TAU, 20, Color(0.95, 0.72, 0.28, 0.82), 1.4)

func _draw_current_marker(pos: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	var glow_radius: float = 10.0 + pulse * 3.0
	draw_circle(pos, glow_radius, Color(0.35, 0.92, 1.0, 0.22))
	draw_circle(pos, 7.0, Color(0.08, 0.18, 0.25, 0.90))
	draw_circle(pos, 5.0, Color(0.20, 0.90, 1.0, 1.0))
	draw_circle(pos + Vector2(-1.5, -1.5), 2.0, Color(1.0, 1.0, 1.0, 0.95))
	draw_arc(pos, 12.0, 0.0, TAU, 28, Color(1.0, 0.86, 0.24, 0.90), 2.0)

func _visited_color(room_type: String) -> Color:
	match room_type:
		"start":
			return Color(0.54, 0.72, 1.0, 0.96)
		"shop":
			return Color(0.42, 0.96, 0.96, 0.96)
		"treasure":
			return Color(1.0, 0.84, 0.28, 0.96)
		"elite":
			return Color(0.84, 0.45, 1.0, 0.96)
		"boss":
			return Color(1.0, 0.36, 0.32, 0.96)
		"forge":
			return Color(1.0, 0.56, 0.22, 0.96)
		_:
			return Color(0.78, 0.74, 0.64, 0.96)
