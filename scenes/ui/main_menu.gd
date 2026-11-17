class_name MainMenu
extends Control
## Menú principal: carrera rápida, campeonato, garaje, opciones y salir.

const TRACK_SELECT: String = "res://scenes/ui/track_select.tscn"
const GARAGE: String = "res://scenes/ui/garage.tscn"
const RACE: String = "res://scenes/race/race.tscn"

@onready var _menu: VBoxContainer = $Center/Menu
@onready var _quick: Button = $Center/Menu/Quick
@onready var _championship: Button = $Center/Menu/Championship
@onready var _garage: Button = $Center/Menu/Garage
@onready var _options: Button = $Center/Menu/Options
@onready var _quit: Button = $Center/Menu/Quit
@onready var _options_panel: OptionsPanel = $OptionsLayer/OptionsPanel
@onready var _options_layer: Control = $OptionsLayer
@onready var _money: Label = $Money


func _ready() -> void:
	_quick.pressed.connect(func() -> void: get_tree().change_scene_to_file(TRACK_SELECT))
	_championship.pressed.connect(_on_championship_pressed)
	_garage.pressed.connect(func() -> void: get_tree().change_scene_to_file(GARAGE))
	_options.pressed.connect(_on_options_pressed)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_options_panel.closed.connect(_on_options_closed)
	_options_layer.visible = false
	_championship.disabled = GameState.championships.is_empty()
	_money.text = "Monedas: %d" % GameState.money
	_quick.grab_focus()


func _on_championship_pressed() -> void:
	var ids: Array[String] = Catalog.sorted_ids(GameState.championships, "reward_mult")
	GameState.start_championship(GameState.championships[ids[0]])
	get_tree().change_scene_to_packed(load(RACE))


func _on_options_pressed() -> void:
	_menu.visible = false
	_options_layer.visible = true
	_options_panel.focus_first()


func _on_options_closed() -> void:
	_options_layer.visible = false
	_menu.visible = true
	_options.grab_focus()
