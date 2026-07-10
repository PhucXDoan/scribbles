package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/ease"
import "core:math/rand"
import "core:reflect"
import "core:os"
import "core:mem"
import "core:time"
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
    Clear_Increase_Reset,
    Increase_Repeat,
    Decrease_Stop,
    Increase_Stop,
}

update_animation :: proc(animation : ^Animation) {

    if animation.running {

        switch animation.control {

            case .Clear_Increase_Reset: {

                animation.value += raylib.GetFrameTime() / animation.duration

                if animation.value > 1 {
                    animation.value   = 0
                    animation.running = false
                }

            }

            case .Increase_Repeat: {
                animation.value += raylib.GetFrameTime() / animation.duration
                animation.value  = math.mod_f32(animation.value, 1)
            }

            case .Decrease_Stop: {
                animation.value -= raylib.GetFrameTime() / animation.duration
                animation.value  = clamp(animation.value, 0, 1)
            }

            case .Increase_Stop: {
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

        case .Clear_Increase_Reset: {
            animation.value   = 0
            animation.running = true
        }

        case .Increase_Repeat: {
            animation.running = true
        }

        case .Decrease_Stop: {
            animation.running = true
        }

        case .Increase_Stop: {
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

        global_asset_pack_file_handle := os.open(GLOBAL_ASSET_PACK_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
        defer os.close(global_asset_pack_file_handle)

        pack_asset_type(Global_Asset_Texture_Handle, Global_Asset_Pack_Texture_Header, global_asset_pack_file_handle)
        pack_asset_type(Global_Asset_Sound_Handle  , Global_Asset_Pack_Sound_Header  , global_asset_pack_file_handle)
        pack_asset_type(Global_Asset_Font_Handle   , Global_Asset_Pack_Font_Header   , global_asset_pack_file_handle)

        pack_asset_type :: proc(
            $Global_Asset_ABC_Handle : typeid,
            $Global_Asset_ABC_Header : typeid,
            pack_file_handle         : ^os.File
        ) {

            for asset_handle, asset_handle_i in Global_Asset_ABC_Handle {

                if asset_handle == nil {
                    continue
                }

                when Global_Asset_ABC_Handle == Global_Asset_Texture_Handle {
                    EXTENSION :: "png"
                } else when Global_Asset_ABC_Handle == Global_Asset_Sound_Handle {
                    EXTENSION :: "wav"
                } else when Global_Asset_ABC_Handle == Global_Asset_Font_Handle {
                    EXTENSION :: "ttf"
                }

                asset_file_path := fmt.tprintf("./media/{}.{}", reflect.enum_string(asset_handle), EXTENSION)

                fmt.printf(
                    "[{}/{}] Packing abc '{}' from file path '{}'...\n",
                    asset_handle_i,
                    len(Global_Asset_ABC_Handle) - 1,
                    asset_handle,
                    asset_file_path,
                )

                asset_file_data := os.read_entire_file(asset_file_path, context.temp_allocator) or_else panic("Failed.")

                header : Global_Asset_Pack_Header = Global_Asset_ABC_Header {
                    handle = asset_handle,
                    length = u32(len(asset_file_data)),
                }

                _ = os.write(pack_file_handle, mem.any_to_bytes(header)) or_else panic("Failed.")
                _ = os.write(pack_file_handle, asset_file_data         ) or_else panic("Failed.")

            }

            fmt.printf("\n")

        }

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

    EASEL_COST          :: 100
    EASEL_DEFAULT_COLOR :: raylib.Color { 234, 240, 243, 255 }

    SAVE_FILE_PATH :: "./scribbles.save"

    #assert(size_of(Save_File_Header) == 32)
    Save_File_Header :: union #no_nil {
        [31]u8,
        Save_File_Header_Game_State,
        Save_File_Header_Easel_Canvas_Image,
        Save_File_Header_Flimsy_Friend,
    }

    Save_File_Header_Game_State :: struct #packed {
        version : u8,
    }

    Save_File_Header_Easel_Canvas_Image :: struct #packed {
        version : u8,
        length  : u32,
    }

    Save_File_Header_Flimsy_Friend :: struct #packed {
        version      : u8,
        image_length : u32,
    }

    #assert(size_of(Game_State) == 256)
    Game_State :: union #no_nil {
        [255]u8,
        Game_State_V1,
    }

    Game_State_V1 :: struct #packed {
        pets           : u128,
        easel_unlocked : b8,
        save_timestamp : Maybe(time.Time),
    }



    game_state              : Game_State_V1
    easel_canvas_image      : raylib.Image
    seconds_since_last_game : int

    main_entities := [dynamic; 16]Main_Entity {

        Main_Entity_Kind.nil = {},

        Main_Entity_Kind.Rolypoly = {
            kind          = .Rolypoly,
            base_position = {
                cast(f32) raylib.GetScreenWidth()  * 0.5,
                cast(f32) raylib.GetScreenHeight() * 0.5,
            },
            origin                = { 0.5, 0.5 },
            base_dimensions       = { 75, 50 },
            texture_reference     = .Rolypoly,
            mouse_hover_animation = { duration = 0.1  },
            mouse_click_animation = { duration = 0.25 },
        },

        Main_Entity_Kind.Easel = {
            kind          = .Easel,
            base_position = {
                cast(f32) raylib.GetScreenWidth()  * 0.85,
                cast(f32) raylib.GetScreenHeight() * 0.6,
            },
            origin                = { 0.5, 1 },
            base_dimensions       = { 100, 200 },
            texture_reference     = .Easel,
            mouse_hover_animation = { duration = 0.1 },
            lock_hover_animation  = { duration = 0.1 },
            mouse_click_animation = { duration = 0.1 },
            locked                = {}, // Filled out later.
        },

    }

    {

        remaining_save_file_data, save_file_reading_error := os.read_entire_file(SAVE_FILE_PATH, context.temp_allocator)

        if save_file_reading_error == nil {

            for len(remaining_save_file_data) >= 1 {

                save_file_header := eat(&remaining_save_file_data, Save_File_Header)

                switch header in save_file_header {



                    // Load game state.

                    case Save_File_Header_Game_State: {

                        assert(header.version <= 1)

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



                    // Load easel canvas image.

                    case Save_File_Header_Easel_Canvas_Image: {

                        assert(header.version <= 1)

                        image_data := eat(&remaining_save_file_data, int(header.length))

                        easel_canvas_image = raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))

                    }



                    // Load flimsy friend.

                    case Save_File_Header_Flimsy_Friend: {

                        assert(header.version <= 1)

                        image_data := eat(&remaining_save_file_data, int(header.image_length))

                        image := raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))
                        defer raylib.UnloadImage(image)

                        create_flimsy_friend(&main_entities, image)

                    }



                    case [31]u8 : panic("Invalid.")
                    case        : panic("Invalid.")

                }

            }

        }

        main_entities[Main_Entity_Kind.Easel].locked = !game_state.easel_unlocked

        if easel_canvas_image == {} {
            easel_canvas_image = raylib.GenImageColor(8, 8, EASEL_DEFAULT_COLOR)
        }

        seconds_since_last_game = int(time.duration_seconds(time.diff(game_state.save_timestamp.? or_else time.now(), time.now())))

        when ODIN_DEBUG {
            fmt.printf("About {} seconds since last game.\n\n", seconds_since_last_game)
        }

    }

    save_game :: proc(game_state : ^Game_State_V1, easel_canvas_image : raylib.Image, main_entities : []Main_Entity) {

        fmt.printf("Saving to '{}'...\n", SAVE_FILE_PATH)

        save_file_handle := os.open(SAVE_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
        defer os.close(save_file_handle)



        // Update the save timestamp for future use upon next loading.

        game_state.save_timestamp = time.now()



        // Save game state.

        {

            save_file_header : Save_File_Header = Save_File_Header_Game_State {
                version = 1,
            }

            save_game_state : Game_State = game_state^

            _ = os.write(save_file_handle, mem.any_to_bytes(save_file_header)) or_else panic("Failed.")
            _ = os.write(save_file_handle, mem.any_to_bytes(save_game_state )) or_else panic("Failed.")

        }



        // Save easel canvas image.

        if easel_canvas_image != {} {

            image_length : i32
            image_data   := raylib.ExportImageToMemory(easel_canvas_image, ".png", &image_length)
            defer raylib.MemFree(image_data)

            save_file_header : Save_File_Header = Save_File_Header_Easel_Canvas_Image {
                version = 1,
                length  = u32(image_length),
            }

            _ = os.write    (save_file_handle, mem.any_to_bytes(save_file_header)) or_else panic("Failed.")
            _ = os.write_ptr(save_file_handle, image_data, int(image_length)     ) or_else panic("Failed.")

        }



        // Save flimsy friends.

        for entity in main_entities {

            if entity.kind != .Flimsy_Friend {
                continue
            }

            image := raylib.LoadImageFromTexture(entity.texture_reference.(raylib.Texture))
            defer raylib.UnloadImage(image)

            image_length : i32
            image_data   := raylib.ExportImageToMemory(image, ".png", &image_length)
            defer raylib.MemFree(image_data)

            save_file_header : Save_File_Header = Save_File_Header_Flimsy_Friend {
                version      = 1,
                image_length = u32(image_length),
            }

            _ = os.write    (save_file_handle, mem.any_to_bytes(save_file_header)) or_else panic("Failed.")
            _ = os.write_ptr(save_file_handle, image_data, int(image_length)     ) or_else panic("Failed.")

        }

    }



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Buttons.
    //

    Button :: struct {
        center           : raylib.Vector2,
        style            : Button_Style,
        mouse_hover_tint : raylib.Color,
        mouse_hovering   : bool,
        pressed          : bool,
        hidden           : bool,
        disabled         : bool,
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

        button.pressed = (
            !button.disabled &&
            button.mouse_hovering &&
            raylib.IsMouseButtonPressed(.LEFT)
        )

    }

    render_button :: proc(button : Button) {

        if !button.hidden {

            tint := raylib.WHITE

            if button.disabled {
                tint = raylib.DARKGRAY
            } else if button.mouse_hovering {
                tint = button.mouse_hover_tint
            }

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
                        color     = tint,
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
                        tint     = tint,
                    )

                }

                case: panic("Invalid.")

            }

        }

    }



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Entities.
    //

    FLIMSY_FRIEND_BASE_DIMENSIONS         :: raylib.Vector2 { 35, 35 }
    FLIMSY_FRIEND_WALK_ANIMATION_DURATION :: 1.25

    Entity_Texture_Reference :: union {
        Global_Asset_Texture_Handle,
        raylib.Texture,
    }

    Main_Entity_Kind :: enum {
        nil,
        Rolypoly,
        Easel,
        Flimsy_Friend,
    }

    Main_Entity :: struct {

        kind                  : Main_Entity_Kind,
        base_position         : raylib.Vector2,
        origin                : raylib.Vector2,
        base_dimensions       : raylib.Vector2,
        texture_reference     : Entity_Texture_Reference,
        mouse_hover_animation : Animation,
        lock_hover_animation  : Animation,
        mouse_click_animation : Animation,
        walk_animation        : Animation,
        walk_displacement     : raylib.Vector2,
        walk_delay            : f32,
        locked                : bool,

        mouse_hovering        : bool,
        mouse_clicked         : bool,

        rendering_position    : raylib.Vector2,
        rendering_dimensions  : raylib.Vector2,

    }

    Dialogue_Bubble :: struct {
        position    : raylib.Vector2,
        message     : cstring,
        font_handle : Global_Asset_Font_Handle,
    }

    create_flimsy_friend :: proc(main_entities : ^[dynamic; 16]Main_Entity, image : raylib.Image) {

        append(
            main_entities,
            Main_Entity {
                kind          = .Flimsy_Friend,
                base_position = {
                    cast(f32) raylib.GetScreenWidth()  * 0.25 + f32(len(main_entities)) * 100,
                    cast(f32) raylib.GetScreenHeight() * 0.7,
                },
                origin                = { 0.5, 1 },
                base_dimensions       = FLIMSY_FRIEND_BASE_DIMENSIONS,
                texture_reference     = raylib.LoadTextureFromImage(image),
                mouse_hover_animation = { duration = 0.1                                   },
                mouse_click_animation = { duration = 0.1                                   },
                walk_animation        = { duration = FLIMSY_FRIEND_WALK_ANIMATION_DURATION },
            }
        )

    }



    ////////////////////////////////////////////////////////////////////////////////
    //
    // Main loop.
    //

    Mode :: enum {
        Main,
        Easel,
    }

    mode := Mode.Main

    easel_canvas_texture := raylib.LoadTextureFromImage(easel_canvas_image)

    easel_canvas_requirement_painted_pixel_minimum := 10
    easel_canvas_requirement_painted_pixel_maximum := 0



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



    save_game(&game_state, easel_canvas_image, main_entities[:])

    for {

        should_close                 := raylib.WindowShouldClose()
        seconds_since_last_save_game := time.duration_seconds(time.diff(game_state.save_timestamp.? or_else time.now(), time.now()))

        if should_close || seconds_since_last_save_game >= 60 {
            save_game(&game_state, easel_canvas_image, main_entities[:])
        }

        if should_close {
            break
        }

        mouse_position := raylib.GetMousePosition()

        dialogue_bubbles : [dynamic; 32]Dialogue_Bubble



        ////////////////////////////////////////////////////////////////////////////////
        //
        // Update entities.
        //

        for &entity in main_entities {



            // Handle walking.

            #partial switch entity.kind {

                case .Flimsy_Friend: {

                    if !entity.walk_animation.running && entity.walk_displacement == {} && entity.walk_delay <= 0 {

                        if entity.base_position.x < f32(raylib.GetScreenWidth()) * 0.2 {

                            entity.walk_displacement = { 20, 0 }

                        } else if entity.base_position.x > f32(raylib.GetScreenWidth()) * 0.8 {

                            entity.walk_displacement = { -20, 0 }

                        } else if entity.base_position.y < f32(raylib.GetScreenHeight()) * 0.6 {

                            entity.walk_displacement = { 0, 20 }

                        } else if entity.base_position.y > f32(raylib.GetScreenHeight()) * 0.9 {

                            entity.walk_displacement = { 0, -20 }

                        } else {

                            entity.walk_displacement = {
                                f32(rand.int31_max(2) * 2 - 1) * (10 + 30 * rand.float32()),
                                f32(rand.int31_max(2) * 2 - 1) * (     10 * rand.float32()),
                            }

                        }

                        entity.walk_delay = 3 * rand.float32()

                    }

                    if entity.walk_delay > 0 {
                        entity.walk_delay -= raylib.GetFrameTime()
                        entity.walk_delay  = max(entity.walk_delay, 0)
                    }

                    if !entity.walk_animation.running && entity.walk_displacement != {} && entity.walk_delay <= 0 {
                        control_animation(&entity.walk_animation, .Clear_Increase_Reset)
                    }

                    update_animation(&entity.walk_animation)

                    if !entity.walk_animation.running && entity.walk_displacement != {} && entity.walk_delay <= 0 {
                        entity.base_position.x   += entity.walk_displacement.x
                        entity.base_position.y   += entity.walk_displacement.y
                        entity.walk_displacement  = {}
                    }

                }

            }



            // Handle mouse hovering.

            entity.mouse_hovering = (
                mode == .Main &&
                raylib.CheckCollisionPointRec(
                    raylib.GetMousePosition(),
                    {
                        entity.base_position.x - entity.rendering_dimensions.x * entity.origin.x,
                        entity.base_position.y - entity.rendering_dimensions.y * entity.origin.y,
                        entity.rendering_dimensions.x,
                        entity.rendering_dimensions.y,
                    },
                )
            )

            control_animation(
                &entity.mouse_hover_animation,
                .Increase_Stop if entity.mouse_hovering else .Decrease_Stop
            )

            update_animation(&entity.mouse_hover_animation)

            if entity.locked {

                control_animation(
                    &entity.lock_hover_animation,
                    .Increase_Stop if entity.mouse_hovering else .Decrease_Stop
                )

                old_lock_hover_animation_value := entity.lock_hover_animation.value

                update_animation(&entity.lock_hover_animation)

                if (
                    old_lock_hover_animation_value    <  0.5 &&
                    entity.lock_hover_animation.value >= 0.5 &&
                    !raylib.IsSoundPlaying(global_asset_sounds[.Padlock])
                ) {
                    raylib.PlaySound(global_asset_sounds[.Padlock])
                }

            }

            #partial switch entity.kind {

                case .Rolypoly: {

                    raylib.SetMouseCursor(
                        raylib.MouseCursor.POINTING_HAND if entity.mouse_hovering else raylib.MouseCursor.DEFAULT
                    )

                }

                case .Easel: {

                    if entity.locked && entity.mouse_hover_animation.value == 1 {

                        append(
                            &dialogue_bubbles,
                            Dialogue_Bubble {
                                position = {
                                    main_entities[Main_Entity_Kind.Rolypoly].rendering_position.x + main_entities[Main_Entity_Kind.Rolypoly].rendering_dimensions.x * 0.25,
                                    main_entities[Main_Entity_Kind.Rolypoly].rendering_position.y - main_entities[Main_Entity_Kind.Rolypoly].rendering_dimensions.y * 0.25,
                                },
                                message = (
                                    game_state.pets < EASEL_COST
                                        ? fmt.ctprintf("I need {} pets...", EASEL_COST)
                                        : fmt.ctprintf("Unlock for {} pets...?", EASEL_COST)
                                ),
                                font_handle = .Sniglet,
                            }
                        )

                    }

                }

            }



            // Handle mouse clicking.

            entity.mouse_clicked = (
                mode == .Main &&
                entity.mouse_hovering && raylib.IsMouseButtonPressed(.LEFT)
            )

            if entity.mouse_clicked {
                control_animation(&entity.mouse_click_animation, .Clear_Increase_Reset)
            }

            update_animation(&entity.mouse_click_animation)

            if entity.mouse_clicked {

                if !entity.locked {

                    #partial switch entity.kind {

                        case .Rolypoly: {

                            game_state.pets += 1
                            control_animation(&entity.mouse_click_animation, .Clear_Increase_Reset)

                            @(static) time_since_last_click := f32(0)

                            xylo_sound_handle := Global_Asset_Sound_Handle(
                                i32(Global_Asset_Sound_Handle.Xylo_0) +
                                rand.int31_max(GLOBAL_ASSET_SOUND_XYLO_COUNT)
                            )

                            raylib.SetSoundVolume(
                                global_asset_sounds[xylo_sound_handle],
                                min(max(f32(raylib.GetTime()) - time_since_last_click, 0), 1)
                            )

                            raylib.PlaySound(global_asset_sounds[xylo_sound_handle])

                            time_since_last_click = f32(raylib.GetTime())

                        }

                        case .Easel: {

                            mode = .Easel
                            raylib.PlaySound(global_asset_sounds[.Easel_Open])

                        }

                    }

                } else if entity.lock_hover_animation.value == 1 { // To make sure user hover over lock for long enough...

                    #partial switch entity.kind {

                        case .Easel: {

                            if game_state.pets >= EASEL_COST {

                                game_state.pets           -= EASEL_COST
                                game_state.easel_unlocked  = true
                                entity.locked              = false

                                raylib.PlaySound(global_asset_sounds[.Padlock_Unlocked])

                            }

                        }

                    }

                    if entity.locked {
                        control_animation(&entity.lock_hover_animation, .Clear_Increase_Reset)
                        raylib.PlaySound(global_asset_sounds[.Padlock_Locked])
                    }

                }

            }



            // Determine rendering dimensions.

            entity.rendering_dimensions = entity.base_dimensions

            if !entity.locked {

                entity.rendering_dimensions.x *= ease_animation(1, 1.025, entity.mouse_hover_animation, .Cubic_Out)
                entity.rendering_dimensions.y *= ease_animation(1, 1.025, entity.mouse_hover_animation, .Cubic_Out)

                if entity.mouse_click_animation.running {
                    entity.rendering_dimensions.x /= ease_animation(1.2, 1, entity.mouse_click_animation, .Quartic_Out)
                    entity.rendering_dimensions.y *= ease_animation(1.2, 1, entity.mouse_click_animation, .Cubic_Out  )
                }

            }

            if entity.walk_animation.running {
                entity.rendering_dimensions.x /= 1 + 0.5 * math.sin(ease_animation(0, math.PI, entity.walk_animation, .Quartic_In_Out))
                entity.rendering_dimensions.y *= 1 + 0.2 * math.sin(ease_animation(0, math.PI, entity.walk_animation, .Quartic_In_Out))
            }



            // Determine rendering position.

            entity.rendering_position = entity.base_position

            if entity.walk_animation.running {
                entity.rendering_position.x += ease_animation(0, entity.walk_displacement.x, entity.walk_animation, .Quartic_In_Out)
                entity.rendering_position.y += ease_animation(0, entity.walk_displacement.y, entity.walk_animation, .Quartic_In_Out)
                entity.rendering_position.y -= 15 * math.pow(math.sin(entity.walk_animation.value * math.PI), 8)
            }

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

        if easel_canvas_back_button.pressed || (mode == .Easel && raylib.IsKeyPressed(.ESCAPE)) {
            mode = .Main
            raylib.PlaySound(global_asset_sounds[.Easel_Close])
        }



        painted_pixel_count := 0

        easel_canvas_pixels := raylib.LoadImageColors(easel_canvas_image)
        defer raylib.UnloadImageColors(easel_canvas_pixels)

        for y in 0 ..< easel_canvas_image.height {

            for x in 0 ..< easel_canvas_image.width {

                pixel := easel_canvas_pixels[y * easel_canvas_image.width + x]

                if pixel != EASEL_DEFAULT_COLOR {
                    painted_pixel_count += 1
                }

            }

        }

        flimsy_friend_count := 0

        for entity in main_entities {
            if entity.kind == .Flimsy_Friend {
                flimsy_friend_count += 1
            }
        }

        satisfied := (
            painted_pixel_count >= easel_canvas_requirement_painted_pixel_minimum &&
            (painted_pixel_count <= easel_canvas_requirement_painted_pixel_maximum || easel_canvas_requirement_painted_pixel_maximum == 0) &&
            flimsy_friend_count < 3
        )

        easel_canvas_submit_button.disabled = !satisfied



        easel_canvas_submit_button.hidden = mode != .Easel

        update_button(&easel_canvas_submit_button)

        if easel_canvas_submit_button.pressed {

            create_flimsy_friend(&main_entities, easel_canvas_image)

            raylib.ImageClearBackground(&easel_canvas_image, EASEL_DEFAULT_COLOR)

            mode = .Main
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
            // Render entities.
            //

            if mode == .Main {

                for entity in main_entities {

                    texture : raylib.Texture

                    switch reference in entity.texture_reference {
                        case nil                         : texture = {}
                        case Global_Asset_Texture_Handle : texture = global_asset_textures[reference]
                        case raylib.Texture              : texture = reference
                        case                             : panic("Invalid.")
                    }

                    raylib.DrawTexturePro(
                        texture = texture,
                        source  = {
                            0,
                            0,
                            cast(f32) texture.width,
                            cast(f32) texture.height,
                        },
                        dest = {
                            entity.rendering_position.x,
                            entity.rendering_position.y,
                            entity.rendering_dimensions.x,
                            entity.rendering_dimensions.y,
                        },
                        origin = {
                            entity.rendering_dimensions.x * entity.origin.x,
                            entity.rendering_dimensions.y * entity.origin.y,
                        },
                        rotation = 0,
                        tint     = raylib.GRAY if entity.locked else raylib.WHITE,
                    )

                    if entity.locked {

                        dest := raylib.Rectangle {
                            entity.rendering_position.x - entity.rendering_dimensions.x * (entity.origin.x - 0.5),
                            entity.rendering_position.y - entity.rendering_dimensions.y * (entity.origin.y - 0.5),
                            ease_animation(75, 100, entity.lock_hover_animation, .Bounce_Out),
                            ease_animation(75, 100, entity.lock_hover_animation, .Bounce_Out),
                        }

                        raylib.DrawTexturePro(
                            texture = global_asset_textures[.Padlock],
                            source  = {
                                0,
                                0,
                                f32(global_asset_textures[.Padlock].width ),
                                f32(global_asset_textures[.Padlock].height),
                            },
                            dest   = dest,
                            origin = {
                                dest.width  / 2,
                                dest.height / 2,
                            },
                            rotation = (
                                math.sin(ease_animation(0, 6, entity.lock_hover_animation, .Cubic_Out)) * 10 +
                                math.sin(ease_animation(0, 6, entity.mouse_click_animation, .Cubic_Out)) * 10
                            ),
                            tint = raylib.WHITE,
                        )

                    }

                }

            }



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render dialogue bubbles.
            //

            for dialogue_bubble in dialogue_bubbles {

                DIALOGUE_BUBBLE_FONT_SIZE :: 30
                DIALOGUE_BUBBLE_PADDING   :: 15
                DIALOGUE_BUBBLE_ROUNDNESS :: 0.3
                DIALOGUE_BUBBLE_OUTLINE   :: 4

                measurement := raylib.MeasureTextEx(
                    font     = global_asset_fonts[dialogue_bubble.font_handle],
                    text     = dialogue_bubble.message,
                    fontSize = DIALOGUE_BUBBLE_FONT_SIZE,
                    spacing  = 0,
                )

                bubble_rec := raylib.Rectangle {
                    dialogue_bubble.position.x - DIALOGUE_BUBBLE_PADDING / 2,
                    dialogue_bubble.position.y - DIALOGUE_BUBBLE_PADDING * 3 - measurement.y,
                    measurement.x + DIALOGUE_BUBBLE_PADDING * 2,
                    measurement.y + DIALOGUE_BUBBLE_PADDING * 2,
                }

                vertices := [?][2]f32 {
                    { dialogue_bubble.position.x, bubble_rec.y + bubble_rec.height },
                    { dialogue_bubble.position.x, dialogue_bubble.position.y },
                    { dialogue_bubble.position.x + (dialogue_bubble.position.x - bubble_rec.x) * 2, bubble_rec.y + bubble_rec.height },
                }

                raylib.DrawRectangleRoundedLinesEx(
                    rec       = bubble_rec,
                    roundness = DIALOGUE_BUBBLE_ROUNDNESS,
                    segments  = 0,
                    lineThick = DIALOGUE_BUBBLE_OUTLINE,
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
                    thick    = DIALOGUE_BUBBLE_OUTLINE,
                    color    = raylib.BLACK,
                )

                raylib.DrawLineEx(
                    startPos = vertices[1],
                    endPos   = vertices[2],
                    thick    = DIALOGUE_BUBBLE_OUTLINE,
                    color    = raylib.BLACK,
                )

                raylib.DrawRectangleRounded(
                    rec       = bubble_rec,
                    roundness = DIALOGUE_BUBBLE_ROUNDNESS,
                    segments  = 0,
                    color     = raylib.LIGHTGRAY,
                )

                raylib.DrawTextEx(
                    font     = global_asset_fonts[dialogue_bubble.font_handle],
                    text     = dialogue_bubble.message,
                    position = {
                        bubble_rec.x + DIALOGUE_BUBBLE_PADDING,
                        bubble_rec.y + DIALOGUE_BUBBLE_PADDING,
                    },
                    fontSize = DIALOGUE_BUBBLE_FONT_SIZE,
                    spacing  = 0,
                    tint     = raylib.BLACK,
                )

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

                {

                    builder := strings.builder_make(context.temp_allocator)
                    defer strings.builder_destroy(&builder)

                    fmt.sbprintf(&builder, "Request:\n")
                    fmt.sbprintf(&builder, "flimsy friend\n")
                    fmt.sbprintf(&builder, "\n")

                    fmt.sbprintf(&builder, "Requirements:\n")

                    if easel_canvas_requirement_painted_pixel_minimum >= 1 {
                        fmt.sbprintf(&builder, "* At least {} painted pixels\n", easel_canvas_requirement_painted_pixel_minimum)
                    }

                    if easel_canvas_requirement_painted_pixel_maximum != 0 {
                        fmt.sbprintf(&builder, "* At most {} painted pixels\n", easel_canvas_requirement_painted_pixel_maximum)
                    }

                    fmt.sbprintf(&builder, "\n")

                    fmt.sbprintf(&builder, "Evaluation:\n")
                    fmt.sbprintf(&builder, "There are {} painted pixels...\n", painted_pixel_count)

                    requirement_text := strings.to_cstring(&builder)

                    raylib.DrawTextEx(
                        font     = global_asset_fonts[.Sniglet],
                        text     = requirement_text,
                        position = { 50, 150 },
                        fontSize = 30,
                        spacing  = 0,
                        tint     = raylib.BLACK,
                    )

                }

            }

            render_button(easel_canvas_back_button)
            render_button(easel_canvas_submit_button)

        }



        free_all(context.temp_allocator)

    }

}
