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

    submit_texture := raylib.LoadTexture("./media/submit.png")
    defer raylib.UnloadTexture(submit_texture)

    rolypoly_image := raylib.LoadImage("./media/rolypoly.png")
    defer raylib.UnloadImage(rolypoly_image)

    sound := raylib.LoadSound("./media/xylo.wav")
    defer raylib.UnloadSound(sound)

    rolypoly_texture := raylib.LoadTextureFromImage(rolypoly_image)
    defer raylib.UnloadTexture(rolypoly_texture)

    cursor_image := raylib.LoadImage("./media/squid.png")
    defer raylib.UnloadImage(cursor_image)

    cursor_texture := raylib.LoadTextureFromImage(cursor_image)
    defer raylib.UnloadTexture(cursor_texture)

    canvas_image := raylib.GenImageColor(16, 16, raylib.SKYBLUE)
    defer raylib.UnloadImage(canvas_image)

    canvas_texture := raylib.LoadTextureFromImage(canvas_image)
    defer raylib.UnloadTexture(canvas_texture)

    friend_texture : Maybe(raylib.Texture)
    defer  {
        if friend_texture != nil {
            raylib.UnloadTexture(friend_texture.?)
        }
    }



    // Main loop.

    Mode :: enum {
        Main,
        Drawing,
    }

    mode                  := Mode.Main
    rolypoly_animating    := false
    rolypoly_animation_t  := cast(f32) 0.0
    time_since_last_click := cast(f32) 0.0
    friend_animation_t    := cast(f32) 0.0
    friend_x              := cast(f32) 100.0

    for !raylib.WindowShouldClose() {



        // Process inputs.

        mouse_position := raylib.GetMousePosition()

        is_hovering := false

        if raylib.IsKeyPressed(.SPACE) {
            if mode == .Main {
                mode = .Drawing
            } else {
                mode = .Main
            }
        }

        if mode == .Drawing {
            raylib.HideCursor()
        } else {
            raylib.ShowCursor()
        }

        switch mode {

            case .Main: {

                is_hovering = raylib.CheckCollisionPointRec(
                    mouse_position,
                    raylib.Rectangle{
                        cast(f32) SCREEN_WIDTH  / 2.0 - cast(f32) rolypoly_texture.width  / 2.0,
                        cast(f32) SCREEN_HEIGHT / 2.0 - cast(f32) rolypoly_texture.height / 2.0,
                        cast(f32) rolypoly_texture.width,
                        cast(f32) rolypoly_texture.height,
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

            }

            case .Drawing: {
            }

        }



        // Render.

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.DARKGRAY)



            switch mode {

                case .Main: {

                    k := 1 + 0.05 * (1 - math.sin(math.PI / 2 * rolypoly_animation_t))

                    dest := raylib.Rectangle {
                        0.0,
                        0.0,
                        cast(f32) rolypoly_texture.width  / (k if rolypoly_animating else 1.0),
                        cast(f32) rolypoly_texture.height * (k if rolypoly_animating else 1.0),
                    }

                    dest.x = cast(f32) SCREEN_WIDTH  / 2.0 - dest.width  / 2.0
                    dest.y = cast(f32) SCREEN_HEIGHT / 2.0 - dest.height / 2.0

                    raylib.DrawTexturePro(
                        texture  = rolypoly_texture,
                        source   = { 0.0, 0.0, cast(f32) rolypoly_texture.width, cast(f32) rolypoly_texture.height },
                        dest     = dest,
                        origin   = { 0.0, 0.0 },
                        rotation = 0.0,
                        tint     = is_hovering ? raylib.YELLOW : raylib.WHITE,
                    )



                    // TODO.

                    friend_animation_t += raylib.GetFrameTime()
                    friend_animation_t  = math.mod_f32(friend_animation_t, cast(f32) 1.0)

                    friend_x += raylib.GetFrameTime() * 10.0

                    friend_dest := raylib.Rectangle {
                        friend_x,
                        200.0,
                        100.0,
                        100.0,
                    }

                    friend_dest.width  /= 1 + 0.085 * math.sin(math.PI * friend_animation_t)
                    friend_dest.height *= 1 + 0.125 * math.sin(math.PI * friend_animation_t)
                    friend_dest.x       = friend_dest.x - friend_dest.width / 2.0
                    friend_dest.y       = friend_dest.y - (friend_dest.height * 0.33 * math.sin(math.PI * friend_animation_t))

                    if friend_texture != nil {

                        raylib.DrawTexturePro(
                            texture = friend_texture.?,
                            source  = {
                                0.0,
                                0.0,
                                cast(f32) friend_texture.?.width,
                                cast(f32) friend_texture.?.height,
                            },
                            dest     = friend_dest,
                            origin   = { 0.0, 0.0 },
                            rotation = 0.0,
                            tint     = raylib.WHITE,
                        )

                    }

                }

                case .Drawing: {



                    // TODO.

                    canvas_center := raylib.Vector2 {
                        cast(f32) SCREEN_WIDTH  / 2.0,
                        cast(f32) SCREEN_HEIGHT / 2.0,
                    }

                    canvas_dimensions := raylib.Vector2 {
                        400.0,
                        400.0,
                    }

                    canvas_cell_dimensions := raylib.Vector2 {
                        canvas_dimensions.x / cast(f32) canvas_image.width,
                        canvas_dimensions.y / cast(f32) canvas_image.height,
                    }

                    canvas_dest := raylib.Rectangle {
                        canvas_center.x - canvas_dimensions.x / 2.0,
                        canvas_center.y - canvas_dimensions.y / 2.0,
                        canvas_dimensions.x,
                        canvas_dimensions.y,
                    }

                    hovered_cell_coordinate_x := cast(int) math.floor((mouse_position.x - canvas_dest.x) / canvas_cell_dimensions.x)
                    hovered_cell_coordinate_y := cast(int) math.floor((mouse_position.y - canvas_dest.y) / canvas_cell_dimensions.y)
                    hovered_cell_within       := (
                        0 <= hovered_cell_coordinate_x && hovered_cell_coordinate_x < cast(int) canvas_image.width &&
                        0 <= hovered_cell_coordinate_y && hovered_cell_coordinate_y < cast(int) canvas_image.height
                    )



                    // TODO.

                    if raylib.IsMouseButtonDown(.LEFT) && hovered_cell_within {

                        raylib.ImageDrawPixel(
                            &canvas_image,
                            cast(i32) hovered_cell_coordinate_x,
                            cast(i32) hovered_cell_coordinate_y,
                            raylib.RED
                        )

                        raylib.UpdateTexture(canvas_texture, canvas_image.data)

                    }



                    // TODO.

                    raylib.DrawTexturePro(
                        texture = canvas_texture,
                        source  = {
                            0.0,
                            0.0,
                            cast(f32) canvas_texture.width,
                            cast(f32) canvas_texture.height,
                        },
                        dest     = canvas_dest,
                        origin   = { 0.0, 0.0 },
                        rotation = 0.0,
                        tint     = raylib.WHITE,
                    )



                    // TODO.

                    if hovered_cell_within {

                        raylib.DrawRectangleLines(
                            posX   = cast(i32) (canvas_dest.x + cast(f32) hovered_cell_coordinate_x * canvas_cell_dimensions.x),
                            posY   = cast(i32) (canvas_dest.y + cast(f32) hovered_cell_coordinate_y * canvas_cell_dimensions.y),
                            width  = cast(i32) canvas_cell_dimensions.x,
                            height = cast(i32) canvas_cell_dimensions.y,
                            color  = raylib.BLACK,
                        )

                    }



                    // TODO.

                    submit_dest := raylib.Rectangle {
                        650.0,
                        200.0,
                        100.0,
                        50.0,
                    }

                    submit_hovering := raylib.CheckCollisionPointRec(mouse_position, submit_dest)

                    {

                        raylib.DrawTexturePro(
                            texture  = submit_texture,
                            source   = { 0.0, 0.0, cast(f32) submit_texture.width, cast(f32) submit_texture.height },
                            dest     = submit_dest,
                            origin   = { 0.0, 0.0 },
                            rotation = 0.0,
                            tint     = raylib.GREEN if submit_hovering else raylib.WHITE,
                        )

                    }

                    if submit_hovering && raylib.IsMouseButtonPressed(.LEFT) {

                        if friend_texture != nil {
                            raylib.UnloadTexture(friend_texture.?)
                        }

                        friend_texture = raylib.LoadTextureFromImage(canvas_image)

                        raylib.ImageClearBackground(&canvas_image, raylib.SKYBLUE)
                        raylib.UpdateTexture(canvas_texture, canvas_image.data)

                        mode = .Main

                    }




                    // TODO.

                    {

                        dest := raylib.Rectangle {
                            mouse_position.x + 4.0,
                            mouse_position.y + 10.0,
                            cast(f32) cursor_texture.width,
                            cast(f32) cursor_texture.height
                        }

                        raylib.DrawTexturePro(
                            texture  = cursor_texture,
                            source   = { 0.0, 0.0, cast(f32) cursor_texture.width, cast(f32) cursor_texture.height },
                            dest     = dest,
                            origin   = { dest.width / 2.0, dest.height / 2.0 },
                            rotation = 150.0 if raylib.IsMouseButtonDown(.LEFT) else 160.0,
                            tint     = raylib.WHITE,
                        )

                    }

                }

            }

        }

    }

}
