class_name RaceManager
extends Node
## Gestiona la carrera: cuenta atrás → carrera → fin. Coches, vueltas, posiciones y reaparición.

enum State { COUNTDOWN, RACING, FINISHED }

signal state_changed(new_state: State)

const CAR_SCENE: PackedScene = preload("res://scenes/car/car.tscn")
const GO_TEXT_TIME: float = 0.8  ## s que se muestra "¡YA!"

@export var track_data: TrackData
@export var car_data: CarData
@export var countdown_seconds: float = 3.0
@export var stuck_seconds: float = 3.0  ## s casi parado antes de reaparecer
@export var stuck_speed: float = 25.0  ## px/s por debajo de los cuales cuenta como atascado


## Un participante de la carrera.
class Racer extends RefCounted:
	var car: Car
	var tracker: LapTracker
	var display_name: String = ""
	var is_player: bool = false
	var stuck_time: float = 0.0
	var finish_time: float = -1.0


var state: State = State.COUNTDOWN
var race_time: float = 0.0
var track: Track
var racers: Array[Racer] = []
var player: Racer

var _countdown_left: float = 0.0
var _go_text_left: float = 0.0

@onready var _cars_root: Node2D = $Cars
@onready var _camera: FollowCamera = $Camera2D
@onready var _hud: Hud = $HUD
@onready var _results: Results = $Results


func _ready() -> void:
	if GameState.current_track != null:
		track_data = GameState.current_track
	track = track_data.scene.instantiate() as Track
	add_child(track)
	move_child(track, 0)
	track.checkpoint_passed.connect(_on_checkpoint_passed)
	_spawn_cars()
	_camera.target = player.car
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
				_hud.set_countdown(str(ceili(_countdown_left)))
		State.RACING:
			race_time += delta
			if _go_text_left > 0.0:
				_go_text_left -= delta
				if _go_text_left <= 0.0:
					_hud.set_countdown("")
			for racer: Racer in racers:
				_check_stuck(racer, delta)
				_check_bounds(racer)
	_update_hud()


# --- Preparación ---

func _spawn_cars() -> void:
	var slots: Array[Transform2D] = track.start_transforms()
	var racer := Racer.new()
	racer.car = CAR_SCENE.instantiate() as Car
	racer.display_name = "Jugador"
	racer.is_player = true
	racer.tracker = LapTracker.new(track.checkpoint_count, track_data.laps)
	racer.tracker.lap_completed.connect(_on_lap_completed.bind(racer))
	_cars_root.add_child(racer.car)
	racer.car.setup(car_data, {})
	racer.car.track = track
	racer.car.teleport(slots[0])
	racer.car.reset_requested.connect(_respawn.bind(racer))
	racers.append(racer)
	player = racer


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
	if racer.tracker.finished:
		racer.finish_time = race_time
		if racer.is_player:
			_finish_race()


func _finish_race() -> void:
	state = State.FINISHED
	_set_locked(true)
	_hud.set_countdown("")
	var results: Array = _build_results()
	Events.race_finished.emit(results)
	_results.show_results(results)
	state_changed.emit(state)


func _build_results() -> Array:
	var positions: Array[int] = _order()
	var results: Array = []
	for i: int in positions.size():
		var racer: Racer = racers[positions[i]]
		results.append({"name": racer.display_name, "position": i + 1, "time": racer.finish_time})
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


# --- HUD ---

func _update_hud() -> void:
	_hud.set_lap(mini(player.tracker.laps + 1, player.tracker.total_laps), player.tracker.total_laps)
	_hud.set_position_text(_order().find(racers.find(player)) + 1, racers.size())
	_hud.set_time(race_time)
	_hud.set_nitro(player.car.nitro_charges, player.car.is_boosting(), player.car.nitro_fraction())
