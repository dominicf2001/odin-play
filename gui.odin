package game
import hm "core:container/handle_map"
import sa "core:container/small_array"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

GUI :: struct {
	entity_list: struct {
		active:       i32,
		scroll_index: i32,
		handles:      sa.Small_Array(ENTITIES_MAX, Entity_Handle),
	},
}

gui := GUI{}

gui_entity_list :: proc(bounds: rl.Rectangle, entities: ^Entity_Handle_Map) -> Entity_Handle {
	sa.clear(&gui.entity_list.handles)

	entity_list_sb := strings.builder_make(context.temp_allocator)

	it, num := hm.iterator_make(entities), uint(0)
	for e in hm.iterate(&it) {
		sa.append(&gui.entity_list.handles, e.handle)
		strings.write_string(&entity_list_sb, e.name)
		if num < hm.len(entities^) - 1 {
			strings.write_byte(&entity_list_sb, ';')
		}
		num += 1
	}
	rl.GuiListView(
		bounds,
		strings.to_cstring(&entity_list_sb),
		&gui.entity_list.scroll_index,
		&gui.entity_list.active,
	)

	if handle, ok := sa.get_safe(gui.entity_list.handles, int(gui.entity_list.active)); ok {
		return handle
	}
	return {}
}

gui_tileset_pallete :: proc(pos: World_Pos, tileset: ^Tileset) {
	tileset_width := tileset.tex.width / i32(TILE_SIZE)
	for &tile, i in tileset.tiles {
		col := i32(i) % tileset_width
		row := i32(i) / tileset_width
		rl.DrawTexturePro(
			tileset.tex,
			{tile.tileset_pos.x, tile.tileset_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)},
			{
				pos.x + f32(col * i32(TILE_SIZE)),
				pos.y + f32(row * i32(TILE_SIZE)),
				f32(TILE_SIZE),
				f32(TILE_SIZE),
			},
			{},
			0,
			rl.WHITE,
		)
	}
}
