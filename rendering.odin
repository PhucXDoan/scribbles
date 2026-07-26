package main

// This file contains the abstraction for describing things and getting things
// to be rendered onto the screen in a more convenient interface.

////////////////////////////////////////////////////////////////////////////////





Rendering_Task :: union {
    Rendering_Task_Texture,
    Rendering_Task_Text,
    Rendering_Task_Dialogue_Bubble,
    Rendering_Task_Rectangle,
}

Rendering_Task_Texture :: struct {
    reference  : Rendering_Texture_Reference,
    position   : Rendering_Vector2,
    dimensions : Rendering_Vector2,
    origin     : Rendering_Vector2_UV,
    rotation   : f32,
    tint       : Maybe(raylib.Color),
}

Rendering_Task_Text :: struct {
    text     : cstring,
    font     : Global_Asset_Font_Handle,
    position : Rendering_Vector2,
    origin   : Rendering_Vector2_UV,
    size     : f32,
    color    : Maybe(raylib.Color),
}

Rendering_Task_Dialogue_Bubble :: struct {
    text     : cstring,
    font     : Global_Asset_Font_Handle,
    position : Rendering_Vector2,
}

Rendering_Task_Rectangle :: struct {
    position          : Rendering_Vector2,
    dimensions        : Rendering_Vector2,
    origin            : Rendering_Vector2_UV,
    stroke            : Maybe(raylib.Color),
    fill              : Maybe(raylib.Color),
    roundness         : f32,
    outline_thickness : Maybe(f32),
}



Rendering_Texture_Reference :: union {
    Global_Asset_Texture_Handle,
    raylib.Texture,
}





////////////////////////////////////////////////////////////////////////////////





Rendering_Vector2_Cartesian :: distinct raylib.Vector2
Rendering_Vector2_UV        :: distinct raylib.Vector2
Rendering_Vector2_Screen    :: distinct raylib.Vector2
Rendering_Vector2           :: union {
    Rendering_Vector2_Cartesian,
    Rendering_Vector2_UV,
    Rendering_Vector2_Screen,
}



to_screen_for_position :: proc {
    to_screen_from_cartesian_for_position,
    to_screen_from_uv_for_position,
    to_screen_from_screen_for_position,
    to_screen_from_generic_for_position,
}

to_screen_from_cartesian_for_position :: proc(position : Rendering_Vector2_Cartesian) -> Rendering_Vector2_Screen {
    return {
        (f32(raylib.GetScreenWidth ()) + position.x * f32(raylib.GetScreenWidth())) / 2,
        (f32(raylib.GetScreenHeight()) - position.y * f32(raylib.GetScreenWidth())) / 2,
    }
}

to_screen_from_uv_for_position :: proc(position : Rendering_Vector2_UV) -> Rendering_Vector2_Screen {
    return {
        (f32(raylib.GetScreenWidth ()) + position.x * f32(raylib.GetScreenWidth ())) / 2,
        (f32(raylib.GetScreenHeight()) - position.y * f32(raylib.GetScreenHeight())) / 2,
    }
}

to_screen_from_screen_for_position :: proc(position : Rendering_Vector2_Screen) -> Rendering_Vector2_Screen {
    return {
        position.x,
        position.y,
    }
}

to_screen_from_generic_for_position :: proc(position : Rendering_Vector2) -> Rendering_Vector2_Screen {
    switch p in position {
        case Rendering_Vector2_Cartesian : return to_screen_from_cartesian_for_position(p)
        case Rendering_Vector2_UV        : return to_screen_from_uv_for_position(p)
        case Rendering_Vector2_Screen    : return to_screen_from_screen_for_position(p)
        case                             : panic("Invalid.")
    }
}



to_screen_for_dimensions :: proc {
    to_screen_from_cartesian_for_dimensions,
    to_screen_from_uv_for_dimensions,
    to_screen_from_screen_for_dimensions,
    to_screen_from_generic_for_dimensions,
}

to_screen_from_cartesian_for_dimensions :: proc(d : Rendering_Vector2_Cartesian) -> Rendering_Vector2_Screen {
    return {
        d.x * f32(raylib.GetScreenWidth()),
        d.y * f32(raylib.GetScreenWidth()),
    }
}

to_screen_from_uv_for_dimensions :: proc(d : Rendering_Vector2_UV) -> Rendering_Vector2_Screen {
    return {
        d.x * f32(raylib.GetScreenWidth ()),
        d.y * f32(raylib.GetScreenHeight()),
    }
}

to_screen_from_screen_for_dimensions :: proc(d : Rendering_Vector2_Screen) -> Rendering_Vector2_Screen {
    return {
        d.x,
        d.y,
    }
}

to_screen_from_generic_for_dimensions :: proc(dimensions : Rendering_Vector2) -> Rendering_Vector2_Screen {
    switch d in dimensions {
        case Rendering_Vector2_Cartesian : return to_screen_from_cartesian_for_dimensions(d)
        case Rendering_Vector2_UV        : return to_screen_from_uv_for_dimensions(d)
        case Rendering_Vector2_Screen    : return to_screen_from_screen_for_dimensions(d)
        case                             : panic("Invalid.")
    }
}



to_screen_for_rectangle :: proc(
    position   : Rendering_Vector2,
    dimensions : Rendering_Vector2,
    origin     : Rendering_Vector2_UV,
) -> raylib.Rectangle {

    screen_position   := to_screen_for_position(position)
    screen_dimensions := to_screen_for_dimensions(dimensions)

    return {
        screen_position.x + screen_dimensions.x * (-1 - origin.x) / 2,
        screen_position.y - screen_dimensions.y * (+1 - origin.y) / 2,
        screen_dimensions.x,
        screen_dimensions.y,
    }

}

to_screen_for_rectangle_uv :: proc(
    position   : Rendering_Vector2,
    dimensions : Rendering_Vector2,
    origin     : Rendering_Vector2_UV,
    uv         : Rendering_Vector2_UV,
) -> Rendering_Vector2_Screen {

    screen_position   := to_screen_for_position(position)
    screen_dimensions := to_screen_for_dimensions(dimensions)

    return {
        screen_position.x + screen_dimensions.x * (uv.x - origin.x) / 2,
        screen_position.y - screen_dimensions.y * (uv.y - origin.y) / 2,
    }

}





////////////////////////////////////////////////////////////////////////////////





render :: proc(rendering_tasks : []Rendering_Task) {

    for rendering_task in rendering_tasks {

        switch task in rendering_task {



            case Rendering_Task_Texture: {

                texture : raylib.Texture

                switch reference in task.reference {
                    case Global_Asset_Texture_Handle : texture = GLOBAL_asset_textures[reference]
                    case raylib.Texture              : texture = reference
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





////////////////////////////////////////////////////////////////////////////////

import "vendor:raylib"
