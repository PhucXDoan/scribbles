package op

////////////////////////////////////////////////////////////////////////////////





push :: proc {
    push_fixed_capacity_dynamic_array_element,
    push_fixed_capacity_dynamic_array_elements,
    push_dynamic_array_element,
    push_dynamic_array_elements,
}

push_fixed_capacity_dynamic_array_element :: proc(array : ^[dynamic; $N]$T, #no_broadcast element : T) {
    amount := append(array, element)
    assert(amount == 1)
}

push_fixed_capacity_dynamic_array_elements :: proc(array : ^[dynamic; $N]$T, #no_broadcast elements : ..T) {
    amount := append(array, ..elements)
    assert(amount == len(elements))
}

push_dynamic_array_element :: proc(array : ^[dynamic]$T, #no_broadcast element : T) {
    amount, _ := append(array, element)
    assert(amount == 1)
}

push_dynamic_array_elements :: proc(array : ^[dynamic]$T, #no_broadcast elements : ..T) {
    amount := append(array, ..elements)
    assert(amount == len(elements))
}

memeq :: proc(lhs : $T, rhs : T) -> bool {
    return slice.equal(mem.any_to_bytes(lhs), mem.any_to_bytes(rhs))
}



eat :: proc {
    eat_type,
    eat_bytes,
}

eat_type :: proc(slice : ^[]u8, $T : typeid) -> ^T {

    assert(len(slice^) >= size_of(T))

    result := transmute(^T) raw_data(slice^)
    slice^  = slice[size_of(T):]

    return result

}

eat_bytes :: proc(slice : ^[]u8, #any_int length : int) -> []u8 {

    assert(len(slice) >= int(length))

    result := slice[:length ]
    slice^  = slice[ length:]

    return result

}



linear_search :: proc {
    slice.linear_search,
    linear_search_enumerated_array,
}

linear_search_enumerated_array :: proc "contextless" (array : ^[$E]$T, key : T) -> (E, bool) {
    index, found := slice.linear_search(slice.enumerated_array(array), key)
    return E(index), found
}



defer_reset_default_temp_allocator :: runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD





////////////////////////////////////////////////////////////////////////////////





V2_Pixel   :: distinct [2]f32
V2_Uniform :: distinct [2]f32
V2_Squared :: distinct [2]f32
V2_Render  :: union {
    V2_Pixel,
    V2_Uniform,
    V2_Squared,
}



to_pixel_for_position :: proc {
    to_pixel_from_squared_for_position,
    to_pixel_from_uniform_for_position,
    to_pixel_from_pixel_for_position,
    to_pixel_from_render_for_position,
}

to_pixel_from_squared_for_position :: proc(position : V2_Squared) -> V2_Pixel {
    return {
        (f32(raylib.GetScreenWidth ()) + position.x * f32(raylib.GetScreenWidth())) / 2,
        (f32(raylib.GetScreenHeight()) - position.y * f32(raylib.GetScreenWidth())) / 2,
    }
}

to_pixel_from_uniform_for_position :: proc(position : V2_Uniform) -> V2_Pixel {
    return {
        (f32(raylib.GetScreenWidth ()) + position.x * f32(raylib.GetScreenWidth ())) / 2,
        (f32(raylib.GetScreenHeight()) - position.y * f32(raylib.GetScreenHeight())) / 2,
    }
}

to_pixel_from_pixel_for_position :: proc(position : V2_Pixel) -> V2_Pixel {
    return {
        position.x,
        position.y,
    }
}

to_pixel_from_render_for_position :: proc(position : V2_Render) -> V2_Pixel {
    switch p in position {
        case V2_Squared : return to_pixel_from_squared_for_position(p)
        case V2_Uniform : return to_pixel_from_uniform_for_position(p)
        case V2_Pixel   : return to_pixel_from_pixel_for_position(p)
        case            : panic("Invalid.")
    }
}



to_pixel_for_dimensions :: proc {
    to_pixel_from_squared_for_dimensions,
    to_pixel_from_uniform_for_dimensions,
    to_pixel_from_pixel_for_dimensions,
    to_pixel_from_render_for_dimensions,
}

to_pixel_from_squared_for_dimensions :: proc(d : V2_Squared) -> V2_Pixel {
    return {
        d.x * f32(raylib.GetScreenWidth()),
        d.y * f32(raylib.GetScreenWidth()),
    }
}

to_pixel_from_uniform_for_dimensions :: proc(d : V2_Uniform) -> V2_Pixel {
    return {
        d.x * f32(raylib.GetScreenWidth ()),
        d.y * f32(raylib.GetScreenHeight()),
    }
}

to_pixel_from_pixel_for_dimensions :: proc(d : V2_Pixel) -> V2_Pixel {
    return {
        d.x,
        d.y,
    }
}

to_pixel_from_render_for_dimensions :: proc(dimensions : V2_Render) -> V2_Pixel {
    switch d in dimensions {
        case V2_Squared : return to_pixel_from_squared_for_dimensions(d)
        case V2_Uniform : return to_pixel_from_uniform_for_dimensions(d)
        case V2_Pixel   : return to_pixel_from_pixel_for_dimensions(d)
        case            : panic("Invalid.")
    }
}



to_pixel_for_rectangle :: proc(
    position   : V2_Render,
    dimensions : V2_Render,
    origin     : V2_Uniform,
) -> raylib.Rectangle {

    pixel_position   := to_pixel_for_position(position)
    pixel_dimensions := to_pixel_for_dimensions(dimensions)

    return {
        pixel_position.x + pixel_dimensions.x * (-1 - origin.x) / 2,
        pixel_position.y - pixel_dimensions.y * (+1 - origin.y) / 2,
        pixel_dimensions.x,
        pixel_dimensions.y,
    }

}

to_pixel_for_rectangle_position :: proc(
    position   : V2_Render,
    dimensions : V2_Render,
    origin     : V2_Uniform,
    center     : V2_Uniform,
) -> V2_Pixel {

    pixel_position   := to_pixel_for_position(position)
    pixel_dimensions := to_pixel_for_dimensions(dimensions)

    return {
        pixel_position.x + pixel_dimensions.x * (center.x - origin.x) / 2,
        pixel_position.y - pixel_dimensions.y * (center.y - origin.y) / 2,
    }

}



to_squared_from_pixel :: proc(position : V2_Pixel) -> V2_Squared {
    return {
        +(position.x * 2 - f32(raylib.GetScreenWidth ())) / f32(raylib.GetScreenWidth()),
        -(position.y * 2 - f32(raylib.GetScreenHeight())) / f32(raylib.GetScreenWidth()),
    }
}

to_uniform_from_pixel :: proc(position : V2_Pixel) -> V2_Uniform {
    return {
        +(position.x * 2 - f32(raylib.GetScreenWidth ())) / f32(raylib.GetScreenWidth ()),
        -(position.y * 2 - f32(raylib.GetScreenHeight())) / f32(raylib.GetScreenHeight()),
    }
}



dampen :: proc(a : $T, b : T, k : f32) -> T {
    return math.lerp(b, a, math.exp(-k * raylib.GetFrameTime()))
}





////////////////////////////////////////////////////////////////////////////////

import "base:runtime"
import "core:mem"
import "core:slice"
import "core:math"
import "vendor:raylib"
