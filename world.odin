package game

import hm "core:container/handle_map"
import rl "vendor:raylib"

TILE_MAP_ORIGIN :: [2]f32{WINDOW_WIDTH / 4, WINDOW_WIDTH / 4}
TILE_SIZE :: 25.0
TILE_GRID_SIZE :: 20

ENTITIES_MAX :: 1024

PLAYER_SPEED :: 500.0

World :: struct {
	camera:   rl.Camera2D,
	player_h: Entity_Handle,
	entities: hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle),
	t_map:    Tile_Map,
}

Tile_Map :: struct {
	size: uint,
	rows: [dynamic][dynamic]Tile,
}

Tile :: struct {
	pos: [2]int,
}

Entity :: struct {
	name:     string,
	rec:      rl.Rectangle,
	tex_path: cstring,
	handle:   Entity_Handle,
}

Entity_Handle :: distinct hm.Handle32

// TODO: may eventually turn into tile_map_load
tile_map_make :: proc(size: uint) -> Tile_Map {
	t_map := Tile_Map {
		size = size,
		rows = make([dynamic][dynamic]Tile, size / 2),
	}

	for &t_row, y in t_map.rows {
		t_row = make([dynamic]Tile, size / 2)
		for &t, x in t_row {
			t = {
				pos = {x, y},
			}
		}
	}

	return t_map
}

tile_map_destroy :: proc(t_map: ^Tile_Map) {
	for &t_row in t_map.rows {
		delete(t_row)
	}
	delete(t_map.rows)
}

tile_map_draw :: proc(t_map: ^Tile_Map) {
	for &t_row in t_map.rows {
		for &tile in t_row {
			tile_draw(&tile)
		}
	}
}

tile_draw :: proc(t: ^Tile) {
	tile_rec := tile_get_rec(t)
	rl.DrawRectangleRec(tile_rec, rl.BLUE)
	rl.DrawRectangleLinesEx(tile_rec, 1, rl.WHITE)
}

tile_get_rec :: proc(tile: ^Tile) -> rl.Rectangle {
	return rl.Rectangle {
		TILE_MAP_ORIGIN.x + f32(tile.pos.x * TILE_SIZE),
		TILE_MAP_ORIGIN.y + f32(tile.pos.y * TILE_SIZE),
		TILE_SIZE,
		TILE_SIZE,
	}
}

entity_draw :: proc(e: ^Entity) {
	tex := tex_load(e.tex_path)
	rl.DrawTexturePro(
		tex,
		{width = f32(tex.width), height = f32(tex.height)},
		e.rec,
		{},
		0,
		rl.WHITE,
	)
}
