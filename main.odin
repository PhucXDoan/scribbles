package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/ease"
import "core:math/rand"
import "core:reflect"
import "core:os"
import "core:mem"
import "vendor:raylib"



////////////////////////////////////////////////////////////////////////////////
//
// Miscellaneous.
//

eat_type :: proc(slice : ^[]u8, $T : typeid) -> ^T {

    assert(len(slice^) >= size_of(T))

    result := transmute(^T) raw_data(slice^)
    slice^  = slice[size_of(T):]

    return result

}

eat_bytes :: proc(slice : ^[]u8, length : int) -> []u8 {

    assert(len(slice) >= length)

    result := slice[:length ]
    slice^  = slice[ length:]

    return result

}

eat :: proc {
    eat_type,
    eat_bytes,
}



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
        nil,
        Submit_Button,
        Rolypoly,
        Easel,
        Padlock,
    }

    GLOBAL_ASSET_SOUND_XYLO_COUNT :: 3
    Global_Asset_Sound_Handle :: enum u32 {
        nil,
        Xylo_0,
        Xylo_1,
        Xylo_2,
        Padlock,
        Padlock_Locked,
        Padlock_Unlocked,
        Easel_Open,
        Easel_Close,
    }

    Global_Asset_Font_Handle :: enum u32 {
        nil     = 0,
        Sniglet = 1,
    }

    #assert(size_of(Global_Asset_Pack_Header) == 32)
    Global_Asset_Pack_Header :: union #no_nil {
        [31]u8,
        Global_Asset_Pack_Texture_Header,
        Global_Asset_Pack_Sound_Header,
        Global_Asset_Pack_Font_Header,
    }

    Global_Asset_Pack_Texture_Header :: struct #packed {
        handle : Global_Asset_Texture_Handle,
        length : u32,
    }

    Global_Asset_Pack_Sound_Header :: struct #packed {
        handle : Global_Asset_Sound_Handle,
        length : u32,
    }

    Global_Asset_Pack_Font_Header :: struct #packed {
        handle : Global_Asset_Font_Handle,
        length : u32,
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
                    handle = global_asset_texture_handle,
                    length = u32(len(global_asset_texture_file_data)),
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
                    handle = global_asset_sound_handle,
                    length = u32(len(global_asset_sound_file_data)),
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
                    handle = global_asset_font_handle,
                    length = u32(len(global_asset_font_file_data)),
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

    raylib.SetExitKey(nil)



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Load global assets.
    //

    @(static) global_asset_textures : [Global_Asset_Texture_Handle]raylib.Texture
    @(static) global_asset_sounds   : [Global_Asset_Sound_Handle  ]raylib.Sound
    @(static) global_asset_fonts    : [Global_Asset_Font_Handle   ]raylib.Font

    {

        when ODIN_DEBUG {

            // Load the local asset pack file.
            remaining_global_asset_pack_data := os.read_entire_file(GLOBAL_ASSET_PACK_FILE_PATH, context.temp_allocator) or_else panic("Failed.")

        } else {

            // Bake the local asset pack file into the executable.
            @(static)
            remaining_global_asset_pack_data := #load(GLOBAL_ASSET_PACK_FILE_PATH)

        }

        for len(remaining_global_asset_pack_data) >= 1 {

            global_asset_pack_header := eat(&remaining_global_asset_pack_data, Global_Asset_Pack_Header)

            switch header in global_asset_pack_header {



                // Load global textures.

                case Global_Asset_Pack_Texture_Header: {

                    image_data := eat(&remaining_global_asset_pack_data, int(header.length))

                    global_asset_image := raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))
                    defer raylib.UnloadImage(global_asset_image)

                    assert(header.handle != nil)
                    assert(int(header.handle) < len(global_asset_textures))
                    assert(global_asset_textures[header.handle] == {})

                    global_asset_textures[header.handle] = raylib.LoadTextureFromImage(global_asset_image)

                }



                // Load global sounds.

                case Global_Asset_Pack_Sound_Header: {

                    sound_data := eat(&remaining_global_asset_pack_data, int(header.length))

                    global_asset_wave := raylib.LoadWaveFromMemory(".wav", raw_data(sound_data), i32(len(sound_data)))
                    defer raylib.UnloadWave(global_asset_wave)

                    assert(header.handle != nil)
                    assert(int(header.handle) < len(global_asset_sounds))
                    assert(global_asset_sounds[header.handle] == {})

                    global_asset_sounds[header.handle] = raylib.LoadSoundFromWave(global_asset_wave)

                }



                // Load global fonts.

                case Global_Asset_Pack_Font_Header: {

                    font_data := eat(&remaining_global_asset_pack_data, int(header.length))

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



                case [31]u8 : panic("Invalid.")
                case        : panic("Invalid.")

            }

        }

    }



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Load local save-file.
    //

    SAVE_FILE_PATH :: "./scribbles.save"

    #assert(size_of(Save_File_Header) == 32)
    Save_File_Header :: union #no_nil {
        [31]u8,
        Game_State_Prefix,
    }

    Game_State_Prefix :: struct #packed {
        version : u8,
    }

    #assert(size_of(Game_State) == 256)
    Game_State :: union #no_nil {
        [255]u8,
        Game_State_V1,
    }

    Game_State_V1 :: struct #packed {
        pets           : u128,
        easel_unlocked : b8,
    }



    game_state : Game_State_V1

    {

        remaining_save_file_data, save_file_reading_error := os.read_entire_file(SAVE_FILE_PATH, context.temp_allocator)

        if save_file_reading_error != nil {
            save_game(game_state)
            remaining_save_file_data = os.read_entire_file(SAVE_FILE_PATH, context.temp_allocator) or_else panic("Failed.")
        }

        for len(remaining_save_file_data) >= 1 {

            save_file_header := eat(&remaining_save_file_data, Save_File_Header)

            switch header in save_file_header {



                // Load game state.

                case Game_State_Prefix: {

                    save_game_state := eat(&remaining_save_file_data, Game_State)

                    switch state in save_game_state {

                        case Game_State_V1: {
                            assert(game_state == {})
                            game_state = state
                        }

                        case [255]u8 : panic("Invalid.")
                        case         : panic("Invalid.")

                    }

                }



                case [31]u8 : panic("Invalid.")
                case        : panic("Invalid.")

            }

        }

    }

    save_game :: proc(game_state : Game_State) {

        fmt.printf("Saving to '{}'...\n", SAVE_FILE_PATH)

        save_file_handle := os.open(SAVE_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
        defer os.close(save_file_handle)



        // Save game state.

        save_file_header : Save_File_Header = Game_State_Prefix {
            version = 1,
        }

        save_game_state : Game_State = game_state

        _ = os.write(save_file_handle, mem.any_to_bytes(save_file_header)) or_else panic("Failed.")
        _ = os.write(save_file_handle, mem.any_to_bytes(save_game_state )) or_else panic("Failed.")



    }

    save_game(game_state)



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Main loop.
    //

    EASEL_COST          :: 100
    EASEL_DEFAULT_COLOR :: raylib.Color { 234, 240, 243, 255 }

    Mode :: enum {
        Normal,
        Easel,
    }

    mode                          := Mode.Normal
    time_since_last_click         := cast(f32) 0.0
    friend_animation              := Animation { duration = 1 }
    friend_x                      := cast(f32) 100.0
    rolypoly_animation            := Animation { duration = 0.25 }
    easel_hover_animation         := Animation { duration = 0.20 }
    easel_lockpad_click_animation := Animation { duration = 0.10 }

    easel_canvas_image   := raylib.GenImageColor(8, 8, EASEL_DEFAULT_COLOR)
    easel_canvas_texture := raylib.LoadTextureFromImage(easel_canvas_image)
    friend_texture       :  Maybe(raylib.Texture)




    Button :: struct {
        center           : raylib.Vector2,
        style            : Button_Style,
        mouse_hover_tint : raylib.Color,
        mouse_hovering   : bool,
        mouse_pressed    : bool,
        hidden           : bool,
    }

    Button_Style :: union {
        Button_Style_Lame,
        Button_Style_Texture,
    }

    Button_Style_Lame :: struct {
        text        : cstring,
        font_handle : Global_Asset_Font_Handle,
        font_size   : f32,
    }

    Button_Style_Texture :: struct {
        dimensions     : raylib.Vector2,
        texture_handle : Global_Asset_Texture_Handle,
    }



    BUTTON_STYLE_LAME_ROUNDNESS :: 0.2
    BUTTON_STYLE_LAME_OUTLINE   :: 4
    BUTTON_STYLE_LAME_PADDING   :: 4

    update_button :: proc(button : ^Button) {

        if button.hidden {

            button.mouse_hovering = false

        } else {

            dest : raylib.Rectangle

            switch style in button.style {

                case Button_Style_Lame: {

                    measurement := raylib.MeasureTextEx(
                        font     = global_asset_fonts[style.font_handle],
                        text     = style.text,
                        fontSize = style.font_size,
                        spacing  = 0,
                    )

                    dest = raylib.Rectangle {
                        button.center.x - measurement.x / 2 - BUTTON_STYLE_LAME_PADDING,
                        button.center.y - measurement.y / 2 - BUTTON_STYLE_LAME_PADDING,
                        measurement.x + BUTTON_STYLE_LAME_PADDING * 2,
                        measurement.y + BUTTON_STYLE_LAME_PADDING * 2,
                    }

                }

                case Button_Style_Texture: {
                    dest = {
                        button.center.x - style.dimensions.x / 2,
                        button.center.y - style.dimensions.y / 2,
                        style.dimensions.x,
                        style.dimensions.y,
                    }
                }

                case: panic("Invalid.")

            }

            button.mouse_hovering = raylib.CheckCollisionPointRec(
                raylib.GetMousePosition(),
                dest,
            )

        }

        button.mouse_pressed = button.mouse_hovering && raylib.IsMouseButtonPressed(.LEFT)

    }

    render_button :: proc(button : Button) {

        if !button.hidden {

            dest : raylib.Rectangle

            switch style in button.style {

                case Button_Style_Lame: {

                    measurement := raylib.MeasureTextEx(
                        font     = global_asset_fonts[style.font_handle],
                        text     = style.text,
                        fontSize = style.font_size,
                        spacing  = 0,
                    )

                    rec := raylib.Rectangle {
                        button.center.x - measurement.x / 2 - BUTTON_STYLE_LAME_PADDING,
                        button.center.y - measurement.y / 2 - BUTTON_STYLE_LAME_PADDING,
                        measurement.x + BUTTON_STYLE_LAME_PADDING * 2,
                        measurement.y + BUTTON_STYLE_LAME_PADDING * 2,
                    }

                    raylib.DrawRectangleRoundedLinesEx(
                        rec       = rec,
                        roundness = BUTTON_STYLE_LAME_ROUNDNESS,
                        segments  = 0,
                        lineThick = BUTTON_STYLE_LAME_OUTLINE,
                        color     = raylib.BLACK,
                    )

                    raylib.DrawRectangleRounded(
                        rec       = rec,
                        roundness = BUTTON_STYLE_LAME_ROUNDNESS,
                        segments  = 0,
                        color     = button.mouse_hover_tint if button.mouse_hovering else raylib.LIGHTGRAY,
                    )

                    raylib.DrawTextEx(
                        font     = global_asset_fonts[style.font_handle],
                        text     = style.text,
                        position = {
                            button.center.x - measurement.x / 2,
                            button.center.y - measurement.y / 2,
                        },
                        fontSize = style.font_size,
                        spacing  = 0,
                        tint     = raylib.BLACK,
                    )

                }

                case Button_Style_Texture: {

                    raylib.DrawTexturePro(
                        texture = global_asset_textures[style.texture_handle],
                        source  = {
                            0,
                            0,
                            f32(global_asset_textures[style.texture_handle].width ),
                            f32(global_asset_textures[style.texture_handle].height),
                        },
                        dest = {
                            button.center.x,
                            button.center.y,
                            style.dimensions.x,
                            style.dimensions.y,
                        },
                        origin = {
                            style.dimensions.x / 2,
                            style.dimensions.y / 2,
                        },
                        rotation = 0,
                        tint     = button.mouse_hover_tint if button.mouse_hovering else raylib.WHITE,
                    )

                }

                case: panic("Invalid.")

            }

        }

    }



    easel_canvas_back_button := Button {

        center = {
            f32(raylib.GetScreenWidth() ) * 0.45,
            f32(raylib.GetScreenHeight()) * 0.85,
        },

        style = Button_Style_Lame {
            text        = "Back",
            font_handle = .Sniglet,
            font_size   = 30,
        },

        mouse_hover_tint = raylib.GREEN,

    }

    easel_canvas_submit_button := Button {

        center = {
            f32(raylib.GetScreenWidth() ) * 0.55,
            f32(raylib.GetScreenHeight()) * 0.85,
        },

        style = Button_Style_Texture {
            dimensions     = { 100, 50 },
            texture_handle = .Submit_Button,
        },

        mouse_hover_tint = raylib.GREEN,

    }



    for {

        if raylib.WindowShouldClose() {
            save_game(game_state)
            break
        }

        mouse_position := raylib.GetMousePosition()



        ////////////////////////////////////////////////////////////////////////////////
        //
        // Update Rolypoly.
        //

        rolypoly_dest := raylib.Rectangle {
            0,
            0,
            200,
            150,
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

                game_state.pets += 1

                control_animation(&rolypoly_animation, .Restart)

                xylo_sound_handle := Global_Asset_Sound_Handle(
                    i32(Global_Asset_Sound_Handle.Xylo_0) +
                    rand.int31_max(GLOBAL_ASSET_SOUND_XYLO_COUNT)
                )

                raylib.SetSoundVolume(
                    global_asset_sounds[xylo_sound_handle],
                    min(max(cast(f32) raylib.GetTime() - time_since_last_click, 0.0), 1.0)
                )

                raylib.PlaySound(global_asset_sounds[xylo_sound_handle])

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

        if game_state.easel_unlocked {
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



        if game_state.easel_unlocked {

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

                if game_state.pets < u128(EASEL_COST) {

                    control_animation(&easel_lockpad_click_animation, .Restart)
                    raylib.PlaySound(global_asset_sounds[.Padlock_Locked])

                } else {

                    game_state.pets           -= u128(EASEL_COST)
                    game_state.easel_unlocked  = true
                    raylib.PlaySound(global_asset_sounds[.Padlock_Unlocked])

                }

            }

            update_animation(&easel_lockpad_click_animation)

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



        if mode == .Easel {

            if raylib.IsMouseButtonPressed(.LEFT) && hovered_easel_canvas_cell_is_within {

                raylib.ImageDrawPixel(
                    &easel_canvas_image,
                    cast(i32) hovered_easel_canvas_cell_coordinate_x,
                    cast(i32) hovered_easel_canvas_cell_coordinate_y,
                    { 49, 42, 22, 255 }
                )

            }

            raylib.UpdateTexture(easel_canvas_texture, easel_canvas_image.data)

        }



        easel_canvas_back_button.hidden = mode != .Easel
        update_button(&easel_canvas_back_button)

        if easel_canvas_back_button.mouse_pressed || raylib.IsKeyPressed(.ESCAPE) {
            mode = .Normal
            raylib.PlaySound(global_asset_sounds[.Easel_Close])
        }



        easel_canvas_submit_button.hidden = mode != .Easel
        update_button(&easel_canvas_submit_button)

        if easel_canvas_submit_button.mouse_pressed {

            if friend_texture != nil {
                raylib.UnloadTexture(friend_texture.?)
            }

            friend_texture = raylib.LoadTextureFromImage(easel_canvas_image)

            raylib.ImageClearBackground(&easel_canvas_image, EASEL_DEFAULT_COLOR)

            mode = .Normal
            raylib.PlaySound(global_asset_sounds[.Easel_Close])

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
                text     = fmt.ctprintf("Pets: {}", game_state.pets),
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
                    tint     = raylib.WHITE if game_state.easel_unlocked else raylib.GRAY,
                )

                if !game_state.easel_unlocked {

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
                            game_state.pets < u128(EASEL_COST)
                                ? fmt.ctprintf("I need {} pets...", EASEL_COST)
                                : fmt.ctprintf("Unlock for {} pets...?", EASEL_COST)
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

            }

            render_button(easel_canvas_back_button)
            render_button(easel_canvas_submit_button)



        }



        free_all(context.temp_allocator)

    }

}
