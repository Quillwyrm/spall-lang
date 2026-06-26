package spall


// Bytecode =======================================================================================
// Stack bytecode. Operand meaning is decided by the opcode.

Op :: enum u8 {
    PUSH_CONST,

    ADD,
    SUB,
    MUL,
    DIV,
    MOD,

    DUP,
    DROP,
    SWAP,
    OVER,

    PRINT,

    // Later:
    // WORD,
    // DEF,
    // DO,
}

Inst :: bit_field u32 {
    op:      Op  | 8,
    arg: u32 | 24,
}

decode_op :: #force_inline proc(word: u32) -> Op {
    return Op(u8(word & 0xff))
}

// Code is one executable stack bytecode stream.
// bytecode[i] came from source line inst_lines[i].
Code :: struct {
    bytecode:   [dynamic]u32,
    inst_lines: [dynamic]int,
    const_pool:     [dynamic]Value,
}


// Runtime data ===================================================================================

Value :: union {
    i64,
    f64,
    bool,
}

VM :: struct {
    stack:        [dynamic]Value,
    error_string: string,
}
