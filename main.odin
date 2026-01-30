package main

import "core:fmt"
import la "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

PLAYER_SPEED :: 500.0

Game :: struct {
	world: struct {
		camera:   rl.Camera2D,
		player:   ^Entity,
		entities: [dynamic]Entity,
	},
	ui:    struct {
		entity_list: struct {
			active:       i32,
			scroll_index: i32,
		},
	},
}

Entity :: struct {
	name: string,
	rect: rl.Rectangle,
	tex:  rl.Texture2D,
}

main :: proc() {
	// INITIALIZE
	//----------------------------------------------------------------------------------

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin play!")

	game := Game {
		world = {
			camera = rl.Camera2D{offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, zoom = 1.0},
			entities = [dynamic]Entity{},
		},
	}

	// player entity
	append(
		&game.world.entities,
		Entity{"Player", {0, 0, 50, 50}, rl.LoadTexture("textures/player.png")},
	)
	game.world.player = &game.world.entities[0]

	// non-player entities
	append(
		&game.world.entities,
		Entity{"Obstacle", {250, 500, 500, 50}, rl.LoadTexture("textures/obstacle.jpg")},
	)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		{
			using game.world

			// calculate player movement
			move := rl.Vector2{0, 0}
			if rl.IsKeyDown(.W) do move.y = -1
			if rl.IsKeyDown(.S) do move.y = 1
			if rl.IsKeyDown(.A) do move.x = -1
			if rl.IsKeyDown(.D) do move.x = 1
			move = la.normalize0(move) * rl.GetFrameTime() * PLAYER_SPEED

			// x-axis
			player.rect.x += move.x
			for &entity in entities {
				if player != &entity && rl.CheckCollisionRecs(player.rect, entity.rect) {
					player.rect.x -= move.x
					break
				}
			}

			// y-axis
			player.rect.y += move.y
			for &entity in entities {
				if player != &entity && rl.CheckCollisionRecs(player.rect, entity.rect) {
					player.rect.y -= move.y
					break
				}
			}

			// point camera to player
			game.world.camera.target = {
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
		{
			using game.world
			rl.BeginMode2D(camera)

			// entities
			for &entity in entities {
				rl.DrawTexturePro(
					entity.tex,
					{width = f32(entity.tex.width), height = f32(entity.tex.height)},
					entity.rect,
					{},
					0,
					rl.WHITE,
				)
			}
			rl.EndMode2D()
		}

		// UI
		{
			using game.ui

			// entity list
			entity_list_sb := strings.builder_make(context.temp_allocator)
			for &entity, i in game.world.entities {
				if i != 0 {
					strings.write_byte(&entity_list_sb, ';')
				}
				strings.write_string(&entity_list_sb, entity.name)
			}
			rl.GuiListView(
				{0, 0, 74, 200},
				strings.to_cstring(&entity_list_sb),
				&entity_list.scroll_index,
				&entity_list.active,
			)
			if entity_list.active >= 0 {
				entity := game.world.entities[entity_list.active]
				using entity.rect

				rl.BeginMode2D(game.world.camera)
				rl.DrawBoundingBox({{x, y, 0}, {x + width, y + height, 0}}, rl.RED)
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

	delete(game.world.entities)
	rl.CloseWindow()

	//----------------------------------------------------------------------------------
}
