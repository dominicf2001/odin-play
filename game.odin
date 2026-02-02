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

	// load world
	world := World {
		camera = rl.Camera2D{offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, zoom = 1.0},
	}

	// player entity
	world.player_h = hm.add(
		&world.entities,
		Entity {
			"Player",
			{
				TILE_GRID_ORIGIN.x + ((TILE_GRID_SIZE * TILE_SIZE) / 4),
				TILE_GRID_ORIGIN.y + ((TILE_GRID_SIZE * TILE_SIZE) / 4),
				TILE_SIZE,
				TILE_SIZE,
			},
			"tex/player.png",
			{},
		},
	)

	tile_grid_load(&world.t_grid)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&world.entities, world.player_h); ok {
			// calculate player movement
			move := rl.Vector2{0, 0}
			if rl.IsKeyPressed(.W) do move.y = -TILE_SIZE
			if rl.IsKeyPressed(.S) do move.y = TILE_SIZE
			if rl.IsKeyPressed(.A) do move.x = -TILE_SIZE
			if rl.IsKeyPressed(.D) do move.x = TILE_SIZE

			new_player_rect := player.rect
			new_player_rect.x += move.x
			new_player_rect.y += move.y

			// check entity collisions
			it := hm.iterator_make(&world.entities)
			for e in hm.iterate(&it) {
				if player == e do continue

				if move.x != 0 && rl.CheckCollisionRecs(new_player_rect, e.rect) {
					new_player_rect.x -= move.x
					move.x = 0
				}

				if move.y != 0 && rl.CheckCollisionRecs(new_player_rect, e.rect) {
					new_player_rect.y -= move.y
					move.y = 0
				}
			}

			// check tile grid out of bounds
			if new_player_rect.x < TILE_GRID_ORIGIN.x {
				new_player_rect.x -= move.x
			}

			if new_player_rect.y < TILE_GRID_ORIGIN.y {
				new_player_rect.y -= move.y
			}

			player.rect = new_player_rect

			// point camera to player
			world.camera.target = {
				player.rect.x + player.rect.width / 2,
				player.rect.y + player.rect.height / 2,
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

			tile_grid_draw(&world.t_grid)

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
					{
						{e.rect.x, e.rect.y, 0},
						{e.rect.x + e.rect.width, e.rect.y + e.rect.height, 0},
					},
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
