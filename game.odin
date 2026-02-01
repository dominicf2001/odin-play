package game

import hm "core:container/handle_map"
import sa "core:container/small_array"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

MAX_ENTITIES :: 1024

PLAYER_SPEED :: 500.0

World :: struct {
	camera:        rl.Camera2D,
	player_handle: Entity_Handle,
	entities:      hm.Static_Handle_Map(MAX_ENTITIES, Entity, Entity_Handle),
}

Entity_Handle :: distinct hm.Handle32

Entity :: struct {
	name:   string,
	rect:   rl.Rectangle,
	tex:    rl.Texture2D,
	handle: Entity_Handle,
}

main :: proc() {
	// INITIALIZE
	//----------------------------------------------------------------------------------

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin play!")

	world := World {
		camera = rl.Camera2D{offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, zoom = 1.0},
	}

	// player entity
	world.player_handle = hm.add(
		&world.entities,
		Entity{"Player", {0, 0, 50, 50}, rl.LoadTexture("textures/player.png"), {}},
	)

	// non-player entities
	obstacle_handle := hm.add(
		&world.entities,
		Entity{"Obstacle", {250, 500, 500, 50}, rl.LoadTexture("textures/obstacle.jpg"), {}},
	)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&world.entities, world.player_handle); ok {
			// calculate player movement
			move := rl.Vector2{0, 0}
			if rl.IsKeyDown(.W) do move.y = -1
			if rl.IsKeyDown(.S) do move.y = 1
			if rl.IsKeyDown(.A) do move.x = -1
			if rl.IsKeyDown(.D) do move.x = 1
			move = rl.Vector2Normalize(move) * rl.GetFrameTime() * PLAYER_SPEED

			new_player_rect := player.rect
			new_player_rect.x += move.x
			new_player_rect.y += move.y

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
		rl.ClearBackground(rl.BLUE)

		// World
		rl.BeginMode2D(world.camera)
		{
			// entities
			it := hm.iterator_make(&world.entities)
			for e in hm.iterate(&it) {
				rl.DrawTexturePro(
					e.tex,
					{width = f32(e.tex.width), height = f32(e.tex.height)},
					e.rect,
					{},
					0,
					rl.WHITE,
				)
			}
		}
		rl.EndMode2D()

		// UI
		{
			selected_entity_handle := gui_entity_list(&world.entities)
			if e, ok := hm.get(&world.entities, selected_entity_handle); ok {
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
