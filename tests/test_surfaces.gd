extends GutTest
## Superficies: los .tres cargan con los valores del GDD y la pista las resuelve.

const TRACK_PATH: String = "res://scenes/tracks/test_track.tscn"


func test_superficies_cargan_con_valores_del_gdd() -> void:
	var expected: Dictionary = {
		"asphalt": [1.0, 1.0, 1.0],
		"dirt": [0.75, 0.95, 1.1],
		"mud": [0.5, 0.7, 2.0],
	}
	for id: String in expected:
		var s: SurfaceData = load("res://data/surfaces/%s.tres" % id) as SurfaceData
		assert_not_null(s, id)
		assert_eq(s.id, id)
		var v: Array = expected[id]
		assert_almost_eq(s.grip_mult, float(v[0]), 0.001, id)
		assert_almost_eq(s.speed_mult, float(v[1]), 0.001, id)
		assert_almost_eq(s.drag_mult, float(v[2]), 0.001, id)


func test_track_resuelve_zonas() -> void:
	var track: Track = add_child_autofree((load(TRACK_PATH) as PackedScene).instantiate()) as Track
	assert_eq(track.get_surface_at(Vector2(0, 520)).id, "asphalt", "arranque")
	assert_eq(track.get_surface_at(Vector2(970, 0)).id, "dirt", "extremo derecho")
	assert_eq(track.get_surface_at(Vector2(-970, 0)).id, "mud", "extremo izquierdo")
	assert_eq(track.get_surface_at(Vector2(5000, 5000)).id, "asphalt", "fuera: por defecto")
