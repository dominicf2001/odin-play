package game

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

TILE_MAP_ORIGIN :: World_Pos{WINDOW_WIDTH / 4, WINDOW_WIDTH / 4}
TILE_SIZE :: u16(16)
ENTITIES_MAX :: 1024

PLAYER_SPEED :: 500.0

World :: struct {
	camera:   rl.Camera2D,
	player_h: Entity_Handle,
	entities: hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle),
	tilemap:  Tilemap,
}

World_Pos :: [2]f32

Tilemap :: struct {
	dim:        [2]u16,
	tileset:    Tileset,
	placements: [dynamic][dynamic]Tile_Placement,
}

Tileset :: struct {
	tex:   rl.Texture,
	tiles: [dynamic]Tile,
}

Tile :: struct {
	tileset_origin: [2]f32,
}

Tile_Placement :: struct {
	tile_index: u16,
}

Tile_Pos :: [2]u16

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

tilemap_load :: proc(atlas_path: cstring, tilemap_dim: [2]u16) -> Tilemap {
	tileset_tex := tex_load(atlas_path)
	tilemap := Tilemap {
		dim = tilemap_dim,
		placements = make([dynamic][dynamic]Tile_Placement, tilemap_dim.y),
		tileset = {
			tex = tileset_tex,
			tiles = make(
				[dynamic]Tile,
				(tileset_tex.height / i32(TILE_SIZE)) * (tileset_tex.width / i32(TILE_SIZE)),
			),
		},
	}

	tileset_width := tileset_tex.width / i32(TILE_SIZE)
	for &tile, i in tilemap.tileset.tiles {
		x := i32(i) % tileset_width
		y := i32(i) / tileset_width
		tile.tileset_origin = {f32(x) * f32(TILE_SIZE), f32(y) * f32(TILE_SIZE)}
	}

	for &row, y in tilemap.placements {
		row = make([dynamic]Tile_Placement, tilemap_dim.x)
	}

	return tilemap
}

tilemap_unload :: proc(tilemap: ^Tilemap) {
	for &t_row in tilemap.placements {
		delete(t_row)
	}
	delete(tilemap.placements)
	delete(tilemap.tileset.tiles)
}

tilemap_draw :: proc(tilemap: ^Tilemap) {
	for &row, y in tilemap.placements {
		for &tile_placement, x in row {
			tile_index := tile_placement.tile_index
			if tile_index < 0 || int(tile_index) >= len(tilemap.tileset.tiles) do continue

			tile := tilemap.tileset.tiles[tile_index]
			rl.DrawTexturePro(
				tilemap.tileset.tex,
				{
					f32(TILE_SIZE) * tile.tileset_origin.x,
					f32(TILE_SIZE) * tile.tileset_origin.y,
					f32(TILE_SIZE),
					f32(TILE_SIZE),
				},
				rec(Tile_Pos{u16(x), u16(y)}),
				{},
				0,
				rl.WHITE,
			)
			rl.DrawRectangleLinesEx(rec(Tile_Pos{u16(x), u16(y)}), 0.5, rl.WHITE)
		}
	}
}

tileset_draw :: proc(tileset: ^Tileset) {
	tileset_width := tileset.tex.width / i32(TILE_SIZE)
	for &tile, i in tileset.tiles {
		x := i32(i) % tileset_width
		y := i32(i) / tileset_width
		rl.DrawTexturePro(
			tileset.tex,
			{tile.tileset_origin.x, tile.tileset_origin.y, f32(TILE_SIZE), f32(TILE_SIZE)},
			rec(Tile_Pos{u16(x), u16(y)}),
			{},
			0,
			rl.WHITE,
		)
	}
}

tilemap_rec :: proc(tilemap: ^Tilemap) -> rl.Rectangle {
	return {
		TILE_MAP_ORIGIN.x,
		TILE_MAP_ORIGIN.y,
		f32(tilemap.dim.x) * f32(TILE_SIZE),
		f32(tilemap.dim.y) * f32(TILE_SIZE),
	}
}

tile_rec :: proc(pos: Tile_Pos) -> rl.Rectangle {
	w_pos := tile_pos_to_world_pos(pos)
	return {w_pos.x, w_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)}
}

tile_pos_to_world_pos :: proc(pos: Tile_Pos) -> World_Pos {
	return {
		TILE_MAP_ORIGIN.x + f32(pos.x) * f32(TILE_SIZE),
		TILE_MAP_ORIGIN.y + f32(pos.y) * f32(TILE_SIZE),
	}
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
				pos_f[axis] += f32(e.movement.progress)
			}
			if e.pos[axis] > e.movement.to[axis] {
				pos_f[axis] -= f32(e.movement.progress)
			}
		}
	}

	return {
		TILE_MAP_ORIGIN.x + pos_f.x * f32(TILE_SIZE),
		TILE_MAP_ORIGIN.y + pos_f.y * f32(TILE_SIZE),
		f32(TILE_SIZE),
		f32(TILE_SIZE),
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
	tilemap_rec,
	tile_rec,
	entity_rec,
}

draw :: proc {
	tilemap_draw,
	tileset_draw,
	entity_draw,
}
