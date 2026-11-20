class_name FinishLine
extends Node2D
## Línea de meta a cuadros, dibujada sobre la calzada en el checkpoint 0. Solo es visual.
## El eje x local es el sentido de la carrera; el y, de lado a lado de la pista.

const SQUARE: float = 12.0
const ROWS: int = 2  ## filas de cuadros a lo largo del avance

var left: float = 130.0  ## px de la línea central hacia la izquierda
var right: float = 130.0  ## y hacia la derecha


func _ready() -> void:
	z_index = 1  # por encima del suelo y de las marcas de derrape, por debajo de los coches


func _draw() -> void:
	var cols: int = ceili((left + right) / SQUARE)
	var y0: float = -left
	var x0: float = -SQUARE * ROWS / 2.0
	for r: int in ROWS:
		for c: int in cols:
			var w: float = minf(SQUARE, (left + right) - c * SQUARE)
			var color: Color = Color.WHITE if (r + c) % 2 == 0 else Color(0.1, 0.1, 0.1)
			draw_rect(Rect2(x0 + r * SQUARE, y0 + c * SQUARE, SQUARE, w), color)
	# Bordes para que se lea también sobre arena clara
	draw_rect(Rect2(x0, y0, SQUARE * ROWS, left + right), Color(0.05, 0.05, 0.05), false, 2.0)
