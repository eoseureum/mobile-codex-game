extends TileMapLayer
## Every stone tile shares the same TileSet collider, including the map boundary.

const MAP_SIZE := Vector2i(40, 28)
const TILE_SIZE: int = 48
const ATLAS = preload("res://assets/tiles.svg")


func _ready() -> void:
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ATLAS
	atlas.texture_region_size = tile_set.tile_size
	tile_set.add_source(atlas, 0)
	for x in range(3):
		atlas.create_tile(Vector2i(x, 0))
	var stone: TileData = atlas.get_tile_data(Vector2i(2, 0), 0)
	stone.set_collision_polygons_count(0, 1)
	stone.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24)
	]))
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var tile: int = 0
			if x in [19, 20] or y in [13, 14]:
				tile = 1
			if x == 0 or y == 0 or x == MAP_SIZE.x - 1 or y == MAP_SIZE.y - 1:
				tile = 2
			if Rect2i(14, 9, 3, 2).has_point(Vector2i(x, y)) \
					or Rect2i(25, 16, 2, 4).has_point(Vector2i(x, y)) \
					or Rect2i(7, 18, 4, 2).has_point(Vector2i(x, y)) \
					or Rect2i(28, 7, 5, 2).has_point(Vector2i(x, y)):
				tile = 2
			set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
