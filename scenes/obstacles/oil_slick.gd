class_name OilSlick
extends Node2D
## Mancha de aceite: quien la pisa pierde casi todo el agarre un momento. Sin colisión.

@export var radius: float = 26.0
@export var slip_time: float = 0.8  ## s sin agarre tras pisarla


func contains(global_pos: Vector2) -> bool:
	return global_position.distance_to(global_pos) <= radius


func _draw() -> void:
	var blob := PackedVector2Array()
	for i: int in 14:
		var a: float = TAU * i / 14.0
		blob.append(Vector2.from_angle(a) * radius * (0.82 + 0.18 * sin(a * 3.0 + 1.0)))
	draw_colored_polygon(blob, Color(0.04, 0.04, 0.06, 0.82))
	draw_circle(Vector2(-radius * 0.25, -radius * 0.2), radius * 0.22, Color(0.3, 0.3, 0.4, 0.5))  # brillo
