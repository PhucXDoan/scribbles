package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/ease"
import "core:reflect"
import "vendor:raylib"



rgba_lerp :: proc(a : raylib.Color, b : raylib.Color, t : f32) -> raylib.Color {
    return raylib.Color {
        u8(math.lerp(f32(a.r), f32(b.r), t)),
        u8(math.lerp(f32(a.g), f32(b.g), t)),
        u8(math.lerp(f32(a.b), f32(b.b), t)),
        u8(math.lerp(f32(a.a), f32(b.a), t)),
    }
}



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

    easel_texture := raylib.LoadTexture("./media/easel.png")
    defer raylib.UnloadTexture(easel_texture)

    padlock_texture := raylib.LoadTexture("./media/padlock.png")
    defer raylib.UnloadTexture(padlock_texture)



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
    //
    // Screen Buttons.
    //

    SCREEN_BUTTON_FONT_SIZE :: 30

    Screen_Option :: enum {
        Roly,
        Draw,
        Shop,
    }

    Screen_Button :: struct {
        text            : cstring,
        text_width      : f32,
        text_height     : f32,
        center_x        : f32,
        center_y        : f32,
        base_box_width  : f32,
        base_box_height : f32,
        hover_t         : f32,
    }

    screen_buttons : [Screen_Option]Screen_Button

    for &screen_button, screen_button_i in screen_buttons {

        screen_button.text = strings.clone_to_cstring(reflect.enum_name_from_value(Screen_Option(screen_button_i)) or_else panic("Invalid."))

        measurement := raylib.MeasureTextEx(raylib.GetFontDefault(), screen_button.text, SCREEN_BUTTON_FONT_SIZE, SCREEN_BUTTON_FONT_SIZE / f32(raylib.GetFontDefault().baseSize))

        screen_button.text_width      = measurement.x
        screen_button.text_height     = measurement.y
        screen_button.center_x        = (f32(screen_button_i) + 1) * f32(raylib.GetScreenWidth()) / (f32(len(Screen_Option)) + 1)
        screen_button.center_y        = f32(raylib.GetScreenHeight()) - 35
        screen_button.base_box_width  = measurement.x * 1.5
        screen_button.base_box_height = measurement.y * 1.5

    }

    defer {
        for screen_button in screen_buttons {
            defer delete(screen_button.text)
        }
    }



    ////////////////////////////////////////////////////////////////////////////////





    // Main loop.

    Mode :: enum {
        Main,
        Drawing,
    }

    mode                  := Mode.Main
    time_since_last_click := cast(f32) 0.0
    friend_animation_t    := cast(f32) 0.0
    friend_x              := cast(f32) 100.0
    pets                  := 0

    rolypoly_animation    := Animation { duration = 0.25 }
    easel_hover_animation := Animation { duration = 0.2 }

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

            case .Main: {

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

            case .Drawing: {
            }

        }



        ////////////////////////////////////////
        //
        // Update screen buttons.
        //

        for &screen_button, screen_button_i in screen_buttons {

            hovering_screen_button := raylib.CheckCollisionPointRec(
                mouse_position,
                {
                    screen_button.center_x - screen_button.base_box_width  / 2,
                    screen_button.center_y - screen_button.base_box_height / 2,
                    screen_button.base_box_width,
                    screen_button.base_box_height,
                }
            )

            if hovering_screen_button {
                screen_button.hover_t += raylib.GetFrameTime() / 0.1
            } else {
                screen_button.hover_t -= raylib.GetFrameTime() / 0.1
            }

            screen_button.hover_t = clamp(screen_button.hover_t, 0, 1)

            if hovering_screen_button && raylib.IsMouseButtonPressed(.LEFT) {

                screen_button.hover_t = 0

                switch screen_button_i {

                    case .Roly: {
                        mode = .Main
                    }

                    case .Draw: {
                        mode = .Drawing
                    }

                    case .Shop: {
                        fmt.printf("TODO\n")
                    }

                    case: panic("Invalid")

                }

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

        if hovering_easel {
            control_animation(&easel_hover_animation, .Increase)

        } else {
            control_animation(&easel_hover_animation, .Decrease)
        }

        old_easel_hover_animation_value := easel_hover_animation.value

        update_animation(&easel_hover_animation)

        if (
            old_easel_hover_animation_value <  0.5 &&
            easel_hover_animation.value     >= 0.5 &&
            !raylib.IsSoundPlaying(padlock_sound)
        ) {
            raylib.PlaySound(padlock_sound)
        }



        ////////////////////////////////////////
        //
        // Render.
        //

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.DARKGRAY)



            ////////////////////////////////////////
            //
            // TODO.
            //

            text := fmt.ctprintf("Pets: {}", pets)
            raylib.DrawText(
                text,
                10,
                10,
                20,
                raylib.WHITE
            )


            switch mode {

                case .Main: {

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

                case .Drawing: {



                    // TODO.

                    canvas_center := raylib.Vector2 {
                        cast(f32) raylib.GetScreenWidth()  / 2.0,
                        cast(f32) raylib.GetScreenHeight() / 2.0,
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
                        f32(raylib.GetScreenWidth() ) * 0.75,
                        f32(raylib.GetScreenHeight()) * 0.25,
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





                }

            }



            ////////////////////////////////////////
            //
            // Render easel.
            //

            raylib.DrawTexturePro(
                texture  = easel_texture,
                source   = { 0, 0, cast(f32) easel_texture.width, cast(f32) easel_texture.height },
                dest     = easel_dest,
                origin   = easel_origin,
                rotation = 0,
                tint     = raylib.GRAY,
            )

            easel_padlock_dest := raylib.Rectangle {
                easel_dest.x,
                easel_dest.y - easel_dest.height / 2,
                ease_animation(75, 100, easel_hover_animation, .Bounce_Out),
                ease_animation(75, 100, easel_hover_animation, .Bounce_Out),
            }

            raylib.DrawTexturePro(
                texture  = padlock_texture,
                source   = { 0, 0, cast(f32) padlock_texture.width, cast(f32) padlock_texture.height },
                dest     = easel_padlock_dest,
                origin   = { f32(easel_padlock_dest.width) / 2, f32(easel_padlock_dest.height) / 2 },
                rotation = math.sin(ease_animation(0, 6, easel_hover_animation, .Cubic_Out)) * 10,
                tint     = raylib.WHITE,
            )

            if easel_hover_animation.value == 1 {

                x       := f32(rolypoly_dest.x + rolypoly_dest.width  * 0.75)
                y       := f32(rolypoly_dest.y + rolypoly_dest.height * 0.10)
                message := cstring("I need 100 pets...")

                BUBBLE_DIALOG_FONT_SIZE :: 20
                BUBBLE_DIALOG_PADDING   :: 15
                BUBBLE_DIALOG_ROUNDNESS :: 0.3
                BUBBLE_DIALOG_OUTLINE   :: 4

                text_width  := f32(raylib.MeasureText(message, BUBBLE_DIALOG_FONT_SIZE))
                text_height := f32(BUBBLE_DIALOG_FONT_SIZE)

                bubble_rectangle := raylib.Rectangle {
                    x      = x - BUBBLE_DIALOG_PADDING / 2,
                    y      = y - BUBBLE_DIALOG_PADDING * 3 - text_height,
                    width  = text_width  + BUBBLE_DIALOG_PADDING * 2,
                    height = text_height + BUBBLE_DIALOG_PADDING * 2,
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

                raylib.DrawText(
                    message,
                    i32(bubble_rectangle.x + BUBBLE_DIALOG_PADDING),
                    i32(bubble_rectangle.y + BUBBLE_DIALOG_PADDING),
                    BUBBLE_DIALOG_FONT_SIZE,
                    raylib.BLACK
                )

            }



            ////////////////////////////////////////
            //
            // Render screen buttons.
            //

            for screen_button in screen_buttons {

                animation_scale   := math.lerp(f32(1), 1.1, ease.cubic_in_out(screen_button.hover_t))
                actual_box_width  := screen_button.base_box_width  * animation_scale
                actual_box_height := screen_button.base_box_height * animation_scale

                raylib.DrawRectanglePro(
                    rec = {
                        screen_button.center_x,
                        screen_button.center_y,
                        actual_box_width,
                        actual_box_height,
                    },
                    origin   = { actual_box_width / 2, actual_box_height / 2 },
                    rotation = math.lerp(f32(0), -2, ease.cubic_in_out(screen_button.hover_t)),
                    color    = rgba_lerp(raylib.BLACK, raylib.YELLOW, screen_button.hover_t),
                )

                raylib.DrawText(
                    screen_button.text,
                    i32(screen_button.center_x - screen_button.text_width  / 2),
                    i32(screen_button.center_y - screen_button.text_height / 2),
                    SCREEN_BUTTON_FONT_SIZE,
                    rgba_lerp(raylib.WHITE, raylib.BLACK, screen_button.hover_t),
                )

            }



            ////////////////////////////////////////
            //
            // Render cursor.
            //

            if mode == .Drawing {

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
