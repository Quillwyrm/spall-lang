package spall

import "core:fmt"


// Bytecode =======================================================================================

// Stack bytecode. Operand meaning is decided by the opcode.
Op :: enum u8 {
	PUSH_CONST,

	ADD,
	SUB,
	MUL,
	DIV,

	DUP,
	DROP,
	SWAP,
	OVER,

	WRITE,
	PRINT,

	// Later:
	// MOD,
	// WORD,
	// DEF,
	// DO,
}

Inst :: bit_field u32 {
	op:  Op  | 8,
	arg: u32 | 24,
}

decode_op :: #force_inline proc(word: u32) -> Op {
	return Op(u8(word & 0xff))
}


// Code ===========================================================================================

// Code is one executable stack bytecode stream.
// bytecode[i] came from source line inst_lines[i].
Code :: struct {
	bytecode:   [dynamic]u32,
	inst_lines: [dynamic]int,
	const_pool: [dynamic]Value,
}


// Runtime data ===================================================================================

Value :: union {
	i64,
	f64,
}

VM :: struct {
	stack:        [dynamic]Value,
	error_string: string,
}


// Stack operations ===============================================================================

push_value :: proc(vm: ^VM, value: Value) {
	append(&vm.stack, value)
}

pop_value :: proc(vm: ^VM) -> Value {
	assert(len(vm.stack) > 0, "VM stack underflow")

	value := vm.stack[len(vm.stack) - 1]
	pop(&vm.stack)
	return value
}


// Values =========================================================================================

write_value :: proc(value: Value) {
	switch v in value {
	case i64:
		fmt.print(v)

	case f64:
		if v == f64(i64(v)) {
			fmt.printf("%.1f", v)
		} else {
			fmt.printf("%g", v)
		}
	}
}

print_value :: proc(value: Value) {
	write_value(value)
	fmt.println()
}


// Execution ======================================================================================

run_number_op :: proc(vm: ^VM, op: Op) {
	rhs := pop_value(vm)
	lhs := pop_value(vm)

	switch l in lhs {
	case i64:
		switch r in rhs {
		case i64:
			if op == .ADD {
				push_value(vm, Value(l + r))
				return
			}

			if op == .SUB {
				push_value(vm, Value(l - r))
				return
			}

			if op == .MUL {
				push_value(vm, Value(l * r))
				return
			}

			if op == .DIV {
				push_value(vm, Value(f64(l) / f64(r)))
				return
			}

		case f64:
			if op == .ADD {
				push_value(vm, Value(f64(l) + r))
				return
			}

			if op == .SUB {
				push_value(vm, Value(f64(l) - r))
				return
			}

			if op == .MUL {
				push_value(vm, Value(f64(l) * r))
				return
			}

			if op == .DIV {
				push_value(vm, Value(f64(l) / r))
				return
			}
		}

	case f64:
		switch r in rhs {
		case i64:
			if op == .ADD {
				push_value(vm, Value(l + f64(r)))
				return
			}

			if op == .SUB {
				push_value(vm, Value(l - f64(r)))
				return
			}

			if op == .MUL {
				push_value(vm, Value(l * f64(r)))
				return
			}

			if op == .DIV {
				push_value(vm, Value(l / f64(r)))
				return
			}

		case f64:
			if op == .ADD {
				push_value(vm, Value(l + r))
				return
			}

			if op == .SUB {
				push_value(vm, Value(l - r))
				return
			}

			if op == .MUL {
				push_value(vm, Value(l * r))
				return
			}

			if op == .DIV {
				push_value(vm, Value(l / r))
				return
			}
		}
	}

	assert(false, "invalid numeric opcode")
}

run_code :: proc(vm: ^VM, code: ^Code) -> bool {
	vm.error_string = ""

	for ip := 0; ip < len(code.bytecode); ip += 1 {
		inst := Inst(code.bytecode[ip])

		switch inst.op {
		case .PUSH_CONST:
			const_index := int(inst.arg)
			assert(const_index >= 0 && const_index < len(code.const_pool), "PUSH_CONST constant index out of range")

			push_value(vm, code.const_pool[const_index])

		case .ADD:
			run_number_op(vm, .ADD)

		case .SUB:
			run_number_op(vm, .SUB)

		case .MUL:
			run_number_op(vm, .MUL)

		case .DIV:
			run_number_op(vm, .DIV)

		case .DUP:
			assert(len(vm.stack) >= 1, "DUP stack underflow")

			value := vm.stack[len(vm.stack) - 1]
			push_value(vm, value)

		case .DROP:
			pop_value(vm)

		case .SWAP:
			assert(len(vm.stack) >= 2, "SWAP stack underflow")

			top := len(vm.stack) - 1
			vm.stack[top], vm.stack[top - 1] = vm.stack[top - 1], vm.stack[top]

		case .OVER:
			assert(len(vm.stack) >= 2, "OVER stack underflow")

			value := vm.stack[len(vm.stack) - 2]
			push_value(vm, value)

		case .WRITE:
			value := pop_value(vm)
			write_value(value)

		case .PRINT:
			value := pop_value(vm)
			print_value(value)
		}
	}

	return true
}
