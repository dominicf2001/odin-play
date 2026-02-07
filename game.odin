package game

import hm "core:container/handle_map"
import sa "core:container/small_array"
import "core:encoding/ini"
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

		// editor state
		editor_apply_input()
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

			// tile placement grid
			if !editor.hide_grid {
				tilemap_it := tilemap_iterator_make(&w.tilemap)
				for tile_placement, tile_pos, layer_num in tilemap_iterate(&tilemap_it) {
					rl.DrawRectangleLinesEx(rec(tile_pos), 0.5, {0, 0, 0, 50})
				}
			}

			rl.EndMode2D()
		}

		// GUI
		{
			// toolbar
			toolbar_rec := editor_toolbar(w)

			// entity panel
			editor_entity_panel(
				{5, toolbar_rec.height + 5, 75, f32(rl.GetScreenHeight() - 75)},
				&w.tilemap.entities,
				editor.selected_entity_h,
			)

			// tileset panel
			tileset_panel_rec := editor_tileset_panel(
				{
					f32(rl.GetScreenWidth()) - f32(w.tilemap.tileset.tex.width) - 5,
					toolbar_rec.height + 5,
				},
				w.tilemap,
				editor.selected_tile_h,
			)

			// selected tile placement panel
			if editor.mode == .TILE_SELECT && editor.selected_tile_placement != nil {
				editor_tile_placement_panel(
					{
						tileset_panel_rec.x,
						tileset_panel_rec.y + tileset_panel_rec.height + 5,
						tileset_panel_rec.width,
						200,
					},
					editor.selected_tile_placement^,
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
