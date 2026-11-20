extends GutTest
## Volante: progresivo con el teclado, menos giro a velocidad alta y sensibilidad ajustable por el jugador.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const DT: float = 1.0 / 60.0

var _ctrl: PlayerController


func before_each() -> void:
	GameState.reset()
	_ctrl = PlayerController.new()
	add_child_autofree(_ctrl)


func after_each() -> void:
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	GameState.reset()


func _steer_after(frames: int) -> float:
	var v: float = 0.0
	for i: int in frames:
		v = _ctrl.get_input(DT).steer
	return v


func test_un_toque_de_tecla_no_es_giro_maximo_de_golpe() -> void:
	GameState.steer_sensitivity = 1.0
	Input.action_press("steer_right")
	var first: float = _ctrl.get_input(DT).steer
	assert_lt(first, 0.2, "el primer fotograma apenas gira (antes: 1.0)")
	assert_gt(first, 0.0)


func test_con_la_tecla_pulsada_llega_al_giro_maximo_en_una_fraccion_de_segundo() -> void:
	GameState.steer_sensitivity = 1.0
	Input.action_press("steer_right")
	assert_almost_eq(_steer_after(15), 1.0, 0.001, "tope a los 0,25 s")


func test_al_soltar_vuelve_al_centro_mas_rapido_de_lo_que_subio() -> void:
	GameState.steer_sensitivity = 1.0
	Input.action_press("steer_right")
	_steer_after(20)
	Input.action_release("steer_right")
	assert_almost_eq(_steer_after(6), 0.0, 0.001, "en 0,1 s está en el centro")


func test_cambiar_de_lado_pasa_por_el_centro_sin_saltar() -> void:
	GameState.steer_sensitivity = 1.0
	Input.action_press("steer_right")
	_steer_after(20)
	Input.action_release("steer_right")
	Input.action_press("steer_left")
	var prev: float = 1.0
	for i: int in 30:
		var v: float = _ctrl.get_input(DT).steer
		assert_lte(absf(v - prev), 0.2, "sin saltos bruscos")
		prev = v
	assert_lt(prev, -0.9, "acaba girando a la izquierda")


func test_la_sensibilidad_escala_el_volante() -> void:
	Input.action_press("steer_right")
	GameState.steer_sensitivity = 0.5
	assert_almost_eq(_steer_after(30), 0.5, 0.001)
	GameState.steer_sensitivity = 1.0
	assert_almost_eq(_steer_after(2), 1.0, 0.001)


func test_la_sensibilidad_se_limita_y_viene_con_un_valor_razonable() -> void:
	assert_almost_eq(GameState.steer_sensitivity, 0.85, 0.0001)
	GameState.steer_sensitivity = 5.0
	assert_eq(GameState.steer_sensitivity, 1.0)
	GameState.steer_sensitivity = 0.0
	assert_eq(GameState.steer_sensitivity, 0.4, "nunca deja el coche sin volante")


func test_mando_analogico_proporcional() -> void:
	GameState.steer_sensitivity = 1.0
	Input.action_press("steer_right", 0.5)
	assert_almost_eq(_steer_after(30), 0.5, 0.01)


func test_la_sensibilidad_se_guarda_y_se_corrige() -> void:
	GameState.steer_sensitivity = 0.6
	var d: Dictionary = GameState.to_dict()
	assert_almost_eq(float(d["steer_sensitivity"]), 0.6, 0.0001)
	GameState.reset()
	GameState.from_dict({"steer_sensitivity": 0.7})
	assert_almost_eq(GameState.steer_sensitivity, 0.7, 0.0001)
	GameState.from_dict({"steer_sensitivity": "mucho"})
	assert_almost_eq(GameState.steer_sensitivity, 0.85, 0.0001, "mal tipado: valor por defecto")


# --- Giro según la velocidad ---

func _turn_per_second(speed: float) -> float:
	var car: Car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(car)
	var ctrl := CarController.new()
	car.controller = ctrl
	var start: float = car.rotation
	car.velocity = Vector2(speed, 0)
	var steer := DriveInput.new()
	steer.steer = 1.0
	steer.throttle = 1.0
	var inputs: Array[DriveInput] = []
	for i: int in 6:  # 0,1 s
		car.velocity = Vector2.RIGHT.rotated(car.rotation) * speed  # mantiene la velocidad para aislar el giro
		var fake := FakeController.new()
		fake.next = steer
		car.controller = fake
		fake.owner_car = car
		car._physics_process(DT)
	return (car.rotation - start) / (6.0 * DT)


class FakeController extends CarController:
	var next: DriveInput

	func get_input(_delta: float) -> DriveInput:
		return next


func test_a_velocidad_maxima_gira_menos_que_a_velocidad_media() -> void:
	var medium: float = _turn_per_second(220.0)
	var fast: float = _turn_per_second(420.0)
	assert_gt(medium, fast * 1.1, "a 420 px/s gira claramente menos que a 220 (%.2f vs %.2f rad/s)" % [fast, medium])
	assert_lt(fast, 2.5, "ya no pasa de ~2 rad/s a tope (antes 3,2)")
	assert_gt(fast, 1.2, "pero sigue siendo conducible")
