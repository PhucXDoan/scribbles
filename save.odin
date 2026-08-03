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
    version : u8, // Version 1.
}

#assert(size_of(Game_State_Vx) == 256)
Game_State_Vx :: union #no_nil {
    [255]u8,
    Game_State_V1,
}





Save_File_Header_Easel_Canvas_Image :: struct #packed {
    version : u8,  // Version 1.
    length  : u32, // "
}





Save_File_Header_Flimsy_Friend :: struct #packed {
    version      : u8,                   // Version 1.
    image_length : u32,                  // "
    age          : time.Duration,        // "
    position     : Maybe(World_Vector2), // "
}





////////////////////////////////////////////////////////////////////////////////





read_save :: proc(
    entities : ^[dynamic; $N]Entity,
) -> (
    game_state               : Game_State_V1,
    easel_canvas_image       : raylib.Image,
    duration_since_last_game : time.Duration,
) {

    remainder, error := os.read_entire_file(SAVE_FILE_PATH, context.temp_allocator)

    when ODIN_DEBUG {
        if error != nil {
            fmt.printf("Local save file: {}.\n\n", error)
        }
    }

    for len(remainder) >= 1 {

        save_file_header := eat(&remainder, Save_File_Header)

        switch header in save_file_header {



            // Load game state.

            case Save_File_Header_Game_State: {

                assert(game_state == {})
                assert(header.version >= 1)

                saved_game_state := eat(&remainder, Game_State_Vx)

                switch state in saved_game_state {

                    case Game_State_V1 : game_state = state
                    case [255]u8       : panic("Invalid.")
                    case               : panic("Invalid.")

                }

                entities[Static_Entity_Kind.Easel     ].locked = !game_state.SAVE_easel_unlocked
                entities[Static_Entity_Kind.Merowchant].locked = !game_state.SAVE_merowchant_unlocked
                duration_since_last_game                       = time.diff(game_state.SAVE_timestamp.? or_else time.now(), time.now())

            }



            // Load easel canvas image.

            case Save_File_Header_Easel_Canvas_Image: {

                assert(easel_canvas_image == {})
                assert(header.version >= 1)

                image_data         := eat(&remainder, int(header.length))
                easel_canvas_image  = raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))

            }



            // Load Flimsy Friend.

            case Save_File_Header_Flimsy_Friend: {

                assert(header.version >= 1)

                image_data := eat(&remainder, int(header.image_length))
                image      := raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))
                defer raylib.UnloadImage(image)

                create_flimsy_friend(
                    entities = entities,
                    image    = image,
                    age      = header.age,
                    position = header.position,
                )

            }



            case [31]u8 : panic("Invalid.")
            case        : panic("Invalid.")

        }

    }

    return

}





////////////////////////////////////////////////////////////////////////////////





write_save :: proc(
    game_state         : ^Game_State_V1,
    entities           : [dynamic; $N]Entity,
    easel_canvas_image : raylib.Image,
) {

    when ODIN_DEBUG {
        fmt.printf("Saving to '{}'...\n", SAVE_FILE_PATH)
    }

    file_handle := os.open(SAVE_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
    defer os.close(file_handle)



    // Update game state's save info.

    game_state.SAVE_timestamp           = time.now()
    game_state.SAVE_easel_unlocked      = !entities[Static_Entity_Kind.Easel     ].locked
    game_state.SAVE_merowchant_unlocked = !entities[Static_Entity_Kind.Merowchant].locked



    // Save the game state.

    {

        header : Save_File_Header = Save_File_Header_Game_State {
            version = 1,
        }

        body : Game_State_Vx = game_state^

        _ = os.write(file_handle, mem.any_to_bytes(header)) or_else panic("Failed.")
        _ = os.write(file_handle, mem.any_to_bytes(body  )) or_else panic("Failed.")

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

        _ = os.write    (file_handle, mem.any_to_bytes(header)     ) or_else panic("Failed.")
        _ = os.write_ptr(file_handle, image_data, int(image_length)) or_else panic("Failed.")

    }



    // Save entities.

    for entity in entities {

        switch entity.kind {

            case .Flimsy_Friend: {

                image := raylib.LoadImageFromTexture(entity.texture_reference.(raylib.Texture))
                defer raylib.UnloadImage(image)

                image_length :  i32
                image_data   := raylib.ExportImageToMemory(image, ".png", &image_length)
                defer raylib.MemFree(image_data)

                header : Save_File_Header = Save_File_Header_Flimsy_Friend {
                    version      = 1,
                    image_length = u32(image_length),
                    age          = entity.age,
                    position     = entity.base_position,
                }

                _ = os.write    (file_handle, mem.any_to_bytes(header)     ) or_else panic("Failed.")
                _ = os.write_ptr(file_handle, image_data, int(image_length)) or_else panic("Failed.")

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
