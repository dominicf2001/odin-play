package game
import hm "core:container/handle_map"
import sa "core:container/small_array"
import "core:encoding/json"
import "core:fmt"
import os "core:os/os2"
import "core:strings"
import rl "vendor:raylib"

PANEL_HEADER_HEIGHT: f32 : 25

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
}

Editor_Input :: struct {
	layer_spinner:        struct {
		value: i32,
	},
	grid_checkbox:        struct {
		is_checked: bool,
	},
	entity_panel:         struct {
		handles:      sa.Small_Array(ENTITIES_MAX, Entity_Handle),
		active_index: i32,
		scroll_index: i32,
	},
	tileset_panel:        struct {
		active_index: i32,
	},
	tile_placement_panel: struct {
		is_collision_checked: bool,
	},
}

@(private = "file")
input := Editor_Input {
	entity_panel = {active_index = -1},
	tileset_panel = {active_index = -1},
}

editor := Editor{}

editor_apply_input :: proc() {
	editor.selected_tile_h = Tile_Handle(input.tileset_panel.active_index)
	editor.mode = editor.selected_tile_h != -1 ? .TILE_PAINT : .TILE_SELECT
	editor.selected_entity_h, _ = sa.get_safe(
		input.entity_panel.handles,
		int(input.entity_panel.active_index),
	)
	editor.hide_grid = input.grid_checkbox.is_checked
	editor.selected_layer = input.layer_spinner.value
	if editor.selected_tile_placement != nil {
		editor.selected_tile_placement.is_collision =
			input.tile_placement_panel.is_collision_checked
	}
}

editor_toolbar :: proc(world: World) -> rl.Rectangle {
	bg_color := rl.GetColor(
		u32(rl.GuiGetStyle(rl.GuiControl.DEFAULT, i32(rl.GuiDefaultProperty.BACKGROUND_COLOR))),
	)

	toolbar_rec := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), 40}
	rl.DrawRectangleRec(toolbar_rec, bg_color)

	// save button
	if rl.GuiButton(
		{5, toolbar_rec.height / 5, toolbar_rec.height * 2, toolbar_rec.height / 1.5},
		"Save",
	) {
		if data, err := json.marshal(world.tilemap, {pretty = true}); err != nil {
			fmt.eprintfln("Unable to marshal tilemap: %v", err)
		} else {
			if err := os.write_entire_file("data/tilemap.json", data); err != nil {
				fmt.eprintfln("Unable to write tilemap: %v", err)
			}
		}
	}

	// mode indicator
	mode_text: cstring
	switch (editor.mode) {
	case .TILE_SELECT:
		mode_text = "-- TILE SELECT -- "
	case .TILE_PAINT:
		mode_text = "-- TILE PAINT -- "
	}
	mode_indicator_s_pos := Screen_Pos {
		f32(rl.GetScreenWidth() - i32(len(mode_text)) * 6),
		toolbar_rec.height / 2.5,
	}
	rl.DrawText(mode_text, i32(mode_indicator_s_pos.x), i32(mode_indicator_s_pos.y), 4, rl.BLACK)

	mode_indicator_rec := rl.Rectangle {
		mode_indicator_s_pos.x - 125,
		toolbar_rec.height / 5,
		100,
		25,
	}
	rl.GuiSpinner(mode_indicator_rec, "Layer", &input.layer_spinner.value, 0, LAYERS_NUM - 1, true)
	input.layer_spinner.value = clamp(input.layer_spinner.value, 0, LAYERS_NUM - 1)

	rl.GuiCheckBox(
		{mode_indicator_rec.x - 125, mode_indicator_rec.y, 25, 25},
		"Hide grid",
		&input.grid_checkbox.is_checked,
	)

	return toolbar_rec
}

editor_entity_panel :: proc(
	bounds: rl.Rectangle,
	entities: ^Entity_Handle_Map,
	selected_entity_h: Entity_Handle,
) -> rl.Rectangle {
	rl.GuiPanel(bounds, "Entities")

	entity_list_sb := strings.builder_make(context.temp_allocator)

	sa.clear(&input.entity_panel.handles)
	it, i := hm.iterator_make(entities), uint(0)
	for e in hm.iterate(&it) {
		if e.handle == selected_entity_h {
			input.entity_panel.active_index = i32(i)
		}

		sa.append(&input.entity_panel.handles, e.handle)
		strings.write_string(&entity_list_sb, e.name)
		if i < hm.len(entities^) - 1 {
			strings.write_byte(&entity_list_sb, ';')
		}
		i += 1
	}

	rl.GuiListView(
		{bounds.x, bounds.y + (PANEL_HEADER_HEIGHT - 1), bounds.width, bounds.height},
		strings.to_cstring(&entity_list_sb),
		&input.entity_panel.scroll_index,
		&input.entity_panel.active_index,
	)

	return bounds
}

editor_tileset_panel :: proc(
	s_pos: Screen_Pos,
	tilemap: Tilemap,
	active_tile_h: Tile_Handle,
) -> rl.Rectangle {
	panel_rec := rl.Rectangle {
		s_pos.x,
		s_pos.y,
		f32(tilemap.tileset.tex.width),
		f32(tilemap.tileset.tex.height) + PANEL_HEADER_HEIGHT,
	}
	rl.GuiPanel(panel_rec, "Tileset")

	pallete_s_pos := s_pos + {0, PANEL_HEADER_HEIGHT}

	input.tileset_panel.active_index = i32(active_tile_h)
	for &tile, i in tilemap.tileset.tiles {
		tile_h := Tile_Handle(i)

		tileset_width := tilemap.tileset.tex.width / i32(TILE_SIZE)
		col := i32(tile_h) % tileset_width
		row := i32(tile_h) / tileset_width

		tile_bounds := rl.Rectangle {
			pallete_s_pos.x + f32(col * i32(TILE_SIZE)),
			pallete_s_pos.y + f32(row * i32(TILE_SIZE)),
			f32(TILE_SIZE),
			f32(TILE_SIZE),
		}

		rl.DrawTexturePro(
			tilemap.tileset.tex,
			{tile.tileset_pos.x, tile.tileset_pos.y, f32(TILE_SIZE), f32(TILE_SIZE)},
			tile_bounds,
			{},
			0,
			rl.WHITE,
		)

		is_mouse_colliding := rl.CheckCollisionPointRec(rl.GetMousePosition(), tile_bounds)
		if i32(tile_h) == input.tileset_panel.active_index {
			line_thickness: f32 = is_mouse_colliding ? 2 : 1
			rl.DrawRectangleLinesEx(tile_bounds, line_thickness, rl.BLACK)

			if is_mouse_colliding && rl.IsMouseButtonPressed(.LEFT) {
				input.tileset_panel.active_index = -1
			}
		} else if is_mouse_colliding {
			rl.DrawRectangleLinesEx(tile_bounds, 1, rl.LIGHTGRAY)

			if rl.IsMouseButtonPressed(.LEFT) {
				input.tileset_panel.active_index = i32(tile_h)
			}
		}
	}

	return panel_rec
}

editor_tile_placement_panel :: proc(
	bounds: rl.Rectangle,
	placement: Tile_Placement,
) -> rl.Rectangle {
	rl.GuiPanel(bounds, "Tile placement")

	input.tile_placement_panel.is_collision_checked = placement.is_collision

	rl.GuiCheckBox(
		{bounds.x + 15, bounds.y + 40, PANEL_HEADER_HEIGHT, PANEL_HEADER_HEIGHT},
		"Is collision",
		&input.tile_placement_panel.is_collision_checked,
	)

	return bounds
}
