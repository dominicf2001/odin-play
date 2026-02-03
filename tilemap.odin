package game

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

TILE_MAP_ORIGIN :: World_Pos{WINDOW_WIDTH / 4, WINDOW_WIDTH / 4}
TILE_SIZE :: u16(16)
ENTITIES_MAX :: 1024

PLAYER_SPEED :: 500.0

Tilemap :: struct {
	dim:        Tilemap_Dim,
	tileset:    Tileset,
	placements: [dynamic][dynamic]Tile_Placement,
	entities:   Entity_Handle_Map,
}

Tilemap_Dim :: distinct [2]u16 // by # of tiles

Tilemap_Pos :: distinct [2]u16

Tileset :: struct {
	tex:   rl.Texture,
	tiles: [dynamic]Tile,
}

Tileset_Pos :: distinct [2]f32

Tile :: struct {
	tileset_pos: Tileset_Pos,
}

Tile_Placement :: struct {
	tile_h: Tile_Handle,
}

Tile_Handle :: distinct u16

Entity :: struct {
	name:     string,
	pos:      Tilemap_Pos,
	tex_path: cstring,
	movement: Movement,
	handle:   Entity_Handle,
}

Entity_Handle_Map :: hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle)

Entity_Handle :: distinct hm.Handle32

Movement :: struct {
	to:       Tilemap_Pos,
	progress: f32, // [0..1]
	speed:    f32,
	active:   bool,
}

tilemap_load :: proc(tex_path: cstring, tilemap_dim: Tilemap_Dim) -> Tilemap {
	tex := tex_load(tex_path)
	tilemap := Tilemap {
		dim = tilemap_dim,
		placements = make([dynamic][dynamic]Tile_Placement, tilemap_dim.y),
		tileset = {
			tex = tex,
			tiles = make(
				[dynamic]Tile,
				(tex.height / i32(TILE_SIZE)) * (tex.width / i32(TILE_SIZE)),
			),
		},
	}

	assert(len(tilemap.tileset.tiles) - 1 <= int(max(Tile_Handle)))

	tileset_width := tex.width / i32(TILE_SIZE)
	for &tile, i in tilemap.tileset.tiles {
		tile_h := Tile_Handle(i)

		x := i32(tile_h) % tileset_width
		y := i32(tile_h) / tileset_width
		tile.tileset_pos = {f32(x) * f32(TILE_SIZE), f32(y) * f32(TILE_SIZE)}
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
	// background
	rl.DrawRectangleRec(t_rec(tilemap), rl.WHITE)

	// tile placements
	for &row, y in tilemap.placements {
		for &tile_placement, x in row {
			tile_h := tile_placement.tile_h
			if tile_h < 0 || int(tile_h) >= len(tilemap.tileset.tiles) do continue

			tile := tilemap.tileset.tiles[tile_h]
			rl.DrawTexturePro(
				tilemap.tileset.tex,
				{tile.tileset_pos.x, tile.tileset_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)},
				t_rec(Tilemap_Pos{u16(x), u16(y)}),
				{},
				0,
				rl.WHITE,
			)
			rl.DrawRectangleLinesEx(t_rec(Tilemap_Pos{u16(x), u16(y)}), 0.5, {0, 0, 0, 50})
		}
	}

	// entities
	it := hm.iterator_make(&tilemap.entities)
	for e in hm.iterate(&it) {
		entity_draw(e)
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

tile_rec :: proc(pos: Tilemap_Pos) -> rl.Rectangle {
	w_pos := tilemap_pos_to_world_pos(pos)
	return {w_pos.x, w_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)}
}

tilemap_pos_to_world_pos :: proc(pos: Tilemap_Pos) -> World_Pos {
	return {
		TILE_MAP_ORIGIN.x + f32(pos.x) * f32(TILE_SIZE),
		TILE_MAP_ORIGIN.y + f32(pos.y) * f32(TILE_SIZE),
	}
}

world_pos_to_tilemap_pos :: proc(tilemap: ^Tilemap, w_pos: World_Pos) -> (Tilemap_Pos, bool) {
	if !rl.CheckCollisionPointRec(w_pos, t_rec(tilemap)) {
		// out of bounds
		return {}, false
	}

	pos_f := World_Pos {
		(w_pos.x - TILE_MAP_ORIGIN.x) / f32(TILE_SIZE),
		(w_pos.y - TILE_MAP_ORIGIN.y) / f32(TILE_SIZE),
	}

	return {u16(pos_f.x), u16(pos_f.y)}, true
}

entity_draw :: proc(e: ^Entity) {
	tex := tex_load(e.tex_path)
	rl.DrawTexturePro(
		tex,
		{width = f32(tex.width), height = f32(tex.height)},
		t_rec(e),
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

entity_movement_start :: proc(e: ^Entity, target_pos: Tilemap_Pos, speed: f32 = 7) {
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

t_rec :: proc {
	tilemap_rec,
	tile_rec,
	entity_rec,
}
