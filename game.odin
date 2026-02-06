package game

import hm "core:container/handle_map"
import sa "core:container/small_array"
import "core:encoding/json"
import "core:fmt"
import os "core:os/os2"
import rl "vendor:raylib"

World :: struct {
	camera:  rl.Camera2D,
	tilemap: Tilemap,
}

Screen_Pos :: [2]f32
World_Pos :: [2]f32

tex_load :: proc(tex_path: cstring) -> rl.Texture {
	@(static) cache := map[cstring]rl.Texture{}

	if ok := tex_path in cache; !ok {
		cache[tex_path] = rl.LoadTexture(tex_path)
	}

	return cache[tex_path]
}

main :: proc() {
	// INITIALIZE
	//----------------------------------------------------------------------------------

	rl.InitWindow(1280, 720, "Odin play!")

	// initialize world
	w := World{}

	// camera
	w.camera = rl.Camera2D {
		offset = {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2},
		zoom   = 2.0,
	}

	// tile map
	w.tilemap = tilemap_make("tex/t_woods.png", {10, 10})
	if os.exists("data/tilemap.json") {
		if err := tilemap_load("data/tilemap.json", &w.tilemap); err != nil {
			fmt.eprintfln("Unable to load tilemap: %v", err)
		}
	}
	defer tilemap_destroy(&w.tilemap)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		mouse_w_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), w.camera)

		// UPDATE
		//----------------------------------------------------------------------------------

		// apply editor inputs
		editor.selected_tile_h = Tile_Handle(editor.input.tileset_pallete.active_index)
		editor.mode = editor.selected_tile_h != -1 ? .TILE_PAINT : .TILE_SELECT
		editor.selected_entity_h, _ = sa.get_safe(
			editor.input.entity_list.handles,
			int(editor.input.entity_list.active_index),
		)
		editor.hide_grid = editor.input.grid_checkbox.is_checked
		editor.selected_layer = editor.input.layer_spinner.value
		if editor.selected_tile_placement != nil {
			selected_pos := tile_placement_pos(&w.tilemap, editor.selected_tile_placement)
			editor.selected_tile_placement = &w.tilemap.layers[editor.selected_layer][selected_pos.y][selected_pos.x]
		}

		// handle mouse click
		if rl.IsMouseButtonDown(.LEFT) {
			switch (editor.mode) {
			case .TILE_SELECT:
				if pos, ok := world_pos_to_tile(&w.tilemap, mouse_w_pos); ok {
					if rl.IsMouseButtonPressed(.LEFT) {
						tile_placement := &w.tilemap.layers[editor.selected_layer][pos.y][pos.x]
						cur_pos := tile_placement_pos(&w.tilemap, editor.selected_tile_placement)
						editor.selected_tile_placement = cur_pos == pos ? nil : tile_placement
					}
				}
			case .TILE_PAINT:
				if pos, ok := world_pos_to_tile(&w.tilemap, mouse_w_pos); ok {
					tile_placement := &w.tilemap.layers[editor.selected_layer][pos.y][pos.x]
					tile_placement.tile_h = editor.selected_tile_h
				}
			}
		}

		// player
		if player, ok := hm.get(&w.tilemap.entities, w.tilemap.player_h); ok {
			is_movement_active := entity_movement_advance(player, rl.GetFrameTime())
			if !is_movement_active {
				og_pos := player.pos

				// determine target pos
				target_pos := og_pos
				if rl.IsKeyDown(.W) do target_pos.y -= 1
				if rl.IsKeyDown(.S) do target_pos.y += 1
				if rl.IsKeyDown(.A) do target_pos.x -= 1
				if rl.IsKeyDown(.D) do target_pos.x += 1

				// check entity collisions
				it := hm.iterator_make(&w.tilemap.entities)
				for e in hm.iterate(&it) {
					if player == e do continue

					for _, axis in target_pos {
						if rl.CheckCollisionRecs(rec(target_pos), rec(e)) {
							target_pos[axis] = og_pos[axis]
						}
					}
				}

				// check tile collisions

				tilemap_it := tilemap_iterator_make(&w.tilemap)
				for tile_placement, tile_pos, layer_num in tilemap_iterate(&tilemap_it) {
					if !tile_placement.is_collision do continue

					for _, axis in target_pos {
						if rl.CheckCollisionRecs(rec(target_pos), rec(tile_pos)) {
							target_pos[axis] = og_pos[axis]
						}
					}
				}

				// check tilemap OOB
				for _, axis in target_pos {
					if !rl.CheckCollisionRecs(rec(target_pos), rec(&w.tilemap)) {
						target_pos[axis] = og_pos[axis]
					}
				}

				if target_pos != og_pos {
					entity_movement_start(player, target_pos)
				}
			}

			// // point camera to player
			player_rec := rec(player)
			w.camera.target = {
				player_rec.x + player_rec.width / 2,
				player_rec.y + player_rec.height / 2,
			}
		}

		//----------------------------------------------------------------------------------


		// DRAW
		//----------------------------------------------------------------------------------

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// WORLD
		{
			rl.BeginMode2D(w.camera)

			// tilemap
			tilemap_draw(&w.tilemap)

			// editor world overlay

			// selected entity bounding box
			if e, ok := hm.get(&w.tilemap.entities, editor.selected_entity_h); ok {
				e_rec := rec(e)
				rl.DrawBoundingBox(
					{{e_rec.x, e_rec.y, 0}, {e_rec.x + e_rec.width, e_rec.y + e_rec.height, 0}},
					rl.RED,
				)
			}

			// selected tile placement
			if editor.selected_tile_placement != nil {
				selected_tile_pos := tile_placement_pos(&w.tilemap, editor.selected_tile_placement)
				rl.DrawRectangleLinesEx(rec(selected_tile_pos), 1, {255, 255, 255, 160})
			}

			// tile hover
			if pos, ok := world_pos_to_tile(&w.tilemap, mouse_w_pos); ok {
				tile_placement := &w.tilemap.layers[editor.selected_layer][pos.y][pos.x]
				switch (editor.mode) {
				case .TILE_SELECT:
					rl.DrawRectangleLinesEx(rec(pos), 1, {255, 255, 255, 200})
				case .TILE_PAINT:
					rl.DrawRectangleRec(rec(pos), {0, 0, 0, 50})
				}
			}

			rl.EndMode2D()
		}

		// GUI
		{
			// toolbar
			bg_color := rl.GetColor(
				u32(
					rl.GuiGetStyle(
						rl.GuiControl.DEFAULT,
						i32(rl.GuiDefaultProperty.BACKGROUND_COLOR),
					),
				),
			)

			toolbar_height := f32(40)
			rl.DrawRectangleRec({0, 0, f32(rl.GetScreenWidth()), toolbar_height}, bg_color)

			// save button
			if rl.GuiButton(
				{5, toolbar_height / 5, toolbar_height * 2, toolbar_height / 1.5},
				"Save",
			) {
				if data, err := json.marshal(w.tilemap, {pretty = true}); err != nil {
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
				toolbar_height / 2.5,
			}
			rl.DrawText(
				mode_text,
				i32(mode_indicator_s_pos.x),
				i32(mode_indicator_s_pos.y),
				4,
				rl.BLACK,
			)

			mode_indicator_rec := rl.Rectangle {
				mode_indicator_s_pos.x - 125,
				toolbar_height / 5,
				100,
				25,
			}
			rl.GuiSpinner(
				mode_indicator_rec,
				"Layer",
				&editor.input.layer_spinner.value,
				0,
				LAYERS_NUM - 1,
				true,
			)
			editor.input.layer_spinner.value = clamp(
				editor.input.layer_spinner.value,
				0,
				LAYERS_NUM - 1,
			)

			rl.GuiCheckBox(
				{mode_indicator_rec.x - 125, mode_indicator_rec.y, 25, 25},
				"Hide grid",
				&editor.input.grid_checkbox.is_checked,
			)

			if !editor.hide_grid {
				rl.BeginMode2D(w.camera)
				tilemap_it := tilemap_iterator_make(&w.tilemap)
				for tile_placement, tile_pos, layer_num in tilemap_iterate(&tilemap_it) {
					rl.DrawRectangleLinesEx(rec(tile_pos), 0.5, {0, 0, 0, 50})
				}
				rl.EndMode2D()
			}

			// left panel
			l_panel_width := f32(75)
			l_panel_s_pos := Screen_Pos{5, toolbar_height + 5}
			rl.GuiPanel(
				{l_panel_s_pos.x, l_panel_s_pos.y, l_panel_width, f32(rl.GetScreenHeight() - 75)},
				"Entities",
			)

			// entity list
			editor_entity_list(
				{
					l_panel_s_pos.x,
					l_panel_s_pos.y + 24,
					l_panel_width,
					f32(rl.GetScreenHeight() - 75),
				},
				&w.tilemap.entities,
				editor.selected_entity_h,
			)

			// right panel
			r_panel_padding := f32(10)
			r_panel_width := f32(w.tilemap.tileset.tex.width) + r_panel_padding
			r_panel_height := f32(w.tilemap.tileset.tex.height) + r_panel_padding + 25
			r_panel_s_pos := Screen_Pos {
				f32(rl.GetScreenWidth()) - r_panel_width - 5,
				toolbar_height + 5,
			}
			rl.GuiPanel(
				{r_panel_s_pos.x, r_panel_s_pos.y, r_panel_width, r_panel_height},
				"Tileset",
			)

			// tileset pallete
			editor_tileset_pallete(
				r_panel_s_pos + {r_panel_padding / 2, (-r_panel_padding / 2) + 35},
				w.tilemap.tileset,
				editor.selected_tile_h,
			)

			// selected tile placement panel
			if editor.mode == .TILE_SELECT && editor.selected_tile_placement != nil {
				placement_panel_rec := rl.Rectangle {
					r_panel_s_pos.x,
					r_panel_s_pos.y + r_panel_height + 5,
					r_panel_width,
					200,
				}
				rl.GuiPanel(placement_panel_rec, "Tile placement")

				rl.GuiCheckBox(
					{placement_panel_rec.x + 15, placement_panel_rec.y + 40, 25, 25},
					"Is collision",
					&editor.selected_tile_placement.is_collision,
				)
			}
		}

		rl.EndDrawing()

		//----------------------------------------------------------------------------------

		// CLEANUP
		//----------------------------------------------------------------------------------

		free_all(context.temp_allocator)

		//----------------------------------------------------------------------------------
	}

	// DE-INITIALIZE
	//----------------------------------------------------------------------------------

	rl.CloseWindow()

	//----------------------------------------------------------------------------------
}
