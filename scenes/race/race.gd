class_name RaceManager
extends Node
## Gestiona la carrera: cuenta atrás → carrera → fin. Coches, vueltas, posiciones y reaparición.

enum State { COUNTDOWN, RACING, FINISHED }

signal state_changed(new_state: State)

const CAR_SCENE: PackedScene = preload("res://scenes/car/car.tscn")
const GO_TEXT_TIME: float = 0.8  ## s que se muestra "¡YA!"
const DIFFICULTY_SKILL: Array[float] = [0.9, 1.0, 1.08]

@export var track_data: TrackData
@export var car_data: CarData
@export var rivals: Array[RivalData] = []
@export_enum("Fácil", "Normal", "Difícil") var difficulty: int = 1
@export var player_slot: int = 3  ## puesto de parrilla del jugador (0 = primero)
@export var rival_engine_db: float = -7.0  ## el motor de los rivales suena más bajo que el tuyo
@export_group("Rubber banding")
@export var rubber_interval: float = 0.5  ## s entre recálculos
@export var rubber_range_cps: float = 2.0  ## ventaja en checkpoints para el efecto máximo
@export var rubber_max_delta: float = 0.08  ## ±8 % de velocidad máxima como mucho
@export var rubber_step: float = 0.02  ## cambio máximo por recálculo (suavizado)
@export_group("")
@export var countdown_seconds: float = 3.0
@export var stuck_seconds: float = 3.0  ## s casi parado antes de reaparecer
@export var stuck_speed: float = 25.0  ## px/s por debajo de los cuales cuenta como atascado
@export_group("Presentación")
@export var finish_slowmo: float = 0.3  ## velocidad del juego durante la cámara lenta de la meta (1 = sin cámara lenta)
@export var finish_slowmo_time: float = 0.9  ## s reales de cámara lenta antes de los resultados (0 = resultados al instante)
@export var wrong_way_seconds: float = 0.8  ## s yendo al revés antes de avisar
@export var stuck_hint_seconds: float = 1.2  ## s casi parado antes de sugerir "pulsa R"

const CONTROLS_HINT: String = "Flechas o WASD: conducir  ·  Espacio: nitro  ·  X: derrapar  ·  R: reaparecer"


## Un participante de la carrera.
class Racer extends RefCounted:
	var car: Car
	var tracker: LapTracker
	var display_name: String = ""
	var is_player: bool = false
	var stuck_time: float = 0.0
	var respawn_count: int = 0
	var finish_time: float = -1.0
	var lap_started: float = 0.0  ## race_time al empezar la vuelta en curso
	var slot: int = -1  ## puesto de parrilla (online)
	var user_id: int = -1
	var remote: bool = false  ## lo simula otro cliente
	var bot: bool = false


var state: State = State.COUNTDOWN
var race_time: float = 0.0
var track: Track
var racers: Array[Racer] = []
var player: Racer

var _countdown_left: float = 0.0
var _go_text_left: float = 0.0
var _rubber_left: float = 0.0
var _last_count: int = 0
var _wrong_way_time: float = 0.0
var _slowmo: bool = false

@onready var _cars_root: Node2D = $Cars
@onready var _camera: FollowCamera = $Camera2D
@onready var _hud: Hud = $HUD
@onready var _results: Results = $Results
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _sounds: RaceSounds = $Sounds


func _ready() -> void:
	if GameState.current_track != null:
		track_data = GameState.current_track
	for arg: String in OS.get_cmdline_user_args():  # godot … race.tscn -- --track=west_02
		if arg.begins_with("--track="):
			track_data = load("res://data/tracks/%s.tres" % arg.trim_prefix("--track=")) as TrackData
	GameState.current_track = track_data  # el premio y el mejor tiempo se aplican a esta pista
	track = track_data.scene.instantiate() as Track
	add_child(track)
	move_child(track, 0)
	track.checkpoint_passed.connect(_on_checkpoint_passed)
	_spawn_cars()
	Music.play(track_data.music)
	_camera.target = player.car
	_setup_presentation()
	_countdown_left = countdown_seconds
	_set_locked(true)
	_update_hud()


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			if _countdown_left <= 0.0:
				_begin_race()
			else:
				var count: int = ceili(_countdown_left)
				if count != _last_count:
					_last_count = count
					_sounds.beep()
				_hud.set_countdown(str(count))
		State.RACING:
			race_time += delta
			if _go_text_left > 0.0:
				_go_text_left -= delta
				if _go_text_left <= 0.0:
					_hud.set_countdown("")
			for racer: Racer in racers:
				_check_stuck(racer, delta)
				_check_bounds(racer)
			_rubber_left -= delta
			if _rubber_left <= 0.0:
				_rubber_left = rubber_interval
				_update_rubber_band()
	_update_hud()


# --- Preparación ---

## Cámara de entrada, minimapa y ayuda de controles. Común a la carrera local y a la online.
func _setup_presentation() -> void:
	_camera.intro()
	_hud.setup_minimap(track.line_points())
	_hud.set_hint(CONTROLS_HINT)



func _spawn_cars() -> void:
	var slots: Array[Transform2D] = track.start_transforms()
	var p_slot: int = clampi(player_slot, 0, slots.size() - 1)
	var rival_i: int = 0
	for slot_i: int in slots.size():
		if slot_i == p_slot:
			player = _add_racer(null, slots[slot_i])
		elif rival_i < rivals.size():
			_add_racer(rivals[rival_i], slots[slot_i])
			rival_i += 1


## rival == null → el jugador (PlayerController de la escena del coche); si no, un AIController.
func _add_racer(rival: RivalData, xform: Transform2D) -> Racer:
	var racer := Racer.new()
	racer.car = CAR_SCENE.instantiate() as Car
	racer.is_player = rival == null
	racer.display_name = "Jugador" if rival == null else rival.display_name
	if rival != null:
		var old: Node = racer.car.get_node("Controller")
		racer.car.remove_child(old)
		old.free()
		var ai := AIController.new()
		ai.name = "Controller"
		ai.configure(rival, DIFFICULTY_SKILL[difficulty])
		racer.car.add_child(ai)
	racer.tracker = LapTracker.new(track.checkpoint_count, track_data.laps)
	racer.tracker.lap_completed.connect(_on_lap_completed.bind(racer))
	_cars_root.add_child(racer.car)
	if rival == null:
		# El jugador usa su coche seleccionado con sus mejoras; los rivales, el coche base
		var chosen: CarData = GameState.selected_car_data() if GameState.selected_car_data() != null else car_data
		racer.car.setup(chosen, GameState.car_levels(chosen.id), GameState.upgrade_defs)
	else:
		(racer.car.get_node("Audio") as CarAudio).volume_offset_db = rival_engine_db
		racer.car.setup(car_data, {})
	racer.car.track = track
	racer.car.teleport(xform)
	if rival != null:
		if rival.sprite != null:
			racer.car.set_sprite(rival.sprite)
		else:
			racer.car.set_body_color(rival.color)
	racer.car.reset_requested.connect(_respawn.bind(racer))
	racers.append(racer)
	return racer


func _set_locked(locked: bool) -> void:
	for racer: Racer in racers:
		racer.car.locked = locked
		if locked:
			racer.car.velocity = Vector2.ZERO


func _begin_race() -> void:
	state = State.RACING
	_set_locked(false)
	_go_text_left = GO_TEXT_TIME
	_hud.set_countdown("¡YA!")
	_hud.set_hint("")
	_sounds.go()
	Events.race_started.emit()
	state_changed.emit(state)


# --- Vueltas y fin ---

func _on_checkpoint_passed(car: Car, index: int) -> void:
	if state != State.RACING:
		return
	for racer: Racer in racers:
		if racer.car == car:
			racer.tracker.passed(index)
			return


func _on_lap_completed(lap: int, racer: Racer) -> void:
	Events.lap_completed.emit(racer.car, lap)
	_announce_lap(lap, racer)
	if racer.tracker.finished:
		racer.finish_time = race_time
		if racer.is_player:
			_finish_race()


## Aviso en pantalla con el tiempo de la vuelta que acaba de cerrar el jugador (y "última vuelta" si toca).
func _announce_lap(lap: int, racer: Racer) -> void:
	var lap_time: float = race_time - racer.lap_started
	racer.lap_started = race_time
	if not racer.is_player or racer.tracker.finished:
		return
	var text: String = "Vuelta %d/%d  ·  %s" % [lap, racer.tracker.total_laps, RaceTime.format(lap_time)]
	if lap == racer.tracker.total_laps - 1:
		text += "\n¡ÚLTIMA VUELTA!"
	_hud.show_banner(text)
	_sounds.lap()


func _finish_race() -> void:
	state = State.FINISHED
	for racer: Racer in racers:
		racer.car.locked = true  # sin frenazo: los coches siguen rodando mientras dura la cámara lenta
	_hud.set_countdown("")
	_hud.set_wrong_way(false)
	_hud.set_hint("")
	var results: Array = _build_results()
	Events.race_finished.emit(results)
	_pause_menu.can_pause = false
	_sounds.finish()
	_camera.finish_focus = true
	state_changed.emit(state)
	# GameState aplica premio, récord y campeonato al oír race_finished (por eso se lee después)
	var info: Dictionary = {
		"prize": GameState.last_prize,
		"record": GameState.last_record,
		"championship": GameState.current_championship,
		"championship_prize": GameState.last_championship_prize,
	}
	# Cámara lenta de la meta (no si el tiempo ya está alterado, como en las pruebas aceleradas)
	if finish_slowmo_time > 0.0 and finish_slowmo < 1.0 and is_equal_approx(Engine.time_scale, 1.0):
		_slowmo = true
		Engine.time_scale = finish_slowmo
		await get_tree().create_timer(finish_slowmo_time, true, false, true).timeout  # en tiempo real
		_end_slowmo()
	_set_locked(true)
	_results.show_results(results, info)


func _end_slowmo() -> void:
	if _slowmo:
		_slowmo = false
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	_end_slowmo()  # salir de la escena a mitad de la cámara lenta no debe dejar el juego lento


func _build_results() -> Array:
	var positions: Array[int] = _order()
	var results: Array = []
	for i: int in positions.size():
		var racer: Racer = racers[positions[i]]
		results.append({
			"name": racer.display_name, "position": i + 1, "time": racer.finish_time, "is_player": racer.is_player,
		})
	return results


# --- Posiciones ---

## Índices de `racers` del primero al último.
func _order() -> Array[int]:
	var scores: Array[float] = []
	for racer: Racer in racers:
		scores.append(_score(racer))
	return RacePositions.order(scores)


func _score(racer: Racer) -> float:
	if racer.finish_time >= 0.0:
		return 1.0e6 - racer.finish_time  # los que han terminado van delante, por orden de llegada
	var last: int = racer.tracker.last_checkpoint
	var length: float = track.curve_length
	var delta: float = wrapf(track.get_offset(racer.car.global_position) - track.checkpoint_offset(last), -length / 2.0, length / 2.0)
	var fraction: float = delta / track.segment_length(last)
	return RacePositions.score(racer.tracker.laps, last, fraction, track.checkpoint_count)


# --- Rubber banding ---

## Ajusta suavemente la velocidad máxima de las IA según su ventaja sobre el jugador.
func _update_rubber_band() -> void:
	var player_score: float = _score(player)
	for racer: Racer in racers:
		if racer.is_player:
			continue
		var target: float = RubberBand.factor(_score(racer) - player_score, rubber_range_cps, rubber_max_delta)
		racer.car.rubber_band = move_toward(racer.car.rubber_band, target, rubber_step)


# --- Reaparición ---

func _check_stuck(racer: Racer, delta: float) -> void:
	if racer.car.velocity.length() < stuck_speed:
		racer.stuck_time += delta
		if racer.stuck_time >= stuck_seconds:
			_respawn(racer)
	else:
		racer.stuck_time = 0.0


func _check_bounds(racer: Racer) -> void:
	if not track.map_bounds.has_point(racer.car.global_position):
		_respawn(racer)


func _respawn(racer: Racer) -> void:
	if state != State.RACING:
		return
	racer.car.teleport(track.get_respawn_transform(racer.tracker.last_checkpoint))
	racer.stuck_time = 0.0
	racer.respawn_count += 1


# --- HUD ---

func _update_hud() -> void:
	_hud.set_lap(mini(player.tracker.laps + 1, player.tracker.total_laps), player.tracker.total_laps)
	_hud.set_position_text(_order().find(racers.find(player)) + 1, racers.size())
	_hud.set_time(race_time)
	_hud.set_nitro(player.car.nitro_charges, player.car.is_boosting(), player.car.nitro_fraction())
	_hud.set_speed(player.car.velocity.length())
	var dots: Array = []
	for racer: Racer in racers:
		dots.append({"pos": racer.car.global_position, "me": racer == player})
	_hud.set_minimap_dots(dots)
	if state == State.RACING:
		_update_warnings(get_physics_process_delta_time())


## Aviso de sentido contrario y sugerencia de reaparecer si el jugador lleva un rato parado.
func _update_warnings(delta: float) -> void:
	var car: Car = player.car
	var speed: float = car.velocity.length()
	var backwards: bool = speed > 60.0 and not car.airborne and player.finish_time < 0.0 \
			and car.velocity.dot(track.get_direction_at(car.global_position)) < -0.4 * speed
	_wrong_way_time = _wrong_way_time + delta if backwards else 0.0
	_hud.set_wrong_way(_wrong_way_time >= wrong_way_seconds)
	if _go_text_left <= 0.0:
		_hud.set_hint("Pulsa R para reaparecer" if player.stuck_time >= stuck_hint_seconds and player.finish_time < 0.0 else "")
