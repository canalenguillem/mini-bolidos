class_name BoostPad
extends Node2D
## Zona de turbo pintada en el suelo. El eje x local es el sentido de la carrera. Sin colisión: la pista dice
## si un punto está encima y el coche recibe un empujón si la pisa en ese sentido.

@export var half_length: float = 38.0
@export var half_width: float = 46.0
@export var boost_time: float = 0.9  ## s de turbo que da


func contains(global_pos: Vector2) -> bool:
	var p: Vector2 = to_local(global_pos)
	return absf(p.x) <= half_length and absf(p.y) <= half_width


func direction() -> Vector2:
	return global_transform.x


func _process(_delta: float) -> void:
	queue_redraw()  # las flechas avanzan


func _draw() -> void:
	var rect := Rect2(-half_length, -half_width, half_length * 2.0, half_width * 2.0)
	draw_rect(rect, Color(0.05, 0.25, 0.45, 0.85))
	var phase: float = fposmod(Time.get_ticks_msec() / 400.0, 1.0)
	for k: int in 3:
		var x: float = -half_length + fposmod((k + phase) / 3.0, 1.0) * half_length * 2.0
		var a: float = 0.35 + 0.65 * (1.0 - absf(x) / half_length)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 12.0, -half_width + 8.0), Vector2(x + 8.0, 0.0), Vector2(x - 12.0, half_width - 8.0),
			Vector2(x - 2.0, 0.0)]), Color(0.3, 0.9, 1.0, a))
	draw_rect(rect, Color(0.3, 0.9, 1.0), false, 2.0)
