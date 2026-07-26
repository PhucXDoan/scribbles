package main

// This file defines the implementation for saving and loading games.

////////////////////////////////////////////////////////////////////////////////





Game_State_V1 :: struct #packed {
    pets                     : u128,
    SAVE_easel_unlocked      : b8,
    SAVE_timestamp           : Maybe(time.Time),
    SAVE_merowchant_unlocked : b8,
}





////////////////////////////////////////////////////////////////////////////////





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
    age          : time.Duration,
    position     : Maybe(World_Vector2),
}



#assert(size_of(Game_State_Vx) == 256)
Game_State_Vx :: union #no_nil {
    [255]u8,
    Game_State_V1,
}





////////////////////////////////////////////////////////////////////////////////





read_save :: proc() -> (
    game_state           : Game_State_V1,
    easel_canvas_image   : raylib.Image,
    easel_canvas_texture : raylib.Texture,
    entities             : [dynamic; 16]Entity,
) {


    entities = {
        Entity_Kind.nil        = {},
        Entity_Kind.Rolypoly   = {},
        Entity_Kind.Easel      = {},
        Entity_Kind.Merowchant = {},
    }

    entities[Entity_Kind.Rolypoly] = {
        kind                  = .Rolypoly,
        base_position         = { 0, 0 },
        origin                = { 0, 0 },
        base_dimensions       = { 1.5, 1 },
        texture_reference     = .Rolypoly,
        mouse_hover_animation = { duration = 0.1  },
        mouse_click_animation = { duration = 0.25 },
    }

    entities[Entity_Kind.Easel] = {
        kind                  = .Easel,
        base_position         = { 7.5, -1 },
        origin                = { 0, -1 },
        base_dimensions       = { 1.5, 3 },
        texture_reference     = .Easel,
        mouse_hover_animation = { duration = 0.1 },
        lock_hover_animation  = { duration = 0.1 },
        mouse_click_animation = { duration = 0.1 },
        locked                = {}, // Filled out later.
        pet_cost              = 100,
    }

    entities[Entity_Kind.Merowchant] = Entity {
        kind                  = .Merowchant,
        base_position         = { -6, 1 },
        origin                = { 0, -1 },
        base_dimensions       = { 3, 3 },
        texture_reference     = .Merowchant_Outside,
        mouse_hover_animation = { duration = 0.1 },
        lock_hover_animation  = { duration = 0.1 },
        mouse_click_animation = { duration = 0.1 },
        locked                = {}, // Filled out later.
        pet_cost              = 9_999,
    }



    stream, error := os.read_entire_file(SAVE_FILE_PATH, context.temp_allocator)

    if error != nil {
        when ODIN_DEBUG {
            fmt.printf("Local Save File: {}.\n\n", error)
        }
    }

    for len(stream) >= 1 {

        save_file_header := eat(&stream, Save_File_Header)

        switch header in save_file_header {



            // Load game state.

            case Save_File_Header_Game_State: {

                assert(game_state == {})
                assert(header.version <= 1)

                saved_game_state := eat(&stream, Game_State_Vx)

                switch state in saved_game_state {

                    case Game_State_V1: {
                        game_state = state
                    }

                    case [255]u8 : panic("Invalid.")
                    case         : panic("Invalid.")

                }

            }



            // Load easel canvas image.

            case Save_File_Header_Easel_Canvas_Image: {

                assert(easel_canvas_image == {})
                assert(header.version <= 1)

                image_data         := eat(&stream, int(header.length))
                easel_canvas_image  = raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))

            }



            // Load Flimsy Friend.

            case Save_File_Header_Flimsy_Friend: {

                assert(header.version <= 1)

                image_data := eat(&stream, int(header.image_length))
                image      := raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))
                defer raylib.UnloadImage(image)

                create_flimsy_friend(
                    entities = &entities,
                    image    = image,
                    age      = header.age,
                    position = header.position,
                )

            }



            case [31]u8 : panic("Invalid.")
            case        : panic("Invalid.")

        }

    }



    // Determine passage of time.

    duration_since_last_game                       :  time.Duration

    duration_since_last_game = time.diff(game_state.SAVE_timestamp.? or_else time.now(), time.now())

    when ODIN_DEBUG {
        fmt.printf("About {} seconds since last game.\n\n", int(time.duration_seconds(duration_since_last_game)))
    }



    // Handle lock status.

    entities[Entity_Kind.Easel     ].locked = !game_state.SAVE_easel_unlocked
    entities[Entity_Kind.Merowchant].locked = !game_state.SAVE_merowchant_unlocked



    // Handle canvas image and texture.

    if easel_canvas_image == {} {
        easel_canvas_image = raylib.GenImageColor(8, 8, EASEL_DEFAULT_COLOR)
    }

    easel_canvas_texture = raylib.LoadTextureFromImage(easel_canvas_image)



    // Age the entities.

    for &entity in entities {

        #partial switch entity.kind {

            case .Flimsy_Friend: {

                duration_of_productivity := min( // TODO Generalize.
                    duration_since_last_game,
                    FLIMSY_FRIEND_LIFESPAN - min(FLIMSY_FRIEND_LIFESPAN, entity.age)
                )

                game_state.pets += u128(FLIMSY_FRIEND_EXPECTED_PETS_PER_SECOND * time.duration_seconds(duration_of_productivity))

            }

        }

        entity.age += duration_since_last_game

    }

    return

}





////////////////////////////////////////////////////////////////////////////////





write_save :: proc(
    game_state         : ^Game_State_V1,
    entities           : [dynamic; 16]Entity,
    easel_canvas_image : raylib.Image,
) {

    when ODIN_DEBUG {
        fmt.printf("Saving to '{}'...\n", SAVE_FILE_PATH)
    }

    save_file_handle := os.open(SAVE_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
    defer os.close(save_file_handle)



    // Update game state's save info.

    game_state.SAVE_timestamp = time.now()
    game_state.SAVE_easel_unlocked      = !entities[Entity_Kind.Easel     ].locked
    game_state.SAVE_merowchant_unlocked = !entities[Entity_Kind.Merowchant].locked



    // Save the game state.

    {

        header : Save_File_Header = Save_File_Header_Game_State {
            version = 1,
        }

        body : Game_State_Vx = game_state^

        _ = os.write(save_file_handle, mem.any_to_bytes(header)) or_else panic("Failed.")
        _ = os.write(save_file_handle, mem.any_to_bytes(body  )) or_else panic("Failed.")

    }



    // Save easel canvas image.

    if easel_canvas_image != {} {

        image_length : i32
        image_data   := raylib.ExportImageToMemory(easel_canvas_image, ".png", &image_length)
        defer raylib.MemFree(image_data)

        header : Save_File_Header = Save_File_Header_Easel_Canvas_Image {
            version = 1,
            length  = u32(image_length),
        }

        _ = os.write    (save_file_handle, mem.any_to_bytes(header)     ) or_else panic("Failed.")
        _ = os.write_ptr(save_file_handle, image_data, int(image_length)) or_else panic("Failed.")

    }



    // Save entities.

    for entity in entities {

        #partial switch entity.kind {

            case .Flimsy_Friend: {

                image := raylib.LoadImageFromTexture(entity.texture_reference.(raylib.Texture))
                defer raylib.UnloadImage(image)

                image_length : i32
                image_data   := raylib.ExportImageToMemory(image, ".png", &image_length)
                defer raylib.MemFree(image_data)

                header : Save_File_Header = Save_File_Header_Flimsy_Friend {
                    version      = 1,
                    image_length = u32(image_length),
                    age          = entity.age,
                    position     = entity.base_position,
                }

                _ = os.write    (save_file_handle, mem.any_to_bytes(header)     ) or_else panic("Failed.")
                _ = os.write_ptr(save_file_handle, image_data, int(image_length)) or_else panic("Failed.")

            }

        }

    }

}





////////////////////////////////////////////////////////////////////////////////

import "core:os"
import "core:fmt"
import "core:time"
import "core:mem"
import "vendor:raylib"
