package main

import "core:fmt"
import "core:math"
import "vendor:raylib"



SCREEN_WIDTH  : i32 : 800
SCREEN_HEIGHT : i32 : 450

main :: proc() {



    // Set up Raylib.

    raylib.SetTraceLogLevel(.WARNING)
    raylib.SetTargetFPS(60)

    raylib.InitWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "scribbles"
    )
    defer raylib.CloseWindow()

    raylib.InitAudioDevice()
    defer raylib.CloseAudioDevice()



    // TODO.

    image := raylib.LoadImage("./media/rolypoly.png")
    defer raylib.UnloadImage(image)

    sound := raylib.LoadSound("./media/xylo.wav")
    defer raylib.UnloadSound(sound)

    texture := raylib.LoadTextureFromImage(image)
    defer raylib.UnloadTexture(texture)



    // Main loop.

    rolypoly_animating   := false
    rolypoly_animation_t := cast(f32) 0.0
    time_since_last_click  := cast(f32) 0.0

    for !raylib.WindowShouldClose() {



        // Process inputs.

        mouse_position := raylib.GetMousePosition()

        is_hovering := raylib.CheckCollisionPointRec(
            mouse_position,
            raylib.Rectangle{
                cast(f32) SCREEN_WIDTH  / 2.0 - cast(f32) texture.width  / 2.0,
                cast(f32) SCREEN_HEIGHT / 2.0 - cast(f32) texture.height / 2.0,
                cast(f32) texture.width,
                cast(f32) texture.height,
            },
        )

        if is_hovering && raylib.IsMouseButtonPressed(.LEFT) {

            rolypoly_animating   = true
            rolypoly_animation_t = 0.0

            raylib.PlaySound(sound)

            raylib.SetSoundVolume(
                sound,
                min(max(cast(f32) raylib.GetTime() - time_since_last_click, 0.0), 1.0)
            )

            time_since_last_click = cast(f32) raylib.GetTime()

        }


        if rolypoly_animating {

            rolypoly_animation_t += raylib.GetFrameTime() / 0.25

            if rolypoly_animation_t > 1.0 {
                rolypoly_animation_t = 0.0
                rolypoly_animating   = false
            }

        }



        // Render.

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.DARKGRAY)



            k := 1 + 0.05 * (1 - math.sin(math.PI / 2 * rolypoly_animation_t))

            dest := raylib.Rectangle {
                0.0,
                0.0,
                cast(f32) texture.width  / (k if rolypoly_animating else 1.0),
                cast(f32) texture.height * (k if rolypoly_animating else 1.0),
            }

            dest.x = cast(f32) SCREEN_WIDTH  / 2.0 - dest.width  / 2.0
            dest.y = cast(f32) SCREEN_HEIGHT / 2.0 - dest.height / 2.0

            raylib.DrawTexturePro(
                texture  = texture,
                source   = { 0.0, 0.0, cast(f32) texture.width, cast(f32) texture.height },
                dest     = dest,
                origin   = { 0.0, 0.0 },
                rotation = 0.0,
                tint     = is_hovering ? raylib.YELLOW : raylib.WHITE,
            )

        }

    }

}
