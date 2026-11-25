class_name NitroPickup
extends Node2D
## Bidón de nitro que se recoge al pasar por encima (+1 carga). Reaparece al cabo de un rato. Sin colisión.

signal taken

@export var radius: float = 42.0  ## zona de recogida, generosa: bastante mayor que el dibujo
@export var respawn_time: float = 8.0

var available: bool = true
var _respawn_left: float = 0.0


func contains(global_pos: Vector2) -> bool:
	return global_position.distance_to(global_pos) <= radius


## Lo recoge un coche. Devuelve false si no estaba disponible.
func take() -> bool:
	if not available:
		return false
	available = false
	_respawn_left = respawn_time
	taken.emit()
	queue_redraw()
	return true


func _process(delta: float) -> void:
	if not available:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			available = true
	queue_redraw()


func _draw() -> void:
	if not available:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(0.3, 0.9, 1.0, 0.25), 2.0)  # hueco: aquí volverá
		return
	var pulse: float = 1.0 + 0.15 * sin(Time.get_ticks_msec() / 180.0)
	draw_circle(Vector2.ZERO, radius * 0.8 * pulse, Color(0.3, 0.9, 1.0, 0.16))  # halo: marca hasta dónde se coge
	draw_circle(Vector2.ZERO, 24.0 * pulse, Color(0.3, 0.9, 1.0, 0.3))
	draw_circle(Vector2.ZERO, 17.0, Color(0.1, 0.45, 0.9))
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 28, Color.WHITE, 2.5)
	# una "N" blanca
	draw_polyline(PackedVector2Array([Vector2(-6, 8), Vector2(-6, -8), Vector2(6, 8), Vector2(6, -8)]), Color.WHITE, 3.0)
