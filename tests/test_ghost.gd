extends GutTest
## Coches remotos: se dibujan con un pequeño retraso, interpolando entre paquetes, sin tirones ni saltos atrás.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const FRAME: float = 1.0 / 60.0

var _car: Car
var _now: float = 0.0


func before_each() -> void:
	_now = 0.0
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_car.make_ghost()
	_car.set_process(false)  # el test lo mueve a mano, con su propio reloj
	_car.clock = func() -> float: return _now


## Simula `seconds` de carrera: el coche real va a `speed` px/s en línea recta y envía paquetes cada `interval`
## con un retraso de red variable (en el rango dado, siempre en orden). Devuelve las x dibujadas por fotograma.
func _run(seconds: float, speed: float, interval: float, delay_min: float, delay_max: float, drop: Callable = Callable()) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var packets: Array[Dictionary] = []
	var send_t: float = 0.0
	var last_arrival: float = 0.0
	while send_t < seconds:
		var arrival: float = maxf(send_t + rng.randf_range(delay_min, delay_max), last_arrival)  # TCP: llegan en orden
		last_arrival = arrival
		if not drop.is_valid() or not drop.call(send_t):
			packets.append({"arrival": arrival, "ts": send_t, "pos": Vector2(speed * send_t, 0.0), "vel": Vector2(speed, 0.0)})
		send_t += interval
	var xs: Array[float] = []
	var next: int = 0
	_now = 0.0
	while _now < seconds:
		while next < packets.size() and float(packets[next]["arrival"]) <= _now:
			_car.net_update(packets[next]["pos"], 0.0, packets[next]["vel"], float(packets[next]["ts"]))
			next += 1
		_car._ghost_render(FRAME)
		xs.append(_car.global_position.x)
		_now += FRAME
	return xs


func _max_step(xs: Array[float], from: int) -> float:
	var worst: float = 0.0
	for i: int in range(from + 1, xs.size()):
		worst = maxf(worst, xs[i] - xs[i - 1])
	return worst


func _min_step(xs: Array[float], from: int) -> float:
	var worst: float = INF
	for i: int in range(from + 1, xs.size()):
		worst = minf(worst, xs[i] - xs[i - 1])
	return worst


func test_con_red_estable_el_movimiento_es_continuo() -> void:
	var xs: Array[float] = _run(3.0, 400.0, 0.05, 0.03, 0.03)
	var expected: float = 400.0 * FRAME  # 6,7 px por fotograma
	assert_lt(_max_step(xs, 40), expected * 1.3, "sin saltos hacia delante")
	assert_gt(_min_step(xs, 40), expected * 0.7, "sin paradas ni retrocesos")


func test_con_jitter_de_red_nunca_retrocede_ni_se_para() -> void:
	var xs: Array[float] = _run(4.0, 400.0, 0.05, 0.02, 0.09)  # paquetes que tardan entre 20 y 90 ms
	var expected: float = 400.0 * FRAME
	assert_gte(_min_step(xs, 60), 0.0, "jamás va hacia atrás (antes se echaba atrás con cada paquete)")
	assert_lt(_max_step(xs, 60), expected * 2.0, "ni da tirones grandes")
	# y va, en media, a la velocidad real
	var mean: float = (xs[xs.size() - 1] - xs[60]) / float(xs.size() - 61)
	assert_almost_eq(mean, expected, expected * 0.1)


func test_un_corte_de_200_ms_no_provoca_saltos() -> void:
	var gap: Callable = func(t: float) -> bool: return t >= 1.5 and t < 1.7  # se pierden los paquetes de 200 ms
	var xs: Array[float] = _run(4.0, 400.0, 0.05, 0.03, 0.05, gap)
	assert_gte(_min_step(xs, 40), 0.0, "no retrocede")
	assert_lt(_max_step(xs, 40), 400.0 * FRAME * 2.0, "no salta al reanudarse")


func test_va_por_detras_del_coche_real_lo_que_dice_el_retardo() -> void:
	var xs: Array[float] = _run(3.0, 400.0, 0.05, 0.03, 0.03)
	var t_now: float = 2.9
	var frame: int = int(t_now / FRAME)
	var truth: float = 400.0 * t_now
	var lag_s: float = (truth - xs[frame]) / 400.0
	assert_between(lag_s, 0.10, 0.22, "retraso total visto: %.0f ms (red + %.0f ms de interpolación)" % [lag_s * 1000.0, _car.ghost_delay * 1000.0])


func test_antes_de_recibir_nada_se_queda_en_su_sitio() -> void:
	_car.global_position = Vector2(123, 456)
	for i: int in 30:
		_now += FRAME
		_car._ghost_render(FRAME)
	assert_eq(_car.global_position, Vector2(123, 456))


func test_el_primer_paquete_coloca_al_coche_de_golpe() -> void:
	_car.global_position = Vector2.ZERO
	_car.net_update(Vector2(5000, -300), 1.2, Vector2.ZERO)
	assert_eq(_car.global_position, Vector2(5000, -300))
	assert_almost_eq(_car.rotation, 1.2, 0.0001)


func test_sin_paquetes_sigue_un_rato_con_su_velocidad_y_se_para() -> void:
	_car.net_update(Vector2(0, 0), 0.0, Vector2(400, 0))
	_now = 5.0  # mucho después del último paquete
	_car._ghost_render(FRAME)
	assert_almost_eq(_car.global_position.x, 400.0 * _car.ghost_max_extrapolation, 0.01, "extrapola solo el máximo permitido")
	_now = 50.0
	_car._ghost_render(FRAME)
	assert_almost_eq(_car.global_position.x, 400.0 * _car.ghost_max_extrapolation, 0.01, "y luego se queda quieto (no se va al infinito)")


func test_el_giro_se_interpola_por_el_camino_corto() -> void:
	_car.net_update(Vector2.ZERO, PI - 0.1, Vector2.ZERO)
	_now = 0.1
	_car.net_update(Vector2.ZERO, -PI + 0.1, Vector2.ZERO)  # 0,2 rad más allá del salto de -π a π
	_now = 0.1 + _car.ghost_delay - 0.05  # a mitad de camino entre los dos
	_car._ghost_render(FRAME)
	assert_gt(absf(_car.rotation), PI - 0.2, "pasa por ±π, no por 0")


func test_los_paquetes_viejos_no_se_acumulan_sin_limite() -> void:
	for i: int in 200:
		_now = i * 0.05
		_car.net_update(Vector2(i, 0), 0.0, Vector2.ZERO)
	assert_lte(_car._snapshots.size(), 40)


func test_sin_hora_del_emisor_tambien_funciona_con_la_de_llegada() -> void:
	_car.net_update(Vector2(0, 0), 0.0, Vector2(100, 0))
	_now = 0.5
	_car.net_update(Vector2(50, 0), 0.0, Vector2(100, 0))
	_now = 0.5 + _car.ghost_delay - 0.25  # a mitad de camino entre los dos paquetes
	_car._ghost_render(FRAME)
	assert_between(_car.global_position.x, 20.0, 30.0)


func test_el_reloj_del_emisor_puede_ir_por_otra_hora() -> void:
	# El emisor empezó su carrera 1000 s antes que nosotros: solo importan las diferencias
	var xs: Array[float] = []
	for i: int in 60:
		_now = i * 0.05 + 0.03
		_car.net_update(Vector2(400.0 * i * 0.05, 0), 0.0, Vector2(400, 0), 1000.0 + i * 0.05)
		for k: int in 3:
			_now += FRAME
			_car._ghost_render(FRAME)
			xs.append(_car.global_position.x)
	assert_gte(_min_step(xs, 12), 0.0)
	assert_gt(xs[xs.size() - 1], 800.0, "avanza")
