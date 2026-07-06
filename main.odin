package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/ease"
import "core:reflect"
import "vendor:raylib"



main :: proc() {



    // Set up Raylib.

    raylib.SetTraceLogLevel(.WARNING)
    raylib.SetTargetFPS(60)
    raylib.SetConfigFlags({ .MSAA_4X_HINT })

    raylib.InitWindow(
        1200,
        675,
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

    xylo_sound := raylib.LoadSound("./media/xylo.wav")
    defer raylib.UnloadSound(xylo_sound)

    padlock_sound := raylib.LoadSound("./media/padlock.wav")
    defer raylib.UnloadSound(padlock_sound)

    padlock_locked_sound := raylib.LoadSound("./media/padlock_locked.wav")
    defer raylib.UnloadSound(padlock_locked_sound)

    padlock_unlocked_sound := raylib.LoadSound("./media/padlock_unlocked.wav")
    defer raylib.UnloadSound(padlock_unlocked_sound)

    easel_open_sound := raylib.LoadSound("./media/easel_open.wav")
    defer raylib.UnloadSound(easel_open_sound)

    easel_close_sound := raylib.LoadSound("./media/easel_close.wav")
    defer raylib.UnloadSound(easel_close_sound)

    rolypoly_texture := raylib.LoadTextureFromImage(rolypoly_image)
    defer raylib.UnloadTexture(rolypoly_texture)

    cursor_image := raylib.LoadImage("./media/squid.png")
    defer raylib.UnloadImage(cursor_image)

    cursor_texture := raylib.LoadTextureFromImage(cursor_image)
    defer raylib.UnloadTexture(cursor_texture)

    friend_texture : Maybe(raylib.Texture)
    defer  {
        if friend_texture != nil {
            raylib.UnloadTexture(friend_texture.?)
        }
    }

    easel_texture := raylib.LoadTexture("./media/easel.png")
    defer raylib.UnloadTexture(easel_texture)

    padlock_texture := raylib.LoadTexture("./media/padlock.png")
    defer raylib.UnloadTexture(padlock_texture)

    font := raylib.LoadFontEx("./media/Sniglet.ttf", 96, nil, 0)
    defer raylib.UnloadFont(font)



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Animation.
    //

    Animation :: struct {
        duration : f32,
        value    : f32,
        running  : bool,
        control  : Animation_Control,
    }

    Animation_Control :: enum {
        Restart,
        Decrease,
        Increase,
    }

    update_animation :: proc(animation : ^Animation) {

        if animation.running {

            switch animation.control {

                case .Restart: {

                    animation.value += raylib.GetFrameTime() / animation.duration

                    if animation.value > 1 {
                        animation.value   = 0
                        animation.running = false
                    }

                }

                case .Decrease: {
                    animation.value -= raylib.GetFrameTime() / animation.duration
                    animation.value  = clamp(animation.value, 0, 1)
                }

                case .Increase: {
                    animation.value += raylib.GetFrameTime() / animation.duration
                    animation.value  = clamp(animation.value, 0, 1)
                }

                case: panic("Invalid.")

            }

        }

    }

    control_animation :: proc(animation : ^Animation, control : Animation_Control) {

        animation.control = control

        switch control {

            case .Restart: {
                animation.value   = 0
                animation.running = true
            }

            case .Decrease: {
                animation.running = true
            }

            case .Increase: {
                animation.running = true
            }

            case: panic("Invalid.")

        }

    }

    ease_animation :: proc(
        start     : f32,
        end       : f32,
        animation : Animation,
        easing    : ease.Ease = .Linear,
    ) -> f32 {
        return math.lerp(
            start,
            end,
            ease.ease(easing, animation.value)
        )
    }



    ////////////////////////////////////////////////////////////////////////////////





    // Main loop.

    Mode :: enum {
        Normal,
        Easel,
    }

    mode                  := Mode.Easel
    time_since_last_click := cast(f32) 0.0
    friend_animation_t    := cast(f32) 0.0
    friend_x              := cast(f32) 100.0
    pets                  := 0

    rolypoly_animation := Animation { duration = 0.25 }

    easel_unlocked                := true // TODO.
    easel_cost                    := 10
    easel_default_color           := raylib.Color { 234, 240, 243, 255 }
    easel_lockpad_hover_animation := Animation { duration = 0.20 }
    easel_lockpad_click_animation := Animation { duration = 0.10 }

    easel_canvas_image := raylib.GenImageColor(8, 8, easel_default_color)
    defer raylib.UnloadImage(easel_canvas_image)

    easel_canvas_texture := raylib.LoadTextureFromImage(easel_canvas_image)
    defer raylib.UnloadTexture(easel_canvas_texture)

    for !raylib.WindowShouldClose() {



        // Process inputs.

        mouse_position := raylib.GetMousePosition()

        is_hovering := false

        if raylib.IsKeyPressed(.SPACE) {
            if mode == .Normal {
                mode = .Easel
            } else {
                mode = .Normal
            }
        }

        if mode == .Easel {
            raylib.HideCursor()
        } else {
            raylib.ShowCursor()
        }

        k := 1 + 0.05 * (1 - math.sin(math.PI / 2 * rolypoly_animation.value))

        rolypoly_dest := raylib.Rectangle {
            0.0,
            0.0,
            cast(f32) rolypoly_texture.width  / (k if rolypoly_animation.running else 1.0),
            cast(f32) rolypoly_texture.height * (k if rolypoly_animation.running else 1.0),
        }

        rolypoly_dest.x = cast(f32) raylib.GetScreenWidth()  / 2.0 - rolypoly_dest.width  / 2.0
        rolypoly_dest.y = cast(f32) raylib.GetScreenHeight() / 2.0 - rolypoly_dest.height / 2.0


        switch mode {

            case .Normal: {

                is_hovering = raylib.CheckCollisionPointRec(
                    mouse_position,
                    rolypoly_dest,
                )

                if is_hovering && raylib.IsMouseButtonPressed(.LEFT) {

                    pets += 1

                    control_animation(&rolypoly_animation, .Restart)

                    raylib.PlaySound(xylo_sound)

                    raylib.SetSoundVolume(
                        xylo_sound,
                        min(max(cast(f32) raylib.GetTime() - time_since_last_click, 0.0), 1.0)
                    )

                    time_since_last_click = cast(f32) raylib.GetTime()

                }


                update_animation(&rolypoly_animation)

            }

            case .Easel: {
            }

        }



        ////////////////////////////////////////
        //
        // Update easel.
        //

        easel_dest := raylib.Rectangle {
            f32(raylib.GetScreenWidth())  * 0.8,
            f32(raylib.GetScreenHeight()) * 0.6,
            100,
            200,
        }

        easel_origin := raylib.Vector2 {
            easel_dest.width / 2,
            easel_dest.height,
        }

        hovering_easel := raylib.CheckCollisionPointRec(
            mouse_position,
            {
                easel_dest.x - easel_origin.x,
                easel_dest.y - easel_origin.y,
                easel_dest.width,
                easel_dest.height,
            }
        )



        if easel_unlocked {

            if hovering_easel && raylib.IsMouseButtonPressed(.LEFT) {

                mode = .Easel
                raylib.PlaySound(easel_open_sound)

            }

        } else {



            // Hovering lockpad.

            if hovering_easel {
                control_animation(&easel_lockpad_hover_animation, .Increase)
            } else {
                control_animation(&easel_lockpad_hover_animation, .Decrease)
            }

            old_easel_lockpad_hover_animation_value := easel_lockpad_hover_animation.value

            update_animation(&easel_lockpad_hover_animation)

            if (
                old_easel_lockpad_hover_animation_value <  0.5 &&
                easel_lockpad_hover_animation.value     >= 0.5 &&
                !raylib.IsSoundPlaying(padlock_sound)
            ) {
                raylib.PlaySound(padlock_sound)
            }



            // Clicking lockpad.

            if easel_lockpad_hover_animation.value == 1 && raylib.IsMouseButtonPressed(.LEFT) {

                if pets < easel_cost {

                    control_animation(&easel_lockpad_click_animation, .Restart)
                    raylib.PlaySound(padlock_locked_sound)

                } else {

                    pets           -= easel_cost
                    easel_unlocked  = true
                    raylib.PlaySound(padlock_unlocked_sound)

                }

            }

            update_animation(&easel_lockpad_click_animation)

        }



        ////////////////////////////////////////
        //
        // Update easel canvas.
        //

        easel_canvas_dest := raylib.Rectangle {
            cast(f32) raylib.GetScreenWidth()  / 2.0,
            cast(f32) raylib.GetScreenHeight() / 2.0,
            400.0,
            400.0,
        }

        easel_canvas_origin := raylib.Vector2 {
            easel_canvas_dest.width  / 2,
            easel_canvas_dest.height / 2,
        }

        easel_canvas_cell_dimensions := raylib.Vector2 {
            easel_canvas_dest.width  / cast(f32) easel_canvas_image.width,
            easel_canvas_dest.height / cast(f32) easel_canvas_image.height,
        }

        hovered_easel_canvas_cell_coordinate_x := cast(int) math.floor((mouse_position.x - (easel_canvas_dest.x - easel_canvas_origin.x)) / easel_canvas_cell_dimensions.x)
        hovered_easel_canvas_cell_coordinate_y := cast(int) math.floor((mouse_position.y - (easel_canvas_dest.y - easel_canvas_origin.y)) / easel_canvas_cell_dimensions.y)
        hovered_easel_canvas_cell_is_within    := (
            0 <= hovered_easel_canvas_cell_coordinate_x && hovered_easel_canvas_cell_coordinate_x < cast(int) easel_canvas_image.width &&
            0 <= hovered_easel_canvas_cell_coordinate_y && hovered_easel_canvas_cell_coordinate_y < cast(int) easel_canvas_image.height
        )

        submit_button_dest := raylib.Rectangle {
            f32(raylib.GetScreenWidth() ) * 0.5,
            f32(raylib.GetScreenHeight()) * 0.85,
            100.0,
            50.0,
        }

        submit_button_origin := raylib.Vector2 {
            submit_button_dest.width  / 2,
            submit_button_dest.height / 2,
        }

        hovering_submit_button : bool

        if mode == .Easel {

            hovering_submit_button = raylib.CheckCollisionPointRec(
                mouse_position,
                {
                    submit_button_dest.x - submit_button_origin.x,
                    submit_button_dest.y - submit_button_origin.y,
                    submit_button_dest.width,
                    submit_button_dest.height,
                }
            )

            if raylib.IsMouseButtonPressed(.LEFT) && hovered_easel_canvas_cell_is_within {

                raylib.ImageDrawPixel(
                    &easel_canvas_image,
                    cast(i32) hovered_easel_canvas_cell_coordinate_x,
                    cast(i32) hovered_easel_canvas_cell_coordinate_y,
                    { 49, 42, 22, 255 }
                )

            }

            if hovering_submit_button && raylib.IsMouseButtonPressed(.LEFT) {

                if friend_texture != nil {
                    raylib.UnloadTexture(friend_texture.?)
                }

                friend_texture = raylib.LoadTextureFromImage(easel_canvas_image)

                raylib.ImageClearBackground(&easel_canvas_image, easel_default_color)

                mode = .Normal
                raylib.PlaySound(easel_close_sound)

            }

            raylib.UpdateTexture(easel_canvas_texture, easel_canvas_image.data)

        }



        ////////////////////////////////////////
        //
        // Render.
        //

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.BROWN if mode == .Easel else raylib.DARKGRAY)



            ////////////////////////////////////////
            //
            // TODO.
            //

            text := fmt.ctprintf("Pets: {}", pets)
            raylib.DrawTextEx(
                font     = font,
                text     = text,
                position = { 10, 10 },
                fontSize = 40,
                spacing  = 0,
                tint     = raylib.WHITE,
            )


            switch mode {

                case .Normal: {

                    raylib.DrawTexturePro(
                        texture  = rolypoly_texture,
                        source   = { 0.0, 0.0, cast(f32) rolypoly_texture.width, cast(f32) rolypoly_texture.height },
                        dest     = rolypoly_dest,
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

                case .Easel: {








                }

            }



            ////////////////////////////////////////
            //
            // Render easel.
            //

            if mode == .Normal {

                raylib.DrawTexturePro(
                    texture  = easel_texture,
                    source   = { 0, 0, cast(f32) easel_texture.width, cast(f32) easel_texture.height },
                    dest     = easel_dest,
                    origin   = easel_origin,
                    rotation = 0,
                    tint     = raylib.WHITE if easel_unlocked else raylib.GRAY,
                )

                if !easel_unlocked {

                    easel_padlock_dest := raylib.Rectangle {
                        easel_dest.x,
                        easel_dest.y - easel_dest.height / 2,
                        ease_animation(75, 100, easel_lockpad_hover_animation, .Bounce_Out),
                        ease_animation(75, 100, easel_lockpad_hover_animation, .Bounce_Out),
                    }

                    easel_padlock_rotation := math.sin(ease_animation(0, 6, easel_lockpad_hover_animation, .Cubic_Out)) * 10
                    easel_padlock_rotation += math.sin(ease_animation(0, 6, easel_lockpad_click_animation, .Cubic_Out)) * 10

                    raylib.DrawTexturePro(
                        texture  = padlock_texture,
                        source   = { 0, 0, cast(f32) padlock_texture.width, cast(f32) padlock_texture.height },
                        dest     = easel_padlock_dest,
                        origin   = { f32(easel_padlock_dest.width) / 2, f32(easel_padlock_dest.height) / 2 },
                        rotation = easel_padlock_rotation,
                        tint     = raylib.WHITE,
                    )

                    if easel_lockpad_hover_animation.value == 1 {

                        x       := f32(rolypoly_dest.x + rolypoly_dest.width  * 0.75)
                        y       := f32(rolypoly_dest.y + rolypoly_dest.height * 0.10)
                        message := (
                            pets < easel_cost
                                ? fmt.ctprintf("I need {} pets...", easel_cost)
                                : fmt.ctprintf("Unlock for {} pets...?", easel_cost)
                        )

                        BUBBLE_DIALOG_FONT_SIZE :: 30
                        BUBBLE_DIALOG_PADDING   :: 15
                        BUBBLE_DIALOG_ROUNDNESS :: 0.3
                        BUBBLE_DIALOG_OUTLINE   :: 4

                        measurement := raylib.MeasureTextEx(
                            font     = font,
                            text     = message,
                            fontSize = BUBBLE_DIALOG_FONT_SIZE,
                            spacing  = 0,
                        )

                        bubble_rectangle := raylib.Rectangle {
                            x      = x - BUBBLE_DIALOG_PADDING / 2,
                            y      = y - BUBBLE_DIALOG_PADDING * 3 - measurement.y,
                            width  = measurement.x + BUBBLE_DIALOG_PADDING * 2,
                            height = measurement.y + BUBBLE_DIALOG_PADDING * 2,
                        }

                        vertices := [?][2]f32 {
                            { x, bubble_rectangle.y + bubble_rectangle.height },
                            { x, y },
                            { x + (x - bubble_rectangle.x) * 2, bubble_rectangle.y + bubble_rectangle.height },
                        }

                        raylib.DrawRectangleRoundedLinesEx(
                            rec       = bubble_rectangle,
                            roundness = BUBBLE_DIALOG_ROUNDNESS,
                            segments  = 0,
                            lineThick = BUBBLE_DIALOG_OUTLINE,
                            color     = raylib.BLACK,
                        )

                        raylib.DrawTriangle(
                            v1       = vertices[0],
                            v2       = vertices[1],
                            v3       = vertices[2],
                            color    = raylib.LIGHTGRAY,
                        )

                        raylib.DrawLineEx(
                            startPos = vertices[0],
                            endPos   = vertices[1],
                            thick    = BUBBLE_DIALOG_OUTLINE,
                            color    = raylib.BLACK,
                        )

                        raylib.DrawLineEx(
                            startPos = vertices[1],
                            endPos   = vertices[2],
                            thick    = BUBBLE_DIALOG_OUTLINE,
                            color    = raylib.BLACK,
                        )

                        raylib.DrawRectangleRounded(
                            rec       = bubble_rectangle,
                            roundness = BUBBLE_DIALOG_ROUNDNESS,
                            segments  = 0,
                            color     = raylib.LIGHTGRAY,
                        )

                        raylib.DrawTextEx(
                            font     = font,
                            text     = message,
                            position = {
                                bubble_rectangle.x + BUBBLE_DIALOG_PADDING,
                                bubble_rectangle.y + BUBBLE_DIALOG_PADDING,
                            },
                            fontSize = BUBBLE_DIALOG_FONT_SIZE,
                            spacing  = 0,
                            tint     = raylib.BLACK,
                        )

                    }

                }

            }



            ////////////////////////////////////////
            //
            // Render easel canvas.
            //

            if mode == .Easel {



                // TODO.

                raylib.DrawTexturePro(
                    texture = easel_canvas_texture,
                    source  = {
                        0.0,
                        0.0,
                        cast(f32) easel_canvas_texture.width,
                        cast(f32) easel_canvas_texture.height,
                    },
                    dest     = easel_canvas_dest,
                    origin   = easel_canvas_origin,
                    rotation = 0.0,
                    tint     = raylib.WHITE,
                )



                // TODO.

                if hovered_easel_canvas_cell_is_within {

                    raylib.DrawRectangleLines(
                        posX   = cast(i32) (easel_canvas_dest.x - easel_canvas_origin.x + cast(f32) hovered_easel_canvas_cell_coordinate_x * easel_canvas_cell_dimensions.x),
                        posY   = cast(i32) (easel_canvas_dest.y - easel_canvas_origin.y + cast(f32) hovered_easel_canvas_cell_coordinate_y * easel_canvas_cell_dimensions.y),
                        width  = cast(i32) easel_canvas_cell_dimensions.x,
                        height = cast(i32) easel_canvas_cell_dimensions.y,
                        color  = raylib.BLACK,
                    )

                }



                // TODO.

                {

                    raylib.DrawTexturePro(
                        texture  = submit_texture,
                        source   = { 0.0, 0.0, cast(f32) submit_texture.width, cast(f32) submit_texture.height },
                        dest     = submit_button_dest,
                        origin   = submit_button_origin,
                        rotation = 0.0,
                        tint     = raylib.GREEN if hovering_submit_button else raylib.WHITE,
                    )

                }

            }



            ////////////////////////////////////////
            //
            // Render cursor.
            //

            if mode == .Easel {

                cursor_dest := raylib.Rectangle {
                    mouse_position.x + 4.0,
                    mouse_position.y + 10.0,
                    cast(f32) cursor_texture.width,
                    cast(f32) cursor_texture.height
                }

                raylib.DrawTexturePro(
                    texture  = cursor_texture,
                    source   = { 0.0, 0.0, cast(f32) cursor_texture.width, cast(f32) cursor_texture.height },
                    dest     = cursor_dest,
                    origin   = { cursor_dest.width / 2.0, cursor_dest.height / 2.0 },
                    rotation = 150.0 if raylib.IsMouseButtonDown(.LEFT) else 160.0,
                    tint     = raylib.WHITE,
                )

            }

        }



        free_all(context.temp_allocator)

    }

}
