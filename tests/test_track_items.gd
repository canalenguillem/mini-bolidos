extends GutTest
## Objetos de la pista: zonas de turbo, manchas de aceite y bidones de nitro.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const DT: float = 1.0 / 60.0

var _car: Car
var _ctrl: FakeController
var _track: Track


class FakeController extends CarController:
	var next: DriveInput = DriveInput.new()

	func get_input(_delta: float) -> DriveInput:
		return next


## Pista mínima con una zona de turbo en x=600, aceite en x=1200 y un bidón en x=1800.
func before_each() -> void:
	_track = Track.new()
	var items := Node2D.new()
	items.name = "Items"
	var pad := BoostPad.new()
	pad.name = "Pad"
	pad.position = Vector2(600, 0)
	items.add_child(pad)
	var oil := OilSlick.new()
	oil.name = "Oil"
	oil.position = Vector2(1200, 0)
	items.add_child(oil)
	var pickup := NitroPickup.new()
	pickup.name = "Nitro"
	pickup.position = Vector2(1800, 0)
	items.add_child(pickup)
	_track.add_child(items)
	add_child_autofree(_track)
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_ctrl = autofree(FakeController.new()) as FakeController
	_car.controller = _ctrl
	_ctrl.owner_car = _car
	_car.track = _track


func _drive(throttle: float, steer: float = 0.0) -> DriveInput:
	var i := DriveInput.new()
	i.throttle = throttle
	i.steer = steer
	return i


func _put(x: float, speed: float, angle: float = 0.0) -> void:
	_car.global_position = Vector2(x, 0)
	_car.rotation = angle
	_car.velocity = Vector2.from_angle(angle) * speed


func _step(n: int = 1, input: DriveInput = null) -> void:
	_ctrl.next = input if input != null else _drive(1.0)
	for k: int in n:
		_car._physics_process(DT)


func _pickup() -> NitroPickup:
	return _track.get_node("Items/Nitro") as NitroPickup


# --- Zona de turbo ---

func test_la_pista_encuentra_los_objetos() -> void:
	assert_not_null(_track.boost_pad_at(Vector2(600, 20)))
	assert_null(_track.boost_pad_at(Vector2(600, 100)))
	assert_not_null(_track.oil_at(Vector2(1210, 5)))
	assert_null(_track.oil_at(Vector2(1300, 0)))
	assert_not_null(_track.pickup_at(Vector2(1800, 10)))


func test_pisar_la_zona_de_turbo_da_un_empujon() -> void:
	watch_signals(_car)
	_put(590, 400)
	_step()
	assert_true(_car.is_drift_boosting())
	assert_signal_emit_count(_car, "boost_pad_hit", 1)
	_step(25)
	assert_gt(_car.velocity.length(), _car.stats.max_speed * 1.05, "va más rápido que su máxima")


func test_cruzarla_no_la_dispara_en_cada_fotograma() -> void:
	watch_signals(_car)
	_put(565, 300)
	_step(12)  # la cruza entera
	assert_signal_emit_count(_car, "boost_pad_hit", 1)


func test_en_sentido_contrario_no_da_turbo() -> void:
	_put(610, 300, PI)
	_step()
	assert_false(_car.is_drift_boosting())


func test_en_el_aire_no_se_pisa_nada() -> void:
	_put(400, 420)
	_car.launch()
	_step(40)  # vuela por encima de la zona de turbo
	assert_gt(_car.global_position.x, 640.0)
	assert_false(_car.is_drift_boosting())


# --- Aceite ---

func test_el_aceite_quita_el_agarre_un_momento() -> void:
	watch_signals(_car)
	_put(1195, 350)
	_step()
	assert_true(_car.is_slipping())
	assert_signal_emit_count(_car, "oil_hit", 1)
	_car.global_position = Vector2(3000, 0)  # ya fuera de la mancha, pero sigue resbalando
	_step(15, _drive(1.0, 1.0))
	var slipping_lat: float = absf(_car.velocity.dot(_car.transform.y))
	assert_gt(slipping_lat, 80.0, "se va de lado")
	_step(60, _drive(1.0, 0.0))
	assert_false(_car.is_slipping(), "se pasa solo")
	assert_lt(absf(_car.velocity.dot(_car.transform.y)), 15.0, "y recupera el agarre")


func test_sin_aceite_la_misma_maniobra_desliza_mucho_menos() -> void:
	_put(3000, 350)
	_step(15, _drive(1.0, 1.0))
	var normal_lat: float = absf(_car.velocity.dot(_car.transform.y))
	_car.teleport(Transform2D(0.0, Vector2(1195, 0)))
	_car.velocity = Vector2(350, 0)
	_step()
	_car.global_position = Vector2(3000, 0)
	_step(15, _drive(1.0, 1.0))
	assert_gt(absf(_car.velocity.dot(_car.transform.y)), normal_lat * 1.5)


func test_sobre_aceite_se_gira_menos() -> void:
	_put(3000, 350)
	var r0: float = _car.rotation
	_step(10, _drive(1.0, 1.0))
	var normal: float = _car.rotation - r0
	_car.teleport(Transform2D(0.0, Vector2(1195, 0)))
	_car.velocity = Vector2(350, 0)
	r0 = _car.rotation
	_step(10, _drive(1.0, 1.0))
	assert_lt(_car.rotation - r0, normal * 0.8)


func test_reaparecer_quita_el_aceite() -> void:
	_put(1195, 350)
	_step()
	_car.teleport(Transform2D(0.0, Vector2(3000, 0)))
	assert_false(_car.is_slipping())


# --- Nitro ---

func test_recoger_un_bidon_da_una_carga_y_el_bidon_desaparece() -> void:
	watch_signals(_car)
	var before: int = _car.nitro_charges
	_put(1795, 300)
	_step()
	assert_eq(_car.nitro_charges, before + 1)
	assert_false(_pickup().available)
	assert_signal_emit_count(_car, "nitro_collected", 1)
	assert_null(_track.pickup_at(Vector2(1800, 0)), "ya no está")


func test_el_bidon_reaparece() -> void:
	var pickup: NitroPickup = _pickup()
	assert_true(pickup.take())
	assert_false(pickup.take(), "no se puede coger dos veces")
	pickup._process(pickup.respawn_time - 0.5)
	assert_false(pickup.available)
	pickup._process(1.0)
	assert_true(pickup.available)


func test_hay_un_maximo_de_cargas() -> void:
	_car.nitro_charges = _car.max_nitro_charges()
	_put(1795, 300)
	_step()
	assert_eq(_car.nitro_charges, _car.max_nitro_charges())
	assert_true(_pickup().available, "si vas lleno, se queda para otro")
	assert_eq(_car.max_nitro_charges(), _car.stats.nitro_charges + _car.extra_nitro_charges)


func test_dos_coches_no_cogen_el_mismo_bidon() -> void:
	var other: Car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	other.data = _car.data
	add_child_autofree(other)
	other.track = _track
	other.global_position = Vector2(1805, 0)
	other.velocity = Vector2(300, 0)
	var a: int = _car.nitro_charges
	var b: int = other.nitro_charges
	_put(1795, 300)
	_step()
	other._physics_process(DT)
	assert_eq((_car.nitro_charges - a) + (other.nitro_charges - b), 1)


func test_un_fantasma_no_recoge_ni_resbala() -> void:
	_car.make_ghost()
	_car.set_process(false)
	var now: Array = [0.0]
	_car.clock = func() -> float: return now[0]
	for x: float in [600.0, 1200.0, 1800.0]:
		_car.net_update(Vector2(x, 0), 0.0, Vector2(300, 0), now[0])
		now[0] += _car.ghost_delay + 0.01
		_car._ghost_render(DT)
	assert_true(_pickup().available)
	assert_false(_car.is_slipping())
	assert_false(_car.is_drift_boosting())


# --- Pistas reales ---

func test_todas_las_pistas_tienen_objetos_sobre_la_calzada() -> void:
	for id: String in ["west_01", "west_02", "jungle_01", "jungle_02"]:
		var track: Track = add_child_autofree((load("res://data/tracks/%s.tres" % id) as TrackData).scene.instantiate()) as Track
		var ground: TileMapLayer = track.get_node("Ground")
		var walls: TileMapLayer = track.get_node("Walls")
		var kinds: Dictionary = {}
		for item: Node2D in track.get_node("Items").get_children():
			kinds[item.get_script().get_global_name()] = int(kinds.get(item.get_script().get_global_name(), 0)) + 1
			var cell: Vector2i = ground.local_to_map(ground.to_local(item.global_position))
			assert_ne(ground.get_cell_source_id(cell), -1, "%s: %s sobre el suelo" % [id, item.name])
			assert_eq(walls.get_cell_source_id(cell), -1, "%s: %s no está en un muro" % [id, item.name])
			assert_null(track.ramp_at(item.global_position), "%s: %s no pisa una rampa" % [id, item.name])
		assert_gte(int(kinds.get("BoostPad", 0)), 1, "%s: zona de turbo" % id)
		assert_gte(int(kinds.get("OilSlick", 0)), 2, "%s: aceite" % id)
		assert_gte(int(kinds.get("NitroPickup", 0)), 2, "%s: bidones" % id)
		for pad: Node2D in track.get_node("Items").get_children():
			if pad is BoostPad:
				assert_gt((pad as BoostPad).direction().dot(track.get_direction_at(pad.global_position)), 0.9, "%s: el turbo apunta bien" % id)


func test_el_aceite_no_esta_en_la_linea_de_carrera() -> void:
	# La IA no esquiva: las manchas van a un lado para no penalizar siempre a los rivales
	for id: String in ["west_01", "west_02", "jungle_01", "jungle_02"]:
		var track: Track = add_child_autofree((load("res://data/tracks/%s.tres" % id) as TrackData).scene.instantiate()) as Track
		for item: Node2D in track.get_node("Items").get_children():
			if item is OilSlick:
				var on_line: Vector2 = track.racing_line.to_global(track.racing_line.curve.get_closest_point(track.racing_line.to_local(item.global_position)))
				assert_gt(item.global_position.distance_to(on_line), (item as OilSlick).radius + 20.0, "%s: %s" % [id, item.name])
