package game

import hm "core:container/handle_map"
import rl "vendor:raylib"

TILE_GRID_SIZE :: 40
TILE_GRID_ORIGIN :: [2]f32{WINDOW_WIDTH / 4, WINDOW_WIDTH / 4}
TILE_SIZE :: 40.0

ENTITIES_MAX :: 1024

PLAYER_SPEED :: 500.0

World :: struct {
	camera:   rl.Camera2D,
	player_h: Entity_Handle,
	entities: hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle),
	t_grid:   Tile_Grid,
}

Tile_Grid :: [TILE_GRID_SIZE / 2][TILE_GRID_SIZE / 2]Tile

Tile :: struct {
	pos: [2]int,
}

Entity :: struct {
	name:     string,
	rect:     rl.Rectangle,
	tex_path: cstring,
	handle:   Entity_Handle,
}

Entity_Handle :: distinct hm.Handle32

// TODO: would eventually probably load from a file
tile_grid_load :: proc(t_grid: ^Tile_Grid) {
	for &t_row, y in t_grid {
		for &t, x in t_row {
			t.pos.x = x
			t.pos.y = y

			// TODO: load texture
		}
	}
}

tile_grid_draw :: proc(t_grid: ^Tile_Grid) {
	for &tile_row in t_grid {
		for &tile in tile_row {
			tile_draw(&tile)
		}
	}
}

tile_draw :: proc(t: ^Tile) {
	tile_rect := rl.Rectangle {
		TILE_GRID_ORIGIN.x + f32(t.pos.x * TILE_SIZE),
		TILE_GRID_ORIGIN.y + f32(t.pos.y * TILE_SIZE),
		TILE_SIZE,
		TILE_SIZE,
	}
	rl.DrawRectangleRec(tile_rect, rl.BLUE)
	rl.DrawRectangleLinesEx(tile_rect, 1, rl.WHITE)
}

entity_draw :: proc(e: ^Entity) {
	tex := tex_load(e.tex_path)
	rl.DrawTexturePro(
		tex,
		{width = f32(tex.width), height = f32(tex.height)},
		e.rect,
		{},
		0,
		rl.WHITE,
	)
}
