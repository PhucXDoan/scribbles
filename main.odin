package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:mem"
import "core:time"
import "vendor:raylib"

main :: proc() {





    ////////////////////////////////////////////////////////////////////////////////
    //
    // Basic Initializations.
    //
    ////////////////////////////////////////////////////////////////////////////////





    when ODIN_DEBUG {
        create_global_asset_pack_file()
    }

    raylib.SetTraceLogLevel(.WARNING)
    raylib.SetTargetFPS(60)
    raylib.SetConfigFlags({ .MSAA_4X_HINT })

    raylib.InitWindow(1200, 675, "scribbles")
    defer raylib.CloseWindow()

    raylib.InitAudioDevice()
    defer raylib.CloseAudioDevice()

    raylib.SetExitKey(nil)

    load_global_asset_pack_file()



    Scene :: enum {
        Main,
        Easel,
        Merowchant,
    }

    scene                                          := Scene.Main
    SAVE_FILE_PATH                                 :: "./scribbles.save"
    EASEL_DEFAULT_COLOR                            :: raylib.Color { 234, 240, 243, 255 }
    game_state                                     :  Game_State_V1
    easel_canvas_image                             :  raylib.Image
    easel_canvas_texture                           :  raylib.Texture
    easel_canvas_requirement_painted_pixel_minimum := 10
    easel_canvas_requirement_painted_pixel_maximum := 0
    merowchant_cat_hover_animation                 := Animation { duration = 0.1 }
    duration_since_last_game                       :  time.Duration

    entities := [dynamic; 16]Entity {
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

    merowchant_back_button := Button_Widget {

        position = Rendering_Vector2_UV { -0.9, -0.9 },

        style = Button_Widget_Style_Lame {
            text = "Back",
            font = .Sniglet,
            size = 30,
        },

        mouse_hover_tint = raylib.GREEN,

    }

    easel_canvas_back_button := Button_Widget {

        position = Rendering_Vector2_UV { -0.15, -0.7 },

        style = Button_Widget_Style_Lame {
            text = "Back",
            font = .Sniglet,
            size = 30,
        },

        mouse_hover_tint = raylib.GREEN,

    }

    easel_canvas_submit_button := Button_Widget {

        position = Rendering_Vector2_UV { 0.15, -0.7 },

        style = Button_Widget_Style_Texture {
            dimensions = Rendering_Vector2_Cartesian { 0.075, 0.035 },
            reference  = .Submit_Button,
        },

        mouse_hover_tint = raylib.GREEN,

    }

    create_flimsy_friend :: proc(
        entities : ^[dynamic; 16]Entity,
        image    : raylib.Image,
        age      : time.Duration,
        position : Maybe(World_Vector2),
    ) {
        push(entities, Entity {
            kind          = .Flimsy_Friend,
            base_position = position.? or_else {
                -5 + f32(len(entities)) * 1,
                -4,
            },
            origin                = { 0, -1 },
            base_dimensions       = { 0.5, 0.5 },
            texture_reference     = raylib.LoadTextureFromImage(image),
            mouse_hover_animation = { duration = 0.1                                           },
            mouse_click_animation = { duration = 0.1                                           },
            walk_animation        = { duration = FLIMSY_FRIEND_WALK_ANIMATION_DURATION_SECONDS },
            age                   = age,
        })
    }





    ////////////////////////////////////////////////////////////////////////////////
    //
    // Local Save File Format and Loading.
    //
    ////////////////////////////////////////////////////////////////////////////////





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

    Game_State_V1 :: struct #packed {
        pets                     : u128,
        SAVE_easel_unlocked      : b8,
        SAVE_timestamp           : Maybe(time.Time),
        SAVE_merowchant_unlocked : b8,
    }



    // Load local save file.

    {

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

    }



    // Determine passage of time.

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





    for {





        ////////////////////////////////////////////////////////////////////////////////
        //
        // Game Saving.
        //
        ////////////////////////////////////////////////////////////////////////////////





        @(static)
        should_save_game  := true // Always save the game on start up.
        should_close      := raylib.WindowShouldClose()
        should_save_game ||= should_close || time.diff(game_state.SAVE_timestamp.? or_else {}, time.now()) >= 60 * time.Second

        if should_save_game {

            should_save_game = false

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

                body : Game_State_Vx = game_state

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
        //
        // Miscellaneous.
        //
        ////////////////////////////////////////////////////////////////////////////////





        if should_close {
            break
        }

        mouse_position := raylib.GetMousePosition()

        rendering_tasks : [dynamic; 32]Rendering_Task





        ////////////////////////////////////////////////////////////////////////////////
        //
        // Entity Update.
        //
        ////////////////////////////////////////////////////////////////////////////////





        to_be_removed_entities :  [dynamic; cap(entities)]int
        new_pets_for_rolypoly  := u128(0)

        for &entity, entity_i in entities {

            if entity_i == 0 {
                continue // Skip the nil entity.
            }

            should_be_removed := false



            // Determine rendering dimensions.

            {

                rendering_dimensions := Rendering_Vector2_Cartesian {
                    entity.base_dimensions.x * 0.1 / 2,
                    entity.base_dimensions.y * 0.1 / 2,
                }

                if !entity.locked {

                    rendering_dimensions.x *= ease_animation(1, 1.025, entity.mouse_hover_animation, .Cubic_Out)
                    rendering_dimensions.y *= ease_animation(1, 1.025, entity.mouse_hover_animation, .Cubic_Out)

                    if entity.mouse_click_animation.running {
                        rendering_dimensions.x /= ease_animation(1.2, 1, entity.mouse_click_animation, .Quartic_Out)
                        rendering_dimensions.y *= ease_animation(1.2, 1, entity.mouse_click_animation, .Cubic_Out  )
                    }

                }

                if entity.walk_animation.running {
                    rendering_dimensions.x /= 1 + 0.5 * math.sin(ease_animation(0, math.PI, entity.walk_animation, .Quartic_In_Out))
                    rendering_dimensions.y *= 1 + 0.2 * math.sin(ease_animation(0, math.PI, entity.walk_animation, .Quartic_In_Out))
                }

                if entity.death_animation.running {
                    rendering_dimensions.x *= ease_animation(1, 2, entity.death_animation, .Quartic_In)
                    rendering_dimensions.y *= ease_animation(1, 2, entity.death_animation, .Quartic_In)
                }

                entity.rendering_dimensions = rendering_dimensions

            }



            // Determine rendering position.

            {

                rendering_position := Rendering_Vector2_Cartesian {
                    entity.base_position.x * 0.1,
                    entity.base_position.y * 0.1,
                }

                if entity.walk_animation.running {

                    destination := World_Vector2 {
                        (entity.base_position.x + entity.walk_displacement.x) * 0.1,
                        ((entity.base_position.y + entity.walk_displacement.y) + 0.5 * math.pow(math.sin(entity.walk_animation.value * math.PI), 8)) * 0.1,
                    }

                    rendering_position.x = ease_animation(rendering_position.x, destination.x, entity.walk_animation, .Quartic_In_Out)
                    rendering_position.y = ease_animation(rendering_position.y, destination.y, entity.walk_animation, .Quartic_In_Out)

                }

                entity.rendering_position = rendering_position

            }



            // With the rendering position and dimensions determined,
            // we know the screen bounding box of the entity.

            bounding_box := to_screen_for_rectangle(
                entity.rendering_position,
                entity.rendering_dimensions,
                entity.origin,
            )



            // Handle aging.

            entity.age += time.Duration(raylib.GetFrameTime() * f32(time.Second))

            #partial switch entity.kind {



                case .Flimsy_Friend: {

                    if entity.age > FLIMSY_FRIEND_LIFESPAN {
                        entity.death_animation.duration = 0.5 + 0.4 * f32(rand.int31_max(10))
                        control_animation(&entity.death_animation, .Increase_Stop)
                    }

                }



            }

            update_animation(&entity.death_animation)

            if entity.death_animation.value == 1 {
                raylib.PlaySound(GLOBAL_asset_sounds[.Pop])
                should_be_removed = true
            }



            // Handle walking.

            #partial switch entity.kind {



                case .Flimsy_Friend: {

                    if !entity.walk_animation.running && entity.walk_displacement == {} && entity.walk_delay <= 0 {

                        entity.walk_displacement = 0.5 * World_Vector2(raylib.Vector2Normalize({
                            entities[Entity_Kind.Rolypoly].base_position.x + f32(math.cos(time.duration_minutes(entity.age))) * 4 - entity.base_position.x,
                            entities[Entity_Kind.Rolypoly].base_position.y + f32(math.sin(time.duration_minutes(entity.age))) * 4 - entity.base_position.y,
                        }))

                        entity.walk_delay = FLIMSY_FRIEND_EXPECTED_WALK_DELAY_SECONDS * 2 * rand.float32()

                    }

                    if entity.walk_delay > 0 && !entity.death_animation.running {
                        entity.walk_delay -= raylib.GetFrameTime()
                        entity.walk_delay  = max(entity.walk_delay, 0)
                    }

                    if !entity.walk_animation.running && entity.walk_displacement != {} && entity.walk_delay <= 0 {

                        control_animation(&entity.walk_animation, .Clear_Increase_Reset)

                        if scene == .Main {

                            #partial switch entity.kind {



                                case .Flimsy_Friend: {

                                    paper_sound_handle := Global_Asset_Sound_Handle(
                                        i32(Global_Asset_Sound_Handle.Paper_0) +
                                        rand.int31_max(GLOBAL_ASSET_SOUND_PAPER_COUNT)
                                    )

                                    raylib.PlaySound(GLOBAL_asset_sounds[paper_sound_handle])

                                }



                            }

                        }

                    }

                    update_animation(&entity.walk_animation)

                    if !entity.walk_animation.running && entity.walk_displacement != {} && entity.walk_delay <= 0 {

                        entity.base_position.x   += entity.walk_displacement.x
                        entity.base_position.y   += entity.walk_displacement.y
                        entity.walk_displacement  = {}
                        new_pets_for_rolypoly    += 1

                    }

                }



            }



            // Handle mouse hovering.

            entity.mouse_hovering = scene == .Main && raylib.CheckCollisionPointRec(raylib.GetMousePosition(), bounding_box)

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
                    !raylib.IsSoundPlaying(GLOBAL_asset_sounds[.Padlock])
                ) {
                    raylib.PlaySound(GLOBAL_asset_sounds[.Padlock])
                }

                if entity.mouse_hover_animation.value == 1 {

                    push(&rendering_tasks, Rendering_Task_Dialogue_Bubble {
                        text = (
                            game_state.pets < entity.pet_cost
                                ? fmt.ctprintf("I need {} pets...", entity.pet_cost)
                                : fmt.ctprintf("Unlock for {} pets...?", entity.pet_cost)
                        ),
                        font     = .Sniglet,
                        position =  Rendering_Vector2_Screen(to_screen_for_rectangle_uv(
                            entities[Entity_Kind.Rolypoly].rendering_position,
                            entities[Entity_Kind.Rolypoly].rendering_dimensions,
                            entities[Entity_Kind.Rolypoly].origin,
                            { 0.75, 0.75 },
                        )),
                    })

                }

            }

            #partial switch entity.kind {



                case .Rolypoly: {
                    raylib.SetMouseCursor(raylib.MouseCursor.POINTING_HAND if entity.mouse_hovering else raylib.MouseCursor.DEFAULT)
                }



            }



            // Handle mouse clicking.

            entity.mouse_clicked = scene == .Main && entity.mouse_hovering && raylib.IsMouseButtonPressed(.LEFT)

            if entity.mouse_clicked {

                control_animation(&entity.mouse_click_animation, .Clear_Increase_Reset)

                entity.click_count += 1

                if entity.locked {

                    if entity.lock_hover_animation.value < 1 {

                        // Player needs to hover over the padlock for longer before we do any click action.

                    } else if game_state.pets < entity.pet_cost {

                        control_animation(&entity.lock_hover_animation, .Clear_Increase_Reset)
                        raylib.PlaySound(GLOBAL_asset_sounds[.Padlock_Locked])

                    } else {

                        game_state.pets -= entity.pet_cost
                        entity.locked    = false
                        raylib.PlaySound(GLOBAL_asset_sounds[.Padlock_Unlocked])

                    }

                } else {

                    #partial switch entity.kind {



                        case .Rolypoly: {
                            new_pets_for_rolypoly += 1
                        }



                        case .Easel: {
                            scene = .Easel
                            raylib.PlaySound(GLOBAL_asset_sounds[.Easel_Open])
                        }



                        case .Merowchant: {
                            scene = .Merowchant
                            raylib.PlaySound(GLOBAL_asset_sounds[.Merowchant_Open])
                        }



                        case .Flimsy_Friend: {

                            if entity.click_count < FLIMSY_FRIEND_CLICKS_TO_POP {

                                raylib.PlaySound(GLOBAL_asset_sounds[.Tap])

                            } else {

                                raylib.PlaySound(GLOBAL_asset_sounds[.Pop])
                                should_be_removed = true

                            }

                        }

                    }

                }

            }

            update_animation(&entity.mouse_click_animation)



            // Mark the entity to be deleted if needed.

            if should_be_removed {
                push(&to_be_removed_entities, entity_i)
            }



            // Create rendering tasks for the entity if it's still around.

            if !should_be_removed && scene == .Main {

                push(&rendering_tasks, Rendering_Task_Texture {
                    reference  = entity.texture_reference,
                    position   = entity.rendering_position,
                    dimensions = entity.rendering_dimensions,
                    origin     = entity.origin,
                    tint       = raylib.GRAY if entity.locked else nil,
                })

                if entity.locked {

                    push(&rendering_tasks, Rendering_Task_Texture {
                        reference  = .Padlock,
                        position   = Rendering_Vector2_Screen(to_screen_for_rectangle_uv(
                            entity.rendering_position,
                            entity.rendering_dimensions,
                            entity.origin,
                            { 0, 0 },
                        )),
                        dimensions = Rendering_Vector2_Cartesian {
                            ease_animation(0.05, 0.06, entity.lock_hover_animation, .Bounce_Out),
                            ease_animation(0.05, 0.06, entity.lock_hover_animation, .Bounce_Out),
                        },
                        rotation = (
                            math.sin(ease_animation(0, 6, entity.lock_hover_animation , .Cubic_Out)) * 10 +
                            math.sin(ease_animation(0, 6, entity.mouse_click_animation, .Cubic_Out)) * 10
                        ),
                    })

                }

            }

        }



        // We get rid of entities in the reverse order that they were marked to be removed.
        // This is to make it so the indices do not have to be updated because things are moved around.

        #reverse for entity_index in to_be_removed_entities {

            entity := &entities[entity_index]

            #partial switch entity.kind {

                case .Flimsy_Friend: {
                    raylib.UnloadTexture(entity.texture_reference.(raylib.Texture))
                }

            }

            unordered_remove(&entities, entity_index)

        }



        // Handle new pets done to the Rolypoly.

        if new_pets_for_rolypoly >= 1 {

            game_state.pets += new_pets_for_rolypoly

            control_animation(&entities[Entity_Kind.Rolypoly].mouse_click_animation, .Clear_Increase_Reset)

            if scene == .Main {

                @(static) time_since_last_pet_sound_effect : time.Time

                xylo_sound_handle := Global_Asset_Sound_Handle(
                    i32(Global_Asset_Sound_Handle.Xylo_0) +
                    rand.int31_max(GLOBAL_ASSET_SOUND_XYLO_COUNT)
                )

                raylib.SetSoundVolume(
                    GLOBAL_asset_sounds[xylo_sound_handle],
                    f32(clamp(time.duration_seconds(time.diff(time_since_last_pet_sound_effect, time.now())) * 2, 0, 1))
                )

                raylib.PlaySound(GLOBAL_asset_sounds[xylo_sound_handle])

                time_since_last_pet_sound_effect = time.now()

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



        if scene == .Easel {

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



        easel_canvas_back_button.hidden = scene != .Easel
        update_button_widget(&easel_canvas_back_button)



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

        for entity in entities {
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



        easel_canvas_submit_button.hidden = scene != .Easel

        update_button_widget(&easel_canvas_submit_button)

        if easel_canvas_submit_button.pressed {

            create_flimsy_friend(
                entities = &entities,
                image    = easel_canvas_image,
                age      = 0,
                position = nil,
            )

            raylib.ImageClearBackground(&easel_canvas_image, EASEL_DEFAULT_COLOR)

            scene = .Main
            raylib.PlaySound(GLOBAL_asset_sounds[.Easel_Close])

        }





        ////////////////////////////////////////////////////////////////////////////////
        //
        // Update Merowchant.
        //

        merowchant_cat_position   := raylib.Vector2 { 750, 475 }
        merowchant_cat_dimensions := raylib.Vector2 { 300, 350 }
        merowchant_cat_dimensions.x *= ease_animation(1, 1.1, merowchant_cat_hover_animation, .Quadratic_Out)
        merowchant_cat_dimensions.y *= ease_animation(1, 1.1, merowchant_cat_hover_animation, .Quadratic_Out)

        merowchant_cat_origin     := raylib.Vector2 { merowchant_cat_dimensions.x * 0.5, merowchant_cat_dimensions.y * 1 }

        hovering_merowchant_cat := scene == .Merowchant && raylib.CheckCollisionPointRec(
            raylib.GetMousePosition(),
            {
                merowchant_cat_position.x - merowchant_cat_origin.x,
                merowchant_cat_position.y - merowchant_cat_origin.y,
                merowchant_cat_dimensions.x,
                merowchant_cat_dimensions.y,
            },
        )

        control_animation(
            &merowchant_cat_hover_animation,
            .Increase_Stop if hovering_merowchant_cat else .Decrease_Stop
        )

        update_animation(&merowchant_cat_hover_animation)

        if scene == .Merowchant {

            if hovering_merowchant_cat {

                push(&rendering_tasks, Rendering_Task_Dialogue_Bubble {
                    text     = "i dont have anything right now...",
                    font     = .Sniglet,
                    position = Rendering_Vector2_Screen {
                        merowchant_cat_position.x,
                        merowchant_cat_position.y - merowchant_cat_dimensions.y * 0.9,
                    },
                })

            }

            if hovering_merowchant_cat && raylib.IsMouseButtonPressed(.LEFT) {
                raylib.PlaySound(GLOBAL_asset_sounds[.Merowchant_Meow])
            }

        }

        merowchant_back_button.hidden = scene != .Merowchant
        update_button_widget(&merowchant_back_button)





        ////////////////////////////////////////////////////////////////////////////////
        //
        // TODO.
        //

        if easel_canvas_back_button.pressed || (scene == .Easel && raylib.IsKeyPressed(.ESCAPE)) {
            scene = .Main
            raylib.PlaySound(GLOBAL_asset_sounds[.Easel_Close])
        }

        if merowchant_back_button.pressed || (scene == .Merowchant && raylib.IsKeyPressed(.ESCAPE)) {
            scene = .Main
            raylib.PlaySound(GLOBAL_asset_sounds[.Merowchant_Close])
        }





        ////////////////////////////////////////////////////////////////////////////////
        //
        // Display version info.
        //

        push(&rendering_tasks, Rendering_Task_Text {
            text     = fmt.ctprintf("Pets: {}", game_state.pets),
            font     = .Sniglet,
            position = Rendering_Vector2_UV { -0.975, 0.975 },
            origin   = { -1, 1 },
            size     = 40,
        })

        push(&rendering_tasks, Rendering_Task_Text {
            text     = #config(VERSION, "???"),
            font     = .Sniglet,
            position = Rendering_Vector2_UV { 1, 1 },
            origin   = { 1, 1 },
            size     = 20,
        })



        ////////////////////////////////////////////////////////////////////////////////
        //
        // Render.
        //

        {

            raylib.BeginDrawing()
            defer raylib.EndDrawing()

            raylib.ClearBackground(raylib.BROWN if scene == .Easel else raylib.DARKGRAY)










            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render easel canvas.
            //

            if scene == .Easel {

                push(&rendering_tasks, Rendering_Task_Texture {
                    reference  = easel_canvas_texture,
                    position   = Rendering_Vector2_Screen { easel_canvas_dest.x, easel_canvas_dest.y }, // TODO.
                    dimensions = Rendering_Vector2_Screen { easel_canvas_dest.width, easel_canvas_dest.height }, // TODO.
                })

                if hovered_easel_canvas_cell_is_within {

                    push(&rendering_tasks, Rendering_Task_Rectangle {
                        position = Rendering_Vector2_Screen { // TODO.
                            (easel_canvas_dest.x - easel_canvas_origin.x + f32(hovered_easel_canvas_cell_coordinate_x) * easel_canvas_cell_dimensions.x),
                            (easel_canvas_dest.y - easel_canvas_origin.y + f32(hovered_easel_canvas_cell_coordinate_y) * easel_canvas_cell_dimensions.y),
                        },
                        dimensions = Rendering_Vector2_Screen(easel_canvas_cell_dimensions),
                        origin     = { -1, 1 }, // TODO.
                    })

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

                    push(&rendering_tasks, Rendering_Task_Text {
                        text       = requirement_text,
                        font       = .Sniglet,
                        position   = Rendering_Vector2_UV { -0.9, 0.5 },
                        origin     = { -1, 1 },
                        size       = 30,
                    })

                }

            }



            render_button_widget(&rendering_tasks, &easel_canvas_back_button  )
            render_button_widget(&rendering_tasks, &easel_canvas_submit_button)
            render_button_widget(&rendering_tasks, &merowchant_back_button    )



            ////////////////////////////////////////////////////////////////////////////////
            //
            // Render Merowchant.
            //

            if scene == .Merowchant {

                MEROWCHANT_TABLE_Y :: 400

                raylib.DrawTexturePro(
                    texture = GLOBAL_asset_textures[.Merowchant_Background],
                    source  = {
                        0,
                        0,
                        cast(f32) GLOBAL_asset_textures[.Merowchant_Background].width,
                        cast(f32) GLOBAL_asset_textures[.Merowchant_Background].height,
                    },
                    dest = {
                        0,
                        0,
                        f32(raylib.GetScreenWidth()),
                        MEROWCHANT_TABLE_Y + 100,
                    },
                    origin   = { 0, 0 },
                    rotation = 0,
                    tint     = raylib.WHITE,
                )

                raylib.DrawTexturePro(
                    texture = GLOBAL_asset_textures[.Merowchant_Cat],
                    source  = {
                        0,
                        0,
                        cast(f32) GLOBAL_asset_textures[.Merowchant_Cat].width,
                        cast(f32) GLOBAL_asset_textures[.Merowchant_Cat].height,
                    },
                    dest = {
                        merowchant_cat_position.x,
                        merowchant_cat_position.y,
                        merowchant_cat_dimensions.x,
                        merowchant_cat_dimensions.y,
                    },
                    origin   = merowchant_cat_origin,
                    rotation = 0,
                    tint     = raylib.WHITE,
                )

                raylib.DrawTexturePro(
                    texture = GLOBAL_asset_textures[.Merowchant_Table],
                    source  = {
                        0,
                        0,
                        cast(f32) GLOBAL_asset_textures[.Merowchant_Table].width,
                        cast(f32) GLOBAL_asset_textures[.Merowchant_Table].height,
                    },
                    dest = {
                        0,
                        MEROWCHANT_TABLE_Y,
                        f32(raylib.GetScreenWidth()),
                        f32(raylib.GetScreenHeight()) - MEROWCHANT_TABLE_Y,
                    },
                    origin   = { 0, 0 },
                    rotation = 0,
                    tint     = raylib.WHITE,
                )

            }





            ////////////////////////////////////////////////////////////////////////////////
            //
            // Handle rendering tasks.
            //

            for rendering_task in rendering_tasks {

                switch task in rendering_task {



                    case Rendering_Task_Texture: {

                        texture : raylib.Texture

                        switch r in task.reference {
                            case Global_Asset_Texture_Handle : texture = GLOBAL_asset_textures[r]
                            case raylib.Texture              : texture = r
                            case                             : panic("Invalid.")
                        }

                        dest := to_screen_for_rectangle(
                            task.position,
                            task.dimensions,
                            { -1, +1 } // To account for `origin` argument of `raylib.DrawTexturePro`.
                        )

                        raylib.DrawTexturePro(
                            texture  = texture,
                            source   = { 0, 0, f32(texture.width), f32(texture.height) },
                            dest     = dest,
                            origin   = {
                                (1 + task.origin.x) / 2 * dest.width,
                                (1 - task.origin.y) / 2 * dest.height,
                            },
                            rotation = task.rotation,
                            tint     = task.tint.? or_else raylib.WHITE,
                        )

                    }



                    case Rendering_Task_Text: {

                        screen_dimensions := raylib.MeasureTextEx(
                            font     = GLOBAL_asset_fonts[task.font],
                            text     = task.text,
                            fontSize = task.size,
                            spacing  = 0,
                        )

                        rectangle := to_screen_for_rectangle(
                            position   = task.position,
                            dimensions = Rendering_Vector2_Screen(screen_dimensions),
                            origin     = task.origin,
                        )

                        raylib.DrawTextEx(
                            font     = GLOBAL_asset_fonts[task.font],
                            text     = task.text,
                            position = { rectangle.x, rectangle.y },
                            fontSize = task.size,
                            spacing  = 0,
                            tint     = task.color.? or_else raylib.WHITE,
                        )

                    }



                    case Rendering_Task_Dialogue_Bubble: { // TODO Rework.

                        DIALOGUE_BUBBLE_FONT_SIZE :: 30
                        DIALOGUE_BUBBLE_PADDING   :: 15
                        DIALOGUE_BUBBLE_ROUNDNESS :: 0.3
                        DIALOGUE_BUBBLE_OUTLINE   :: 4

                        position := to_screen_for_position(task.position)

                        measurement := raylib.MeasureTextEx(
                            font     = GLOBAL_asset_fonts[task.font],
                            text     = task.text,
                            fontSize = DIALOGUE_BUBBLE_FONT_SIZE,
                            spacing  = 0,
                        )

                        bubble_rec := raylib.Rectangle {
                            position.x - DIALOGUE_BUBBLE_PADDING / 2,
                            position.y - DIALOGUE_BUBBLE_PADDING * 3 - measurement.y,
                            measurement.x + DIALOGUE_BUBBLE_PADDING * 2,
                            measurement.y + DIALOGUE_BUBBLE_PADDING * 2,
                        }

                        vertices := [?][2]f32 {
                            { position.x, bubble_rec.y + bubble_rec.height },
                            { position.x, position.y },
                            { position.x + (position.x - bubble_rec.x) * 2, bubble_rec.y + bubble_rec.height },
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
                            font     = GLOBAL_asset_fonts[task.font],
                            text     = task.text,
                            position = {
                                bubble_rec.x + DIALOGUE_BUBBLE_PADDING,
                                bubble_rec.y + DIALOGUE_BUBBLE_PADDING,
                            },
                            fontSize = DIALOGUE_BUBBLE_FONT_SIZE,
                            spacing  = 0,
                            tint     = raylib.BLACK,
                        )

                    }



                    case Rendering_Task_Rectangle: {

                        rec := to_screen_for_rectangle(
                            task.position,
                            task.dimensions,
                            task.origin,
                        )

                        raylib.DrawRectangleRounded(
                            rec       = rec,
                            roundness = task.roundness,
                            segments  = 0,
                            color     = task.fill.? or_else {},
                        )

                        raylib.DrawRectangleRoundedLinesEx(
                            rec       = rec,
                            roundness = task.roundness,
                            segments  = 0,
                            lineThick = task.outline_thickness.? or_else 1,
                            color     = task.stroke.? or_else raylib.BLACK,
                        )

                    }



                    case: panic("Invalid.")

                }

            }

        }





        free_all(context.temp_allocator)

    }

}









////////////////////////////////////////////////////////////////////////////////
//
// Button Widgets.
//

Button_Widget :: struct {

    style : union {
        Button_Widget_Style_Lame,
        Button_Widget_Style_Texture,
    },

    position         : Rendering_Vector2,
    mouse_hover_tint : raylib.Color,
    disabled         : bool,
    hidden           : bool,

    mouse_hovering   : bool,
    pressed          : bool,

}

BUTTON_WIDGET_STYLE_LAME_ROUNDNESS :: 0.2
BUTTON_WIDGET_STYLE_LAME_OUTLINE   :: 4
BUTTON_WIDGET_STYLE_LAME_PADDING   :: 4
Button_Widget_Style_Lame           :: struct {
    text : cstring,
    font : Global_Asset_Font_Handle,
    size : f32,
}

Button_Widget_Style_Texture :: struct {
    dimensions : Rendering_Vector2,
    reference  : Rendering_Texture_Reference,
}

update_button_widget :: proc(button : ^Button_Widget) {

    button.mouse_hovering = !button.hidden && raylib.CheckCollisionPointRec(
        raylib.GetMousePosition(),
        screen_bounding_box_for_button_widget(button^),
    )

    button.pressed = (
        !button.disabled &&
        button.mouse_hovering &&
        raylib.IsMouseButtonPressed(.LEFT)
    )

}

render_button_widget :: proc(
    rendering_tasks : ^[dynamic; 32]Rendering_Task,
    button          : ^Button_Widget,
) {

    if button.hidden {
        return
    }

    tint : raylib.Color
    switch {
        case button.disabled       : tint = raylib.DARKGRAY
        case button.mouse_hovering : tint = button.mouse_hover_tint
        case                       : tint = raylib.WHITE
    }

    bounding_box := screen_bounding_box_for_button_widget(button^)

    switch style in button.style {

        case Button_Widget_Style_Lame: {

            push(rendering_tasks, Rendering_Task_Rectangle {
                position          = Rendering_Vector2_Screen { bounding_box.x    , bounding_box.y      },
                dimensions        = Rendering_Vector2_Screen { bounding_box.width, bounding_box.height },
                origin            = { -1, 1 },
                fill              = tint,
                roundness         = BUTTON_WIDGET_STYLE_LAME_ROUNDNESS,
                outline_thickness = BUTTON_WIDGET_STYLE_LAME_OUTLINE,
            })

            push(rendering_tasks, Rendering_Task_Text {
                position = button.position,
                text     = style.text,
                font     = style.font,
                size     = style.size,
                color    = raylib.BLACK,
            })

        }

        case Button_Widget_Style_Texture: {

            push(rendering_tasks, Rendering_Task_Texture {
                reference  = style.reference,
                position   = Rendering_Vector2_Screen { bounding_box.x    , bounding_box.y      },
                dimensions = Rendering_Vector2_Screen { bounding_box.width, bounding_box.height },
                origin     = { -1, 1 },
                tint       = tint,
            })

        }

        case: panic("Invalid.")

    }

}

screen_bounding_box_for_button_widget :: proc(button : Button_Widget) -> raylib.Rectangle {

    position := to_screen_for_position(button.position)

    switch style in button.style {

        case Button_Widget_Style_Lame: {

            measurement := raylib.MeasureTextEx(
                font     = GLOBAL_asset_fonts[style.font],
                text     = style.text,
                fontSize = style.size,
                spacing  = 0,
            )

            return {
                position.x - measurement.x / 2 - BUTTON_WIDGET_STYLE_LAME_PADDING,
                position.y - measurement.y / 2 - BUTTON_WIDGET_STYLE_LAME_PADDING,
                measurement.x + BUTTON_WIDGET_STYLE_LAME_PADDING * 2,
                measurement.y + BUTTON_WIDGET_STYLE_LAME_PADDING * 2,
            }

        }

        case Button_Widget_Style_Texture: {

            return to_screen_for_rectangle(
                position   = button.position,
                dimensions = style.dimensions,
                origin     = { 0, 0 },
            )

        }

        case: panic("Invalid.")

    }

}





////////////////////////////////////////////////////////////////////////////////
//
// Entities.
//

Entity :: struct {

    kind                  : Entity_Kind,
    base_position         : World_Vector2,
    origin                : Rendering_Vector2_UV,
    base_dimensions       : World_Vector2,
    texture_reference     : Rendering_Texture_Reference,
    mouse_hover_animation : Animation,
    lock_hover_animation  : Animation,
    mouse_click_animation : Animation,
    death_animation       : Animation,
    walk_animation        : Animation,
    walk_displacement     : World_Vector2,
    walk_delay            : f32,
    locked                : bool,
    age                   : time.Duration,
    pet_cost              : u128,

    mouse_hovering        : bool,
    mouse_clicked         : bool,
    click_count           : int,

    rendering_position    : Rendering_Vector2,
    rendering_dimensions  : Rendering_Vector2,

}

Entity_Kind :: enum {

    nil,

    // These entities are fixed; they are spawned at initialization
    // and should never be removed. They can be directly indexed for.
    Rolypoly,
    Easel,
    Merowchant,

    // These entities are volatile; they can spawn and despawn at any time.
    Flimsy_Friend,

}

FLIMSY_FRIEND_CLICKS_TO_POP                   :: 5
FLIMSY_FRIEND_LIFESPAN                        :: 3 * time.Hour
FLIMSY_FRIEND_WALK_ANIMATION_DURATION_SECONDS :: 0.5
FLIMSY_FRIEND_EXPECTED_WALK_DELAY_SECONDS     :: 2.5
FLIMSY_FRIEND_EXPECTED_PETS_PER_SECOND        :: 1 / (FLIMSY_FRIEND_EXPECTED_WALK_DELAY_SECONDS + FLIMSY_FRIEND_WALK_ANIMATION_DURATION_SECONDS)

World_Vector2 :: distinct raylib.Vector2
