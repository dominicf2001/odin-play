package game

import hm "core:container/handle_map"
import "core:encoding/json"
import "core:fmt"
import os "core:os/os2"
import rl "vendor:raylib"

Mode :: enum {
	TILE_SELECT,
	TILE_PAINT,
}

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

	// initialize mode
	mode := Mode.TILE_SELECT

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
		// UPDATE
		//----------------------------------------------------------------------------------

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

		// Tilemap
		{
			rl.BeginMode2D(w.camera)

			tilemap_draw(&w.tilemap)

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
			switch (mode) {
			case .TILE_SELECT:
				mode_text = "-- TILE SELECT -- "
			case .TILE_PAINT:
				mode_text = "-- TILE PAINT -- "
			}
			rl.DrawText(
				mode_text,
				rl.GetScreenWidth() - i32(len(mode_text)) * 6,
				i32(toolbar_height / 2.5),
				4,
				rl.BLACK,
			)

			// left panel
			l_panel_width := f32(75)
			l_panel_s_pos := Screen_Pos{5, toolbar_height + 5}
			rl.GuiPanel(
				{l_panel_s_pos.x, l_panel_s_pos.y, l_panel_width, f32(rl.GetScreenHeight() - 75)},
				"Entities",
			)

			// entity list
			selected_entity_h := gui_entity_list(
				{
					l_panel_s_pos.x,
					l_panel_s_pos.y + 24,
					l_panel_width,
					f32(rl.GetScreenHeight() - 75),
				},
				&w.tilemap.entities,
			)
			if e, ok := hm.get(&w.tilemap.entities, selected_entity_h); ok {
				rl.BeginMode2D(w.camera)

				e_rec := rec(e)
				rl.DrawBoundingBox(
					{{e_rec.x, e_rec.y, 0}, {e_rec.x + e_rec.width, e_rec.y + e_rec.height, 0}},
					rl.RED,
				)

				rl.EndMode2D()
			}

			// right panel
			r_panel_padding := f32(10)
			r_panel_width := f32(w.tilemap.tileset.tex.width) + r_panel_padding
			r_panel_height := f32(w.tilemap.tileset.tex.height) + r_panel_padding + 50
			r_panel_s_pos := Screen_Pos {
				f32(rl.GetScreenWidth()) - r_panel_width - 5,
				toolbar_height + 5,
			}
			rl.GuiPanel(
				{r_panel_s_pos.x, r_panel_s_pos.y, r_panel_width, r_panel_height},
				"Tileset",
			)

			gui.selected_layer = clamp(gui.selected_layer, 0, 1)
			rl.GuiSpinner(
				{r_panel_s_pos.x + 35, r_panel_s_pos.y + 30, 100, 25},
				"Layer",
				&gui.selected_layer,
				0,
				1,
				true,
			)

			// tileset pallete
			gui_tileset_pallete(
				r_panel_s_pos + {r_panel_padding / 2, (-r_panel_padding / 2) + 65},
				&w.tilemap.tileset,
				&gui.tileset_pallete.active_tile_h,
			)

			// update mode
			mode = gui.tileset_pallete.active_tile_h != -1 ? .TILE_PAINT : .TILE_SELECT

			mouse_w_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), w.camera)
			switch (mode) {
			case .TILE_SELECT:
				if pos, ok := world_pos_to_tile(&w.tilemap, mouse_w_pos); ok {
					tile_placement := &w.tilemap.layers[gui.selected_layer][pos.y][pos.x]

					rl.BeginMode2D(w.camera)
					rl.DrawRectangleLinesEx(rec(pos), 1, {255, 255, 255, 200})
					rl.EndMode2D()

					if rl.IsMouseButtonPressed(.LEFT) {
						if gui.selected_tile_pos == nil {
							gui.selected_tile_pos = new(Tile_Pos)
						}

						if gui.selected_tile_pos^ == pos {
							free(gui.selected_tile_pos)
							gui.selected_tile_pos = nil
						} else {
							gui.selected_tile_pos^ = pos
						}
					}
				} else if (rl.IsMouseButtonPressed(.LEFT)) {
					free(gui.selected_tile_pos)
					gui.selected_tile_pos = nil
				}

				if gui.selected_tile_pos != nil {
					rl.BeginMode2D(w.camera)
					rl.DrawRectangleLinesEx(rec(gui.selected_tile_pos^), 1, {255, 255, 255, 160})
					rl.EndMode2D()
					rl.GuiPanel(
						{
							r_panel_s_pos.x,
							r_panel_s_pos.y + r_panel_height + 5,
							r_panel_width,
							200,
						},
						"Tile placement",
					)
				}
			case .TILE_PAINT:
				if pos, ok := world_pos_to_tile(&w.tilemap, mouse_w_pos); ok {
					tile_placement := &w.tilemap.layers[gui.selected_layer][pos.y][pos.x]

					rl.BeginMode2D(w.camera)
					rl.DrawRectangleRec(rec(pos), {0, 0, 0, 50})
					rl.EndMode2D()

					if rl.IsMouseButtonPressed(.LEFT) {
						tile_placement.tile_h = Tile_Handle(gui.tileset_pallete.active_tile_h)
					}
				}
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
