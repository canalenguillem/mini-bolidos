class_name Car
extends CharacterBody2D
## Coche arcade cenital. Mira hacia +X. No sabe quién lo conduce: usa su Controller.

signal crashed(impact: float)
signal reset_requested  ## el piloto pide reaparecer (tecla R)

@export var data: CarData
@export_group("Tuning")
@export var turn_speed_ref: float = 220.0  ## velocidad a la que el giro llega al 100 %
@export var drift_grip_factor: float = 0.35  ## fracción del agarre durante el derrape
@export var wall_speed_keep: float = 0.55  ## fracción de velocidad que se conserva al chocar con una pared
@export var car_bump_impulse: float = 140.0
@export var barrel_push: float = 0.9  ## fracción del impacto que se transmite a los cuerpos rígidos (barriles)
@export var barrel_drag: float = 0.15  ## velocidad que se pierde al empujar uno de frente
@export var nitro_accel_mult: float = 1.5  ## multiplicador de aceleración con nitro

var stats: CarStats
var track: Track  ## lo asigna la pista o RaceManager
var rubber_band: float = 1.0  ## solo coches IA (0.92…1.08)
var nitro_charges: int = 0
var locked: bool = false  ## bloqueado (cuenta atrás, fin de carrera): ignora el input
var current_surface: SurfaceData
var controller: CarController
var _nitro_time_left: float = 0.0
var _default_surface: SurfaceData = preload("res://data/surfaces/asphalt.tres")


func _ready() -> void:
	add_to_group("cars")
	controller = $Controller as CarController
	controller.owner_car = self
	current_surface = _default_surface
	if stats == null and data != null:
		setup(data, {})


func setup(car_data: CarData, levels: Dictionary, upgrades: Dictionary = {}) -> void:
	data = car_data
	stats = CarStats.build(car_data, levels, upgrades)
	nitro_charges = stats.nitro_charges
	if has_node("Body"):
		set_body_color(car_data.color)


func is_boosting() -> bool:
	return _nitro_time_left > 0.0


## Fracción de nitro activo restante (1 al activarlo, 0 al acabar).
func nitro_fraction() -> float:
	return _nitro_time_left / stats.nitro_duration if stats != null and stats.nitro_duration > 0.0 else 0.0


## Color de la carrocería (placeholder visual).
func set_body_color(color: Color) -> void:
	($Body as Polygon2D).color = color


## Coloca el coche y lo deja parado (reaparición).
func teleport(xform: Transform2D) -> void:
	global_transform = xform
	velocity = Vector2.ZERO
	_nitro_time_left = 0.0


func _physics_process(delta: float) -> void:
	if stats == null:
		return
	var input: DriveInput = DriveInput.new() if locked else controller.get_input(delta)
	if input.reset:
		reset_requested.emit()
	var surface: SurfaceData = track.get_surface_at(global_position) if track else _default_surface
	current_surface = surface

	var fwd: float = velocity.dot(transform.x)
	var lat: float = velocity.dot(transform.y)

	# --- Nitro ---
	if input.nitro and nitro_charges > 0 and _nitro_time_left <= 0.0:
		nitro_charges -= 1
		_nitro_time_left = stats.nitro_duration
	var boosting: bool = _nitro_time_left > 0.0
	_nitro_time_left = maxf(_nitro_time_left - delta, 0.0)

	# --- Longitudinal ---
	var speed_mult: float = lerpf(surface.speed_mult, 1.0, stats.offroad)
	var drag_mult: float = lerpf(surface.drag_mult, 1.0, stats.offroad)
	var grip_mult: float = lerpf(surface.grip_mult, 1.0, stats.offroad)
	var max_speed: float = stats.max_speed * speed_mult * rubber_band \
			* (stats.nitro_boost if boosting else 1.0)
	var accel: float = stats.acceleration * input.throttle * (nitro_accel_mult if boosting else 1.0)
	if boosting:
		accel = maxf(accel, stats.acceleration * nitro_accel_mult)  # el nitro empuja sin pisar el acelerador
	if input.brake > 0.0:
		# Si va hacia delante frena; si está casi parado, marcha atrás
		accel -= (stats.braking if fwd > 10.0 else stats.acceleration * 0.5) * input.brake
	fwd += accel * delta
	fwd -= fwd * stats.drag * drag_mult * delta
	fwd = clampf(fwd, -stats.max_reverse, max_speed)

	# --- Giro (no se gira parado; la marcha atrás invierte el volante) ---
	var speed_factor: float = clampf(absf(fwd) / turn_speed_ref, 0.0, 1.0)
	rotation += input.steer * stats.steering * speed_factor * signf(fwd) * delta

	# --- Agarre lateral / derrape ---
	var drifting: bool = input.brake > 0.0 and absf(input.steer) > 0.5 and fwd > turn_speed_ref
	var grip: float = stats.grip * grip_mult * (drift_grip_factor if drifting else 1.0)
	lat = lerpf(lat, 0.0, clampf(grip * delta, 0.0, 1.0))

	# Recompone con la NUEVA orientación (el morro ya ha girado)
	var basis := Transform2D(rotation, Vector2.ZERO)
	velocity = basis.x * fwd + basis.y * lat
	var pre_velocity: Vector2 = velocity
	move_and_slide()
	_handle_collisions(pre_velocity)


func _handle_collisions(pre_velocity: Vector2) -> void:
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		var other: Object = col.get_collider()
		var impact: float = maxf(-pre_velocity.dot(col.get_normal()), 0.0)
		if other is Car:
			var push: Vector2 = -col.get_normal() * car_bump_impulse
			(other as Car).velocity += push
			velocity -= push * 0.5
		elif other is RigidBody2D:
			var body := other as RigidBody2D
			body.apply_central_impulse(-col.get_normal() * impact * body.mass * barrel_push)
			velocity *= 1.0 - barrel_drag * clampf(impact / maxf(pre_velocity.length(), 1.0), 0.0, 1.0)
		elif impact > 0.0 and pre_velocity.length() > 0.0:
			# Pérdida proporcional al ángulo: de frente se conserva wall_speed_keep, rozando casi todo
			var head_on: float = clampf(impact / pre_velocity.length(), 0.0, 1.0)
			velocity *= lerpf(1.0, wall_speed_keep, head_on)
		crashed.emit(impact)
