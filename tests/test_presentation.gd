extends GutTest
## Cámara con vida, minimapa, velocímetro y avisos (sentido contrario, reaparecer, controles).

const CAR_PATH: String = "res://scenes/car/car.tscn"
const RACE_PATH: String = "res://scenes/race/race.tscn"
const DT: float = 1.0 / 60.0

var _car: Car
var _cam: FollowCamera


func _make_camera() -> void:
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_cam = FollowCamera.new()
	_cam.target = _car
	add_child_autofree(_cam)


func after_each() -> void:
	Engine.time_scale = 1.0


# --- Cámara ---

func test_la_entrada_empieza_cerca_y_se_abre() -> void:
	_make_camera()
	_cam.intro()
	assert_almost_eq(_cam.zoom.x, _cam.intro_zoom * _cam.base_zoom, 0.001)
	for i: int in 180:
		_cam._process(DT)
	assert_almost_eq(_cam.zoom.x, _cam.base_zoom, 0.03, "tras 3 s de cuenta atrás ya está en su zoom normal")


func test_el_nitro_aleja_la_camara_y_la_sacude() -> void:
	_make_camera()
	_car.velocity = Vector2(420, 0)
	var normal: float = _cam.wanted_zoom()
	_car._nitro_time_left = 1.0
	assert_lt(_cam.wanted_zoom(), normal)
	_cam._process(DT)
	assert_gt(_cam.trauma, 0.0, "golpe al activarlo")
	var t: float = _cam.trauma
	_cam._process(DT)
	assert_lt(_cam.trauma, t, "solo una vez, no cada fotograma")


func test_el_miniturbo_tambien() -> void:
	_make_camera()
	_car.velocity = Vector2(420, 0)
	var normal: float = _cam.wanted_zoom()
	_car._drift_boost_left = 0.5
	assert_lt(_cam.wanted_zoom(), normal)
	_car.drift_boosted.emit(1)
	assert_gt(_cam.trauma, 0.0)


func test_en_los_saltos_se_aleja_y_al_aterrizar_tiembla() -> void:
	_make_camera()
	_car.velocity = Vector2(420, 0)
	var ground: float = _cam.wanted_zoom()
	_car.launch()
	_car._air_left = _car._air_total / 2.0  # punto más alto
	assert_lt(_cam.wanted_zoom(), ground * 0.95)
	_car.landed.emit(0.7)
	assert_almost_eq(_cam.trauma, _cam.landing_trauma, 0.001)


func test_un_saltito_tiembla_menos_que_un_salto_largo() -> void:
	_make_camera()
	_car.landed.emit(0.2)
	assert_lt(_cam.trauma, _cam.landing_trauma * 0.5)


func test_se_inclina_al_derrapar_y_vuelve() -> void:
	_make_camera()
	_car.velocity = Vector2(300, 200)  # deslizando hacia +y
	_car.drifting = true
	for i: int in 60:
		_cam._process(DT)
	assert_gt(_cam.rotation, 0.01)
	assert_lte(absf(_cam.rotation), _cam.drift_tilt + 0.001, "inclinación pequeña")
	_car.drifting = false
	for i: int in 90:
		_cam._process(DT)
	assert_almost_eq(_cam.rotation, 0.0, 0.002)


func test_en_la_meta_se_acerca_al_coche() -> void:
	_make_camera()
	_car.velocity = Vector2(420, 0)
	_cam.finish_focus = true
	assert_eq(_cam.wanted_zoom(), _cam.finish_zoom)
	_cam._process(DT)
	assert_eq(_cam.global_position, _car.global_position, "centrada en el coche, sin adelanto")


func test_cambiar_de_objetivo_desconecta_todo() -> void:
	_make_camera()
	_cam.target = null
	_car.landed.emit(0.7)
	_car.drift_boosted.emit(1)
	assert_eq(_cam.trauma, 0.0)


# --- Minimapa ---

func test_el_minimapa_encaja_la_pista_en_su_recuadro() -> void:
	var map := Minimap.new()
	map.size = Vector2(220, 160)
	add_child_autofree(map)
	map.setup(PackedVector2Array([Vector2(1000, 500), Vector2(5000, 500), Vector2(5000, 2500), Vector2(1000, 2500)]))
	for corner: Vector2 in [Vector2(1000, 500), Vector2(5000, 2500), Vector2(3000, 1500)]:
		var p: Vector2 = map.to_map(corner)
		assert_true(Rect2(Vector2.ZERO, map.size).has_point(p), "%s cae dentro (%s)" % [corner, p])
	var a: Vector2 = map.to_map(Vector2(1000, 500))
	var b: Vector2 = map.to_map(Vector2(5000, 2500))
	assert_almost_eq((b.x - a.x) / (b.y - a.y), 2.0, 0.01, "sin deformar: misma escala en x e y")
	assert_almost_eq(map.to_map(Vector2(3000, 1500)).x, 110.0, 0.5, "centrado")


func test_el_minimapa_vacio_no_rompe() -> void:
	var map := Minimap.new()
	map.size = Vector2(220, 160)
	add_child_autofree(map)
	map.setup(PackedVector2Array())
	map.set_dots([{"pos": Vector2(5, 5), "me": true}])
	pass_test("sin errores")


func test_las_pistas_dan_su_trazado_para_el_minimapa() -> void:
	var track: Track = add_child_autofree((load("res://data/tracks/west_01.tres") as TrackData).scene.instantiate()) as Track
	var pts: PackedVector2Array = track.line_points()
	assert_gt(pts.size(), 50)
	assert_lt(pts[0].distance_to(pts[pts.size() - 1]), 5.0, "cerrado")


# --- Carrera: HUD y avisos ---

func _race(countdown: float = 0.05) -> RaceManager:
	var race: RaceManager = (load(RACE_PATH) as PackedScene).instantiate() as RaceManager
	race.countdown_seconds = countdown
	race.finish_slowmo_time = 0.0
	add_child_autofree(race)
	return race


func test_en_la_cuenta_atras_se_ven_los_controles_y_la_camara_entra_cerca() -> void:
	var race: RaceManager = _race(5.0)
	await wait_physics_frames(2)
	var hint: Label = race._hud._hint
	assert_true(hint.visible)
	assert_string_contains(hint.text, "derrapar")
	assert_string_contains(hint.text, "nitro")
	assert_gt(race._camera.zoom.x, race._camera.base_zoom * 1.3, "entrada con zoom")


func test_al_salir_se_quita_la_ayuda() -> void:
	var race: RaceManager = _race()
	await wait_physics_frames(10)
	assert_eq(race.state, RaceManager.State.RACING)
	assert_false(race._hud._hint.visible)


func test_minimapa_y_velocimetro_en_carrera() -> void:
	var race: RaceManager = _race()
	await wait_physics_frames(10)
	assert_gt(race._hud._minimap._points.size(), 50)
	assert_eq(race._hud._minimap._dots.size(), 4, "un punto por coche")
	assert_eq(race._hud._minimap._dots.filter(func(d: Dictionary) -> bool: return d["me"]).size(), 1)
	race.player.car.velocity = Vector2(420, 0)
	race._update_hud()
	assert_eq(race._hud._speed.text, "210 km/h")


func test_aviso_de_sentido_contrario() -> void:
	var race: RaceManager = _race()
	race.stuck_seconds = 100.0
	await wait_physics_frames(10)
	var car: Car = race.player.car
	var dir: Vector2 = race.track.get_direction_at(car.global_position)
	for i: int in 70:  # más de 0,8 s yendo al revés
		car.velocity = -dir * 200.0
		race._update_warnings(DT)
	assert_true(race._hud._wrong_way.visible)
	for i: int in 5:
		car.velocity = dir * 200.0
		race._update_warnings(DT)
	assert_false(race._hud._wrong_way.visible, "al enderezarse desaparece")


func test_un_giro_breve_no_avisa() -> void:
	var race: RaceManager = _race()
	await wait_physics_frames(10)
	var car: Car = race.player.car
	var dir: Vector2 = race.track.get_direction_at(car.global_position)
	for i: int in 20:
		car.velocity = -dir * 200.0
		race._update_warnings(DT)
	assert_false(race._hud._wrong_way.visible)


func test_parado_un_rato_sugiere_reaparecer() -> void:
	var race: RaceManager = _race()
	race.stuck_seconds = 100.0
	await wait_physics_frames(10)
	race._go_text_left = 0.0
	race.player.stuck_time = 2.0
	race._update_warnings(DT)
	assert_true(race._hud._hint.visible)
	assert_string_contains(race._hud._hint.text, "R")
	race.player.stuck_time = 0.0
	race._update_warnings(DT)
	assert_false(race._hud._hint.visible)


func _finish(race: RaceManager) -> void:
	var n: int = race.track.checkpoint_count
	for lap: int in 3:
		for i: int in range(1, n + 1):
			race.player.car.teleport(race.track.get_respawn_transform(i % n))
			await wait_physics_frames(2)


func test_la_meta_tiene_camara_lenta_y_luego_resultados() -> void:
	var race: RaceManager = _race()
	race.stuck_seconds = 100.0
	race.finish_slowmo_time = 0.4
	await wait_physics_frames(10)
	await _finish(race)
	assert_eq(race.state, RaceManager.State.FINISHED)
	assert_almost_eq(Engine.time_scale, race.finish_slowmo, 0.001, "cámara lenta")
	assert_true(race._camera.finish_focus)
	assert_false(race._results.visible, "los resultados esperan")
	await wait_seconds(0.7)
	assert_eq(Engine.time_scale, 1.0)
	assert_true(race._results.visible)


func test_salir_durante_la_camara_lenta_restaura_el_tiempo() -> void:
	var race: RaceManager = _race()
	race.stuck_seconds = 100.0
	race.finish_slowmo_time = 5.0
	await wait_physics_frames(10)
	await _finish(race)
	assert_lt(Engine.time_scale, 1.0)
	race.queue_free()
	await wait_physics_frames(3)
	assert_eq(Engine.time_scale, 1.0)


func test_sin_camara_lenta_los_resultados_salen_al_momento() -> void:
	var race: RaceManager = _race()
	race.stuck_seconds = 100.0
	await wait_physics_frames(10)
	await _finish(race)
	assert_true(race._results.visible)
	assert_eq(Engine.time_scale, 1.0)
