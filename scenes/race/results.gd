class_name Results
extends CanvasLayer
## Pantalla de resultados al terminar la carrera.

@onready var _list: Label = $Panel/Box/List
@onready var _retry: Button = $Panel/Box/Retry


func _ready() -> void:
	visible = false
	_retry.pressed.connect(_on_retry_pressed)


## results: [{name: String, position: int, time: float (-1 si no terminó)}], ya ordenado.
func show_results(results: Array) -> void:
	var lines: PackedStringArray = []
	for r: Dictionary in results:
		var t: float = float(r["time"])
		var time_text: String = RaceTime.format(t) if t >= 0.0 else "—"
		lines.append("%dº  %s  %s" % [int(r["position"]), str(r["name"]), time_text])
	_list.text = "\n".join(lines)
	visible = true
	_retry.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
