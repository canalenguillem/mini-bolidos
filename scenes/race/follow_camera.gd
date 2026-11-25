class_name FollowCamera
extends Camera2D
## Sigue a un coche con suavizado y adelanto, y le da vida: zoom según la velocidad, golpe de zoom con el nitro
## y el miniturbo, se aleja en los saltos, tiembla en choques y aterrizajes, se inclina un poco en los derrapes,
## entra acercándose en la salida y se acerca al coche en la meta.

@export var target: Car:
	set(value):
		if target != null and target.crashed.is_connected(_on_target_crashed):
			target.crashed.disconnect(_on_target_crashed)
			target.landed.disconnect(_on_target_landed)
			target.drift_boosted.disconnect(_on_target_drift_boosted)
			target.boost_pad_hit.disconnect(_on_target_pad)
		target = value
		if target != null:
			target.crashed.connect(_on_target_crashed)
			target.landed.connect(_on_target_landed)
			target.drift_boosted.connect(_on_target_drift_boosted)
			target.boost_pad_hit.connect(_on_target_pad)
@export var lookahead_time: float = 0.4  ## s de velocidad que se adelanta la cámara
@export var max_lookahead: float = 170.0  ## px
@export_group("Zoom")
@export var base_zoom: float = 1.4  ## zoom general: más alto = coches más grandes en pantalla (y se ve menos pista)
@export var zoom_out_speed: float = 480.0  ## px/s a los que se llega al zoom mínimo
@export var min_zoom: float = 0.85  ## zoom a máxima velocidad (1 = sin alejarse)
@export var zoom_smoothing: float = 3.0
@export var boost_zoom: float = 0.92  ## factor extra con nitro o miniturbo (se aleja: sensación de velocidad)
@export var air_zoom: float = 0.88  ## factor extra en lo más alto de un salto
@export var intro_zoom: float = 1.7  ## zoom con el que empieza la cuenta atrás (luego se abre)
@export var finish_zoom: float = 1.3  ## zoom al cruzar la meta
@export_group("Sacudida")
@export var shake_min_impact: float = 200.0  ## px/s de impacto por debajo de los cuales no tiembla
@export var shake_max_impact: float = 600.0  ## impacto que da la sacudida máxima
@export var max_shake: float = 14.0  ## px de desplazamiento máximo
@export var shake_decay: float = 2.5  ## trauma que se pierde por segundo
@export var landing_trauma: float = 0.45  ## sacudida al aterrizar de un salto largo
@export var boost_trauma: float = 0.25  ## sacudida al activar el nitro o un miniturbo
@export_group("Derrape")
@export var drift_tilt: float = 0.03  ## rad de inclinación máxima de la cámara al derrapar (0 = sin inclinación)
@export var tilt_smoothing: float = 5.0

var trauma: float = 0.0  ## 0..1, la sacudida crece con su cuadrado
var finish_focus: bool = false  ## la carrera lo activa al cruzar la meta

var _rng := RandomNumberGenerator.new()
var _was_boosting: bool = false


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	ignore_rotation = false
	_rng.randomize()
	if target != null:
		global_position = target.global_position


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Empieza muy cerca del coche; el suavizado normal lo abre durante la cuenta atrás.
func intro() -> void:
	zoom = Vector2(intro_zoom, intro_zoom) * base_zoom
	if target != null:
		global_position = target.global_position
		reset_smoothing()


## Zoom que le corresponde ahora mismo (sin suavizar).
func wanted_zoom() -> float:
	if target == null:
		return 1.0
	if finish_focus:
		return finish_zoom
	var speed_t: float = clampf(target.velocity.length() / zoom_out_speed, 0.0, 1.0)
	var wanted: float = lerpf(1.0, min_zoom, speed_t)
	if target.is_boosting() or target.is_drift_boosting():
		wanted *= boost_zoom
	return wanted * lerpf(1.0, air_zoom, target.jump_height())


func _process(delta: float) -> void:
	if target == null:
		return
	var ahead: Vector2 = (target.velocity * lookahead_time).limit_length(max_lookahead)
	global_position = target.global_position + (Vector2.ZERO if finish_focus else ahead)

	var wanted: float = wanted_zoom() * base_zoom
	zoom = zoom.lerp(Vector2(wanted, wanted), 1.0 - exp(-zoom_smoothing * delta))

	if target.is_boosting() and not _was_boosting:
		add_trauma(boost_trauma)
	_was_boosting = target.is_boosting()

	# Inclinación en los derrapes: hacia el lado al que desliza el coche
	var tilt: float = 0.0
	if target.drifting:
		tilt = clampf(target.velocity.dot(target.transform.y) / 300.0, -1.0, 1.0) * drift_tilt
	rotation = lerp_angle(rotation, tilt, 1.0 - exp(-tilt_smoothing * delta))

	trauma = maxf(trauma - shake_decay * delta, 0.0)
	var amplitude: float = max_shake * trauma * trauma
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * amplitude


func _on_target_crashed(impact: float) -> void:
	if impact < shake_min_impact:
		return
	add_trauma(inverse_lerp(shake_min_impact, shake_max_impact, impact) * 0.7 + 0.3)


func _on_target_landed(air_time: float) -> void:
	add_trauma(landing_trauma * clampf(air_time / 0.7, 0.3, 1.0))


func _on_target_drift_boosted(_level: int) -> void:
	add_trauma(boost_trauma)


func _on_target_pad() -> void:
	add_trauma(boost_trauma)
