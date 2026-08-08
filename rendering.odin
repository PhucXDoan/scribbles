package main

// This file contains the abstraction for describing things and getting things
// to be rendered onto the screen in a more convenient interface.

////////////////////////////////////////////////////////////////////////////////





Rendering_Task :: union {
    Rendering_Task_Texture,
    Rendering_Task_Text,
    Rendering_Task_Dialogue_Bubble,
    Rendering_Task_Rectangle,
    Rendering_Task_Line,
}

Rendering_Task_Texture :: struct {
    reference  : Rendering_Texture_Reference,
    position   : op.V2_Render,
    dimensions : op.V2_Render,
    origin     : op.V2_Uniform,
    rotation   : f32,
    tint       : Maybe(raylib.Color),
}

Rendering_Task_Text :: struct {
    text                                : cstring,
    font                                : Baked_Font,
    position                            : op.V2_Render,
    origin                              : op.V2_Uniform,
    size                                : f32,
    color                               : Maybe(raylib.Color),
    adjust_position_to_be_within_screen : bool,
}

Rendering_Task_Dialogue_Bubble :: struct {
    text     : cstring,
    font     : Baked_Font,
    position : op.V2_Render,
}

Rendering_Task_Rectangle :: struct {
    position          : op.V2_Render,
    dimensions        : op.V2_Render,
    origin            : op.V2_Uniform,
    stroke            : Maybe(raylib.Color),
    fill              : Maybe(raylib.Color),
    roundness         : f32,
    outline_thickness : Maybe(f32),
}

Rendering_Task_Line :: struct {
    positions         : [2]op.V2_Render,
    color             : Maybe(raylib.Color),
    outline_thickness : Maybe(f32),
}



Rendering_Texture_Reference :: union {
    Baked_Texture,
    raylib.Texture,
}





////////////////////////////////////////////////////////////////////////////////





render :: proc(rendering_tasks : []Rendering_Task) {

    for rendering_task in rendering_tasks {

        switch task in rendering_task {



            case Rendering_Task_Texture: {

                texture : raylib.Texture

                switch reference in task.reference {
                    case Baked_Texture : texture = BAKED_TEXTURES[reference]
                    case raylib.Texture              : texture = reference
                    case                             : panic("Invalid.")
                }

                dest := op.to_screen_for_rectangle(
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
                    font     = BAKED_FONTS[task.font],
                    text     = task.text,
                    fontSize = task.size,
                    spacing  = 0,
                )

                rectangle := op.to_screen_for_rectangle(
                    position   = task.position,
                    dimensions = op.V2_Screen(screen_dimensions),
                    origin     = task.origin,
                )

                if task.adjust_position_to_be_within_screen {
                    rectangle.x = clamp(rectangle.x, 0, f32(raylib.GetScreenWidth ()) - rectangle.width )
                    rectangle.y = clamp(rectangle.y, 0, f32(raylib.GetScreenHeight()) - rectangle.height)
                }

                raylib.DrawTextEx(
                    font     = BAKED_FONTS[task.font],
                    text     = task.text,
                    position = { rectangle.x, rectangle.y },
                    fontSize = task.size,
                    spacing  = 0,
                    tint     = task.color.? or_else raylib.WHITE,
                )

            }



            case Rendering_Task_Dialogue_Bubble: {

                FONT_SIZE :: 30
                PADDING   :: 15
                ROUNDNESS :: 0.3
                OUTLINE   :: 4

                tip := op.to_screen_for_position(task.position)

                measurement := raylib.MeasureTextEx(
                    font     = BAKED_FONTS[task.font],
                    text     = task.text,
                    fontSize = FONT_SIZE,
                    spacing  = 0,
                )

                rec := raylib.Rectangle {
                    tip.x         - PADDING / 2,
                    tip.y         - PADDING * 3 - measurement.y,
                    measurement.x + PADDING * 2,
                    measurement.y + PADDING * 2,
                }

                vertices := [?][2]f32 {
                    { tip.x                      , rec.y + rec.height },
                    { tip.x                      , tip.y              },
                    { tip.x + (tip.x - rec.x) * 2, rec.y + rec.height },
                }

                raylib.DrawRectangleRoundedLinesEx( // Dialogue bubble outline.
                    rec       = rec,
                    roundness = ROUNDNESS,
                    segments  = 0,
                    lineThick = OUTLINE,
                    color     = raylib.BLACK,
                )

                raylib.DrawTriangle(                // Fill of the bubble tip.
                    v1       = vertices[0],
                    v2       = vertices[1],
                    v3       = vertices[2],
                    color    = raylib.LIGHTGRAY,
                )

                raylib.DrawLineEx(                  // First side of the bubble tip's outline.
                    startPos = vertices[0],
                    endPos   = vertices[1],
                    thick    = OUTLINE,
                    color    = raylib.BLACK,
                )

                raylib.DrawLineEx(                  // Second side of the bubble tip's outline.
                    startPos = vertices[1],
                    endPos   = vertices[2],
                    thick    = OUTLINE,
                    color    = raylib.BLACK,
                )

                raylib.DrawRectangleRounded(        // Fill of the dialogue bubble.
                    rec       = rec,
                    roundness = ROUNDNESS,
                    segments  = 0,
                    color     = raylib.LIGHTGRAY,
                )

                raylib.DrawTextEx(                  // Finally the dialogue bubble text itself.
                    font     = BAKED_FONTS[task.font],
                    text     = task.text,
                    position = {
                        rec.x + PADDING,
                        rec.y + PADDING,
                    },
                    fontSize = FONT_SIZE,
                    spacing  = 0,
                    tint     = raylib.BLACK,
                )

            }



            case Rendering_Task_Rectangle: {

                rec := op.to_screen_for_rectangle(
                    task.position,
                    task.dimensions,
                    task.origin,
                )

                rec.width  = max(rec.width , 0)
                rec.height = max(rec.height, 0)

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



            case Rendering_Task_Line: {

                raylib.DrawLineEx(
                    startPos = op.to_screen_for_position(task.positions[0]).xy,
                    endPos   = op.to_screen_for_position(task.positions[1]).xy,
                    thick    = task.outline_thickness.? or_else 1,
                    color    = task.color.? or_else raylib.BLACK,
                )

            }



            case: panic("Invalid.")

        }

    }

}





////////////////////////////////////////////////////////////////////////////////

import "vendor:raylib"
import "op"
