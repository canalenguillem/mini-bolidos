class_name PlayerController
extends CarController
## Lee las acciones del InputMap y las traduce a DriveInput.
## El volante no salta a tope de golpe (con teclado un toque era giro máximo): sube y baja de forma progresiva y se
## multiplica por la sensibilidad que cada jugador elige en Opciones.

@export var steer_ramp_up: float = 5.0  ## 1/s: cuánto crece el volante al pulsar (de 0 a tope en 0,2 s)
@export var steer_ramp_down: float = 10.0  ## 1/s: cuánto vuelve al centro al soltar o cambiar de lado

var _steer: float = 0.0


func get_input(delta: float) -> DriveInput:
	var input := DriveInput.new()
	input.throttle = Input.get_action_strength("accelerate")
	input.brake = Input.get_action_strength("brake")
	var target: float = Input.get_axis("steer_left", "steer_right")
	var returning: bool = is_zero_approx(target) or (not is_zero_approx(_steer) and signf(target) != signf(_steer))
	_steer = move_toward(_steer, target, (steer_ramp_down if returning else steer_ramp_up) * delta)
	input.steer = _steer * GameState.steer_sensitivity
	input.nitro = Input.is_action_just_pressed("nitro")
	input.reset = Input.is_action_just_pressed("reset")
	return input
