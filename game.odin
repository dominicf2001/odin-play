package game

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

World :: struct {
	camera:  rl.Camera2D,
	tilemap: Tilemap,
}

World_Pos :: [2]f32
Screen_Pos :: [2]f32

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

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin play!")

	// initialize world
	w := World{}

	// camera
	w.camera = rl.Camera2D {
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		zoom   = 2.0,
	}

	// tile map
	w.tilemap = tilemap_load("tex/t_woods.png", {10, 10})
	defer tilemap_unload(&w.tilemap)

	// player entity
	player_h := hm.add(
		&w.tilemap.entities,
		Entity{name = "Player", pos = {0, 0}, tex_path = "tex/player.png"},
	)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&w.tilemap.entities, player_h); ok {
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
						if rl.CheckCollisionRecs(t_rec(target_pos), t_rec(e)) {
							target_pos[axis] = og_pos[axis]
						}
					}
				}

				// check tilemap OOB
				for _, axis in target_pos {
					if !rl.CheckCollisionRecs(t_rec(target_pos), t_rec(&w.tilemap)) {
						target_pos[axis] = og_pos[axis]
					}
				}

				if target_pos != og_pos {
					entity_movement_start(player, target_pos)
				}
			}

			// point camera to player
			player_rec := t_rec(player)
			w.camera.target = {
				player_rec.x + f32(TILE_SIZE) / 2,
				player_rec.y + f32(TILE_SIZE) / 2,
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
			// entity list
			selected_entity_h := gui_entity_list({0, 0, 74, 200}, &w.tilemap.entities)
			if e, ok := hm.get(&w.tilemap.entities, selected_entity_h); ok {
				rl.BeginMode2D(w.camera)

				e_rec := t_rec(e)
				rl.DrawBoundingBox(
					{
						{e_rec.x, e_rec.y, 0},
						{e_rec.x + f32(TILE_SIZE), e_rec.y + f32(TILE_SIZE), 0},
					},
					rl.RED,
				)

				rl.EndMode2D()
			}

			// tileset pallete
			selected_tile_h := gui_tileset_pallete(
				{0, WINDOW_HEIGHT - f32(w.tilemap.tileset.tex.height)},
				&w.tilemap.tileset,
			)
			if selected_tile_h != -1 {
				rl.BeginMode2D(w.camera)
				mouse_w_pos: World_Pos = rl.GetScreenToWorld2D(rl.GetMousePosition(), w.camera)
				if pos, ok := world_pos_to_tilemap_pos(&w.tilemap, mouse_w_pos); ok {
					tile_placement := &w.tilemap.placements[pos.y][pos.x]

					if rl.CheckCollisionPointRec(mouse_w_pos, t_rec(pos)) {
						rl.DrawRectangleRec(t_rec(pos), {0, 0, 0, 50})
					}

					if rl.IsMouseButtonDown(.LEFT) {
						tile_placement.tile_h = Tile_Handle(selected_tile_h)
					}
				}
				rl.EndMode2D()
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
