package main

import "core:fmt"
import la "core:math/linalg"
import "core:strings"
import rl "vendor:raylib"

PLAYER_SPEED :: 500.0

Game :: struct {
	world: struct {
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
	rl.InitWindow(1280, 720, "Hellope!")


	// INIT GAME
	// -----------------------
	game := Game {
		world = {entities = [dynamic]Entity{}},
	}

	// player
	append(
		&game.world.entities,
		Entity{"Player", {0, 0, 50, 50}, rl.LoadTexture("textures/player.png")},
	)
	game.world.player = &game.world.entities[0]

	// entities
	append(
		&game.world.entities,
		Entity{"Obstacle", {250, 500, 500, 50}, rl.LoadTexture("textures/obstacle.jpg")},
	)

	// -----------------------

	for !rl.WindowShouldClose() {
		// HANDLE PLAYER INPUT
		// -----------------------
		{
			using game.world

			move := rl.Vector2{0, 0}
			if rl.IsKeyDown(.W) do move.y = -1
			if rl.IsKeyDown(.S) do move.y = 1
			if rl.IsKeyDown(.A) do move.x = -1
			if rl.IsKeyDown(.D) do move.x = 1
			move = la.normalize0(move) * rl.GetFrameTime() * PLAYER_SPEED

			player.rect.x += move.x
			for &entity in entities {
				if player != &entity && rl.CheckCollisionRecs(player.rect, entity.rect) {
					player.rect.x -= move.x
					break
				}
			}

			player.rect.y += move.y
			for &entity in entities {
				if player != &entity && rl.CheckCollisionRecs(player.rect, entity.rect) {
					player.rect.y -= move.y
					break
				}
			}
		}
		// -----------------------

		rl.BeginDrawing()

		// DRAW GAME WORLD
		// -----------------------
		{
			using game.world

			rl.ClearBackground(rl.BLUE)

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
		}
		// -----------------------

		// DRAW UI
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
				rl.DrawBoundingBox({{x, y, 0}, {x + width, y + height, 0}}, rl.RED)
			}
		}
		// -----------------------

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	delete(game.world.entities)
	rl.CloseWindow()
}
