package main

import "vendor:raylib"



SCREEN_WIDTH  : i32 : 800
SCREEN_HEIGHT : i32 : 450

main :: proc() {



    // Set up Raylib.

    raylib.InitWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "scribbles"
    )
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(60)



    // TODO.

    image := raylib.LoadImage("./media/pikmin.png")
    defer raylib.UnloadImage(image)

    texture := raylib.LoadTextureFromImage(image)
    defer raylib.UnloadTexture(texture)

    player_pos   := raylib.Vector2{400, 225}
    player_size  := raylib.Vector2{50, 50}
    player_speed : f32 = 5.0

    texture_position  := raylib.Vector2{100.0, 100.0}
    texture_size := raylib.Vector2{f32(texture.width), f32(texture.height)}



    // Main loop.

    for !raylib.WindowShouldClose() {



        // Process inputs.

        if raylib.IsKeyDown(.LEFT)  || raylib.IsKeyDown(.A) { player_pos.x -= player_speed }
        if raylib.IsKeyDown(.RIGHT) || raylib.IsKeyDown(.D) { player_pos.x += player_speed }
        if raylib.IsKeyDown(.UP)    || raylib.IsKeyDown(.W) { player_pos.y -= player_speed }
        if raylib.IsKeyDown(.DOWN)  || raylib.IsKeyDown(.S) { player_pos.y += player_speed }

        mouse_position := raylib.GetMousePosition()

        is_hovering := raylib.CheckCollisionPointRec(
            mouse_position,
            raylib.Rectangle{
                texture_position.x,
                texture_position.y,
                texture_size.x,
                texture_size.y,
            },
        )



        // Render.

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.DARKGRAY)

            raylib.DrawText("Use WASD or Arrow Keys to move the player", 10, 10, 20, raylib.RAYWHITE)

            raylib.DrawRectangleV(player_pos, player_size, raylib.MAROON)

            raylib.DrawTextureV(
                texture,
                texture_position,
                is_hovering ? raylib.YELLOW : raylib.WHITE,
            )

            mouse_text := raylib.TextFormat(
                "Mouse: (%.0f, %.0f) - Hovering: %s",
                mouse_position.x,
                mouse_position.y,
                is_hovering ? "YES" : "NO",
            )
            raylib.DrawText(mouse_text, 10, 40, 20, raylib.RAYWHITE)

        }

    }

}
