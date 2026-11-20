class_name RaceSounds
extends Node
## Sonidos de la carrera que no pertenecen a un coche: cuenta atrás, salida y meta.

@onready var _beep: AudioStreamPlayer = $Beep
@onready var _go: AudioStreamPlayer = $Go
@onready var _finish: AudioStreamPlayer = $Finish


func beep() -> void:
	_beep.play()


func go() -> void:
	_go.volume_db = -2.0
	_go.play()


func finish() -> void:
	_finish.play()


## Pitido de fin de vuelta (más suave que la salida).
func lap() -> void:
	_go.volume_db = -8.0
	_go.play()
