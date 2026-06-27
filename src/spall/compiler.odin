package spall

import "core:fmt"


// Compiler state =================================================================================

// Compiler is package-local scratch state for building one Code object.
// VM is host-owned runtime state; Compiler is not.
Compiler := struct {
	code:         Code,
	error_string: string,
	stack_depth:  int,
}{}


// Bytecode emission ==============================================================================

emit_inst :: proc(op: Op, arg: u32 = 0) {
	inst := Inst {
		op  = op,
		arg = arg,
	}

	append(&Compiler.code.bytecode, u32(inst))
	append(&Compiler.code.inst_lines, 0)
}

require_stack :: proc(word: string, count: int) -> bool {
	if Compiler.stack_depth >= count {
		return true
	}

	Compiler.error_string = fmt.tprintf("%s needs %d stack values", word, count)
	return false
}


// Constants ======================================================================================

const_int :: proc(value: i64) -> u32 {
	append(&Compiler.code.const_pool, Value(value))
	return u32(len(Compiler.code.const_pool) - 1)
}

const_float :: proc(value: f64) -> u32 {
	append(&Compiler.code.const_pool, Value(value))
	return u32(len(Compiler.code.const_pool) - 1)
}


// Source compilation =============================================================================

compile_source :: proc(source: string) -> (Code, bool) {
	begin_lex(source)

	clear(&Compiler.code.bytecode)
	clear(&Compiler.code.inst_lines)
	clear(&Compiler.code.const_pool)
	Compiler.error_string = ""
	Compiler.stack_depth = 0

	for {
		token := lex_next_token()

		switch token.kind {
		case .EOF:
			return Compiler.code, true

		case .ERROR:
			Compiler.error_string = token.value.(string)
			return {}, false

		case .INT:
			value := token.value.(i64)
			const_index := const_int(value)
			emit_inst(.PUSH_CONST, const_index)
			Compiler.stack_depth += 1

		case .FLOAT:
			value := token.value.(f64)
			const_index := const_float(value)
			emit_inst(.PUSH_CONST, const_index)
			Compiler.stack_depth += 1

		case .WORD:
			word := token.value.(string)

			switch word {
			case "+":
				if !require_stack(word, 2) {
					return {}, false
				}

				emit_inst(.ADD)
				Compiler.stack_depth -= 1

			case "-":
				if !require_stack(word, 2) {
					return {}, false
				}

				emit_inst(.SUB)
				Compiler.stack_depth -= 1

			case "*":
				if !require_stack(word, 2) {
					return {}, false
				}

				emit_inst(.MUL)
				Compiler.stack_depth -= 1

			case "/":
				if !require_stack(word, 2) {
					return {}, false
				}

				emit_inst(.DIV)
				Compiler.stack_depth -= 1

			case "dup":
				if !require_stack(word, 1) {
					return {}, false
				}

				emit_inst(.DUP)
				Compiler.stack_depth += 1

			case "drop":
				if !require_stack(word, 1) {
					return {}, false
				}

				emit_inst(.DROP)
				Compiler.stack_depth -= 1

			case "swap":
				if !require_stack(word, 2) {
					return {}, false
				}

				emit_inst(.SWAP)

			case "over":
				if !require_stack(word, 2) {
					return {}, false
				}

				emit_inst(.OVER)
				Compiler.stack_depth += 1

			case ".":
				if !require_stack(word, 1) {
					return {}, false
				}

				emit_inst(.WRITE)
				Compiler.stack_depth -= 1

			case "print":
				if !require_stack(word, 1) {
					return {}, false
				}

				emit_inst(.PRINT)
				Compiler.stack_depth -= 1

			case:
				Compiler.error_string = fmt.tprintf("unknown word: %s", word)
				return {}, false
			}
		}
	}
}


// Debug ==========================================================================================

op_to_string :: proc(op: Op) -> string {
	switch op {
	case .PUSH_CONST:
		return "PUSH_CONST"

	case .ADD:
		return "ADD"
	case .SUB:
		return "SUB"
	case .MUL:
		return "MUL"
	case .DIV:
		return "DIV"

	case .DUP:
		return "DUP"
	case .DROP:
		return "DROP"
	case .SWAP:
		return "SWAP"
	case .OVER:
		return "OVER"

	case .WRITE:
		return "WRITE"
	case .PRINT:
		return "PRINT"
	}

	return "UNKNOWN"
}

debug_print_code :: proc(code: ^Code) {
	fmt.println("CONSTANTS:")

	for index := 0; index < len(code.const_pool); index += 1 {
		value := code.const_pool[index]

		switch v in value {
		case i64:
			fmt.printf("  %04d %-6s %d\n", index, "INT", v)

		case f64:
			fmt.printf("  %04d %-6s %g\n", index, "FLOAT", v)
		}
	}

	fmt.println("")
	fmt.println("CODE:")

	for index := 0; index < len(code.bytecode); index += 1 {
		inst := Inst(code.bytecode[index])
		op_text := op_to_string(inst.op)

		if inst.op == .PUSH_CONST {
			fmt.printf("  %04d %-10s %d\n", index, op_text, inst.arg)
		} else {
			fmt.printf("  %04d %s\n", index, op_text)
		}
	}
}
