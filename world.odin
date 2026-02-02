package game

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

TILE_MAP_ORIGIN :: [2]f32{WINDOW_WIDTH / 4, WINDOW_WIDTH / 4}
TILE_SIZE :: 16.0

ENTITIES_MAX :: 1024

PLAYER_SPEED :: 500.0

World :: struct {
	camera:   rl.Camera2D,
	player_h: Entity_Handle,
	entities: hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle),
	t_map:    Tile_Map,
}

World_Pos :: [2]f32

Tile_Map :: struct {
	size: int,
	rows: [dynamic][dynamic]Tile,
}

Tile :: struct {
	atlas: struct {
		path: cstring,
		id:   int,
	},
	pos:   Tile_Pos,
}

Tile_Pos :: [2]int

Entity :: struct {
	name:     string,
	pos:      Tile_Pos,
	tex_path: cstring,
	movement: Movement,
	handle:   Entity_Handle,
}

Movement :: struct {
	to:       Tile_Pos,
	progress: f32, // [0..1]
	speed:    f32,
	active:   bool,
}

Entity_Handle :: distinct hm.Handle32

// TODO: may eventually turn into tile_map_load
tile_map_make :: proc(atlas_path: cstring, size: int) -> Tile_Map {
	t_map := Tile_Map {
		size = size,
		rows = make([dynamic][dynamic]Tile, size / 2),
	}

	for &t_row, y in t_map.rows {
		t_row = make([dynamic]Tile, size / 2)
		for &t, x in t_row {
			t = {
				atlas = {atlas_path, 3},
				pos   = {x, y},
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
			draw(&tile)
		}
	}
}

tile_map_rec :: proc(t_map: ^Tile_Map) -> rl.Rectangle {
	height := f32((t_map.size * TILE_SIZE) / 2)
	width := height
	return {TILE_MAP_ORIGIN.x, TILE_MAP_ORIGIN.y, width, height}
}

tile_draw :: proc(tile: ^Tile) {
	atlas_tex := tex_load(tile.atlas.path)
	rl.DrawTexturePro(
		atlas_tex,
		{TILE_SIZE * f32(tile.atlas.id), TILE_SIZE * f32(tile.atlas.id), TILE_SIZE, TILE_SIZE},
		rec(tile),
		{},
		0,
		rl.WHITE,
	)
	rl.DrawRectangleLinesEx(rec(tile), 0.5, rl.WHITE)
}

tile_rec :: proc(tile: ^Tile) -> rl.Rectangle {
	return rec(tile.pos)
}

tile_pos_rec :: proc(pos: Tile_Pos) -> rl.Rectangle {
	w_pos := tile_pos_to_world_pos(pos)
	return {w_pos.x, w_pos.y, TILE_SIZE, TILE_SIZE}
}

tile_pos_to_world_pos :: proc(pos: Tile_Pos) -> World_Pos {
	return {TILE_MAP_ORIGIN.x + f32(pos.x * TILE_SIZE), TILE_MAP_ORIGIN.y + f32(pos.y * TILE_SIZE)}
}

entity_draw :: proc(e: ^Entity) {
	tex := tex_load(e.tex_path)
	rl.DrawTexturePro(
		tex,
		{width = f32(tex.width), height = f32(tex.height)},
		rec(e),
		{},
		0,
		rl.WHITE,
	)
}

entity_rec :: proc(e: ^Entity) -> rl.Rectangle {
	pos_f := World_Pos{f32(e.pos.x), f32(e.pos.y)}
	if e.movement.active {
		for _, axis in e.pos {
			if e.pos[axis] < e.movement.to[axis] {
				pos_f[axis] += e.movement.progress
			}
			if e.pos[axis] > e.movement.to[axis] {
				pos_f[axis] -= e.movement.progress
			}
		}
	}

	return {
		TILE_MAP_ORIGIN.x + f32(pos_f.x * TILE_SIZE),
		TILE_MAP_ORIGIN.y + f32(pos_f.y * TILE_SIZE),
		TILE_SIZE,
		TILE_SIZE,
	}
}

entity_movement_start :: proc(e: ^Entity, target_pos: Tile_Pos, speed: f32 = 7) {
	e.movement = {
		active   = true,
		to       = target_pos,
		speed    = speed,
		progress = 0,
	}
}

entity_movement_advance :: proc(e: ^Entity, frame_time: f32) -> bool {
	if e.movement.active {
		e.movement.progress += e.movement.speed * frame_time
	}

	if e.movement.progress >= 1 {
		e.pos = e.movement.to
		e.movement = {}
	}

	return e.movement.active
}

rec :: proc {
	tile_map_rec,
	tile_rec,
	tile_pos_rec,
	entity_rec,
}

draw :: proc {
	tile_map_draw,
	tile_draw,
	entity_draw,
}
