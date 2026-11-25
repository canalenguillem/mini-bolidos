extends GutTest
## Derrape con miniturbo y saltos en rampas.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const DT: float = 1.0 / 60.0

var _car: Car
var _ctrl: FakeController


class FakeController extends CarController:
	var next: DriveInput = DriveInput.new()

	func get_input(_delta: float) -> DriveInput:
		return next


func before_each() -> void:
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_ctrl = autofree(FakeController.new()) as FakeController
	_car.controller = _ctrl
	_ctrl.owner_car = _car


func _in(throttle: float, steer: float = 0.0, drift: bool = false, brake: float = 0.0) -> DriveInput:
	var i := DriveInput.new()
	i.throttle = throttle
	i.steer = steer
	i.drift = drift
	i.brake = brake
	return i


func _run(seconds: float, input: DriveInput) -> void:
	_ctrl.next = input
	for k: int in roundi(seconds / DT):
		_car._physics_process(DT)


# --- Derrape ---

func test_freno_de_mano_con_volante_derrapa() -> void:
	_run(4.0, _in(1.0))
	assert_false(_car.drifting)
	_run(0.3, _in(1.0, 1.0, true))
	assert_true(_car.drifting)
	assert_gt(absf(_car.velocity.dot(_car.transform.y)), 60.0, "el coche se cruza: hay velocidad lateral")


func test_sin_volante_o_despacio_no_derrapa() -> void:
	_run(4.0, _in(1.0))
	_run(0.3, _in(1.0, 0.0, true))
	assert_false(_car.drifting, "recto: el freno de mano solo no derrapa")
	_car.teleport(Transform2D.IDENTITY)
	_run(0.25, _in(1.0))
	_run(0.2, _in(1.0, 1.0, true))
	assert_false(_car.drifting, "demasiado despacio")


func test_el_freno_de_mano_pierde_poca_velocidad() -> void:
	_run(4.0, _in(1.0))
	var before: float = _car.velocity.length()
	_run(0.5, _in(1.0, 0.0, true))
	assert_gt(_car.velocity.length(), before * 0.9)
	_run(0.5, _in(0.0, 0.0, false, 1.0))
	assert_lt(_car.velocity.length(), before * 0.3, "el freno de verdad sí frena")


func test_derrapando_gira_mas_que_sin_derrapar() -> void:
	_run(4.0, _in(1.0))
	var r0: float = _car.rotation
	_run(0.5, _in(1.0, 1.0))
	var normal: float = _car.rotation - r0
	_car.teleport(Transform2D.IDENTITY)
	_run(4.0, _in(1.0))
	r0 = _car.rotation
	_run(0.5, _in(1.0, 1.0, true))
	assert_gt(_car.rotation - r0, normal * 1.1)


func test_un_derrape_largo_carga_y_da_miniturbo_al_soltar() -> void:
	watch_signals(_car)
	_run(4.0, _in(1.0))
	_run(1.0, _in(1.0, 0.6, true))
	assert_eq(_car.drift_level(), 1, "0,7 s derrapando = nivel 1")
	_run(0.05, _in(1.0))
	assert_false(_car.drifting)
	assert_true(_car.is_drift_boosting())
	assert_signal_emitted_with_parameters(_car, "drift_boosted", [1])
	_run(0.5, _in(1.0))
	assert_gt(_car.velocity.length(), _car.stats.max_speed * 1.05, "va por encima de su máxima")
	_run(1.5, _in(1.0))
	assert_false(_car.is_drift_boosting())
	assert_lte(_car.velocity.length(), _car.stats.max_speed + 1.0, "y vuelve a su velocidad normal")


func test_derrape_muy_largo_da_el_nivel_dos() -> void:
	watch_signals(_car)
	_run(4.0, _in(1.0))
	_run(2.2, _in(1.0, 0.5, true))
	assert_eq(_car.drift_level(), 2)
	_run(0.05, _in(1.0))
	assert_signal_emitted_with_parameters(_car, "drift_boosted", [2])
	assert_almost_eq(_car._drift_boost_left, _car.drift_boost_times[1], 0.1)


func test_un_derrape_corto_no_da_nada() -> void:
	watch_signals(_car)
	_run(4.0, _in(1.0))
	_run(0.3, _in(1.0, 1.0, true))
	_run(0.05, _in(1.0))
	assert_false(_car.is_drift_boosting())
	assert_signal_not_emitted(_car, "drift_boosted")


func test_las_chispas_avisan_de_que_el_miniturbo_esta_cargado() -> void:
	var fx: CarFx = _car.get_node("Fx")
	_run(4.0, _in(1.0))
	_run(0.3, _in(1.0, 0.6, true))
	assert_eq(fx.drift_level, 0)
	_run(0.7, _in(1.0, 0.6, true))
	assert_eq(fx.drift_level, 1)
	assert_true((fx.get_node("Sparks") as CPUParticles2D).emitting)
	_run(0.05, _in(1.0))
	assert_false((fx.get_node("Sparks") as CPUParticles2D).emitting)


func test_frenar_girando_sigue_derrapando_como_antes() -> void:
	_run(4.0, _in(1.0))
	_run(0.1, _in(0.0, 1.0, false, 1.0))
	assert_true(_car.drifting)


func test_reaparecer_cancela_derrape_y_turbo() -> void:
	_run(4.0, _in(1.0))
	_run(1.0, _in(1.0, 0.6, true))
	_car.teleport(Transform2D.IDENTITY)
	assert_false(_car.drifting)
	assert_eq(_car.drift_charge, 0.0)
	assert_false(_car.is_drift_boosting())


# --- Salto ---

func test_despegar_rapido_dura_mas_que_despegar_lento() -> void:
	_car.velocity = Vector2(420, 0)
	assert_true(_car.launch())
	var fast: float = _car._air_total
	_car.teleport(Transform2D.IDENTITY)
	_car.velocity = Vector2(200, 0)
	assert_true(_car.launch())
	assert_gt(fast, _car._air_total)
	assert_almost_eq(fast, _car.jump_time_at_max, 0.01)


func test_despacio_no_despega() -> void:
	_car.velocity = Vector2(100, 0)
	assert_false(_car.launch())
	assert_false(_car.airborne)


func test_en_el_aire_mantiene_la_velocidad_y_no_obedece_al_freno() -> void:
	watch_signals(_car)
	_run(4.0, _in(1.0))
	var v: Vector2 = _car.velocity
	assert_true(_car.launch())
	assert_signal_emitted(_car, "jumped")
	_run(0.3, _in(0.0, 0.0, false, 1.0))
	assert_true(_car.airborne)
	assert_almost_eq(_car.velocity.length(), v.length(), 1.0, "frenar en el aire no hace nada")
	assert_gt(_car.jump_height(), 0.5)


func test_el_coche_crece_en_el_aire_y_aparece_su_sombra() -> void:
	_run(4.0, _in(1.0))
	_car.launch()
	_run(_car._air_total / 2.0, _in(1.0))
	assert_gt((_car.get_node("Sprite") as Node2D).scale.x, 0.5 * 1.3)
	assert_true((_car.get_node("Shadow") as Node2D).visible)
	assert_gt((_car.get_node("Shadow") as Node2D).global_position.distance_to(_car.global_position), 10.0)


func test_aterriza_y_todo_vuelve_a_la_normalidad() -> void:
	watch_signals(_car)
	_run(4.0, _in(1.0))
	var mask: int = _car.collision_mask
	_car.launch()
	assert_eq(_car.collision_mask & 10, 0, "en el aire no choca con coches ni obstáculos")
	assert_eq(_car.collision_mask & 1, 1, "pero sí con las paredes")
	assert_eq(_car.collision_layer, 2, "y sigue activando checkpoints")
	_run(1.0, _in(1.0))
	assert_false(_car.airborne)
	assert_eq(_car.collision_mask, mask)
	assert_signal_emitted(_car, "landed")
	assert_almost_eq((_car.get_node("Sprite") as Node2D).scale.x, 0.5, 0.001)
	assert_false((_car.get_node("Shadow") as Node2D).visible)


func test_no_se_puede_saltar_dos_veces_en_el_aire() -> void:
	_car.velocity = Vector2(420, 0)
	assert_true(_car.launch())
	assert_false(_car.launch())


func test_saltar_cancela_el_derrape_sin_premio() -> void:
	_run(4.0, _in(1.0))
	_run(1.0, _in(1.0, 0.6, true))
	_car.launch()
	assert_false(_car.drifting)
	assert_false(_car.is_drift_boosting())


func test_reaparecer_en_el_aire_deja_el_coche_en_el_suelo() -> void:
	_car.velocity = Vector2(420, 0)
	var mask: int = _car.collision_mask
	_car.launch()
	_car.teleport(Transform2D.IDENTITY)
	assert_false(_car.airborne)
	assert_eq(_car.collision_mask, mask)


# --- Rampas ---

func _ramp_world() -> Track:
	var track := Track.new()
	var ramps := Node2D.new()
	ramps.name = "Ramps"
	var ramp := Ramp.new()
	ramp.position = Vector2(600, 0)
	ramp.half_width = 100.0
	ramps.add_child(ramp)
	track.add_child(ramps)
	add_child_autofree(track)
	return track


func test_la_rampa_detecta_puntos_encima() -> void:
	var track: Track = _ramp_world()
	assert_not_null(track.ramp_at(Vector2(600, 50)))
	assert_null(track.ramp_at(Vector2(600, 150)), "fuera por el lado")
	assert_null(track.ramp_at(Vector2(700, 0)), "ya la pasó")


func test_pasar_por_la_rampa_en_el_sentido_bueno_hace_saltar() -> void:
	_car.track = _ramp_world()
	_car.global_position = Vector2(0, 0)
	_ctrl.next = _in(1.0)
	var jumped_at: float = -1.0
	for k: int in 400:
		_car._physics_process(DT)
		if _car.airborne and jumped_at < 0.0:
			jumped_at = _car.global_position.x
	assert_between(jumped_at, 570.0, 640.0, "despega sobre la rampa")


func test_en_sentido_contrario_no_salta() -> void:
	_car.track = _ramp_world()
	_car.global_position = Vector2(1200, 0)
	_car.rotation = PI
	_ctrl.next = _in(1.0)
	for k: int in 300:
		_car._physics_process(DT)
		assert_false(_car.airborne)
	assert_lt(_car.global_position.x, 500.0, "la cruzó")


func test_los_fantasmas_tambien_saltan() -> void:
	_car.track = _ramp_world()
	_car.make_ghost()
	_car.set_process(false)
	var now: Array = [0.0]
	_car.clock = func() -> float: return now[0]
	_car.net_update(Vector2(600, 0), 0.0, Vector2(400, 0), 0.0)
	now[0] = _car.ghost_delay + 0.001
	_car._ghost_render(DT)
	assert_true(_car.airborne)
	assert_eq(_car.collision_mask, 0, "un fantasma no gana colisiones al saltar")


func test_todas_las_pistas_tienen_rampa_sobre_la_calzada() -> void:
	for id: String in ["west_01", "west_02", "jungle_01", "jungle_02"]:
		var track: Track = add_child_autofree((load("res://data/tracks/%s.tres" % id) as TrackData).scene.instantiate()) as Track
		var ramps: Array = track.get_node("Ramps").get_children()
		assert_gte(ramps.size(), 1, id)
		for ramp: Ramp in ramps:
			assert_eq(track.ramp_at(ramp.global_position), ramp, id)
			var dir: Vector2 = track.get_direction_at(ramp.global_position)
			assert_gt(ramp.direction().dot(dir), 0.95, "%s: la rampa mira en el sentido de la carrera" % id)


## Regresión: los coches pasaban por debajo de la rampa y de la línea de meta (estaban en una capa superior).
func test_rampas_y_meta_se_dibujan_por_debajo_de_los_coches() -> void:
	var race: RaceManager = (load("res://scenes/race/race.tscn") as PackedScene).instantiate() as RaceManager
	race.finish_slowmo_time = 0.0
	add_child_autofree(race)
	await wait_physics_frames(2)
	var car: Car = race.player.car
	var cars_root: Node = car.get_parent()
	for node: Node in [race.track.get_node("Ramps").get_child(0), race.track.get_node("FinishLine")]:
		var item: CanvasItem = node as CanvasItem
		assert_lte(item.z_index, car.z_index, "%s no está en una capa por encima del coche" % node.name)
		assert_true(race.track.is_ancestor_of(node))
	assert_lt(race.track.get_index(), cars_root.get_index(), "la pista se dibuja antes que los coches")


func test_en_el_aire_el_coche_se_dibuja_por_encima_de_todo() -> void:
	_car.velocity = Vector2(420, 0)
	_car.launch()
	_car._air_tick(0.2)
	assert_gt(_car.z_index, 0)
	_car._air_tick(5.0)
	assert_eq(_car.z_index, 0, "y al aterrizar vuelve a su capa")
