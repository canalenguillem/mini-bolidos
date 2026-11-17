class_name Track
extends Node2D
## Script común de las pistas. En M1 solo resuelve superficies; M2 añade checkpoints y parrilla.

const SURFACES: Dictionary = {
	"asphalt": preload("res://data/surfaces/asphalt.tres"),
	"dirt": preload("res://data/surfaces/dirt.tres"),
	"mud": preload("res://data/surfaces/mud.tres"),
}
const DEFAULT_SURFACE: String = "asphalt"

@onready var _ground: TileMapLayer = get_node_or_null("Ground") as TileMapLayer
@onready var _zones: Node2D = get_node_or_null("SurfaceZones") as Node2D


func _ready() -> void:
	# Los coches ya están en el grupo (los hijos hacen _ready antes que la pista)
	for node: Node in get_tree().get_nodes_in_group("cars"):
		if is_ancestor_of(node):
			(node as Car).track = self


## Superficie bajo un punto: primero las SurfaceZones, luego el tile de Ground.
func get_surface_at(global_pos: Vector2) -> SurfaceData:
	var id: String = _zone_surface_id(global_pos)
	if id.is_empty() and _ground != null and _ground.tile_set != null:
		var cell: Vector2i = _ground.local_to_map(_ground.to_local(global_pos))
		var tile: TileData = _ground.get_cell_tile_data(cell)
		if tile != null:
			id = str(tile.get_custom_data("surface"))
	return SURFACES.get(id, SURFACES[DEFAULT_SURFACE]) as SurfaceData


func _zone_surface_id(global_pos: Vector2) -> String:
	if _zones == null:
		return ""
	for zone: Node in _zones.get_children():
		for child: Node in zone.get_children():
			var poly := child as CollisionPolygon2D
			if poly == null:
				continue
			if Geometry2D.is_point_in_polygon(poly.to_local(global_pos), poly.polygon):
				return str(zone.get_meta("surface", ""))
	return ""
