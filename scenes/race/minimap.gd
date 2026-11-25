class_name Minimap
extends Control
## Minimapa: el trazado de la pista y un punto por coche. Solo dibuja lo que le pasan.

const MARGIN: float = 8.0

var _points: PackedVector2Array = []  ## trazado ya en coordenadas del minimapa
var _origin: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _dots: Array = []  ## [{pos: Vector2 (mundo), me: bool}]


## Trazado de la pista en coordenadas del mundo (cerrado o no).
func setup(world_points: PackedVector2Array) -> void:
	_points = PackedVector2Array()
	if world_points.is_empty():
		queue_redraw()
		return
	var bounds := Rect2(world_points[0], Vector2.ZERO)
	for p: Vector2 in world_points:
		bounds = bounds.expand(p)
	var room: Vector2 = size - Vector2(MARGIN, MARGIN) * 2.0
	_scale = minf(room.x / maxf(bounds.size.x, 1.0), room.y / maxf(bounds.size.y, 1.0))
	_origin = bounds.position - (room / _scale - bounds.size) / 2.0  # centrado
	for p: Vector2 in world_points:
		_points.append(to_map(p))
	queue_redraw()


func to_map(world: Vector2) -> Vector2:
	return (world - _origin) * _scale + Vector2(MARGIN, MARGIN)


func set_dots(dots: Array) -> void:
	_dots = dots
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	if _points.size() >= 2:
		draw_polyline(_points, Color(0, 0, 0, 0.8), 6.0, true)
		draw_polyline(_points, Color(0.9, 0.9, 0.9), 3.0, true)
		draw_circle(_points[0], 4.0, Color(0.2, 0.2, 0.2))  # meta
	for dot: Dictionary in _dots:
		if not bool(dot.get("me", false)):
			draw_circle(to_map(dot["pos"]), 4.0, Color(0.35, 0.7, 1.0))
	for dot: Dictionary in _dots:  # el jugador encima de todos
		if bool(dot.get("me", false)):
			draw_circle(to_map(dot["pos"]), 6.5, Color.BLACK)
			draw_circle(to_map(dot["pos"]), 5.0, Color(1, 0.85, 0.2))
