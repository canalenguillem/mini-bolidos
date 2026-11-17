extends Track
## Óvalo de pruebas con asfalto, tierra y barro. Muestra datos de depuración.

@onready var _car: Car = $Car
@onready var _label: Label = $Debug/Label


func _process(_delta: float) -> void:
	_label.text = "%d px/s | %s | nitro x%d%s" % [
		roundi(_car.velocity.length()),
		_car.current_surface.id,
		_car.nitro_charges,
		" ¡ON!" if _car.is_boosting() else "",
	]
