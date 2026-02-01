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

Game :: struct {
	world: struct {
		camera:        rl.Camera2D,
		player_handle: EntityHandle,
		entities:      hm.Static_Handle_Map(MAX_ENTITIES, Entity, EntityHandle),
	},
	ui:    struct {
		entity_list: struct {
			active:       i32,
			scroll_index: i32,
			handles:      sa.Small_Array(MAX_ENTITIES, EntityHandle),
		},
	},
}

EntityHandle :: distinct hm.Handle32

Entity :: struct {
	name:   string,
	rect:   rl.Rectangle,
	tex:    rl.Texture2D,
	handle: EntityHandle,
}

main :: proc() {
	// INITIALIZE
	//----------------------------------------------------------------------------------

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin play!")

	game := Game {
		world = {
			camera = rl.Camera2D{offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, zoom = 1.0},
			entities = {},
		},
	}

	// player entity
	game.world.player_handle = hm.add(
		&game.world.entities,
		Entity{"Player", {0, 0, 50, 50}, rl.LoadTexture("textures/player.png"), {}},
	)

	// non-player entities
	obstacle_handle := hm.add(
		&game.world.entities,
		Entity{"Obstacle", {250, 500, 500, 50}, rl.LoadTexture("textures/obstacle.jpg"), {}},
	)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&game.world.entities, game.world.player_handle); ok {
			// calculate player movement
			move := rl.Vector2{0, 0}
			if rl.IsKeyDown(.W) do move.y = -1
			if rl.IsKeyDown(.S) do move.y = 1
			if rl.IsKeyDown(.A) do move.x = -1
			if rl.IsKeyDown(.D) do move.x = 1
			move = rl.Vector2Normalize(move) * rl.GetFrameTime() * PLAYER_SPEED

			// x-axis
			player.rect.x += move.x

			it := hm.iterator_make(&game.world.entities)
			for entity in hm.iterate(&it) {
				if player != entity && rl.CheckCollisionRecs(player.rect, entity.rect) {
					player.rect.x -= move.x
					break
				}
			}

			// y-axis
			player.rect.y += move.y
			it = hm.iterator_make(&game.world.entities)
			for entity in hm.iterate(&it) {
				if player != entity && rl.CheckCollisionRecs(player.rect, entity.rect) {
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
			rl.BeginMode2D(game.world.camera)

			// entities
			it := hm.iterator_make(&game.world.entities)
			for entity in hm.iterate(&it) {
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

		// draw entity list
		sa.clear(&game.ui.entity_list.handles)
		entity_list_sb := strings.builder_make(context.temp_allocator)

		it := hm.iterator_make(&game.world.entities)
		for entity in hm.iterate(&it) {
			sa.append(&game.ui.entity_list.handles, entity.handle)
			strings.write_string(&entity_list_sb, entity.name)
			strings.write_byte(&entity_list_sb, ';')
		}
		rl.GuiListView(
			{0, 0, 74, 200},
			strings.to_cstring(&entity_list_sb),
			&game.ui.entity_list.scroll_index,
			&game.ui.entity_list.active,
		)
		if game.ui.entity_list.active >= 0 {
			entity_handle := sa.get(game.ui.entity_list.handles, int(game.ui.entity_list.active))
			if entity, ok := hm.get(&game.world.entities, entity_handle); ok {
				rl.BeginMode2D(game.world.camera)
				rl.DrawBoundingBox(
					{
						{entity.rect.x, entity.rect.y, 0},
						{entity.rect.x + entity.rect.width, entity.rect.y + entity.rect.height, 0},
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
