package veld

import "core:fmt"
import "core:strings"


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
	NEWLINE,

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


// Code ===========================================================================================

// Code aliases Compiler scratch storage and is valid only until the next compile_source call.
Code :: struct {
	bytecode:   [dynamic]u32,
	const_pool: [dynamic]Value,
}

// VM values ===========================================================================================

ObjectKind :: enum u8 {
	STRING,
}

ObjectHeader :: struct {
	kind: ObjectKind,
}

StringObject :: struct {
	header: ObjectHeader,
	text:   string,
}

Value :: union {
	i64,
	f64,
	^ObjectHeader,
}

new_string_object :: proc(text: string) -> ^StringObject {
	object := new(StringObject)
	object.header.kind = .STRING
	object.text = strings.clone(text)
	return object
}

// VM context ===================================================================================

VM :: struct {
	stack:        [dynamic]Value,
	error_string: string,
}

// Execution is single-active and non-reentrant.
Active_VM: ^VM


// Stack operations ===============================================================================

push_value :: proc(value: Value) {
	append(&Active_VM.stack, value)
}

pop_value :: proc() -> Value {
	assert(len(Active_VM.stack) > 0, "VM stack underflow")

	value := Active_VM.stack[len(Active_VM.stack) - 1]
	pop(&Active_VM.stack)
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

	case ^ObjectHeader:
		switch v.kind {
		case .STRING:
			object := cast(^StringObject)v
			fmt.print(object.text)

		case:
			assert(false, "invalid object tag")
		}
	}
}


// Execution ======================================================================================

runtime_error :: proc(message: string) {
	Active_VM.error_string = message
}

run_number_op :: proc(op: Op) {
	rhs := pop_value()
	lhs := pop_value()

	switch l in lhs {
	case i64:
		switch r in rhs {
		case i64:
			if op == .ADD {
				push_value(Value(l + r))
				return
			}

			if op == .SUB {
				push_value(Value(l - r))
				return
			}

			if op == .MUL {
				push_value(Value(l * r))
				return
			}

			if op == .DIV {
				push_value(Value(f64(l) / f64(r)))
				return
			}

		case f64:
			if op == .ADD {
				push_value(Value(f64(l) + r))
				return
			}

			if op == .SUB {
				push_value(Value(f64(l) - r))
				return
			}

			if op == .MUL {
				push_value(Value(f64(l) * r))
				return
			}

			if op == .DIV {
				push_value(Value(f64(l) / r))
				return
			}

		case ^ObjectHeader:
			runtime_error("numeric operator expected numbers")
			return
		}

	case f64:
		switch r in rhs {
		case i64:
			if op == .ADD {
				push_value(Value(l + f64(r)))
				return
			}

			if op == .SUB {
				push_value(Value(l - f64(r)))
				return
			}

			if op == .MUL {
				push_value(Value(l * f64(r)))
				return
			}

			if op == .DIV {
				push_value(Value(l / f64(r)))
				return
			}

		case f64:
			if op == .ADD {
				push_value(Value(l + r))
				return
			}

			if op == .SUB {
				push_value(Value(l - r))
				return
			}

			if op == .MUL {
				push_value(Value(l * r))
				return
			}

			if op == .DIV {
				push_value(Value(l / r))
				return
			}

		case ^ObjectHeader:
			runtime_error("numeric operator expected numbers")
			return
		}

	case ^ObjectHeader:
		runtime_error("numeric operator expected numbers")
		return
	}

	runtime_error("numeric operator expected numbers")
}

run_code :: proc(vm: ^VM, code: ^Code) -> bool {
	Active_VM = vm
	vm.error_string = ""

	for ip := 0; ip < len(code.bytecode); ip += 1 {
		inst := Inst(code.bytecode[ip])

		switch inst.op {
		case .PUSH_CONST:
			const_index := int(inst.arg)
			assert(const_index < len(code.const_pool), "PUSH_CONST constant index out of range")

			push_value(code.const_pool[const_index])

		case .ADD:
			run_number_op(.ADD)
			if Active_VM.error_string != "" do return false

		case .SUB:
			run_number_op(.SUB)
			if Active_VM.error_string != "" do return false

		case .MUL:
			run_number_op(.MUL)
			if Active_VM.error_string != "" do return false

		case .DIV:
			run_number_op(.DIV)
			if Active_VM.error_string != "" do return false

		case .DUP:
			assert(len(Active_VM.stack) >= 1, "DUP stack underflow")

			value := Active_VM.stack[len(Active_VM.stack) - 1]
			push_value(value)

		case .DROP:
			pop_value()

		case .SWAP:
			assert(len(Active_VM.stack) >= 2, "SWAP stack underflow")

			top := len(Active_VM.stack) - 1
			Active_VM.stack[top], Active_VM.stack[top - 1] = Active_VM.stack[top - 1], Active_VM.stack[top]

		case .OVER:
			assert(len(Active_VM.stack) >= 2, "OVER stack underflow")

			value := Active_VM.stack[len(Active_VM.stack) - 2]
			push_value(value)

		case .WRITE:
			value := pop_value()
			write_value(value)

		case .PRINT:
			value := pop_value()
			write_value(value)
			fmt.println()

		case .NEWLINE:
			fmt.println()

		case:
			assert(false, "invalid opcode")
		}
	}

	return true
}
