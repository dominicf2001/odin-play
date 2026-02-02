package game

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

TILE_SIZE :: 50.0
TILES_NUM :: 40
TILES_ORIGIN: [2]f32 : {WINDOW_WIDTH / 4, WINDOW_WIDTH / 4}

ENTITIES_MAX :: 1024

PLAYER_SPEED :: 500.0

World :: struct {
	camera:   rl.Camera2D,
	player_h: Entity_Handle,
	entities: hm.Static_Handle_Map(ENTITIES_MAX, Entity, Entity_Handle),
	tiles:    [TILES_NUM / 2][TILES_NUM / 2]Tile,
}

Tile :: struct {
	color: rl.Color, // TODO: switch to tex
}

Entity :: struct {
	name:     string,
	rect:     rl.Rectangle,
	tex_path: cstring,
	handle:   Entity_Handle,
}

Entity_Handle :: distinct hm.Handle32

entity_draw :: proc(e: ^Entity) {
	tex := tex_load(e.tex_path)
	rl.DrawTexturePro(
		tex,
		{width = f32(tex.width), height = f32(tex.height)},
		e.rect,
		{},
		0,
		rl.WHITE,
	)
}

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

	world := World {
		camera = rl.Camera2D{offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}, zoom = 1.0},
	}

	// player entity
	world.player_h = hm.add(
		&world.entities,
		Entity{"Player", {TILES_ORIGIN.x, TILES_ORIGIN.y, 50, 50}, "tex/player.png", {}},
	)

	//----------------------------------------------------------------------------------

	for !rl.WindowShouldClose() {
		// UPDATE
		//----------------------------------------------------------------------------------

		if player, ok := hm.get(&world.entities, world.player_h); ok {
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
		rl.ClearBackground(rl.BLACK)

		// World
		{
			rl.BeginMode2D(world.camera)
			// tiles

			for tile_row, row_num in world.tiles {
				for tile, col_num in tile_row {
					tile_rect := rl.Rectangle {
						TILES_ORIGIN.x + f32(row_num * TILE_SIZE),
						TILES_ORIGIN.y + f32(col_num * TILE_SIZE),
						TILE_SIZE,
						TILE_SIZE,
					}
					rl.DrawRectangleRec(tile_rect, rl.BLUE)
					rl.DrawRectangleLinesEx(tile_rect, 1, rl.WHITE)
				}
			}

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
