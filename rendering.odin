package main

import "vendor:raylib"



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
