class_name Hud
extends CanvasLayer
## HUD de carrera: vuelta, posición, tiempo, nitro y cuenta atrás. Solo muestra; no decide nada.

@onready var _lap: Label = $LapLabel
@onready var _position: Label = $PositionLabel
@onready var _time: Label = $TimeLabel
@onready var _nitro_label: Label = $NitroLabel
@onready var _nitro_bar: ProgressBar = $NitroBar
@onready var _countdown: Label = $CountdownLabel
@onready var _banner: Label = $BannerLabel

var _banner_left: float = 0.0


func set_lap(lap: int, total: int) -> void:
	_lap.text = "Vuelta %d/%d" % [lap, total]


func set_position_text(pos: int, count: int) -> void:
	_position.text = "%dº/%d" % [pos, count]


func set_time(seconds: float) -> void:
	_time.text = RaceTime.format(seconds)


func set_nitro(charges: int, boosting: bool, fraction: float) -> void:
	_nitro_label.text = "NITRO x%d" % charges
	_nitro_bar.value = fraction if boosting else (1.0 if charges > 0 else 0.0)


## Texto grande central; cadena vacía lo oculta.
func set_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.visible = not text.is_empty()


## Aviso grande bajo el reloj (fin de vuelta, última vuelta…) que se apaga solo.
func show_banner(text: String, seconds: float = 2.2) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_left = seconds


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.visible = false
