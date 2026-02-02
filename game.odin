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
		Entity {
			"Player",
			{
				TILE_MAP_ORIGIN.x + ((TILE_GRID_SIZE * TILE_SIZE) / 4),
				TILE_MAP_ORIGIN.y + ((TILE_GRID_SIZE * TILE_SIZE) / 4),
				TILE_SIZE,
				TILE_SIZE,
			},
			"tex/player.png",
			{},
		},
	)

	// tile map
	world.t_map = tile_map_make(20)
	defer tile_map_destroy(&world.t_map)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&world.entities, world.player_h); ok {
			// calculate player movement
			move := rl.Vector2{0, 0}

			@(static) secs_since_press := f32(0)

			if secs_since_press > 0.1 {
				if rl.IsKeyDown(.W) do move.y = -TILE_SIZE
				if rl.IsKeyDown(.S) do move.y = TILE_SIZE
				if rl.IsKeyDown(.A) do move.x = -TILE_SIZE
				if rl.IsKeyDown(.D) do move.x = TILE_SIZE

				secs_since_press = 0
			} else {
				secs_since_press += rl.GetFrameTime()
			}

			new_player_rec := player.rec
			new_player_rec.x += move.x
			new_player_rec.y += move.y

			// check entity collisions
			it := hm.iterator_make(&world.entities)
			for e in hm.iterate(&it) {
				if player == e do continue

				if move.x != 0 && rl.CheckCollisionRecs(new_player_rec, e.rec) {
					new_player_rec.x -= move.x
					move.x = 0
				}

				if move.y != 0 && rl.CheckCollisionRecs(new_player_rec, e.rec) {
					new_player_rec.y -= move.y
					move.y = 0
				}
			}

			if new_player_rec.x < TILE_MAP_ORIGIN.x {
				new_player_rec.x -= move.x
			}

			if new_player_rec.y < TILE_MAP_ORIGIN.y {
				new_player_rec.y -= move.y
			}

			player.rec = new_player_rec

			// point camera to player
			world.camera.target = {
				player.rec.x + player.rec.width / 2,
				player.rec.y + player.rec.height / 2,
			}
		}

		//----------------------------------------------------------------------------------


		// DRAW
		//----------------------------------------------------------------------------------

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// World
		{
			rl.BeginMode2D(world.camera)
			// tiles

			tile_map_draw(&world.t_map)

			// entities
			it := hm.iterator_make(&world.entities)
			for e in hm.iterate(&it) {
				entity_draw(e)
			}
			rl.EndMode2D()
		}

		// UI
		{
			selected_entity_h := gui_entity_list(&world.entities)

			if e, ok := hm.get(&world.entities, selected_entity_h); ok {
				rl.BeginMode2D(world.camera)
				rl.DrawBoundingBox(
					{{e.rec.x, e.rec.y, 0}, {e.rec.x + e.rec.width, e.rec.y + e.rec.height, 0}},
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
