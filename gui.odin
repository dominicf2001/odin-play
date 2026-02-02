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

gui_entity_list :: proc(
	entities: ^hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle),
) -> Entity_Handle {
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
		{0, 0, 74, 200},
		strings.to_cstring(&entity_list_sb),
		&gui.entity_list.scroll_index,
		&gui.entity_list.active,
	)

	if handle, ok := sa.get_safe(gui.entity_list.handles, int(gui.entity_list.active)); ok {
		return handle
	}
	return {}
}
