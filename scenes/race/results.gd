class_name Results
extends CanvasLayer
## Pantalla de resultados al terminar la carrera.

@onready var _list: Label = $Panel/Box/List
@onready var _prize: Label = $Panel/Box/Prize
@onready var _retry: Button = $Panel/Box/Buttons/Retry
@onready var _garage: Button = $Panel/Box/Buttons/Garage


func _ready() -> void:
	visible = false
	_retry.pressed.connect(_on_retry_pressed)
	_garage.pressed.connect(_on_garage_pressed)


## results: [{name: String, position: int, time: float (-1 si no terminó)}], ya ordenado.
func show_results(results: Array, prize: int = 0) -> void:
	var lines: PackedStringArray = []
	for r: Dictionary in results:
		var t: float = float(r["time"])
		var time_text: String = RaceTime.format(t) if t >= 0.0 else "—"
		lines.append("%dº  %s  %s" % [int(r["position"]), str(r["name"]), time_text])
	_list.text = "\n".join(lines)
	_prize.text = "Premio: +%d monedas" % prize if prize > 0 else "Sin premio"
	visible = true
	_retry.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_garage_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/garage.tscn")
