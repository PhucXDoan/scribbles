package main

// This file has routines to make working with animations
// based on a parameterized `t` value easier.

////////////////////////////////////////////////////////////////////////////////





Animation :: struct {
    duration : f32,
    value    : f32,
    running  : bool,
    control  : Animation_Control,
}

Animation_Control :: enum {
    Clear_Increase_Reset,
    Increase_Repeat,
    Decrease_Stop,
    Increase_Stop,
}

update_animation :: proc(animation : ^Animation) {

    if !animation.running {
        return
    }

    switch animation.control {

        case .Clear_Increase_Reset: {

            animation.value += raylib.GetFrameTime() / animation.duration

            if animation.value > 1 {
                animation.value   = 0
                animation.running = false
            }

        }

        case .Increase_Repeat: {
            animation.value += raylib.GetFrameTime() / animation.duration
            animation.value  = math.mod_f32(animation.value, 1)
        }

        case .Decrease_Stop: {
            animation.value -= raylib.GetFrameTime() / animation.duration
            animation.value  = clamp(animation.value, 0, 1)
        }

        case .Increase_Stop: {
            animation.value += raylib.GetFrameTime() / animation.duration
            animation.value  = clamp(animation.value, 0, 1)
        }

        case: panic("Invalid.")

    }

}

control_animation :: proc(animation : ^Animation, control : Animation_Control) {

    animation.control = control

    switch control {

        case .Clear_Increase_Reset: {
            animation.value   = 0
            animation.running = true
        }

        case .Increase_Repeat, .Decrease_Stop, .Increase_Stop: {
            animation.running = true
        }

        case: panic("Invalid.")

    }

}

ease_animation :: proc(
    start     : f32,
    end       : f32,
    animation : Animation,
    easing    : ease.Ease = .Linear,
) -> f32 {
    return math.lerp(
        start,
        end,
        ease.ease(easing, animation.value)
    )
}





////////////////////////////////////////////////////////////////////////////////

import "core:math"
import "core:math/ease"
import "vendor:raylib"
