extends SceneTree
## Demo para grabar capturas de la conducción: la IA lleva el coche del jugador (salta la rampa) y hace un derrape.
##   godot --path . --write-movie out.png --fixed-fps 30 --quit-after 330 -s res://tools/feel_demo.gd [-- --track=west_02]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var race: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()  # sin tipo: depende de autoloads
	race.set("countdown_seconds", 1.5)
	race.set("player_slot", 0)
	root.add_child(race)
	var car: Node = race.get("player").car
	var old: Node = car.get_node("Controller")
	car.remove_child(old)
	old.free()
	var ai: Node = (load("res://scenes/car/controllers/ai_controller.gd") as GDScript).new()
	ai.name = "Controller"
	ai.set("mistakes", 0.0)
	car.add_child(ai)
	car.set("controller", ai)
	ai.set("owner_car", car)
	car.set("nitro_charges", 1)
	# A los 7,5 s, un derrape de freno de mano de 1 s (se ve el humo, las chispas y el miniturbo)
	await create_timer(7.5).timeout
	var wrapper: GDScript = GDScript.new()
	wrapper.source_code = "extends CarController\nvar inner: CarController\nvar left: float = 1.0\nfunc get_input(d: float) -> DriveInput:\n\tvar i: DriveInput = inner.get_input(d)\n\tleft -= d\n\tif left > 0.0:\n\t\ti.drift = true\n\t\ti.steer = clampf(i.steer + 0.35, -1.0, 1.0)\n\t\ti.throttle = 1.0\n\treturn i\n"
	wrapper.reload()
	var w: Node = wrapper.new()
	w.set("inner", ai)
	w.set("owner_car", car)
	car.set("controller", w)
