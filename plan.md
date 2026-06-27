Yep. Small path. I’d add **one execution block to `vm.odin`**, one small `runtime.odin`, and replace `main.odin`.

## 1. In `vm.odin`, add this import

At top:

```odin
import "core:fmt"
```

## 2. In `vm.odin`, append this after `pop_value`

```odin
print_value :: proc(value: Value) {
	switch v in value {
	case i64:
		fmt.println(v)

	case f64:
		fmt.println(v)

	case bool:
		fmt.println(v)
	}
}

value_as_int :: proc(value: Value) -> (i64, bool) {
	switch v in value {
	case i64:
		return v, true

	case f64:
		return 0, false

	case bool:
		return 0, false
	}

	return 0, false
}

value_as_float :: proc(value: Value) -> (f64, bool) {
	switch v in value {
	case i64:
		return f64(v), true

	case f64:
		return v, true

	case bool:
		return 0, false
	}

	return 0, false
}

run_number_op :: proc(vm: ^VM, op: Op) -> bool {
	if len(vm.stack) < 2 {
		vm.error_string = "stack underflow"
		return false
	}

	rhs, _ := pop_value(vm)
	lhs, _ := pop_value(vm)

	if op == .MOD {
		lhs_int, lhs_ok := value_as_int(lhs)
		rhs_int, rhs_ok := value_as_int(rhs)

		if !lhs_ok || !rhs_ok {
			vm.error_string = "mod expects two ints"
			return false
		}

		push_value(vm, Value(lhs_int % rhs_int))
		return true
	}

	lhs_int, lhs_is_int := value_as_int(lhs)
	rhs_int, rhs_is_int := value_as_int(rhs)

	if lhs_is_int && rhs_is_int && op != .DIV {
		if op == .ADD {
			push_value(vm, Value(lhs_int + rhs_int))
			return true
		}

		if op == .SUB {
			push_value(vm, Value(lhs_int - rhs_int))
			return true
		}

		if op == .MUL {
			push_value(vm, Value(lhs_int * rhs_int))
			return true
		}
	}

	lhs_float, lhs_ok := value_as_float(lhs)
	rhs_float, rhs_ok := value_as_float(rhs)

	if !lhs_ok || !rhs_ok {
		vm.error_string = "numeric op expects numbers"
		return false
	}

	if op == .ADD {
		push_value(vm, Value(lhs_float + rhs_float))
		return true
	}

	if op == .SUB {
		push_value(vm, Value(lhs_float - rhs_float))
		return true
	}

	if op == .MUL {
		push_value(vm, Value(lhs_float * rhs_float))
		return true
	}

	if op == .DIV {
		push_value(vm, Value(lhs_float / rhs_float))
		return true
	}

	vm.error_string = "invalid numeric op"
	return false
}

run_code :: proc(vm: ^VM, code: ^Code) -> bool {
	vm.error_string = ""

	for ip := 0; ip < len(code.bytecode); ip += 1 {
		inst := Inst(code.bytecode[ip])

		switch inst.op {
		case .PUSH_CONST:
			const_index := int(inst.arg)

			if const_index >= len(code.const_pool) {
				vm.error_string = "constant index out of range"
				return false
			}

			push_value(vm, code.const_pool[const_index])

		case .ADD:
			if !run_number_op(vm, .ADD) do return false

		case .SUB:
			if !run_number_op(vm, .SUB) do return false

		case .MUL:
			if !run_number_op(vm, .MUL) do return false

		case .DIV:
			if !run_number_op(vm, .DIV) do return false

		case .MOD:
			if !run_number_op(vm, .MOD) do return false

		case .DUP:
			if len(vm.stack) < 1 {
				vm.error_string = "stack underflow"
				return false
			}

			value := vm.stack[len(vm.stack) - 1]
			push_value(vm, value)

		case .DROP:
			_, ok := pop_value(vm)
			if !ok do return false

		case .SWAP:
			if len(vm.stack) < 2 {
				vm.error_string = "stack underflow"
				return false
			}

			top := len(vm.stack) - 1
			vm.stack[top], vm.stack[top - 1] = vm.stack[top - 1], vm.stack[top]

		case .OVER:
			if len(vm.stack) < 2 {
				vm.error_string = "stack underflow"
				return false
			}

			value := vm.stack[len(vm.stack) - 2]
			push_value(vm, value)

		case .PRINT:
			value, ok := pop_value(vm)
			if !ok do return false

			print_value(value)
		}
	}

	return true
}
```

This is the VM execution core. It does not clear the stack at run start, only `error_string`, which is better for later REPL behavior.

## 3. Add `src/veld/runtime.odin`

```odin
package veld

import "core:fmt"
import "core:os"


run_string :: proc(vm: ^VM, source: string) -> bool {
	code, ok := compile_source(source)
	if !ok {
		vm.error_string = Compiler.error_string
		return false
	}

	return run_code(vm, &code)
}

run_file :: proc(vm: ^VM, path: string) -> bool {
	bytes, read_error := os.read_entire_file(path, context.allocator)
	if read_error != nil {
		vm.error_string = fmt.tprintf("could not read file `%s`: %v", path, read_error)
		return false
	}
	defer delete(bytes)

	return run_string(vm, string(bytes))
}
```

This gives you the host-facing core:

```odin
veld.run_string(&vm, source)
veld.run_file(&vm, path)
```

## 4. Replace `main.odin`

```odin
package main

import "core:fmt"
import "core:os"
import "core:strings"
import "veld"

print_help :: proc() {
	fmt.println("veld")
	fmt.println("")
	fmt.println("Usage:")
	fmt.println("  veld run <file>")
	fmt.println("  veld eval <source>")
	fmt.println("  veld dump <source>")
}

join_args :: proc(args: []string, start: int) -> string {
	result := ""

	for index := start; index < len(args); index += 1 {
		if index > start {
			result = fmt.tprintf("%s %s", result, args[index])
		} else {
			result = args[index]
		}
	}

	return result
}

main :: proc() {
	if len(os.args) < 2 {
		print_help()
		return
	}

	command := os.args[1]

	if command == "help" || command == "--help" || command == "-h" {
		print_help()
		return
	}

	if command == "run" {
		if len(os.args) != 3 {
			fmt.eprintln("usage: veld run <file>")
			os.exit(1)
		}

		vm: veld.VM
		if !veld.run_file(&vm, os.args[2]) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	if command == "eval" {
		if len(os.args) < 3 {
			fmt.eprintln("usage: veld eval <source>")
			os.exit(1)
		}

		source := join_args(os.args, 2)

		vm: veld.VM
		if !veld.run_string(&vm, source) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	if command == "dump" {
		if len(os.args) < 3 {
			fmt.eprintln("usage: veld dump <source>")
			os.exit(1)
		}

		source := join_args(os.args, 2)

		code, ok := veld.compile_source(source)
		if !ok {
			fmt.eprintln(veld.Compiler.error_string)
			os.exit(1)
		}

		veld.debug_print_code(&code)
		return
	}

	if strings.has_suffix(command, ".veld") {
		vm: veld.VM
		if !veld.run_file(&vm, command) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	fmt.eprintfln("unknown command: %s", command)
	print_help()
	os.exit(1)
}
```

Then you should be able to do:

```powershell
.\veld.exe eval 1 2 + print
.\veld.exe eval "10 3 mod print"
.\veld.exe dump "1 2 + print"
.\veld.exe run test.veld
```

One note: this is intentionally not a REPL yet. It just sets up the right boundary so REPL later is trivial:

```odin
vm: veld.VM
for each input line:
	veld.run_string(&vm, line)
```
