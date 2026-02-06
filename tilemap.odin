package game

import hm "core:container/handle_map"
import "core:encoding/json"
import "core:fmt"
import os "core:os/os2"
import rl "vendor:raylib"

TILEMAP_W_POS :: World_Pos{0, 0}
TILE_SIZE :: u16(16)
ENTITIES_MAX :: 1024
LAYERS_NUM :: 2

PLAYER_SPEED :: 500.0

Tilemap :: struct {
	dim:      Tilemap_Dim,
	tileset:  Tileset,
	layers:   [LAYERS_NUM][dynamic][dynamic]Tile_Placement,
	entities: Entity_Handle_Map,
	player_h: Entity_Handle,
}

Tilemap_Iterator :: struct {
	layer_num: int,
	pos:       Tile_Pos,
	data:      ^Tilemap,
}

Tilemap_Dim :: distinct [2]u16 // by tiles

Tile_Pos :: distinct [2]u16

Tileset :: struct {
	tex_path: cstring,
	tex:      rl.Texture,
	tiles:    [dynamic]Tile,
}

Tile :: struct {
	tileset_pos: [2]f32,
}

Tile_Placement :: struct {
	tile_h:       Tile_Handle,
	is_collision: bool,
}

Tile_Handle :: distinct u16

Entity :: struct {
	name:     string,
	pos:      Tile_Pos,
	tex_path: cstring,
	movement: Movement,
	handle:   Entity_Handle,
}

Entity_Handle_Map :: distinct hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle)

Entity_Handle :: distinct hm.Handle32

Movement :: struct {
	target_pos: Tile_Pos,
	progress:   f32, // 0..<=1
	speed:      f32, // tiles per sec
	active:     bool,
}

tilemap_make :: proc(tex_path: cstring, tilemap_dim: Tilemap_Dim) -> Tilemap {
	tex := tex_load(tex_path)

	tilemap := Tilemap {
		dim = tilemap_dim,
		tileset = {
			tex_path = tex_path,
			tex = tex,
			tiles = make(
				[dynamic]Tile,
				(tex.height / i32(TILE_SIZE)) * (tex.width / i32(TILE_SIZE)),
			),
		},
	}

	for &layer in tilemap.layers {
		layer = make([dynamic][dynamic]Tile_Placement, tilemap_dim.y)
	}

	tilemap.player_h = hm.add(
		&tilemap.entities,
		Entity{name = "Player", pos = {0, 0}, tex_path = "tex/player.png"},
	)

	assert(len(tilemap.tileset.tiles) - 1 <= int(max(Tile_Handle)))

	tileset_width := tex.width / i32(TILE_SIZE)
	for &tile, i in tilemap.tileset.tiles {
		tile_h := Tile_Handle(i)

		x := i32(tile_h) % tileset_width
		y := i32(tile_h) / tileset_width
		tile.tileset_pos = {f32(x) * f32(TILE_SIZE), f32(y) * f32(TILE_SIZE)}
	}

	for layer in tilemap.layers {
		for &row, y in layer {
			row = make([dynamic]Tile_Placement, tilemap_dim.x)
		}
	}

	return tilemap
}

tilemap_load :: proc(tilemap_path: string, tilemap: ^Tilemap) -> os.Error {
	data := os.read_entire_file(tilemap_path, context.allocator) or_return
	defer delete(data)
	json.unmarshal(data, tilemap)
	tilemap.tileset.tex = tex_load(tilemap.tileset.tex_path)
	return nil
}

tilemap_destroy :: proc(tilemap: ^Tilemap) {
	for &layer in tilemap.layers {
		for &t_row in layer {
			delete(t_row)
		}
		delete(layer)
	}
	delete(tilemap.tileset.tiles)
}

tilemap_draw :: proc(tilemap: ^Tilemap) {
	// background
	rl.DrawRectangleRec(rec(tilemap), rl.WHITE)

	// tile placements
	for &layer in tilemap.layers {
		for &row, y in layer {
			for &tile_placement, x in row {
				tile_h := tile_placement.tile_h
				if tile_h < 0 || int(tile_h) >= len(tilemap.tileset.tiles) do continue

				tile := tilemap.tileset.tiles[tile_h]
				rl.DrawTexturePro(
					tilemap.tileset.tex,
					{tile.tileset_pos.x, tile.tileset_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)},
					rec(Tile_Pos{u16(x), u16(y)}),
					{},
					0,
					rl.WHITE,
				)

				if !editor.hide_grid {
					rl.DrawRectangleLinesEx(rec(Tile_Pos{u16(x), u16(y)}), 0.5, {0, 0, 0, 50})
				}
			}
		}
	}

	// entities
	it := hm.iterator_make(&tilemap.entities)
	for e in hm.iterate(&it) {
		entity_draw(e)
	}
}

tilemap_iterator_make :: proc(tilemap: ^Tilemap) -> Tilemap_Iterator {
	return {data = tilemap, pos = {0, 0}}
}

tilemap_iterate :: proc(it: ^Tilemap_Iterator) -> (^Tile_Placement, Tile_Pos, int, bool) {
	if it.layer_num >= len(it.data.layers) {
		return {}, {}, {}, false
	}

	layer_num := it.layer_num
	layer := it.data.layers[layer_num]
	tile_pos := it.pos
	row := layer[tile_pos.y]
	tile_placement := &row[tile_pos.x]

	it.pos.x += 1
	if int(it.pos.x) >= len(row) {
		it.pos.y += 1
		it.pos.x = 0
	}

	if int(it.pos.y) >= len(layer) {
		it.layer_num += 1
		it.pos = {}
	}

	return tile_placement, tile_pos, layer_num, true
}

tilemap_rec :: proc(tilemap: ^Tilemap) -> rl.Rectangle {
	return {
		TILEMAP_W_POS.x,
		TILEMAP_W_POS.y,
		f32(tilemap.dim.x) * f32(TILE_SIZE),
		f32(tilemap.dim.y) * f32(TILE_SIZE),
	}
}

tile_rec :: proc(pos: Tile_Pos) -> rl.Rectangle {
	w_pos := tile_pos_to_world(pos)
	return {w_pos.x, w_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)}
}

tile_pos_to_world :: proc(pos: Tile_Pos) -> World_Pos {
	return {
		TILEMAP_W_POS.x + f32(pos.x) * f32(TILE_SIZE),
		TILEMAP_W_POS.y + f32(pos.y) * f32(TILE_SIZE),
	}
}

world_pos_to_tile :: proc(tilemap: ^Tilemap, w_pos: World_Pos) -> (Tile_Pos, bool) {
	if !rl.CheckCollisionPointRec(w_pos, rec(tilemap)) {
		// out of bounds
		return {}, false
	}

	pos_f := [2]f32 {
		(w_pos.x - TILEMAP_W_POS.x) / f32(TILE_SIZE),
		(w_pos.y - TILEMAP_W_POS.y) / f32(TILE_SIZE),
	}

	return {u16(pos_f.x), u16(pos_f.y)}, true
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
	pos_f := [2]f32{f32(e.pos.x), f32(e.pos.y)}
	if e.movement.active {
		for _, axis in e.pos {
			if e.pos[axis] < e.movement.target_pos[axis] {
				pos_f[axis] += f32(e.movement.progress)
			}
			if e.pos[axis] > e.movement.target_pos[axis] {
				pos_f[axis] -= f32(e.movement.progress)
			}
		}
	}

	return {
		TILEMAP_W_POS.x + pos_f.x * f32(TILE_SIZE),
		TILEMAP_W_POS.y + pos_f.y * f32(TILE_SIZE),
		f32(TILE_SIZE),
		f32(TILE_SIZE),
	}
}

entity_movement_start :: proc(e: ^Entity, target_pos: Tile_Pos, speed: f32 = 7) {
	e.movement = {
		active     = true,
		target_pos = target_pos,
		speed      = speed,
		progress   = 0,
	}
}

entity_movement_advance :: proc(e: ^Entity, frame_time: f32) -> bool {
	if e.movement.active {
		e.movement.progress += e.movement.speed * frame_time
	}

	if e.movement.progress >= 1 {
		e.pos = e.movement.target_pos
		e.movement = {}
	}

	return e.movement.active
}

rec :: proc {
	tilemap_rec,
	tile_rec,
	entity_rec,
}
