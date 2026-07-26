package main

import "core:fmt"
import "core:os"
import "core:reflect"
import "core:mem"
import "vendor:raylib"





////////////////////////////////////////////////////////////////////////////////
//
// Global Assets.
//
// These are game assets that are baked into the executable and are always
// accessible. For debug builds, we pack the assets and export it into a file,
// and in the release builds we load that file at compile-time to be embedded
// into the executable. This is to make the game be just a single executable
// without any other dependencies besides the optional save file.
//
// TODO Simplify the packed asset file format.
//

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

    Xylo_0, // Group: "GLOBAL_ASSET_SOUND_XYLO_COUNT".
    Xylo_1, // "
    Xylo_2, // "

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

GLOBAL_asset_textures : [Global_Asset_Texture_Handle]raylib.Texture
GLOBAL_asset_sounds   : [Global_Asset_Sound_Handle  ]raylib.Sound
GLOBAL_asset_fonts    : [Global_Asset_Font_Handle   ]raylib.Font



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

pack_global_assets :: proc() {

    GLOBAL_asset_pack_file_handle := os.open(GLOBAL_ASSET_PACK_FILE_PATH, os.O_CREATE | os.O_TRUNC | os.O_APPEND) or_else panic("Failed.")
    defer os.close(GLOBAL_asset_pack_file_handle)

    pack_asset_type(Global_Asset_Texture_Handle, Global_Asset_Pack_Texture_Header, GLOBAL_asset_pack_file_handle)
    pack_asset_type(Global_Asset_Sound_Handle  , Global_Asset_Pack_Sound_Header  , GLOBAL_asset_pack_file_handle)
    pack_asset_type(Global_Asset_Font_Handle   , Global_Asset_Pack_Font_Header   , GLOBAL_asset_pack_file_handle)

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

}



load_global_assets :: proc() {

    when ODIN_DEBUG {

        // Load the local asset pack file.
        remaining_global_asset_pack_data := os.read_entire_file(GLOBAL_ASSET_PACK_FILE_PATH, context.temp_allocator) or_else panic("Failed.")

    } else {

        // Bake the local asset pack file into the executable.
        @(static)
        remaining_global_asset_pack_data := #load(GLOBAL_ASSET_PACK_FILE_PATH)

    }

    for len(remaining_global_asset_pack_data) >= 1 {

        GLOBAL_asset_pack_header := eat(&remaining_global_asset_pack_data, Global_Asset_Pack_Header)

        switch header in GLOBAL_asset_pack_header {



            // Load global textures.

            case Global_Asset_Pack_Texture_Header: {

                image_data := eat(&remaining_global_asset_pack_data, int(header.length))

                GLOBAL_asset_image := raylib.LoadImageFromMemory(".png", raw_data(image_data), i32(len(image_data)))
                defer raylib.UnloadImage(GLOBAL_asset_image)

                assert(header.handle != nil)
                assert(int(header.handle) < len(GLOBAL_asset_textures))
                assert(GLOBAL_asset_textures[header.handle] == {})

                GLOBAL_asset_textures[header.handle] = raylib.LoadTextureFromImage(GLOBAL_asset_image)

            }



            // Load global sounds.

            case Global_Asset_Pack_Sound_Header: {

                sound_data := eat(&remaining_global_asset_pack_data, int(header.length))

                GLOBAL_asset_wave := raylib.LoadWaveFromMemory(".wav", raw_data(sound_data), i32(len(sound_data)))
                defer raylib.UnloadWave(GLOBAL_asset_wave)

                assert(header.handle != nil)
                assert(int(header.handle) < len(GLOBAL_asset_sounds))
                assert(GLOBAL_asset_sounds[header.handle] == {})

                GLOBAL_asset_sounds[header.handle] = raylib.LoadSoundFromWave(GLOBAL_asset_wave)

            }



            // Load global fonts.

            case Global_Asset_Pack_Font_Header: {

                font_data := eat(&remaining_global_asset_pack_data, int(header.length))

                assert(header.handle != nil)
                assert(int(header.handle) < len(GLOBAL_asset_fonts))
                assert(GLOBAL_asset_fonts[header.handle] == {})

                GLOBAL_asset_fonts[header.handle] = raylib.LoadFontFromMemory(
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
