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
	selected_layer:          i32, // 0 ..< LAYERS_NUM
	selected_tile_h:         Tile_Handle,
	selected_tile_placement: ^Tile_Placement,
	selected_entity_h:       Entity_Handle,
	hide_grid:               bool,
	input:                   struct {
		layer_spinner:   struct {
			value: i32,
		},
		grid_checkbox:   struct {
			is_checked: bool,
		},
		entity_list:     struct {
			handles:      sa.Small_Array(ENTITIES_MAX, Entity_Handle),
			active_index: i32,
			scroll_index: i32,
		},
		tileset_pallete: struct {
			active_index: i32,
		},
	},
}

editor := Editor {
	input = {entity_list = {active_index = -1}, tileset_pallete = {active_index = -1}},
}

editor_entity_list :: proc(
	bounds: rl.Rectangle,
	entities: ^Entity_Handle_Map,
	selected_entity_h: Entity_Handle,
) {
	entity_list := &editor.input.entity_list

	entity_list_sb := strings.builder_make(context.temp_allocator)

	sa.clear(&entity_list.handles)
	it, i := hm.iterator_make(entities), uint(0)
	for e in hm.iterate(&it) {
		if e.handle == selected_entity_h {
			entity_list.active_index = i32(i)
		}

		sa.append(&entity_list.handles, e.handle)
		strings.write_string(&entity_list_sb, e.name)
		if i < hm.len(entities^) - 1 {
			strings.write_byte(&entity_list_sb, ';')
		}
		i += 1
	}
	rl.GuiListView(
		bounds,
		strings.to_cstring(&entity_list_sb),
		&entity_list.scroll_index,
		&entity_list.active_index,
	)
}

editor_tileset_pallete :: proc(s_pos: Screen_Pos, tileset: Tileset, active_tile_h: Tile_Handle) {
	tileset_pallete := &editor.input.tileset_pallete

	tileset_pallete.active_index = i32(active_tile_h)
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
		if i32(tile_h) == tileset_pallete.active_index {
			line_thickness: f32 = is_mouse_colliding ? 2 : 1
			rl.DrawRectangleLinesEx(tile_bounds, line_thickness, rl.BLACK)

			if is_mouse_colliding && rl.IsMouseButtonPressed(.LEFT) {
				tileset_pallete.active_index = -1
			}
		} else if is_mouse_colliding {
			rl.DrawRectangleLinesEx(tile_bounds, 1, rl.LIGHTGRAY)

			if rl.IsMouseButtonPressed(.LEFT) {
				tileset_pallete.active_index = i32(tile_h)
			}
		}
	}
}
