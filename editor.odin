package game
import hm "core:container/handle_map"
import sa "core:container/small_array"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Editor_Mode :: enum {
	TILE_SELECT,
	TILE_PAINT,
}

Editor :: struct {
	mode:                    Editor_Mode,
	component:               struct {
		entity_list:     struct {
			active_index: i32,
			scroll_index: i32,
		},
		tileset_pallete: struct {
			active_index: i32,
		},
	},
	selected_tile_placement: struct {
		data: ^Tile_Placement,
		pos:  Tile_Pos,
	},
	selected_layer:          i32,
}

editor := Editor {
	component = {entity_list = {active_index = -1}, tileset_pallete = {active_index = -1}},
}

editor_entity_list :: proc(bounds: rl.Rectangle, entities: ^Entity_Handle_Map) -> Entity_Handle {
	entity_list := &editor.component.entity_list

	entity_list_sb := strings.builder_make(context.temp_allocator)

	handles := sa.Small_Array(ENTITIES_MAX, Entity_Handle){}
	it, num := hm.iterator_make(entities), uint(0)
	for e in hm.iterate(&it) {
		sa.append(&handles, e.handle)
		strings.write_string(&entity_list_sb, e.name)
		if num < hm.len(entities^) - 1 {
			strings.write_byte(&entity_list_sb, ';')
		}
		num += 1
	}
	rl.GuiListView(
		bounds,
		strings.to_cstring(&entity_list_sb),
		&entity_list.scroll_index,
		&entity_list.active_index,
	)

	if handle, ok := sa.get_safe(handles, int(entity_list.active_index)); ok {
		return handle
	}
	return {}
}

editor_tileset_pallete :: proc(s_pos: Screen_Pos, tileset: ^Tileset, active_tile_h: ^i32) -> i32 {
	for &tile, i in tileset.tiles {
		tile_h := Tile_Handle(i)

		tileset_width := tileset.tex.width / i32(TILE_SIZE)
		col := i32(tile_h) % tileset_width
		row := i32(tile_h) / tileset_width

		tile_bounds := rl.Rectangle {
			s_pos.x + f32(col * i32(TILE_SIZE)),
			s_pos.y + f32(row * i32(TILE_SIZE)),
			f32(TILE_SIZE),
			f32(TILE_SIZE),
		}

		rl.DrawTexturePro(
			tileset.tex,
			{tile.tileset_pos.x, tile.tileset_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)},
			tile_bounds,
			{},
			0,
			rl.WHITE,
		)

		is_mouse_colliding := rl.CheckCollisionPointRec(rl.GetMousePosition(), tile_bounds)
		if i32(tile_h) == active_tile_h^ {
			line_thickness: f32 = is_mouse_colliding ? 2 : 1
			rl.DrawRectangleLinesEx(tile_bounds, line_thickness, rl.BLACK)

			if is_mouse_colliding && rl.IsMouseButtonPressed(.LEFT) {
				active_tile_h^ = -1
			}
		} else if is_mouse_colliding {
			rl.DrawRectangleLinesEx(tile_bounds, 1, rl.LIGHTGRAY)

			if rl.IsMouseButtonPressed(.LEFT) {
				active_tile_h^ = i32(tile_h)
			}
		}
	}

	return active_tile_h^
}
