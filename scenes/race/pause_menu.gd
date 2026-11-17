class_name PauseMenu
extends CanvasLayer
## Menú de pausa. Siempre procesa (process_mode ALWAYS) para poder reanudar con el juego parado.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

var can_pause: bool = true  ## la carrera lo desactiva al terminar

@onready var _menu: VBoxContainer = $Center/Menu
@onready var _resume: Button = $Center/Menu/Resume
@onready var _options: Button = $Center/Menu/Options
@onready var _quit: Button = $Center/Menu/Quit
@onready var _options_panel: OptionsPanel = $Center/OptionsPanel


func _ready() -> void:
	visible = false
	_options_panel.visible = false
	_resume.pressed.connect(close)
	_options.pressed.connect(_on_options_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_options_panel.closed.connect(_on_options_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	elif can_pause:
		open()


func open() -> void:
	visible = true
	_menu.visible = true
	_options_panel.visible = false
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_options_pressed() -> void:
	_menu.visible = false
	_options_panel.visible = true
	_options_panel.focus_first()


func _on_options_closed() -> void:
	_options_panel.visible = false
	_menu.visible = true
	_options.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	GameState.current_championship = null  # abandonar la carrera abandona el campeonato
	get_tree().change_scene_to_file(MAIN_MENU)
