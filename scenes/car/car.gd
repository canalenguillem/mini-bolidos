class_name Car
extends CharacterBody2D
## Coche arcade cenital. Mira hacia +X. No sabe quién lo conduce: usa su Controller.

signal crashed(impact: float)
signal reset_requested  ## el piloto pide reaparecer (tecla R)
signal drift_boosted(level: int)  ## miniturbo al soltar un derrape cargado (nivel 1 o 2)
signal jumped
signal landed(air_time: float)

@export var data: CarData
@export_group("Tuning")
@export var turn_speed_ref: float = 220.0  ## velocidad a la que el giro llega al 100 %
@export var drift_grip_factor: float = 0.35  ## fracción del agarre durante el derrape
@export var normal_grip_mult: float = 1.6  ## agarre en conducción normal (más = menos deslizamiento en las curvas)
@export var wall_speed_keep: float = 0.55  ## fracción de velocidad que se conserva al chocar con una pared
@export var car_bump_impulse: float = 140.0
@export var barrel_push: float = 0.9  ## fracción del impacto que se transmite a los cuerpos rígidos (barriles)
@export var barrel_drag: float = 0.15  ## velocidad que se pierde al empujar uno de frente
@export var steer_speed_mult: float = 0.7  ## fracción del giro que se conserva a velocidad máxima (a poca velocidad, el 100 %)
@export var nitro_accel_mult: float = 1.5  ## multiplicador de aceleración con nitro
@export_group("Derrape")
@export var drift_min_speed_frac: float = 0.45  ## fracción de la velocidad máxima a partir de la cual el freno de mano derrapa
@export var drift_steer_boost: float = 1.25  ## giro extra mientras derrapa
@export var drift_brake_frac: float = 0.12  ## fracción del freno que aplica el freno de mano (pierde poca velocidad)
@export var drift_slide_speed: float = 40.0  ## px/s de velocidad lateral mínima para que el derrape cargue el miniturbo
@export var drift_charge_times: Array[float] = [0.7, 1.6]  ## s derrapando para el miniturbo de nivel 1 y 2
@export var drift_boost_times: Array[float] = [0.6, 1.1]  ## s que dura el miniturbo de cada nivel
@export var drift_boost_mult: float = 1.14  ## velocidad máxima durante el miniturbo
@export var drift_boost_accel: float = 1.3  ## empuje mínimo durante el miniturbo (× aceleración)
@export_group("Salto")
@export var jump_min_speed: float = 180.0  ## px/s mínimos sobre una rampa para despegar
@export var jump_time_at_max: float = 0.7  ## s en el aire saliendo a velocidad máxima
@export var jump_height_scale: float = 0.45  ## cuánto crece el coche en lo más alto del salto
@export var air_steer_frac: float = 0.15  ## fracción del giro que queda en el aire

var stats: CarStats
var track: Track  ## lo asigna la pista o RaceManager
var rubber_band: float = 1.0  ## solo coches IA (0.92…1.08)
var nitro_charges: int = 0
var locked: bool = false  ## bloqueado (cuenta atrás, fin de carrera): ignora el input
var current_surface: SurfaceData
var controller: CarController
var ghost: bool = false  ## coche remoto (online): sin física, sigue la posición que llega por red
var _fx: CarFx
var _audio: CarAudio
var ghost_delay: float = 0.12  ## s de retraso con los que se dibuja un fantasma, para poder interpolar entre dos paquetes
var ghost_max_extrapolation: float = 0.25  ## s máximos que sigue con su velocidad si no llegan paquetes
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0  ## las pruebas lo sustituyen
var _snapshots: Array[Dictionary] = []  ## paquetes recibidos: {t (hora del emisor), pos, rot, vel}
var _offsets: Array[float] = []  ## llegada - hora del emisor, de los últimos paquetes
var _offset: float = 0.0  ## el menor de ellos: la hora del emisor que corresponde a "ahora" sin jitter
var _fx_accum: float = 0.0
var _name_tag: Label
var _nitro_time_left: float = 0.0
var drifting: bool = false
var drift_charge: float = 0.0  ## s acumulados en el derrape en curso
var airborne: bool:
	get:
		return _air_left > 0.0
var _drift_boost_left: float = 0.0
var _air_left: float = 0.0
var _air_total: float = 0.0
var _ground_mask: int = -1  ## máscara de colisión en el suelo (en el aire no choca con coches ni obstáculos)
var _default_surface: SurfaceData = preload("res://data/surfaces/asphalt.tres")


func _ready() -> void:
	add_to_group("cars")
	controller = $Controller as CarController
	_fx = get_node_or_null("Fx") as CarFx
	_audio = get_node_or_null("Audio") as CarAudio
	controller.owner_car = self
	current_surface = _default_surface
	if stats == null and data != null:
		setup(data, {})


func setup(car_data: CarData, levels: Dictionary, upgrades: Dictionary = {}) -> void:
	data = car_data
	stats = CarStats.build(car_data, levels, upgrades)
	nitro_charges = stats.nitro_charges
	if car_data.sprite != null:
		set_sprite(car_data.sprite)
	elif has_node("Body"):
		set_body_color(car_data.color)


## Convierte el coche en un fantasma online: no choca ni simula; lo mueve net_update().
func make_ghost() -> void:
	ghost = true
	collision_layer = 0
	collision_mask = 0


## Coche online que sí simula (el tuyo o un bot que gobierna el anfitrión): no choca con otros coches.
func make_online_local() -> void:
	collision_layer = 2  # sigue en la capa de coches: los checkpoints solo detectan esa capa
	collision_mask = 9  # pero solo choca con paredes (1) y obstáculos (4), no con otros coches


## Posición de un coche remoto que acaba de llegar por red (~20 veces por segundo). `ts` es la hora del emisor
## (segundos): así los paquetes quedan igual de separados que cuando se enviaron, aunque lleguen con jitter.
## Sin `ts` se usa la hora de llegada. El fantasma se dibuja `ghost_delay` segundos por detrás para poder interpolar.
func net_update(pos: Vector2, rot: float, vel: Vector2, ts: float = -1.0) -> void:
	var now: float = clock.call()
	var stamp: float = now
	if ts >= 0.0:
		stamp = ts
		_offsets.append(now - ts)
		if _offsets.size() > 60:
			_offsets.pop_front()
		_offset = _offsets.min()  # el paquete menos retrasado fija la correspondencia entre relojes
	if _snapshots.is_empty():
		global_position = pos
		rotation = rot
	_snapshots.append({"t": stamp, "pos": pos, "rot": rot, "vel": vel})
	if _snapshots.size() > 40:
		_snapshots.pop_front()


## Texto flotante con el nombre del piloto.
func set_name_tag(text: String) -> void:
	if _name_tag == null:
		_name_tag = Label.new()
		_name_tag.top_level = true
		_name_tag.z_index = 20
		_name_tag.add_theme_font_size_override("font_size", 13)
		_name_tag.add_theme_color_override("font_outline_color", Color.BLACK)
		_name_tag.add_theme_constant_override("outline_size", 4)
		add_child(_name_tag)
	_name_tag.text = text
	_name_tag.reset_size()


func _process(delta: float) -> void:
	if ghost:
		_ghost_render(delta)  # a la cadencia de la pantalla, no de la física: así se ve fluido a 144 Hz
	if _name_tag != null:
		_name_tag.global_position = global_position + Vector2(-_name_tag.size.x / 2.0, -34.0)


## Dibuja el fantasma en su instante de render (ahora - ghost_delay) a partir de los paquetes recibidos.
func _ghost_render(delta: float) -> void:
	if _snapshots.is_empty():
		return  # aún no ha llegado ninguna posición: se queda en su puesto de la parrilla
	var render_t: float = float(clock.call()) - _offset - ghost_delay  # en la línea de tiempo del emisor
	var state: Dictionary = _sample(render_t)
	global_position = state["pos"]
	rotation = state["rot"]
	velocity = state["vel"]
	_fx_accum += delta
	if _fx_accum < 1.0 / 60.0:
		return  # efectos y sonido a 60 Hz como el resto, aunque la pantalla sea de 144
	var dt: float = _fx_accum
	_fx_accum = 0.0
	var fwd: float = velocity.dot(transform.x)
	var lat: float = velocity.dot(transform.y)
	var surface: SurfaceData = track.get_surface_at(global_position) if track else _default_surface
	current_surface = surface
	_check_ramp()  # los fantasmas también saltan (cada cliente lo calcula con las rampas de su pista)
	if airborne:
		_air_tick(dt)
		lat = 0.0
		surface = _default_surface
	if _fx != null:
		_fx.update_state(dt, fwd, lat, 0.0, surface, false)
	if _audio != null and stats != null:
		_audio.update_state(dt, fwd, lat, false, stats.max_speed)


## Estado interpolado en el instante t; si t es posterior al último paquete, sigue con su velocidad un tiempo limitado.
func _sample(t: float) -> Dictionary:
	var first: Dictionary = _snapshots[0]
	var last: Dictionary = _snapshots[_snapshots.size() - 1]
	if t <= float(first["t"]):
		return first
	if t >= float(last["t"]):
		var ahead: float = minf(t - float(last["t"]), ghost_max_extrapolation)
		return {"pos": (last["pos"] as Vector2) + (last["vel"] as Vector2) * ahead, "rot": last["rot"], "vel": last["vel"]}
	for i: int in range(_snapshots.size() - 1, 0, -1):
		var b: Dictionary = _snapshots[i]
		var a: Dictionary = _snapshots[i - 1]
		if float(a["t"]) <= t:
			var span: float = float(b["t"]) - float(a["t"])
			var f: float = 0.0 if span <= 0.0 else (t - float(a["t"])) / span
			return {
				"pos": (a["pos"] as Vector2).lerp(b["pos"], f),
				"rot": lerp_angle(float(a["rot"]), float(b["rot"]), f),
				"vel": (a["vel"] as Vector2).lerp(b["vel"], f),
			}
	return first


func is_boosting() -> bool:
	return _nitro_time_left > 0.0


func is_drift_boosting() -> bool:
	return _drift_boost_left > 0.0


## Nivel de miniturbo ya cargado en el derrape en curso (0, 1 o 2).
func drift_level() -> int:
	var level: int = 0
	for t: float in drift_charge_times:
		if drift_charge >= t:
			level += 1
	return level


## Altura del salto, 0 (suelo) a 1 (punto más alto).
func jump_height() -> float:
	return sin(PI * (1.0 - _air_left / _air_total)) if airborne and _air_total > 0.0 else 0.0


## Despega (lo llaman las rampas). Cuanto más rápido, más tiempo en el aire. Devuelve si saltó.
func launch(strength: float = 1.0) -> bool:
	if airborne or stats == null:
		return false
	var speed: float = velocity.length()
	if speed < jump_min_speed:
		return false
	_air_total = clampf(speed / stats.max_speed, 0.45, 1.3) * jump_time_at_max * strength
	_air_left = _air_total
	if not ghost:
		_ground_mask = collision_mask
		collision_mask &= ~10  # vuela por encima de coches (capa 2) y obstáculos (capa 4)
	_end_drift(false)
	jumped.emit()
	return true


func _check_ramp() -> void:
	if airborne or track == null:
		return
	var ramp: Ramp = track.ramp_at(global_position)
	if ramp != null and velocity.dot(ramp.direction()) >= jump_min_speed:
		launch(ramp.strength)


## Avanza el salto: escala el coche y su sombra, y aterriza al acabar.
func _air_tick(delta: float) -> void:
	_air_left = maxf(_air_left - delta, 0.0)
	_show_height(jump_height())
	if _air_left <= 0.0:
		if _ground_mask >= 0:
			collision_mask = _ground_mask
			_ground_mask = -1
		if _fx != null:
			_fx.land_burst()
		if _audio != null:
			_audio.on_land()
		landed.emit(_air_total)


func _show_height(h: float) -> void:
	var k: float = 1.0 + jump_height_scale * h
	($Sprite as Node2D).scale = Vector2(0.5, 0.5) * k
	($Body as Node2D).scale = Vector2.ONE * k
	($Nose as Node2D).scale = Vector2.ONE * k
	if _fx != null:
		_fx.scale = Vector2.ONE * k
	var shadow: Node2D = $Shadow
	shadow.visible = h > 0.01
	shadow.global_position = global_position + Vector2(14.0, 20.0) * h


func _cancel_air() -> void:
	_air_left = 0.0
	if _ground_mask >= 0:
		collision_mask = _ground_mask
		_ground_mask = -1
	_show_height(0.0)


## Termina el derrape; si estaba cargado y `reward`, da el miniturbo.
func _end_drift(reward: bool) -> void:
	var level: int = drift_level()
	drifting = false
	drift_charge = 0.0
	if reward and level > 0:
		_drift_boost_left = drift_boost_times[mini(level, drift_boost_times.size()) - 1]
		if _audio != null:
			_audio.on_drift_boost()
		drift_boosted.emit(level)


## Fracción de nitro activo restante (1 al activarlo, 0 al acabar).
func nitro_fraction() -> float:
	return _nitro_time_left / stats.nitro_duration if stats != null and stats.nitro_duration > 0.0 else 0.0


## Sustituye el placeholder de polígonos por un sprite (que mira hacia arriba: ya viene rotado en la escena).
func set_sprite(texture: Texture2D) -> void:
	($Sprite as Sprite2D).texture = texture
	$Sprite.visible = texture != null
	$Body.visible = texture == null
	$Nose.visible = texture == null


## Color de la carrocería (placeholder visual, solo si no hay sprite).
func set_body_color(color: Color) -> void:
	($Body as Polygon2D).color = color


## Coloca el coche y lo deja parado (reaparición).
func teleport(xform: Transform2D) -> void:
	global_transform = xform
	velocity = Vector2.ZERO
	_nitro_time_left = 0.0
	_drift_boost_left = 0.0
	_end_drift(false)
	_cancel_air()
	if _fx != null:
		_fx.reset()


func _physics_process(delta: float) -> void:
	if stats == null:
		return
	if ghost:
		return  # su movimiento lo dibuja _process (_ghost_render)
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
	var turbo: bool = _drift_boost_left > 0.0
	_drift_boost_left = maxf(_drift_boost_left - delta, 0.0)

	# --- Salto: en el aire no hay acelerador, freno ni agarre; el coche sigue su trayectoria ---
	_check_ramp()
	if airborne:
		rotation += input.steer * stats.steering * air_steer_frac * delta
		var air_velocity: Vector2 = velocity
		move_and_slide()
		_handle_collisions(air_velocity)
		_air_tick(delta)
		if _fx != null:
			_fx.set_drift_level(0)
			_fx.update_state(delta, fwd, 0.0, input.steer, _default_surface, boosting or turbo)
		if _audio != null:
			_audio.update_state(delta, fwd, 0.0, boosting, stats.max_speed)
		return

	# --- Giro (no se gira parado; la marcha atrás invierte el volante) ---
	var speed_factor: float = clampf(absf(fwd) / turn_speed_ref, 0.0, 1.0)
	var steer_scale: float = lerpf(1.0, steer_speed_mult, clampf(absf(fwd) / maxf(stats.max_speed, 1.0), 0.0, 1.0))
	if drifting:
		steer_scale *= drift_steer_boost
	rotation += input.steer * stats.steering * steer_scale * speed_factor * signf(fwd) * delta
	# El morro ya ha girado pero el coche sigue yendo hacia donde iba: lo que queda de lado es deslizamiento,
	# que el agarre irá frenando. (Antes la velocidad giraba al instante con el morro y nunca deslizaba.)
	fwd = velocity.dot(transform.x)
	lat = velocity.dot(transform.y)

	# --- Longitudinal ---
	var speed_mult: float = lerpf(surface.speed_mult, 1.0, stats.offroad)
	var drag_mult: float = lerpf(surface.drag_mult, 1.0, stats.offroad)
	var grip_mult: float = lerpf(surface.grip_mult, 1.0, stats.offroad)
	var max_speed: float = stats.max_speed * speed_mult * rubber_band \
			* (stats.nitro_boost if boosting else 1.0) * (drift_boost_mult if turbo else 1.0)
	var accel: float = stats.acceleration * input.throttle * (nitro_accel_mult if boosting else 1.0)
	if boosting:
		accel = maxf(accel, stats.acceleration * nitro_accel_mult)  # el nitro empuja sin pisar el acelerador
	elif turbo:
		accel = maxf(accel, stats.acceleration * drift_boost_accel)
	if input.brake > 0.0:
		# Si va hacia delante frena; si está casi parado, marcha atrás
		accel -= (stats.braking if fwd > 10.0 else stats.acceleration * 0.5) * input.brake
	elif input.drift and fwd > 10.0:
		accel -= stats.braking * drift_brake_frac  # el freno de mano apenas frena
	fwd += accel * delta
	fwd -= fwd * stats.drag * drag_mult * delta
	fwd = clampf(fwd, -stats.max_reverse, max_speed)

	# --- Derrape: freno de mano + volante (con histéresis), o frenar girando a alta velocidad ---
	var steer_abs: float = absf(input.steer)
	var drift_speed: float = stats.max_speed * drift_min_speed_frac
	var was_drifting: bool = drifting
	var hand: bool = input.drift and (
			(drifting and fwd > drift_speed * 0.6 and steer_abs > 0.1) or (fwd > drift_speed and steer_abs > 0.3))
	var braking_drift: bool = input.brake > 0.0 and steer_abs > 0.5 and fwd > turn_speed_ref
	drifting = hand or braking_drift
	if drifting:
		if absf(lat) > drift_slide_speed:
			drift_charge += delta
	elif was_drifting:
		_end_drift(true)

	# --- Agarre lateral: frena el deslizamiento (mucho en conducción normal, poco derrapando) ---
	var grip: float = stats.grip * grip_mult * (drift_grip_factor if drifting else normal_grip_mult)
	lat = lerpf(lat, 0.0, clampf(grip * delta, 0.0, 1.0))

	velocity = transform.x * fwd + transform.y * lat
	var pre_velocity: Vector2 = velocity
	move_and_slide()
	_handle_collisions(pre_velocity)
	if _fx != null:
		_fx.set_drift_level(drift_level() if drifting else 0)
		_fx.update_state(delta, fwd, lat, input.steer, surface, boosting or turbo)
	if _audio != null:
		_audio.update_state(delta, fwd, lat, boosting, max_speed)


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
		if _audio != null:
			_audio.on_crash(impact)
		crashed.emit(impact)
