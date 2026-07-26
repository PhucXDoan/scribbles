package main

// This file defines game assets that are baked into the executable and
// thus are always available. For debug builds, we pack the assets and
// export it into a file, and in the release build we load that file at
// compile-time to be embedded into the executable. This is to make the
// game just be a single executable without any other dependencies besides
// the optional save file.

////////////////////////////////////////////////////////////////////////////////





GLOBAL_asset_textures : [Global_Asset_Texture_Handle]raylib.Texture
GLOBAL_asset_sounds   : [Global_Asset_Sound_Handle  ]raylib.Sound
GLOBAL_asset_fonts    : [Global_Asset_Font_Handle   ]raylib.Font

Global_Asset_Texture_Handle :: enum u32 {
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

GLOBAL_ASSET_SOUND_XYLO_COUNT  :: 3
GLOBAL_ASSET_SOUND_PAPER_COUNT :: 3
Global_Asset_Sound_Handle      :: enum u32 {

    nil,

    Xylo_0,  // Group: "GLOBAL_ASSET_SOUND_XYLO_COUNT".
    Xylo_1,  // "
    Xylo_2,  // "

    Paper_0, // Group: "GLOBAL_ASSET_SOUND_PAPER_COUNT".
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

Global_Asset_Font_Handle :: enum u32 {
    nil,
    Sniglet,
}





////////////////////////////////////////////////////////////////////////////////





GLOBAL_ASSET_PACK_FILE_PATH :: "./media/Global_Asset_Pack.bin"

create_global_asset_pack_file :: proc() {

    file_handle := os.open(GLOBAL_ASSET_PACK_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
    defer os.close(file_handle)

    pack(file_handle, Global_Asset_Texture_Handle)
    pack(file_handle, Global_Asset_Sound_Handle  )
    pack(file_handle, Global_Asset_Font_Handle   )

    pack :: proc(file_handle : ^os.File, $Global_Asset_XYZ_Handle : typeid) {

        for asset_handle, asset_handle_i in Global_Asset_XYZ_Handle {

            asset_file_data : []u8

            if asset_handle != nil {

                when Global_Asset_XYZ_Handle == Global_Asset_Texture_Handle {
                    EXTENSION :: "png"
                } else when Global_Asset_XYZ_Handle == Global_Asset_Sound_Handle {
                    EXTENSION :: "wav"
                } else when Global_Asset_XYZ_Handle == Global_Asset_Font_Handle {
                    EXTENSION :: "ttf"
                }

                asset_file_path := fmt.tprintf("./media/{}.{}", reflect.enum_string(asset_handle), EXTENSION)

                fmt.printf(
                    "[{}/{}] Packing abc '{}' from file path '{}'...\n{}",
                    asset_handle_i,
                    len(Global_Asset_XYZ_Handle) - 1,
                    asset_handle,
                    asset_file_path,
                    "\n" if asset_handle_i == len(Global_Asset_XYZ_Handle) - 1 else ""
                )

                asset_file_data = os.read_entire_file(asset_file_path, context.temp_allocator) or_else panic("Failed.")

            }

            _ = os.write(file_handle, mem.any_to_bytes(i32(len(asset_file_data)))) or_else panic("Failed.")
            _ = os.write(file_handle,                          asset_file_data   ) or_else panic("Failed.")

        }

    }

}

load_global_asset_pack_file :: proc() {

    when ODIN_DEBUG { // Load the local asset pack file at run-time.

        GLOBAL_ASSET_PACK_FILE_DATA := os.read_entire_file(GLOBAL_ASSET_PACK_FILE_PATH, context.temp_allocator) or_else panic("Failed.")

    } else { // Bake the local asset pack file into the executable.

        @(static)
        @(rodata)
        GLOBAL_ASSET_PACK_FILE_DATA := #load(GLOBAL_ASSET_PACK_FILE_PATH)

    }

    remainder := GLOBAL_ASSET_PACK_FILE_DATA[:]
    unpack(&remainder, Global_Asset_Texture_Handle)
    unpack(&remainder, Global_Asset_Sound_Handle  )
    unpack(&remainder, Global_Asset_Font_Handle   )

    unpack :: proc(remainder : ^[]u8, $Global_Asset_XYZ_Handle : typeid) {

        for asset_handle in Global_Asset_XYZ_Handle {

            asset_size := eat(remainder, i32       )^
            asset_data := eat(remainder, asset_size)

            if asset_handle != nil {

                when Global_Asset_XYZ_Handle == Global_Asset_Texture_Handle {

                    image := raylib.LoadImageFromMemory(".png", raw_data(asset_data), asset_size)
                    defer raylib.UnloadImage(image)

                    GLOBAL_asset_textures[asset_handle] = raylib.LoadTextureFromImage(image)

                } else when Global_Asset_XYZ_Handle == Global_Asset_Sound_Handle {

                    wave := raylib.LoadWaveFromMemory(".wav", raw_data(asset_data), asset_size)
                    defer raylib.UnloadWave(wave)

                    GLOBAL_asset_sounds[asset_handle] = raylib.LoadSoundFromWave(wave)

                } else when Global_Asset_XYZ_Handle == Global_Asset_Font_Handle {

                    GLOBAL_asset_fonts[asset_handle] = raylib.LoadFontFromMemory(
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

}





////////////////////////////////////////////////////////////////////////////////

import "core:fmt"
import "core:os"
import "core:reflect"
import "core:mem"
import "vendor:raylib"
