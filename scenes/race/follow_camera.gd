class_name FollowCamera
extends Camera2D
## Sigue a un coche con suavizado y adelanto en la dirección de su velocidad.

@export var target: Car
@export var lookahead_time: float = 0.35  ## s de velocidad que se adelanta la cámara
@export var max_lookahead: float = 160.0  ## px


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	if target != null:
		global_position = target.global_position


func _process(_delta: float) -> void:
	if target == null:
		return
	var ahead: Vector2 = (target.velocity * lookahead_time).limit_length(max_lookahead)
	global_position = target.global_position + ahead
