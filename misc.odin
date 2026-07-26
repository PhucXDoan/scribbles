package main

import "core:mem"



push :: proc {
    push_fixed_capacity_dynamic_array_element,
    push_dynamic_array_element,
}

push_fixed_capacity_dynamic_array_element :: proc(array : ^[dynamic; $N]$T, element : T) {
    amount := append(array, element)
    assert(amount == 1)
}

push_dynamic_array_element :: proc(array : ^[dynamic]$T, element : T) {
    amount, _ := append(array, element)
    assert(amount == 1)
}



memeq :: proc(lhs : $T, rhs : T) -> bool {
    lhs_copy := lhs
    rhs_copy := rhs
    return mem.compare_ptrs(&lhs_copy, &rhs_copy, size_of(T)) == 0
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

eat_bytes :: proc(slice : ^[]u8, length : int) -> []u8 {

    assert(len(slice) >= length)

    result := slice[:length ]
    slice^  = slice[ length:]

    return result

}
