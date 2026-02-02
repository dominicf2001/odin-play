package game

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

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
	world := World{}

	// camera
	world.camera = rl.Camera2D {
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		zoom   = 1.0,
	}

	// player entity
	world.player_h = hm.add(
		&world.entities,
		Entity{name = "Player", t_pos = {0, 0}, tex_path = "tex/player.png"},
	)

	// tile map
	world.t_map = tile_map_make(20)
	defer tile_map_destroy(&world.t_map)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&world.entities, world.player_h); ok {
			is_movement_active := entity_movement_advance(player, rl.GetFrameTime())
			if !is_movement_active {
				og_t_pos := player.t_pos

				// determine target pos
				to_t_pos := og_t_pos
				if rl.IsKeyDown(.W) do to_t_pos.y -= 1
				if rl.IsKeyDown(.S) do to_t_pos.y += 1
				if rl.IsKeyDown(.A) do to_t_pos.x -= 1
				if rl.IsKeyDown(.D) do to_t_pos.x += 1

				target_t_rec := rec(&world.t_map.rows[to_t_pos.y][to_t_pos.x])

				// check entity collisions
				it := hm.iterator_make(&world.entities)
				for e in hm.iterate(&it) {
					if player == e do continue

					if to_t_pos.x != og_t_pos.x && rl.CheckCollisionRecs(target_t_rec, rec(e)) {
						target_t_rec.x = f32(og_t_pos.x)
						to_t_pos.x = og_t_pos.x
					}
					if to_t_pos.y != og_t_pos.y && rl.CheckCollisionRecs(target_t_rec, rec(e)) {
						target_t_rec.y = f32(og_t_pos.y)
						to_t_pos.y = og_t_pos.y
					}
				}

				// check tilemap OOB
				if to_t_pos.x != og_t_pos.x &&
				   !rl.CheckCollisionRecs(target_t_rec, rec(&world.t_map)) {
					target_t_rec.x = f32(og_t_pos.x)
					to_t_pos.x = og_t_pos.x
				}
				if to_t_pos.y != og_t_pos.y &&
				   !rl.CheckCollisionRecs(target_t_rec, rec(&world.t_map)) {
					target_t_rec.y = f32(og_t_pos.y)
					to_t_pos.y = og_t_pos.y
				}

				if to_t_pos != og_t_pos {
					entity_movement_start(player, to_t_pos)
				}
			}

			// point camera to player
			player_w_pos := w_pos(player)
			world.camera.target = {player_w_pos.x + TILE_SIZE / 2, player_w_pos.y + TILE_SIZE / 2}
		}

		//----------------------------------------------------------------------------------


		// DRAW
		//----------------------------------------------------------------------------------

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// World
		{
			rl.BeginMode2D(world.camera)

			// tile map
			draw(&world.t_map)

			// entities
			it := hm.iterator_make(&world.entities)
			for e in hm.iterate(&it) {
				draw(e)
			}

			rl.EndMode2D()
		}

		// UI
		{
			selected_entity_h := gui_entity_list(&world.entities)

			if e, ok := hm.get(&world.entities, selected_entity_h); ok {
				rl.BeginMode2D(world.camera)

				w_pos := w_pos(e)
				rl.DrawBoundingBox(
					{{w_pos.x, w_pos.y, 0}, {w_pos.x + TILE_SIZE, w_pos.y + TILE_SIZE, 0}},
					rl.RED,
				)

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
