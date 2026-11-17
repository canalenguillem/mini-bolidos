extends SceneTree
## Genera los TileSets de los temas (placeholder de colores planos) en assets/tilesets/.
## Cada tile lleva el custom data "surface"; el muro lleva colisión (capa de física 1 = walls).
## Uso: godot --headless --path . -s res://tools/gen_tilesets.gd

const TILE: int = 32
## Orden del atlas: debe coincidir con TrackBuilder.SURFACE_ATLAS y WALL_ATLAS.
const ORDER: Array[String] = ["asphalt", "dirt", "sand", "mud", "grass", "water", "wall"]

const PALETTES: Dictionary = {
	"west": {
		"asphalt": Color(0.35, 0.35, 0.38), "dirt": Color(0.72, 0.52, 0.30),
		"sand": Color(0.88, 0.78, 0.52), "mud": Color(0.40, 0.28, 0.18),
		"grass": Color(0.50, 0.58, 0.30), "water": Color(0.25, 0.50, 0.75),
		"wall": Color(0.55, 0.26, 0.17),
	},
	"jungle": {
		"asphalt": Color(0.35, 0.35, 0.38), "dirt": Color(0.55, 0.42, 0.28),
		"sand": Color(0.80, 0.75, 0.50), "mud": Color(0.33, 0.24, 0.14),
		"grass": Color(0.30, 0.60, 0.25), "water": Color(0.20, 0.45, 0.60),
		"wall": Color(0.08, 0.28, 0.12),
	},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/tilesets")
	var failed: bool = false
	for theme: String in PALETTES:
		var path: String = "res://assets/tilesets/%s.tres" % theme
		var err: Error = ResourceSaver.save(_build(PALETTES[theme] as Dictionary), path)
		print("tileset %s → %s" % [path, error_string(err)])
		failed = failed or err != OK
	quit(1 if failed else 0)


func _build(palette: Dictionary) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "surface")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)  # capa 1: walls
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = _make_texture(palette)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)  # primero al TileSet, para que conozca las capas
	var half: float = TILE / 2.0
	for i: int in ORDER.size():
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		var td: TileData = src.get_tile_data(coords, 0)
		var id: String = ORDER[i]
		td.set_custom_data("surface", "" if id == "wall" else id)
		if id == "wall":
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	return ts


func _make_texture(palette: Dictionary) -> ImageTexture:
	var img := Image.create(TILE * ORDER.size(), TILE, false, Image.FORMAT_RGBA8)
	for i: int in ORDER.size():
		var base: Color = palette[ORDER[i]]
		for y: int in TILE:
			for x: int in TILE:
				# Moteado determinista para que se aprecie el movimiento sobre suelo liso
				var h: int = (x * 73856093) ^ (y * 19349663) ^ (i * 83492791)
				var shade: float = 1.0 + (float(h & 15) / 15.0 - 0.5) * 0.10
				var c := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
				if ORDER[i] == "wall" and (x < 2 or y < 2):
					c = c.lightened(0.15)
				img.set_pixel(i * TILE + x, y, c)
	return ImageTexture.create_from_image(img)
