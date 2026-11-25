class_name Ramp
extends Node2D
## Rampa de salto. El eje x local es el sentido de la carrera. No tiene colisión: la pista dice si un punto
## está encima (`contains`) y el coche despega si pasa en ese sentido con velocidad suficiente.

@export var half_length: float = 22.0  ## semilargo en el sentido de la carrera (px)
@export var half_width: float = 140.0  ## semiancho, de lado a lado de la calzada (px)
@export var strength: float = 1.0  ## multiplica el tiempo en el aire


func _ready() -> void:
	z_index = 1


func contains(global_pos: Vector2) -> bool:
	var p: Vector2 = to_local(global_pos)
	return absf(p.x) <= half_length and absf(p.y) <= half_width


func direction() -> Vector2:
	return global_transform.x


func _draw() -> void:
	var rect := Rect2(-half_length, -half_width, half_length * 2.0, half_width * 2.0)
	draw_rect(rect, Color(0.45, 0.3, 0.16))
	# Galones amarillos apuntando en el sentido de la carrera
	var step: float = 28.0
	var y: float = -half_width + step / 2.0
	while y < half_width:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-half_length + 6.0, y - 9.0), Vector2(half_length - 6.0, y), Vector2(-half_length + 6.0, y + 9.0),
			Vector2(-half_length + 14.0, y)]), Color(1, 0.85, 0.2))
		y += step
	draw_rect(Rect2(half_length - 5.0, -half_width, 5.0, half_width * 2.0), Color(0.95, 0.95, 0.9))  # borde de despegue
	draw_rect(rect, Color(0.15, 0.1, 0.05), false, 2.0)
