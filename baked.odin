package main

// This file defines data that are baked into the executable and thus
// are always available. For debug builds, the baked file is loaded at
// run-time, but for release builds, it's part of the executable so that
// the game will not have any other dependencies besides the optional save
// file.

////////////////////////////////////////////////////////////////////////////////





BAKED_FILE_PATH                    :: "./media/baked.bin"
BAKED_STATIC_ENTITY_DIRECTORY_PATH :: "./media/static_entities"



BAKED_textures :  [Baked_Texture]raylib.Texture
Baked_Texture  :: enum {
    nil,
    Submit_Button,
    Rolypoly,
    Easel,
    Padlock,
    Merowchant_Outside,
    Merowchant_Table,
    Merowchant_Background,
    Merowchant_Cat,
}



BAKED_sounds            :  [Baked_Sound]raylib.Sound
BAKED_SOUND_XYLO_COUNT  :: 3
BAKED_SOUND_PAPER_COUNT :: 3
Baked_Sound             :: enum u32 {

    nil,

    Xylo_0,  // Group: "BAKED_SOUND_XYLO_COUNT".
    Xylo_1,  // "
    Xylo_2,  // "

    Paper_0, // Group: "BAKED_SOUND_PAPER_COUNT".
    Paper_1, // "
    Paper_2, // "

    Padlock,
    Padlock_Locked,
    Padlock_Unlocked,
    Easel_Open,
    Easel_Close,
    Tap,
    Pop,
    Merowchant_Open,
    Merowchant_Close,
    Merowchant_Meow,

}



BAKED_fonts :  [Baked_Font]raylib.Font
Baked_Font  :: enum {
    nil,
    Sniglet,
    SpaceMono,
}





////////////////////////////////////////////////////////////////////////////////





bake :: proc(save_static_entity_data : bool, entities : []Entity) {



    // Save static entity data.

    when ODIN_DEBUG {{

        if save_static_entity_data {

            for static_entity_kind in Static_Entity_Kind {

                static_entity_file_path   := fmt.tprintf("{}/{}", BAKED_STATIC_ENTITY_DIRECTORY_PATH, static_entity_kind)
                static_entity_file_handle := os.open(static_entity_file_path, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
                defer os.close(static_entity_file_handle)

                file_content := json.marshal(
                    v         = entities[static_entity_kind].bakeable_fields,
                    opt       = { pretty = true, use_spaces = true },
                    allocator = context.temp_allocator,
                ) or_else panic("Failed.")

                _ = os.write(static_entity_file_handle, file_content) or_else panic("Failed.")

            }

        }

    }} else {

        assert(!save_static_entity_data)

    }



    // Create the baked file.

    when ODIN_DEBUG {{

        baked_file_handle := os.open(BAKED_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
        defer os.close(baked_file_handle)



        // Media assets.

        pack(baked_file_handle, Baked_Texture)
        pack(baked_file_handle, Baked_Sound  )
        pack(baked_file_handle, Baked_Font   )

        pack :: proc(baked_file_handle : ^os.File, $Baked_XYZ : typeid) {

            for asset_handle, asset_handle_i in Baked_XYZ {

                asset_file_data : []u8

                if asset_handle != nil {

                    when Baked_XYZ == Baked_Texture {
                        EXTENSION :: "png"
                    } else when Baked_XYZ == Baked_Sound {
                        EXTENSION :: "wav"
                    } else when Baked_XYZ == Baked_Font {
                        EXTENSION :: "ttf"
                    }

                    asset_file_path := fmt.tprintf("./media/{}.{}", reflect.enum_string(asset_handle), EXTENSION)

                    fmt.printf(
                        "[{}/{}] Packing abc '{}' from file path '{}'...\n{}",
                        asset_handle_i,
                        len(Baked_XYZ) - 1,
                        asset_handle,
                        asset_file_path,
                        "\n" if asset_handle_i == len(Baked_XYZ) - 1 else ""
                    )

                    asset_file_data = os.read_entire_file(asset_file_path, context.temp_allocator) or_else panic("Failed.")

                }

                _ = os.write(baked_file_handle, mem.any_to_bytes(i32(len(asset_file_data)))) or_else panic("Failed.")
                _ = os.write(baked_file_handle,                          asset_file_data   ) or_else panic("Failed.")

            }

        }



        // Static entities.

        for static_entity_kind in Static_Entity_Kind {

            static_entity_file_path := fmt.tprintf("{}/{}", BAKED_STATIC_ENTITY_DIRECTORY_PATH, static_entity_kind)

            bakable_entity_fields : Bakeable_Entity_Fields

            if json.unmarshal(
                data      = os.read_entire_file(static_entity_file_path, context.temp_allocator) or_else panic("Failed."),
                ptr       = &bakable_entity_fields,
                allocator = context.temp_allocator,
            ) != nil {
                panic("Failed.")
            }

            _ = os.write(baked_file_handle, mem.any_to_bytes(bakable_entity_fields)) or_else panic("Failed.")

        }

    }}



    // Load the baked data.

    {

        when ODIN_DEBUG { // Load the local asset pack file at run-time.

            BAKED_DATA := os.read_entire_file(BAKED_FILE_PATH, context.temp_allocator) or_else panic("Failed.")

        } else { // Bake the local asset pack file into the executable.

            @(static)
            @(rodata)
            BAKED_DATA := #load(BAKED_FILE_PATH)

        }

        remainder := BAKED_DATA[:]



        // Media assets.

        unpack(&remainder, Baked_Texture)
        unpack(&remainder, Baked_Sound  )
        unpack(&remainder, Baked_Font   )

        unpack :: proc(remainder : ^[]u8, $Baked_XYZ : typeid) {

            for asset_handle in Baked_XYZ {

                asset_size := op.eat(remainder, i32       )^
                asset_data := op.eat(remainder, asset_size)

                if asset_handle != nil {

                    when Baked_XYZ == Baked_Texture {

                        image := raylib.LoadImageFromMemory(".png", raw_data(asset_data), asset_size)
                        defer raylib.UnloadImage(image)

                        if BAKED_textures[asset_handle] != {} {
                            raylib.UnloadTexture(BAKED_textures[asset_handle])
                            BAKED_textures[asset_handle] = {}
                        }

                        BAKED_textures[asset_handle] = raylib.LoadTextureFromImage(image)

                    } else when Baked_XYZ == Baked_Sound {

                        wave := raylib.LoadWaveFromMemory(".wav", raw_data(asset_data), asset_size)
                        defer raylib.UnloadWave(wave)

                        if BAKED_sounds[asset_handle] != {} {
                            raylib.UnloadSound(BAKED_sounds[asset_handle])
                            BAKED_sounds[asset_handle] = {}
                        }

                        BAKED_sounds[asset_handle] = raylib.LoadSoundFromWave(wave)

                    } else when Baked_XYZ == Baked_Font {

                        if BAKED_fonts[asset_handle] != {} {
                            raylib.UnloadFont(BAKED_fonts[asset_handle])
                            BAKED_fonts[asset_handle] = {}
                        }

                        BAKED_fonts[asset_handle] = raylib.LoadFontFromMemory(
                            fileType       = ".ttf",
                            fileData       = raw_data(asset_data),
                            dataSize       =          asset_size,
                            fontSize       = 96,
                            codepoints     = nil,
                            codepointCount = 0,
                        )

                    }

                }

            }

        }



        // Static entities.

        for static_entity_kind in Static_Entity_Kind {
            entities[static_entity_kind].bakeable_fields = op.eat(&remainder, Bakeable_Entity_Fields)^
        }

    }

}





////////////////////////////////////////////////////////////////////////////////

import "core:fmt"
import "core:os"
import "core:reflect"
import "core:mem"
import "core:slice"
import "core:encoding/json"
import "base:runtime"
import "vendor:raylib"
import "op"
