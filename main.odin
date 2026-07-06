package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/ease"
import "core:reflect"
import "core:os"
import "core:mem"
import "vendor:raylib"



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
    Cyclic,
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

            case .Cyclic: {
                animation.value += raylib.GetFrameTime() / animation.duration
                animation.value  = math.mod_f32(animation.value, 1)
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

        case .Cyclic: {
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
// Main.
//

main :: proc() {



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Pack global assets.
    //

    Global_Asset_Texture_Handle :: enum u32 {
        nil           = 0,
        Submit_Button = 1,
        Rolypoly      = 2,
        Cursor        = 3,
        Easel         = 4,
        Padlock       = 5,
    }

    Global_Asset_Sound_Handle :: enum u32 {
        nil              = 0,
        Xylo             = 1,
        Padlock          = 2,
        Padlock_Locked   = 3,
        Padlock_Unlocked = 4,
        Easel_Open       = 5,
        Easel_Close      = 6,
    }

    Global_Asset_Font_Handle :: enum u32 {
        nil     = 0,
        Sniglet = 1,
    }

    #assert(size_of(Global_Asset_Pack_Header) == 32)
    Global_Asset_Pack_Header :: union {
        Global_Asset_Pack_Texture_Header,
        Global_Asset_Pack_Sound_Header,
        Global_Asset_Pack_Font_Header,
    }

    Global_Asset_Pack_Texture_Header :: struct #packed {
        handle       : Global_Asset_Texture_Handle,
        image_length : u32,
        _            : [23]u8,
    }

    Global_Asset_Pack_Sound_Header :: struct #packed {
        handle       : Global_Asset_Sound_Handle,
        sound_length : u32,
        _            : [23]u8,
    }

    Global_Asset_Pack_Font_Header :: struct #packed {
        handle      : Global_Asset_Font_Handle,
        font_length : u32,
        _           : [23]u8,
    }

    GLOBAL_ASSET_PACK_FILE_PATH :: "./media/Global_Asset_Pack.bin"

    when ODIN_DEBUG {{



        // Set up global asset pack file.

        global_asset_pack_file_handle := os.open(GLOBAL_ASSET_PACK_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
        defer os.close(global_asset_pack_file_handle)



        // Pack textures.

        for global_asset_texture_handle, global_asset_texture_handle_i in Global_Asset_Texture_Handle {

            if global_asset_texture_handle != nil {

                global_asset_texture_file_path := fmt.tprintf("./media/{}.png", reflect.enum_string(global_asset_texture_handle))

                fmt.printf(
                    "[{}/{}] Packing texture '{}' from file path '{}'...\n",
                    global_asset_texture_handle_i,
                    len(Global_Asset_Texture_Handle) - 1,
                    global_asset_texture_handle,
                    global_asset_texture_file_path,
                )

                global_asset_texture_file_data := os.read_entire_file(global_asset_texture_file_path, context.temp_allocator) or_else panic("Failed.")

                global_asset_pack_texture_header : Global_Asset_Pack_Header = Global_Asset_Pack_Texture_Header {
                    handle       = global_asset_texture_handle,
                    image_length = u32(len(global_asset_texture_file_data)),
                }

                _ = os.write(global_asset_pack_file_handle, mem.any_to_bytes(global_asset_pack_texture_header)) or_else panic("Failed.")
                _ = os.write(global_asset_pack_file_handle, global_asset_texture_file_data                    ) or_else panic("Failed.")

            }

        }

        fmt.printf("\n")



        // Pack sounds.

        for global_asset_sound_handle, global_asset_sound_handle_i in Global_Asset_Sound_Handle {

            if global_asset_sound_handle != nil {

                global_asset_sound_file_path := fmt.tprintf("./media/{}.wav", reflect.enum_string(global_asset_sound_handle))

                fmt.printf(
                    "[{}/{}] Packing sound '{}' from file path '{}'...\n",
                    global_asset_sound_handle_i,
                    len(Global_Asset_Sound_Handle) - 1,
                    global_asset_sound_handle,
                    global_asset_sound_file_path,
                )

                global_asset_sound_file_data := os.read_entire_file(global_asset_sound_file_path, context.temp_allocator) or_else panic("Failed.")

                global_asset_pack_sound_header : Global_Asset_Pack_Header = Global_Asset_Pack_Sound_Header {
                    handle       = global_asset_sound_handle,
                    sound_length = u32(len(global_asset_sound_file_data)),
                }

                _ = os.write(global_asset_pack_file_handle, mem.any_to_bytes(global_asset_pack_sound_header)) or_else panic("Failed.")
                _ = os.write(global_asset_pack_file_handle, global_asset_sound_file_data                    ) or_else panic("Failed.")

            }

        }

        fmt.printf("\n")



        // Pack fonts.

        for global_asset_font_handle, global_asset_font_handle_i in Global_Asset_Font_Handle {

            if global_asset_font_handle != nil {

                global_asset_font_file_path := fmt.tprintf("./media/{}.ttf", reflect.enum_string(global_asset_font_handle))

                fmt.printf(
                    "[{}/{}] Packing font '{}' from file path '{}'...\n",
                    global_asset_font_handle_i,
                    len(Global_Asset_Font_Handle) - 1,
                    global_asset_font_handle,
                    global_asset_font_file_path,
                )

                global_asset_font_file_data := os.read_entire_file(global_asset_font_file_path, context.temp_allocator) or_else panic("Failed.")

                global_asset_pack_font_header : Global_Asset_Pack_Header = Global_Asset_Pack_Font_Header {
                    handle      = global_asset_font_handle,
                    font_length = u32(len(global_asset_font_file_data)),
                }

                _ = os.write(global_asset_pack_file_handle, mem.any_to_bytes(global_asset_pack_font_header)) or_else panic("Failed.")
                _ = os.write(global_asset_pack_file_handle, global_asset_font_file_data                    ) or_else panic("Failed.")

            }

        }

        fmt.printf("\n")

    }}



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Set up Raylib.
    //

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



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Load global assets.
    //

    global_asset_textures : [Global_Asset_Texture_Handle]raylib.Texture
    global_asset_sounds   : [Global_Asset_Sound_Handle  ]raylib.Sound
    global_asset_fonts    : [Global_Asset_Font_Handle   ]raylib.Font

    {

        when ODIN_DEBUG {

            // Load the local asset pack file.
            remaining_global_asset_pack_data := os.read_entire_file(GLOBAL_ASSET_PACK_FILE_PATH, context.temp_allocator) or_else panic("Failed.")

        } else {

            // Bake the local asset pack file into the executable.
            @(static)
            remaining_global_asset_pack_data := #load(GLOBAL_ASSET_PACK_FILE_PATH)

        }

        for {



            // Done processing all of the data?

            if len(remaining_global_asset_pack_data) == 0 {
                break
            }



            // Get header.

            global_asset_pack_header : ^Global_Asset_Pack_Header

            assert(len(remaining_global_asset_pack_data) >= size_of(global_asset_pack_header^))

            global_asset_pack_header         = transmute(^Global_Asset_Pack_Header) raw_data(remaining_global_asset_pack_data)
            remaining_global_asset_pack_data = remaining_global_asset_pack_data[size_of(global_asset_pack_header^):]



            // Handle header.

            switch header in global_asset_pack_header {



                // Textures.

                case Global_Asset_Pack_Texture_Header: {



                    // Get image data.

                    image_data : []u8

                    assert(u32(len(remaining_global_asset_pack_data)) >= header.image_length)

                    image_data                       = remaining_global_asset_pack_data[:header.image_length ]
                    remaining_global_asset_pack_data = remaining_global_asset_pack_data[ header.image_length:]



                    // Load asset texture.

                    global_asset_image := raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))
                    defer raylib.UnloadImage(global_asset_image)

                    assert(header.handle != nil)
                    assert(int(header.handle) < len(global_asset_textures))
                    assert(global_asset_textures[header.handle] == {})

                    global_asset_textures[header.handle] = raylib.LoadTextureFromImage(global_asset_image)

                }



                // Sounds.

                case Global_Asset_Pack_Sound_Header: {



                    // Get sound data.

                    sound_data : []u8

                    assert(u32(len(remaining_global_asset_pack_data)) >= header.sound_length)

                    sound_data                       = remaining_global_asset_pack_data[:header.sound_length ]
                    remaining_global_asset_pack_data = remaining_global_asset_pack_data[ header.sound_length:]



                    // Load asset sound.

                    global_asset_wave := raylib.LoadWaveFromMemory(".wav", raw_data(sound_data), i32(len(sound_data)))
                    defer raylib.UnloadWave(global_asset_wave)

                    assert(header.handle != nil)
                    assert(int(header.handle) < len(global_asset_sounds))
                    assert(global_asset_sounds[header.handle] == {})

                    global_asset_sounds[header.handle] = raylib.LoadSoundFromWave(global_asset_wave)

                }



                // Fonts.

                case Global_Asset_Pack_Font_Header: {



                    // Get font data.

                    font_data : []u8

                    assert(u32(len(remaining_global_asset_pack_data)) >= header.font_length)

                    font_data                        = remaining_global_asset_pack_data[:header.font_length ]
                    remaining_global_asset_pack_data = remaining_global_asset_pack_data[ header.font_length:]



                    // Load asset font.

                    assert(header.handle != nil)
                    assert(int(header.handle) < len(global_asset_fonts))
                    assert(global_asset_fonts[header.handle] == {})

                    global_asset_fonts[header.handle] = raylib.LoadFontFromMemory(
                        fileType       = ".ttf",
                        fileData       = raw_data(font_data),
                        dataSize       = i32(len(font_data)),
                        fontSize       = 96,
                        codepoints     = nil,
                        codepointCount = 0,
                    )

                }



                case: panic("Invalid.")

            }

        }

    }



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Main loop.
    //

    Mode :: enum {
        Normal,
        Easel,
    }

    mode                  := Mode.Normal
    time_since_last_click := cast(f32) 0.0
    friend_animation      := Animation { duration = 1 }
    friend_x              := cast(f32) 100.0
    pets                  := 0

    rolypoly_animation := Animation { duration = 0.25 }

    easel_unlocked                := false
    easel_cost                    := 100
    easel_default_color           := raylib.Color { 234, 240, 243, 255 }
    easel_hover_animation         := Animation { duration = 0.20 }
    easel_lockpad_click_animation := Animation { duration = 0.10 }

    easel_canvas_image := raylib.GenImageColor(8, 8, easel_default_color)
    defer raylib.UnloadImage(easel_canvas_image)

    easel_canvas_texture := raylib.LoadTextureFromImage(easel_canvas_image)
    defer raylib.UnloadTexture(easel_canvas_texture)

    friend_texture : Maybe(raylib.Texture)
    defer  {
        if friend_texture != nil {
            raylib.UnloadTexture(friend_texture.?)
        }
    }

    for !raylib.WindowShouldClose() {

        mouse_position := raylib.GetMousePosition()



        ////////////////////////////////////////////////////////////////////////////////
        //
        // Update Rolypoly.
        //

        rolypoly_dest := raylib.Rectangle {
            0.0,
            0.0,
            cast(f32) global_asset_textures[.Rolypoly].width,
            cast(f32) global_asset_textures[.Rolypoly].height,
        }

        if rolypoly_animation.running {
            rolypoly_dest.width  /= ease_animation(1.2, 1, rolypoly_animation, .Quartic_Out)
            rolypoly_dest.height *= ease_animation(1.2, 1, rolypoly_animation, .Cubic_Out)
        }

        rolypoly_dest.x = cast(f32) raylib.GetScreenWidth()  / 2.0 - rolypoly_dest.width  / 2.0
        rolypoly_dest.y = cast(f32) raylib.GetScreenHeight() / 2.0 - rolypoly_dest.height / 2.0

        hovering_rolypoly := false

        if mode == .Normal {

            hovering_rolypoly = raylib.CheckCollisionPointRec(
                mouse_position,
                rolypoly_dest,
            )

            if hovering_rolypoly && raylib.IsMouseButtonPressed(.LEFT) {

                pets += 1

                control_animation(&rolypoly_animation, .Restart)

                raylib.PlaySound(global_asset_sounds[.Xylo])

                raylib.SetSoundVolume(
                    global_asset_sounds[.Xylo],
                    min(max(cast(f32) raylib.GetTime() - time_since_last_click, 0.0), 1.0)
                )

                time_since_last_click = cast(f32) raylib.GetTime()

            }

        }

        if hovering_rolypoly {
            raylib.SetMouseCursor(raylib.MouseCursor.POINTING_HAND)
        } else {
            raylib.SetMouseCursor(raylib.MouseCursor.DEFAULT)
        }

        update_animation(&rolypoly_animation)



        ////////////////////////////////////////////////////////////////////////////////
        //
        // Update easel.
        //

        easel_dest := raylib.Rectangle {
            f32(raylib.GetScreenWidth())  * 0.8,
            f32(raylib.GetScreenHeight()) * 0.6,
            100,
            200,
        }

        if easel_unlocked {
            easel_dest.width  *= ease_animation(1.0, 1.025, easel_hover_animation, .Cubic_Out)
            easel_dest.height *= ease_animation(1.0, 1.025, easel_hover_animation, .Cubic_Out)
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



        if easel_unlocked {

            if hovering_easel && raylib.IsMouseButtonPressed(.LEFT) {

                mode = .Easel
                raylib.PlaySound(global_asset_sounds[.Easel_Open])

            }

        } else {

            if (
                old_easel_hover_animation_value <  0.5 &&
                easel_hover_animation.value     >= 0.5 &&
                !raylib.IsSoundPlaying(global_asset_sounds[.Padlock])
            ) {
                raylib.PlaySound(global_asset_sounds[.Padlock])
            }

            if easel_hover_animation.value == 1 && raylib.IsMouseButtonPressed(.LEFT) {

                if pets < easel_cost {

                    control_animation(&easel_lockpad_click_animation, .Restart)
                    raylib.PlaySound(global_asset_sounds[.Padlock_Locked])

                } else {

                    pets           -= easel_cost
                    easel_unlocked  = true
                    raylib.PlaySound(global_asset_sounds[.Padlock_Unlocked])

                }

            }

            update_animation(&easel_lockpad_click_animation)

        }

        if mode == .Easel {
            raylib.HideCursor()
        } else {
            raylib.ShowCursor()
        }



        ////////////////////////////////////////////////////////////////////////////////
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

        hovering_submit_button := false

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
                raylib.PlaySound(global_asset_sounds[.Easel_Close])

            }

            raylib.UpdateTexture(easel_canvas_texture, easel_canvas_image.data)

        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        // Render.
        //

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.BROWN if mode == .Easel else raylib.DARKGRAY)



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render statistics.
            //

            raylib.DrawTextEx(
                font     = global_asset_fonts[.Sniglet],
                text     = fmt.ctprintf("Pets: {}", pets),
                position = { 10, 10 },
                fontSize = 40,
                spacing  = 0,
                tint     = raylib.WHITE,
            )



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render Rolypoly.
            //

            if mode == .Normal {

                raylib.DrawTexturePro(
                    texture  = global_asset_textures[.Rolypoly],
                    source   = { 0.0, 0.0, cast(f32) global_asset_textures[.Rolypoly].width, cast(f32) global_asset_textures[.Rolypoly].height },
                    dest     = rolypoly_dest,
                    origin   = { 0.0, 0.0 },
                    rotation = 0.0,
                    tint     = raylib.WHITE,
                )

            }



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render friend.
            //

            control_animation(&friend_animation, .Cyclic)
            update_animation(&friend_animation)

            friend_x += raylib.GetFrameTime() * 10.0

            if mode == .Normal {

                friend_dest := raylib.Rectangle {
                    friend_x,
                    500.0,
                    100.0 / 1 + 0.085 * math.sin(math.PI * friend_animation.value),
                    100.0 * 1 + 0.125 * math.sin(math.PI * friend_animation.value),
                }

                friend_dest.y -= friend_dest.height * 0.33 * math.sin(math.PI * friend_animation.value)

                friend_origin := raylib.Vector2 {
                    friend_dest.width / 2,
                    friend_dest.height,
                }

                if friend_texture != nil {

                    raylib.DrawTexturePro(
                        texture  = friend_texture.?,
                        source   = { 0, 0, f32(friend_texture.?.width), f32(friend_texture.?.height) },
                        dest     = friend_dest,
                        origin   = friend_origin,
                        rotation = 0,
                        tint     = raylib.WHITE,
                    )

                }

            }



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render easel.
            //

            if mode == .Normal {

                raylib.DrawTexturePro(
                    texture  = global_asset_textures[.Easel],
                    source   = { 0, 0, cast(f32) global_asset_textures[.Easel].width, cast(f32) global_asset_textures[.Easel].height },
                    dest     = easel_dest,
                    origin   = easel_origin,
                    rotation = 0,
                    tint     = raylib.WHITE if easel_unlocked else raylib.GRAY,
                )

                if !easel_unlocked {

                    easel_padlock_dest := raylib.Rectangle {
                        easel_dest.x,
                        easel_dest.y - easel_dest.height / 2,
                        ease_animation(75, 100, easel_hover_animation, .Bounce_Out),
                        ease_animation(75, 100, easel_hover_animation, .Bounce_Out),
                    }

                    easel_padlock_rotation := math.sin(ease_animation(0, 6, easel_hover_animation, .Cubic_Out)) * 10
                    easel_padlock_rotation += math.sin(ease_animation(0, 6, easel_lockpad_click_animation, .Cubic_Out)) * 10

                    raylib.DrawTexturePro(
                        texture  = global_asset_textures[.Padlock],
                        source   = { 0, 0, cast(f32) global_asset_textures[.Padlock].width, cast(f32) global_asset_textures[.Padlock].height },
                        dest     = easel_padlock_dest,
                        origin   = { f32(easel_padlock_dest.width) / 2, f32(easel_padlock_dest.height) / 2 },
                        rotation = easel_padlock_rotation,
                        tint     = raylib.WHITE,
                    )

                    if easel_hover_animation.value == 1 {

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
                            font     = global_asset_fonts[.Sniglet],
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
                            font     = global_asset_fonts[.Sniglet],
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



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render easel canvas.
            //

            if mode == .Easel {

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

                if hovered_easel_canvas_cell_is_within {

                    raylib.DrawRectangleLines(
                        posX   = i32((easel_canvas_dest.x - easel_canvas_origin.x + f32(hovered_easel_canvas_cell_coordinate_x) * easel_canvas_cell_dimensions.x)),
                        posY   = i32((easel_canvas_dest.y - easel_canvas_origin.y + f32(hovered_easel_canvas_cell_coordinate_y) * easel_canvas_cell_dimensions.y)),
                        width  = i32(easel_canvas_cell_dimensions.x),
                        height = i32(easel_canvas_cell_dimensions.y),
                        color  = raylib.BLACK,
                    )

                }

                raylib.DrawTexturePro(
                    texture  = global_asset_textures[.Submit_Button],
                    source   = { 0.0, 0.0, f32(global_asset_textures[.Submit_Button].width), f32(global_asset_textures[.Submit_Button].height) },
                    dest     = submit_button_dest,
                    origin   = submit_button_origin,
                    rotation = 0.0,
                    tint     = raylib.GREEN if hovering_submit_button else raylib.WHITE,
                )

            }



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render cursor.
            //

            if mode == .Easel {

                cursor_dest := raylib.Rectangle {
                    mouse_position.x + 4.0,
                    mouse_position.y + 10.0,
                    cast(f32) global_asset_textures[.Cursor].width,
                    cast(f32) global_asset_textures[.Cursor].height
                }

                raylib.DrawTexturePro(
                    texture  = global_asset_textures[.Cursor],
                    source   = { 0.0, 0.0, cast(f32) global_asset_textures[.Cursor].width, cast(f32) global_asset_textures[.Cursor].height },
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
